# Queue-Based Load Leveling Pattern

> Utiliser une queue comme buffer pour lisser les pics de charge.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │          QUEUE LOAD LEVELING                 │
                    └─────────────────────────────────────────────┘

  SANS QUEUE (pics saturent le service):
                                           ┌─────────┐
  ████████████                            │ Service │
  ██  PEAK  ██ ─────────────────────────▶ │ OVERLOAD│
  ████████████                            │   !!!   │
       │                                   └─────────┘
       │ Capacite max
       ▼
  ═══════════════

  AVEC QUEUE (charge lissee):
                    ┌─────────────┐        ┌─────────┐
  ████████████      │             │        │ Service │
  ██  PEAK  ██ ───▶ │    QUEUE    │ ─────▶ │ Stable  │
  ████████████      │   (buffer)  │        │  Load   │
                    └─────────────┘        └─────────┘
                          │                     │
  Charge entrante         │    Debit constant   │
  ════════════════════════════════════════════════
```

## Comparaison patterns

```
  INPUT RATE        QUEUE DEPTH         OUTPUT RATE
       │                 │                   │
  100  │  ████           │    ████           │
       │  ██████         │      ████████     │ ════════
   50  │    ████████     │        ████████   │ Constant
       │      ████       │          ████     │
    0  └──────────────   └──────────────     └──────────
       Time              Time                Time
```

## Exemple TypeScript

```typescript
interface Task {
  id: string;
  type: string;
  payload: unknown;
  createdAt: Date;
}

class LoadLevelingQueue {
  constructor(
    private queue: QueueService,
    private maxConcurrent: number = 10,
    private processingDelayMs: number = 100,
  ) {}

  async enqueue(task: Task): Promise<void> {
    await this.queue.push(task);
    console.log(`Task ${task.id} queued. Queue depth: ${await this.depth()}`);
  }

  async depth(): Promise<number> {
    return this.queue.length();
  }
}

class LeveledConsumer {
  private active = 0;
  private running = false;

  constructor(
    private queue: QueueService,
    private handler: (task: Task) => Promise<void>,
    private maxConcurrent: number = 10,
    private pollIntervalMs: number = 100,
  ) {}

  async start(): Promise<void> {
    this.running = true;

    while (this.running) {
      // Respecter la limite de concurrence
      while (this.active < this.maxConcurrent) {
        const task = await this.queue.pop();
        if (!task) break;

        this.active++;
        this.processTask(task).finally(() => this.active--);
      }

      await this.sleep(this.pollIntervalMs);
    }
  }

  private async processTask(task: Task): Promise<void> {
    try {
      await this.handler(task);
    } catch (error) {
      console.error(`Task ${task.id} failed:`, error);
      // Optionnel: re-queue for retry
      await this.queue.push({ ...task, attempts: (task.attempts ?? 0) + 1 });
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

## Implementation avec rate limiting

```typescript
class TokenBucketConsumer {
  private tokens: number;
  private lastRefill: number;

  constructor(
    private queue: QueueService,
    private handler: (task: Task) => Promise<void>,
    private tokensPerSecond: number = 10,
    private maxTokens: number = 20,
  ) {
    this.tokens = maxTokens;
    this.lastRefill = Date.now();
  }

  async start(): Promise<void> {
    while (true) {
      this.refillTokens();

      if (this.tokens >= 1) {
        const task = await this.queue.pop();
        if (task) {
          this.tokens--;
          this.handler(task); // Fire and forget
        }
      }

      await this.sleep(10); // Poll frequently
    }
  }

  private refillTokens(): void {
    const now = Date.now();
    const elapsed = (now - this.lastRefill) / 1000;
    const newTokens = elapsed * this.tokensPerSecond;

    this.tokens = Math.min(this.maxTokens, this.tokens + newTokens);
    this.lastRefill = now;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
```

## Auto-scaling base sur la queue

```typescript
class AutoScalingConsumer {
  private consumers: LeveledConsumer[] = [];

  constructor(
    private queue: QueueService,
    private handler: (task: Task) => Promise<void>,
    private minConsumers: number = 1,
    private maxConsumers: number = 10,
    private scaleUpThreshold: number = 100, // Queue depth
    private scaleDownThreshold: number = 10,
  ) {
    // Start with min consumers
    for (let i = 0; i < minConsumers; i++) {
      this.addConsumer();
    }

    // Monitor and scale
    this.startMonitoring();
  }

  private addConsumer(): void {
    if (this.consumers.length >= this.maxConsumers) return;

    const consumer = new LeveledConsumer(this.queue, this.handler, 1);
    consumer.start();
    this.consumers.push(consumer);
    console.log(`Scaled up to ${this.consumers.length} consumers`);
  }

  private removeConsumer(): void {
    if (this.consumers.length <= this.minConsumers) return;

    const consumer = this.consumers.pop();
    consumer?.stop();
    console.log(`Scaled down to ${this.consumers.length} consumers`);
  }

  private startMonitoring(): void {
    setInterval(async () => {
      const depth = await this.queue.length();

      if (depth > this.scaleUpThreshold) {
        this.addConsumer();
      } else if (depth < this.scaleDownThreshold) {
        this.removeConsumer();
      }
    }, 5000); // Check every 5 seconds
  }
}
```

## Metriques cles

```typescript
class QueueMetrics {
  private enqueueTimes: number[] = [];
  private dequeueTimes: number[] = [];

  recordEnqueue(): void {
    this.enqueueTimes.push(Date.now());
    this.cleanup();
  }

  recordDequeue(): void {
    this.dequeueTimes.push(Date.now());
    this.cleanup();
  }

  // Messages par seconde entrant
  getEnqueueRate(): number {
    return this.calculateRate(this.enqueueTimes);
  }

  // Messages par seconde sortant
  getDequeueRate(): number {
    return this.calculateRate(this.dequeueTimes);
  }

  // Si > 1, queue grandit (backpressure)
  getBackpressureRatio(): number {
    const enqRate = this.getEnqueueRate();
    const deqRate = this.getDequeueRate();
    return deqRate > 0 ? enqRate / deqRate : Infinity;
  }

  private calculateRate(times: number[]): number {
    if (times.length < 2) return 0;
    const window = 60000; // 1 minute
    const recent = times.filter((t) => t > Date.now() - window);
    return (recent.length / window) * 1000;
  }

  private cleanup(): void {
    const cutoff = Date.now() - 300000; // Keep 5 min
    this.enqueueTimes = this.enqueueTimes.filter((t) => t > cutoff);
    this.dequeueTimes = this.dequeueTimes.filter((t) => t > cutoff);
  }
}
```

## Services cloud

| Service | Provider | Caracteristiques |
|---------|----------|------------------|
| SQS | AWS | Serverless, auto-scale, 14j retention |
| Azure Queue | Azure | Integre Functions, 7j retention |
| Cloud Tasks | GCP | HTTP targets, scheduling |
| RabbitMQ | Self-hosted | Features avancees, clustering |
| Redis Streams | Redis | Ultra-rapide, persistence |

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Pics de trafic previsibles | Oui |
| Decoupler producteur/consommateur | Oui |
| Service downstream lent | Oui |
| Latence temps reel critique | Non (ajoute delai) |
| Ordre strict requis | Avec FIFO garantie |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Priority Queue | Traitement par importance |
| Competing Consumers | Parallelisation |
| Throttling | Limiter le debit |
| Circuit Breaker | Si consumer defaillant |

## Sources

- [Microsoft - Queue-Based Load Leveling](https://learn.microsoft.com/en-us/azure/architecture/patterns/queue-based-load-leveling)
- [AWS SQS Best Practices](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-best-practices.html)
- [Martin Fowler - Messaging](https://martinfowler.com/articles/integration-patterns.html)
