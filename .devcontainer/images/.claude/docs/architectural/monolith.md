# Monolithic Architecture

> Une application unique contenant toute la logique métier.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                        MONOLITH                                  │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │    User     │  │    Order    │  │   Product   │              │
│  │   Module    │  │   Module    │  │   Module    │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│         │               │               │                        │
│         └───────────────┴───────────────┘                        │
│                         │                                        │
│                         ▼                                        │
│                  ┌─────────────┐                                 │
│                  │   Shared    │                                 │
│                  │  Database   │                                 │
│                  └─────────────┘                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Types de Monolith

### 1. Monolith classique (à éviter)

```
❌ Big Ball of Mud
┌─────────────────────────────────────┐
│  Code spaghetti, pas de structure   │
│  Tout dépend de tout               │
└─────────────────────────────────────┘
```

### 2. Monolith modulaire (recommandé)

```
✅ Bien structuré
┌─────────────────────────────────────────────────────────────┐
│                     MONOLITH MODULAIRE                       │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │    Users    │  │   Orders    │  │  Products   │          │
│  │  ┌───────┐  │  │  ┌───────┐  │  │  ┌───────┐  │          │
│  │  │Domain │  │  │  │Domain │  │  │  │Domain │  │          │
│  │  ├───────┤  │  │  ├───────┤  │  │  ├───────┤  │          │
│  │  │  API  │  │  │  │  API  │  │  │  │  API  │  │          │
│  │  ├───────┤  │  │  ├───────┤  │  │  ├───────┤  │          │
│  │  │  DB   │  │  │  │  DB   │  │  │  │  DB   │  │          │
│  │  └───────┘  │  │  └───────┘  │  │  └───────┘  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│        │                │                │                   │
│        └────── API publiques entre modules ──────┘          │
└─────────────────────────────────────────────────────────────┘
```

## Structure recommandée

```
src/
├── modules/
│   ├── users/
│   │   ├── domain/
│   │   │   ├── User.go
│   │   │   └── UserService.go
│   │   ├── api/
│   │   │   └── UserController.go
│   │   ├── infra/
│   │   │   └── UserRepository.go
│   │   └── module.go          # API publique du module
│   │
│   ├── orders/
│   │   ├── domain/
│   │   ├── api/
│   │   ├── infra/
│   │   └── module.go
│   │
│   └── products/
│       └── ...
│
├── shared/                    # Code vraiment partagé
│   ├── database/
│   └── utils/
│
└── main.go
```

## Règles du Monolith Modulaire

### 1. Encapsulation des modules

```go
// ❌ Direct access to internals
// import "app/modules/users/infra"

// ✅ Use public API
import "app/modules/users"

func main() {
	user, err := users.GetUser(ctx, id)
	if err != nil {
		log.Fatal(err)
	}
}
```

### 2. Communication par interfaces

```go
package users

import "context"

// UserModule is the public API for the user module.
type UserModule interface {
	GetUser(ctx context.Context, id string) (*User, error)
	CreateUser(ctx context.Context, data CreateUserDTO) (*User, error)
}

type userModule struct {
	service *UserService
}

// NewUserModule creates a new user module.
func NewUserModule(db *sql.DB) UserModule {
	repo := NewUserRepository(db)
	service := NewUserService(repo)
	return &userModule{service: service}
}

func (m *userModule) GetUser(ctx context.Context, id string) (*User, error) {
	return m.service.FindByID(ctx, id)
}

func (m *userModule) CreateUser(ctx context.Context, data CreateUserDTO) (*User, error) {
	return m.service.Create(ctx, data)
}
```

### 3. Base de données par schéma

```sql
-- Schémas séparés par module
CREATE SCHEMA users;
CREATE SCHEMA orders;
CREATE SCHEMA products;

-- Chaque module accède uniquement à son schéma
```

## Quand utiliser

| ✅ Utiliser | ❌ Éviter |
|-------------|-----------|
| Startup / MVP | Équipe > 20 devs |
| Équipe < 10 personnes | Besoins de scale différents |
| Domaine pas encore clair | Bounded contexts évidents |
| Besoin de vitesse | Équipes autonomes requises |
| Budget infra limité | Haute disponibilité critique |

## Avantages

- **Simplicité** : Un seul déploiement
- **Performance** : Appels in-process
- **Transactions** : ACID native
- **Debugging** : Stack trace complète
- **Coût** : Moins d'infra

## Inconvénients

- **Scalabilité** : Tout scale ensemble
- **Déploiement** : Tout redéployer
- **Technologie** : Stack unique
- **Équipes** : Coordination nécessaire

## Migration vers Microservices

```
Étape 1: Monolith → Monolith Modulaire
Étape 2: Définir les bounded contexts
Étape 3: Strangler Fig (un module à la fois)
Étape 4: Microservices complets
```

## Anti-patterns

### Module Coupling

```go
// ❌ Modules too coupled
type OrderService struct {
	userRepo    *UserRepository    // Direct access
	productRepo *ProductRepository // Direct access
}

// ✅ Communication through events/API
type OrderService struct {
	userModule    users.UserModule
	productModule products.ProductModule
}

func (s *OrderService) CreateOrder(ctx context.Context, userID, productID string) (*Order, error) {
	user, err := s.userModule.GetUser(ctx, userID)
	if err != nil {
		return nil, err
	}

	product, err := s.productModule.GetProduct(ctx, productID)
	if err != nil {
		return nil, err
	}

	// Create order
	return nil, nil
}
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Hexagonal | Structure interne des modules |
| CQRS | Applicable par module |
| Event Sourcing | Pour la communication entre modules |
| Strangler Fig | Migration vers microservices |

## Sources

- [Modular Monolith - Kamil Grzybek](https://www.kamilgrzybek.com/design/modular-monolith-primer/)
- [Martin Fowler - Monolith First](https://martinfowler.com/bliki/MonolithFirst.html)
