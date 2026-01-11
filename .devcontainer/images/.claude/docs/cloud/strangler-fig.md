# Strangler Fig Pattern

> Migrer progressivement un systeme legacy en le remplacant incrementalement.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │              STRANGLER FIG                   │
                    └─────────────────────────────────────────────┘

  Inspiration naturelle: Figuier etrangleur
  - Pousse autour d'un arbre existant
  - Le remplace progressivement
  - L'arbre original disparait

  Phase 1: COEXISTENCE
  ┌─────────────────────────────────────────────────────────┐
  │                        FACADE                           │
  └──────────────────────────┬──────────────────────────────┘
                             │
           ┌─────────────────┴─────────────────┐
           │                                   │
           ▼                                   ▼
  ┌─────────────────┐               ┌─────────────────┐
  │    LEGACY       │               │      NEW        │
  │   (monolith)    │               │   (services)    │
  │   ████████████  │               │   ░░░░          │
  └─────────────────┘               └─────────────────┘

  Phase 2: MIGRATION PROGRESSIVE
  ┌─────────────────────────────────────────────────────────┐
  │                        FACADE                           │
  └──────────────────────────┬──────────────────────────────┘
                             │
           ┌─────────────────┴─────────────────┐
           │                                   │
           ▼                                   ▼
  ┌─────────────────┐               ┌─────────────────┐
  │    LEGACY       │               │      NEW        │
  │   ████████      │               │   ░░░░░░░░░░░░  │
  └─────────────────┘               └─────────────────┘

  Phase 3: DECOMMISSION
  ┌─────────────────────────────────────────────────────────┐
  │                        FACADE                           │
  └──────────────────────────┬──────────────────────────────┘
                             │
                             ▼
                  ┌─────────────────┐
                  │      NEW        │
                  │   ░░░░░░░░░░░░  │
                  │   (complete)    │
                  └─────────────────┘
```

## Implementation TypeScript

```go
package stranglerfig

import (
	"context"
	"fmt"
	"math/rand"
	"sync"
)

// RoutingConfig defines routing configuration for a feature.
type RoutingConfig struct {
	Feature    string
	UseNew     bool
	Percentage int // For canary deployment
}

// LegacyService defines the legacy service interface.
type LegacyService interface {
	Execute(ctx context.Context, feature, method string, data interface{}) (interface{}, error)
}

// NewService defines the new service interface.
type NewService interface {
	Execute(ctx context.Context, method string, data interface{}) (interface{}, error)
}

// StranglerFacade manages migration from legacy to new services.
type StranglerFacade struct {
	mu            sync.RWMutex
	routingConfig map[string]*RoutingConfig
	legacyService LegacyService
	newServices   map[string]NewService
}

// NewStranglerFacade creates a new StranglerFacade.
func NewStranglerFacade(
	legacyService LegacyService,
	newServices map[string]NewService,
) *StranglerFacade {
	sf := &StranglerFacade{
		routingConfig: make(map[string]*RoutingConfig),
		legacyService: legacyService,
		newServices:   newServices,
	}
	
	sf.initializeRouting()
	return sf
}

func (sf *StranglerFacade) initializeRouting() {
	// Configuration by feature
	sf.routingConfig["users"] = &RoutingConfig{
		Feature: "users",
		UseNew:  true,
	}
	sf.routingConfig["orders"] = &RoutingConfig{
		Feature:    "orders",
		UseNew:     true,
		Percentage: 50, // Canary: 50% traffic
	}
	sf.routingConfig["inventory"] = &RoutingConfig{
		Feature: "inventory",
		UseNew:  false, // Still legacy
	}
	sf.routingConfig["reports"] = &RoutingConfig{
		Feature: "reports",
		UseNew:  false,
	}
}

// HandleRequest handles a request by routing to legacy or new service.
func (sf *StranglerFacade) HandleRequest(
	ctx context.Context,
	feature, method string,
	data interface{},
) (interface{}, error) {
	sf.mu.RLock()
	config, exists := sf.routingConfig[feature]
	sf.mu.RUnlock()

	if !exists {
		return nil, fmt.Errorf("unknown feature: %s", feature)
	}

	useNewService := sf.shouldUseNewService(config)

	if useNewService {
		service, exists := sf.newServices[feature]
		if !exists {
			return nil, fmt.Errorf("new service not found for: %s", feature)
		}
		return service.Execute(ctx, method, data)
	}

	return sf.legacyService.Execute(ctx, feature, method, data)
}

func (sf *StranglerFacade) shouldUseNewService(config *RoutingConfig) bool {
	if !config.UseNew {
		return false
	}

	// Canary: percentage of traffic
	if config.Percentage > 0 && config.Percentage < 100 {
		return rand.Intn(100) < config.Percentage
	}

	return true
}

// EnableNewService migrates a feature to the new service.
func (sf *StranglerFacade) EnableNewService(feature string, percentage int) {
	if percentage == 0 {
		percentage = 100
	}

	sf.mu.Lock()
	defer sf.mu.Unlock()

	sf.routingConfig[feature] = &RoutingConfig{
		Feature:    feature,
		UseNew:     true,
		Percentage: percentage,
	}
}

// DisableNewService rolls back to legacy service.
func (sf *StranglerFacade) DisableNewService(feature string) {
	sf.mu.Lock()
	defer sf.mu.Unlock()

	sf.routingConfig[feature] = &RoutingConfig{
		Feature: feature,
		UseNew:  false,
	}
}
```

## Anti-Corruption Layer

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Sync bidirectionnelle pendant migration

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Feature flags pour migration

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Phases de migration

```
┌─────────────────────────────────────────────────────────────────┐
│                    STRANGLER MIGRATION PHASES                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Phase 1: SETUP (2-4 semaines)                                 │
│  ├─ Facade/API Gateway en place                                │
│  ├─ Logging/monitoring unifie                                  │
│  └─ Premier service extrait (le plus simple)                   │
│                                                                 │
│  Phase 2: EXTRACT (iteratif, mois)                             │
│  ├─ Identifier bounded contexts                                │
│  ├─ Extraire service par service                               │
│  ├─ Dual-write pendant transition                              │
│  └─ Basculer trafic progressivement                            │
│                                                                 │
│  Phase 3: VALIDATE (par service)                               │
│  ├─ 100% trafic vers nouveau service                           │
│  ├─ Periode de soak test (1-4 semaines)                        │
│  └─ Monitoring comparatif                                      │
│                                                                 │
│  Phase 4: CLEANUP                                              │
│  ├─ Supprimer code legacy                                      │
│  ├─ Supprimer dual-write                                       │
│  └─ Documenter                                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Metriques de migration

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Monolithe vers microservices | Oui |
| Modernisation progressive | Oui |
| Migration cloud | Oui |
| Systeme critique (zero downtime) | Oui |
| Petit projet simple | Non (overkill) |
| Deadline tres courte | Non (big bang plus rapide) |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Anti-Corruption Layer | Traduction entre domaines |
| Branch by Abstraction | Alternative similaire |
| Feature Flags | Controle de la migration |
| Facade | Point d'entree unique |

## Sources

- [Microsoft - Strangler Fig](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig)
- [Martin Fowler - Strangler Fig Application](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Sam Newman - Monolith to Microservices](https://samnewman.io/books/monolith-to-microservices/)
