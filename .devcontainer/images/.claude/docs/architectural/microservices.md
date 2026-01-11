# Microservices Architecture

> Décomposer une application en services indépendants, déployables séparément.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                          API Gateway                             │
└─────────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
    ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
    │  User   │   │  Order  │   │ Product │   │ Payment │
    │ Service │   │ Service │   │ Service │   │ Service │
    └─────────┘   └─────────┘   └─────────┘   └─────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
    ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
    │ User DB │   │Order DB │   │Product  │   │Payment  │
    │(Postgres)│  │(MongoDB)│   │DB(Redis)│   │DB (SQL) │
    └─────────┘   └─────────┘   └─────────┘   └─────────┘
```

## Caractéristiques

| Aspect | Microservices |
|--------|---------------|
| Déploiement | Indépendant par service |
| Données | Base de données par service |
| Communication | API (REST, gRPC, Events) |
| Équipes | Autonomes par service |
| Scalabilité | Horizontale par service |
| Technologie | Polyglot possible |

## Quand utiliser

| ✅ Utiliser | ❌ Éviter |
|-------------|-----------|
| Grande équipe (>20 devs) | Petite équipe (<5) |
| Domaines bien définis | Domaine flou |
| Besoin de scale différent | Charge uniforme |
| Équipes autonomes | Équipe centralisée |
| Maturité DevOps | Pas de CI/CD |

## Patterns associés

### Communication

```
┌──────────────────────────────────────────────────────────┐
│                    Synchrone                              │
│  ┌─────────┐        REST/gRPC         ┌─────────┐        │
│  │Service A│ ─────────────────────►  │Service B│        │
│  └─────────┘                          └─────────┘        │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                    Asynchrone                             │
│  ┌─────────┐     ┌─────────┐          ┌─────────┐        │
│  │Service A│ ──► │  Queue  │ ──►     │Service B│        │
│  └─────────┘     └─────────┘          └─────────┘        │
└──────────────────────────────────────────────────────────┘
```

### Service Discovery

```go
package discovery

import (
	"context"
	"fmt"
	"net/http"
)

// ServiceDiscovery discovers services (Consul, Kubernetes DNS, etc.).
type ServiceDiscovery interface {
	GetService(ctx context.Context, name string) (*ServiceInfo, error)
}

// ServiceInfo contains service location information.
type ServiceInfo struct {
	Name string
	URL  string
	Port int
}

// Example usage
func CallUserService(ctx context.Context, discovery ServiceDiscovery, userID string) error {
	userService, err := discovery.GetService(ctx, "user-service")
	if err != nil {
		return fmt.Errorf("discovering user-service: %w", err)
	}

	url := fmt.Sprintf("%s/users/%s", userService.URL, userID)
	resp, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("calling user service: %w", err)
	}
	defer resp.Body.Close()

	return nil
}
```

### Circuit Breaker

```go
package resilience

// Voir cloud/circuit-breaker.md pour l'implémentation complète

// CircuitBreaker prevents cascading failures.
type CircuitBreaker struct {
	// Implementation details
}

// Example usage
func UseCircuitBreaker() error {
	breaker := NewCircuitBreaker(/* config */)
	
	result, err := breaker.Execute(func() (interface{}, error) {
		return callUserService()
	})
	
	if err != nil {
		return err
	}
	
	// Use result
	return nil
}
```

### Saga Pattern

```go
// Voir cloud/saga.md pour l'implémentation complète
```

## Structure d'un microservice

```
user-service/
├── src/
│   ├── domain/           # Logique métier
│   ├── application/      # Use cases
│   ├── infrastructure/   # DB, HTTP, Messaging
│   └── main.go
├── Dockerfile
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── tests/
└── go.mod
```

## Anti-patterns

### Distributed Monolith

```
❌ Services trop couplés = pire que monolith

┌─────────┐   sync   ┌─────────┐   sync   ┌─────────┐
│Service A│ ◄──────► │Service B│ ◄──────► │Service C│
└─────────┘          └─────────┘          └─────────┘
     │                    │                    │
     └────────────────────┴────────────────────┘
              Tous dépendent les uns des autres
```

### Shared Database

```
❌ Base partagée = couplage caché

┌─────────┐   ┌─────────┐   ┌─────────┐
│Service A│   │Service B│   │Service C│
└────┬────┘   └────┬────┘   └────┬────┘
     │             │             │
     └─────────────┼─────────────┘
                   ▼
              ┌─────────┐
              │Shared DB│
              └─────────┘
```

## Migration depuis Monolith

```
Phase 1: Identifier les bounded contexts
Phase 2: Strangler Fig pattern
Phase 3: Extraire service par service
Phase 4: Découpler les données

┌─────────────────────────────────────────────┐
│               MONOLITH                       │
│  ┌───────┐  ┌───────┐  ┌───────┐           │
│  │ User  │  │ Order │  │Product│           │
│  │Module │  │Module │  │Module │           │
│  └───────┘  └───────┘  └───────┘           │
│                │                            │
│                ▼                            │
│           ┌─────────┐                       │
│           │   DB    │                       │
│           └─────────┘                       │
└─────────────────────────────────────────────┘
                    │
                    │ Strangler Fig
                    ▼
┌──────────┐  ┌──────────┐  ┌─────────────────┐
│  User    │  │  Order   │  │   MONOLITH      │
│ Service  │  │ Service  │  │  (shrinking)    │
└──────────┘  └──────────┘  └─────────────────┘
```

## Checklist avant adoption

- [ ] Équipe > 10 personnes ?
- [ ] Domaines clairement délimités ?
- [ ] Infrastructure Kubernetes/Docker ?
- [ ] CI/CD mature ?
- [ ] Monitoring/Observability en place ?
- [ ] Expérience systèmes distribués ?

## Sources

- [microservices.io](https://microservices.io/)
- [Martin Fowler - Microservices](https://martinfowler.com/articles/microservices.html)
- [Sam Newman - Building Microservices](https://samnewman.io/books/building_microservices/)
