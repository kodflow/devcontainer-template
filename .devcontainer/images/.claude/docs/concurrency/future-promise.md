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

## Implementation Go

### Future basique avec channels

```go
package future

// Future represents a value that will be available later.
type Future[T any] struct {
	value chan T
	err   chan error
	once  sync.Once
}

// NewFuture creates a new future.
func NewFuture[T any]() *Future[T] {
	return &Future[T]{
		value: make(chan T, 1),
		err:   make(chan error, 1),
	}
}

// Complete resolves the future with a value.
func (f *Future[T]) Complete(value T) {
	f.once.Do(func() {
		f.value <- value
	})
}

// Fail rejects the future with an error.
func (f *Future[T]) Fail(err error) {
	f.once.Do(func() {
		f.err <- err
	})
}

// Get waits for and returns the result.
func (f *Future[T]) Get(ctx context.Context) (T, error) {
	select {
	case <-ctx.Done():
		var zero T
		return zero, ctx.Err()
	case value := <-f.value:
		return value, nil
	case err := <-f.err:
		var zero T
		return zero, err
	}
}

// GetWithTimeout waits with a timeout.
func (f *Future[T]) GetWithTimeout(timeout time.Duration) (T, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	return f.Get(ctx)
}
```

**Usage:**

```go
package main

import (
	"context"
	"fmt"
	"time"
)

func fetchDataAsync(url string) *Future[string] {
	future := NewFuture[string]()

	go func() {
		time.Sleep(100 * time.Millisecond) // Simulate work
		future.Complete(fmt.Sprintf("Data from %s", url))
	}()

	return future
}

func main() {
	future := fetchDataAsync("https://api.example.com")

	ctx := context.Background()
	result, err := future.Get(ctx)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}

	fmt.Printf("Result: %s\n", result)
}
```

---

### Promise avec resolver

```go
package promise

import (
	"context"
	"sync"
)

// Promise is a controllable future.
type Promise[T any] struct {
	future *Future[T]
	mu     sync.Mutex
	done   bool
}

// NewPromise creates a new promise.
func NewPromise[T any]() *Promise[T] {
	return &Promise[T]{
		future: NewFuture[T](),
	}
}

// Resolve fulfills the promise.
func (p *Promise[T]) Resolve(value T) bool {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.done {
		return false
	}

	p.done = true
	p.future.Complete(value)
	return true
}

// Reject rejects the promise.
func (p *Promise[T]) Reject(err error) bool {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.done {
		return false
	}

	p.done = true
	p.future.Fail(err)
	return true
}

// Future returns the associated future.
func (p *Promise[T]) Future() *Future[T] {
	return p.future
}

// IsDone returns whether the promise is settled.
func (p *Promise[T]) IsDone() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.done
}
```

---

## Patterns de composition

### Sequential composition

```go
package future

// Then chains a transformation.
func Then[T, U any](f *Future[T], fn func(T) (U, error)) *Future[U] {
	result := NewFuture[U]()

	go func() {
		ctx := context.Background()
		value, err := f.Get(ctx)
		if err != nil {
			result.Fail(err)
			return
		}

		transformed, err := fn(value)
		if err != nil {
			result.Fail(err)
			return
		}

		result.Complete(transformed)
	}()

	return result
}

// ThenAsync chains an async transformation.
func ThenAsync[T, U any](f *Future[T], fn func(T) *Future[U]) *Future[U] {
	result := NewFuture[U]()

	go func() {
		ctx := context.Background()
		value, err := f.Get(ctx)
		if err != nil {
			result.Fail(err)
			return
		}

		next := fn(value)
		nextValue, err := next.Get(ctx)
		if err != nil {
			result.Fail(err)
			return
		}

		result.Complete(nextValue)
	}()

	return result
}
```

### Parallel composition (All)

```go
package future

// All waits for all futures to complete.
func All[T any](futures ...*Future[T]) *Future[[]T] {
	result := NewFuture[[]T]()

	go func() {
		ctx := context.Background()
		results := make([]T, len(futures))

		for i, f := range futures {
			value, err := f.Get(ctx)
			if err != nil {
				result.Fail(err)
				return
			}
			results[i] = value
		}

		result.Complete(results)
	}()

	return result
}
```

### Race composition

```go
package future

// Race returns the first future to complete.
func Race[T any](futures ...*Future[T]) *Future[T] {
	result := NewFuture[T]()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	for _, f := range futures {
		go func(fut *Future[T]) {
			value, err := fut.Get(ctx)
			if err != nil {
				result.Fail(err)
			} else {
				result.Complete(value)
			}
			cancel() // Cancel other goroutines
		}(f)
	}

	return result
}
```

---

## Future avec timeout

```go
package future

// WithTimeout wraps a future with timeout.
func WithTimeout[T any](f *Future[T], timeout time.Duration) *Future[T] {
	result := NewFuture[T]()

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		defer cancel()

		value, err := f.Get(ctx)
		if err != nil {
			result.Fail(err)
		} else {
			result.Complete(value)
		}
	}()

	return result
}
```

---

## Future cancellable

```go
package future

// CancellableFuture supports cancellation.
type CancellableFuture[T any] struct {
	*Future[T]
	cancel context.CancelFunc
}

// NewCancellableFuture creates a cancellable future.
func NewCancellableFuture[T any]() *CancellableFuture[T] {
	ctx, cancel := context.WithCancel(context.Background())

	return &CancellableFuture[T]{
		Future: NewFuture[T](),
		cancel: cancel,
	}
}

// Cancel cancels the future.
func (cf *CancellableFuture[T]) Cancel() {
	cf.cancel()
	cf.Fail(context.Canceled)
}

// FromAsync creates a future from an async function.
func FromAsync[T any](fn func(context.Context) (T, error)) *CancellableFuture[T] {
	cf := NewCancellableFuture[T]()

	go func() {
		ctx, cancel := context.WithCancel(context.Background())
		defer cancel()

		value, err := fn(ctx)
		if err != nil {
			cf.Fail(err)
		} else {
			cf.Complete(value)
		}
	}()

	return cf
}
```

**Usage:**

```go
package main

import (
	"context"
	"fmt"
	"net/http"
	"time"
)

func main() {
	future := FromAsync(func(ctx context.Context) (string, error) {
		req, err := http.NewRequestWithContext(ctx, "GET", "https://api.example.com", nil)
		if err != nil {
			return "", err
		}

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			return "", err
		}
		defer resp.Body.Close()

		return fmt.Sprintf("Status: %d", resp.StatusCode), nil
	})

	// Cancel after 1 second
	time.AfterFunc(1*time.Second, func() {
		future.Cancel()
	})

	ctx := context.Background()
	result, err := future.Get(ctx)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}

	fmt.Printf("Result: %s\n", result)
}
```

---

## Lazy Future

```go
package future

// LazyFuture defers computation until Get.
type LazyFuture[T any] struct {
	factory func(context.Context) (T, error)
	future  *Future[T]
	mu      sync.Mutex
	started bool
}

// NewLazyFuture creates a lazy future.
func NewLazyFuture[T any](factory func(context.Context) (T, error)) *LazyFuture[T] {
	return &LazyFuture[T]{
		factory: factory,
	}
}

// Get starts computation if needed and returns result.
func (lf *LazyFuture[T]) Get(ctx context.Context) (T, error) {
	lf.mu.Lock()

	if !lf.started {
		lf.started = true
		lf.future = NewFuture[T]()

		go func() {
			value, err := lf.factory(ctx)
			if err != nil {
				lf.future.Fail(err)
			} else {
				lf.future.Complete(value)
			}
		}()
	}

	lf.mu.Unlock()

	return lf.future.Get(ctx)
}
```

---

## Complexite et Trade-offs

| Aspect | Valeur |
|--------|--------|
| Creation | O(1) |
| Get (completed) | O(1) |
| Get (pending) | O(wait) |
| Memoire | O(1) per future |

### Avantages

- Composition elegante
- Context natif Go
- Type-safe avec generics
- Compatible avec goroutines

### Inconvenients

- Plus verbose que async/await
- Pas de retry natif
- Requires manual error handling

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Operations async simples | Non (use goroutines) |
| Composition operations | Oui |
| Valeur calculee une fois | Oui |
| Stream de valeurs | Non (use channels) |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Channel** | Future = single-value channel |
| **Context** | Cancellation and timeout |
| **Async/Await** | Future est le primitif sous-jacent |
| **Pipeline** | Futures dans une pipeline |

---

## Sources

- [Go Concurrency Patterns](https://go.dev/blog/pipelines)
- [Java CompletableFuture](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/CompletableFuture.html)
- [MDN Promise](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise)
