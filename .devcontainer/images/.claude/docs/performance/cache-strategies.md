# Cache Strategies

Strategies d'ecriture et lecture pour systemes de cache.

---

## Vue d'ensemble des strategies

```
+--------------------------------------------------------------+
|                    Cache Strategies                           |
|                                                               |
|  Read Strategies:          Write Strategies:                  |
|                                                               |
|  +------------------+      +------------------+               |
|  | Cache-Aside      |      | Write-Through    |               |
|  | Read-Through     |      | Write-Behind     |               |
|  +------------------+      | Write-Around     |               |
|                            +------------------+               |
|                                                               |
|  Invalidation:             Eviction:                          |
|                                                               |
|  +------------------+      +------------------+               |
|  | TTL              |      | LRU              |               |
|  | Event-based      |      | LFU              |               |
|  | Version-based    |      | FIFO             |               |
|  +------------------+      +------------------+               |
+--------------------------------------------------------------+
```

---

## Read Strategies

### Cache-Aside (Lazy Loading)

> L'application gere le cache explicitement.

```typescript
class CacheAsideRepository<T> {
  constructor(
    private cache: Cache<T>,
    private db: Database<T>,
  ) {}

  async get(id: string): Promise<T | null> {
    // 1. Chercher dans le cache
    const cached = await this.cache.get(id);
    if (cached !== undefined) {
      return cached;
    }

    // 2. Charger depuis la DB
    const data = await this.db.findById(id);
    if (data === null) {
      return null;
    }

    // 3. Mettre en cache
    await this.cache.set(id, data);
    return data;
  }

  async update(id: string, data: T): Promise<void> {
    // Ecrire en DB puis invalider le cache
    await this.db.update(id, data);
    await this.cache.delete(id);
  }
}
```

**Avantages:** Controle total, resilient si cache down
**Inconvenients:** Code duplique, risque d'inconsistance

### Read-Through

> Le cache charge automatiquement depuis la source.

```typescript
class ReadThroughCache<T> {
  private cache = new Map<string, T>();

  constructor(
    private loader: (key: string) => Promise<T>,
    private ttl: number,
  ) {}

  async get(key: string): Promise<T> {
    if (this.cache.has(key)) {
      return this.cache.get(key)!;
    }

    // Chargement automatique
    const value = await this.loader(key);
    this.cache.set(key, value);

    // TTL
    setTimeout(() => this.cache.delete(key), this.ttl);

    return value;
  }
}

// Usage
const userCache = new ReadThroughCache<User>(
  async (id) => db.users.findById(id),
  60_000,
);

const user = await userCache.get('user-123');
```

**Avantages:** Logique centralisee, transparent
**Inconvenients:** Couplage cache-source

---

## Write Strategies

### Write-Through

> Ecriture synchrone dans cache ET source.

```typescript
class WriteThroughCache<T> {
  constructor(
    private cache: Cache<T>,
    private db: Database<T>,
  ) {}

  async write(key: string, value: T): Promise<void> {
    // Ecrire dans les deux de maniere synchrone
    await Promise.all([
      this.cache.set(key, value),
      this.db.save(key, value),
    ]);
  }

  async read(key: string): Promise<T | null> {
    // Le cache est toujours a jour
    return this.cache.get(key);
  }
}
```

```
Write-Through:
  App --write--> Cache --write--> DB
                   |
                   +--- reponse seulement apres DB commit
```

**Avantages:** Consistance forte
**Inconvenients:** Latence ecriture doublee

### Write-Behind (Write-Back)

> Ecriture asynchrone dans la source.

```typescript
class WriteBehindCache<T> {
  private pending = new Map<string, T>();
  private timer: ReturnType<typeof setInterval>;

  constructor(
    private cache: Cache<T>,
    private db: Database<T>,
    private flushInterval: number,
  ) {
    this.timer = setInterval(() => this.flush(), flushInterval);
  }

  async write(key: string, value: T): Promise<void> {
    // Ecriture immediate dans le cache
    await this.cache.set(key, value);
    // Marquer pour ecriture differee
    this.pending.set(key, value);
  }

  private async flush(): Promise<void> {
    if (this.pending.size === 0) return;

    const entries = [...this.pending.entries()];
    this.pending.clear();

    // Batch write vers DB
    await this.db.bulkSave(entries);
  }

  async close(): Promise<void> {
    clearInterval(this.timer);
    await this.flush();
  }
}
```

```
Write-Behind:
  App --write--> Cache ---(async)---> DB
         |
         +--- reponse immediate
```

**Avantages:** Latence ecriture minimale, batching
**Inconvenients:** Risque perte donnees, complexite

### Write-Around

> Ecriture directe en DB, cache uniquement en lecture.

```typescript
class WriteAroundCache<T> {
  constructor(
    private cache: Cache<T>,
    private db: Database<T>,
  ) {}

  async write(key: string, value: T): Promise<void> {
    // Ecriture directe en DB
    await this.db.save(key, value);
    // Invalider le cache (optionnel)
    await this.cache.delete(key);
  }

  async read(key: string): Promise<T | null> {
    const cached = await this.cache.get(key);
    if (cached) return cached;

    const value = await this.db.findById(key);
    if (value) {
      await this.cache.set(key, value);
    }
    return value;
  }
}
```

**Avantages:** Pas de cache pollution pour donnees peu lues
**Inconvenients:** Miss cache apres ecriture

---

## Eviction Strategies

### LRU (Least Recently Used)

```typescript
class LRUCache<K, V> {
  private cache = new Map<K, V>();

  constructor(private maxSize: number) {}

  get(key: K): V | undefined {
    if (!this.cache.has(key)) return undefined;

    // Deplacer a la fin (plus recent)
    const value = this.cache.get(key)!;
    this.cache.delete(key);
    this.cache.set(key, value);
    return value;
  }

  set(key: K, value: V): void {
    if (this.cache.has(key)) {
      this.cache.delete(key);
    } else if (this.cache.size >= this.maxSize) {
      // Supprimer le plus ancien (premier)
      const oldest = this.cache.keys().next().value;
      this.cache.delete(oldest);
    }
    this.cache.set(key, value);
  }
}
```

### LFU (Least Frequently Used)

```typescript
class LFUCache<K, V> {
  private cache = new Map<K, { value: V; freq: number }>();
  private freqMap = new Map<number, Set<K>>();
  private minFreq = 0;

  constructor(private maxSize: number) {}

  get(key: K): V | undefined {
    const entry = this.cache.get(key);
    if (!entry) return undefined;

    // Incrementer frequence
    this.updateFrequency(key, entry.freq);
    entry.freq++;
    return entry.value;
  }

  private updateFrequency(key: K, oldFreq: number): void {
    this.freqMap.get(oldFreq)?.delete(key);

    const newFreq = oldFreq + 1;
    if (!this.freqMap.has(newFreq)) {
      this.freqMap.set(newFreq, new Set());
    }
    this.freqMap.get(newFreq)!.add(key);

    if (this.freqMap.get(this.minFreq)?.size === 0) {
      this.minFreq = newFreq;
    }
  }

  set(key: K, value: V): void {
    if (this.maxSize <= 0) return;

    if (this.cache.has(key)) {
      const entry = this.cache.get(key)!;
      entry.value = value;
      this.get(key); // Update frequency
      return;
    }

    if (this.cache.size >= this.maxSize) {
      // Evict LFU
      const lfuKeys = this.freqMap.get(this.minFreq)!;
      const keyToRemove = lfuKeys.values().next().value;
      lfuKeys.delete(keyToRemove);
      this.cache.delete(keyToRemove);
    }

    this.cache.set(key, { value, freq: 1 });
    this.freqMap.set(1, (this.freqMap.get(1) || new Set()).add(key));
    this.minFreq = 1;
  }
}
```

---

## Tableau de decision

| Scenario | Strategy recommandee |
|----------|---------------------|
| Lectures frequentes, ecritures rares | Cache-Aside + LRU |
| Consistance critique | Write-Through |
| Performance ecriture critique | Write-Behind |
| Donnees rarement relues | Write-Around |
| Working set predictible | LFU |
| Acces recents importants | LRU |
| Donnees avec expiration naturelle | TTL |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Memoization** | Cache au niveau fonction |
| **Proxy** | Encapsule l'acces cache |
| **Circuit Breaker** | Protection source si down |
| **CQRS** | Separation lecture/ecriture |

---

## Sources

- [Caching Strategies](https://docs.aws.amazon.com/AmazonElastiCache/latest/mem-ug/Strategies.html)
- [Redis Patterns](https://redis.io/docs/manual/patterns/)
- [Facebook TAO](https://www.usenix.org/conference/atc13/technical-sessions/presentation/bronson)
