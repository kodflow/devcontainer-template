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

## Exemple TypeScript

```typescript
interface CompensableOperation<T> {
  name: string;
  execute: () => Promise<T>;
  compensate: (result: T) => Promise<void>;
  isCompensable: (result: T) => boolean;
}

class CompensatingTransaction {
  private executedOperations: Array<{
    operation: CompensableOperation<any>;
    result: any;
  }> = [];

  async execute<T>(operations: CompensableOperation<T>[]): Promise<void> {
    for (const operation of operations) {
      try {
        console.log(`Executing: ${operation.name}`);
        const result = await operation.execute();

        this.executedOperations.push({ operation, result });
      } catch (error) {
        console.error(`Failed at: ${operation.name}`, error);
        await this.compensate();
        throw error;
      }
    }
  }

  private async compensate(): Promise<void> {
    console.log('Starting compensation...');

    // Compensate in reverse order
    const toCompensate = [...this.executedOperations].reverse();

    for (const { operation, result } of toCompensate) {
      if (operation.isCompensable(result)) {
        try {
          console.log(`Compensating: ${operation.name}`);
          await operation.compensate(result);
        } catch (error) {
          // Log but continue compensating others
          console.error(`Compensation failed for ${operation.name}:`, error);
          await this.handleCompensationFailure(operation, result, error);
        }
      }
    }
  }

  private async handleCompensationFailure(
    operation: CompensableOperation<any>,
    result: any,
    error: unknown,
  ): Promise<void> {
    // Queue for manual intervention or retry
    await this.queueForManualReview({
      operation: operation.name,
      result,
      error: String(error),
      timestamp: new Date(),
    });
  }
}
```

## Exemple: Reservation de voyage

```typescript
interface BookingResult {
  confirmationId: string;
  status: 'confirmed' | 'pending';
}

// Operations compensables
const bookFlight: CompensableOperation<BookingResult> = {
  name: 'Book Flight',
  async execute() {
    const response = await flightService.book({
      from: 'CDG',
      to: 'JFK',
      date: '2024-06-15',
    });
    return { confirmationId: response.id, status: 'confirmed' };
  },
  async compensate(result) {
    await flightService.cancel(result.confirmationId);
  },
  isCompensable: (result) => result.status === 'confirmed',
};

const bookHotel: CompensableOperation<BookingResult> = {
  name: 'Book Hotel',
  async execute() {
    const response = await hotelService.book({
      city: 'New York',
      checkIn: '2024-06-15',
      checkOut: '2024-06-20',
    });
    return { confirmationId: response.id, status: 'confirmed' };
  },
  async compensate(result) {
    await hotelService.cancel(result.confirmationId);
  },
  isCompensable: (result) => result.status === 'confirmed',
};

const bookCar: CompensableOperation<BookingResult> = {
  name: 'Book Rental Car',
  async execute() {
    const response = await carService.book({
      location: 'JFK Airport',
      pickUp: '2024-06-15',
      dropOff: '2024-06-20',
    });
    return { confirmationId: response.id, status: 'confirmed' };
  },
  async compensate(result) {
    await carService.cancel(result.confirmationId);
  },
  isCompensable: (result) => result.status === 'confirmed',
};

const chargePayment: CompensableOperation<{ transactionId: string }> = {
  name: 'Charge Payment',
  async execute() {
    const response = await paymentService.charge({
      amount: 2500,
      currency: 'EUR',
    });
    return { transactionId: response.id };
  },
  async compensate(result) {
    await paymentService.refund(result.transactionId);
  },
  isCompensable: () => true,
};

// Execution
async function bookTrip() {
  const transaction = new CompensatingTransaction();

  try {
    await transaction.execute([
      bookFlight,
      bookHotel,
      bookCar,
      chargePayment,
    ]);
    console.log('Trip booked successfully!');
  } catch (error) {
    console.log('Trip booking failed, all operations compensated');
  }
}
```

## Patterns de compensation

### 1. Compensation immediate

```typescript
// Compensation des que l'echec est detecte
try {
  await step1();
  await step2();
  await step3(); // Echoue
} catch {
  await compensateStep2();
  await compensateStep1();
}
```

### 2. Compensation differee

```typescript
// Compensation via une queue pour fiabilite
await compensationQueue.publish({
  operations: completedSteps,
  reason: 'step3_failed',
});

// Worker de compensation
compensationQueue.subscribe(async (msg) => {
  for (const op of msg.operations.reverse()) {
    await executeCompensation(op);
  }
});
```

### 3. Compensation avec retry

```typescript
async function compensateWithRetry(
  operation: CompensableOperation<any>,
  result: any,
  maxRetries = 3,
): Promise<void> {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      await operation.compensate(result);
      return;
    } catch (error) {
      if (attempt === maxRetries) {
        await alertOperations(operation, result, error);
        throw error;
      }
      await delay(Math.pow(2, attempt) * 1000);
    }
  }
}
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
