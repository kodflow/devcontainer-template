# Object Pool

Pattern de gestion de ressources reutilisant des objets couteux au lieu de les recreer.

---

## Qu'est-ce que l'Object Pool ?

> Pre-allouer et reutiliser des objets pour eviter le cout de creation/destruction.

```
+-------------------------------------------------------------+
|                     Object Pool                             |
|                                                             |
|  acquire()                         release(obj)             |
|      |                                  |                   |
|      v                                  v                   |
|  +-------+    +-------+    +-------+    +-------+           |
|  |  obj  |    |  obj  |    |  obj  |    |  obj  |           |
|  | (used)|    |(avail)|    |(avail)|    | (used)|           |
|  +-------+    +-------+    +-------+    +-------+           |
|      ^            |            |            ^               |
|      |            +-----+------+            |               |
|      |                  |                   |               |
|  Client A          Available           Client B             |
|                                                             |
+-------------------------------------------------------------+
```

**Pourquoi :**

- Eviter les allocations couteuses (GC pressure)
- Limiter les ressources systeme (connexions, threads)
- Reduire la latence d'acquisition

---

## Implementation TypeScript

```typescript
interface Poolable {
  reset(): void;
}

class ObjectPool<T extends Poolable> {
  private available: T[] = [];
  private inUse = new Set<T>();
  private readonly maxSize: number;

  constructor(
    private factory: () => T,
    private opts: { initialSize?: number; maxSize?: number } = {},
  ) {
    this.maxSize = opts.maxSize ?? Infinity;
    const initial = opts.initialSize ?? 0;

    for (let i = 0; i < initial; i++) {
      this.available.push(factory());
    }
  }

  acquire(): T {
    let obj = this.available.pop();

    if (!obj) {
      if (this.inUse.size >= this.maxSize) {
        throw new Error('Pool exhausted');
      }
      obj = this.factory();
    }

    this.inUse.add(obj);
    return obj;
  }

  release(obj: T): void {
    if (!this.inUse.delete(obj)) {
      throw new Error('Object not from this pool');
    }
    obj.reset();
    this.available.push(obj);
  }

  async withObject<R>(fn: (obj: T) => Promise<R>): Promise<R> {
    const obj = this.acquire();
    try {
      return await fn(obj);
    } finally {
      this.release(obj);
    }
  }

  get stats() {
    return {
      available: this.available.length,
      inUse: this.inUse.size,
      total: this.available.length + this.inUse.size,
    };
  }
}
```

---

## Exemple d'utilisation

```typescript
// Buffer reutilisable
class ReusableBuffer implements Poolable {
  private data: Uint8Array;
  private position = 0;

  constructor(size: number = 4096) {
    this.data = new Uint8Array(size);
  }

  write(bytes: Uint8Array): void {
    this.data.set(bytes, this.position);
    this.position += bytes.length;
  }

  reset(): void {
    this.position = 0;
    // Pas besoin d'effacer, juste reset position
  }
}

// Pool de buffers
const bufferPool = new ObjectPool(
  () => new ReusableBuffer(8192),
  { initialSize: 10, maxSize: 100 },
);

// Usage
async function processRequest(data: Uint8Array) {
  return bufferPool.withObject(async (buffer) => {
    buffer.write(data);
    // ... traitement
    return result;
  });
}
```

---

## Complexite et Trade-offs

| Aspect | Valeur |
|--------|--------|
| Complexite temps acquire | O(1) |
| Complexite temps release | O(1) |
| Memoire | O(maxSize) pre-allouee |

### Avantages

- Reduction allocations/GC
- Latence predictible
- Controle des ressources

### Inconvenients

- Memoire reservee meme si non utilisee
- Complexite de gestion du cycle de vie
- Risque de fuite si release oublie

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Objets couteux a creer | Oui |
| Haute frequence creation/destruction | Oui |
| Ressources systeme limitees | Oui |
| Objets legers et simples | Non |
| Objets avec etat complexe | Prudence |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Flyweight** | Partage d'etat, pas de cycle acquire/release |
| **Singleton** | Instance unique vs pool d'instances |
| **Connection Pool** | Specialisation pour connexions |
| **Factory** | Creation des objets du pool |

---

## Sources

- [Game Programming Patterns - Object Pool](https://gameprogrammingpatterns.com/object-pool.html)
- [Apache Commons Pool](https://commons.apache.org/proper/commons-pool/)
