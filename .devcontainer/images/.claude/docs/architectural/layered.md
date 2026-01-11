# Layered Architecture (N-Tier)

> Organiser le code en couches horizontales avec des responsabilités distinctes.

**Aussi appelé :** N-Tier, Multi-tier, Onion (variante)

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                    LAYERED ARCHITECTURE                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  PRESENTATION LAYER                      │    │
│  │              (Controllers, Views, APIs)                  │    │
│  │                                                          │    │
│  │  • Gère les requêtes HTTP                               │    │
│  │  • Valide les entrées                                   │    │
│  │  • Formate les réponses                                 │    │
│  └──────────────────────────┬──────────────────────────────┘    │
│                             │ Dépend de                          │
│                             ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   BUSINESS LAYER                         │    │
│  │              (Services, Use Cases, Logic)                │    │
│  │                                                          │    │
│  │  • Logique métier                                       │    │
│  │  • Règles de validation                                 │    │
│  │  • Orchestration                                        │    │
│  └──────────────────────────┬──────────────────────────────┘    │
│                             │ Dépend de                          │
│                             ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                 PERSISTENCE LAYER                        │    │
│  │              (Repositories, DAOs, ORM)                   │    │
│  │                                                          │    │
│  │  • Accès aux données                                    │    │
│  │  • Mapping objet-relationnel                            │    │
│  │  • Queries                                              │    │
│  └──────────────────────────┬──────────────────────────────┘    │
│                             │ Dépend de                          │
│                             ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   DATABASE LAYER                         │    │
│  │              (PostgreSQL, MongoDB, Redis)                │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘

Règle: Une couche ne peut appeler que la couche immédiatement en dessous
```

## Structure de fichiers

```
src/
├── presentation/                # Couche présentation
│   ├── controllers/
│   │   ├── UserController.go
│   │   └── OrderController.go
│   ├── middleware/
│   │   ├── AuthMiddleware.go
│   │   └── ValidationMiddleware.go
│   ├── dto/                     # Data Transfer Objects
│   │   ├── CreateUserDTO.go
│   │   └── OrderResponseDTO.go
│   └── routes/
│       └── routes.go
│
├── business/                    # Couche métier
│   ├── services/
│   │   ├── UserService.go
│   │   └── OrderService.go
│   ├── validators/
│   │   └── OrderValidator.go
│   └── rules/
│       └── PricingRules.go
│
├── persistence/                 # Couche persistance
│   ├── repositories/
│   │   ├── UserRepository.go
│   │   └── OrderRepository.go
│   ├── entities/
│   │   ├── UserEntity.go
│   │   └── OrderEntity.go
│   └── migrations/
│       └── ...
│
└── shared/                      # Cross-cutting concerns
    ├── config/
    ├── utils/
    └── types/
```

## Implémentation

### Presentation Layer

```go
package controllers

import (
	"encoding/json"
	"net/http"
)

// CreateUserDTO is the data transfer object for creating a user.
type CreateUserDTO struct {
	Email string `json:"email"`
	Name  string `json:"name"`
}

// UserResponseDTO is the data transfer object for user responses.
type UserResponseDTO struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name"`
}

// UserController handles user HTTP requests.
type UserController struct {
	userService UserService
}

// NewUserController creates a new user controller.
func NewUserController(userService UserService) *UserController {
	return &UserController{userService: userService}
}

// Create handles user creation requests.
func (c *UserController) Create(w http.ResponseWriter, r *http.Request) {
	var dto CreateUserDTO
	if err := json.NewDecoder(r.Body).Decode(&dto); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	user, err := c.userService.CreateUser(r.Context(), dto)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	response := UserResponseDTO{
		ID:    user.ID,
		Email: user.Email,
		Name:  user.Name,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteStatus(http.StatusCreated)
	json.NewEncoder(w).Encode(response)
}

// GetByID handles get user by ID requests.
func (c *UserController) GetByID(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")

	user, err := c.userService.GetUserByID(r.Context(), id)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	if user == nil {
		http.Error(w, "User not found", http.StatusNotFound)
		return
	}

	response := UserResponseDTO{
		ID:    user.ID,
		Email: user.Email,
		Name:  user.Name,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}
```

### Business Layer

```go
package services

import (
	"context"
	"fmt"
	"time"
)

// User represents a user entity.
type User struct {
	ID        string
	Email     string
	Name      string
	CreatedAt time.Time
}

// UserService handles user business logic.
type UserService struct {
	userRepository UserRepository
	emailService   EmailService
}

// NewUserService creates a new user service.
func NewUserService(userRepository UserRepository, emailService EmailService) *UserService {
	return &UserService{
		userRepository: userRepository,
		emailService:   emailService,
	}
}

// CreateUser creates a new user.
func (s *UserService) CreateUser(ctx context.Context, dto CreateUserDTO) (*User, error) {
	// Business validation
	if err := s.validateEmail(ctx, dto.Email); err != nil {
		return nil, err
	}

	user := &User{
		ID:        GenerateID(),
		Email:     dto.Email,
		Name:      dto.Name,
		CreatedAt: time.Now(),
	}

	// Persistence
	if err := s.userRepository.Save(ctx, user); err != nil {
		return nil, fmt.Errorf("saving user: %w", err)
	}

	// Side effects
	if err := s.emailService.SendWelcome(ctx, user.Email); err != nil {
		// Log error but don't fail
		fmt.Printf("failed to send welcome email: %v\n", err)
	}

	return user, nil
}

// GetUserByID retrieves a user by ID.
func (s *UserService) GetUserByID(ctx context.Context, id string) (*User, error) {
	return s.userRepository.FindByID(ctx, id)
}

func (s *UserService) validateEmail(ctx context.Context, email string) error {
	existing, err := s.userRepository.FindByEmail(ctx, email)
	if err != nil {
		return fmt.Errorf("finding user by email: %w", err)
	}
	if existing != nil {
		return &DuplicateEmailError{Email: email}
	}
	return nil
}
```

### Persistence Layer

```go
package repositories

import (
	"context"
	"database/sql"
	"fmt"
)

// UserRepository handles user data access.
type UserRepository struct {
	db *sql.DB
}

// NewUserRepository creates a new user repository.
func NewUserRepository(db *sql.DB) *UserRepository {
	return &UserRepository{db: db}
}

// Save saves a user to the database.
func (r *UserRepository) Save(ctx context.Context, user *User) error {
	query := `
		INSERT INTO users (id, email, name, created_at)
		VALUES ($1, $2, $3, $4)
	`

	_, err := r.db.ExecContext(ctx, query, user.ID, user.Email, user.Name, user.CreatedAt)
	if err != nil {
		return fmt.Errorf("executing insert: %w", err)
	}

	return nil
}

// FindByID finds a user by ID.
func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
	query := "SELECT id, email, name, created_at FROM users WHERE id = $1"

	var user User
	err := r.db.QueryRowContext(ctx, query, id).Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("querying user: %w", err)
	}

	return &user, nil
}

// FindByEmail finds a user by email.
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	query := "SELECT id, email, name, created_at FROM users WHERE email = $1"

	var user User
	err := r.db.QueryRowContext(ctx, query, email).Scan(&user.ID, &user.Email, &user.Name, &user.CreatedAt)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, nil
		}
		return nil, fmt.Errorf("querying user: %w", err)
	}

	return &user, nil
}
```

## Variantes

### 3-Tier classique

```
┌───────────────────┐
│   Presentation    │  UI / API
├───────────────────┤
│     Business      │  Logique métier
├───────────────────┤
│       Data        │  Base de données
└───────────────────┘
```

### 4-Tier avec Intégration

```
┌───────────────────┐
│   Presentation    │  UI / API
├───────────────────┤
│     Business      │  Logique métier
├───────────────────┤
│   Integration     │  APIs externes, messaging
├───────────────────┤
│       Data        │  Base de données
└───────────────────┘
```

### Onion / Clean Architecture

```
        ┌───────────────────────────────────┐
        │           Infrastructure          │
        │  ┌───────────────────────────┐   │
        │  │       Application         │   │
        │  │  ┌───────────────────┐   │   │
        │  │  │      Domain       │   │   │
        │  │  │                   │   │   │
        │  │  │   (Entities)      │   │   │
        │  │  │                   │   │   │
        │  │  └───────────────────┘   │   │
        │  │    (Use Cases)           │   │
        │  └───────────────────────────┘   │
        │  (DB, Web, External Services)    │
        └───────────────────────────────────┘

Dépendances: vers le centre (Domain)
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Applications CRUD | Domaine très complexe |
| Équipes traditionnelles | Microservices |
| APIs simples | Haute performance |
| Prototypes évolutifs | Scaling horizontal |
| Applications web classiques | Event-driven |

## Avantages

- **Simplicité** : Facile à comprendre
- **Séparation** : Responsabilités claires
- **Testabilité** : Couches isolables
- **Maintenabilité** : Changements localisés
- **Standard** : Pattern bien connu

## Inconvénients

- **Overhead** : Mapping entre couches
- **Rigidité** : Structure parfois contraignante
- **Performance** : Traversée des couches
- **Couplage** : Dépendances descendantes
- **Monolithe** : Tendance au monolithe

## Exemples réels

| Framework | Architecture |
|-----------|--------------|
| **Spring MVC** | Controller-Service-Repository |
| **ASP.NET MVC** | Controller-Service-Data |
| **Django** | Views-Models-Templates |
| **Rails** | MVC traditionnel |
| **NestJS** | Controller-Service-Repository |

## Migration path

### Vers Hexagonal

```
1. Extraire interfaces des repositories
2. Inverser les dépendances (DIP)
3. Créer un vrai Domain layer
4. Séparer ports (interfaces) et adapters (implem)
```

### Vers Microservices

```
1. Identifier bounded contexts
2. Séparer en modules indépendants
3. Extraire en services
4. Remplacer appels par API/Events
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Hexagonal | Évolution avec inversion dépendances |
| Clean Architecture | Variante avec cercles |
| MVC | Sous-pattern de presentation |
| Repository | Pattern de la couche data |

## Sources

- [Martin Fowler - PresentationDomainDataLayering](https://martinfowler.com/bliki/PresentationDomainDataLayering.html)
- [Microsoft - N-tier Architecture](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/n-tier)
- [Clean Architecture - Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
