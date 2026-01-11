# Ambassador Pattern

> Creer des services proxy pour gerer les communications entre clients et services.

## Principe

```
                          ┌──────────────────────────────┐
                          │         AMBASSADOR           │
                          │                              │
┌─────────┐               │  ┌─────────┐   ┌─────────┐  │   ┌─────────┐
│  Client │ ─────────────▶│  │  Proxy  │───│ Logging │  │──▶│ Service │
└─────────┘               │  └─────────┘   └─────────┘  │   └─────────┘
                          │       │                     │
                          │       ▼                     │
                          │  ┌─────────┐   ┌─────────┐  │
                          │  │ Retry   │   │ Monitor │  │
                          │  └─────────┘   └─────────┘  │
                          └──────────────────────────────┘
```

L'Ambassador agit comme un sidecar qui decharge les fonctionnalites cross-cutting du service principal.

## Responsabilites

| Fonction | Description |
|----------|-------------|
| **Logging** | Journalisation des requetes/reponses |
| **Retry** | Relances automatiques |
| **Circuit Breaking** | Protection pannes cascade |
| **Authentication** | Verification tokens |
| **Rate Limiting** | Controle du debit |
| **Monitoring** | Metriques et traces |

## Exemple Go

```go
package ambassador

import (
	"context"
	"fmt"
	"log"
	"math"
	"net/http"
	"time"
)

// CircuitBreakerConfig configure circuit breaker parameters.
type CircuitBreakerConfig struct {
	FailureThreshold int
	Timeout          time.Duration
}

// AmbassadorConfig defines configuration for the Ambassador.
type AmbassadorConfig struct {
	Retries        int
	Timeout        time.Duration
	Logging        bool
	CircuitBreaker *CircuitBreakerConfig
}

// Ambassador handles cross-cutting concerns like retry, logging, and circuit breaking.
type Ambassador struct {
	targetURL      string
	config         AmbassadorConfig
	circuitBreaker *CircuitBreaker
	client         *http.Client
}

// NewAmbassador creates a new Ambassador instance.
func NewAmbassador(targetURL string, config AmbassadorConfig) *Ambassador {
	a := &Ambassador{
		targetURL: targetURL,
		config:    config,
		client: &http.Client{
			Timeout: config.Timeout,
		},
	}

	if config.CircuitBreaker != nil {
		a.circuitBreaker = NewCircuitBreaker(*config.CircuitBreaker)
	}

	return a
}

// Forward forwards a request with retry logic and logging.
func (a *Ambassador) Forward(ctx context.Context, req *http.Request) (*http.Response, error) {
	startTime := time.Now()

	// Logging entry
	if a.config.Logging {
		log.Printf("[Ambassador] %s %s", req.Method, req.URL.Path)
	}

	// Retry wrapper
	var lastErr error
	for attempt := 0; attempt <= a.config.Retries; attempt++ {
		resp, err := a.executeWithTimeout(ctx, req)
		if err == nil {
			// Logging output
			if a.config.Logging {
				log.Printf("[Ambassador] Response in %v", time.Since(startTime))
			}
			return resp, nil
		}

		lastErr = err
		if attempt < a.config.Retries {
			// Exponential backoff
			backoff := time.Duration(math.Pow(2, float64(attempt))) * 100 * time.Millisecond
			time.Sleep(backoff)
		}
	}

	return nil, fmt.Errorf("all retries failed: %w", lastErr)
}

func (a *Ambassador) executeWithTimeout(ctx context.Context, req *http.Request) (*http.Response, error) {
	timeoutCtx, cancel := context.WithTimeout(ctx, a.config.Timeout)
	defer cancel()

	req = req.WithContext(timeoutCtx)

	if a.circuitBreaker != nil {
		return a.circuitBreaker.Call(func() (*http.Response, error) {
			return a.client.Do(req)
		})
	}

	return a.client.Do(req)
}
```

## Usage avec Kubernetes Sidecar

```yaml
# Deployment avec Ambassador sidecar
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: main-service
          image: my-service:latest
          ports:
            - containerPort: 8080
        - name: ambassador
          image: envoy:latest
          ports:
            - containerPort: 9000
```

## Cas d'usage

| Scenario | Benefice |
|----------|----------|
| Microservices legacy | Ajouter resilience sans modifier le code |
| Multi-cloud | Abstraction des specifites cloud |
| Compliance | Logging centralise pour audit |
| Migration | Transition progressive vers nouveaux protocoles |

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Ambassador trop lourd | Latence excessive | Garder leger, deleguer au mesh |
| Logique metier | Couplage fort | Ambassador = cross-cutting seulement |
| Sans monitoring | Debugging difficile | Toujours exposer des metriques |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Sidecar | Implementation concrete |
| Circuit Breaker | Fonctionnalite embarquee |
| Gateway | Alternative centralisee |
| Service Mesh | Evolution a grande echelle |

## Sources

- [Microsoft - Ambassador Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/ambassador)
- [Envoy Proxy](https://www.envoyproxy.io/)
