# Gateway Offloading Pattern

> Decharger les fonctionnalites partagees des services vers le gateway.

## Principe

```
┌────────────────────────────────────────────────────────────────────┐
│                         API GATEWAY                                 │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │    SSL      │  │    Auth     │  │   Logging   │  │   Rate    │  │
│  │ Termination │  │   (OAuth)   │  │  & Tracing  │  │  Limiting │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘  │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │   Caching   │  │ Compression │  │    CORS     │  │  Metrics  │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘  │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
     ┌────────────────────────┬────────────────────────┐
     │                        │                        │
     ▼                        ▼                        ▼
┌─────────┐             ┌─────────┐             ┌─────────┐
│ Service │             │ Service │             │ Service │
│    A    │             │    B    │             │    C    │
│ (leger) │             │ (leger) │             │ (leger) │
└─────────┘             └─────────┘             └─────────┘
```

## Fonctionnalites dechargeables

| Fonctionnalite | Avantage au Gateway | Complexite |
|----------------|---------------------|------------|
| **SSL Termination** | Certificats centralises | Faible |
| **Authentication** | Politique uniforme | Moyenne |
| **Rate Limiting** | Protection globale | Faible |
| **Caching** | Reduction charge backend | Moyenne |
| **Compression** | Bande passante optimisee | Faible |
| **CORS** | Configuration unique | Faible |
| **Request Validation** | Rejet precoce | Moyenne |
| **Response Transformation** | Format uniforme | Haute |

## Exemple Go

```go
package gateway

import (
	"context"
	"net/http"
)

// GatewayContext provides context for middleware execution.
type GatewayContext struct {
	Request  *http.Request
	Response http.ResponseWriter
	User     *User
}

// User represents an authenticated user.
type User struct {
	ID   string
	Name string
}

// OffloadingMiddleware defines a middleware function.
type OffloadingMiddleware struct {
	Name    string
	Execute func(ctx context.Context, gc *GatewayContext, next func() error) error
}

// GatewayOffloader manages middleware chain.
type GatewayOffloader struct {
	middlewares []OffloadingMiddleware
}

// NewGatewayOffloader creates a new GatewayOffloader.
func NewGatewayOffloader() *GatewayOffloader {
	return &GatewayOffloader{
		middlewares: make([]OffloadingMiddleware, 0),
	}
}

// Use adds a middleware to the chain.
func (gw *GatewayOffloader) Use(middleware OffloadingMiddleware) *GatewayOffloader {
	gw.middlewares = append(gw.middlewares, middleware)
	return gw
}

// Handle executes the middleware chain.
func (gw *GatewayOffloader) Handle(ctx context.Context, r *http.Request, w http.ResponseWriter) error {
	gc := &GatewayContext{
		Request:  r,
		Response: w,
	}

	return gw.executeMiddleware(ctx, gc, 0)
}

func (gw *GatewayOffloader) executeMiddleware(ctx context.Context, gc *GatewayContext, index int) error {
	if index >= len(gw.middlewares) {
		return nil
	}

	middleware := gw.middlewares[index]
	return middleware.Execute(ctx, gc, func() error {
		return gw.executeMiddleware(ctx, gc, index+1)
	})
}

// Example middlewares

// SSLTerminationMiddleware handles SSL termination.
var SSLTerminationMiddleware = OffloadingMiddleware{
	Name: "ssl-termination",
	Execute: func(ctx context.Context, gc *GatewayContext, next func() error) error {
		// SSL handled by load balancer/gateway
		gc.Request.Header.Set("X-Forwarded-Proto", "https")
		return next()
	},
}

// AuthMiddleware handles authentication.
var AuthMiddleware = OffloadingMiddleware{
	Name: "authentication",
	Execute: func(ctx context.Context, gc *GatewayContext, next func() error) error {
		token := gc.Request.Header.Get("Authorization")
		
		if token == "" {
			http.Error(gc.Response, "Unauthorized", http.StatusUnauthorized)
			return nil
		}
		
		// Validate token (simplified)
		user := &User{ID: "user123", Name: "John"}
		gc.User = user
		gc.Request.Header.Set("X-User-Id", user.ID)
		
		return next()
	},
}
```

## Configuration Gateway

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Benefices

| Aspect | Sans Offloading | Avec Offloading |
|--------|-----------------|-----------------|
| **Code service** | Complexe | Simple |
| **Certificats SSL** | N services | 1 gateway |
| **Policies auth** | Dupliquees | Centralisees |
| **Mise a jour** | N deploiements | 1 deploiement |
| **Monitoring** | Fragmente | Unifie |

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Gateway trop charge | SPOF, latence | Distribuer, scaler |
| Logique metier | Couplage | Garder cross-cutting seulement |
| Sans fallback | Gateway down = tout down | Resilience, multi-instance |
| Over-caching | Donnees stales | TTL adapte, invalidation |

## Quand utiliser

- Centralisation de la terminaison SSL pour simplifier la gestion des certificats
- Authentification et autorisation uniformes sur tous les services
- Rate limiting et protection contre les abus a l'echelle de l'API
- Logging et tracing centralises pour l'observabilite
- Services backend devant rester legers et focuses sur la logique metier

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Gateway Routing | Complementaire |
| Gateway Aggregation | Complementaire |
| Ambassador | Alternative distribuee |
| Service Mesh | Evolution a grande echelle |

## Sources

- [Microsoft - Gateway Offloading](https://learn.microsoft.com/en-us/azure/architecture/patterns/gateway-offloading)
- [Kong Gateway](https://konghq.com/)
- [Nginx](https://nginx.org/en/docs/)
