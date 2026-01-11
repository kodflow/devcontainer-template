# Circuit Breaker Pattern

> Prévenir les pannes en cascade dans les systèmes distribués.

## Principe

```
        ┌──────────────────────────────────────────────────────┐
        │                    CIRCUIT BREAKER                    │
        │                                                       │
        │   CLOSED ──────▶ OPEN ──────▶ HALF-OPEN              │
        │     │              │              │                   │
        │     │ failures     │ timeout      │ success           │
        │     │ > threshold  │ expires      │ → CLOSED          │
        │     │              │              │ failure           │
        │     │              │              │ → OPEN            │
        │     ▼              ▼              ▼                   │
        └──────────────────────────────────────────────────────┘

┌─────────┐         ┌──────────────┐         ┌─────────┐
│ Service │ ──────▶ │Circuit Breaker│ ──────▶ │ Remote  │
│   A     │         │              │         │ Service │
└─────────┘         └──────────────┘         └─────────┘
```

## États

| État | Comportement |
|------|--------------|
| **CLOSED** | Requêtes passent normalement. Compte les échecs. |
| **OPEN** | Requêtes échouent immédiatement (fail fast). |
| **HALF-OPEN** | Permet quelques requêtes test. |

## Exemple Go

```go
package circuitbreaker

import (
	"errors"
	"sync"
	"time"
)

// State represents the circuit breaker state.
type State string

const (
	StateClosed   State = "CLOSED"
	StateOpen     State = "OPEN"
	StateHalfOpen State = "HALF_OPEN"
)

// CircuitOpenError is returned when circuit is open.
var CircuitOpenError = errors.New("circuit breaker is open")

// CircuitBreaker implements the circuit breaker pattern.
type CircuitBreaker struct {
	mu            sync.RWMutex
	state         State
	failures      int
	lastFailure   time.Time
	threshold     int
	timeout       time.Duration
}

// NewCircuitBreaker creates a new CircuitBreaker.
func NewCircuitBreaker(threshold int, timeout time.Duration) *CircuitBreaker {
	return &CircuitBreaker{
		state:     StateClosed,
		threshold: threshold,
		timeout:   timeout,
	}
}

// Call executes the function with circuit breaker protection.
func (cb *CircuitBreaker) Call(fn func() error) error {
	cb.mu.RLock()
	state := cb.state
	lastFailure := cb.lastFailure
	cb.mu.RUnlock()

	if state == StateOpen {
		if time.Since(lastFailure) > cb.timeout {
			cb.mu.Lock()
			cb.state = StateHalfOpen
			cb.mu.Unlock()
		} else {
			return CircuitOpenError
		}
	}

	err := fn()
	if err != nil {
		cb.onFailure()
		return err
	}

	cb.onSuccess()
	return nil
}

func (cb *CircuitBreaker) onSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failures = 0
	cb.state = StateClosed
}

func (cb *CircuitBreaker) onFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failures++
	cb.lastFailure = time.Now()

	if cb.failures >= cb.threshold {
		cb.state = StateOpen
	}
}

// State returns the current circuit breaker state.
func (cb *CircuitBreaker) State() State {
	cb.mu.RLock()
	defer cb.mu.RUnlock()
	return cb.state
}
```

## Usage

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Configuration recommandée

| Paramètre | Valeur typique | Description |
|-----------|----------------|-------------|
| `threshold` | 5-10 | Échecs avant ouverture |
| `timeout` | 30-60s | Temps avant HALF_OPEN |
| `halfOpenRequests` | 1-3 | Requêtes test en HALF_OPEN |

## Librairies

| Langage | Librairie |
|---------|-----------|
| Node.js | `opossum`, `cockatiel` |
| Java | Resilience4j, Hystrix (deprecated) |
| Go | `sony/gobreaker` |
| Python | `pybreaker` |

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Retry | Avant circuit breaker |
| Bulkhead | Isolation des ressources |
| Fallback | Alternative quand circuit ouvert |
| Health Check | Monitoring du circuit |

## Sources

- [Microsoft - Circuit Breaker](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)
- [Martin Fowler - Circuit Breaker](https://martinfowler.com/bliki/CircuitBreaker.html)
