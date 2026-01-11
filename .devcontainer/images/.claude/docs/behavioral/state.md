# State Pattern

> Permettre a un objet de modifier son comportement lorsque son etat change.

## Intention

Permettre a un objet de modifier son comportement lorsque son etat interne
change. L'objet semblera changer de classe.

## Structure

```typescript
// 1. Interface State
interface OrderState {
  name: string;
  confirm(order: Order): void;
  ship(order: Order): void;
  deliver(order: Order): void;
  cancel(order: Order): void;
}

// 2. Context
class Order {
  private state: OrderState;
  public id: string;
  public items: OrderItem[];

  constructor(id: string, items: OrderItem[]) {
    this.id = id;
    this.items = items;
    this.state = new PendingState();
  }

  setState(state: OrderState): void {
    console.log(`Order ${this.id}: ${this.state.name} -> ${state.name}`);
    this.state = state;
  }

  getState(): string {
    return this.state.name;
  }

  // Delegue au state actuel
  confirm(): void {
    this.state.confirm(this);
  }

  ship(): void {
    this.state.ship(this);
  }

  deliver(): void {
    this.state.deliver(this);
  }

  cancel(): void {
    this.state.cancel(this);
  }
}

// 3. Concrete States
class PendingState implements OrderState {
  name = 'Pending';

  confirm(order: Order): void {
    console.log('Payment confirmed, preparing order...');
    order.setState(new ConfirmedState());
  }

  ship(order: Order): void {
    throw new Error('Cannot ship: order not confirmed yet');
  }

  deliver(order: Order): void {
    throw new Error('Cannot deliver: order not shipped yet');
  }

  cancel(order: Order): void {
    console.log('Order cancelled before confirmation');
    order.setState(new CancelledState());
  }
}

class ConfirmedState implements OrderState {
  name = 'Confirmed';

  confirm(order: Order): void {
    console.log('Order already confirmed');
  }

  ship(order: Order): void {
    console.log('Order shipped!');
    order.setState(new ShippedState());
  }

  deliver(order: Order): void {
    throw new Error('Cannot deliver: order not shipped yet');
  }

  cancel(order: Order): void {
    console.log('Order cancelled, initiating refund...');
    order.setState(new CancelledState());
  }
}

class ShippedState implements OrderState {
  name = 'Shipped';

  confirm(order: Order): void {
    console.log('Order already confirmed and shipped');
  }

  ship(order: Order): void {
    console.log('Order already shipped');
  }

  deliver(order: Order): void {
    console.log('Order delivered!');
    order.setState(new DeliveredState());
  }

  cancel(order: Order): void {
    throw new Error('Cannot cancel: order already shipped');
  }
}

class DeliveredState implements OrderState {
  name = 'Delivered';

  confirm(order: Order): void {
    console.log('Order already delivered');
  }

  ship(order: Order): void {
    console.log('Order already delivered');
  }

  deliver(order: Order): void {
    console.log('Order already delivered');
  }

  cancel(order: Order): void {
    throw new Error('Cannot cancel: order already delivered');
  }
}

class CancelledState implements OrderState {
  name = 'Cancelled';

  confirm(order: Order): void {
    throw new Error('Cannot confirm: order is cancelled');
  }

  ship(order: Order): void {
    throw new Error('Cannot ship: order is cancelled');
  }

  deliver(order: Order): void {
    throw new Error('Cannot deliver: order is cancelled');
  }

  cancel(order: Order): void {
    console.log('Order already cancelled');
  }
}
```

## Usage

```typescript
const order = new Order('ORD-001', [{ product: 'Laptop', qty: 1 }]);

console.log(order.getState()); // Pending

order.confirm(); // Payment confirmed, preparing order...
console.log(order.getState()); // Confirmed

order.ship(); // Order shipped!
console.log(order.getState()); // Shipped

try {
  order.cancel(); // Error: Cannot cancel: order already shipped
} catch (e) {
  console.log(e.message);
}

order.deliver(); // Order delivered!
console.log(order.getState()); // Delivered
```

## State Machine avec transitions explicites

```typescript
type StateType = 'idle' | 'loading' | 'success' | 'error';
type EventType = 'FETCH' | 'SUCCESS' | 'ERROR' | 'RETRY' | 'RESET';

interface StateConfig {
  on: Partial<Record<EventType, StateType>>;
  onEnter?: () => void;
  onExit?: () => void;
}

type MachineConfig = Record<StateType, StateConfig>;

class StateMachine {
  private state: StateType;
  private config: MachineConfig;

  constructor(initialState: StateType, config: MachineConfig) {
    this.state = initialState;
    this.config = config;
    this.config[initialState].onEnter?.();
  }

  getState(): StateType {
    return this.state;
  }

  send(event: EventType): void {
    const currentConfig = this.config[this.state];
    const nextState = currentConfig.on[event];

    if (!nextState) {
      console.warn(`No transition for ${event} from ${this.state}`);
      return;
    }

    // Execute exit action
    currentConfig.onExit?.();

    // Transition
    console.log(`${this.state} --(${event})--> ${nextState}`);
    this.state = nextState;

    // Execute enter action
    this.config[nextState].onEnter?.();
  }

  can(event: EventType): boolean {
    return !!this.config[this.state].on[event];
  }
}

// Configuration declarative
const fetchMachine = new StateMachine('idle', {
  idle: {
    on: { FETCH: 'loading' },
    onEnter: () => console.log('Ready to fetch'),
  },
  loading: {
    on: { SUCCESS: 'success', ERROR: 'error' },
    onEnter: () => console.log('Fetching data...'),
  },
  success: {
    on: { RESET: 'idle' },
    onEnter: () => console.log('Data loaded!'),
  },
  error: {
    on: { RETRY: 'loading', RESET: 'idle' },
    onEnter: () => console.log('Fetch failed'),
  },
});

// Usage
fetchMachine.send('FETCH'); // idle --(FETCH)--> loading
fetchMachine.send('SUCCESS'); // loading --(SUCCESS)--> success
fetchMachine.send('RESET'); // success --(RESET)--> idle
```

## State avec historique

```typescript
interface StateWithHistory {
  name: string;
  handle(context: DocumentContext): void;
}

class DocumentContext {
  private state: StateWithHistory;
  private history: StateWithHistory[] = [];

  constructor() {
    this.state = new DraftState();
  }

  setState(state: StateWithHistory, saveHistory = true): void {
    if (saveHistory) {
      this.history.push(this.state);
    }
    this.state = state;
  }

  goBack(): void {
    const previous = this.history.pop();
    if (previous) {
      this.state = previous;
    }
  }

  process(): void {
    this.state.handle(this);
  }
}
```

## State avec persistence

```typescript
interface SerializableState {
  name: string;
  data: Record<string, unknown>;
}

class PersistentStateMachine {
  private state: OrderState;
  private stateData: Record<string, unknown> = {};

  constructor(serialized?: SerializableState) {
    if (serialized) {
      this.state = this.deserializeState(serialized.name);
      this.stateData = serialized.data;
    } else {
      this.state = new PendingState();
    }
  }

  private deserializeState(name: string): OrderState {
    const states: Record<string, OrderState> = {
      Pending: new PendingState(),
      Confirmed: new ConfirmedState(),
      Shipped: new ShippedState(),
      Delivered: new DeliveredState(),
      Cancelled: new CancelledState(),
    };
    return states[name] ?? new PendingState();
  }

  serialize(): SerializableState {
    return {
      name: this.state.name,
      data: this.stateData,
    };
  }

  // Sauvegarder en base de donnees
  async persist(): Promise<void> {
    await db.save('state', this.serialize());
  }

  // Charger depuis base de donnees
  static async load(): Promise<PersistentStateMachine> {
    const data = await db.get('state');
    return new PersistentStateMachine(data);
  }
}
```

## Anti-patterns

```typescript
// MAUVAIS: Logique de transition dans le context
class BadContext {
  private state: string = 'pending';

  process(): void {
    // La logique devrait etre dans les states
    if (this.state === 'pending') {
      // ...
      this.state = 'processing';
    } else if (this.state === 'processing') {
      // ...
      this.state = 'completed';
    }
  }
}

// MAUVAIS: States qui connaissent trop de contexte
class TightlyCoupledState implements OrderState {
  handle(order: Order): void {
    // Acces direct aux proprietes internes
    order.privateMethod(); // Violation encapsulation
    order.internalData = 'modified'; // Modification directe
  }
}

// MAUVAIS: State avec etat interne
class StatefulState implements OrderState {
  private attempts = 0; // Etat dans le state = problemes

  handle(order: Order): void {
    this.attempts++;
    // Le state est partage entre tous les orders!
  }
}
```

## Tests unitaires

```typescript
import { describe, it, expect, vi } from 'vitest';

describe('Order State Machine', () => {
  describe('PendingState', () => {
    it('should transition to Confirmed on confirm', () => {
      const order = new Order('1', []);
      expect(order.getState()).toBe('Pending');

      order.confirm();

      expect(order.getState()).toBe('Confirmed');
    });

    it('should transition to Cancelled on cancel', () => {
      const order = new Order('1', []);

      order.cancel();

      expect(order.getState()).toBe('Cancelled');
    });

    it('should throw on ship', () => {
      const order = new Order('1', []);

      expect(() => order.ship()).toThrow('Cannot ship');
    });
  });

  describe('ShippedState', () => {
    let order: Order;

    beforeEach(() => {
      order = new Order('1', []);
      order.confirm();
      order.ship();
    });

    it('should transition to Delivered on deliver', () => {
      order.deliver();

      expect(order.getState()).toBe('Delivered');
    });

    it('should throw on cancel', () => {
      expect(() => order.cancel()).toThrow('Cannot cancel');
    });
  });

  describe('Full workflow', () => {
    it('should complete happy path', () => {
      const order = new Order('1', []);

      order.confirm();
      order.ship();
      order.deliver();

      expect(order.getState()).toBe('Delivered');
    });

    it('should handle cancellation path', () => {
      const order = new Order('1', []);

      order.confirm();
      order.cancel();

      expect(order.getState()).toBe('Cancelled');
    });
  });
});

describe('StateMachine', () => {
  it('should transition on valid events', () => {
    const machine = new StateMachine('idle', {
      idle: { on: { FETCH: 'loading' } },
      loading: { on: { SUCCESS: 'success' } },
      success: { on: {} },
    });

    machine.send('FETCH');
    expect(machine.getState()).toBe('loading');

    machine.send('SUCCESS');
    expect(machine.getState()).toBe('success');
  });

  it('should ignore invalid transitions', () => {
    const machine = new StateMachine('idle', {
      idle: { on: { FETCH: 'loading' } },
      loading: { on: {} },
    });

    machine.send('SUCCESS'); // Invalid from idle

    expect(machine.getState()).toBe('idle');
  });

  it('should call onEnter/onExit hooks', () => {
    const onEnter = vi.fn();
    const onExit = vi.fn();

    const machine = new StateMachine('idle', {
      idle: { on: { GO: 'next' }, onExit },
      next: { on: {}, onEnter },
    });

    machine.send('GO');

    expect(onExit).toHaveBeenCalled();
    expect(onEnter).toHaveBeenCalled();
  });
});
```

## Quand utiliser

- Comportement depend de l'etat
- Nombreux etats avec transitions complexes
- Logique conditionnelle sur l'etat
- Workflow ou processus metier

## Patterns lies

- **Strategy** : Change d'algorithme (explicite) vs comportement (implicite)
- **Flyweight** : Partager les instances de State
- **Singleton** : States sans donnees peuvent etre singletons

## Sources

- [Refactoring Guru - State](https://refactoring.guru/design-patterns/state)
- [XState](https://xstate.js.org/)
