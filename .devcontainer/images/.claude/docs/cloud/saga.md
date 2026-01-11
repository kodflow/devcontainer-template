# Saga Pattern

> Gérer les transactions distribuées sans 2PC.

## Problème

```
❌ Transaction ACID impossible en distribué

┌─────────┐     ┌─────────┐     ┌─────────┐
│ Order   │     │ Payment │     │ Stock   │
│ Service │     │ Service │     │ Service │
└────┬────┘     └────┬────┘     └────┬────┘
     │               │               │
     └───── Pas de transaction commune ─────┘
```

## Solution : Saga

Séquence de transactions locales avec compensations.

```
┌────────────────────────────────────────────────────────────────┐
│                           SAGA                                  │
│                                                                 │
│  T1 ──▶ T2 ──▶ T3 ──▶ T4                                      │
│  │      │      │      │                                        │
│  C1 ◀── C2 ◀── C3 ◀── (échec)                                 │
│                                                                 │
│  T = Transaction locale                                         │
│  C = Compensation (rollback)                                    │
└────────────────────────────────────────────────────────────────┘
```

## Deux approches

### 1. Choreography (événements)

```
┌─────────┐   OrderCreated   ┌─────────┐   PaymentDone   ┌─────────┐
│  Order  │ ───────────────▶ │ Payment │ ───────────────▶ │  Stock  │
│ Service │                  │ Service │                  │ Service │
└─────────┘                  └─────────┘                  └─────────┘
     ▲                            │                            │
     │         PaymentFailed      │                            │
     └────────────────────────────┘                            │
     │                        StockReserved                    │
     └─────────────────────────────────────────────────────────┘
```

```go
package saga

import (
	"context"
	"fmt"
	"log"
)

// SagaStep defines a step in a saga with action and compensation.
type SagaStep struct {
	Action       func(ctx context.Context) error
	Compensation func(ctx context.Context) error
}

// Saga manages a sequence of saga steps.
type Saga struct {
	steps          []SagaStep
	completedSteps []SagaStep
}

// NewSaga creates a new Saga.
func NewSaga() *Saga {
	return &Saga{
		steps:          make([]SagaStep, 0),
		completedSteps: make([]SagaStep, 0),
	}
}

// AddStep adds a step to the saga.
func (s *Saga) AddStep(step SagaStep) {
	s.steps = append(s.steps, step)
}

// Execute executes all saga steps.
func (s *Saga) Execute(ctx context.Context) error {
	for _, step := range s.steps {
		if err := step.Action(ctx); err != nil {
			log.Printf("Saga step failed: %v", err)
			
			// Compensate all completed steps
			if compErr := s.Compensate(ctx); compErr != nil {
				return fmt.Errorf("compensation failed: %w (original error: %v)", compErr, err)
			}
			
			return fmt.Errorf("saga execution failed: %w", err)
		}
		
		s.completedSteps = append(s.completedSteps, step)
	}
	
	return nil
}

// Compensate compensates all completed steps in reverse order.
func (s *Saga) Compensate(ctx context.Context) error {
	log.Println("Starting saga compensation...")
	
	// Compensate in reverse order
	for i := len(s.completedSteps) - 1; i >= 0; i-- {
		step := s.completedSteps[i]
		
		if err := step.Compensation(ctx); err != nil {
			// Log but continue compensating others
			log.Printf("Compensation step %d failed: %v", i, err)
			// In production, this should be queued for manual intervention
		}
	}
	
	return nil
}
```

### 2. Orchestration (coordinateur)

```
                    ┌─────────────────┐
                    │  Saga           │
                    │  Orchestrator   │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
   ┌─────────┐         ┌─────────┐         ┌─────────┐
   │  Order  │         │ Payment │         │  Stock  │
   │ Service │         │ Service │         │ Service │
   └─────────┘         └─────────┘         └─────────┘
```

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Comparaison

| Aspect | Choreography | Orchestration |
|--------|--------------|---------------|
| Couplage | Faible | Centralisé |
| Complexité | Distribuée | Dans l'orchestrateur |
| Debugging | Difficile | Plus facile |
| Scalabilité | Meilleure | Orchestrateur = SPOF |
| Recommandé | Sagas simples | Sagas complexes |

## Implémentation Saga Class

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Event Sourcing | Historique des états |
| CQRS | Modèle read pour suivi |
| Outbox | Fiabilité des événements |

## Sources

- [Microsoft - Saga Pattern](https://learn.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga)
- [microservices.io - Saga](https://microservices.io/patterns/data/saga.html)
