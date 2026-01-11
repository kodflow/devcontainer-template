# Concurrency Patterns

Patterns pour la programmation concurrente et parallèle.

## Les 15 Patterns

### 1. Thread Pool

> Pool de workers pour exécuter des tâches en parallèle.

```typescript
class ThreadPool {
  private workers: Worker[] = [];
  private taskQueue: (() => Promise<any>)[] = [];
  private activeWorkers = 0;

  constructor(private maxWorkers: number = navigator.hardwareConcurrency) {}

  async execute<T>(task: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      const wrappedTask = async () => {
        try {
          resolve(await task());
        } catch (e) {
          reject(e);
        }
      };

      if (this.activeWorkers < this.maxWorkers) {
        this.runTask(wrappedTask);
      } else {
        this.taskQueue.push(wrappedTask);
      }
    });
  }

  private async runTask(task: () => Promise<any>) {
    this.activeWorkers++;
    await task();
    this.activeWorkers--;

    const nextTask = this.taskQueue.shift();
    if (nextTask) {
      this.runTask(nextTask);
    }
  }
}

// Usage
const pool = new ThreadPool(4);
const results = await Promise.all(
  urls.map((url) => pool.execute(() => fetch(url))),
);
```

**Quand :** Limiter la concurrence, CPU-bound tasks, rate limiting.
**Lié à :** Object Pool, Executor.

---

### 2. Producer-Consumer

> Séparer production et consommation via une queue.

```typescript
class ProducerConsumer<T> {
  private queue: T[] = [];
  private consumers: ((item: T) => void)[] = [];
  private maxSize: number;

  constructor(maxSize = Infinity) {
    this.maxSize = maxSize;
  }

  produce(item: T): boolean {
    if (this.queue.length >= this.maxSize) {
      return false; // Queue pleine
    }

    const consumer = this.consumers.shift();
    if (consumer) {
      consumer(item); // Consommateur en attente
    } else {
      this.queue.push(item);
    }
    return true;
  }

  consume(): Promise<T> {
    return new Promise((resolve) => {
      const item = this.queue.shift();
      if (item !== undefined) {
        resolve(item);
      } else {
        this.consumers.push(resolve);
      }
    });
  }
}

// Usage
const queue = new ProducerConsumer<Task>();

// Producer
setInterval(() => {
  queue.produce({ id: Date.now(), data: 'task' });
}, 100);

// Consumers
for (let i = 0; i < 3; i++) {
  (async () => {
    while (true) {
      const task = await queue.consume();
      await processTask(task);
    }
  })();
}
```

**Quand :** Message queues, work distribution, async processing.
**Lié à :** Buffer, Queue, Observer.

---

### 3. Future / Promise

> Résultat asynchrone différé.

```typescript
// Deferred pattern - Promise contrôlable
class Deferred<T> {
  readonly promise: Promise<T>;
  resolve!: (value: T) => void;
  reject!: (reason: any) => void;

  constructor() {
    this.promise = new Promise((resolve, reject) => {
      this.resolve = resolve;
      this.reject = reject;
    });
  }
}

// Usage
const deferred = new Deferred<string>();

// Quelque part plus tard...
deferred.resolve('result');

// Ailleurs...
const result = await deferred.promise;

// CompletableFuture pattern
class CompletableFuture<T> {
  private deferred = new Deferred<T>();

  then<U>(fn: (value: T) => U | Promise<U>): CompletableFuture<U> {
    const next = new CompletableFuture<U>();
    this.deferred.promise.then(fn).then(
      (v) => next.complete(v),
      (e) => next.completeExceptionally(e),
    );
    return next;
  }

  complete(value: T) {
    this.deferred.resolve(value);
  }

  completeExceptionally(error: any) {
    this.deferred.reject(error);
  }

  get(): Promise<T> {
    return this.deferred.promise;
  }
}
```

**Quand :** Async operations, lazy evaluation, cancellation.
**Lié à :** Observer, Callback.

---

### 4. Mutex / Lock

> Accès exclusif à une ressource partagée.

```typescript
class Mutex {
  private locked = false;
  private waiting: (() => void)[] = [];

  async acquire(): Promise<void> {
    if (!this.locked) {
      this.locked = true;
      return;
    }

    return new Promise((resolve) => {
      this.waiting.push(resolve);
    });
  }

  release() {
    const next = this.waiting.shift();
    if (next) {
      next();
    } else {
      this.locked = false;
    }
  }

  async withLock<T>(fn: () => Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await fn();
    } finally {
      this.release();
    }
  }
}

// Usage
const mutex = new Mutex();
let counter = 0;

async function increment() {
  await mutex.withLock(async () => {
    const current = counter;
    await delay(10); // Simulate work
    counter = current + 1;
  });
}
```

**Quand :** Race conditions, ressource partagée unique.
**Lié à :** Semaphore, Read-Write Lock.

---

### 5. Semaphore

> Limiter l'accès concurrent à N ressources.

```typescript
class Semaphore {
  private permits: number;
  private waiting: (() => void)[] = [];

  constructor(permits: number) {
    this.permits = permits;
  }

  async acquire(count = 1): Promise<void> {
    if (this.permits >= count) {
      this.permits -= count;
      return;
    }

    return new Promise((resolve) => {
      this.waiting.push(() => {
        this.permits -= count;
        resolve();
      });
    });
  }

  release(count = 1) {
    this.permits += count;
    while (this.waiting.length > 0 && this.permits > 0) {
      const next = this.waiting.shift()!;
      next();
    }
  }

  async withPermit<T>(fn: () => Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await fn();
    } finally {
      this.release();
    }
  }
}

// Usage - Limiter à 5 requêtes simultanées
const apiSemaphore = new Semaphore(5);

async function fetchWithLimit(url: string) {
  return apiSemaphore.withPermit(() => fetch(url));
}
```

**Quand :** Rate limiting, connection pools, resource limiting.
**Lié à :** Mutex, Bulkhead.

---

### 6. Read-Write Lock

> Plusieurs lecteurs OU un seul écrivain.

```typescript
class ReadWriteLock {
  private readers = 0;
  private writer = false;
  private writerWaiting: (() => void)[] = [];
  private readerWaiting: (() => void)[] = [];

  async acquireRead(): Promise<void> {
    if (!this.writer && this.writerWaiting.length === 0) {
      this.readers++;
      return;
    }
    return new Promise((resolve) => {
      this.readerWaiting.push(() => {
        this.readers++;
        resolve();
      });
    });
  }

  releaseRead() {
    this.readers--;
    if (this.readers === 0 && this.writerWaiting.length > 0) {
      this.writer = true;
      this.writerWaiting.shift()!();
    }
  }

  async acquireWrite(): Promise<void> {
    if (!this.writer && this.readers === 0) {
      this.writer = true;
      return;
    }
    return new Promise((resolve) => {
      this.writerWaiting.push(() => {
        this.writer = true;
        resolve();
      });
    });
  }

  releaseWrite() {
    this.writer = false;
    // Priorité aux lecteurs en attente
    while (this.readerWaiting.length > 0) {
      this.readerWaiting.shift()!();
    }
    if (this.readers === 0 && this.writerWaiting.length > 0) {
      this.writerWaiting.shift()!();
    }
  }
}
```

**Quand :** Caches, configurations, données lues fréquemment.
**Lié à :** Mutex, Cache.

---

### 7. Actor Model

> Entités isolées communiquant par messages.

```typescript
type Message = { type: string; payload?: any };

abstract class Actor {
  private mailbox: Message[] = [];
  private processing = false;

  protected abstract receive(message: Message): Promise<void>;

  send(message: Message) {
    this.mailbox.push(message);
    this.processNext();
  }

  private async processNext() {
    if (this.processing) return;
    this.processing = true;

    while (this.mailbox.length > 0) {
      const message = this.mailbox.shift()!;
      try {
        await this.receive(message);
      } catch (error) {
        console.error('Actor error:', error);
      }
    }

    this.processing = false;
  }
}

// Usage
class CounterActor extends Actor {
  private count = 0;

  async receive(message: Message) {
    switch (message.type) {
      case 'increment':
        this.count++;
        break;
      case 'get':
        message.payload.callback(this.count);
        break;
    }
  }
}

const counter = new CounterActor();
counter.send({ type: 'increment' });
counter.send({
  type: 'get',
  payload: { callback: (count: number) => console.log(count) },
});
```

**Quand :** Distributed systems, isolation, fault tolerance.
**Lié à :** Message Queue, Observer.

---

### 8. Active Object

> Découpler invocation et exécution de méthode.

```typescript
class ActiveObject<T> {
  private queue: (() => Promise<void>)[] = [];
  private processing = false;

  constructor(private target: T) {}

  invoke<R>(method: (target: T) => Promise<R>): Promise<R> {
    return new Promise((resolve, reject) => {
      this.queue.push(async () => {
        try {
          resolve(await method(this.target));
        } catch (e) {
          reject(e);
        }
      });
      this.processQueue();
    });
  }

  private async processQueue() {
    if (this.processing) return;
    this.processing = true;

    while (this.queue.length > 0) {
      await this.queue.shift()!();
    }

    this.processing = false;
  }
}

// Usage
class DatabaseService {
  async query(sql: string) {
    /* ... */
  }
}

const activeDb = new ActiveObject(new DatabaseService());
// Toutes les queries sont sérialisées
await activeDb.invoke((db) => db.query('SELECT 1'));
```

**Quand :** Sérialiser les accès, thread-safety.
**Lié à :** Actor, Command.

---

### 9. Monitor

> Synchronisation avec conditions.

```typescript
class Monitor {
  private mutex = new Mutex();
  private conditions = new Map<string, (() => void)[]>();

  async enter() {
    await this.mutex.acquire();
  }

  leave() {
    this.mutex.release();
  }

  async wait(condition: string) {
    return new Promise<void>((resolve) => {
      if (!this.conditions.has(condition)) {
        this.conditions.set(condition, []);
      }
      this.conditions.get(condition)!.push(resolve);
      this.mutex.release();
    });
  }

  signal(condition: string) {
    const waiters = this.conditions.get(condition);
    if (waiters && waiters.length > 0) {
      waiters.shift()!();
    }
  }

  signalAll(condition: string) {
    const waiters = this.conditions.get(condition);
    if (waiters) {
      waiters.forEach((w) => w());
      this.conditions.set(condition, []);
    }
  }
}
```

**Quand :** Producer-consumer, bounded buffer, state machines.
**Lié à :** Mutex, Condition Variable.

---

### 10. Barrier

> Synchroniser plusieurs threads à un point.

```typescript
class Barrier {
  private count: number;
  private waiting: (() => void)[] = [];

  constructor(private parties: number) {
    this.count = parties;
  }

  async await(): Promise<void> {
    this.count--;

    if (this.count === 0) {
      // Dernier arrivé - libère tous
      this.waiting.forEach((w) => w());
      this.waiting = [];
      this.count = this.parties;
      return;
    }

    return new Promise((resolve) => {
      this.waiting.push(resolve);
    });
  }
}

// Usage
const barrier = new Barrier(3);

async function worker(id: number) {
  console.log(`Worker ${id} phase 1 done`);
  await barrier.await();
  console.log(`Worker ${id} phase 2 starting`);
}

// Tous attendent que les 3 aient terminé phase 1
await Promise.all([worker(1), worker(2), worker(3)]);
```

**Quand :** Phases synchronisées, parallel algorithms.
**Lié à :** CountDownLatch, CyclicBarrier.

---

### 11. Fork-Join

> Diviser pour régner en parallèle.

```typescript
class ForkJoin {
  constructor(private pool: ThreadPool) {}

  async compute<T, R>(
    items: T[],
    task: (item: T) => Promise<R>,
    threshold = 10,
  ): Promise<R[]> {
    if (items.length <= threshold) {
      return Promise.all(items.map(task));
    }

    const mid = Math.floor(items.length / 2);
    const [left, right] = await Promise.all([
      this.compute(items.slice(0, mid), task, threshold),
      this.compute(items.slice(mid), task, threshold),
    ]);

    return [...left, ...right];
  }
}

// Usage - Parallel merge sort
async function parallelSort(arr: number[]): Promise<number[]> {
  if (arr.length <= 1) return arr;

  const mid = Math.floor(arr.length / 2);
  const [left, right] = await Promise.all([
    parallelSort(arr.slice(0, mid)),
    parallelSort(arr.slice(mid)),
  ]);

  return merge(left, right);
}
```

**Quand :** Divide and conquer, recursive parallelism.
**Lié à :** Thread Pool, Map-Reduce.

---

### 12. Pipeline

> Chaîne de stages de traitement.

```typescript
type Stage<I, O> = (input: I) => Promise<O>;

class Pipeline<I, O> {
  private stages: Stage<any, any>[] = [];

  addStage<N>(stage: Stage<O, N>): Pipeline<I, N> {
    this.stages.push(stage);
    return this as any;
  }

  async execute(input: I): Promise<O> {
    let result: any = input;
    for (const stage of this.stages) {
      result = await stage(result);
    }
    return result;
  }

  // Stream avec backpressure
  async* stream(inputs: AsyncIterable<I>): AsyncGenerator<O> {
    for await (const input of inputs) {
      yield await this.execute(input);
    }
  }
}

// Usage
const imageProcessor = new Pipeline<Buffer, string>()
  .addStage(async (buf) => await decode(buf))
  .addStage(async (img) => await resize(img, 800))
  .addStage(async (img) => await compress(img))
  .addStage(async (img) => await upload(img));

const url = await imageProcessor.execute(imageBuffer);
```

**Quand :** Data processing, ETL, stream processing.
**Lié à :** Chain of Responsibility, Decorator.

---

### 13. Scheduler

> Planifier l'exécution des tâches.

```typescript
interface ScheduledTask {
  id: string;
  execute: () => Promise<void>;
  nextRun: number;
  interval?: number;
}

class Scheduler {
  private tasks = new Map<string, ScheduledTask>();
  private timer: ReturnType<typeof setTimeout> | null = null;

  schedule(task: ScheduledTask) {
    this.tasks.set(task.id, task);
    this.reschedule();
  }

  cancel(id: string) {
    this.tasks.delete(id);
    this.reschedule();
  }

  private reschedule() {
    if (this.timer) clearTimeout(this.timer);

    const tasks = [...this.tasks.values()].sort((a, b) => a.nextRun - b.nextRun);
    if (tasks.length === 0) return;

    const next = tasks[0];
    const delay = Math.max(0, next.nextRun - Date.now());

    this.timer = setTimeout(async () => {
      await next.execute();
      if (next.interval) {
        next.nextRun = Date.now() + next.interval;
      } else {
        this.tasks.delete(next.id);
      }
      this.reschedule();
    }, delay);
  }
}

// Usage
const scheduler = new Scheduler();
scheduler.schedule({
  id: 'cleanup',
  execute: async () => await cleanupOldFiles(),
  nextRun: Date.now() + 60000,
  interval: 3600000, // Toutes les heures
});
```

**Quand :** Cron jobs, delayed tasks, periodic tasks.
**Lié à :** Command, Timer.

---

### 14. Double-Checked Locking

> Initialisation thread-safe performante.

```typescript
class LazyInitialization<T> {
  private instance: T | null = null;
  private initialized = false;
  private mutex = new Mutex();

  constructor(private factory: () => Promise<T>) {}

  async get(): Promise<T> {
    // First check without lock
    if (this.initialized) {
      return this.instance!;
    }

    await this.mutex.acquire();
    try {
      // Second check with lock
      if (!this.initialized) {
        this.instance = await this.factory();
        this.initialized = true;
      }
      return this.instance!;
    } finally {
      this.mutex.release();
    }
  }
}

// Usage
const dbConnection = new LazyInitialization(async () => {
  return await Database.connect(config);
});

const db = await dbConnection.get();
```

**Quand :** Singleton thread-safe, lazy initialization coûteuse.
**Lié à :** Singleton, Lazy Loading.

---

### 15. Async Queue

> Queue avec traitement asynchrone ordonné.

```typescript
class AsyncQueue<T> {
  private queue: T[] = [];
  private processing = false;
  private processor: (item: T) => Promise<void>;
  private concurrency: number;
  private activeCount = 0;

  constructor(
    processor: (item: T) => Promise<void>,
    concurrency = 1,
  ) {
    this.processor = processor;
    this.concurrency = concurrency;
  }

  push(item: T) {
    this.queue.push(item);
    this.processNext();
  }

  private async processNext() {
    while (
      this.queue.length > 0 &&
      this.activeCount < this.concurrency
    ) {
      const item = this.queue.shift()!;
      this.activeCount++;

      this.processor(item)
        .finally(() => {
          this.activeCount--;
          this.processNext();
        });
    }
  }

  async drain(): Promise<void> {
    return new Promise((resolve) => {
      const check = () => {
        if (this.queue.length === 0 && this.activeCount === 0) {
          resolve();
        } else {
          setTimeout(check, 10);
        }
      };
      check();
    });
  }
}

// Usage
const emailQueue = new AsyncQueue<Email>(
  async (email) => await sendEmail(email),
  5, // 5 emails en parallèle max
);

emailQueue.push({ to: 'user@example.com', subject: 'Hello' });
```

**Quand :** Job queues, background tasks, rate limiting.
**Lié à :** Producer-Consumer, Thread Pool.

---

## Tableau de décision

| Besoin | Pattern |
|--------|---------|
| Limiter workers | Thread Pool |
| Découpler prod/cons | Producer-Consumer |
| Résultat différé | Future/Promise |
| Accès exclusif | Mutex |
| N accès simultanés | Semaphore |
| Multi lecteurs / 1 écrivain | Read-Write Lock |
| Isolation par messages | Actor |
| Sérialiser méthodes | Active Object |
| Sync avec conditions | Monitor |
| Sync à un point | Barrier |
| Divide & conquer | Fork-Join |
| Stages de traitement | Pipeline |
| Tâches planifiées | Scheduler |
| Init thread-safe | Double-Checked Locking |
| Queue avec concurrence | Async Queue |

## Sources

- [Concurrency Patterns - Wikipedia](https://en.wikipedia.org/wiki/Concurrency_pattern)
- [Java Concurrency in Practice](https://jcip.net/)
- [Go Concurrency Patterns](https://go.dev/blog/pipelines)
