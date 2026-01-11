# Performance Patterns

Patterns d'optimisation des performances et de la mémoire.

## Les 12 Patterns

### 1. Object Pool

> Réutiliser des objets coûteux au lieu de les recréer.

```go
package performance

import "sync"

// Pool is a generic object pool with reset functionality.
type Pool[T any] struct {
	pool  *sync.Pool
	reset func(*T)
}

// NewPool creates a new object pool.
func NewPool[T any](factory func() *T, reset func(*T)) *Pool[T] {
	return &Pool[T]{
		pool: &sync.Pool{
			New: func() any {
				return factory()
			},
		},
		reset: reset,
	}
}

// Acquire retrieves an object from the pool.
func (p *Pool[T]) Acquire() *T {
	return p.pool.Get().(*T)
}

// Release returns an object to the pool after resetting it.
func (p *Pool[T]) Release(obj *T) {
	p.reset(obj)
	p.pool.Put(obj)
}

// Usage - Pool de connexions DB
type DatabaseConnection struct {
	conn interface{}
}

func (d *DatabaseConnection) Reset() {
	d.conn = nil
}

func (d *DatabaseConnection) Query(sql string) error {
	// Execute query
	return nil
}

func ExampleDatabasePool() {
	dbPool := NewPool(
		func() *DatabaseConnection {
			return &DatabaseConnection{}
		},
		func(conn *DatabaseConnection) {
			conn.Reset()
		},
	)

	conn := dbPool.Acquire()
	defer dbPool.Release(conn)

	_ = conn.Query("SELECT * FROM users")
}
```

**Quand :** Connexions DB, threads, objets graphiques coûteux.
**Lié à :** Flyweight, Singleton.

---

### 2. Buffer / Ring Buffer

> Tampon circulaire pour flux de données continus.

```go
package performance

import (
	"errors"
	"sync"
)

// RingBuffer is a thread-safe circular buffer.
type RingBuffer[T any] struct {
	mu       sync.RWMutex
	buffer   []T
	head     int
	tail     int
	count    int
	capacity int
}

// NewRingBuffer creates a new ring buffer with the given capacity.
func NewRingBuffer[T any](capacity int) *RingBuffer[T] {
	return &RingBuffer[T]{
		buffer:   make([]T, capacity),
		capacity: capacity,
	}
}

var (
	ErrBufferFull  = errors.New("buffer is full")
	ErrBufferEmpty = errors.New("buffer is empty")
)

// Write adds an item to the buffer.
func (rb *RingBuffer[T]) Write(item T) error {
	rb.mu.Lock()
	defer rb.mu.Unlock()

	if rb.count == rb.capacity {
		return ErrBufferFull
	}

	rb.buffer[rb.tail] = item
	rb.tail = (rb.tail + 1) % rb.capacity
	rb.count++
	return nil
}

// Read removes and returns an item from the buffer.
func (rb *RingBuffer[T]) Read() (T, error) {
	rb.mu.Lock()
	defer rb.mu.Unlock()

	var zero T
	if rb.count == 0 {
		return zero, ErrBufferEmpty
	}

	item := rb.buffer[rb.head]
	rb.buffer[rb.head] = zero // Clear reference
	rb.head = (rb.head + 1) % rb.capacity
	rb.count--
	return item, nil
}

// Size returns the current number of items.
func (rb *RingBuffer[T]) Size() int {
	rb.mu.RLock()
	defer rb.mu.RUnlock()
	return rb.count
}

// IsEmpty returns true if the buffer is empty.
func (rb *RingBuffer[T]) IsEmpty() bool {
	rb.mu.RLock()
	defer rb.mu.RUnlock()
	return rb.count == 0
}

// IsFull returns true if the buffer is full.
func (rb *RingBuffer[T]) IsFull() bool {
	rb.mu.RLock()
	defer rb.mu.RUnlock()
	return rb.count == rb.capacity
}

// Usage - Buffer audio/video
type AudioFrame struct {
	Data []byte
}

func ExampleAudioBuffer() {
	audioBuffer := NewRingBuffer[*AudioFrame](1024)
	_ = audioBuffer.Write(&AudioFrame{Data: []byte("sample")})
	frame, _ := audioBuffer.Read()
	_ = frame
}
```

**Quand :** Streaming, audio/video, logging haute performance.
**Lié à :** Producer-Consumer, Queue.

---

### 3. Cache (avec stratégies)

> Stocker les résultats pour éviter les recalculs.

```go
package performance

import (
	"container/list"
	"sync"
	"time"
)

// LRUCache is a thread-safe Least Recently Used cache.
type LRUCache[K comparable, V any] struct {
	mu       sync.Mutex
	maxSize  int
	cache    map[K]*list.Element
	evictList *list.List
}

type entry[K comparable, V any] struct {
	key   K
	value V
}

// NewLRUCache creates a new LRU cache.
func NewLRUCache[K comparable, V any](maxSize int) *LRUCache[K, V] {
	return &LRUCache[K, V]{
		maxSize:   maxSize,
		cache:     make(map[K]*list.Element),
		evictList: list.New(),
	}
}

// Get retrieves a value from the cache.
func (c *LRUCache[K, V]) Get(key K) (V, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	var zero V
	if elem, ok := c.cache[key]; ok {
		c.evictList.MoveToFront(elem)
		return elem.Value.(*entry[K, V]).value, true
	}
	return zero, false
}

// Set adds or updates a value in the cache.
func (c *LRUCache[K, V]) Set(key K, value V) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if elem, ok := c.cache[key]; ok {
		c.evictList.MoveToFront(elem)
		elem.Value.(*entry[K, V]).value = value
		return
	}

	if c.evictList.Len() >= c.maxSize {
		oldest := c.evictList.Back()
		if oldest != nil {
			c.evictList.Remove(oldest)
			delete(c.cache, oldest.Value.(*entry[K, V]).key)
		}
	}

	elem := c.evictList.PushFront(&entry[K, V]{key, value})
	c.cache[key] = elem
}

// TTLCache is a cache with time-to-live expiration.
type TTLCache[K comparable, V any] struct {
	mu    sync.RWMutex
	cache map[K]*ttlEntry[V]
	ttl   time.Duration
}

type ttlEntry[V any] struct {
	value   V
	expires time.Time
}

// NewTTLCache creates a new TTL cache.
func NewTTLCache[K comparable, V any](ttl time.Duration) *TTLCache[K, V] {
	return &TTLCache[K, V]{
		cache: make(map[K]*ttlEntry[V]),
		ttl:   ttl,
	}
}

// Set adds a value with TTL.
func (c *TTLCache[K, V]) Set(key K, value V) {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.cache[key] = &ttlEntry[V]{
		value:   value,
		expires: time.Now().Add(c.ttl),
	}
}

// Get retrieves a value if not expired.
func (c *TTLCache[K, V]) Get(key K) (V, bool) {
	c.mu.RLock()
	entry, ok := c.cache[key]
	c.mu.RUnlock()

	var zero V
	if !ok {
		return zero, false
	}

	if time.Now().After(entry.expires) {
		c.mu.Lock()
		delete(c.cache, key)
		c.mu.Unlock()
		return zero, false
	}

	return entry.value, true
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

```go
package performance

import "sync"

// LazyValue holds a lazily-initialized value.
type LazyValue[T any] struct {
	once    sync.Once
	factory func() T
	value   T
}

// NewLazyValue creates a new lazy value.
func NewLazyValue[T any](factory func() T) *LazyValue[T] {
	return &LazyValue[T]{
		factory: factory,
	}
}

// Get returns the value, initializing it if necessary.
func (lv *LazyValue[T]) Get() T {
	lv.once.Do(func() {
		lv.value = lv.factory()
	})
	return lv.value
}

// LazyFunc returns a lazy initializer function (Go 1.21+).
func LazyFunc[T any](factory func() T) func() T {
	return sync.OnceValue(factory)
}

// Usage
type DatabaseConnection struct {
	conn string
}

func NewDatabaseConnection() *DatabaseConnection {
	// Expensive initialization
	return &DatabaseConnection{conn: "connected"}
}

type HeavyService struct {
	database func() *DatabaseConnection
}

func NewHeavyService() *HeavyService {
	return &HeavyService{
		database: sync.OnceValue(func() *DatabaseConnection {
			return NewDatabaseConnection()
		}),
	}
}

func (hs *HeavyService) GetDatabase() *DatabaseConnection {
	return hs.database()
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

```go
package performance

import (
	"context"
	"encoding/json"
	"sync"
)

// Memoize caches function results based on input arguments.
func Memoize[K comparable, V any](fn func(K) V) func(K) V {
	cache := make(map[K]V)
	var mu sync.RWMutex

	return func(key K) V {
		mu.RLock()
		if val, ok := cache[key]; ok {
			mu.RUnlock()
			return val
		}
		mu.RUnlock()

		mu.Lock()
		defer mu.Unlock()

		// Double-check
		if val, ok := cache[key]; ok {
			return val
		}

		result := fn(key)
		cache[key] = result
		return result
	}
}

// MemoizeJSON memoizes functions with complex arguments using JSON serialization.
func MemoizeJSON[T any, R any](fn func(T) R) func(T) R {
	cache := make(map[string]R)
	var mu sync.RWMutex

	return func(arg T) R {
		data, _ := json.Marshal(arg)
		key := string(data)

		mu.RLock()
		if val, ok := cache[key]; ok {
			mu.RUnlock()
			return val
		}
		mu.RUnlock()

		mu.Lock()
		defer mu.Unlock()

		if val, ok := cache[key]; ok {
			return val
		}

		result := fn(arg)
		cache[key] = result
		return result
	}
}

// Usage
var Fibonacci = Memoize(func(n int) int {
	if n <= 1 {
		return n
	}
	return Fibonacci(n-1) + Fibonacci(n-2)
})

// MemoizeAsync caches async function results.
type AsyncResult[V any] struct {
	value V
	err   error
	done  chan struct{}
}

func MemoizeAsync[K comparable, V any](fn func(context.Context, K) (V, error)) func(context.Context, K) (V, error) {
	cache := make(map[K]*AsyncResult[V])
	var mu sync.Mutex

	return func(ctx context.Context, key K) (V, error) {
		mu.Lock()
		result, ok := cache[key]
		if !ok {
			result = &AsyncResult[V]{
				done: make(chan struct{}),
			}
			cache[key] = result
			mu.Unlock()

			// Execute function
			val, err := fn(ctx, key)
			result.value = val
			result.err = err
			close(result.done)

			// Remove from cache on error
			if err != nil {
				mu.Lock()
				delete(cache, key)
				mu.Unlock()
			}

			return val, err
		}
		mu.Unlock()

		// Wait for result
		select {
		case <-result.done:
			return result.value, result.err
		case <-ctx.Done():
			var zero V
			return zero, ctx.Err()
		}
	}
}
```

**Quand :** Fonctions pures, calculs récursifs, API calls identiques.
**Lié à :** Cache, Decorator.

---

### 6. Debounce

> Exécuter après un délai d'inactivité.

```go
package performance

import (
	"sync"
	"time"
)

// Debounce creates a debounced function.
func Debounce[T any](fn func(T), delay time.Duration) func(T) {
	var (
		mu    sync.Mutex
		timer *time.Timer
	)

	return func(arg T) {
		mu.Lock()
		defer mu.Unlock()

		if timer != nil {
			timer.Stop()
		}

		timer = time.AfterFunc(delay, func() {
			fn(arg)
		})
	}
}

// DebounceFunc creates a debounced function with no arguments.
func DebounceFunc(fn func(), delay time.Duration) func() {
	var (
		mu    sync.Mutex
		timer *time.Timer
	)

	return func() {
		mu.Lock()
		defer mu.Unlock()

		if timer != nil {
			timer.Stop()
		}

		timer = time.AfterFunc(delay, fn)
	}
}

// Usage - Recherche en temps réel
type SearchAPI struct{}

func (s *SearchAPI) Search(query string) {
	// Execute search
}

func ExampleDebounce() {
	api := &SearchAPI{}
	debouncedSearch := Debounce(api.Search, 300*time.Millisecond)

	// Simulate user typing
	debouncedSearch("h")
	debouncedSearch("he")
	debouncedSearch("hel")
	debouncedSearch("hello") // Only this executes after 300ms
}
```

**Quand :** Input utilisateur, resize, scroll, recherche.
**Lié à :** Throttle.

---

### 7. Throttle

> Limiter la fréquence d'exécution.

```go
package performance

import (
	"sync"
	"time"
)

// Throttle creates a throttled function.
func Throttle[T any](fn func(T), limit time.Duration) func(T) {
	var (
		mu         sync.Mutex
		inThrottle bool
		lastArgs   *T
	)

	return func(arg T) {
		mu.Lock()

		if inThrottle {
			lastArgs = &arg
			mu.Unlock()
			return
		}

		inThrottle = true
		mu.Unlock()

		fn(arg)

		time.AfterFunc(limit, func() {
			mu.Lock()
			inThrottle = false
			pending := lastArgs
			lastArgs = nil
			mu.Unlock()

			if pending != nil {
				fn(*pending)
			}
		})
	}
}

// ThrottleFunc creates a throttled function with no arguments.
func ThrottleFunc(fn func(), limit time.Duration) func() {
	var (
		mu         sync.Mutex
		inThrottle bool
		pending    bool
	)

	return func() {
		mu.Lock()

		if inThrottle {
			pending = true
			mu.Unlock()
			return
		}

		inThrottle = true
		mu.Unlock()

		fn()

		time.AfterFunc(limit, func() {
			mu.Lock()
			inThrottle = false
			shouldRun := pending
			pending = false
			mu.Unlock()

			if shouldRun {
				fn()
			}
		})
	}
}

// Usage - Animation scroll
func updateParallax() {
	// Update animation
}

func ExampleThrottle() {
	throttledScroll := ThrottleFunc(updateParallax, 16*time.Millisecond) // ~60fps

	// Simulate scroll events
	for i := 0; i < 100; i++ {
		throttledScroll() // Only executes ~6 times (100ms / 16ms)
		time.Sleep(time.Millisecond)
	}
}
```

**Quand :** Events haute fréquence, animations, rate limiting.
**Lié à :** Debounce, Rate Limiter.

---

### 8. Batch Processing

> Grouper les opérations pour réduire l'overhead.

```go
package performance

import (
	"context"
	"sync"
	"time"
)

// BatchProcessor processes items in batches.
type BatchProcessor[T any] struct {
	mu        sync.Mutex
	batch     []T
	timer     *time.Timer
	processor func(context.Context, []T) error
	maxSize   int
	maxWait   time.Duration
	ctx       context.Context
	cancel    context.CancelFunc
}

// NewBatchProcessor creates a new batch processor.
func NewBatchProcessor[T any](
	processor func(context.Context, []T) error,
	maxSize int,
	maxWait time.Duration,
) *BatchProcessor[T] {
	ctx, cancel := context.WithCancel(context.Background())
	return &BatchProcessor[T]{
		processor: processor,
		maxSize:   maxSize,
		maxWait:   maxWait,
		ctx:       ctx,
		cancel:    cancel,
	}
}

// Add adds an item to the batch.
func (bp *BatchProcessor[T]) Add(item T) {
	bp.mu.Lock()
	defer bp.mu.Unlock()

	bp.batch = append(bp.batch, item)

	if len(bp.batch) >= bp.maxSize {
		go bp.Flush()
	} else if bp.timer == nil {
		bp.timer = time.AfterFunc(bp.maxWait, func() {
			bp.Flush()
		})
	}
}

// Flush processes the current batch.
func (bp *BatchProcessor[T]) Flush() {
	bp.mu.Lock()
	if bp.timer != nil {
		bp.timer.Stop()
		bp.timer = nil
	}

	if len(bp.batch) == 0 {
		bp.mu.Unlock()
		return
	}

	items := bp.batch
	bp.batch = nil
	bp.mu.Unlock()

	_ = bp.processor(bp.ctx, items)
}

// Close stops the processor and flushes remaining items.
func (bp *BatchProcessor[T]) Close() {
	bp.cancel()
	bp.Flush()
}

// Usage - Batch insert en DB
type LogEntry struct {
	Level   string
	Message string
}

type Database struct{}

func (db *Database) InsertLogs(ctx context.Context, entries []LogEntry) error {
	// Batch insert
	return nil
}

func ExampleBatchProcessor() {
	db := &Database{}
	batcher := NewBatchProcessor(
		func(ctx context.Context, entries []LogEntry) error {
			return db.InsertLogs(ctx, entries)
		},
		100,              // Max 100 entries
		1*time.Second,    // Ou après 1 seconde
	)
	defer batcher.Close()

	batcher.Add(LogEntry{Level: "info", Message: "Hello"})
}
```

**Quand :** Insertions DB, API calls, événements.
**Lié à :** Buffer, Queue.

---

### 9. Pagination / Cursor

> Charger les données par morceaux.

```go
package performance

import "context"

// OffsetPagination represents offset-based pagination.
type OffsetPagination struct {
	Page     int
	PageSize int
	Total    int
}

// OffsetPage represents a page of results.
type OffsetPage[T any] struct {
	Data       []T
	Pagination OffsetPagination
}

// GetPageOffset retrieves a page using offset pagination.
func GetPageOffset[T any](
	ctx context.Context,
	query func(ctx context.Context, offset, limit int) ([]T, int, error),
	page int,
	pageSize int,
) (*OffsetPage[T], error) {
	offset := (page - 1) * pageSize
	data, total, err := query(ctx, offset, pageSize)
	if err != nil {
		return nil, err
	}

	return &OffsetPage[T]{
		Data: data,
		Pagination: OffsetPagination{
			Page:     page,
			PageSize: pageSize,
			Total:    total,
		},
	}, nil
}

// CursorPagination represents cursor-based pagination.
type CursorPagination struct {
	Cursor  *string
	HasMore bool
}

// CursorPage represents a cursor-based page.
type CursorPage[T any] struct {
	Data       []T
	Pagination CursorPagination
}

// Cursorable represents an item with a cursor ID.
type Cursorable interface {
	GetCursor() string
}

// GetPageCursor retrieves a page using cursor pagination.
func GetPageCursor[T Cursorable](
	ctx context.Context,
	query func(ctx context.Context, cursor *string, limit int) ([]T, error),
	cursor *string,
	limit int,
) (*CursorPage[T], error) {
	data, err := query(ctx, cursor, limit)
	if err != nil {
		return nil, err
	}

	hasMore := len(data) == limit
	var nextCursor *string
	if hasMore && len(data) > 0 {
		c := data[len(data)-1].GetCursor()
		nextCursor = &c
	}

	return &CursorPage[T]{
		Data: data,
		Pagination: CursorPagination{
			Cursor:  nextCursor,
			HasMore: hasMore,
		},
	}, nil
}
```

**Quand :** Listes longues, infinite scroll, API REST.
**Lié à :** Lazy Loading, Iterator.

---

### 10. Connection Pooling

> Pool de connexions réutilisables.

```go
package performance

import (
	"context"
	"errors"
	"sync"
)

var ErrPoolClosed = errors.New("connection pool closed")

// Connection represents a pooled connection.
type Connection interface {
	Query(ctx context.Context, sql string) error
	Close() error
}

// ConnectionPool manages a pool of reusable connections.
type ConnectionPool struct {
	mu             sync.Mutex
	available      chan Connection
	factory        func(context.Context) (Connection, error)
	maxConnections int
	activeCount    int
	closed         bool
}

// NewConnectionPool creates a new connection pool.
func NewConnectionPool(
	factory func(context.Context) (Connection, error),
	maxConnections int,
) *ConnectionPool {
	return &ConnectionPool{
		available:      make(chan Connection, maxConnections),
		factory:        factory,
		maxConnections: maxConnections,
	}
}

// Acquire retrieves a connection from the pool.
func (cp *ConnectionPool) Acquire(ctx context.Context) (Connection, error) {
	cp.mu.Lock()
	if cp.closed {
		cp.mu.Unlock()
		return nil, ErrPoolClosed
	}

	// Try to get available connection
	select {
	case conn := <-cp.available:
		cp.activeCount++
		cp.mu.Unlock()
		return cp.wrapConnection(conn), nil
	default:
	}

	// Create new if under limit
	if cp.activeCount < cp.maxConnections {
		cp.activeCount++
		cp.mu.Unlock()

		conn, err := cp.factory(ctx)
		if err != nil {
			cp.mu.Lock()
			cp.activeCount--
			cp.mu.Unlock()
			return nil, err
		}
		return cp.wrapConnection(conn), nil
	}
	cp.mu.Unlock()

	// Wait for available connection
	select {
	case conn := <-cp.available:
		return cp.wrapConnection(conn), nil
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

type wrappedConnection struct {
	Connection
	pool *ConnectionPool
}

func (wc *wrappedConnection) Close() error {
	wc.pool.release(wc.Connection)
	return nil
}

func (cp *ConnectionPool) wrapConnection(conn Connection) Connection {
	return &wrappedConnection{
		Connection: conn,
		pool:       cp,
	}
}

func (cp *ConnectionPool) release(conn Connection) {
	cp.mu.Lock()
	defer cp.mu.Unlock()

	if cp.closed {
		_ = conn.Close()
		return
	}

	cp.activeCount--
	select {
	case cp.available <- conn:
	default:
		_ = conn.Close()
	}
}

// Close closes all connections in the pool.
func (cp *ConnectionPool) Close() error {
	cp.mu.Lock()
	defer cp.mu.Unlock()

	if cp.closed {
		return nil
	}
	cp.closed = true

	close(cp.available)
	for conn := range cp.available {
		_ = conn.Close()
	}
	return nil
}
```

**Quand :** Connexions DB, HTTP clients, WebSockets.
**Lié à :** Object Pool, Resource Management.

---

### 11. Double Buffering

> Deux buffers alternés pour éviter les conflits.

```go
package performance

import "sync/atomic"

// DoubleBuffer maintains two buffers for lock-free read/write.
type DoubleBuffer[T any] struct {
	buffers    [2][]T
	writeIndex atomic.Uint32
}

// NewDoubleBuffer creates a new double buffer.
func NewDoubleBuffer[T any]() *DoubleBuffer[T] {
	return &DoubleBuffer[T]{
		buffers: [2][]T{{}, {}},
	}
}

// ReadBuffer returns the current read buffer.
func (db *DoubleBuffer[T]) ReadBuffer() []T {
	idx := db.writeIndex.Load()
	return db.buffers[1-idx]
}

// WriteBuffer returns the current write buffer.
func (db *DoubleBuffer[T]) WriteBuffer() []T {
	idx := db.writeIndex.Load()
	return db.buffers[idx]
}

// Swap swaps the buffers and clears the new write buffer.
func (db *DoubleBuffer[T]) Swap() {
	idx := db.writeIndex.Load()
	newIdx := 1 - idx
	db.buffers[newIdx] = db.buffers[newIdx][:0] // Clear
	db.writeIndex.Store(newIdx)
}

// Write adds an item to the write buffer.
func (db *DoubleBuffer[T]) Write(item T) {
	idx := db.writeIndex.Load()
	db.buffers[idx] = append(db.buffers[idx], item)
}

// Usage - Rendering
type DrawCommand struct {
	X, Y int
}

type Renderer struct {
	buffer *DoubleBuffer[DrawCommand]
}

func NewRenderer() *Renderer {
	return &Renderer{
		buffer: NewDoubleBuffer[DrawCommand](),
	}
}

func (r *Renderer) Draw(cmd DrawCommand) {
	r.buffer.Write(cmd)
}

func (r *Renderer) Render() {
	r.buffer.Swap()
	for _, cmd := range r.buffer.ReadBuffer() {
		r.execute(cmd)
	}
}

func (r *Renderer) execute(cmd DrawCommand) {
	// Execute draw command
}
```

**Quand :** Graphics, audio, game loops, animations.
**Lié à :** Buffer, Producer-Consumer.

---

### 12. Flyweight (optimisation mémoire)

> Voir structural/README.md pour détails.

Partager l'état intrinsèque (immutable) entre objets similaires.

```go
package performance

import "sync"

// ParticleType represents shared immutable particle data.
type ParticleType struct {
	Color   string
	Texture string
	Mass    float64
}

var (
	particleTypes = map[string]*ParticleType{
		"smoke": {"gray", "smoke.png", 0.5},
		"fire":  {"orange", "fire.png", 1.0},
		"spark": {"yellow", "spark.png", 0.3},
	}
	particleTypesMu sync.RWMutex
)

// GetParticleType returns a shared particle type (flyweight).
func GetParticleType(name string) *ParticleType {
	particleTypesMu.RLock()
	pt, ok := particleTypes[name]
	particleTypesMu.RUnlock()

	if ok {
		return pt
	}

	particleTypesMu.Lock()
	defer particleTypesMu.Unlock()

	// Double-check
	if pt, ok := particleTypes[name]; ok {
		return pt
	}

	// Create new type
	pt = &ParticleType{Color: "white", Texture: "default.png", Mass: 1.0}
	particleTypes[name] = pt
	return pt
}

// Particle represents a single particle with extrinsic state.
type Particle struct {
	X, Y float64
	Type *ParticleType // Flyweight partagé
}

// NewParticle creates a new particle.
func NewParticle(x, y float64, typeName string) *Particle {
	return &Particle{
		X:    x,
		Y:    y,
		Type: GetParticleType(typeName),
	}
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

```go
package performance

// PoolBuffer combines object pooling with ring buffering.
type PoolBuffer[T any] struct {
	pool   *Pool[T]
	buffer *RingBuffer[T]
}

// NewPoolBuffer creates a new pool buffer.
func NewPoolBuffer[T any](
	factory func() *T,
	reset func(*T),
	poolSize int,
	bufferSize int,
) *PoolBuffer[T] {
	return &PoolBuffer[T]{
		pool:   NewPool(factory, reset),
		buffer: NewRingBuffer[T](bufferSize),
	}
}

// Produce acquires from pool and writes to buffer.
func (pb *PoolBuffer[T]) Produce() (*T, error) {
	if pb.buffer.IsFull() {
		return nil, ErrBufferFull
	}

	obj := pb.pool.Acquire()
	if err := pb.buffer.Write(*obj); err != nil {
		pb.pool.Release(obj)
		return nil, err
	}
	return obj, nil
}

// Consume reads from buffer and releases to pool.
func (pb *PoolBuffer[T]) Consume() (*T, error) {
	obj, err := pb.buffer.Read()
	if err != nil {
		return nil, err
	}

	// After processing, caller should release
	return &obj, nil
}

// Release returns an object to the pool.
func (pb *PoolBuffer[T]) Release(obj *T) {
	pb.pool.Release(obj)
}
```

**Usage :** Streaming haute performance, game objects, message queues.

## Sources

- [Game Programming Patterns - Optimization](https://gameprogrammingpatterns.com/optimization-patterns.html)
- [Martin Fowler - Performance Patterns](https://martinfowler.com/articles/patterns-of-distributed-systems/)
