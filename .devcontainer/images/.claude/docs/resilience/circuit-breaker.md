# Circuit Breaker Pattern

> Prevenir les pannes en cascade en arretant les appels vers un service defaillant.

---

## Principe

```
        ┌──────────────────────────────────────────────────────┐
        │                    CIRCUIT BREAKER                    │
        │                                                       │
        │   CLOSED ──────► OPEN ──────► HALF-OPEN              │
        │     │              │              │                   │
        │     │ failures     │ timeout      │ success           │
        │     │ > threshold  │ expires      │ → CLOSED          │
        │     │              │              │ failure           │
        │     │              │              │ → OPEN            │
        │     ▼              ▼              ▼                   │
        └──────────────────────────────────────────────────────┘

┌─────────┐         ┌──────────────┐         ┌─────────┐
│ Service │ ──────► │Circuit Breaker│ ──────► │ Remote  │
│   A     │         │              │         │ Service │
└─────────┘         └──────────────┘         └─────────┘
```

---

## Etats

| Etat | Comportement |
|------|--------------|
| **CLOSED** | Requetes passent normalement. Compte les echecs. |
| **OPEN** | Requetes echouent immediatement (fail fast). |
| **HALF-OPEN** | Permet quelques requetes test pour verifier la recovery. |

---

## Implementation Go

```go
package circuitbreaker

import (
	"errors"
	"fmt"
	"sync"
	"time"
)

// State represents circuit breaker state.
type State int

const (
	StateClosed State = iota
	StateOpen
	StateHalfOpen
)

func (s State) String() string {
	switch s {
	case StateClosed:
		return "CLOSED"
	case StateOpen:
		return "OPEN"
	case StateHalfOpen:
		return "HALF_OPEN"
	default:
		return "UNKNOWN"
	}
}

// ErrCircuitOpen is returned when circuit is open.
var ErrCircuitOpen = errors.New("circuit breaker is open")

// CircuitBreakerError wraps circuit breaker errors.
type CircuitBreakerError struct {
	Message string
}

func (e *CircuitBreakerError) Error() string {
	return e.Message
}

// Options configures circuit breaker behavior.
type Options struct {
	FailureThreshold  int           // Failures before opening
	SuccessThreshold  int           // Successes to close from half-open
	Timeout           time.Duration // Time before half-open
	HalfOpenRequests  int           // Max requests in half-open
}

// CircuitBreaker implements the circuit breaker pattern.
type CircuitBreaker struct {
	mu               sync.RWMutex
	state            State
	failures         int
	successes        int
	lastFailureTime  time.Time
	halfOpenAttempts int
	options          Options
}

// NewCircuitBreaker creates a new circuit breaker.
func NewCircuitBreaker(options Options) *CircuitBreaker {
	return &CircuitBreaker{
		state:   StateClosed,
		options: options,
	}
}

// Execute runs fn through the circuit breaker.
func (cb *CircuitBreaker) Execute(fn func() error) error {
	if !cb.canExecute() {
		return ErrCircuitOpen
	}

	err := fn()
	if err != nil {
		cb.onFailure()
		return err
	}

	cb.onSuccess()
	return nil
}

func (cb *CircuitBreaker) canExecute() bool {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	switch cb.state {
	case StateClosed:
		return true

	case StateOpen:
		elapsed := time.Since(cb.lastFailureTime)
		if elapsed >= cb.options.Timeout {
			cb.transitionTo(StateHalfOpen)
			return true
		}
		return false

	case StateHalfOpen:
		if cb.halfOpenAttempts < cb.options.HalfOpenRequests {
			cb.halfOpenAttempts++
			return true
		}
		return false

	default:
		return false
	}
}

func (cb *CircuitBreaker) onSuccess() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	if cb.state == StateHalfOpen {
		cb.successes++
		if cb.successes >= cb.options.SuccessThreshold {
			cb.transitionTo(StateClosed)
		}
	} else {
		cb.failures = 0
	}
}

func (cb *CircuitBreaker) onFailure() {
	cb.mu.Lock()
	defer cb.mu.Unlock()

	cb.failures++
	cb.lastFailureTime = time.Now()

	if cb.state == StateHalfOpen {
		cb.transitionTo(StateOpen)
	} else if cb.failures >= cb.options.FailureThreshold {
		cb.transitionTo(StateOpen)
	}
}

func (cb *CircuitBreaker) transitionTo(newState State) {
	oldState := cb.state
	cb.state = newState

	if newState == StateClosed {
		cb.failures = 0
		cb.successes = 0
		cb.halfOpenAttempts = 0
	} else if newState == StateHalfOpen {
		cb.halfOpenAttempts = 0
		cb.successes = 0
	}

	// Log state transition
	log.Printf("Circuit breaker: %s → %s", oldState, newState)
}

// GetState returns current circuit state.
func (cb *CircuitBreaker) GetState() State {
	cb.mu.RLock()
	defer cb.mu.RUnlock()
	return cb.state
}
```

---

## Usage avec fallback

```go
package circuitbreaker

import (
	"context"
	"fmt"
)

// Usage example with fallback
func getUserWithFallback(ctx context.Context, userID string) (*User, error) {
	cb := NewCircuitBreaker(Options{
		FailureThreshold: 5,
		SuccessThreshold: 2,
		Timeout:          30 * time.Second,
		HalfOpenRequests: 3,
	})

	var user *User
	err := cb.Execute(func() error {
		var err error
		user, err = fetchUserFromAPI(ctx, userID)
		return err
	})

	if err != nil {
		if errors.Is(err, ErrCircuitOpen) {
			// Circuit is open, use cache
			return getCachedUser(userID)
		}
		return nil, err
	}

	return user, nil
}

func fetchUserFromAPI(ctx context.Context, userID string) (*User, error) {
	// HTTP call to external API
	resp, err := http.Get(fmt.Sprintf("https://api.example.com/users/%s", userID))
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	var user User
	if err := json.NewDecoder(resp.Body).Decode(&user); err != nil {
		return nil, err
	}

	return &user, nil
}
```

---

## Configuration recommandee

| Parametre | Valeur typique | Description |
|-----------|----------------|-------------|
| `failureThreshold` | 5-10 | Echecs consecutifs avant ouverture |
| `successThreshold` | 2-3 | Succes en HALF_OPEN pour fermer |
| `timeout` | 30-60s | Duree avant passage en HALF_OPEN |
| `halfOpenRequests` | 1-3 | Requetes test en HALF_OPEN |

---

## Quand utiliser

- Appels vers des services externes (APIs, databases)
- Microservices avec dependances reseau
- Integration avec des systemes tiers instables
- Protection contre les pannes en cascade

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [Retry](retry.md) | Utiliser avant le circuit breaker |
| [Timeout](timeout.md) | Limiter le temps par tentative |
| [Bulkhead](bulkhead.md) | Isolation complementaire |
| [Health Check](health-check.md) | Monitoring du circuit |

---

## Librairies

| Langage | Librairie |
|---------|-----------|
| Node.js | `opossum`, `cockatiel` |
| Java | Resilience4j |
| Go | `sony/gobreaker` |
| Python | `pybreaker` |
| .NET | Polly |

---

## Sources

- [Microsoft - Circuit Breaker](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)
- [Martin Fowler - Circuit Breaker](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Release It! - Michael Nygard](https://pragprog.com/titles/mnee2/release-it-second-edition/)
