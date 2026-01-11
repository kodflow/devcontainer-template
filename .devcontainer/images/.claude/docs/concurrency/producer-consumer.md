# Producer-Consumer

Pattern separant production et consommation de donnees via une queue.

---

## Qu'est-ce que Producer-Consumer ?

> Decoupler les producteurs des consommateurs avec une queue intermediaire.

```
+--------------------------------------------------------------+
|                   Producer-Consumer                           |
|                                                               |
|  Producers              Queue              Consumers          |
|                                                               |
|  +----------+      +------------+       +----------+          |
|  |Producer 1|--+   |            |   +---|Consumer 1|          |
|  +----------+  |   | [item][..] |   |   +----------+          |
|                +-->|    -->     |---+                         |
|  +----------+  |   |            |   |   +----------+          |
|  |Producer 2|--+   +------------+   +---|Consumer 2|          |
|  +----------+                       |   +----------+          |
|                    Bounded Queue    |                         |
|                    (backpressure)   |   +----------+          |
|                                     +---|Consumer 3|          |
|                                         +----------+          |
|                                                               |
|  Decouplage:                                                  |
|  - Producteurs independants des consommateurs                 |
|  - Vitesses differentes gerees par la queue                   |
|  - Scalabilite independante                                   |
+--------------------------------------------------------------+
```

**Pourquoi :**

- Decoupler production/consommation
- Gerer les differences de vitesse
- Permettre le buffering

---

## Implementation TypeScript

### Queue basique

```typescript
class ProducerConsumerQueue<T> {
  private queue: T[] = [];
  private waiting: Array<(item: T) => void> = [];
  private closed = false;

  produce(item: T): void {
    if (this.closed) {
      throw new Error('Queue is closed');
    }

    const waiter = this.waiting.shift();
    if (waiter) {
      waiter(item);
    } else {
      this.queue.push(item);
    }
  }

  async consume(): Promise<T | null> {
    if (this.queue.length > 0) {
      return this.queue.shift()!;
    }

    if (this.closed) {
      return null;
    }

    return new Promise((resolve) => {
      this.waiting.push(resolve);
    });
  }

  close(): void {
    this.closed = true;
    // Liberer tous les consommateurs en attente
    this.waiting.forEach((resolve) => resolve(null as T));
    this.waiting = [];
  }

  get size(): number {
    return this.queue.length;
  }
}
```

### Bounded Queue (avec backpressure)

```typescript
class BoundedQueue<T> {
  private queue: T[] = [];
  private consumers: Array<(item: T | null) => void> = [];
  private producers: Array<() => void> = [];
  private closed = false;

  constructor(private maxSize: number) {}

  async produce(item: T): Promise<void> {
    if (this.closed) {
      throw new Error('Queue is closed');
    }

    // Attendre si la queue est pleine (backpressure)
    while (this.queue.length >= this.maxSize && !this.closed) {
      await new Promise<void>((resolve) => {
        this.producers.push(resolve);
      });
    }

    if (this.closed) {
      throw new Error('Queue is closed');
    }

    const consumer = this.consumers.shift();
    if (consumer) {
      consumer(item);
    } else {
      this.queue.push(item);
    }
  }

  async consume(): Promise<T | null> {
    if (this.queue.length > 0) {
      const item = this.queue.shift()!;
      // Debloquer un producteur en attente
      const producer = this.producers.shift();
      producer?.();
      return item;
    }

    if (this.closed) {
      return null;
    }

    return new Promise((resolve) => {
      this.consumers.push(resolve);
    });
  }

  close(): void {
    this.closed = true;
    this.consumers.forEach((c) => c(null));
    this.producers.forEach((p) => p());
    this.consumers = [];
    this.producers = [];
  }
}
```

---

## Multi-Consumer Pattern

```typescript
class WorkerPool<T, R> {
  private queue: BoundedQueue<T | null>;
  private results: R[] = [];
  private workers: Promise<void>[] = [];

  constructor(
    private processor: (item: T) => Promise<R>,
    private numWorkers: number,
    queueSize: number,
  ) {
    this.queue = new BoundedQueue(queueSize);
  }

  async start(): Promise<void> {
    // Demarrer les workers
    for (let i = 0; i < this.numWorkers; i++) {
      this.workers.push(this.worker(i));
    }
  }

  private async worker(id: number): Promise<void> {
    while (true) {
      const item = await this.queue.consume();
      if (item === null) break; // Poison pill

      try {
        const result = await this.processor(item);
        this.results.push(result);
      } catch (error) {
        console.error(`Worker ${id} error:`, error);
      }
    }
  }

  async produce(item: T): Promise<void> {
    await this.queue.produce(item);
  }

  async shutdown(): Promise<R[]> {
    // Envoyer poison pills
    for (let i = 0; i < this.numWorkers; i++) {
      await this.queue.produce(null as T);
    }

    // Attendre tous les workers
    await Promise.all(this.workers);

    return this.results;
  }
}

// Usage
const pool = new WorkerPool<string, Response>(
  async (url) => fetch(url),
  4, // 4 workers
  100, // queue max 100
);

await pool.start();

for (const url of urls) {
  await pool.produce(url);
}

const results = await pool.shutdown();
```

---

## AsyncIterable Pattern

```typescript
class AsyncQueue<T> implements AsyncIterable<T> {
  private queue: T[] = [];
  private resolvers: Array<(value: IteratorResult<T>) => void> = [];
  private closed = false;

  push(item: T): void {
    if (this.closed) return;

    const resolver = this.resolvers.shift();
    if (resolver) {
      resolver({ value: item, done: false });
    } else {
      this.queue.push(item);
    }
  }

  close(): void {
    this.closed = true;
    this.resolvers.forEach((r) => r({ value: undefined, done: true }));
    this.resolvers = [];
  }

  async *[Symbol.asyncIterator](): AsyncIterator<T> {
    while (true) {
      if (this.queue.length > 0) {
        yield this.queue.shift()!;
        continue;
      }

      if (this.closed) {
        return;
      }

      const result = await new Promise<IteratorResult<T>>((resolve) => {
        this.resolvers.push(resolve);
      });

      if (result.done) return;
      yield result.value;
    }
  }
}

// Usage avec for-await
const queue = new AsyncQueue<number>();

// Producer
setTimeout(() => {
  queue.push(1);
  queue.push(2);
  queue.push(3);
  queue.close();
}, 100);

// Consumer
for await (const item of queue) {
  console.log('Received:', item);
}
```

---

## Patterns de distribution

```
1. Competing Consumers (Work Queue):
   Producer --> [Queue] --> Consumer 1 (traite un message)
                       --> Consumer 2 (traite un message)
   Chaque message traite par UN seul consumer

2. Publish-Subscribe:
   Producer --> [Topic] --> Consumer 1 (recoit tous)
                       --> Consumer 2 (recoit tous)
   Chaque message traite par TOUS les consumers

3. Fan-Out:
   Producer --> [Router] --> Queue 1 --> Consumer type A
                        --> Queue 2 --> Consumer type B
   Messages routes selon leur type
```

---

## Complexite et Trade-offs

| Aspect | Valeur |
|--------|--------|
| Produce | O(1) ou O(wait) si bounded |
| Consume | O(1) ou O(wait) si vide |
| Memoire | O(queue_size) |

### Avantages

- Decouplage temporel
- Absorption des pics
- Scalabilite independante

### Inconvenients

- Latence ajoutee
- Complexite de gestion queue
- Perte possible si crash

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Vitesses production/consommation differentes | Oui |
| Traitement async en arriere-plan | Oui |
| Pics de charge | Oui |
| Latence minimale critique | Non |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Thread Pool** | Consumers = workers du pool |
| **Buffer** | Queue = buffer |
| **Observer** | Push-based vs pull-based |
| **Pipeline** | Chaine de producer-consumer |

---

## Sources

- [Enterprise Integration Patterns](https://www.enterpriseintegrationpatterns.com/)
- [RabbitMQ Tutorials](https://www.rabbitmq.com/getstarted.html)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
