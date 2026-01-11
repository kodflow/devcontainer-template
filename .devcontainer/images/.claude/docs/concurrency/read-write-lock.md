# Read-Write Lock

Pattern permettant plusieurs lecteurs simultanes mais un seul ecrivain exclusif.

---

## Qu'est-ce qu'un Read-Write Lock ?

> Optimise l'acces concurrent en permettant la lecture parallele tout en garantissant l'ecriture exclusive.

```
+--------------------------------------------------------------+
|                    Read-Write Lock                            |
|                                                               |
|  Mode Lecture:                 Mode Ecriture:                 |
|                                                               |
|  +--------+                    +--------+                     |
|  |Resource|                    |Resource|                     |
|  +---+----+                    +---+----+                     |
|      |                             |                          |
|  +---+---+---+                     |                          |
|  |   |   |   |                     |                          |
|  R1  R2  R3  R4               W (exclusif)                    |
|                                                               |
|  Regles:                                                      |
|  - Plusieurs readers en parallele OK                          |
|  - Un seul writer a la fois                                   |
|  - Writer bloque tous les readers                             |
|  - Readers bloquent les writers                               |
|                                                               |
|  Timeline:                                                    |
|  R1 ====                                                      |
|  R2    ====                                                   |
|  W        ====  (attend fin lectures)                         |
|  R3            ====  (attend fin ecriture)                    |
+--------------------------------------------------------------+
```

**Pourquoi :**

- Lectures frequentes, ecritures rares
- Maximiser le throughput en lecture
- Garantir la consistance en ecriture

---

## Implementation TypeScript

### ReadWriteLock basique

```typescript
class ReadWriteLock {
  private readers = 0;
  private writer = false;
  private writerWaiting = 0;
  private readerQueue: Array<() => void> = [];
  private writerQueue: Array<() => void> = [];

  async acquireRead(): Promise<void> {
    // Attendre si un writer est actif ou en attente
    if (this.writer || this.writerWaiting > 0) {
      await new Promise<void>((resolve) => {
        this.readerQueue.push(resolve);
      });
    }
    this.readers++;
  }

  releaseRead(): void {
    this.readers--;

    // Si plus de readers et writers en attente, en reveiller un
    if (this.readers === 0 && this.writerQueue.length > 0) {
      this.writer = true;
      this.writerWaiting--;
      const next = this.writerQueue.shift()!;
      next();
    }
  }

  async acquireWrite(): Promise<void> {
    this.writerWaiting++;

    // Attendre que tous les readers et le writer actuel finissent
    if (this.readers > 0 || this.writer) {
      await new Promise<void>((resolve) => {
        this.writerQueue.push(resolve);
      });
    } else {
      this.writerWaiting--;
      this.writer = true;
    }
  }

  releaseWrite(): void {
    this.writer = false;

    // Priorite aux readers en attente (reader preference)
    if (this.readerQueue.length > 0) {
      const readers = this.readerQueue;
      this.readerQueue = [];
      readers.forEach((resolve) => resolve());
    } else if (this.writerQueue.length > 0) {
      this.writer = true;
      this.writerWaiting--;
      const next = this.writerQueue.shift()!;
      next();
    }
  }

  async withRead<T>(fn: () => T | Promise<T>): Promise<T> {
    await this.acquireRead();
    try {
      return await fn();
    } finally {
      this.releaseRead();
    }
  }

  async withWrite<T>(fn: () => T | Promise<T>): Promise<T> {
    await this.acquireWrite();
    try {
      return await fn();
    } finally {
      this.releaseWrite();
    }
  }
}
```

### Writer Preference (evite writer starvation)

```typescript
class WriterPreferenceRWLock {
  private readers = 0;
  private writer = false;
  private writerWaiting = 0;
  private readerQueue: Array<() => void> = [];
  private writerQueue: Array<() => void> = [];

  async acquireRead(): Promise<void> {
    // Bloquer si writer actif OU writers en attente
    while (this.writer || this.writerWaiting > 0) {
      await new Promise<void>((resolve) => {
        this.readerQueue.push(resolve);
      });
    }
    this.readers++;
  }

  releaseRead(): void {
    this.readers--;
    this.notifyNext();
  }

  async acquireWrite(): Promise<void> {
    this.writerWaiting++;

    while (this.readers > 0 || this.writer) {
      await new Promise<void>((resolve) => {
        this.writerQueue.push(resolve);
      });
    }

    this.writerWaiting--;
    this.writer = true;
  }

  releaseWrite(): void {
    this.writer = false;
    this.notifyNext();
  }

  private notifyNext(): void {
    // Priorite aux writers
    if (this.writerQueue.length > 0 && this.readers === 0) {
      const next = this.writerQueue.shift()!;
      next();
    } else if (this.writerWaiting === 0) {
      // Liberer tous les readers
      const readers = this.readerQueue;
      this.readerQueue = [];
      readers.forEach((r) => r());
    }
  }
}
```

---

## Cas d'usage: Cache Thread-Safe

```typescript
class ThreadSafeCache<K, V> {
  private cache = new Map<K, V>();
  private lock = new ReadWriteLock();

  async get(key: K): Promise<V | undefined> {
    return this.lock.withRead(() => {
      return this.cache.get(key);
    });
  }

  async set(key: K, value: V): Promise<void> {
    await this.lock.withWrite(() => {
      this.cache.set(key, value);
    });
  }

  async getOrSet(key: K, factory: () => V | Promise<V>): Promise<V> {
    // D'abord essayer en lecture
    const existing = await this.get(key);
    if (existing !== undefined) {
      return existing;
    }

    // Sinon, ecriture
    return this.lock.withWrite(async () => {
      // Double-check apres acquisition du write lock
      const current = this.cache.get(key);
      if (current !== undefined) {
        return current;
      }

      const value = await factory();
      this.cache.set(key, value);
      return value;
    });
  }

  async delete(key: K): Promise<boolean> {
    return this.lock.withWrite(() => {
      return this.cache.delete(key);
    });
  }

  async size(): Promise<number> {
    return this.lock.withRead(() => {
      return this.cache.size;
    });
  }
}
```

---

## Upgradeable Read Lock

```typescript
class UpgradeableRWLock {
  private rwLock = new ReadWriteLock();
  private upgradeLock = new Mutex();

  async acquireRead(): Promise<void> {
    await this.rwLock.acquireRead();
  }

  releaseRead(): void {
    this.rwLock.releaseRead();
  }

  async acquireUpgradeable(): Promise<void> {
    await this.upgradeLock.acquire();
    await this.rwLock.acquireRead();
  }

  async upgradeToWrite(): Promise<void> {
    // Deja tient upgradeLock, donc seul a pouvoir upgrader
    this.rwLock.releaseRead();
    await this.rwLock.acquireWrite();
  }

  releaseUpgradeable(): void {
    this.rwLock.releaseRead();
    this.upgradeLock.release();
  }

  releaseWrite(): void {
    this.rwLock.releaseWrite();
    this.upgradeLock.release();
  }
}

// Usage
const lock = new UpgradeableRWLock();

await lock.acquireUpgradeable();
try {
  const value = readValue();
  if (needsUpdate(value)) {
    await lock.upgradeToWrite();
    updateValue();
    lock.releaseWrite();
  } else {
    lock.releaseUpgradeable();
  }
} catch (e) {
  lock.releaseUpgradeable();
}
```

---

## Comparaison des strategies

```
Reader Preference:
  Readers: ========    ========    ========
  Writers:         ====        ====
  (Writers peuvent starve si lectures continues)

Writer Preference:
  Readers: ====              ====
  Writers:     ====    ====
  (Readers attendent si writers en queue)

Fair (FIFO):
  Queue:  R1, R2, W1, R3, R4, W2
  Exec:   R1 R2  W1  R3 R4  W2
  (Ordre d'arrivee respecte)
```

---

## Complexite et Trade-offs

| Operation | Complexite |
|-----------|------------|
| acquireRead (no contention) | O(1) |
| acquireWrite (no contention) | O(1) |
| release | O(waiting) |

### Avantages

- Throughput lecture maximise
- Consistance ecriture garantie
- Meilleur que mutex pour read-heavy

### Inconvenients

- Plus complexe que mutex simple
- Risque de starvation (reader ou writer)
- Overhead si peu de lectures

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Lectures >> Ecritures | Oui |
| Cache en memoire | Oui |
| Configuration partagee | Oui |
| Ecritures frequentes | Non (mutex suffit) |
| Courtes operations | Non (overhead) |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Mutex** | Cas special avec 1 reader/writer |
| **Semaphore** | RWLock = Semaphore specialise |
| **Copy-on-Write** | Alternative sans locks |
| **MVCC** | Multi-version pour eviter locks |

---

## Sources

- [Wikipedia - Readers-Writer Lock](https://en.wikipedia.org/wiki/Readers%E2%80%93writer_lock)
- [Java ReentrantReadWriteLock](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/locks/ReentrantReadWriteLock.html)
- [Go sync.RWMutex](https://pkg.go.dev/sync#RWMutex)
