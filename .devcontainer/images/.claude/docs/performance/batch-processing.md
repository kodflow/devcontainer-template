# Batch Processing

Pattern de regroupement d'operations pour reduire l'overhead.

---

## Qu'est-ce que le Batch Processing ?

> Collecter plusieurs operations et les executer en une seule fois.

```
+--------------------------------------------------------------+
|                    Batch Processing                           |
|                                                               |
|  Sans batch:     Op1 --> DB                                   |
|                  Op2 --> DB                                   |
|                  Op3 --> DB     (3 round-trips)               |
|                                                               |
|  Avec batch:     Op1 -+                                       |
|                  Op2 -+--> [Batch] --> DB  (1 round-trip)     |
|                  Op3 -+                                       |
|                                                               |
|  Timeline:                                                    |
|                                                               |
|  add() add() add()                  flush()                   |
|    |     |     |                       |                      |
|    v     v     v                       v                      |
|  +---+ +---+ +---+                 +-------+                  |
|  | 1 | | 2 | | 3 | === batch ===> | 1,2,3 | --> process()    |
|  +---+ +---+ +---+                 +-------+                  |
+--------------------------------------------------------------+
```

**Pourquoi :**
- Reduire les round-trips reseau/DB
- Amortir les couts fixes (connexion, headers)
- Optimiser le throughput

---

## Implementation TypeScript

### BatchProcessor basique

```typescript
class BatchProcessor<T> {
  private batch: T[] = [];
  private timer: ReturnType<typeof setTimeout> | null = null;
  private processing = false;

  constructor(
    private processor: (items: T[]) => Promise<void>,
    private options: {
      maxSize: number;
      maxWait: number;
    },
  ) {}

  add(item: T): void {
    this.batch.push(item);

    if (this.batch.length >= this.options.maxSize) {
      this.flush();
    } else if (!this.timer) {
      this.timer = setTimeout(() => this.flush(), this.options.maxWait);
    }
  }

  async flush(): Promise<void> {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    if (this.batch.length === 0 || this.processing) {
      return;
    }

    this.processing = true;
    const items = this.batch;
    this.batch = [];

    try {
      await this.processor(items);
    } finally {
      this.processing = false;
    }
  }

  get pending(): number {
    return this.batch.length;
  }
}

// Usage
const logBatcher = new BatchProcessor<LogEntry>(
  async (entries) => {
    await db.logs.insertMany(entries);
  },
  { maxSize: 100, maxWait: 1000 },
);

logBatcher.add({ level: 'info', message: 'User logged in' });
```

### BatchProcessor avec resultats

```typescript
interface BatchItem<TInput, TResult> {
  input: TInput;
  resolve: (result: TResult) => void;
  reject: (error: Error) => void;
}

class BatchProcessorWithResults<TInput, TResult> {
  private batch: BatchItem<TInput, TResult>[] = [];
  private timer: ReturnType<typeof setTimeout> | null = null;

  constructor(
    private processor: (inputs: TInput[]) => Promise<TResult[]>,
    private options: { maxSize: number; maxWait: number },
  ) {}

  async add(input: TInput): Promise<TResult> {
    return new Promise<TResult>((resolve, reject) => {
      this.batch.push({ input, resolve, reject });

      if (this.batch.length >= this.options.maxSize) {
        this.flush();
      } else if (!this.timer) {
        this.timer = setTimeout(() => this.flush(), this.options.maxWait);
      }
    });
  }

  private async flush(): Promise<void> {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    if (this.batch.length === 0) return;

    const items = this.batch;
    this.batch = [];
    const inputs = items.map((i) => i.input);

    try {
      const results = await this.processor(inputs);
      items.forEach((item, index) => {
        item.resolve(results[index]);
      });
    } catch (error) {
      items.forEach((item) => {
        item.reject(error as Error);
      });
    }
  }
}

// Usage - DataLoader pattern
const userLoader = new BatchProcessorWithResults<string, User>(
  async (ids) => {
    const users = await db.users.findByIds(ids);
    // Maintenir l'ordre des resultats
    return ids.map((id) => users.find((u) => u.id === id)!);
  },
  { maxSize: 100, maxWait: 10 },
);

// Appels individuels, execution groupee
const user1 = await userLoader.add('user-1');
const user2 = await userLoader.add('user-2');
```

---

## Strategies de batching

### 1. Time-based

```typescript
// Flush toutes les N millisecondes
setInterval(() => batcher.flush(), 1000);
```

### 2. Size-based

```typescript
// Flush quand le batch atteint N items
if (batch.length >= maxSize) {
  flush();
}
```

### 3. Hybride (recommande)

```typescript
// Flush au premier de: maxSize ou maxWait
class HybridBatcher<T> {
  add(item: T): void {
    this.batch.push(item);

    if (this.batch.length >= this.maxSize) {
      this.flush(); // Size trigger
    } else if (!this.timer) {
      this.timer = setTimeout(() => this.flush(), this.maxWait); // Time trigger
    }
  }
}
```

### 4. Backpressure

```typescript
class BackpressureBatcher<T> {
  private processing = false;
  private queue: T[][] = [];

  async add(item: T): Promise<void> {
    this.batch.push(item);

    if (this.batch.length >= this.maxSize) {
      const items = this.batch;
      this.batch = [];

      if (this.processing) {
        // Mettre en queue si deja en traitement
        this.queue.push(items);
      } else {
        await this.processWithQueue(items);
      }
    }
  }

  private async processWithQueue(items: T[]): Promise<void> {
    this.processing = true;
    await this.processor(items);

    while (this.queue.length > 0) {
      const next = this.queue.shift()!;
      await this.processor(next);
    }

    this.processing = false;
  }
}
```

---

## Cas d'usage

```typescript
// 1. Insertion DB en masse
const insertBatcher = new BatchProcessor<Record>(
  async (records) => {
    await db.collection.insertMany(records);
  },
  { maxSize: 1000, maxWait: 100 },
);

// 2. Envoi d'emails
const emailBatcher = new BatchProcessor<Email>(
  async (emails) => {
    await emailService.sendBulk(emails);
  },
  { maxSize: 50, maxWait: 5000 },
);

// 3. Metrics/Analytics
const metricsBatcher = new BatchProcessor<Metric>(
  async (metrics) => {
    await analytics.trackBatch(metrics);
  },
  { maxSize: 100, maxWait: 10000 },
);
```

---

## Complexite et Trade-offs

| Aspect | Valeur |
|--------|--------|
| Latence ajoutee | maxWait (pire cas) |
| Reduction round-trips | ~N/maxSize |
| Memoire | O(maxSize) |

### Avantages

- Throughput ameliore
- Moins de connexions/requetes
- Meilleure utilisation reseau

### Inconvenients

- Latence ajoutee
- Complexite erreurs partielles
- Risque de perte si crash avant flush

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Buffer** | Stockage temporaire similaire |
| **DataLoader** | Batch + cache pour GraphQL |
| **Producer-Consumer** | Queue entre production et traitement |
| **Debounce** | Grouper dans le temps, pas en nombre |

---

## Sources

- [DataLoader](https://github.com/graphql/dataloader)
- [Batch Processing - Enterprise Patterns](https://www.enterpriseintegrationpatterns.com/patterns/messaging/BatchSequence.html)
