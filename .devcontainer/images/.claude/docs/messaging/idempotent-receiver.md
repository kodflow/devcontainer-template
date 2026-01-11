# Idempotent Receiver Pattern

Garantir un traitement unique malgre les messages dupliques.

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

```typescript
interface IdempotencyStore {
  exists(messageId: string): Promise<boolean>;
  mark(messageId: string, ttlSeconds?: number): Promise<void>;
  getResult(messageId: string): Promise<unknown | null>;
  storeResult(messageId: string, result: unknown, ttlSeconds?: number): Promise<void>;
}

class IdempotentReceiver<TMessage, TResult> {
  constructor(
    private store: IdempotencyStore,
    private handler: (message: TMessage) => Promise<TResult>,
    private idExtractor: (message: TMessage) => string,
    private ttlSeconds: number = 86400 // 24 heures
  ) {}

  async handle(message: TMessage): Promise<TResult> {
    const messageId = this.idExtractor(message);

    // Verifier si deja traite
    const existingResult = await this.store.getResult(messageId);
    if (existingResult !== null) {
      console.log(`Message ${messageId} already processed, returning cached result`);
      return existingResult as TResult;
    }

    // Marquer comme en cours (pour eviter traitement concurrent)
    const acquired = await this.tryAcquireLock(messageId);
    if (!acquired) {
      // Un autre worker traite ce message
      throw new ConcurrentProcessingError(messageId);
    }

    try {
      // Traiter le message
      const result = await this.handler(message);

      // Stocker le resultat
      await this.store.storeResult(messageId, result, this.ttlSeconds);

      return result;
    } catch (error) {
      // En cas d'erreur, liberer le lock pour permettre retry
      await this.releaseLock(messageId);
      throw error;
    }
  }

  private async tryAcquireLock(messageId: string): Promise<boolean> {
    // Implementation avec Redis SETNX ou similar
    return this.store.mark(messageId);
  }

  private async releaseLock(messageId: string): Promise<void> {
    // Liberer le lock
  }
}
```

---

## Implementation Redis

```typescript
class RedisIdempotencyStore implements IdempotencyStore {
  constructor(private redis: Redis) {}

  async exists(messageId: string): Promise<boolean> {
    const key = this.getKey(messageId);
    return (await this.redis.exists(key)) === 1;
  }

  async mark(messageId: string, ttlSeconds: number = 86400): Promise<boolean> {
    const key = this.getKey(messageId);
    // SETNX retourne 1 si la cle n'existait pas
    const result = await this.redis.set(key, 'processing', 'EX', ttlSeconds, 'NX');
    return result === 'OK';
  }

  async getResult(messageId: string): Promise<unknown | null> {
    const key = this.getResultKey(messageId);
    const result = await this.redis.get(key);
    return result ? JSON.parse(result) : null;
  }

  async storeResult(
    messageId: string,
    result: unknown,
    ttlSeconds: number = 86400
  ): Promise<void> {
    const processingKey = this.getKey(messageId);
    const resultKey = this.getResultKey(messageId);

    // Transaction atomique
    await this.redis
      .multi()
      .set(resultKey, JSON.stringify(result), 'EX', ttlSeconds)
      .set(processingKey, 'completed', 'EX', ttlSeconds)
      .exec();
  }

  private getKey(messageId: string): string {
    return `idempotency:${messageId}`;
  }

  private getResultKey(messageId: string): string {
    return `idempotency:result:${messageId}`;
  }
}

// Usage
const store = new RedisIdempotencyStore(redis);
const receiver = new IdempotentReceiver(
  store,
  processOrder,
  (order) => order.orderId,
  3600 // 1 heure TTL
);

await receiver.handle(orderMessage);
```

---

## Implementation PostgreSQL

```typescript
class PostgresIdempotencyStore implements IdempotencyStore {
  constructor(private db: Pool) {}

  async exists(messageId: string): Promise<boolean> {
    const result = await this.db.query(
      `SELECT 1 FROM processed_messages WHERE message_id = $1`,
      [messageId]
    );
    return result.rows.length > 0;
  }

  async mark(messageId: string, ttlSeconds?: number): Promise<boolean> {
    try {
      await this.db.query(
        `INSERT INTO processed_messages (message_id, status, created_at, expires_at)
         VALUES ($1, 'processing', NOW(), NOW() + INTERVAL '${ttlSeconds} seconds')`,
        [messageId]
      );
      return true;
    } catch (error) {
      // Unique constraint violation = deja traite
      if ((error as { code: string }).code === '23505') {
        return false;
      }
      throw error;
    }
  }

  async storeResult(
    messageId: string,
    result: unknown,
    ttlSeconds?: number
  ): Promise<void> {
    await this.db.query(
      `UPDATE processed_messages
       SET status = 'completed', result = $2, completed_at = NOW(),
           expires_at = NOW() + INTERVAL '${ttlSeconds} seconds'
       WHERE message_id = $1`,
      [messageId, JSON.stringify(result)]
    );
  }

  async getResult(messageId: string): Promise<unknown | null> {
    const result = await this.db.query(
      `SELECT result FROM processed_messages
       WHERE message_id = $1 AND status = 'completed'`,
      [messageId]
    );
    return result.rows[0]?.result ?? null;
  }

  // Cleanup des entrees expirees
  async cleanup(): Promise<number> {
    const result = await this.db.query(
      `DELETE FROM processed_messages WHERE expires_at < NOW()`
    );
    return result.rowCount ?? 0;
  }
}

// Schema SQL
/*
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

```typescript
// 1. ID fourni par le producer
interface MessageWithId {
  messageId: string;
  payload: unknown;
}

// 2. Hash du contenu (content-based dedup)
function generateContentHash(message: unknown): string {
  const content = JSON.stringify(message);
  return crypto.createHash('sha256').update(content).digest('hex');
}

// 3. Composite key
function generateCompositeId(message: OrderMessage): string {
  return `${message.customerId}:${message.orderId}:${message.timestamp}`;
}

// 4. Idempotency key fourni par le client
class IdempotentApiHandler {
  async handleRequest(
    request: Request,
    handler: () => Promise<Response>
  ): Promise<Response> {
    const idempotencyKey = request.headers.get('Idempotency-Key');

    if (!idempotencyKey) {
      return handler();
    }

    const cached = await this.store.getResult(idempotencyKey);
    if (cached) {
      return cached as Response;
    }

    const response = await handler();
    await this.store.storeResult(idempotencyKey, response, 3600);
    return response;
  }
}
```

---

## Avec RabbitMQ/Kafka

```typescript
// RabbitMQ consumer idempotent
class IdempotentRabbitMQConsumer {
  async consume(queue: string): Promise<void> {
    await this.channel.consume(queue, async (msg) => {
      if (!msg) return;

      const messageId = msg.properties.messageId ||
                        msg.properties.headers['x-message-id'] ||
                        this.generateId(msg.content);

      const idempotentHandler = new IdempotentReceiver(
        this.store,
        this.handler,
        () => messageId
      );

      try {
        await idempotentHandler.handle(JSON.parse(msg.content.toString()));
        this.channel.ack(msg);
      } catch (error) {
        if (error instanceof ConcurrentProcessingError) {
          // Requeue pour retry plus tard
          this.channel.nack(msg, false, true);
        } else {
          // DLQ ou ack selon la politique
          this.channel.nack(msg, false, false);
        }
      }
    });
  }
}

// Kafka avec deduplication
class IdempotentKafkaConsumer {
  async consume(): Promise<void> {
    await this.consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        // Kafka fournit un ID unique: topic + partition + offset
        const messageId = `${topic}:${partition}:${message.offset}`;

        // Ou utiliser une cle metier
        const businessId = message.headers['x-idempotency-key']?.toString() ||
                          message.key?.toString();

        const receiver = new IdempotentReceiver(
          this.store,
          this.handler,
          () => businessId || messageId
        );

        await receiver.handle(JSON.parse(message.value!.toString()));
      },
    });
  }
}
```

---

## Cas d'erreur

```typescript
class RobustIdempotentReceiver<T, R> extends IdempotentReceiver<T, R> {
  async handle(message: T): Promise<R> {
    const messageId = this.idExtractor(message);

    try {
      // Verifier store disponible
      await this.store.ping();
    } catch (storeError) {
      // Store indisponible - decision critique
      if (this.config.failOpenOnStoreError) {
        // Traiter quand meme (risque de duplicate)
        console.warn('Idempotency store unavailable, processing anyway');
        return this.handler(message);
      } else {
        // Refuser le traitement
        throw new StoreUnavailableError();
      }
    }

    return super.handle(message);
  }
}

// Cleanup automatique
class IdempotencyCleanupJob {
  @Scheduled('0 0 * * *') // Chaque jour a minuit
  async cleanup(): Promise<void> {
    const deleted = await this.store.cleanup();
    console.log(`Cleaned up ${deleted} expired idempotency records`);
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

## Patterns complementaires

- **At-least-once Delivery** - Necessite idempotence
- **Transactional Outbox** - Garantit unicite a la source
- **Deduplication** - Niveau broker
- **Event Sourcing** - Idempotence native
