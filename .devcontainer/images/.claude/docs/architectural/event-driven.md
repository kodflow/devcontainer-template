# Event-Driven Architecture

> Architecture où les composants communiquent via des événements asynchrones.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│               SYNCHRONE vs EVENT-DRIVEN                          │
│                                                                  │
│  SYNCHRONE (Request/Response)     EVENT-DRIVEN                  │
│  ┌──────┐  request  ┌──────┐     ┌──────┐   ┌─────────┐        │
│  │  A   │──────────►│  B   │     │  A   │──►│  Event  │        │
│  │      │◄──────────│      │     │      │   │  Bus    │        │
│  └──────┘  response └──────┘     └──────┘   └────┬────┘        │
│                                                   │              │
│  A attend B                            ┌─────────┼─────────┐    │
│  Couplage fort                         ▼         ▼         ▼    │
│                                    ┌──────┐ ┌──────┐ ┌──────┐  │
│                                    │  B   │ │  C   │ │  D   │  │
│                                    └──────┘ └──────┘ └──────┘  │
│                                    A ne connaît pas B, C, D     │
└─────────────────────────────────────────────────────────────────┘
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   EVENT-DRIVEN ARCHITECTURE                      │
│                                                                  │
│  ┌─────────────┐     ┌─────────────────────────────────────┐   │
│  │  Producer   │────►│           EVENT BROKER              │   │
│  │  (Order)    │     │         (Kafka / RabbitMQ)          │   │
│  └─────────────┘     │                                     │   │
│                      │   ┌───────────────────────────────┐ │   │
│  ┌─────────────┐     │   │         TOPICS/QUEUES         │ │   │
│  │  Producer   │────►│   │  ┌───────┐ ┌───────┐ ┌─────┐  │ │   │
│  │  (Payment)  │     │   │  │orders │ │payment│ │ship │  │ │   │
│  └─────────────┘     │   │  └───────┘ └───────┘ └─────┘  │ │   │
│                      │   └───────────────────────────────┘ │   │
│                      └───────────────┬─────────────────────┘   │
│                                      │                          │
│              ┌───────────────────────┼───────────────────┐     │
│              │                       │                   │     │
│              ▼                       ▼                   ▼     │
│     ┌─────────────┐         ┌─────────────┐     ┌───────────┐ │
│     │  Consumer   │         │  Consumer   │     │ Consumer  │ │
│     │  (Email)    │         │ (Analytics) │     │ (Inventory│ │
│     └─────────────┘         └─────────────┘     └───────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Types d'événements

### Domain Events

```go
package events

import "time"

// OrderItem represents an item in an order.
type OrderItem struct {
	ProductID string
	Quantity  int
	Price     float64
}

// EventMetadata contains event metadata.
type EventMetadata struct {
	Timestamp     time.Time
	CorrelationID string
	CausationID   string
}

// OrderCreatedEvent represents an order creation event.
type OrderCreatedEvent struct {
	Type          string `json:"type"` // "order.created"
	OrderID       string
	CustomerID    string
	Items         []OrderItem
	Total         float64
	Metadata      EventMetadata
}

// PaymentCompletedEvent represents a payment completion event.
type PaymentCompletedEvent struct {
	Type      string `json:"type"` // "payment.completed"
	PaymentID string
	OrderID   string
	Amount    float64
	Method    string
}
```

### Integration Events

```go
package events

// CustomerCreatedIntegrationEvent represents a customer creation event between services.
type CustomerCreatedIntegrationEvent struct {
	Type       string `json:"type"` // "integration.customer.created"
	CustomerID string
	Email      string
	Name       string
	Source     string // "customer-service"
	Version    string // "1.0"
}
```

### Commands vs Events

```go
package commands

// CreateOrderCommand represents an intention to create an order (can fail).
type CreateOrderCommand struct {
	Type       string `json:"type"` // "CreateOrder"
	CustomerID string
	Items      []OrderItem
}

// OrderCreatedEvent represents a past fact (immutable).
type OrderCreatedEvent struct {
	Type       string `json:"type"` // "OrderCreated"
	OrderID    string
	CustomerID string
	Items      []OrderItem
	CreatedAt  time.Time
}
```

## Implémentation avec Kafka

```go
package kafka

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/segmentio/kafka-go"
)

// DomainEvent is the interface for all domain events.
type DomainEvent interface {
	GetType() string
	GetAggregateID() string
	GetMetadata() EventMetadata
}

// EventPublisher publishes events to Kafka.
type EventPublisher struct {
	writer *kafka.Writer
}

// NewEventPublisher creates a new event publisher.
func NewEventPublisher(brokers []string, clientID string) *EventPublisher {
	return &EventPublisher{
		writer: &kafka.Writer{
			Addr:     kafka.TCP(brokers...),
			Balancer: &kafka.LeastBytes{},
		},
	}
}

// Publish publishes an event to Kafka.
func (p *EventPublisher) Publish(ctx context.Context, event DomainEvent) error {
	value, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("marshaling event: %w", err)
	}

	// Extract topic from event type: "order.created" -> "order"
	topic := strings.Split(event.GetType(), ".")[0]

	msg := kafka.Message{
		Topic: topic,
		Key:   []byte(event.GetAggregateID()),
		Value: value,
		Headers: []kafka.Header{
			{Key: "event-type", Value: []byte(event.GetType())},
			{Key: "correlation-id", Value: []byte(event.GetMetadata().CorrelationID)},
			{Key: "timestamp", Value: []byte(event.GetMetadata().Timestamp.Format(time.RFC3339))},
		},
	}

	if err := p.writer.WriteMessages(ctx, msg); err != nil {
		return fmt.Errorf("writing message: %w", err)
	}

	return nil
}

// Close closes the publisher.
func (p *EventPublisher) Close() error {
	return p.writer.Close()
}

// EventHandler handles domain events.
type EventHandler func(context.Context, DomainEvent) error

// EventSubscriber subscribes to events from Kafka.
type EventSubscriber struct {
	reader *kafka.Reader
}

// NewEventSubscriber creates a new event subscriber.
func NewEventSubscriber(brokers []string, topic, groupID string) *EventSubscriber {
	return &EventSubscriber{
		reader: kafka.NewReader(kafka.ReaderConfig{
			Brokers:  brokers,
			Topic:    topic,
			GroupID:  groupID,
			MinBytes: 10e3, // 10KB
			MaxBytes: 10e6, // 10MB
		}),
	}
}

// Subscribe subscribes to events and processes them with the handler.
func (s *EventSubscriber) Subscribe(ctx context.Context, handler EventHandler) error {
	for {
		msg, err := s.reader.FetchMessage(ctx)
		if err != nil {
			return fmt.Errorf("fetching message: %w", err)
		}

		var event DomainEvent
		if err := json.Unmarshal(msg.Value, &event); err != nil {
			if handleErr := s.handleError(ctx, event, err); handleErr != nil {
				return fmt.Errorf("handling unmarshal error: %w", handleErr)
			}
			continue
		}

		if err := handler(ctx, event); err != nil {
			if handleErr := s.handleError(ctx, event, err); handleErr != nil {
				return fmt.Errorf("handling processing error: %w", handleErr)
			}
			continue
		}

		if err := s.reader.CommitMessages(ctx, msg); err != nil {
			return fmt.Errorf("committing message: %w", err)
		}
	}
}

// handleError sends failed events to dead letter queue.
func (s *EventSubscriber) handleError(ctx context.Context, event DomainEvent, err error) error {
	// Log error
	fmt.Printf("Failed to process %s: %v\n", event.GetType(), err)

	// Send to DLQ (dead letter queue)
	// Implementation omitted for brevity

	return nil
}

// Close closes the subscriber.
func (s *EventSubscriber) Close() error {
	return s.reader.Close()
}
```

## Patterns Event-Driven

### Choreography

```
┌────────┐   OrderCreated   ┌────────┐
│ Order  │─────────────────►│Payment │
│Service │                  │Service │
└────────┘                  └────────┘
                                │
                        PaymentComplete
                                │
    ┌───────────────────────────┼────────────────────────┐
    ▼                           ▼                        ▼
┌────────┐              ┌────────┐                ┌────────┐
│Shipping│              │ Email  │                │Inventory
│Service │              │Service │                │Service │
└────────┘              └────────┘                └────────┘

Décentralisé, pas de coordinateur
```

### Orchestration

```
┌────────────────────────────────────────┐
│            ORDER SAGA                   │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │         Orchestrator             │  │
│  │                                  │  │
│  │  1. CreateOrder                  │  │
│  │  2. ReserveInventory             │  │
│  │  3. ProcessPayment               │  │
│  │  4. ShipOrder                    │  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│       │         │           │          │
│       ▼         ▼           ▼          │
│  ┌────────┐ ┌────────┐ ┌────────┐     │
│  │Order   │ │Inventory│ │Payment │     │
│  │Service │ │Service  │ │Service │     │
│  └────────┘ └────────┘ └────────┘     │
└────────────────────────────────────────┘

Centralisé, logique dans orchestrator
```

### Event Sourcing + Event-Driven

```
┌──────────────────────────────────────────────────────────────┐
│                                                               │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐   │
│  │ Command  │───►│Aggregate │───►│    Event Store       │   │
│  └──────────┘    └──────────┘    └──────────────────────┘   │
│                                           │                   │
│                                           │ Publish           │
│                                           ▼                   │
│                                  ┌──────────────────────┐    │
│                                  │    Event Bus         │    │
│                                  └──────────────────────┘    │
│                                           │                   │
│              ┌────────────────────────────┼──────────────┐   │
│              ▼                            ▼              ▼   │
│       ┌──────────┐               ┌──────────┐    ┌──────────┐
│       │Projection│               │ Notifier │    │Analytics │
│       └──────────┘               └──────────┘    └──────────┘
└──────────────────────────────────────────────────────────────┘
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Découplage requis | Transactions ACID simples |
| Haute disponibilité | Faible latence critique |
| Scale horizontal | Petite équipe |
| Résilience | Pas besoin asynchrone |
| Intégrations multiples | Flux linéaire simple |

## Avantages

- **Découplage** : Services indépendants
- **Scalabilité** : Consumers parallèles
- **Résilience** : Pannes isolées
- **Extensibilité** : Ajouter consumers sans modifier producer
- **Audit** : Log centralisé d'événements
- **Replay** : Rejouer les événements

## Inconvénients

- **Complexité** : Debug difficile
- **Eventual consistency** : Pas de ACID
- **Ordre** : Garantir l'ordre peut être complexe
- **Monitoring** : Observabilité nécessaire
- **Idempotency** : Gérer les doublons

## Exemples réels

| Entreprise | Usage |
|------------|-------|
| **LinkedIn** | Kafka (backbone) |
| **Uber** | Events pour matching |
| **Netflix** | Event-driven microservices |
| **Airbnb** | Real-time notifications |
| **Twitter** | Timeline updates |

## Migration path

### Depuis Synchrone

```
Phase 1: Identifier bounded contexts
Phase 2: Ajouter broker (Kafka/RabbitMQ)
Phase 3: Dual-write (sync + async)
Phase 4: Migrer vers async
Phase 5: Supprimer appels synchrones
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Event Sourcing | Events persistés |
| CQRS | Séparation read/write |
| Saga | Transactions distribuées |
| Circuit Breaker | Résilience consumers |

## Sources

- [Martin Fowler - Event-Driven](https://martinfowler.com/articles/201701-event-driven.html)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Enterprise Integration Patterns](https://www.enterpriseintegrationpatterns.com/)
