# Compensating Transaction Pattern

> Annuler les effets d'operations deja executees dans un workflow distribue.

## Principe

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    COMPENSATING TRANSACTION                              │
│                                                                          │
│   FORWARD OPERATIONS (Success path)                                      │
│   ┌────────┐     ┌────────┐     ┌────────┐     ┌────────┐              │
│   │   T1   │────▶│   T2   │────▶│   T3   │────▶│   T4   │              │
│   │ Create │     │ Reserve│     │ Charge │     │  Ship  │              │
│   │ Order  │     │ Stock  │     │ Payment│     │        │              │
│   └────────┘     └────────┘     └────────┘     └────────┘              │
│                                       │                                  │
│                                       │ FAILURE!                         │
│                                       ▼                                  │
│   COMPENSATION (Rollback path)                                           │
│   ┌────────┐     ┌────────┐     ┌────────┐                              │
│   │   C1   │◀────│   C2   │◀────│   C3   │                              │
│   │ Cancel │     │ Release│     │ Refund │                              │
│   │ Order  │     │ Stock  │     │ Payment│                              │
│   └────────┘     └────────┘     └────────┘                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Difference avec Rollback ACID

| Aspect | ACID Rollback | Compensation |
|--------|---------------|--------------|
| **Scope** | Transaction unique | Transactions distribuees |
| **Mecanisme** | Undo log DB | Logique metier explicite |
| **Atomicite** | Garantie | Best effort |
| **Visibility** | Invisible | Peut etre visible |

## Exemple Go

```go
package compensation

import (
	"context"
	"fmt"
	"log"
)

// CompensableOperation defines an operation that can be compensated.
type CompensableOperation[T any] struct {
	Name         string
	Execute      func(ctx context.Context) (T, error)
	Compensate   func(ctx context.Context, result T) error
	IsCompensable func(result T) bool
}

// ExecutedOperation tracks an executed operation with its result.
type ExecutedOperation struct {
	Name          string
	Result        interface{}
	IsCompensable bool
	CompensateFn  func(ctx context.Context) error
}

// CompensatingTransaction manages a sequence of compensable operations.
type CompensatingTransaction struct {
	executedOperations []ExecutedOperation
}

// NewCompensatingTransaction creates a new CompensatingTransaction.
func NewCompensatingTransaction() *CompensatingTransaction {
	return &CompensatingTransaction{
		executedOperations: make([]ExecutedOperation, 0),
	}
}

// Execute runs all operations and compensates on failure.
func (ct *CompensatingTransaction) Execute(ctx context.Context, operations []CompensableOperation[interface{}]) error {
	for _, op := range operations {
		log.Printf("Executing: %s", op.Name)
		
		result, err := op.Execute(ctx)
		if err != nil {
			log.Printf("Failed at: %s - %v", op.Name, err)
			if compErr := ct.compensate(ctx); compErr != nil {
				return fmt.Errorf("compensation failed: %w", compErr)
			}
			return fmt.Errorf("operation failed: %w", err)
		}

		// Track executed operation
		ct.executedOperations = append(ct.executedOperations, ExecutedOperation{
			Name:          op.Name,
			Result:        result,
			IsCompensable: op.IsCompensable(result),
			CompensateFn: func(ctx context.Context) error {
				return op.Compensate(ctx, result)
			},
		})
	}

	return nil
}

func (ct *CompensatingTransaction) compensate(ctx context.Context) error {
	log.Println("Starting compensation...")

	// Compensate in reverse order
	for i := len(ct.executedOperations) - 1; i >= 0; i-- {
		op := ct.executedOperations[i]
		
		if !op.IsCompensable {
			continue
		}

		log.Printf("Compensating: %s", op.Name)
		if err := op.CompensateFn(ctx); err != nil {
			// Log but continue compensating others
			log.Printf("Compensation failed for %s: %v", op.Name, err)
			// Queue for manual intervention
			ct.handleCompensationFailure(ctx, op, err)
		}
	}

	return nil
}

func (ct *CompensatingTransaction) handleCompensationFailure(ctx context.Context, op ExecutedOperation, err error) {
	// Queue for manual review
	log.Printf("Manual review needed for operation: %s, error: %v", op.Name, err)
}
```

## Exemple: Reservation de voyage (Go)

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Patterns de compensation

### 1. Compensation immediate

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

### 2. Compensation differee

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

### 3. Compensation avec retry

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Compensation non-idempotente | Double compensation | Idempotency keys |
| Sans timeout | Blocage indefini | Timeout + escalation |
| Compensation partielle ignoree | Etat inconsistant | Retry + alerting |
| Ordre incorrect | Dependances cassees | Compensation en ordre inverse |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Saga | Utilise compensating transactions |
| Outbox | Fiabilite des compensations |
| Retry | Resilience des compensations |
| Dead Letter | Compensations echouees |

## Sources

- [Microsoft - Compensating Transaction](https://learn.microsoft.com/en-us/azure/architecture/patterns/compensating-transaction)
- [Saga Pattern](saga.md)
