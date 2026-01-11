# Transactional Outbox Pattern

Garantir la fiabilite des messages avec les transactions de base de donnees.

## Vue d'ensemble

```
+------------------+
|   Application    |
+--------+---------+
         |
         | BEGIN TRANSACTION
         |
         v
+--------+---------+     +----------------+
|    Database      |     |   Outbox       |
|                  |     |   Table        |
| INSERT order     |     | INSERT message |
| UPDATE inventory |     |                |
+--------+---------+     +-------+--------+
         |                       |
         | COMMIT                |
         |                       v
         |              +--------+--------+
         |              | Outbox Relay    |
         |              | (Poll/CDC)      |
         +------------->+--------+--------+
                                 |
                                 v
                        +--------+--------+
                        | Message Broker  |
                        | (RabbitMQ/Kafka)|
                        +-----------------+
```

---

## Probleme resolu

```
SANS OUTBOX (probleme du dual write):

Transaction 1: UPDATE order SET status='paid'  --> OK
Transaction 2: PUBLISH OrderPaid event         --> FAIL

Resultat: DB mise a jour, mais message perdu!

AVEC OUTBOX:

Transaction atomique:
  - UPDATE order SET status='paid'
  - INSERT INTO outbox (event_type, payload)
COMMIT

Relay separee publie le message --> Fiable!
```

---

## Implementation de base

### Schema de table Outbox

```sql
CREATE TABLE outbox (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aggregate_type VARCHAR(100) NOT NULL,
  aggregate_id VARCHAR(100) NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  payload JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  published_at TIMESTAMP NULL,
  retry_count INT NOT NULL DEFAULT 0,
  last_error TEXT NULL,

  INDEX idx_outbox_unpublished (published_at) WHERE published_at IS NULL
);
```

### Application Layer

```typescript
interface OutboxMessage {
  aggregateType: string;
  aggregateId: string;
  eventType: string;
  payload: unknown;
}

class OutboxRepository {
  constructor(private db: Pool) {}

  async saveMessage(
    message: OutboxMessage,
    client?: PoolClient
  ): Promise<void> {
    const conn = client || this.db;
    await conn.query(
      `INSERT INTO outbox (aggregate_type, aggregate_id, event_type, payload)
       VALUES ($1, $2, $3, $4)`,
      [
        message.aggregateType,
        message.aggregateId,
        message.eventType,
        JSON.stringify(message.payload),
      ]
    );
  }

  async getUnpublished(limit: number = 100): Promise<OutboxRow[]> {
    const result = await this.db.query(
      `SELECT * FROM outbox
       WHERE published_at IS NULL
       ORDER BY created_at ASC
       LIMIT $1
       FOR UPDATE SKIP LOCKED`,
      [limit]
    );
    return result.rows;
  }

  async markAsPublished(id: string): Promise<void> {
    await this.db.query(
      `UPDATE outbox SET published_at = NOW() WHERE id = $1`,
      [id]
    );
  }

  async markAsFailed(id: string, error: string): Promise<void> {
    await this.db.query(
      `UPDATE outbox
       SET retry_count = retry_count + 1, last_error = $2
       WHERE id = $1`,
      [id, error]
    );
  }
}

// Usage dans le service
class OrderService {
  async placeOrder(orderData: OrderData): Promise<Order> {
    const client = await this.db.connect();

    try {
      await client.query('BEGIN');

      // 1. Creer la commande
      const order = await this.orderRepository.create(orderData, client);

      // 2. Ajouter l'evenement dans l'outbox (meme transaction)
      await this.outboxRepository.saveMessage({
        aggregateType: 'Order',
        aggregateId: order.id,
        eventType: 'OrderCreated',
        payload: {
          orderId: order.id,
          customerId: order.customerId,
          total: order.total,
          items: order.items,
        },
      }, client);

      await client.query('COMMIT');
      return order;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}
```

---

## Outbox Relay (Polling)

```typescript
class OutboxRelay {
  private running = false;
  private pollInterval = 1000;

  constructor(
    private outboxRepo: OutboxRepository,
    private messageBroker: MessageBroker
  ) {}

  async start(): Promise<void> {
    this.running = true;
    await this.poll();
  }

  stop(): void {
    this.running = false;
  }

  private async poll(): Promise<void> {
    while (this.running) {
      try {
        const messages = await this.outboxRepo.getUnpublished(100);

        for (const message of messages) {
          await this.processMessage(message);
        }

        if (messages.length === 0) {
          await this.delay(this.pollInterval);
        }
      } catch (error) {
        console.error('Outbox relay error:', error);
        await this.delay(this.pollInterval * 2);
      }
    }
  }

  private async processMessage(message: OutboxRow): Promise<void> {
    try {
      await this.messageBroker.publish(
        this.getTopicForEvent(message.event_type),
        {
          id: message.id,
          type: message.event_type,
          aggregateId: message.aggregate_id,
          payload: message.payload,
          timestamp: message.created_at,
        }
      );

      await this.outboxRepo.markAsPublished(message.id);
    } catch (error) {
      await this.outboxRepo.markAsFailed(message.id, (error as Error).message);
    }
  }

  private getTopicForEvent(eventType: string): string {
    const topicMap: Record<string, string> = {
      'OrderCreated': 'orders.created',
      'OrderShipped': 'orders.shipped',
      'PaymentReceived': 'payments.received',
    };
    return topicMap[eventType] || 'events.default';
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
```

---

## Outbox Relay (CDC - Change Data Capture)

```typescript
// Avec Debezium pour PostgreSQL
/*
Debezium capture les INSERT sur la table outbox
et les publie directement vers Kafka.

Configuration Debezium:
{
  "name": "outbox-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "db",
    "database.port": "5432",
    "database.user": "app",
    "database.password": "***",
    "database.dbname": "orders",
    "table.include.list": "public.outbox",
    "transforms": "outbox",
    "transforms.outbox.type": "io.debezium.transforms.outbox.EventRouter",
    "transforms.outbox.table.field.event.key": "aggregate_id",
    "transforms.outbox.table.field.event.type": "event_type",
    "transforms.outbox.table.field.event.payload": "payload"
  }
}
*/

// Consumer cote application
class DebeziumOutboxConsumer {
  async consume(): Promise<void> {
    await this.kafkaConsumer.subscribe({ topic: 'outbox.events' });

    await this.kafkaConsumer.run({
      eachMessage: async ({ message }) => {
        const event = JSON.parse(message.value!.toString());

        // Debezium formate l'evenement avec before/after
        const payload = event.after;

        await this.eventHandler.handle({
          type: payload.event_type,
          aggregateId: payload.aggregate_id,
          payload: JSON.parse(payload.payload),
        });
      },
    });
  }
}
```

---

## Outbox avec Cleanup

```typescript
class OutboxCleaner {
  constructor(
    private db: Pool,
    private retentionDays: number = 7
  ) {}

  // Executer periodiquement (cron)
  async cleanup(): Promise<number> {
    const result = await this.db.query(
      `DELETE FROM outbox
       WHERE published_at IS NOT NULL
       AND published_at < NOW() - INTERVAL '${this.retentionDays} days'`
    );

    return result.rowCount ?? 0;
  }

  // Archiver avant suppression (optionnel)
  async archiveAndCleanup(): Promise<void> {
    await this.db.query(`
      WITH archived AS (
        INSERT INTO outbox_archive
        SELECT * FROM outbox
        WHERE published_at IS NOT NULL
        AND published_at < NOW() - INTERVAL '${this.retentionDays} days'
        RETURNING id
      )
      DELETE FROM outbox WHERE id IN (SELECT id FROM archived)
    `);
  }
}
```

---

## Gestion des echecs

```typescript
class RobustOutboxRelay extends OutboxRelay {
  private maxRetries = 5;

  async processMessage(message: OutboxRow): Promise<void> {
    if (message.retry_count >= this.maxRetries) {
      await this.moveToDeadLetter(message);
      await this.outboxRepo.markAsPublished(message.id); // Retirer de l'outbox
      return;
    }

    // Backoff exponentiel
    if (message.retry_count > 0) {
      const backoff = Math.pow(2, message.retry_count) * 1000;
      const timeSinceLastRetry = Date.now() - new Date(message.created_at).getTime();
      if (timeSinceLastRetry < backoff) {
        return; // Pas encore temps de retry
      }
    }

    try {
      await this.messageBroker.publish(
        this.getTopicForEvent(message.event_type),
        this.formatMessage(message)
      );
      await this.outboxRepo.markAsPublished(message.id);
    } catch (error) {
      await this.outboxRepo.markAsFailed(message.id, (error as Error).message);

      if (message.retry_count >= this.maxRetries - 1) {
        await this.alertService.warn('Outbox message max retries', {
          messageId: message.id,
          eventType: message.event_type,
        });
      }
    }
  }

  private async moveToDeadLetter(message: OutboxRow): Promise<void> {
    await this.db.query(
      `INSERT INTO outbox_dead_letter
       SELECT *, NOW() as moved_at FROM outbox WHERE id = $1`,
      [message.id]
    );
  }
}
```

---

## Ordering et Partitioning

```typescript
class OrderedOutboxRelay {
  async processMessages(): Promise<void> {
    // Grouper par aggregate pour maintenir l'ordre
    const messages = await this.db.query(`
      SELECT DISTINCT ON (aggregate_id) *
      FROM outbox
      WHERE published_at IS NULL
      ORDER BY aggregate_id, created_at ASC
    `);

    // Traiter en parallele par aggregate, sequentiel dans l'aggregate
    const byAggregate = this.groupByAggregate(messages.rows);

    await Promise.all(
      Object.entries(byAggregate).map(([aggregateId, msgs]) =>
        this.processAggregateMessages(aggregateId, msgs)
      )
    );
  }

  private async processAggregateMessages(
    aggregateId: string,
    messages: OutboxRow[]
  ): Promise<void> {
    // Sequentiel pour maintenir l'ordre
    for (const message of messages) {
      await this.processMessage(message);
    }
  }
}
```

---

## Patterns complementaires

- **Idempotent Receiver** - Cote consumer
- **Event Sourcing** - Alternative complete
- **Saga** - Transactions distribuees
- **Dead Letter Channel** - Messages echoues
