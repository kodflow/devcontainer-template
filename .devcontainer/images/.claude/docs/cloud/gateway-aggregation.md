# Gateway Aggregation Pattern

> Agreger plusieurs requetes backend en une seule requete client.

## Principe

```
                                    ┌─────────────────────────┐
                                    │    API GATEWAY          │
                                    │    (Aggregation)        │
┌─────────┐    1 requete            │                         │
│  Client │ ───────────────────────▶│  ┌───────────────────┐  │
└─────────┘                         │  │   Orchestrator    │  │
     ▲                              │  └─────────┬─────────┘  │
     │                              │            │            │
     │    1 reponse agregee         │    ┌───────┼───────┐    │
     └──────────────────────────────│    │       │       │    │
                                    │    ▼       ▼       ▼    │
                                    │  ┌───┐   ┌───┐   ┌───┐  │
                                    │  │ A │   │ B │   │ C │  │
                                    │  └───┘   └───┘   └───┘  │
                                    └─────────────────────────┘
                                           │       │       │
                                           ▼       ▼       ▼
                                    ┌─────────────────────────┐
                                    │      Backend Services    │
                                    └─────────────────────────┘
```

## Probleme resolu

```
AVANT (N requetes client):
┌────────┐                 ┌─────────┐
│ Client │ ──────────────▶ │ User    │
│        │ ──────────────▶ │ Orders  │
│        │ ──────────────▶ │ Payment │
│        │ ──────────────▶ │ Reviews │
└────────┘                 └─────────┘

APRES (1 requete agregee):
┌────────┐        ┌─────────┐        ┌─────────┐
│ Client │ ──────▶│ Gateway │ ──────▶│ Backend │
└────────┘        └─────────┘        └─────────┘
```

## Exemple Go

```go
package gateway

import (
	"context"
	"fmt"
	"net/http"
	"time"
)

// EndpointConfig defines an endpoint to aggregate.
type EndpointConfig struct {
	Name     string
	URL      string
	Timeout  time.Duration
	Required bool
}

// AggregationConfig configures the aggregation behavior.
type AggregationConfig struct {
	Endpoints         []EndpointConfig
	ParallelExecution bool
}

// RequestContext provides context for the aggregation request.
type RequestContext struct {
	AuthToken string
	Params    map[string]string
}

// GatewayAggregator aggregates multiple backend requests.
type GatewayAggregator struct {
	config AggregationConfig
	client *http.Client
}

// NewGatewayAggregator creates a new GatewayAggregator.
func NewGatewayAggregator(config AggregationConfig) *GatewayAggregator {
	return &GatewayAggregator{
		config: config,
		client: &http.Client{},
	}
}

// Aggregate aggregates responses from multiple endpoints.
func (ga *GatewayAggregator) Aggregate(ctx context.Context, reqCtx RequestContext) (map[string]interface{}, error) {
	if ga.config.ParallelExecution {
		return ga.aggregateParallel(ctx, reqCtx)
	}
	return ga.aggregateSequential(ctx, reqCtx)
}

type endpointResult struct {
	Name  string
	Data  interface{}
	Error error
}

func (ga *GatewayAggregator) aggregateParallel(ctx context.Context, reqCtx RequestContext) (map[string]interface{}, error) {
	results := make(chan endpointResult, len(ga.config.Endpoints))
	
	for _, endpoint := range ga.config.Endpoints {
		go func(ep EndpointConfig) {
			data, err := ga.fetchWithTimeout(ctx, ep.URL, ep.Timeout, reqCtx)
			results <- endpointResult{
				Name:  ep.Name,
				Data:  data,
				Error: err,
			}
		}(endpoint)
	}
	
	// Collect results
	aggregated := make(map[string]interface{})
	for i := 0; i < len(ga.config.Endpoints); i++ {
		result := <-results
		
		if result.Error != nil {
			// Check if endpoint is required
			for _, ep := range ga.config.Endpoints {
				if ep.Name == result.Name && ep.Required {
					return nil, fmt.Errorf("required endpoint %s failed: %w", result.Name, result.Error)
				}
			}
			aggregated[result.Name] = nil
		} else {
			aggregated[result.Name] = result.Data
		}
	}
	
	return aggregated, nil
}

func (ga *GatewayAggregator) aggregateSequential(ctx context.Context, reqCtx RequestContext) (map[string]interface{}, error) {
	result := make(map[string]interface{})
	
	for _, endpoint := range ga.config.Endpoints {
		data, err := ga.fetchWithTimeout(ctx, endpoint.URL, endpoint.Timeout, reqCtx)
		if err != nil {
			if endpoint.Required {
				return nil, fmt.Errorf("required endpoint %s failed: %w", endpoint.Name, err)
			}
			result[endpoint.Name] = nil
		} else {
			result[endpoint.Name] = data
		}
	}
	
	return result, nil
}

func (ga *GatewayAggregator) fetchWithTimeout(ctx context.Context, url string, timeout time.Duration, reqCtx RequestContext) (interface{}, error) {
	if timeout == 0 {
		timeout = 5 * time.Second
	}
	
	timeoutCtx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()
	
	req, err := http.NewRequestWithContext(timeoutCtx, "GET", url, nil)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}
	
	req.Header.Set("Authorization", reqCtx.AuthToken)
	
	resp, err := ga.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("executing request: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status: %d", resp.StatusCode)
	}
	
	// Parse response (simplified - should decode JSON)
	return resp.Body, nil
}
```

## Usage

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Strategies de gestion d'erreur

| Strategie | Description | Cas d'usage |
|-----------|-------------|-------------|
| **Fail Fast** | Echouer si un service requis echoue | Donnees critiques |
| **Partial Response** | Retourner les donnees disponibles | Dashboard |
| **Fallback** | Utiliser cache/defaut si echec | UX optimale |
| **Timeout Racing** | Retourner ce qui arrive avant timeout | Performance |

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Aggregation synchrone | Latence = sum(latences) | Execution parallele |
| Sans timeout | Requete bloquee indefiniment | Timeout par endpoint |
| Trop de services | Fragilite, lenteur | Limiter a 5-7 max |
| Couplage fort | Gateway dependant du format | Transformation flexible |

## Quand utiliser

- Clients mobiles necessitant une reduction du nombre de requetes reseau
- Pages ou ecrans aggregeant des donnees de plusieurs microservices
- APIs publiques necessitant une facade simplifiee
- Reduction de la latence perçue par aggregation parallele
- Backend for Frontend (BFF) patterns

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Gateway Routing | Complementaire |
| Backend for Frontend (BFF) | Specialisation |
| Facade | Pattern GoF similaire |
| Circuit Breaker | Protection des appels |

## Sources

- [Microsoft - Gateway Aggregation](https://learn.microsoft.com/en-us/azure/architecture/patterns/gateway-aggregation)
- [Netflix Zuul](https://github.com/Netflix/zuul)
