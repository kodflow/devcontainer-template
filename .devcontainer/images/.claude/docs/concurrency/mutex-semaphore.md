# Mutex et Semaphore

Primitives de synchronisation pour controler l'acces aux ressources partagees.

---

## Vue d'ensemble

```
+--------------------------------------------------------------+
|              Mutex vs Semaphore                               |
|                                                               |
|  MUTEX (Mutual Exclusion)         SEMAPHORE                   |
|  Permits: 1                       Permits: N                  |
|                                                               |
|  +--------+                       +--------+                  |
|  |Resource|                       |Resource|                  |
|  +----+---+                       +----+---+                  |
|       |                                |                      |
|       v                                v                      |
|  [1 thread]                       [N threads max]             |
|                                                               |
|  Usage:                           Usage:                      |
|  - Section critique               - Connection pool           |
|  - Ecriture fichier unique        - Rate limiting             |
|  - Singleton init                 - Resource limiting         |
|                                                               |
+--------------------------------------------------------------+
```

---

## Mutex

> Assure qu'une seule tache peut acceder a une ressource a la fois.

```typescript
class Mutex {
  private locked = false;
  private waiting: Array<() => void> = [];

  async acquire(): Promise<void> {
    if (!this.locked) {
      this.locked = true;
      return;
    }

    return new Promise<void>((resolve) => {
      this.waiting.push(resolve);
    });
  }

  release(): void {
    if (this.waiting.length > 0) {
      const next = this.waiting.shift()!;
      next();
    } else {
      this.locked = false;
    }
  }

  async withLock<T>(fn: () => T | Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await fn();
    } finally {
      this.release();
    }
  }

  get isLocked(): boolean {
    return this.locked;
  }
}

// Usage
const fileMutex = new Mutex();

async function writeToFile(content: string): Promise<void> {
  await fileMutex.withLock(async () => {
    await fs.appendFile('log.txt', content);
  });
}

// Appels concurrents - serialises par le mutex
await Promise.all([
  writeToFile('Line 1\n'),
  writeToFile('Line 2\n'),
  writeToFile('Line 3\n'),
]);
```

### Mutex avec timeout

```typescript
class TimedMutex extends Mutex {
  async acquireWithTimeout(timeoutMs: number): Promise<boolean> {
    const timeoutPromise = new Promise<boolean>((resolve) => {
      setTimeout(() => resolve(false), timeoutMs);
    });

    const acquirePromise = this.acquire().then(() => true);

    const acquired = await Promise.race([acquirePromise, timeoutPromise]);

    if (!acquired) {
      // Retirer de la waiting list si present
      return false;
    }

    return true;
  }
}
```

---

## Semaphore

> Limite l'acces concurrent a N ressources.

```typescript
class Semaphore {
  private permits: number;
  private waiting: Array<() => void> = [];

  constructor(permits: number) {
    if (permits < 1) throw new Error('Permits must be >= 1');
    this.permits = permits;
  }

  async acquire(count: number = 1): Promise<void> {
    if (this.permits >= count) {
      this.permits -= count;
      return;
    }

    return new Promise<void>((resolve) => {
      const tryAcquire = () => {
        if (this.permits >= count) {
          this.permits -= count;
          resolve();
        } else {
          this.waiting.push(tryAcquire);
        }
      };
      this.waiting.push(tryAcquire);
    });
  }

  release(count: number = 1): void {
    this.permits += count;

    // Reveiller les waiters
    while (this.waiting.length > 0 && this.permits > 0) {
      const tryAcquire = this.waiting.shift()!;
      tryAcquire();
    }
  }

  async withPermit<T>(fn: () => T | Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await fn();
    } finally {
      this.release();
    }
  }

  get available(): number {
    return this.permits;
  }
}

// Usage - Limiter les requetes API
const apiSemaphore = new Semaphore(5); // Max 5 requetes simultanees

async function fetchData(url: string): Promise<Response> {
  return apiSemaphore.withPermit(() => fetch(url));
}

// 100 requetes mais max 5 en parallele
const urls = generateUrls(100);
const results = await Promise.all(urls.map(fetchData));
```

---

## Counting Semaphore avance

```typescript
class CountingSemaphore {
  private permits: number;
  private maxPermits: number;
  private queue: Array<{
    count: number;
    resolve: () => void;
  }> = [];

  constructor(initialPermits: number, maxPermits: number = Infinity) {
    this.permits = initialPermits;
    this.maxPermits = maxPermits;
  }

  async acquire(count: number = 1): Promise<void> {
    if (count > this.maxPermits) {
      throw new Error(`Cannot acquire ${count} permits (max: ${this.maxPermits})`);
    }

    if (this.permits >= count && this.queue.length === 0) {
      this.permits -= count;
      return;
    }

    return new Promise<void>((resolve) => {
      this.queue.push({ count, resolve });
    });
  }

  release(count: number = 1): void {
    this.permits = Math.min(this.permits + count, this.maxPermits);
    this.processQueue();
  }

  private processQueue(): void {
    while (this.queue.length > 0) {
      const first = this.queue[0];
      if (this.permits >= first.count) {
        this.permits -= first.count;
        this.queue.shift();
        first.resolve();
      } else {
        break;
      }
    }
  }

  tryAcquire(count: number = 1): boolean {
    if (this.permits >= count) {
      this.permits -= count;
      return true;
    }
    return false;
  }

  drainPermits(): number {
    const drained = this.permits;
    this.permits = 0;
    return drained;
  }
}
```

---

## Patterns courants

### Rate Limiter

```typescript
class RateLimiter {
  private semaphore: Semaphore;
  private refillInterval: ReturnType<typeof setInterval>;

  constructor(
    private maxRequests: number,
    private windowMs: number,
  ) {
    this.semaphore = new Semaphore(maxRequests);

    // Refill periodique
    this.refillInterval = setInterval(() => {
      const toRefill = maxRequests - this.semaphore.available;
      if (toRefill > 0) {
        this.semaphore.release(toRefill);
      }
    }, windowMs);
  }

  async acquire(): Promise<void> {
    await this.semaphore.acquire();
  }

  stop(): void {
    clearInterval(this.refillInterval);
  }
}
```

### Resource Guard

```typescript
class ResourceGuard<T> {
  private mutex = new Mutex();

  constructor(private resource: T) {}

  async use<R>(fn: (resource: T) => R | Promise<R>): Promise<R> {
    return this.mutex.withLock(() => fn(this.resource));
  }
}

// Usage
const fileGuard = new ResourceGuard(new FileHandle('data.json'));

await fileGuard.use(async (file) => {
  await file.write(JSON.stringify(data));
});
```

---

## Complexite et Trade-offs

| Operation | Mutex | Semaphore |
|-----------|-------|-----------|
| acquire (no wait) | O(1) | O(1) |
| release | O(1) | O(waiting) |
| Memoire | O(waiting) | O(waiting) |

### Mutex vs Semaphore

| Critere | Mutex | Semaphore |
|---------|-------|-----------|
| Permits | 1 | N |
| Owner | Oui (celui qui lock) | Non |
| Usage | Section critique | Resource pool |

### Avantages

- Prevention race conditions
- Controle de concurrence
- Simple a comprendre

### Inconvenients

- Risque de deadlock
- Contention = latence
- Priority inversion possible

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Acces exclusif a une ressource | Mutex |
| Pool de N ressources | Semaphore(N) |
| Rate limiting | Semaphore + timer |
| Read-heavy workload | Read-Write Lock |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Read-Write Lock** | Specialisation pour lectures |
| **Monitor** | Mutex + conditions |
| **Object Pool** | Semaphore pour limiter |
| **Circuit Breaker** | Protection differente |

---

## Sources

- [The Little Book of Semaphores](https://greenteapress.com/wp/semaphores/)
- [Java Semaphore](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/Semaphore.html)
- [OS Mutex vs Semaphore](https://www.geeksforgeeks.org/mutex-vs-semaphore/)
