# Future / Promise

Pattern representant une valeur qui sera disponible dans le futur.

---

## Qu'est-ce que Future/Promise ?

> Placeholder pour un resultat asynchrone, permettant de composer des operations.

```
+--------------------------------------------------------------+
|                    Future / Promise                           |
|                                                               |
|  Creation          Pending           Settled                  |
|                                                               |
|  new Promise() --> [ Pending ] -+-> [ Fulfilled ] --> value   |
|       |                         |                             |
|       |                         +-> [ Rejected  ] --> error   |
|       |                                                       |
|       +-- resolve(value) ou reject(error)                     |
|                                                               |
|  Chaining:                                                    |
|                                                               |
|  promise                                                      |
|    .then(fn1)  --> nouvelle Promise                           |
|    .then(fn2)  --> nouvelle Promise                           |
|    .catch(err) --> gestion erreur                             |
|    .finally()  --> cleanup                                    |
|                                                               |
+--------------------------------------------------------------+
```

**Pourquoi :**
- Representer des operations asynchrones
- Composer des operations sequentielles/paralleles
- Gerer les erreurs de maniere uniforme

---

## Implementation TypeScript

### Deferred (Promise controlable)

```typescript
class Deferred<T> {
  readonly promise: Promise<T>;
  resolve!: (value: T | PromiseLike<T>) => void;
  reject!: (reason?: unknown) => void;
  private settled = false;

  constructor() {
    this.promise = new Promise<T>((resolve, reject) => {
      this.resolve = (value) => {
        if (!this.settled) {
          this.settled = true;
          resolve(value);
        }
      };
      this.reject = (reason) => {
        if (!this.settled) {
          this.settled = true;
          reject(reason);
        }
      };
    });
  }

  get isSettled(): boolean {
    return this.settled;
  }
}

// Usage
const deferred = new Deferred<string>();

// Quelque part...
setTimeout(() => {
  deferred.resolve('Hello!');
}, 1000);

// Ailleurs...
const result = await deferred.promise;
```

### CompletableFuture (Java-style)

```typescript
class CompletableFuture<T> {
  private deferred = new Deferred<T>();
  private callbacks: Array<(value: T) => void> = [];

  get promise(): Promise<T> {
    return this.deferred.promise;
  }

  complete(value: T): boolean {
    if (this.deferred.isSettled) return false;
    this.deferred.resolve(value);
    this.callbacks.forEach((cb) => cb(value));
    return true;
  }

  completeExceptionally(error: Error): boolean {
    if (this.deferred.isSettled) return false;
    this.deferred.reject(error);
    return true;
  }

  thenApply<U>(fn: (value: T) => U): CompletableFuture<U> {
    const next = new CompletableFuture<U>();
    this.promise
      .then((v) => next.complete(fn(v)))
      .catch((e) => next.completeExceptionally(e));
    return next;
  }

  thenCompose<U>(fn: (value: T) => CompletableFuture<U>): CompletableFuture<U> {
    const next = new CompletableFuture<U>();
    this.promise
      .then((v) => fn(v).promise)
      .then((u) => next.complete(u))
      .catch((e) => next.completeExceptionally(e));
    return next;
  }

  static allOf<T>(...futures: CompletableFuture<T>[]): CompletableFuture<T[]> {
    const result = new CompletableFuture<T[]>();
    Promise.all(futures.map((f) => f.promise))
      .then((values) => result.complete(values))
      .catch((e) => result.completeExceptionally(e));
    return result;
  }

  static anyOf<T>(...futures: CompletableFuture<T>[]): CompletableFuture<T> {
    const result = new CompletableFuture<T>();
    Promise.race(futures.map((f) => f.promise))
      .then((value) => result.complete(value))
      .catch((e) => result.completeExceptionally(e));
    return result;
  }
}
```

---

## Patterns de composition

### Sequential (then chain)

```typescript
async function processUser(userId: string): Promise<Report> {
  const user = await fetchUser(userId);
  const orders = await fetchOrders(user.id);
  const report = await generateReport(user, orders);
  return report;
}

// Equivalent Promise chain
function processUserPromise(userId: string): Promise<Report> {
  return fetchUser(userId)
    .then((user) =>
      fetchOrders(user.id).then((orders) => ({ user, orders })),
    )
    .then(({ user, orders }) => generateReport(user, orders));
}
```

### Parallel (Promise.all)

```typescript
async function fetchDashboard(userId: string): Promise<Dashboard> {
  const [user, notifications, stats] = await Promise.all([
    fetchUser(userId),
    fetchNotifications(userId),
    fetchStats(userId),
  ]);

  return { user, notifications, stats };
}
```

### Race (first wins)

```typescript
async function fetchWithTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
): Promise<T> {
  const timeout = new Promise<never>((_, reject) => {
    setTimeout(() => reject(new Error('Timeout')), timeoutMs);
  });

  return Promise.race([promise, timeout]);
}

// Usage
const data = await fetchWithTimeout(fetchData(), 5000);
```

### Any (first success)

```typescript
async function fetchFromMirrors(url: string): Promise<Response> {
  const mirrors = [
    'https://mirror1.example.com',
    'https://mirror2.example.com',
    'https://mirror3.example.com',
  ];

  // Retourne le premier succes
  return Promise.any(
    mirrors.map((mirror) => fetch(`${mirror}${url}`)),
  );
}
```

---

## Cancellable Future

```typescript
class CancellableFuture<T> {
  private deferred = new Deferred<T>();
  private abortController = new AbortController();

  get promise(): Promise<T> {
    return this.deferred.promise;
  }

  get signal(): AbortSignal {
    return this.abortController.signal;
  }

  complete(value: T): void {
    this.deferred.resolve(value);
  }

  cancel(reason?: string): void {
    this.abortController.abort();
    this.deferred.reject(new Error(reason ?? 'Cancelled'));
  }

  static fromAsync<T>(
    fn: (signal: AbortSignal) => Promise<T>,
  ): CancellableFuture<T> {
    const future = new CancellableFuture<T>();

    fn(future.signal)
      .then((v) => future.complete(v))
      .catch((e) => future.deferred.reject(e));

    return future;
  }
}

// Usage
const future = CancellableFuture.fromAsync(async (signal) => {
  const response = await fetch(url, { signal });
  return response.json();
});

// Plus tard...
future.cancel('User navigated away');
```

---

## Lazy Future

```typescript
class LazyFuture<T> {
  private promise?: Promise<T>;
  private started = false;

  constructor(private factory: () => Promise<T>) {}

  get(): Promise<T> {
    if (!this.started) {
      this.started = true;
      this.promise = this.factory();
    }
    return this.promise!;
  }

  get isStarted(): boolean {
    return this.started;
  }
}

// Usage - ne demarre pas avant get()
const lazyData = new LazyFuture(() => fetchExpensiveData());

// ... plus tard quand on en a besoin
const data = await lazyData.get();
```

---

## Complexite et Trade-offs

| Aspect | Valeur |
|--------|--------|
| Creation | O(1) |
| Chaining | O(1) |
| Resolution | O(callbacks) |
| Memoire | O(chain_length) |

### Avantages

- Composition elegante
- Gestion d'erreurs unifiee
- Compatible async/await
- Standard JavaScript

### Inconvenients

- Une seule resolution (pas de retry natif)
- Callback hell si mal utilise
- Pas de cancellation native

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Operations async | Oui (natif) |
| Composition operations | Oui |
| Valeur calculee une fois | Oui |
| Stream de valeurs | Non (use Observable) |
| Annulation frequente | Prudence |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Observer** | Multiple valeurs vs une seule |
| **Callback** | Promise remplace callbacks |
| **Lazy Loading** | LazyFuture combine les deux |
| **Async Queue** | Futures dans une queue |

---

## Sources

- [MDN Promise](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise)
- [Java CompletableFuture](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletableFuture.html)
- [Bluebird Promise Library](http://bluebirdjs.com/)
