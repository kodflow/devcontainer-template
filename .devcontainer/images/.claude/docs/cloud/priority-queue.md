# Priority Queue Pattern

> Traiter les messages selon leur priorite plutot que leur ordre d'arrivee.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │              PRIORITY QUEUE                  │
                    └─────────────────────────────────────────────┘

  FIFO Standard:
  ┌───┬───┬───┬───┬───┐
  │ 1 │ 2 │ 3 │ 4 │ 5 │ ──▶ Traitement: 1, 2, 3, 4, 5
  └───┴───┴───┴───┴───┘

  Priority Queue:
  ┌─────────────────────────────────────┐
  │  HIGH   │ ██ ██ ██                  │ ──▶ Traite d'abord
  ├─────────┼───────────────────────────┤
  │  MEDIUM │ ░░ ░░ ░░ ░░ ░░           │ ──▶ Traite ensuite
  ├─────────┼───────────────────────────┤
  │  LOW    │ ▒▒ ▒▒ ▒▒ ▒▒ ▒▒ ▒▒ ▒▒    │ ──▶ Traite en dernier
  └─────────┴───────────────────────────┘

  Implementation:
  ┌──────────┐      ┌─────────────┐      ┌──────────┐
  │ Producer │ ───▶ │  Router     │ ───▶ │ Queue Hi │ ───┐
  └──────────┘      │ (priority)  │      └──────────┘    │
                    │             │      ┌──────────┐    │ ┌──────────┐
                    │             │ ───▶ │ Queue Med│ ───┼▶│ Consumer │
                    │             │      └──────────┘    │ └──────────┘
                    │             │      ┌──────────┐    │
                    │             │ ───▶ │ Queue Low│ ───┘
                    └─────────────┘      └──────────┘
```

## Exemple TypeScript

```typescript
interface Message<T = unknown> {
  id: string;
  priority: 'high' | 'medium' | 'low';
  payload: T;
  createdAt: Date;
  attempts: number;
}

class PriorityQueueService {
  private queues = {
    high: [] as Message[],
    medium: [] as Message[],
    low: [] as Message[],
  };

  private readonly priorityOrder = ['high', 'medium', 'low'] as const;

  enqueue<T>(
    payload: T,
    priority: 'high' | 'medium' | 'low' = 'medium',
  ): string {
    const message: Message<T> = {
      id: crypto.randomUUID(),
      priority,
      payload,
      createdAt: new Date(),
      attempts: 0,
    };

    this.queues[priority].push(message);
    return message.id;
  }

  dequeue(): Message | null {
    // Check queues in priority order
    for (const priority of this.priorityOrder) {
      if (this.queues[priority].length > 0) {
        const message = this.queues[priority].shift()!;
        message.attempts++;
        return message;
      }
    }
    return null;
  }

  // Weighted fair queuing (evite starvation)
  dequeueWeighted(): Message | null {
    const weights = { high: 6, medium: 3, low: 1 }; // 60%, 30%, 10%
    const total = Object.values(weights).reduce((a, b) => a + b, 0);
    const random = Math.random() * total;

    let cumulative = 0;
    for (const priority of this.priorityOrder) {
      cumulative += weights[priority];
      if (random < cumulative && this.queues[priority].length > 0) {
        const message = this.queues[priority].shift()!;
        message.attempts++;
        return message;
      }
    }

    // Fallback: any available message
    return this.dequeue();
  }

  getStats(): Record<string, number> {
    return {
      high: this.queues.high.length,
      medium: this.queues.medium.length,
      low: this.queues.low.length,
    };
  }
}
```

## Implementation avec Redis

```typescript
class RedisPriorityQueue {
  private readonly queuePrefix = 'pqueue';

  constructor(private redis: Redis) {}

  async enqueue(
    queueName: string,
    message: unknown,
    priority: number = 5,
  ): Promise<void> {
    // ZADD avec score inverse (plus petit = plus prioritaire)
    const score = priority * 1_000_000_000 + Date.now();
    await this.redis.zadd(
      `${this.queuePrefix}:${queueName}`,
      score,
      JSON.stringify(message),
    );
  }

  async dequeue(queueName: string): Promise<unknown | null> {
    // ZPOPMIN: retire et retourne l'element avec le plus petit score
    const result = await this.redis.zpopmin(
      `${this.queuePrefix}:${queueName}`,
    );

    if (result && result.length > 0) {
      return JSON.parse(result[0]);
    }
    return null;
  }

  async peek(queueName: string, count = 10): Promise<unknown[]> {
    const results = await this.redis.zrange(
      `${this.queuePrefix}:${queueName}`,
      0,
      count - 1,
    );
    return results.map((r) => JSON.parse(r));
  }
}

// Usage avec niveaux nommes
class NamedPriorityQueue {
  private readonly priorities = {
    critical: 1,
    high: 3,
    medium: 5,
    low: 7,
    background: 9,
  };

  constructor(private queue: RedisPriorityQueue) {}

  async enqueue(
    queueName: string,
    message: unknown,
    priority: keyof typeof this.priorities = 'medium',
  ): Promise<void> {
    await this.queue.enqueue(queueName, message, this.priorities[priority]);
  }
}
```

## Consumer avec priorite

```typescript
class PriorityQueueConsumer {
  private running = false;

  constructor(
    private queue: RedisPriorityQueue,
    private handler: (message: unknown) => Promise<void>,
    private queueName: string,
  ) {}

  async start(): Promise<void> {
    this.running = true;

    while (this.running) {
      const message = await this.queue.dequeue(this.queueName);

      if (message) {
        try {
          await this.handler(message);
        } catch (error) {
          // Re-queue with lower priority after failure
          await this.queue.enqueue(this.queueName, message, 8);
        }
      } else {
        // No messages, wait before polling again
        await this.sleep(100);
      }
    }
  }

  stop(): void {
    this.running = false;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
```

## Cas d'usage reels

| Domaine | High Priority | Medium | Low |
|---------|---------------|--------|-----|
| E-commerce | Paiement echoue | Confirmation commande | Newsletter |
| Support | Incident critique | Ticket client | Analytics |
| CI/CD | Hotfix production | Feature branch | Nightly builds |
| Notifications | Alerte securite | Transaction | Marketing |

## Eviter la starvation

```typescript
class AntiStarvationQueue {
  private lastLowProcessed = Date.now();
  private lowStarvationThreshold = 30000; // 30 seconds

  async dequeue(): Promise<Message | null> {
    // Force traitement low priority si trop longtemps ignore
    if (
      Date.now() - this.lastLowProcessed > this.lowStarvationThreshold &&
      this.queues.low.length > 0
    ) {
      this.lastLowProcessed = Date.now();
      return this.queues.low.shift()!;
    }

    // Normal priority order
    for (const priority of this.priorityOrder) {
      if (this.queues[priority].length > 0) {
        if (priority === 'low') {
          this.lastLowProcessed = Date.now();
        }
        return this.queues[priority].shift()!;
      }
    }

    return null;
  }
}
```

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| SLA differencies par client | Oui |
| Taches batch vs temps reel | Oui |
| Ressources limitees | Oui |
| Traitement equitable requis | Non (ou avec anti-starvation) |
| Ordre strict FIFO | Non |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Queue Load Leveling | Lissage de charge |
| Competing Consumers | Parallelisation traitement |
| Throttling | Limiter le debit |
| Circuit Breaker | Gestion erreurs |

## Sources

- [Microsoft - Priority Queue](https://learn.microsoft.com/en-us/azure/architecture/patterns/priority-queue)
- [AWS SQS Message Priority](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-message-priority.html)
- [RabbitMQ Priority Queues](https://www.rabbitmq.com/priority.html)
