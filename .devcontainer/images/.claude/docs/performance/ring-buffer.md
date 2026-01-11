# Ring Buffer (Circular Buffer)

Structure de donnees circulaire haute performance pour flux continus.

---

## Qu'est-ce qu'un Ring Buffer ?

> Tampon de taille fixe qui ecrase les donnees anciennes quand il est plein.

```
+--------------------------------------------------------------+
|                      Ring Buffer                              |
|                                                               |
|  Capacite: 8                                                  |
|                                                               |
|      0     1     2     3     4     5     6     7              |
|    +-----+-----+-----+-----+-----+-----+-----+-----+          |
|    |  A  |  B  |  C  |  D  |     |     |     |  H  |          |
|    +-----+-----+-----+-----+-----+-----+-----+-----+          |
|            ^                 ^                                |
|          head              tail                               |
|        (lecture)         (ecriture)                           |
|                                                               |
|  Write: tail avance (modulo capacity)                         |
|  Read:  head avance (modulo capacity)                         |
|                                                               |
|  Quand tail == head: buffer vide                              |
|  Quand (tail+1) % cap == head: buffer plein                   |
+--------------------------------------------------------------+
```

**Pourquoi :**
- Allocation memoire fixe (pas de GC)
- O(1) pour lecture/ecriture
- Ideal pour streaming et logs

---

## Implementation TypeScript

### RingBuffer basique

```typescript
class RingBuffer<T> {
  private buffer: (T | undefined)[];
  private head = 0; // Prochain index de lecture
  private tail = 0; // Prochain index d'ecriture
  private count = 0;

  constructor(private readonly capacity: number) {
    this.buffer = new Array(capacity);
  }

  write(item: T): boolean {
    if (this.isFull) {
      return false; // Ou: overwrite mode
    }

    this.buffer[this.tail] = item;
    this.tail = (this.tail + 1) % this.capacity;
    this.count++;
    return true;
  }

  read(): T | undefined {
    if (this.isEmpty) {
      return undefined;
    }

    const item = this.buffer[this.head];
    this.buffer[this.head] = undefined; // GC hint
    this.head = (this.head + 1) % this.capacity;
    this.count--;
    return item;
  }

  peek(): T | undefined {
    return this.isEmpty ? undefined : this.buffer[this.head];
  }

  get size(): number {
    return this.count;
  }

  get isEmpty(): boolean {
    return this.count === 0;
  }

  get isFull(): boolean {
    return this.count === this.capacity;
  }

  clear(): void {
    this.buffer.fill(undefined);
    this.head = 0;
    this.tail = 0;
    this.count = 0;
  }
}
```

### RingBuffer avec overwrite

```typescript
class OverwriteRingBuffer<T> {
  private buffer: (T | undefined)[];
  private head = 0;
  private tail = 0;
  private full = false;

  constructor(private readonly capacity: number) {
    this.buffer = new Array(capacity);
  }

  write(item: T): void {
    this.buffer[this.tail] = item;

    if (this.full) {
      // Ecrase le plus ancien, avance head
      this.head = (this.head + 1) % this.capacity;
    }

    this.tail = (this.tail + 1) % this.capacity;
    this.full = this.tail === this.head;
  }

  read(): T | undefined {
    if (this.isEmpty) {
      return undefined;
    }

    const item = this.buffer[this.head];
    this.buffer[this.head] = undefined;
    this.head = (this.head + 1) % this.capacity;
    this.full = false;
    return item;
  }

  get size(): number {
    if (this.full) return this.capacity;
    if (this.tail >= this.head) return this.tail - this.head;
    return this.capacity - this.head + this.tail;
  }

  get isEmpty(): boolean {
    return !this.full && this.head === this.tail;
  }

  // Iterateur sur les elements (du plus ancien au plus recent)
  *[Symbol.iterator](): Iterator<T> {
    if (this.isEmpty) return;

    let i = this.head;
    do {
      yield this.buffer[i]!;
      i = (i + 1) % this.capacity;
    } while (i !== this.tail);
  }
}
```

---

## Cas d'usage

### 1. Buffer audio/video

```typescript
class AudioBuffer {
  private buffer = new RingBuffer<Float32Array>(1024);

  onAudioData(samples: Float32Array): void {
    if (!this.buffer.write(samples)) {
      console.warn('Audio buffer overflow');
    }
  }

  getNextChunk(): Float32Array | undefined {
    return this.buffer.read();
  }
}
```

### 2. Historique de logs

```typescript
class LogHistory {
  private logs = new OverwriteRingBuffer<LogEntry>(1000);

  log(entry: LogEntry): void {
    this.logs.write(entry);
  }

  getRecentLogs(): LogEntry[] {
    return [...this.logs];
  }

  getLastN(n: number): LogEntry[] {
    const all = [...this.logs];
    return all.slice(-n);
  }
}
```

### 3. Metriques rolling window

```typescript
class RollingAverage {
  private samples = new OverwriteRingBuffer<number>(100);

  addSample(value: number): void {
    this.samples.write(value);
  }

  getAverage(): number {
    const values = [...this.samples];
    if (values.length === 0) return 0;
    return values.reduce((a, b) => a + b, 0) / values.length;
  }

  getPercentile(p: number): number {
    const sorted = [...this.samples].sort((a, b) => a - b);
    const index = Math.floor(sorted.length * p / 100);
    return sorted[index] ?? 0;
  }
}
```

### 4. Undo/Redo limite

```typescript
class LimitedUndoStack<T> {
  private undoBuffer = new OverwriteRingBuffer<T>(50);
  private redoBuffer = new OverwriteRingBuffer<T>(50);

  push(state: T): void {
    this.undoBuffer.write(state);
    // Vider redo apres une nouvelle action
  }

  undo(current: T): T | undefined {
    const previous = this.undoBuffer.read();
    if (previous) {
      this.redoBuffer.write(current);
    }
    return previous;
  }

  redo(current: T): T | undefined {
    const next = this.redoBuffer.read();
    if (next) {
      this.undoBuffer.write(current);
    }
    return next;
  }
}
```

---

## Variantes

### Lock-free Ring Buffer (multi-thread)

```typescript
// Pseudo-code - concept
class LockFreeRingBuffer<T> {
  private buffer: T[];
  private head: AtomicInt;  // Lecture atomique
  private tail: AtomicInt;  // Ecriture atomique

  write(item: T): boolean {
    const currentTail = this.tail.load();
    const nextTail = (currentTail + 1) % this.capacity;

    if (nextTail === this.head.load()) {
      return false; // Plein
    }

    this.buffer[currentTail] = item;
    this.tail.store(nextTail); // Memory barrier
    return true;
  }
}
```

---

## Complexite et Trade-offs

| Operation | Complexite |
|-----------|------------|
| write() | O(1) |
| read() | O(1) |
| peek() | O(1) |
| Memoire | O(capacity) fixe |

### Avantages

- Pas d'allocation dynamique
- Performances predictibles
- Ideal pour temps reel

### Inconvenients

- Taille fixe (doit etre dimensionne)
- Perte de donnees si overwrite

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Queue** | Ring buffer est une implementation |
| **Producer-Consumer** | Utilise souvent un ring buffer |
| **Double Buffer** | Deux buffers alternes vs circulaire |
| **Object Pool** | Gestion memoire similaire |

---

## Sources

- [Wikipedia - Circular Buffer](https://en.wikipedia.org/wiki/Circular_buffer)
- [LMAX Disruptor](https://lmax-exchange.github.io/disruptor/) - Ring buffer haute perf
