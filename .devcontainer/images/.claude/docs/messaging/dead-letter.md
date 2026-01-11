# Dead Letter Channel Pattern

Gestion des messages non traitables.

## Vue d'ensemble

```
+----------+     +-------------+     +-----------+
| Producer |---->|    Queue    |---->| Consumer  |
+----------+     +------+------+     +-----+-----+
                        |                  |
                        |            FAIL (x3)
                        |                  |
                        v                  v
                 +------+------+    +------+------+
                 |   Expired   |    |   Rejected  |
                 +------+------+    +------+------+
                        |                  |
                        +--------+---------+
                                 |
                                 v
                        +--------+--------+
                        | Dead Letter Queue|
                        |   (DLQ)          |
                        +--------+--------+
                                 |
                                 v
                        +--------+--------+
                        | DLQ Consumer    |
                        | - Alert         |
                        | - Log           |
                        | - Retry         |
                        | - Archive       |
                        +-----------------+
```

---

## Implementation de base

```typescript
interface DeadLetterMessage {
  id: string;
  originalQueue: string;
  originalMessage: unknown;
  error: {
    name: string;
    message: string;
    stack?: string;
  };
  attempts: number;
  firstFailedAt: Date;
  lastFailedAt: Date;
  headers: Record<string, string>;
}

class DeadLetterChannel {
  constructor(
    private dlq: MessageQueue,
    private alertService: AlertService
  ) {}

  async send(
    originalQueue: string,
    message: unknown,
    error: Error,
    attempts: number
  ): Promise<void> {
    const dlMessage: DeadLetterMessage = {
      id: crypto.randomUUID(),
      originalQueue,
      originalMessage: message,
      error: {
        name: error.name,
        message: error.message,
        stack: error.stack,
      },
      attempts,
      firstFailedAt: new Date(),
      lastFailedAt: new Date(),
      headers: this.extractHeaders(message),
    };

    await this.dlq.send('dead-letter-queue', dlMessage);

    // Alerter si erreur critique
    if (this.isCriticalError(error)) {
      await this.alertService.critical('Message moved to DLQ', {
        queue: originalQueue,
        error: error.message,
        messageId: dlMessage.id,
      });
    }
  }

  private isCriticalError(error: Error): boolean {
    return error instanceof PaymentError ||
           error instanceof DataCorruptionError ||
           error instanceof SecurityError;
  }

  private extractHeaders(message: unknown): Record<string, string> {
    if (typeof message === 'object' && message !== null && 'headers' in message) {
      return (message as { headers: Record<string, string> }).headers;
    }
    return {};
  }
}
```

---

## Consumer avec retry et DLQ

```typescript
interface RetryConfig {
  maxRetries: number;
  backoffMultiplier: number;
  initialDelayMs: number;
  maxDelayMs: number;
}

class ResilientConsumer {
  private retryConfig: RetryConfig = {
    maxRetries: 3,
    backoffMultiplier: 2,
    initialDelayMs: 1000,
    maxDelayMs: 30000,
  };

  constructor(
    private queue: MessageQueue,
    private handler: (msg: unknown) => Promise<void>,
    private deadLetter: DeadLetterChannel
  ) {}

  async consume(): Promise<void> {
    await this.queue.subscribe(async (message, meta) => {
      const attempts = meta.headers['x-retry-count'] ?? 0;

      try {
        await this.handler(message);
        await this.queue.ack(message);
      } catch (error) {
        if (attempts >= this.retryConfig.maxRetries) {
          // Max retries atteint -> DLQ
          await this.deadLetter.send(
            meta.queue,
            message,
            error as Error,
            attempts
          );
          await this.queue.ack(message); // Retirer de la queue principale
        } else {
          // Requeue avec delay
          const delay = this.calculateDelay(attempts);
          await this.requeueWithDelay(message, attempts + 1, delay);
          await this.queue.ack(message);
        }
      }
    });
  }

  private calculateDelay(attempts: number): number {
    const delay = this.retryConfig.initialDelayMs *
                  Math.pow(this.retryConfig.backoffMultiplier, attempts);
    return Math.min(delay, this.retryConfig.maxDelayMs);
  }

  private async requeueWithDelay(
    message: unknown,
    attempts: number,
    delayMs: number
  ): Promise<void> {
    // Utiliser un delayed exchange ou scheduler
    await this.queue.sendDelayed(message, delayMs, {
      'x-retry-count': attempts,
    });
  }
}
```

---

## RabbitMQ Dead Letter Configuration

```typescript
// Configuration RabbitMQ avec DLX
class RabbitMQDeadLetterSetup {
  async setup(): Promise<void> {
    // Dead Letter Exchange
    await this.channel.assertExchange('dlx', 'direct', { durable: true });

    // Dead Letter Queue
    await this.channel.assertQueue('dead-letter-queue', {
      durable: true,
      arguments: {
        'x-message-ttl': 7 * 24 * 60 * 60 * 1000, // 7 jours
      },
    });
    await this.channel.bindQueue('dead-letter-queue', 'dlx', 'dead-letter');

    // Queue principale avec DLX configure
    await this.channel.assertQueue('orders', {
      durable: true,
      arguments: {
        'x-dead-letter-exchange': 'dlx',
        'x-dead-letter-routing-key': 'dead-letter',
      },
    });
  }

  // Consumer sur la DLQ
  async consumeDeadLetters(): Promise<void> {
    await this.channel.consume('dead-letter-queue', async (msg) => {
      if (!msg) return;

      const deathInfo = msg.properties.headers['x-death'];
      const dlMessage = {
        content: JSON.parse(msg.content.toString()),
        originalQueue: deathInfo?.[0]?.queue,
        reason: deathInfo?.[0]?.reason, // rejected, expired, maxlen
        count: deathInfo?.[0]?.count,
        firstDeathTime: deathInfo?.[0]?.time,
      };

      await this.processDLQMessage(dlMessage);
      this.channel.ack(msg);
    });
  }
}
```

---

## Kafka DLQ Pattern

```typescript
class KafkaDeadLetterHandler {
  private dlqTopic: string;

  constructor(
    private producer: KafkaProducer,
    mainTopic: string
  ) {
    this.dlqTopic = `${mainTopic}.dlq`;
  }

  async sendToDLQ(
    message: KafkaMessage,
    error: Error,
    partition: number,
    offset: string
  ): Promise<void> {
    await this.producer.send({
      topic: this.dlqTopic,
      messages: [{
        key: message.key,
        value: message.value,
        headers: {
          ...message.headers,
          'x-original-topic': message.topic,
          'x-original-partition': String(partition),
          'x-original-offset': offset,
          'x-error-message': error.message,
          'x-error-type': error.name,
          'x-failed-at': new Date().toISOString(),
        },
      }],
    });
  }

  // Consumer avec auto-DLQ
  async consumeWithDLQ(
    topic: string,
    handler: (msg: unknown) => Promise<void>
  ): Promise<void> {
    await this.consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const payload = JSON.parse(message.value!.toString());
          await handler(payload);
        } catch (error) {
          await this.sendToDLQ(
            { ...message, topic },
            error as Error,
            partition,
            message.offset
          );
        }
      },
    });
  }
}
```

---

## DLQ Consumer et Remediation

```typescript
class DLQRemediator {
  constructor(
    private dlqConsumer: MessageQueue,
    private originalQueues: Map<string, MessageQueue>,
    private archiveStore: ArchiveStore
  ) {}

  async processDeadLetters(): Promise<void> {
    await this.dlqConsumer.subscribe(async (dlMessage: DeadLetterMessage) => {
      const action = await this.determineAction(dlMessage);

      switch (action) {
        case 'retry':
          await this.retryMessage(dlMessage);
          break;
        case 'fix_and_retry':
          const fixed = await this.fixMessage(dlMessage);
          await this.retryMessage({ ...dlMessage, originalMessage: fixed });
          break;
        case 'archive':
          await this.archiveMessage(dlMessage);
          break;
        case 'discard':
          // Log et supprimer
          console.log('Discarding message:', dlMessage.id);
          break;
      }
    });
  }

  private async determineAction(dlMessage: DeadLetterMessage): Promise<string> {
    // Regles de remediation basees sur l'erreur
    const errorType = dlMessage.error.name;

    if (errorType === 'TransientError' || errorType === 'TimeoutError') {
      return 'retry';
    }
    if (errorType === 'ValidationError') {
      return 'fix_and_retry';
    }
    if (errorType === 'PermanentError') {
      return 'archive';
    }
    if (dlMessage.attempts > 10) {
      return 'archive';
    }

    return 'retry';
  }

  private async retryMessage(dlMessage: DeadLetterMessage): Promise<void> {
    const originalQueue = this.originalQueues.get(dlMessage.originalQueue);
    if (!originalQueue) {
      throw new Error(`Unknown queue: ${dlMessage.originalQueue}`);
    }

    await originalQueue.send(dlMessage.originalMessage, {
      'x-retry-from-dlq': 'true',
      'x-original-failure': dlMessage.error.message,
    });
  }

  private async fixMessage(dlMessage: DeadLetterMessage): Promise<unknown> {
    const message = dlMessage.originalMessage as Record<string, unknown>;

    // Exemples de corrections automatiques
    if (dlMessage.error.message.includes('missing field')) {
      return { ...message, missingField: 'default_value' };
    }
    if (dlMessage.error.message.includes('invalid date')) {
      return { ...message, date: new Date().toISOString() };
    }

    return message;
  }

  private async archiveMessage(dlMessage: DeadLetterMessage): Promise<void> {
    await this.archiveStore.store({
      ...dlMessage,
      archivedAt: new Date(),
    });
  }
}
```

---

## Monitoring et Alerting

```typescript
class DLQMonitor {
  async checkHealth(): Promise<DLQHealth> {
    const queueSize = await this.queue.getMessageCount('dead-letter-queue');
    const oldestMessage = await this.getOldestMessageAge();
    const errorBreakdown = await this.getErrorBreakdown();

    const health: DLQHealth = {
      queueSize,
      oldestMessageAgeMinutes: oldestMessage,
      errorTypes: errorBreakdown,
      status: this.determineStatus(queueSize, oldestMessage),
    };

    if (health.status === 'critical') {
      await this.alertService.critical('DLQ Critical', health);
    } else if (health.status === 'warning') {
      await this.alertService.warning('DLQ Warning', health);
    }

    return health;
  }

  private determineStatus(size: number, ageMinutes: number): string {
    if (size > 1000 || ageMinutes > 60) return 'critical';
    if (size > 100 || ageMinutes > 30) return 'warning';
    return 'healthy';
  }
}
```

---

## Patterns complementaires

- **Retry Pattern** - Avant DLQ
- **Circuit Breaker** - Prevenir surcharge
- **Idempotent Receiver** - Retry safe
- **Process Manager** - Orchestrer remediation
