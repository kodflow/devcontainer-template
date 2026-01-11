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

## Implementation Go

```go
package pool

import (
	"context"
	"errors"
	"sync"
)

var (
	ErrPoolExhausted = errors.New("pool exhausted")
	ErrNotFromPool   = errors.New("object not from this pool")
)

// Poolable defines objects that can be pooled.
type Poolable interface {
	Reset() error
}

// ObjectPool manages a pool of reusable objects.
type ObjectPool[T Poolable] struct {
	pool    *sync.Pool
	inUse   map[*T]struct{}
	maxSize int
	mu      sync.Mutex
}

// New creates a new ObjectPool.
func New[T Poolable](factory func() T, maxSize int) *ObjectPool[T] {
	return &ObjectPool[T]{
		pool: &sync.Pool{
			New: func() any {
				obj := factory()
				return &obj
			},
		},
		inUse:   make(map[*T]struct{}),
		maxSize: maxSize,
	}
}

// Acquire gets an object from the pool.
func (op *ObjectPool[T]) Acquire(ctx context.Context) (*T, error) {
	op.mu.Lock()
	defer op.mu.Unlock()

	if op.maxSize > 0 && len(op.inUse) >= op.maxSize {
		return nil, ErrPoolExhausted
	}

	obj := op.pool.Get().(*T)
	op.inUse[obj] = struct{}{}
	return obj, nil
}

// Release returns an object to the pool.
func (op *ObjectPool[T]) Release(obj *T) error {
	op.mu.Lock()
	defer op.mu.Unlock()

	if _, ok := op.inUse[obj]; !ok {
		return ErrNotFromPool
	}

	if err := (*obj).Reset(); err != nil {
		delete(op.inUse, obj)
		return err
	}

	delete(op.inUse, obj)
	op.pool.Put(obj)
	return nil
}

// WithObject executes a function with a pooled object.
func (op *ObjectPool[T]) WithObject(ctx context.Context, fn func(*T) error) error {
	obj, err := op.Acquire(ctx)
	if err != nil {
		return err
	}
	defer op.Release(obj)
	return fn(obj)
}

// Stats returns pool statistics.
func (op *ObjectPool[T]) Stats() (inUse, total int) {
	op.mu.Lock()
	defer op.mu.Unlock()
	return len(op.inUse), len(op.inUse)
}
```

---

## Exemple d'utilisation

```go
package main

import (
	"context"
	"fmt"
)

// ReusableBuffer is a poolable buffer.
type ReusableBuffer struct {
	data     []byte
	position int
}

// NewReusableBuffer creates a new reusable buffer.
func NewReusableBuffer(size int) *ReusableBuffer {
	return &ReusableBuffer{
		data: make([]byte, size),
	}
}

// Write writes bytes to the buffer.
func (rb *ReusableBuffer) Write(bytes []byte) error {
	if rb.position+len(bytes) > len(rb.data) {
		return fmt.Errorf("buffer overflow")
	}
	copy(rb.data[rb.position:], bytes)
	rb.position += len(bytes)
	return nil
}

// Reset resets the buffer for reuse.
func (rb *ReusableBuffer) Reset() error {
	rb.position = 0
	return nil
}

// Usage example
func main() {
	bufferPool := pool.New(
		func() *ReusableBuffer { return NewReusableBuffer(8192) },
		100,
	)

	ctx := context.Background()

	// Use buffer with automatic cleanup
	err := bufferPool.WithObject(ctx, func(buffer *ReusableBuffer) error {
		data := []byte("hello world")
		return buffer.Write(data)
	})

	if err != nil {
		panic(err)
	}
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
