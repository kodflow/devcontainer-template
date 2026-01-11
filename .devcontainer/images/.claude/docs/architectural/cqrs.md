# CQRS - Command Query Responsibility Segregation

> Séparer les modèles de lecture et d'écriture.

**Auteur :** Greg Young (basé sur CQS de Bertrand Meyer)

## Principe

```
┌────────────────────────────────────────────────────────────────┐
│                           CLIENT                                │
└───────────────────────┬────────────────────┬───────────────────┘
                        │                    │
            ┌───────────▼───────┐  ┌─────────▼─────────┐
            │     COMMANDS      │  │      QUERIES      │
            │  (Write Model)    │  │   (Read Model)    │
            └───────────┬───────┘  └─────────┬─────────┘
                        │                    │
            ┌───────────▼───────┐  ┌─────────▼─────────┐
            │  Command Handler  │  │   Query Handler   │
            └───────────┬───────┘  └─────────┬─────────┘
                        │                    │
            ┌───────────▼───────┐  ┌─────────▼─────────┐
            │    Write DB       │  │     Read DB       │
            │  (Normalized)     │  │  (Denormalized)   │
            └───────────────────┘  └───────────────────┘
```

## Niveaux de CQRS

### Niveau 1 : Séparation logique

```go
package service

import "context"

// CreateUserDTO is the data transfer object for creating a user.
type CreateUserDTO struct {
	Email string
	Name  string
}

// UpdateUserDTO is the data transfer object for updating a user.
type UpdateUserDTO struct {
	Name string
}

// UserDTO is the data transfer object for user queries.
type UserDTO struct {
	ID    string
	Email string
	Name  string
}

// SearchCriteria defines search parameters.
type SearchCriteria struct {
	Email string
	Name  string
}

// UserCommandService handles user write operations.
type UserCommandService struct {
	repo UserRepository
}

// Create creates a new user.
func (s *UserCommandService) Create(ctx context.Context, dto CreateUserDTO) error {
	user := &User{
		Email: dto.Email,
		Name:  dto.Name,
	}
	return s.repo.Save(ctx, user)
}

// Update updates an existing user.
func (s *UserCommandService) Update(ctx context.Context, id string, dto UpdateUserDTO) error {
	user, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return err
	}
	user.Name = dto.Name
	return s.repo.Save(ctx, user)
}

// UserQueryService handles user read operations.
type UserQueryService struct {
	repo UserRepository
}

// GetByID retrieves a user by ID.
func (s *UserQueryService) GetByID(ctx context.Context, id string) (*UserDTO, error) {
	user, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return nil, err
	}
	return &UserDTO{
		ID:    user.ID,
		Email: user.Email,
		Name:  user.Name,
	}, nil
}

// Search searches users by criteria.
func (s *UserQueryService) Search(ctx context.Context, criteria SearchCriteria) ([]*UserDTO, error) {
	users, err := s.repo.Search(ctx, criteria)
	if err != nil {
		return nil, err
	}

	dtos := make([]*UserDTO, len(users))
	for i, user := range users {
		dtos[i] = &UserDTO{
			ID:    user.ID,
			Email: user.Email,
			Name:  user.Name,
		}
	}
	return dtos, nil
}
```

### Niveau 2 : Bases séparées

```go
package handler

import (
	"context"
	"fmt"
)

// CreateUserCommand represents a command to create a user.
type CreateUserCommand struct {
	User *User
}

// UserCreatedEvent represents an event when a user is created.
type UserCreatedEvent struct {
	User *User
}

// UserCommandHandler handles user commands with separate write DB.
type UserCommandHandler struct {
	writeDB  WriteDatabase     // PostgreSQL (normalized)
	eventBus EventBus
}

// Handle handles the create user command.
func (h *UserCommandHandler) Handle(ctx context.Context, cmd CreateUserCommand) error {
	if err := h.writeDB.Insert(ctx, cmd.User); err != nil {
		return fmt.Errorf("inserting user: %w", err)
	}

	event := UserCreatedEvent{User: cmd.User}
	if err := h.eventBus.Publish(ctx, event); err != nil {
		return fmt.Errorf("publishing event: %w", err)
	}

	return nil
}

// UserProjection synchronizes read model from events.
type UserProjection struct {
	readDB ReadDatabase // Elasticsearch (optimized for search)
}

// OnUserCreated handles user created events.
func (p *UserProjection) OnUserCreated(ctx context.Context, event UserCreatedEvent) error {
	if err := p.readDB.Index(ctx, event.User); err != nil {
		return fmt.Errorf("indexing user: %w", err)
	}
	return nil
}
```

### Niveau 3 : Avec Event Sourcing

```
Commands → Event Store → Projections → Read Models
```

## Exemple complet

### Command

```go
package commands

import (
	"context"
	"fmt"
)

// OrderItem represents an item in an order.
type OrderItem struct {
	ProductID string
	Quantity  int
	Price     float64
}

// CreateOrderCommand represents a command to create an order.
type CreateOrderCommand struct {
	UserID string
	Items  []OrderItem
}

// CreateOrderHandler handles order creation commands.
type CreateOrderHandler struct {
	orderRepo OrderRepository
	eventBus  EventBus
}

// NewCreateOrderHandler creates a new create order handler.
func NewCreateOrderHandler(orderRepo OrderRepository, eventBus EventBus) *CreateOrderHandler {
	return &CreateOrderHandler{
		orderRepo: orderRepo,
		eventBus:  eventBus,
	}
}

// Handle handles the create order command.
func (h *CreateOrderHandler) Handle(ctx context.Context, cmd CreateOrderCommand) error {
	order := CreateOrder(cmd.UserID, cmd.Items)

	if err := h.orderRepo.Save(ctx, order); err != nil {
		return fmt.Errorf("saving order: %w", err)
	}

	event := OrderCreatedEvent{Order: order}
	if err := h.eventBus.Publish(ctx, event); err != nil {
		return fmt.Errorf("publishing event: %w", err)
	}

	return nil
}
```

### Query

```go
package queries

import "context"

// OrderDTO is the data transfer object for orders.
type OrderDTO struct {
	ID        string
	UserID    string
	UserName  string
	Items     []OrderItem
	Total     float64
	CreatedAt time.Time
}

// GetOrderQuery represents a query to get an order.
type GetOrderQuery struct {
	OrderID string
}

// GetOrderHandler handles order queries.
type GetOrderHandler struct {
	readDB ReadDatabase
}

// NewGetOrderHandler creates a new get order handler.
func NewGetOrderHandler(readDB ReadDatabase) *GetOrderHandler {
	return &GetOrderHandler{readDB: readDB}
}

// Handle handles the get order query.
func (h *GetOrderHandler) Handle(ctx context.Context, query GetOrderQuery) (*OrderDTO, error) {
	// Read from denormalized view (fast)
	order, err := h.readDB.Orders.FindByID(ctx, query.OrderID)
	if err != nil {
		return nil, err
	}
	return order, nil
}
```

### Projection (Sync read model)

```go
package projections

import (
	"context"
	"fmt"
)

// OrderView is the denormalized read model for orders.
type OrderView struct {
	ID        string
	UserID    string
	UserName  string
	Items     []OrderItem
	Total     float64
	CreatedAt time.Time
}

// OrderProjection handles order projections.
type OrderProjection struct {
	readDB ReadDatabase
}

// NewOrderProjection creates a new order projection.
func NewOrderProjection(readDB ReadDatabase) *OrderProjection {
	return &OrderProjection{readDB: readDB}
}

// OnOrderCreated handles order created events.
func (p *OrderProjection) OnOrderCreated(ctx context.Context, event OrderCreatedEvent) error {
	userName, err := p.getUserName(ctx, event.Order.UserID)
	if err != nil {
		return fmt.Errorf("getting user name: %w", err)
	}

	view := &OrderView{
		ID:        event.Order.ID,
		UserID:    event.Order.UserID,
		UserName:  userName,
		Items:     event.Order.Items,
		Total:     calculateTotal(event.Order.Items),
		CreatedAt: time.Now(),
	}

	if err := p.readDB.Orders.Upsert(ctx, view); err != nil {
		return fmt.Errorf("upserting order view: %w", err)
	}

	return nil
}

func (p *OrderProjection) getUserName(ctx context.Context, userID string) (string, error) {
	user, err := p.readDB.Users.FindByID(ctx, userID)
	if err != nil {
		return "", err
	}
	return user.Name, nil
}

func calculateTotal(items []OrderItem) float64 {
	var total float64
	for _, item := range items {
		total += item.Price * float64(item.Quantity)
	}
	return total
}
```

## Quand utiliser

| ✅ Utiliser | ❌ Éviter |
|-------------|-----------|
| Lecture >> Écriture | CRUD simple |
| Vues complexes | Données temps réel strict |
| Scalabilité lecture | Équipe petite |
| Domaine complexe | Prototype/MVP |

## Avantages

- **Performance** : Read model optimisé
- **Scalabilité** : Scale lecture indépendamment
- **Simplicité** : Modèles spécialisés
- **Flexibilité** : Vues multiples

## Inconvénients

- **Complexité** : Plus de code
- **Eventual Consistency** : Sync asynchrone
- **Debugging** : Plus difficile à suivre

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Event Sourcing | Souvent utilisé ensemble |
| Saga | Transactions distribuées |
| Mediator | Pour router commands/queries |

## Sources

- [Martin Fowler - CQRS](https://martinfowler.com/bliki/CQRS.html)
- [Microsoft - CQRS Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)
