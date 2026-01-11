# Identity Map

> "Ensures that each object gets loaded only once by keeping every loaded object in a map. Looks up objects using the map when referring to them." - Martin Fowler, PoEAA

## Concept

Identity Map est un cache qui stocke tous les objets charges depuis la base de donnees, indexes par leur identite. Il garantit qu'il n'y a qu'une seule instance de chaque objet en memoire pendant une session.

## Objectifs

1. **Unicite** : Une seule instance par entite
2. **Performance** : Eviter les requetes repetees
3. **Coherence** : Modifications visibles partout
4. **Integration** : Fonctionne avec Unit of Work

## Implementation Go

```go
package identitymap

import (
	"sync"
)

// Entity represents a domain entity.
type Entity interface {
	GetID() string
}

// IdentityMap is a generic identity map.
type IdentityMap[T Entity] struct {
	mu   sync.RWMutex
	data map[string]T
}

// NewIdentityMap creates a new identity map.
func NewIdentityMap[T Entity]() *IdentityMap[T] {
	return &IdentityMap[T]{
		data: make(map[string]T),
	}
}

// Get retrieves an entity by ID.
func (m *IdentityMap[T]) Get(id string) (T, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	entity, ok := m.data[id]
	return entity, ok
}

// Add adds an entity to the map.
func (m *IdentityMap[T]) Add(entity T) {
	m.mu.Lock()
	defer m.mu.Unlock()

	id := entity.GetID()
	if id == "" {
		panic("entity must have an ID")
	}

	m.data[id] = entity
}

// Has checks if an entity exists.
func (m *IdentityMap[T]) Has(id string) bool {
	m.mu.RLock()
	defer m.mu.RUnlock()

	_, ok := m.data[id]
	return ok
}

// Remove removes an entity from the map.
func (m *IdentityMap[T]) Remove(id string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	if _, ok := m.data[id]; !ok {
		return false
	}

	delete(m.data, id)
	return true
}

// Clear removes all entities.
func (m *IdentityMap[T]) Clear() {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.data = make(map[string]T)
}

// GetAll returns all entities.
func (m *IdentityMap[T]) GetAll() []T {
	m.mu.RLock()
	defer m.mu.RUnlock()

	entities := make([]T, 0, len(m.data))
	for _, entity := range m.data {
		entities = append(entities, entity)
	}

	return entities
}

// Size returns the number of entities.
func (m *IdentityMap[T]) Size() int {
	m.mu.RLock()
	defer m.mu.RUnlock()

	return len(m.data)
}

// TypedIdentityMap manages multiple entity types.
type TypedIdentityMap struct {
	mu   sync.RWMutex
	maps map[string]any
}

// NewTypedIdentityMap creates a new typed identity map.
func NewTypedIdentityMap() *TypedIdentityMap {
	return &TypedIdentityMap{
		maps: make(map[string]any),
	}
}

// getMap retrieves or creates a map for a type.
func (m *TypedIdentityMap) getMap(typeName string) *IdentityMap[Entity] {
	if existingMap, ok := m.maps[typeName]; ok {
		return existingMap.(*IdentityMap[Entity])
	}

	newMap := NewIdentityMap[Entity]()
	m.maps[typeName] = newMap
	return newMap
}

// Get retrieves an entity by type and ID.
func (m *TypedIdentityMap) Get(typeName, id string) (Entity, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	entityMap := m.getMap(typeName)
	return entityMap.Get(id)
}

// Add adds an entity.
func (m *TypedIdentityMap) Add(typeName string, entity Entity) {
	m.mu.Lock()
	defer m.mu.Unlock()

	entityMap := m.getMap(typeName)
	entityMap.Add(entity)
}

// Has checks if an entity exists.
func (m *TypedIdentityMap) Has(typeName, id string) bool {
	m.mu.RLock()
	defer m.mu.RUnlock()

	entityMap := m.getMap(typeName)
	return entityMap.Has(id)
}

// Remove removes an entity.
func (m *TypedIdentityMap) Remove(typeName, id string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()

	entityMap := m.getMap(typeName)
	return entityMap.Remove(id)
}

// ClearAll clears all maps.
func (m *TypedIdentityMap) ClearAll() {
	m.mu.Lock()
	defer m.mu.Unlock()

	m.maps = make(map[string]any)
}

// ClearType clears a specific type map.
func (m *TypedIdentityMap) ClearType(typeName string) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if entityMap, ok := m.maps[typeName]; ok {
		entityMap.(*IdentityMap[Entity]).Clear()
	}
}
```

## Integration avec Repository

```go
package repository

import (
	"context"
	"database/sql"
	"fmt"
)

// Order represents an order entity.
type Order struct {
	ID         string
	CustomerID string
	Status     string
}

func (o *Order) GetID() string { return o.ID }

// OrderDataMapper handles order persistence.
type OrderDataMapper struct {
	db *sql.DB
}

func (m *OrderDataMapper) FindByID(ctx context.Context, id string) (*Order, error) {
	// Implementation omitted
	return nil, nil
}

func (m *OrderDataMapper) FindByCustomerID(ctx context.Context, customerID string) ([]*Order, error) {
	// Implementation omitted
	return nil, nil
}

// OrderRepository uses identity map.
type OrderRepository struct {
	db          *sql.DB
	mapper      *OrderDataMapper
	identityMap *IdentityMap[*Order]
}

// NewOrderRepository creates a new repository.
func NewOrderRepository(db *sql.DB, mapper *OrderDataMapper) *OrderRepository {
	return &OrderRepository{
		db:          db,
		mapper:      mapper,
		identityMap: NewIdentityMap[*Order](),
	}
}

// FindByID finds an order, checking identity map first.
func (r *OrderRepository) FindByID(ctx context.Context, id string) (*Order, error) {
	// 1. Check identity map first
	if order, ok := r.identityMap.Get(id); ok {
		return order, nil
	}

	// 2. Load from database
	order, err := r.mapper.FindByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("mapper find by id: %w", err)
	}
	if order == nil {
		return nil, nil
	}

	// 3. Add to identity map
	r.identityMap.Add(order)

	return order, nil
}

// FindByCustomerID finds orders by customer.
func (r *OrderRepository) FindByCustomerID(ctx context.Context, customerID string) ([]*Order, error) {
	// Query database
	orders, err := r.mapper.FindByCustomerID(ctx, customerID)
	if err != nil {
		return nil, fmt.Errorf("mapper find by customer: %w", err)
	}

	// Add/update identity map
	result := make([]*Order, len(orders))
	for i, order := range orders {
		if cached, ok := r.identityMap.Get(order.ID); ok {
			// Return existing instance
			result[i] = cached
		} else {
			r.identityMap.Add(order)
			result[i] = order
		}
	}

	return result, nil
}

// Save saves an order.
func (r *OrderRepository) Save(ctx context.Context, order *Order) error {
	// Implementation omitted
	// Ensure identity map is updated
	if !r.identityMap.Has(order.ID) {
		r.identityMap.Add(order)
	}
	return nil
}

// Delete deletes an order.
func (r *OrderRepository) Delete(ctx context.Context, order *Order) error {
	// Implementation omitted
	r.identityMap.Remove(order.ID)
	return nil
}
```

## Session-Scoped Identity Map

```go
package session

import (
	"context"
	"database/sql"
)

// Session represents a database session with identity map.
type Session struct {
	db          *sql.DB
	identityMap *TypedIdentityMap
	unitOfWork  *UnitOfWork
}

// NewSession creates a new session.
func NewSession(db *sql.DB, mappers *MapperRegistry) *Session {
	identityMap := NewTypedIdentityMap()
	return &Session{
		db:          db,
		identityMap: identityMap,
		unitOfWork:  NewUnitOfWork(db, mappers),
	}
}

// GetIdentityMap returns the session's identity map.
func (s *Session) GetIdentityMap() *TypedIdentityMap {
	return s.identityMap
}

// GetOrderRepository creates an order repository for this session.
func (s *Session) GetOrderRepository() *OrderRepository {
	mapper := &OrderDataMapper{db: s.db}
	return &OrderRepository{
		db:          s.db,
		mapper:      mapper,
		identityMap: s.identityMap.getOrderMap(),
	}
}

// Commit commits the unit of work.
func (s *Session) Commit(ctx context.Context) error {
	return s.unitOfWork.Commit(ctx)
}

// Close clears the identity map.
func (s *Session) Close() {
	s.identityMap.ClearAll()
}

// Usage example
func HandleRequest(req *Request, res *Response) error {
	session := NewSession(db, mappers)
	defer session.Close()

	orderRepo := session.GetOrderRepository()
	customerRepo := session.GetCustomerRepository()

	// Same identity map = same instances
	order, err := orderRepo.FindByID(ctx, req.Params.ID)
	if err != nil {
		return err
	}

	customer, err := customerRepo.FindByID(ctx, order.CustomerID)
	if err != nil {
		return err
	}

	// If we reload order.customer, we get the same instance
	sameCustomer, _ := order.GetCustomer()
	// customer == sameCustomer (true)

	if err := session.Commit(ctx); err != nil {
		return err
	}

	return json.NewEncoder(res).Encode(order)
}
```

## Comparaison avec alternatives

| Aspect | Identity Map | Simple Cache | No Cache |
|--------|--------------|--------------|----------|
| Unicite garantie | Oui | Non | Non |
| Coherence | Oui | Non | Oui (DB) |
| Performance | Bonne | Bonne | Mauvaise |
| Memoire | Session-bound | Configurable | Minimale |
| Complexite | Moyenne | Faible | Aucune |

## Quand utiliser

**Utiliser Identity Map quand :**

- ORM avec Domain Model
- Relations entre entites
- Modifications multiples de memes objets
- Besoin de coherence en memoire
- Unit of Work

**Eviter Identity Map quand :**

- CRUD simple sans relations
- Requetes read-only pures
- Objets immutables (Value Objects)
- Long-running processes (memoire)

## Patterns liés

- [Unit of Work](./unit-of-work.md) - Gestion transactionnelle avec Identity Map
- [Repository](./repository.md) - Utilise Identity Map pour le cache
- [Data Mapper](./data-mapper.md) - Charge les entites dans Identity Map
- [Lazy Load](./lazy-load.md) - Chargement differe avec cache Identity Map

## Sources

- Martin Fowler, PoEAA, Chapter 11
- [Identity Map - martinfowler.com](https://martinfowler.com/eaaCatalog/identityMap.html)
