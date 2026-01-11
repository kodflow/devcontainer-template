# Pipeline

Pattern de traitement par etapes sequentielles potentiellement paralleles.

---

## Qu'est-ce qu'un Pipeline ?

> Chaine de stages de traitement ou chaque stage transforme les donnees pour le suivant.

```
+--------------------------------------------------------------+
|                        Pipeline                               |
|                                                               |
|  Input --> [Stage 1] --> [Stage 2] --> [Stage 3] --> Output   |
|             Parse        Transform       Validate             |
|                                                               |
|  Parallelisme par stage:                                      |
|                                                               |
|  Data 1: [S1] -----> [S2] -----> [S3]                         |
|  Data 2:      [S1] -----> [S2] -----> [S3]                    |
|  Data 3:           [S1] -----> [S2] -----> [S3]               |
|                                                               |
|  Chaque stage peut traiter pendant que les autres travaillent |
|                                                               |
|  Throughput = (N items) / (temps stage le plus lent)          |
+--------------------------------------------------------------+
```

**Pourquoi :**

- Decomposer un traitement complexe
- Paralleliser les etapes independantes
- Meilleure utilisation des ressources

---

## Implementation TypeScript

### Pipeline basique

```typescript
type Stage<I, O> = (input: I) => O | Promise<O>;

class Pipeline<TInput, TOutput> {
  private stages: Stage<any, any>[] = [];

  addStage<TNewOutput>(
    stage: Stage<TOutput, TNewOutput>,
  ): Pipeline<TInput, TNewOutput> {
    this.stages.push(stage);
    return this as unknown as Pipeline<TInput, TNewOutput>;
  }

  async execute(input: TInput): Promise<TOutput> {
    let result: any = input;

    for (const stage of this.stages) {
      result = await stage(result);
    }

    return result;
  }
}

// Usage
const pipeline = new Pipeline<string, ProcessedData>()
  .addStage((raw) => JSON.parse(raw))           // Parse
  .addStage((data) => validate(data))            // Validate
  .addStage((data) => transform(data))           // Transform
  .addStage((data) => enrich(data));             // Enrich

const result = await pipeline.execute(rawJson);
```

### Pipeline avec streaming

```typescript
class StreamPipeline<TInput, TOutput> {
  private stages: Stage<any, any>[] = [];

  addStage<TNewOutput>(
    stage: Stage<TOutput, TNewOutput>,
  ): StreamPipeline<TInput, TNewOutput> {
    this.stages.push(stage);
    return this as unknown as StreamPipeline<TInput, TNewOutput>;
  }

  async *stream(
    inputs: AsyncIterable<TInput>,
  ): AsyncGenerator<TOutput> {
    for await (const input of inputs) {
      let result: any = input;

      for (const stage of this.stages) {
        result = await stage(result);
      }

      yield result;
    }
  }

  async collect(inputs: AsyncIterable<TInput>): Promise<TOutput[]> {
    const results: TOutput[] = [];
    for await (const output of this.stream(inputs)) {
      results.push(output);
    }
    return results;
  }
}
```

---

## Pipeline parallele

```typescript
interface ParallelStage<I, O> {
  process: (input: I) => Promise<O>;
  concurrency: number;
}

class ParallelPipeline<TInput, TOutput> {
  private stages: ParallelStage<any, any>[] = [];

  addStage<TNewOutput>(
    process: (input: TOutput) => Promise<TNewOutput>,
    concurrency: number = 1,
  ): ParallelPipeline<TInput, TNewOutput> {
    this.stages.push({ process, concurrency });
    return this as unknown as ParallelPipeline<TInput, TNewOutput>;
  }

  async *stream(
    inputs: AsyncIterable<TInput>,
  ): AsyncGenerator<TOutput> {
    // Creer des queues entre chaque stage
    const queues: AsyncQueue<any>[] = [];

    for (let i = 0; i < this.stages.length; i++) {
      queues.push(new AsyncQueue());
    }

    // Demarrer les workers pour chaque stage
    const workers: Promise<void>[] = [];

    for (let i = 0; i < this.stages.length; i++) {
      const stage = this.stages[i];
      const inputQueue = i === 0 ? null : queues[i - 1];
      const outputQueue = queues[i];

      for (let w = 0; w < stage.concurrency; w++) {
        workers.push(
          this.runStageWorker(stage, inputQueue, outputQueue),
        );
      }
    }

    // Alimenter le premier stage
    (async () => {
      for await (const input of inputs) {
        queues[0].push(input);
      }
      queues[0].close();
    })();

    // Consommer le dernier stage
    for await (const output of queues[queues.length - 1]) {
      yield output;
    }
  }

  private async runStageWorker(
    stage: ParallelStage<any, any>,
    inputQueue: AsyncQueue<any> | null,
    outputQueue: AsyncQueue<any>,
  ): Promise<void> {
    if (!inputQueue) return;

    for await (const input of inputQueue) {
      const output = await stage.process(input);
      outputQueue.push(output);
    }
  }
}

// Queue asynchrone
class AsyncQueue<T> implements AsyncIterable<T> {
  private queue: T[] = [];
  private waiting: Array<(value: IteratorResult<T>) => void> = [];
  private closed = false;

  push(item: T): void {
    if (this.closed) return;
    const waiter = this.waiting.shift();
    if (waiter) {
      waiter({ value: item, done: false });
    } else {
      this.queue.push(item);
    }
  }

  close(): void {
    this.closed = true;
    this.waiting.forEach((w) => w({ value: undefined as T, done: true }));
  }

  async *[Symbol.asyncIterator](): AsyncIterator<T> {
    while (true) {
      if (this.queue.length > 0) {
        yield this.queue.shift()!;
      } else if (this.closed) {
        return;
      } else {
        const result = await new Promise<IteratorResult<T>>((resolve) => {
          this.waiting.push(resolve);
        });
        if (result.done) return;
        yield result.value;
      }
    }
  }
}
```

---

## Pipeline avec error handling

```typescript
interface PipelineResult<T> {
  success: boolean;
  data?: T;
  error?: Error;
  stage?: string;
}

class RobustPipeline<TInput, TOutput> {
  private stages: Array<{
    name: string;
    process: Stage<any, any>;
  }> = [];

  addStage<TNewOutput>(
    name: string,
    process: Stage<TOutput, TNewOutput>,
  ): RobustPipeline<TInput, TNewOutput> {
    this.stages.push({ name, process });
    return this as unknown as RobustPipeline<TInput, TNewOutput>;
  }

  async execute(input: TInput): Promise<PipelineResult<TOutput>> {
    let result: any = input;

    for (const stage of this.stages) {
      try {
        result = await stage.process(result);
      } catch (error) {
        return {
          success: false,
          error: error as Error,
          stage: stage.name,
        };
      }
    }

    return { success: true, data: result };
  }

  async executeWithRetry(
    input: TInput,
    retries: number = 3,
  ): Promise<PipelineResult<TOutput>> {
    for (let attempt = 0; attempt < retries; attempt++) {
      const result = await this.execute(input);
      if (result.success) return result;

      console.warn(`Pipeline failed at ${result.stage}, retry ${attempt + 1}`);
      await delay(Math.pow(2, attempt) * 100);
    }

    return this.execute(input); // Dernier essai
  }
}
```

---

## Cas d'usage: ETL Pipeline

```typescript
interface RawData {
  id: string;
  json: string;
}

interface ParsedData {
  id: string;
  data: Record<string, unknown>;
}

interface EnrichedData extends ParsedData {
  metadata: { processedAt: Date };
}

interface ValidatedData extends EnrichedData {
  valid: boolean;
}

const etlPipeline = new Pipeline<RawData, ValidatedData>()
  .addStage(async (raw): Promise<ParsedData> => ({
    id: raw.id,
    data: JSON.parse(raw.json),
  }))
  .addStage(async (parsed): Promise<EnrichedData> => ({
    ...parsed,
    metadata: { processedAt: new Date() },
  }))
  .addStage(async (enriched): Promise<ValidatedData> => ({
    ...enriched,
    valid: validateSchema(enriched.data),
  }));

// Traitement batch
const rawItems = await fetchRawData();
const results = await Promise.all(
  rawItems.map((item) => etlPipeline.execute(item)),
);
```

---

## Complexite et Trade-offs

| Aspect | Valeur |
|--------|--------|
| Latence (1 item) | O(sum of stages) |
| Throughput | O(1 / slowest stage) |
| Memoire | O(queue sizes) |

### Avantages

- Separation des responsabilites
- Parallelisme naturel
- Testabilite par stage
- Monitoring par stage

### Inconvenients

- Overhead pour petits traitements
- Complexite debugging
- Backpressure a gerer

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Traitement multi-etapes | Oui |
| ETL / Data processing | Oui |
| Traitement d'images | Oui |
| Logique metier simple | Non |
| Latence critique | Prudence |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Chain of Responsibility** | Similaire, focus sur handlers |
| **Producer-Consumer** | Queues entre stages |
| **Decorator** | Transformation sequentielle |
| **Stream** | Pipeline sur flux continu |

---

## Sources

- [Go Pipelines](https://go.dev/blog/pipelines)
- [Unix Pipes](https://en.wikipedia.org/wiki/Pipeline_(Unix))
- [Enterprise Integration Patterns - Pipes and Filters](https://www.enterpriseintegrationpatterns.com/patterns/messaging/PipesAndFilters.html)
