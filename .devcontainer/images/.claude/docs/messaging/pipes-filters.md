# Pipes and Filters Pattern

Pipeline de traitement composable pour les messages.

## Vue d'ensemble

```
+--------+     +--------+     +--------+     +--------+
| Filter |---->| Filter |---->| Filter |---->| Filter |
|   A    |     |   B    |     |   C    |     |   D    |
+--------+     +--------+     +--------+     +--------+
    |              |              |              |
    v              v              v              v
  Validate      Enrich       Transform       Route

Input ============= PIPE ============= PIPE =============> Output
```

---

## Concepts fondamentaux

```
FILTER: Unite de traitement autonome
  - Input -> Processing -> Output
  - Single Responsibility
  - Stateless (idealement)

PIPE: Connecteur entre filtres
  - Transporte les messages
  - Peut etre synchrone ou asynchrone
  - Peut etre une queue, un channel, un stream
```

---

## Implementation de base

```typescript
// Interface de base pour un filtre
interface Filter<TInput, TOutput> {
  process(input: TInput): Promise<TOutput>;
}

// Pipe qui connecte les filtres
class Pipe<T> {
  private buffer: T[] = [];
  private consumers: ((value: T) => void)[] = [];

  send(value: T): void {
    if (this.consumers.length > 0) {
      this.consumers.forEach(consumer => consumer(value));
    } else {
      this.buffer.push(value);
    }
  }

  receive(): Promise<T> {
    if (this.buffer.length > 0) {
      return Promise.resolve(this.buffer.shift()!);
    }
    return new Promise(resolve => {
      this.consumers.push(resolve);
    });
  }
}

// Pipeline builder
class Pipeline<TInput> {
  private filters: Filter<unknown, unknown>[] = [];

  addFilter<TOutput>(filter: Filter<TInput, TOutput>): Pipeline<TOutput> {
    this.filters.push(filter as Filter<unknown, unknown>);
    return this as unknown as Pipeline<TOutput>;
  }

  async execute(input: TInput): Promise<unknown> {
    let current: unknown = input;
    for (const filter of this.filters) {
      current = await filter.process(current);
      if (current === null || current === undefined) {
        return null; // Message filtre
      }
    }
    return current;
  }
}

// Usage
const pipeline = new Pipeline<RawOrder>()
  .addFilter(new ValidationFilter())
  .addFilter(new EnrichmentFilter())
  .addFilter(new TransformationFilter())
  .addFilter(new RoutingFilter());

const result = await pipeline.execute(rawOrder);
```

---

## Filtres reusables

```typescript
// Filtre de validation
class ValidationFilter<T> implements Filter<T, T> {
  constructor(private validator: (input: T) => ValidationResult) {}

  async process(input: T): Promise<T> {
    const result = this.validator(input);
    if (!result.valid) {
      throw new ValidationError(result.errors);
    }
    return input;
  }
}

// Filtre de transformation
class TransformFilter<TInput, TOutput> implements Filter<TInput, TOutput> {
  constructor(private transformer: (input: TInput) => TOutput) {}

  async process(input: TInput): Promise<TOutput> {
    return this.transformer(input);
  }
}

// Filtre d'enrichissement
class EnrichmentFilter<T> implements Filter<T, T & Record<string, unknown>> {
  constructor(
    private enricher: (input: T) => Promise<Record<string, unknown>>
  ) {}

  async process(input: T): Promise<T & Record<string, unknown>> {
    const enrichedData = await this.enricher(input);
    return { ...input, ...enrichedData };
  }
}

// Filtre conditionnel (filtering)
class ConditionalFilter<T> implements Filter<T, T | null> {
  constructor(private predicate: (input: T) => boolean) {}

  async process(input: T): Promise<T | null> {
    return this.predicate(input) ? input : null;
  }
}

// Filtre de logging/audit
class LoggingFilter<T> implements Filter<T, T> {
  constructor(private logger: Logger, private stage: string) {}

  async process(input: T): Promise<T> {
    this.logger.info(`${this.stage}: Processing message`, { input });
    return input;
  }
}
```

---

## Pipeline asynchrone avec queues

```typescript
// Chaque filtre consomme d'une queue et publie vers la suivante
class AsyncPipeline {
  private stages: PipelineStage[] = [];

  addStage(
    name: string,
    filter: Filter<unknown, unknown>,
    inputQueue: string,
    outputQueue: string
  ): void {
    this.stages.push({ name, filter, inputQueue, outputQueue });
  }

  async start(): Promise<void> {
    for (const stage of this.stages) {
      this.startStage(stage);
    }
  }

  private async startStage(stage: PipelineStage): Promise<void> {
    await this.messageQueue.subscribe(stage.inputQueue, async (message) => {
      try {
        const result = await stage.filter.process(message);
        if (result !== null) {
          await this.messageQueue.send(stage.outputQueue, result);
        }
      } catch (error) {
        await this.handleError(stage, message, error as Error);
      }
    });
  }

  private async handleError(
    stage: PipelineStage,
    message: unknown,
    error: Error
  ): Promise<void> {
    await this.messageQueue.send('pipeline-errors', {
      stage: stage.name,
      message,
      error: error.message,
      timestamp: new Date(),
    });
  }
}

// Configuration
const pipeline = new AsyncPipeline();
pipeline.addStage('validate', new ValidationFilter(), 'orders.raw', 'orders.validated');
pipeline.addStage('enrich', new EnrichmentFilter(), 'orders.validated', 'orders.enriched');
pipeline.addStage('transform', new TransformFilter(), 'orders.enriched', 'orders.final');
await pipeline.start();
```

---

## Pipeline avec RabbitMQ/Kafka

```typescript
// RabbitMQ - Exchange chain
class RabbitMQPipeline {
  async setupPipeline(stages: string[]): Promise<void> {
    for (let i = 0; i < stages.length; i++) {
      const stage = stages[i];
      const nextStage = stages[i + 1] || 'output';

      await this.channel.assertQueue(`pipeline.${stage}`, { durable: true });
      await this.channel.assertExchange(`pipeline.${stage}.out`, 'direct');

      if (nextStage !== 'output') {
        await this.channel.bindQueue(
          `pipeline.${nextStage}`,
          `pipeline.${stage}.out`,
          'next'
        );
      }
    }
  }
}

// Kafka - Topic chain avec Streams
class KafkaStreamsPipeline {
  buildTopology(): StreamsBuilder {
    const builder = new StreamsBuilder();

    builder
      .stream('orders-raw')
      .filter((key, value) => this.isValid(value))
      .mapValues((value) => this.enrich(value))
      .mapValues((value) => this.transform(value))
      .to('orders-processed');

    return builder;
  }
}

// Consumer-Producer chain
class KafkaPipelineStage {
  constructor(
    private inputTopic: string,
    private outputTopic: string,
    private filter: Filter<unknown, unknown>
  ) {}

  async start(): Promise<void> {
    await this.consumer.subscribe({ topic: this.inputTopic });

    await this.consumer.run({
      eachMessage: async ({ message }) => {
        const input = JSON.parse(message.value!.toString());
        const output = await this.filter.process(input);

        if (output !== null) {
          await this.producer.send({
            topic: this.outputTopic,
            messages: [{ value: JSON.stringify(output) }],
          });
        }
      },
    });
  }
}
```

---

## Parallelisation

```typescript
// Filtres paralleles qui se rejoignent
class ParallelPipeline<TInput, TOutput> {
  constructor(
    private parallelFilters: Filter<TInput, Partial<TOutput>>[],
    private merger: (results: Partial<TOutput>[]) => TOutput
  ) {}

  async process(input: TInput): Promise<TOutput> {
    const results = await Promise.all(
      this.parallelFilters.map(filter => filter.process(input))
    );
    return this.merger(results);
  }
}

// Usage: Enrichissement parallele depuis plusieurs sources
const parallelEnrichment = new ParallelPipeline<Order, EnrichedOrder>(
  [
    new CustomerEnrichmentFilter(customerService),
    new InventoryEnrichmentFilter(inventoryService),
    new PricingEnrichmentFilter(pricingService),
  ],
  (results) => Object.assign({}, ...results)
);
```

---

## Gestion des erreurs

```typescript
class ResilientPipeline<TInput> extends Pipeline<TInput> {
  private errorHandlers: Map<string, ErrorHandler> = new Map();
  private circuitBreakers: Map<string, CircuitBreaker> = new Map();

  async execute(input: TInput): Promise<unknown> {
    let current: unknown = input;

    for (const filter of this.filters) {
      const filterName = filter.constructor.name;
      const breaker = this.circuitBreakers.get(filterName);

      if (breaker?.isOpen()) {
        // Skip ou utiliser fallback
        continue;
      }

      try {
        current = await this.executeWithTimeout(filter, current);
        breaker?.recordSuccess();
      } catch (error) {
        breaker?.recordFailure();

        const handler = this.errorHandlers.get(filterName);
        if (handler) {
          const recovery = await handler.handle(error as Error, current);
          if (recovery.continue) {
            current = recovery.value;
            continue;
          }
        }

        throw new PipelineError(filterName, error as Error);
      }
    }

    return current;
  }

  private async executeWithTimeout(
    filter: Filter<unknown, unknown>,
    input: unknown
  ): Promise<unknown> {
    return Promise.race([
      filter.process(input),
      new Promise((_, reject) =>
        setTimeout(() => reject(new TimeoutError()), 5000)
      ),
    ]);
  }
}
```

---

## Monitoring du pipeline

```typescript
class InstrumentedPipeline<TInput> extends Pipeline<TInput> {
  async execute(input: TInput): Promise<unknown> {
    const traceId = crypto.randomUUID();
    const stages: StageMetrics[] = [];
    let current: unknown = input;

    for (const filter of this.filters) {
      const start = Date.now();
      const filterName = filter.constructor.name;

      try {
        current = await filter.process(current);

        stages.push({
          name: filterName,
          durationMs: Date.now() - start,
          success: true,
        });
      } catch (error) {
        stages.push({
          name: filterName,
          durationMs: Date.now() - start,
          success: false,
          error: (error as Error).message,
        });
        throw error;
      }
    }

    this.metrics.record({
      traceId,
      totalDurationMs: stages.reduce((sum, s) => sum + s.durationMs, 0),
      stages,
    });

    return current;
  }
}
```

---

## Patterns complementaires

- **Message Router** - Routage dynamique
- **Splitter/Aggregator** - Division et fusion
- **Content Enricher** - Type de filtre
- **Message Filter** - Type de filtre
