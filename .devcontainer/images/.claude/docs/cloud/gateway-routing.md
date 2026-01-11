# Gateway Routing Pattern

> Router les requetes vers les services backend appropries.

## Principe

```
┌────────────────────────────────────────────────────────────────┐
│                        API GATEWAY                              │
│                                                                 │
│    Routing Rules:                                               │
│    /api/users/*     ──▶  User Service                          │
│    /api/orders/*    ──▶  Order Service                         │
│    /api/products/*  ──▶  Product Service                       │
│    /v2/*            ──▶  New API Version                       │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
         │               │                │               │
         ▼               ▼                ▼               ▼
    ┌─────────┐    ┌─────────┐     ┌─────────┐     ┌─────────┐
    │  User   │    │  Order  │     │ Product │     │  API    │
    │ Service │    │ Service │     │ Service │     │   v2    │
    └─────────┘    └─────────┘     └─────────┘     └─────────┘
```

## Types de routage

| Type | Description | Exemple |
|------|-------------|---------|
| **Path-based** | Route selon le chemin URL | `/api/users/*` → User Service |
| **Header-based** | Route selon headers | `X-Version: 2` → API v2 |
| **Query-based** | Route selon query params | `?region=eu` → EU cluster |
| **Method-based** | Route selon methode HTTP | `POST /orders` → Write Service |
| **Weight-based** | Distribution ponderee | 90% stable, 10% canary |

## Exemple Go

```go
package gateway

import (
	"math/rand"
	"net/http"
	"net/http/httputil"
	"net/url"
)

// RoutingRule defines a routing rule.
type RoutingRule struct {
	Name      string
	Match     func(r *http.Request) bool
	Target    string
	Weight    int
	Transform func(r *http.Request) *http.Request
}

// GatewayRouter routes requests to backend services.
type GatewayRouter struct {
	rules []*RoutingRule
}

// NewGatewayRouter creates a new GatewayRouter.
func NewGatewayRouter() *GatewayRouter {
	return &GatewayRouter{
		rules: make([]*RoutingRule, 0),
	}
}

// AddRule adds a routing rule.
func (gr *GatewayRouter) AddRule(rule *RoutingRule) *GatewayRouter {
	if rule.Weight == 0 {
		rule.Weight = 100
	}
	gr.rules = append(gr.rules, rule)
	return gr
}

// Route routes a request to the appropriate backend.
func (gr *GatewayRouter) Route(w http.ResponseWriter, r *http.Request) {
	matchedRules := make([]*RoutingRule, 0)
	
	for _, rule := range gr.rules {
		if rule.Match(r) {
			matchedRules = append(matchedRules, rule)
		}
	}
	
	if len(matchedRules) == 0 {
		http.Error(w, "Not Found", http.StatusNotFound)
		return
	}
	
	// Select rule by weight
	selectedRule := gr.selectByWeight(matchedRules)
	
	// Transform request if needed
	targetReq := r
	if selectedRule.Transform != nil {
		targetReq = selectedRule.Transform(r)
	}
	
	// Forward to target
	gr.forward(w, targetReq, selectedRule.Target)
}

func (gr *GatewayRouter) selectByWeight(rules []*RoutingRule) *RoutingRule {
	totalWeight := 0
	for _, r := range rules {
		totalWeight += r.Weight
	}
	
	random := rand.Intn(totalWeight)
	
	for _, rule := range rules {
		random -= rule.Weight
		if random < 0 {
			return rule
		}
	}
	
	return rules[0]
}

func (gr *GatewayRouter) forward(w http.ResponseWriter, r *http.Request, target string) {
	targetURL, err := url.Parse(target)
	if err != nil {
		http.Error(w, "Invalid target URL", http.StatusInternalServerError)
		return
	}
	
	proxy := httputil.NewSingleHostReverseProxy(targetURL)
	proxy.ServeHTTP(w, r)
}
```

## Configuration des routes

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Strategies avancees

### A/B Testing

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

### Blue-Green Deployment

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

### Circuit Breaker Integration

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Regles trop specifiques | Maintenance difficile | Grouper par service |
| Logique metier | Couplage gateway/domaine | Routage technique seulement |
| Sans fallback | Echec silencieux | Route par defaut + monitoring |
| Ordre non deterministe | Comportement imprevisible | Priorite explicite |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Gateway Aggregation | Complementaire |
| Gateway Offloading | Complementaire |
| Service Discovery | Resolution dynamique |
| Load Balancer | Distribution intra-service |

## Sources

- [Microsoft - Gateway Routing](https://learn.microsoft.com/en-us/azure/architecture/patterns/gateway-routing)
- [Traefik](https://traefik.io/traefik/)
- [Kong Routing](https://docs.konghq.com/gateway/latest/get-started/configure-routes/)
