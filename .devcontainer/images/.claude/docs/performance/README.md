# Performance Patterns

Patterns d'optimisation des performances et de la mémoire.

## Les 12 Patterns

### 1. Object Pool

> Réutiliser des objets coûteux au lieu de les recréer.

```typescript
class ObjectPool<T> {
  private available: T[] = [];
  private inUse = new Set<T>();

  constructor(
    private factory: () => T,
    private reset: (obj: T) => void,
    private initialSize = 10,
  ) {
    for (let i = 0; i < initialSize; i++) {
      this.available.push(factory());
    }
  }

  acquire(): T {
    const obj = this.available.pop() ?? this.factory();
    this.inUse.add(obj);
    return obj;
  }

  release(obj: T) {
    if (this.inUse.delete(obj)) {
      this.reset(obj);
      this.available.push(obj);
    }
  }
}

// Usage - Pool de connexions DB
const dbPool = new ObjectPool(
  () => new DatabaseConnection(),
  (conn) => conn.reset(),
  20,
);

const conn = dbPool.acquire();
try {
  await conn.query('SELECT * FROM users');
} finally {
  dbPool.release(conn);
}
```

**Quand :** Connexions DB, threads, objets graphiques coûteux.
**Lié à :** Flyweight, Singleton.

---

### 2. Buffer / Ring Buffer

> Tampon circulaire pour flux de données continus.

```typescript
class RingBuffer<T> {
  private buffer: (T | undefined)[];
  private head = 0;
  private tail = 0;
  private count = 0;

  constructor(private capacity: number) {
    this.buffer = new Array(capacity);
  }

  write(item: T): boolean {
    if (this.count === this.capacity) return false;
    this.buffer[this.tail] = item;
    this.tail = (this.tail + 1) % this.capacity;
    this.count++;
    return true;
  }

  read(): T | undefined {
    if (this.count === 0) return undefined;
    const item = this.buffer[this.head];
    this.buffer[this.head] = undefined;
    this.head = (this.head + 1) % this.capacity;
    this.count--;
    return item;
  }

  get size() { return this.count; }
  get isEmpty() { return this.count === 0; }
  get isFull() { return this.count === this.capacity; }
}

// Usage - Buffer audio/video
const audioBuffer = new RingBuffer<AudioFrame>(1024);
```

**Quand :** Streaming, audio/video, logging haute performance.
**Lié à :** Producer-Consumer, Queue.

---

### 3. Cache (avec stratégies)

> Stocker les résultats pour éviter les recalculs.

```typescript
// LRU Cache (Least Recently Used)
class LRUCache<K, V> {
  private cache = new Map<K, V>();

  constructor(private maxSize: number) {}

  get(key: K): V | undefined {
    if (!this.cache.has(key)) return undefined;
    // Move to end (most recent)
    const value = this.cache.get(key)!;
    this.cache.delete(key);
    this.cache.set(key, value);
    return value;
  }

  set(key: K, value: V) {
    if (this.cache.has(key)) {
      this.cache.delete(key);
    } else if (this.cache.size >= this.maxSize) {
      // Remove oldest (first)
      const oldest = this.cache.keys().next().value;
      this.cache.delete(oldest);
    }
    this.cache.set(key, value);
  }
}

// TTL Cache (Time To Live)
class TTLCache<K, V> {
  private cache = new Map<K, { value: V; expires: number }>();

  constructor(private ttlMs: number) {}

  set(key: K, value: V) {
    this.cache.set(key, {
      value,
      expires: Date.now() + this.ttlMs,
    });
  }

  get(key: K): V | undefined {
    const entry = this.cache.get(key);
    if (!entry) return undefined;
    if (Date.now() > entry.expires) {
      this.cache.delete(key);
      return undefined;
    }
    return entry.value;
  }
}
```

**Stratégies :**

- **LRU** : Évicte le moins récemment utilisé
- **LFU** : Évicte le moins fréquemment utilisé
- **TTL** : Expiration temporelle
- **Write-through** : Écriture cache + source
- **Write-behind** : Écriture asynchrone

**Quand :** API responses, calculs coûteux, données fréquentes.
**Lié à :** Proxy, Memoization.

---

### 4. Lazy Loading

> Différer l'initialisation jusqu'à l'utilisation.

```typescript
class LazyValue<T> {
  private value: T | undefined;
  private initialized = false;

  constructor(private factory: () => T) {}

  get(): T {
    if (!this.initialized) {
      this.value = this.factory();
      this.initialized = true;
    }
    return this.value!;
  }
}

// Lazy property decorator
function lazy<T>(factory: () => T) {
  let value: T;
  let initialized = false;
  return () => {
    if (!initialized) {
      value = factory();
      initialized = true;
    }
    return value;
  };
}

// Usage
class HeavyService {
  private _database = lazy(() => new DatabaseConnection());

  get database() { return this._database(); }
}
```

**Variantes :**

- **Virtual Proxy** : Proxy qui charge à la demande
- **Ghost** : Objet partiel chargé progressivement
- **Value Holder** : Conteneur qui charge au premier accès

**Quand :** Ressources lourdes, images, modules, dépendances optionnelles.
**Lié à :** Proxy, Virtual Proxy.

---

### 5. Memoization

> Mettre en cache les résultats de fonctions pures.

```typescript
function memoize<T extends (...args: any[]) => any>(fn: T): T {
  const cache = new Map<string, ReturnType<T>>();

  return ((...args: Parameters<T>) => {
    const key = JSON.stringify(args);
    if (cache.has(key)) {
      return cache.get(key)!;
    }
    const result = fn(...args);
    cache.set(key, result);
    return result;
  }) as T;
}

// Usage
const fibonacci = memoize((n: number): number => {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
});

fibonacci(50); // Instantané avec memoization

// Async memoization
function memoizeAsync<T extends (...args: any[]) => Promise<any>>(fn: T): T {
  const cache = new Map<string, Promise<Awaited<ReturnType<T>>>>();

  return ((...args: Parameters<T>) => {
    const key = JSON.stringify(args);
    if (!cache.has(key)) {
      cache.set(key, fn(...args).catch((err) => {
        cache.delete(key); // Remove on error
        throw err;
      }));
    }
    return cache.get(key)!;
  }) as T;
}
```

**Quand :** Fonctions pures, calculs récursifs, API calls identiques.
**Lié à :** Cache, Decorator.

---

### 6. Debounce

> Exécuter après un délai d'inactivité.

```typescript
function debounce<T extends (...args: any[]) => any>(
  fn: T,
  delay: number,
): (...args: Parameters<T>) => void {
  let timeoutId: ReturnType<typeof setTimeout>;

  return (...args: Parameters<T>) => {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn(...args), delay);
  };
}

// Usage - Recherche en temps réel
const searchInput = document.querySelector('input');
const debouncedSearch = debounce((query: string) => {
  api.search(query);
}, 300);

searchInput.addEventListener('input', (e) => {
  debouncedSearch(e.target.value);
});
```

**Quand :** Input utilisateur, resize, scroll, recherche.
**Lié à :** Throttle.

---

### 7. Throttle

> Limiter la fréquence d'exécution.

```typescript
function throttle<T extends (...args: any[]) => any>(
  fn: T,
  limit: number,
): (...args: Parameters<T>) => void {
  let inThrottle = false;
  let lastArgs: Parameters<T> | null = null;

  return (...args: Parameters<T>) => {
    if (inThrottle) {
      lastArgs = args;
      return;
    }

    fn(...args);
    inThrottle = true;

    setTimeout(() => {
      inThrottle = false;
      if (lastArgs) {
        fn(...lastArgs);
        lastArgs = null;
      }
    }, limit);
  };
}

// Usage - Animation scroll
const throttledScroll = throttle(() => {
  updateParallax();
}, 16); // ~60fps

window.addEventListener('scroll', throttledScroll);
```

**Quand :** Events haute fréquence, animations, rate limiting.
**Lié à :** Debounce, Rate Limiter.

---

### 8. Batch Processing

> Grouper les opérations pour réduire l'overhead.

```typescript
class BatchProcessor<T> {
  private batch: T[] = [];
  private timer: ReturnType<typeof setTimeout> | null = null;

  constructor(
    private processor: (items: T[]) => Promise<void>,
    private maxSize: number = 100,
    private maxWait: number = 1000,
  ) {}

  add(item: T) {
    this.batch.push(item);

    if (this.batch.length >= this.maxSize) {
      this.flush();
    } else if (!this.timer) {
      this.timer = setTimeout(() => this.flush(), this.maxWait);
    }
  }

  async flush() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    if (this.batch.length === 0) return;

    const items = this.batch;
    this.batch = [];
    await this.processor(items);
  }
}

// Usage - Batch insert en DB
const batcher = new BatchProcessor<LogEntry>(
  async (entries) => {
    await db.logs.insertMany(entries);
  },
  100,  // Max 100 entries
  1000, // Ou après 1 seconde
);

batcher.add({ level: 'info', message: 'Hello' });
```

**Quand :** Insertions DB, API calls, événements.
**Lié à :** Buffer, Queue.

---

### 9. Pagination / Cursor

> Charger les données par morceaux.

```typescript
// Offset-based (simple mais moins performant)
interface OffsetPagination {
  page: number;
  pageSize: number;
  total: number;
}

async function getPageOffset<T>(
  query: () => Promise<T[]>,
  page: number,
  pageSize: number,
): Promise<{ data: T[]; pagination: OffsetPagination }> {
  const offset = (page - 1) * pageSize;
  const data = await query(); // Avec LIMIT/OFFSET
  return { data, pagination: { page, pageSize, total: 0 } };
}

// Cursor-based (plus performant pour grands datasets)
interface CursorPagination {
  cursor: string | null;
  hasMore: boolean;
}

async function getPageCursor<T extends { id: string }>(
  query: (cursor?: string) => Promise<T[]>,
  cursor?: string,
  limit: number = 20,
): Promise<{ data: T[]; pagination: CursorPagination }> {
  const data = await query(cursor);
  const hasMore = data.length === limit;
  const nextCursor = hasMore ? data[data.length - 1].id : null;
  return { data, pagination: { cursor: nextCursor, hasMore } };
}
```

**Quand :** Listes longues, infinite scroll, API REST.
**Lié à :** Lazy Loading, Iterator.

---

### 10. Connection Pooling

> Pool de connexions réutilisables.

```typescript
interface PooledConnection {
  query(sql: string): Promise<any>;
  release(): void;
}

class ConnectionPool {
  private available: PooledConnection[] = [];
  private waiting: ((conn: PooledConnection) => void)[] = [];
  private activeCount = 0;

  constructor(
    private factory: () => Promise<PooledConnection>,
    private maxConnections: number = 10,
  ) {}

  async acquire(): Promise<PooledConnection> {
    // Connection disponible
    const conn = this.available.pop();
    if (conn) {
      this.activeCount++;
      return this.wrapConnection(conn);
    }

    // Créer nouvelle si possible
    if (this.activeCount < this.maxConnections) {
      this.activeCount++;
      const newConn = await this.factory();
      return this.wrapConnection(newConn);
    }

    // Attendre une libération
    return new Promise((resolve) => {
      this.waiting.push(resolve);
    });
  }

  private wrapConnection(conn: PooledConnection): PooledConnection {
    return {
      query: conn.query.bind(conn),
      release: () => this.release(conn),
    };
  }

  private release(conn: PooledConnection) {
    this.activeCount--;
    const waiter = this.waiting.shift();
    if (waiter) {
      this.activeCount++;
      waiter(this.wrapConnection(conn));
    } else {
      this.available.push(conn);
    }
  }
}
```

**Quand :** Connexions DB, HTTP clients, WebSockets.
**Lié à :** Object Pool, Resource Management.

---

### 11. Double Buffering

> Deux buffers alternés pour éviter les conflits.

```typescript
class DoubleBuffer<T> {
  private buffers: [T[], T[]] = [[], []];
  private writeIndex = 0;

  get readBuffer(): readonly T[] {
    return this.buffers[1 - this.writeIndex];
  }

  get writeBuffer(): T[] {
    return this.buffers[this.writeIndex];
  }

  swap() {
    this.writeIndex = 1 - this.writeIndex;
    this.buffers[this.writeIndex] = [];
  }
}

// Usage - Rendering
class Renderer {
  private buffer = new DoubleBuffer<DrawCommand>();

  draw(command: DrawCommand) {
    this.buffer.writeBuffer.push(command);
  }

  render() {
    this.buffer.swap();
    for (const cmd of this.buffer.readBuffer) {
      this.execute(cmd);
    }
  }
}
```

**Quand :** Graphics, audio, game loops, animations.
**Lié à :** Buffer, Producer-Consumer.

---

### 12. Flyweight (optimisation mémoire)

> Voir structural/README.md pour détails.

Partager l'état intrinsèque (immutable) entre objets similaires.

```typescript
// Millions de particules, peu de types
const particleTypes = {
  smoke: new ParticleType('gray', smokeTexture, 0.5),
  fire: new ParticleType('orange', fireTexture, 1.0),
  spark: new ParticleType('yellow', sparkTexture, 0.3),
};

class Particle {
  constructor(
    public x: number,
    public y: number,
    public type: ParticleType, // Flyweight partagé
  ) {}
}
```

**Quand :** Jeux, éditeurs texte, millions d'objets similaires.
**Lié à :** Object Pool, Prototype.

---

## Tableau de décision

| Besoin | Pattern |
|--------|---------|
| Réutiliser objets coûteux | Object Pool |
| Flux continu de données | Ring Buffer |
| Éviter recalculs | Cache / Memoization |
| Différer initialisation | Lazy Loading |
| Limiter rate input | Debounce / Throttle |
| Grouper opérations | Batch Processing |
| Grands datasets | Pagination / Cursor |
| Connexions réutilisables | Connection Pool |
| Éviter conflits lecture/écriture | Double Buffering |
| Réduire mémoire objets similaires | Flyweight |

## Pool + Buffer Pattern

Le pattern **PoolBuffer** combine Object Pool et Ring Buffer :

```typescript
class PoolBuffer<T> {
  private pool: ObjectPool<T>;
  private buffer: RingBuffer<T>;

  constructor(
    factory: () => T,
    reset: (obj: T) => void,
    poolSize: number,
    bufferSize: number,
  ) {
    this.pool = new ObjectPool(factory, reset, poolSize);
    this.buffer = new RingBuffer(bufferSize);
  }

  // Producteur : acquiert du pool, écrit dans buffer
  produce(): T | null {
    if (this.buffer.isFull) return null;
    const obj = this.pool.acquire();
    this.buffer.write(obj);
    return obj;
  }

  // Consommateur : lit du buffer, retourne au pool
  consume(): T | undefined {
    const obj = this.buffer.read();
    if (obj) {
      // Process then release
      this.pool.release(obj);
    }
    return obj;
  }
}
```

**Usage :** Streaming haute performance, game objects, message queues.

## Sources

- [Game Programming Patterns - Optimization](https://gameprogrammingpatterns.com/optimization-patterns.html)
- [Martin Fowler - Performance Patterns](https://martinfowler.com/articles/patterns-of-distributed-systems/)
