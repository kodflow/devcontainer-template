# Thread Pool

Pattern de gestion d'un pool de workers pour executer des taches en parallele.

---

## Qu'est-ce qu'un Thread Pool ?

> Maintenir un ensemble de workers pre-crees pour traiter des taches sans overhead de creation.

```
+--------------------------------------------------------------+
|                       Thread Pool                             |
|                                                               |
|  Task Queue                    Workers                        |
|  +--------+                                                   |
|  | Task 1 | ----+          +----------+                       |
|  +--------+     |          | Worker 1 | --> execute Task 1    |
|  | Task 2 | ----+--------->+----------+                       |
|  +--------+     |          | Worker 2 | --> execute Task 2    |
|  | Task 3 | ----+          +----------+                       |
|  +--------+     |          | Worker 3 | --> (idle)            |
|  | Task 4 | ----+          +----------+                       |
|  +--------+                | Worker 4 | --> execute Task 3    |
|  |  ...   |                +----------+                       |
|  +--------+                                                   |
|                                                               |
|  maxWorkers: 4     activeWorkers: 3     queueSize: N          |
+--------------------------------------------------------------+
```

**Pourquoi :**

- Eviter le cout de creation/destruction de threads
- Limiter la concurrence (eviter surcharge)
- Reutiliser les ressources

---

## Implementation TypeScript

### ThreadPool basique

```typescript
class ThreadPool {
  private taskQueue: Array<() => Promise<void>> = [];
  private activeWorkers = 0;
  private readonly maxWorkers: number;

  constructor(maxWorkers: number = navigator.hardwareConcurrency || 4) {
    this.maxWorkers = maxWorkers;
  }

  async execute<T>(task: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const wrappedTask = async () => {
        try {
          const result = await task();
          resolve(result);
        } catch (error) {
          reject(error);
        }
      };

      this.taskQueue.push(wrappedTask);
      this.processQueue();
    });
  }

  private async processQueue(): Promise<void> {
    if (this.activeWorkers >= this.maxWorkers) {
      return;
    }

    const task = this.taskQueue.shift();
    if (!task) {
      return;
    }

    this.activeWorkers++;

    try {
      await task();
    } finally {
      this.activeWorkers--;
      this.processQueue(); // Traiter la tache suivante
    }
  }

  get stats() {
    return {
      active: this.activeWorkers,
      queued: this.taskQueue.length,
      maxWorkers: this.maxWorkers,
    };
  }
}

// Usage
const pool = new ThreadPool(4);

const results = await Promise.all(
  urls.map((url) => pool.execute(() => fetch(url).then((r) => r.json()))),
);
```

### ThreadPool avec priorite

```typescript
interface PriorityTask<T> {
  priority: number;
  task: () => Promise<T>;
  resolve: (value: T) => void;
  reject: (error: Error) => void;
}

class PriorityThreadPool {
  private queue: PriorityTask<unknown>[] = [];
  private activeWorkers = 0;

  constructor(private maxWorkers: number) {}

  async execute<T>(
    task: () => Promise<T>,
    priority: number = 0,
  ): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const priorityTask: PriorityTask<T> = {
        priority,
        task,
        resolve,
        reject,
      };

      // Inserer par priorite (plus haut = plus prioritaire)
      const index = this.queue.findIndex((t) => t.priority < priority);
      if (index === -1) {
        this.queue.push(priorityTask as PriorityTask<unknown>);
      } else {
        this.queue.splice(index, 0, priorityTask as PriorityTask<unknown>);
      }

      this.processQueue();
    });
  }

  private async processQueue(): Promise<void> {
    if (this.activeWorkers >= this.maxWorkers) return;

    const item = this.queue.shift();
    if (!item) return;

    this.activeWorkers++;

    try {
      const result = await item.task();
      item.resolve(result);
    } catch (error) {
      item.reject(error as Error);
    } finally {
      this.activeWorkers--;
      this.processQueue();
    }
  }
}
```

### ThreadPool avec timeout et abort

```typescript
class RobustThreadPool {
  private queue: Array<{
    task: () => Promise<unknown>;
    resolve: (value: unknown) => void;
    reject: (error: Error) => void;
    timeout?: number;
    signal?: AbortSignal;
  }> = [];
  private activeWorkers = 0;

  constructor(private maxWorkers: number) {}

  async execute<T>(
    task: () => Promise<T>,
    options: { timeout?: number; signal?: AbortSignal } = {},
  ): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      // Verifier abort avant meme de queuer
      if (options.signal?.aborted) {
        reject(new Error('Aborted'));
        return;
      }

      this.queue.push({
        task,
        resolve: resolve as (v: unknown) => void,
        reject,
        ...options,
      });

      this.processQueue();
    });
  }

  private async processQueue(): Promise<void> {
    if (this.activeWorkers >= this.maxWorkers) return;

    const item = this.queue.shift();
    if (!item) return;

    // Verifier abort
    if (item.signal?.aborted) {
      item.reject(new Error('Aborted'));
      this.processQueue();
      return;
    }

    this.activeWorkers++;

    try {
      const result = await this.executeWithTimeout(
        item.task,
        item.timeout,
        item.signal,
      );
      item.resolve(result);
    } catch (error) {
      item.reject(error as Error);
    } finally {
      this.activeWorkers--;
      this.processQueue();
    }
  }

  private async executeWithTimeout<T>(
    task: () => Promise<T>,
    timeout?: number,
    signal?: AbortSignal,
  ): Promise<T> {
    if (!timeout) {
      return task();
    }

    return Promise.race([
      task(),
      new Promise<T>((_, reject) => {
        const timer = setTimeout(() => {
          reject(new Error('Task timeout'));
        }, timeout);

        signal?.addEventListener('abort', () => {
          clearTimeout(timer);
          reject(new Error('Aborted'));
        });
      }),
    ]);
  }
}
```

---

## Web Workers Pool

```typescript
class WorkerPool {
  private workers: Worker[] = [];
  private available: Worker[] = [];
  private pending: Array<{
    task: unknown;
    resolve: (result: unknown) => void;
    reject: (error: Error) => void;
  }> = [];

  constructor(
    workerScript: string,
    size: number = navigator.hardwareConcurrency,
  ) {
    for (let i = 0; i < size; i++) {
      const worker = new Worker(workerScript);
      this.workers.push(worker);
      this.available.push(worker);
    }
  }

  async execute<T>(task: unknown): Promise<T> {
    return new Promise((resolve, reject) => {
      const worker = this.available.pop();

      if (worker) {
        this.runOnWorker(worker, task, resolve, reject);
      } else {
        this.pending.push({ task, resolve, reject });
      }
    });
  }

  private runOnWorker(
    worker: Worker,
    task: unknown,
    resolve: (result: unknown) => void,
    reject: (error: Error) => void,
  ): void {
    const handler = (e: MessageEvent) => {
      worker.removeEventListener('message', handler);
      worker.removeEventListener('error', errorHandler);

      resolve(e.data);
      this.releaseWorker(worker);
    };

    const errorHandler = (e: ErrorEvent) => {
      worker.removeEventListener('message', handler);
      worker.removeEventListener('error', errorHandler);

      reject(new Error(e.message));
      this.releaseWorker(worker);
    };

    worker.addEventListener('message', handler);
    worker.addEventListener('error', errorHandler);
    worker.postMessage(task);
  }

  private releaseWorker(worker: Worker): void {
    const pending = this.pending.shift();
    if (pending) {
      this.runOnWorker(worker, pending.task, pending.resolve, pending.reject);
    } else {
      this.available.push(worker);
    }
  }

  terminate(): void {
    this.workers.forEach((w) => w.terminate());
    this.workers = [];
    this.available = [];
  }
}
```

---

## Complexite et Trade-offs

| Aspect | Valeur |
|--------|--------|
| Submit task | O(1) |
| Memoire | O(maxWorkers + queueSize) |
| Context switch | Reduit vs creation threads |

### Avantages

- Controle de la concurrence
- Reutilisation des workers
- Backpressure naturelle (queue)

### Inconvenients

- Dimensionnement delicat
- Deadlock si taches interdependantes
- Queue non bornee = memory leak

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Requetes HTTP paralleles | Oui |
| Calculs CPU-intensive | Oui (Worker Pool) |
| Traitement batch | Oui |
| Taches dependantes entre elles | Prudence (deadlock) |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Object Pool** | Meme concept, objets vs workers |
| **Producer-Consumer** | Queue entre producteur et pool |
| **Semaphore** | Limitation similaire |
| **Fork-Join** | Diviser taches pour le pool |

---

## Sources

- [Java ThreadPoolExecutor](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/ThreadPoolExecutor.html)
- [Node.js Worker Threads](https://nodejs.org/api/worker_threads.html)
- [Web Workers API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Workers_API)
