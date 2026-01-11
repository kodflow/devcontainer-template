# Idempotent Receiver Pattern

> Garantir un traitement unique malgré les messages dupliqués en stockant les identifiants des messages déjà traités.

## Vue d'ensemble

```
                     +---------------------+
Message 1 (id: A) -->|                     |
                     |  Idempotent         |
Message 2 (id: A) -->|  Receiver           |--> Traitement unique
                     |                     |
Message 3 (id: A) -->|  [Dedup Store]      |
                     +---------------------+
                            |
                            v
                     +-------------+
                     | id: A       |
                     | processed:  |
                     | true        |
                     +-------------+
```

---

## Implementation de base

```go
package messaging

import (
	"context"
	"fmt"
	"time"
)

type IdempotencyStore interface {
	Exists(ctx context.Context, messageID string) (bool, error)
	Mark(ctx context.Context, messageID string, ttlSeconds int) (bool, error)
	GetResult(ctx context.Context, messageID string) (interface{}, error)
	StoreResult(ctx context.Context, messageID string, result interface{}, ttlSeconds int) error
}

type MessageHandler[TMessage any, TResult any] func(ctx context.Context, message TMessage) (TResult, error)
type IDExtractor[TMessage any] func(message TMessage) string

type IdempotentReceiver[TMessage any, TResult any] struct {
	store       IdempotencyStore
	handler     MessageHandler[TMessage, TResult]
	idExtractor IDExtractor[TMessage]
	ttlSeconds  int
}

func NewIdempotentReceiver[TMessage any, TResult any](
	store IdempotencyStore,
	handler MessageHandler[TMessage, TResult],
	idExtractor IDExtractor[TMessage],
	ttlSeconds int,
) *IdempotentReceiver[TMessage, TResult] {
	if ttlSeconds == 0 {
		ttlSeconds = 86400 // 24 heures par defaut
	}
	return &IdempotentReceiver[TMessage, TResult]{
		store:       store,
		handler:     handler,
		idExtractor: idExtractor,
		ttlSeconds:  ttlSeconds,
	}
}

type ConcurrentProcessingError struct {
	MessageID string
}

func (e *ConcurrentProcessingError) Error() string {
	return fmt.Sprintf("message %s is being processed concurrently", e.MessageID)
}

func (r *IdempotentReceiver[TMessage, TResult]) Handle(ctx context.Context, message TMessage) (TResult, error) {
	var zero TResult
	messageID := r.idExtractor(message)

	// Verifier si deja traite
	existingResult, err := r.store.GetResult(ctx, messageID)
	if err == nil && existingResult != nil {
		fmt.Printf("Message %s already processed, returning cached result\n", messageID)
		return existingResult.(TResult), nil
	}

	// Marquer comme en cours (pour eviter traitement concurrent)
	acquired, err := r.tryAcquireLock(ctx, messageID)
	if err != nil {
		return zero, fmt.Errorf("acquiring lock: %w", err)
	}
	if !acquired {
		// Un autre worker traite ce message
		return zero, &ConcurrentProcessingError{MessageID: messageID}
	}

	// Traiter le message
	result, err := r.handler(ctx, message)
	if err != nil {
		// En cas d'erreur, liberer le lock pour permettre retry
		r.releaseLock(ctx, messageID)
		return zero, fmt.Errorf("handling message: %w", err)
	}

	// Stocker le resultat
	if err := r.store.StoreResult(ctx, messageID, result, r.ttlSeconds); err != nil {
		return zero, fmt.Errorf("storing result: %w", err)
	}

	return result, nil
}

func (r *IdempotentReceiver[TMessage, TResult]) tryAcquireLock(ctx context.Context, messageID string) (bool, error) {
	return r.store.Mark(ctx, messageID, r.ttlSeconds)
}

func (r *IdempotentReceiver[TMessage, TResult]) releaseLock(ctx context.Context, messageID string) error {
	// Implementation depends on store
	return nil
}
```

---

## Implementation Redis

```go
package messaging

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

type RedisIdempotencyStore struct {
	client *redis.Client
}

func NewRedisIdempotencyStore(client *redis.Client) *RedisIdempotencyStore {
	return &RedisIdempotencyStore{client: client}
}

func (r *RedisIdempotencyStore) Exists(ctx context.Context, messageID string) (bool, error) {
	key := r.getKey(messageID)
	count, err := r.client.Exists(ctx, key).Result()
	if err != nil {
		return false, fmt.Errorf("checking existence: %w", err)
	}
	return count == 1, nil
}

func (r *RedisIdempotencyStore) Mark(ctx context.Context, messageID string, ttlSeconds int) (bool, error) {
	key := r.getKey(messageID)
	ttl := time.Duration(ttlSeconds) * time.Second
	
	// SETNX retourne true si la cle n'existait pas
	ok, err := r.client.SetNX(ctx, key, "processing", ttl).Result()
	if err != nil {
		return false, fmt.Errorf("marking: %w", err)
	}
	return ok, nil
}

func (r *RedisIdempotencyStore) GetResult(ctx context.Context, messageID string) (interface{}, error) {
	key := r.getResultKey(messageID)
	result, err := r.client.Get(ctx, key).Result()
	if err == redis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("getting result: %w", err)
	}

	var data interface{}
	if err := json.Unmarshal([]byte(result), &data); err != nil {
		return nil, fmt.Errorf("unmarshaling result: %w", err)
	}
	return data, nil
}

func (r *RedisIdempotencyStore) StoreResult(ctx context.Context, messageID string, result interface{}, ttlSeconds int) error {
	processingKey := r.getKey(messageID)
	resultKey := r.getResultKey(messageID)
	ttl := time.Duration(ttlSeconds) * time.Second

	resultJSON, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("marshaling result: %w", err)
	}

	// Transaction atomique avec pipeline
	pipe := r.client.Pipeline()
	pipe.Set(ctx, resultKey, resultJSON, ttl)
	pipe.Set(ctx, processingKey, "completed", ttl)
	_, err = pipe.Exec(ctx)
	if err != nil {
		return fmt.Errorf("storing result: %w", err)
	}

	return nil
}

func (r *RedisIdempotencyStore) getKey(messageID string) string {
	return fmt.Sprintf("idempotency:%s", messageID)
}

func (r *RedisIdempotencyStore) getResultKey(messageID string) string {
	return fmt.Sprintf("idempotency:result:%s", messageID)
}

// Usage
type Order struct {
	OrderID    string
	CustomerID string
	Total      float64
}

type OrderResult struct {
	OrderID string
	Status  string
}

func ExampleUsage(ctx context.Context) error {
	redisClient := redis.NewClient(&redis.Options{
		Addr: "localhost:6379",
	})
	store := NewRedisIdempotencyStore(redisClient)

	processOrder := func(ctx context.Context, order Order) (OrderResult, error) {
		// Process order logic here
		return OrderResult{
			OrderID: order.OrderID,
			Status:  "processed",
		}, nil
	}

	receiver := NewIdempotentReceiver(
		store,
		processOrder,
		func(order Order) string { return order.OrderID },
		3600, // 1 heure TTL
	)

	orderMessage := Order{
		OrderID:    "ORD-123",
		CustomerID: "CUST-456",
		Total:      99.99,
	}

	result, err := receiver.Handle(ctx, orderMessage)
	if err != nil {
		return fmt.Errorf("handling order: %w", err)
	}

	fmt.Printf("Order processed: %+v\n", result)
	return nil
}
```

---

## Implementation PostgreSQL

```go
package messaging

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
)

type PostgresIdempotencyStore struct {
	db *sql.DB
}

func NewPostgresIdempotencyStore(db *sql.DB) *PostgresIdempotencyStore {
	return &PostgresIdempotencyStore{db: db}
}

func (p *PostgresIdempotencyStore) Exists(ctx context.Context, messageID string) (bool, error) {
	var count int
	err := p.db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM processed_messages WHERE message_id = $1`,
		messageID,
	).Scan(&count)
	if err != nil {
		return false, fmt.Errorf("checking existence: %w", err)
	}
	return count > 0, nil
}

func (p *PostgresIdempotencyStore) Mark(ctx context.Context, messageID string, ttlSeconds int) (bool, error) {
	query := `INSERT INTO processed_messages (message_id, status, created_at, expires_at)
              VALUES ($1, 'processing', NOW(), NOW() + INTERVAL '%d seconds')
              ON CONFLICT (message_id) DO NOTHING
              RETURNING message_id`

	var id string
	err := p.db.QueryRowContext(ctx, fmt.Sprintf(query, ttlSeconds), messageID).Scan(&id)
	if err == sql.ErrNoRows {
		return false, nil // Already exists
	}
	if err != nil {
		return false, fmt.Errorf("marking: %w", err)
	}
	return true, nil
}

func (p *PostgresIdempotencyStore) StoreResult(ctx context.Context, messageID string, result interface{}, ttlSeconds int) error {
	resultJSON, err := json.Marshal(result)
	if err != nil {
		return fmt.Errorf("marshaling result: %w", err)
	}

	query := `UPDATE processed_messages
              SET status = 'completed', result = $2, completed_at = NOW(),
                  expires_at = NOW() + INTERVAL '%d seconds'
              WHERE message_id = $1`

	_, err = p.db.ExecContext(ctx, fmt.Sprintf(query, ttlSeconds), messageID, resultJSON)
	if err != nil {
		return fmt.Errorf("storing result: %w", err)
	}
	return nil
}

func (p *PostgresIdempotencyStore) GetResult(ctx context.Context, messageID string) (interface{}, error) {
	var resultJSON []byte
	err := p.db.QueryRowContext(ctx,
		`SELECT result FROM processed_messages
         WHERE message_id = $1 AND status = 'completed'`,
		messageID,
	).Scan(&resultJSON)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("getting result: %w", err)
	}

	var result interface{}
	if err := json.Unmarshal(resultJSON, &result); err != nil {
		return nil, fmt.Errorf("unmarshaling result: %w", err)
	}
	return result, nil
}

// Cleanup des entrees expirees
func (p *PostgresIdempotencyStore) Cleanup(ctx context.Context) (int64, error) {
	result, err := p.db.ExecContext(ctx,
		`DELETE FROM processed_messages WHERE expires_at < NOW()`,
	)
	if err != nil {
		return 0, fmt.Errorf("cleanup: %w", err)
	}
	return result.RowsAffected()
}

/*
Schema SQL:

CREATE TABLE processed_messages (
  message_id VARCHAR(255) PRIMARY KEY,
  status VARCHAR(20) NOT NULL DEFAULT 'processing',
  result JSONB,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,

  INDEX idx_expires_at (expires_at)
);
*/
```

---

## Strategies de generation d'ID

```go
package messaging

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
)

// 1. ID fourni par le producer
type MessageWithID struct {
	MessageID string      `json:"messageId"`
	Payload   interface{} `json:"payload"`
}

// 2. Hash du contenu (content-based dedup)
func GenerateContentHash(message interface{}) (string, error) {
	content, err := json.Marshal(message)
	if err != nil {
		return "", fmt.Errorf("marshaling message: %w", err)
	}
	hash := sha256.Sum256(content)
	return hex.EncodeToString(hash[:]), nil
}

// 3. Composite key
type OrderMessage struct {
	CustomerID string
	OrderID    string
	Timestamp  int64
}

func GenerateCompositeID(message OrderMessage) string {
	return fmt.Sprintf("%s:%s:%d", message.CustomerID, message.OrderID, message.Timestamp)
}

// 4. Idempotency key fourni par le client
type HTTPRequest struct {
	Headers map[string]string
	Body    interface{}
}

type HTTPResponse struct {
	Status int
	Body   interface{}
}

type IdempotentAPIHandler struct {
	store IdempotencyStore
}

func NewIdempotentAPIHandler(store IdempotencyStore) *IdempotentAPIHandler {
	return &IdempotentAPIHandler{store: store}
}

func (h *IdempotentAPIHandler) HandleRequest(
	ctx context.Context,
	request *HTTPRequest,
	handler func(ctx context.Context) (*HTTPResponse, error),
) (*HTTPResponse, error) {
	idempotencyKey := request.Headers["Idempotency-Key"]

	if idempotencyKey == "" {
		return handler(ctx)
	}

	cached, err := h.store.GetResult(ctx, idempotencyKey)
	if err == nil && cached != nil {
		return cached.(*HTTPResponse), nil
	}

	response, err := handler(ctx)
	if err != nil {
		return nil, err
	}

	if err := h.store.StoreResult(ctx, idempotencyKey, response, 3600); err != nil {
		return response, fmt.Errorf("storing result: %w", err)
	}

	return response, nil
}
```

---

## Avec RabbitMQ/Kafka

```go
package messaging

import (
	"context"
	"encoding/json"
	"fmt"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/segmentio/kafka-go"
)

// RabbitMQ consumer idempotent
type IdempotentRabbitMQConsumer struct {
	channel *amqp.Channel
	store   IdempotencyStore
	handler MessageHandler[interface{}, interface{}]
}

func NewIdempotentRabbitMQConsumer(
	channel *amqp.Channel,
	store IdempotencyStore,
	handler MessageHandler[interface{}, interface{}],
) *IdempotentRabbitMQConsumer {
	return &IdempotentRabbitMQConsumer{
		channel: channel,
		store:   store,
		handler: handler,
	}
}

func (c *IdempotentRabbitMQConsumer) Consume(ctx context.Context, queue string) error {
	msgs, err := c.channel.Consume(
		queue,
		"",    // consumer
		false, // auto-ack
		false, // exclusive
		false, // no-local
		false, // no-wait
		nil,   // args
	)
	if err != nil {
		return fmt.Errorf("consuming queue: %w", err)
	}

	for msg := range msgs {
		if err := c.processMessage(ctx, msg); err != nil {
			if _, ok := err.(*ConcurrentProcessingError); ok {
				// Requeue pour retry plus tard
				msg.Nack(false, true)
				continue
			}
			// DLQ ou ack selon la politique
			msg.Nack(false, false)
			continue
		}
		msg.Ack(false)
	}

	return nil
}

func (c *IdempotentRabbitMQConsumer) processMessage(ctx context.Context, msg amqp.Delivery) error {
	messageID := msg.MessageId
	if messageID == "" {
		if id, ok := msg.Headers["x-message-id"].(string); ok {
			messageID = id
		} else {
			hash, _ := GenerateContentHash(msg.Body)
			messageID = hash
		}
	}

	receiver := NewIdempotentReceiver(
		c.store,
		c.handler,
		func(_ interface{}) string { return messageID },
		86400,
	)

	var payload interface{}
	if err := json.Unmarshal(msg.Body, &payload); err != nil {
		return fmt.Errorf("unmarshaling payload: %w", err)
	}

	_, err := receiver.Handle(ctx, payload)
	return err
}

// Kafka avec deduplication
type IdempotentKafkaConsumer struct {
	reader  *kafka.Reader
	store   IdempotencyStore
	handler MessageHandler[interface{}, interface{}]
}

func NewIdempotentKafkaConsumer(
	reader *kafka.Reader,
	store IdempotencyStore,
	handler MessageHandler[interface{}, interface{}],
) *IdempotentKafkaConsumer {
	return &IdempotentKafkaConsumer{
		reader:  reader,
		store:   store,
		handler: handler,
	}
}

func (c *IdempotentKafkaConsumer) Consume(ctx context.Context) error {
	for {
		msg, err := c.reader.FetchMessage(ctx)
		if err != nil {
			return fmt.Errorf("fetching message: %w", err)
		}

		// Kafka fournit un ID unique: topic + partition + offset
		messageID := fmt.Sprintf("%s:%d:%d", msg.Topic, msg.Partition, msg.Offset)

		// Ou utiliser une cle metier
		for _, header := range msg.Headers {
			if header.Key == "x-idempotency-key" {
				messageID = string(header.Value)
				break
			}
		}
		if messageID == "" && msg.Key != nil {
			messageID = string(msg.Key)
		}

		receiver := NewIdempotentReceiver(
			c.store,
			c.handler,
			func(_ interface{}) string { return messageID },
			86400,
		)

		var payload interface{}
		if err := json.Unmarshal(msg.Value, &payload); err != nil {
			c.reader.CommitMessages(ctx, msg)
			continue
		}

		if _, err := receiver.Handle(ctx, payload); err != nil {
			// Handle error
			fmt.Printf("Error processing message: %v\n", err)
		}

		c.reader.CommitMessages(ctx, msg)
	}
}
```

---

## Cas d'erreur

```go
package messaging

import (
	"context"
	"fmt"
	"time"
)

type StoreUnavailableError struct{}

func (e *StoreUnavailableError) Error() string {
	return "idempotency store unavailable"
}

type IdempotencyConfig struct {
	FailOpenOnStoreError bool
}

type RobustIdempotentReceiver[T any, R any] struct {
	*IdempotentReceiver[T, R]
	config *IdempotencyConfig
}

func NewRobustIdempotentReceiver[T any, R any](
	store IdempotencyStore,
	handler MessageHandler[T, R],
	idExtractor IDExtractor[T],
	config *IdempotencyConfig,
) *RobustIdempotentReceiver[T, R] {
	return &RobustIdempotentReceiver[T, R]{
		IdempotentReceiver: NewIdempotentReceiver(store, handler, idExtractor, 86400),
		config:             config,
	}
}

func (r *RobustIdempotentReceiver[T, R]) Handle(ctx context.Context, message T) (R, error) {
	var zero R

	// Verifier store disponible
	messageID := r.idExtractor(message)
	_, err := r.store.Exists(ctx, messageID)
	if err != nil {
		// Store indisponible - decision critique
		if r.config.FailOpenOnStoreError {
			// Traiter quand meme (risque de duplicate)
			fmt.Println("Idempotency store unavailable, processing anyway")
			return r.handler(ctx, message)
		}
		// Refuser le traitement
		return zero, &StoreUnavailableError{}
	}

	return r.IdempotentReceiver.Handle(ctx, message)
}

// Cleanup automatique
type IdempotencyCleanupJob struct {
	store PostgresIdempotencyStore
}

func NewIdempotencyCleanupJob(store *PostgresIdempotencyStore) *IdempotencyCleanupJob {
	return &IdempotencyCleanupJob{store: *store}
}

func (j *IdempotencyCleanupJob) Cleanup(ctx context.Context) error {
	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-ticker.C:
			deleted, err := j.store.Cleanup(ctx)
			if err != nil {
				fmt.Printf("Cleanup error: %v\n", err)
			} else {
				fmt.Printf("Cleaned up %d expired idempotency records\n", deleted)
			}
		}
	}
}
```

---

## Tableau de decision

| Scenario | Store | TTL |
|----------|-------|-----|
| Haute frequence | Redis | Court (1h) |
| Audit requis | PostgreSQL | Long (30j) |
| Multi-datacenter | Redis Cluster | Moyen (24h) |
| Fallback local | LRU Cache | Tres court (5m) |

---

## Quand utiliser

- Système de messagerie at-least-once delivery
- Retries automatiques pouvant causer des duplications
- Opérations non-idempotentes par nature (paiements, envois email)
- Besoin de garantir exactement-une-fois sémantique
- Multi-consumer sur même queue

## Patterns liés

- [Transactional Outbox](./transactional-outbox.md) - Garantit unicité à la source
- [Event Sourcing](../architectural/event-sourcing.md) - Idempotence native
- [Dead Letter Channel](./dead-letter.md) - Messages échoués
