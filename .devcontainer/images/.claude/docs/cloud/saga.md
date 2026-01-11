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

```typescript
// Order Service
class OrderService {
  @OnEvent(PaymentCompletedEvent)
  async onPaymentCompleted(event: PaymentCompletedEvent) {
    await this.orderRepo.updateStatus(event.orderId, 'PAID');
    await this.eventBus.publish(new ReserveStockEvent(event.orderId));
  }

  @OnEvent(PaymentFailedEvent)
  async onPaymentFailed(event: PaymentFailedEvent) {
    await this.orderRepo.updateStatus(event.orderId, 'CANCELLED');
    // Compensation: annuler la commande
  }
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

```typescript
class OrderSagaOrchestrator {
  async execute(order: Order) {
    const saga = new Saga();

    saga.addStep({
      action: () => this.orderService.create(order),
      compensation: () => this.orderService.cancel(order.id),
    });

    saga.addStep({
      action: () => this.paymentService.charge(order.userId, order.total),
      compensation: () => this.paymentService.refund(order.id),
    });

    saga.addStep({
      action: () => this.stockService.reserve(order.items),
      compensation: () => this.stockService.release(order.items),
    });

    try {
      await saga.execute();
    } catch (error) {
      await saga.compensate(); // Rollback
      throw error;
    }
  }
}
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

```typescript
interface SagaStep {
  action: () => Promise<void>;
  compensation: () => Promise<void>;
}

class Saga {
  private steps: SagaStep[] = [];
  private completedSteps: SagaStep[] = [];

  addStep(step: SagaStep) {
    this.steps.push(step);
  }

  async execute() {
    for (const step of this.steps) {
      try {
        await step.action();
        this.completedSteps.push(step);
      } catch (error) {
        await this.compensate();
        throw error;
      }
    }
  }

  async compensate() {
    // Compensation en ordre inverse
    for (const step of this.completedSteps.reverse()) {
      try {
        await step.compensation();
      } catch (error) {
        // Log but continue compensation
        console.error('Compensation failed:', error);
      }
    }
  }
}
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
