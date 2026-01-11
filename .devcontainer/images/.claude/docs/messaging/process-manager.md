# Process Manager Pattern

Orchestration de workflows complexes et Saga pattern.

## Vue d'ensemble

```
+------------------+     +------------------+
|  Process Manager |<--->|  State Store     |
+--------+---------+     +------------------+
         |
    Orchestrates
         |
    +----+----+----+----+
    |    |    |    |    |
    v    v    v    v    v
  Step  Step Step Step Step
   1     2    3    4    5

  Events flow back to Process Manager
  which decides next step based on state
```

---

## Process Manager

> Coordonne l'execution d'un workflow multi-etapes.

### Schema de workflow

```
+--------+     +----------+     +---------+     +---------+
| Create |---->| Validate |---->| Reserve |---->| Payment |
| Order  |     | Order    |     |Inventory|     | Process |
+--------+     +----+-----+     +----+----+     +----+----+
                   |                 |               |
                   v                 v               v
              [Validated]      [Reserved]      [Paid/Failed]
                   |                 |               |
                   +--------+--------+-------+-------+
                            |                |
                            v                v
                       +--------+       +--------+
                       |  Ship  |       | Cancel |
                       +--------+       +--------+
```

### Implementation

```typescript
interface ProcessState {
  processId: string;
  processType: string;
  currentStep: string;
  status: 'running' | 'completed' | 'failed' | 'compensating';
  data: Record<string, unknown>;
  history: StepExecution[];
  startedAt: Date;
  updatedAt: Date;
}

interface StepExecution {
  step: string;
  status: 'pending' | 'completed' | 'failed';
  startedAt: Date;
  completedAt?: Date;
  result?: unknown;
  error?: string;
}

abstract class ProcessManager<TData> {
  protected abstract steps: Map<string, Step<TData>>;
  protected abstract compensations: Map<string, Step<TData>>;

  constructor(
    protected stateStore: ProcessStateStore,
    protected messageBus: MessageBus
  ) {}

  async start(processId: string, initialData: TData): Promise<void> {
    const state: ProcessState = {
      processId,
      processType: this.constructor.name,
      currentStep: 'start',
      status: 'running',
      data: initialData as Record<string, unknown>,
      history: [],
      startedAt: new Date(),
      updatedAt: new Date(),
    };

    await this.stateStore.save(state);
    await this.executeNextStep(state);
  }

  async handleEvent(processId: string, event: ProcessEvent): Promise<void> {
    const state = await this.stateStore.load(processId);
    if (!state) {
      throw new ProcessNotFoundError(processId);
    }

    // Mettre a jour l'historique
    const currentExecution = state.history.find(
      h => h.step === state.currentStep && h.status === 'pending'
    );
    if (currentExecution) {
      currentExecution.status = event.success ? 'completed' : 'failed';
      currentExecution.completedAt = new Date();
      currentExecution.result = event.payload;
      if (!event.success) {
        currentExecution.error = event.error;
      }
    }

    // Determiner la prochaine action
    if (event.success) {
      state.data = { ...state.data, ...event.payload };
      await this.executeNextStep(state);
    } else {
      await this.handleFailure(state, event);
    }
  }

  protected async executeNextStep(state: ProcessState): Promise<void> {
    const nextStep = this.determineNextStep(state);

    if (!nextStep) {
      state.status = 'completed';
      state.updatedAt = new Date();
      await this.stateStore.save(state);
      await this.onComplete(state);
      return;
    }

    state.currentStep = nextStep;
    state.history.push({
      step: nextStep,
      status: 'pending',
      startedAt: new Date(),
    });
    state.updatedAt = new Date();
    await this.stateStore.save(state);

    const step = this.steps.get(nextStep)!;
    await step.execute(state.processId, state.data as TData);
  }

  protected abstract determineNextStep(state: ProcessState): string | null;
  protected abstract handleFailure(state: ProcessState, event: ProcessEvent): Promise<void>;
  protected abstract onComplete(state: ProcessState): Promise<void>;
}
```

---

## Saga Pattern

> Pattern de transactions distribuees avec compensation.

### Schema

```
+--------+     +----------+     +---------+
| Step 1 |---->|  Step 2  |---->| Step 3  |---> SUCCESS
+---+----+     +----+-----+     +----+----+
    |               |                |
    |  COMPENSATE   |  COMPENSATE    | FAIL
    v               v                |
+--------+     +----------+          |
|Undo 1  |<----|  Undo 2  |<---------+
+--------+     +----------+
```

### Implementation Saga Orchestree

```typescript
interface SagaStep<T> {
  name: string;
  execute: (data: T) => Promise<StepResult>;
  compensate: (data: T) => Promise<void>;
}

interface StepResult {
  success: boolean;
  data?: unknown;
  error?: string;
}

class SagaOrchestrator<T> {
  constructor(
    private steps: SagaStep<T>[],
    private stateStore: SagaStateStore
  ) {}

  async execute(sagaId: string, initialData: T): Promise<SagaResult> {
    const executedSteps: string[] = [];
    let currentData = initialData;

    try {
      for (const step of this.steps) {
        await this.saveState(sagaId, step.name, 'executing', currentData);

        const result = await step.execute(currentData);

        if (!result.success) {
          await this.compensate(sagaId, executedSteps, currentData);
          return { success: false, error: result.error };
        }

        executedSteps.push(step.name);
        currentData = { ...currentData, ...result.data } as T;
        await this.saveState(sagaId, step.name, 'completed', currentData);
      }

      return { success: true, data: currentData };
    } catch (error) {
      await this.compensate(sagaId, executedSteps, currentData);
      return { success: false, error: (error as Error).message };
    }
  }

  private async compensate(
    sagaId: string,
    executedSteps: string[],
    data: T
  ): Promise<void> {
    // Compenser dans l'ordre inverse
    for (const stepName of [...executedSteps].reverse()) {
      const step = this.steps.find(s => s.name === stepName)!;
      try {
        await this.saveState(sagaId, stepName, 'compensating', data);
        await step.compensate(data);
        await this.saveState(sagaId, stepName, 'compensated', data);
      } catch (error) {
        // Log mais continuer les compensations
        console.error(`Compensation failed for ${stepName}:`, error);
        await this.saveState(sagaId, stepName, 'compensation_failed', data);
      }
    }
  }
}

// Exemple: Order Saga
const orderSaga = new SagaOrchestrator<OrderData>([
  {
    name: 'reserve_inventory',
    execute: async (data) => {
      const result = await inventoryService.reserve(data.items);
      return { success: result.reserved, data: { reservationId: result.id } };
    },
    compensate: async (data) => {
      await inventoryService.release(data.reservationId);
    },
  },
  {
    name: 'process_payment',
    execute: async (data) => {
      const result = await paymentService.charge(data.customerId, data.total);
      return { success: result.success, data: { paymentId: result.id } };
    },
    compensate: async (data) => {
      await paymentService.refund(data.paymentId);
    },
  },
  {
    name: 'create_shipment',
    execute: async (data) => {
      const result = await shippingService.createShipment(data);
      return { success: true, data: { shipmentId: result.id } };
    },
    compensate: async (data) => {
      await shippingService.cancelShipment(data.shipmentId);
    },
  },
]);
```

---

## Saga Choregraphiee

```typescript
// Chaque service reagit aux evenements et publie le suivant

class OrderService {
  @OnEvent('OrderCreated')
  async handleOrderCreated(event: OrderCreatedEvent): Promise<void> {
    await this.eventBus.publish('inventory', {
      type: 'ReserveInventory',
      orderId: event.orderId,
      items: event.items,
    });
  }

  @OnEvent('InventoryReserved')
  async handleInventoryReserved(event: InventoryReservedEvent): Promise<void> {
    await this.eventBus.publish('payment', {
      type: 'ProcessPayment',
      orderId: event.orderId,
      amount: event.totalAmount,
    });
  }

  @OnEvent('PaymentFailed')
  async handlePaymentFailed(event: PaymentFailedEvent): Promise<void> {
    // Declencher compensation
    await this.eventBus.publish('inventory', {
      type: 'ReleaseInventory',
      orderId: event.orderId,
      reservationId: event.reservationId,
    });

    await this.updateOrderStatus(event.orderId, 'failed');
  }
}
```

---

## Gestion d'etat persistant

```typescript
interface ProcessStateStore {
  save(state: ProcessState): Promise<void>;
  load(processId: string): Promise<ProcessState | null>;
  findByStatus(status: string): Promise<ProcessState[]>;
}

// Implementation PostgreSQL
class PostgresProcessStateStore implements ProcessStateStore {
  async save(state: ProcessState): Promise<void> {
    await this.db.query(
      `INSERT INTO process_states (process_id, process_type, current_step, status, data, history, started_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (process_id) DO UPDATE SET
         current_step = $3, status = $4, data = $5, history = $6, updated_at = $8`,
      [
        state.processId,
        state.processType,
        state.currentStep,
        state.status,
        JSON.stringify(state.data),
        JSON.stringify(state.history),
        state.startedAt,
        new Date(),
      ]
    );
  }

  // Recovery des processus bloques
  async recoverStuckProcesses(): Promise<void> {
    const stuckProcesses = await this.db.query(
      `SELECT * FROM process_states
       WHERE status = 'running'
       AND updated_at < NOW() - INTERVAL '5 minutes'`
    );

    for (const row of stuckProcesses.rows) {
      const state = this.rowToState(row);
      await this.processManager.resume(state);
    }
  }
}
```

---

## Cas d'erreur

```typescript
class ResilientProcessManager extends ProcessManager<OrderData> {
  protected async handleFailure(
    state: ProcessState,
    event: ProcessEvent
  ): Promise<void> {
    const retryCount = this.getRetryCount(state, state.currentStep);

    if (retryCount < 3) {
      // Retry avec backoff
      await this.scheduleRetry(state, Math.pow(2, retryCount) * 1000);
    } else {
      // Demarrer compensation
      state.status = 'compensating';
      await this.stateStore.save(state);
      await this.startCompensation(state);
    }
  }

  private async startCompensation(state: ProcessState): Promise<void> {
    const completedSteps = state.history
      .filter(h => h.status === 'completed')
      .map(h => h.step)
      .reverse();

    for (const stepName of completedSteps) {
      const compensation = this.compensations.get(stepName);
      if (compensation) {
        try {
          await compensation.execute(state.processId, state.data as OrderData);
        } catch (error) {
          // Log et alerter pour intervention manuelle
          await this.alertManualIntervention(state, stepName, error);
        }
      }
    }

    state.status = 'failed';
    await this.stateStore.save(state);
  }
}
```

---

## Patterns complementaires

- **Routing Slip** - Workflow dynamique
- **Dead Letter Channel** - Echecs de process
- **Idempotent Receiver** - Eviter duplications
- **Transactional Outbox** - Fiabilite des messages
