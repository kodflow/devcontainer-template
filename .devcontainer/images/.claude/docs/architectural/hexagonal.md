# Hexagonal Architecture (Ports & Adapters)

> Isoler le cœur métier des détails techniques.

**Auteur :** Alistair Cockburn (2005)

## Principe

```
                    ┌─────────────────────────────────────┐
                    │           ADAPTERS (Driving)         │
                    │  REST API │ CLI │ gRPC │ GraphQL    │
                    └─────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │             PORTS (In)               │
                    │      Interfaces d'entrée             │
                    └─────────────────────────────────────┘
                                      │
                                      ▼
          ┌───────────────────────────────────────────────────────┐
          │                                                       │
          │                    DOMAIN CORE                        │
          │                                                       │
          │   ┌─────────────┐   ┌─────────────┐   ┌───────────┐  │
          │   │   Entities  │   │   Services  │   │   Rules   │  │
          │   └─────────────┘   └─────────────┘   └───────────┘  │
          │                                                       │
          └───────────────────────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │             PORTS (Out)              │
                    │      Interfaces de sortie            │
                    └─────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │          ADAPTERS (Driven)           │
                    │  PostgreSQL │ Redis │ S3 │ Email    │
                    └─────────────────────────────────────┘
```

## Structure de fichiers

```
src/
├── domain/                    # Cœur métier (AUCUNE dépendance externe)
│   ├── entities/
│   │   └── User.go
│   ├── services/
│   │   └── UserService.go
│   ├── repositories/          # Interfaces (Ports Out)
│   │   └── UserRepository.go
│   └── errors/
│       └── UserNotFoundError.go
│
├── application/               # Use Cases / Ports In
│   ├── commands/
│   │   └── CreateUserCommand.go
│   ├── queries/
│   │   └── GetUserQuery.go
│   └── handlers/
│       └── CreateUserHandler.go
│
├── infrastructure/            # Adapters (implémentations)
│   ├── persistence/
│   │   ├── PostgresUserRepository.go
│   │   └── InMemoryUserRepository.go
│   ├── http/
│   │   └── UserController.go
│   └── messaging/
│       └── RabbitMQPublisher.go
│
└── main.go                    # Composition root (DI)
```

## Exemple

### Port (Interface)

```go
package repositories

import "context"

// UserRepository is the port for user persistence.
type UserRepository interface {
	FindByID(ctx context.Context, id string) (*User, error)
	Save(ctx context.Context, user *User) error
	Delete(ctx context.Context, id string) error
}
```

### Domain Service

```go
package services

import (
	"context"
	"fmt"
)

// UserService handles user business logic.
type UserService struct {
	userRepo UserRepository
}

// NewUserService creates a new user service.
func NewUserService(userRepo UserRepository) *UserService {
	return &UserService{userRepo: userRepo}
}

// CreateUser creates a new user.
func (s *UserService) CreateUser(ctx context.Context, email, name string) (*User, error) {
	existing, err := s.userRepo.FindByEmail(ctx, email)
	if err != nil && !errors.Is(err, ErrNotFound) {
		return nil, fmt.Errorf("finding user by email: %w", err)
	}
	if existing != nil {
		return nil, &UserAlreadyExistsError{Email: email}
	}

	user := &User{
		ID:    GenerateID(),
		Email: email,
		Name:  name,
	}

	if err := s.userRepo.Save(ctx, user); err != nil {
		return nil, fmt.Errorf("saving user: %w", err)
	}

	return user, nil
}
```

### Adapter (Implémentation)

```go
package persistence

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/lib/pq"
)

// PostgresUserRepository is the PostgreSQL adapter for UserRepository.
type PostgresUserRepository struct {
	db *sql.DB
}

// NewPostgresUserRepository creates a new PostgreSQL user repository.
func NewPostgresUserRepository(db *sql.DB) *PostgresUserRepository {
	return &PostgresUserRepository{db: db}
}

// FindByID finds a user by ID.
func (r *PostgresUserRepository) FindByID(ctx context.Context, id string) (*User, error) {
	query := "SELECT id, email, name FROM users WHERE id = $1"
	
	var user User
	err := r.db.QueryRowContext(ctx, query, id).Scan(&user.ID, &user.Email, &user.Name)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("querying user: %w", err)
	}

	return &user, nil
}

// Save saves a user.
func (r *PostgresUserRepository) Save(ctx context.Context, user *User) error {
	query := "INSERT INTO users (id, email, name) VALUES ($1, $2, $3)"
	
	_, err := r.db.ExecContext(ctx, query, user.ID, user.Email, user.Name)
	if err != nil {
		return fmt.Errorf("inserting user: %w", err)
	}

	return nil
}
```

### Test (avec Mock Adapter)

```go
package services_test

import (
	"context"
	"testing"
)

// InMemoryUserRepository is a mock repository for testing.
type InMemoryUserRepository struct {
	users map[string]*User
}

// NewInMemoryUserRepository creates a new in-memory user repository.
func NewInMemoryUserRepository() *InMemoryUserRepository {
	return &InMemoryUserRepository{
		users: make(map[string]*User),
	}
}

// FindByID finds a user by ID.
func (r *InMemoryUserRepository) FindByID(ctx context.Context, id string) (*User, error) {
	user, ok := r.users[id]
	if !ok {
		return nil, nil
	}
	return user, nil
}

// Save saves a user.
func (r *InMemoryUserRepository) Save(ctx context.Context, user *User) error {
	r.users[user.ID] = user
	return nil
}

func TestUserService_CreateUser(t *testing.T) {
	mockRepo := NewInMemoryUserRepository()
	service := NewUserService(mockRepo)

	user, err := service.CreateUser(context.Background(), "test@example.com", "Test")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if user.Email != "test@example.com" {
		t.Errorf("expected email test@example.com, got %s", user.Email)
	}

	found, err := mockRepo.FindByID(context.Background(), user.ID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if found == nil {
		t.Error("user not found in repository")
	}
}
```

## Quand utiliser

| ✅ Utiliser | ❌ Éviter |
|-------------|-----------|
| Applications métier complexes | CRUD simple |
| Longue durée de vie | Prototypes/MVPs |
| Tests importants | Scripts one-shot |
| Équipes multiples | Projets solo courts |
| Changements d'infra prévisibles | Stack figé |

## Avantages

- **Testabilité** : Domain testable sans DB/HTTP
- **Flexibilité** : Changer de DB = un adapter
- **Clarté** : Séparation claire des responsabilités
- **Indépendance** : Le métier ne dépend de rien

## Inconvénients

- **Verbosité** : Plus de fichiers/interfaces
- **Overhead** : Mapping entre couches
- **Courbe d'apprentissage** : Concepts à maîtriser

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Clean Architecture | Évolution avec plus de couches |
| DIP (SOLID) | Fondement du pattern |
| Adapter (GoF) | Implémentation des ports |
| Repository | Port typique pour la persistance |

## Frameworks qui supportent Hexagonal

| Langage | Framework |
|---------|-----------|
| TypeScript | NestJS, ts-arch |
| Java | Spring (modules) |
| Go | go-kit, structure manuelle |
| Python | FastAPI + structure manuelle |

## Sources

- [Alistair Cockburn - Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)
- [Netflix Tech Blog](https://netflixtechblog.com/)
- [microservices.io](https://microservices.io/patterns/microservices.html)
