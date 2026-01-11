# Lazy Load

> "An object that doesn't contain all of the data you need but knows how to get it." - Martin Fowler, PoEAA

## Concept

Lazy Load est un pattern qui differe le chargement des donnees jusqu'au moment ou elles sont reellement necessaires. Cela ameliore les performances en evitant de charger des donnees qui ne seront peut-etre jamais utilisees.

## Quatre variantes

1. **Lazy Initialization** : Champ initialise a null, charge au premier acces
2. **Virtual Proxy** : Objet proxy qui charge le vrai objet a la demande
3. **Value Holder** : Wrapper generique qui encapsule le chargement
4. **Ghost** : Objet partiellement charge qui se complete lui-meme

## Lazy Initialization

```go
package lazyload

import (
	"context"
	"fmt"
	"sync"
)

// Customer represents a customer entity.
type Customer struct {
	ID   string
	Name string
}

// CustomerLoader loads customers.
type CustomerLoader interface {
	Load(ctx context.Context, id string) (*Customer, error)
}

// Order with lazy-loaded customer.
type Order struct {
	ID         string
	CustomerID string

	customer       *Customer
	customerOnce   sync.Once
	customerLoader CustomerLoader
	mu             sync.RWMutex
}

// NewOrder creates a new order.
func NewOrder(id, customerID string, loader CustomerLoader) *Order {
	return &Order{
		ID:             id,
		CustomerID:     customerID,
		customerLoader: loader,
	}
}

// GetCustomer returns the customer, loading it if necessary.
func (o *Order) GetCustomer(ctx context.Context) (*Customer, error) {
	var err error

	o.customerOnce.Do(func() {
		customer, loadErr := o.customerLoader.Load(ctx, o.CustomerID)
		if loadErr != nil {
			err = loadErr
			return
		}

		o.mu.Lock()
		o.customer = customer
		o.mu.Unlock()
	})

	if err != nil {
		return nil, fmt.Errorf("load customer: %w", err)
	}

	o.mu.RLock()
	defer o.mu.RUnlock()
	return o.customer, nil
}
```

## Value Holder

```go
// Lazy is a generic value holder.
type Lazy[T any] struct {
	loader func(context.Context) (T, error)
	value  T
	loaded bool
	mu     sync.RWMutex
	once   sync.Once
	err    error
}

// NewLazy creates a new lazy value.
func NewLazy[T any](loader func(context.Context) (T, error)) *Lazy[T] {
	return &Lazy[T]{
		loader: loader,
	}
}

// Get returns the value, loading it if necessary.
func (l *Lazy[T]) Get(ctx context.Context) (T, error) {
	l.once.Do(func() {
		value, err := l.loader(ctx)
		if err != nil {
			l.err = err
			return
		}

		l.mu.Lock()
		l.value = value
		l.loaded = true
		l.mu.Unlock()
	})

	if l.err != nil {
		var zero T
		return zero, l.err
	}

	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.value, nil
}

// IsLoaded returns true if the value has been loaded.
func (l *Lazy[T]) IsLoaded() bool {
	l.mu.RLock()
	defer l.mu.RUnlock()
	return l.loaded
}

// Reset resets the lazy value.
func (l *Lazy[T]) Reset() {
	l.mu.Lock()
	defer l.mu.Unlock()

	var zero T
	l.value = zero
	l.loaded = false
	l.err = nil
	l.once = sync.Once{}
}

// OrderItem represents an order item.
type OrderItem struct {
	ID        string
	ProductID string
	Quantity  int
}

// OrderWithLazy uses lazy value holders.
type OrderWithLazy struct {
	ID         string
	CustomerID string

	customer *Lazy[*Customer]
	items    *Lazy[[]*OrderItem]
}

// NewOrderWithLazy creates an order with lazy loading.
func NewOrderWithLazy(
	id, customerID string,
	customerLoader func(context.Context, string) (*Customer, error),
	itemsLoader func(context.Context, string) ([]*OrderItem, error),
) *OrderWithLazy {
	return &OrderWithLazy{
		ID:         id,
		CustomerID: customerID,
		customer: NewLazy(func(ctx context.Context) (*Customer, error) {
			return customerLoader(ctx, customerID)
		}),
		items: NewLazy(func(ctx context.Context) ([]*OrderItem, error) {
			return itemsLoader(ctx, id)
		}),
	}
}

// GetCustomer returns the lazy-loaded customer.
func (o *OrderWithLazy) GetCustomer(ctx context.Context) (*Customer, error) {
	return o.customer.Get(ctx)
}

// GetItems returns the lazy-loaded items.
func (o *OrderWithLazy) GetItems(ctx context.Context) ([]*OrderItem, error) {
	return o.items.Get(ctx)
}
```

## Ghost Pattern

```go
// ProductGhost is a partially loaded product.
type ProductGhost struct {
	id string

	// Lazy-loaded properties
	name        string
	description string
	price       float64
	stock       int
	loaded      bool

	loader func(context.Context, string) (*ProductData, error)
	once   sync.Once
	mu     sync.RWMutex
	err    error
}

// ProductData represents full product data.
type ProductData struct {
	Name        string
	Description string
	Price       float64
	Stock       int
}

// NewProductGhost creates a new product ghost.
func NewProductGhost(id string, loader func(context.Context, string) (*ProductData, error)) *ProductGhost {
	return &ProductGhost{
		id:     id,
		loader: loader,
	}
}

// GetID returns the product ID (always available).
func (p *ProductGhost) GetID() string {
	return p.id
}

func (p *ProductGhost) ensureLoaded(ctx context.Context) error {
	p.once.Do(func() {
		data, err := p.loader(ctx, p.id)
		if err != nil {
			p.err = err
			return
		}

		p.mu.Lock()
		p.name = data.Name
		p.description = data.Description
		p.price = data.Price
		p.stock = data.Stock
		p.loaded = true
		p.mu.Unlock()
	})

	return p.err
}

// GetName returns the product name.
func (p *ProductGhost) GetName(ctx context.Context) (string, error) {
	if err := p.ensureLoaded(ctx); err != nil {
		return "", err
	}

	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.name, nil
}

// GetDescription returns the product description.
func (p *ProductGhost) GetDescription(ctx context.Context) (string, error) {
	if err := p.ensureLoaded(ctx); err != nil {
		return "", err
	}

	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.description, nil
}

// GetPrice returns the product price.
func (p *ProductGhost) GetPrice(ctx context.Context) (float64, error) {
	if err := p.ensureLoaded(ctx); err != nil {
		return 0, err
	}

	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.price, nil
}

// GetStock returns the product stock.
func (p *ProductGhost) GetStock(ctx context.Context) (int, error) {
	if err := p.ensureLoaded(ctx); err != nil {
		return 0, err
	}

	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.stock, nil
}
```

## Batch Loading (DataLoader pattern)

```go
// BatchLoader implements the DataLoader pattern.
type BatchLoader[K comparable, V any] struct {
	loadFunc func(context.Context, []K) (map[K]V, error)
	batch    map[K][]chan result[V]
	mu       sync.Mutex
	delay    time.Duration
	timer    *time.Timer
}

type result[V any] struct {
	value V
	err   error
}

// NewBatchLoader creates a new batch loader.
func NewBatchLoader[K comparable, V any](
	loadFunc func(context.Context, []K) (map[K]V, error),
	delay time.Duration,
) *BatchLoader[K, V] {
	return &BatchLoader[K, V]{
		loadFunc: loadFunc,
		batch:    make(map[K][]chan result[V]),
		delay:    delay,
	}
}

// Load loads a value by key.
func (l *BatchLoader[K, V]) Load(ctx context.Context, key K) (V, error) {
	resultCh := make(chan result[V], 1)

	l.mu.Lock()
	if l.batch[key] == nil {
		l.batch[key] = []chan result[V]{}
	}
	l.batch[key] = append(l.batch[key], resultCh)

	// Start timer if not already running
	if l.timer == nil {
		l.timer = time.AfterFunc(l.delay, func() {
			l.executeBatch(ctx)
		})
	}
	l.mu.Unlock()

	// Wait for result
	r := <-resultCh
	return r.value, r.err
}

func (l *BatchLoader[K, V]) executeBatch(ctx context.Context) {
	l.mu.Lock()
	batch := l.batch
	l.batch = make(map[K][]chan result[V])
	l.timer = nil
	l.mu.Unlock()

	// Extract keys
	keys := make([]K, 0, len(batch))
	for key := range batch {
		keys = append(keys, key)
	}

	// Load all values
	values, err := l.loadFunc(ctx, keys)

	// Distribute results
	for key, channels := range batch {
		var r result[V]
		if err != nil {
			r.err = err
		} else if value, ok := values[key]; ok {
			r.value = value
		} else {
			r.err = fmt.Errorf("key not found: %v", key)
		}

		for _, ch := range channels {
			ch <- r
		}
	}
}
```

## Comparaison des variantes

| Variante | Complexite | Use Case | Avantage |
|----------|------------|----------|----------|
| Lazy Init | Faible | Simple, un champ | Simple a implementer |
| Virtual Proxy | Moyenne | Interface complete | Transparent pour le client |
| Value Holder | Moyenne | Generique, reutilisable | Type-safe, reutilisable |
| Ghost | Elevee | Objets complexes | Un seul chargement |

## Quand utiliser

**Utiliser Lazy Load quand :**

- Relations one-to-many ou many-to-many
- Donnees rarement accedees
- Donnees volumineuses (LOB, collections)
- Performance critique

**Eviter Lazy Load quand :**

- Donnees toujours necessaires (eager load)
- N+1 queries problem (batch loading)
- Contexte deconnecte (DTOs)

## Patterns liés

- [Identity Map](./identity-map.md) - Cache des entites chargees paresseusement
- [Repository](./repository.md) - Fournit les methodes de chargement
- [Data Mapper](./data-mapper.md) - Execute le chargement des donnees
- [Unit of Work](./unit-of-work.md) - Tracking des entites lazy-loaded

## Sources

- Martin Fowler, PoEAA, Chapter 11
- [Lazy Load - martinfowler.com](https://martinfowler.com/eaaCatalog/lazyLoad.html)
