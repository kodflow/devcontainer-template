# Observer Pattern

> Definir une dependance un-a-plusieurs entre objets pour notifier les changements.

## Intention

Definir un mecanisme de souscription pour notifier plusieurs objets de tout
changement d'etat de l'objet qu'ils observent.

## Structure classique

```typescript
// 1. Interface Observer
interface Observer<T> {
  update(data: T): void;
}

// 2. Interface Subject
interface Subject<T> {
  subscribe(observer: Observer<T>): void;
  unsubscribe(observer: Observer<T>): void;
  notify(data: T): void;
}

// 3. Concrete Subject
class EventEmitter<T> implements Subject<T> {
  private observers: Set<Observer<T>> = new Set();

  subscribe(observer: Observer<T>): void {
    this.observers.add(observer);
  }

  unsubscribe(observer: Observer<T>): void {
    this.observers.delete(observer);
  }

  notify(data: T): void {
    this.observers.forEach(observer => observer.update(data));
  }
}

// 4. Concrete Observer
class PriceDisplay implements Observer<number> {
  constructor(private name: string) {}

  update(price: number): void {
    console.log(`${this.name}: Price updated to $${price}`);
  }
}

// 5. Observable avec etat
class Stock extends EventEmitter<number> {
  private _price: number = 0;

  get price(): number {
    return this._price;
  }

  set price(value: number) {
    this._price = value;
    this.notify(value);
  }
}

// Usage
const apple = new Stock();
const display1 = new PriceDisplay('Terminal 1');
const display2 = new PriceDisplay('Terminal 2');

apple.subscribe(display1);
apple.subscribe(display2);
apple.price = 150; // Les deux displays sont notifies
```

## Event Emitter moderne (TypeScript)

```typescript
type EventMap = Record<string, unknown>;
type EventCallback<T> = (data: T) => void;

class TypedEventEmitter<Events extends EventMap> {
  private listeners = new Map<keyof Events, Set<EventCallback<unknown>>>();

  on<K extends keyof Events>(
    event: K,
    callback: EventCallback<Events[K]>,
  ): () => void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(callback as EventCallback<unknown>);

    // Retourne fonction de desinscription
    return () => this.off(event, callback);
  }

  off<K extends keyof Events>(
    event: K,
    callback: EventCallback<Events[K]>,
  ): void {
    this.listeners.get(event)?.delete(callback as EventCallback<unknown>);
  }

  emit<K extends keyof Events>(event: K, data: Events[K]): void {
    this.listeners.get(event)?.forEach(callback => callback(data));
  }

  once<K extends keyof Events>(
    event: K,
    callback: EventCallback<Events[K]>,
  ): () => void {
    const wrapper: EventCallback<Events[K]> = data => {
      this.off(event, wrapper);
      callback(data);
    };
    return this.on(event, wrapper);
  }
}

// Usage avec types
interface UserEvents {
  login: { userId: string; timestamp: Date };
  logout: { userId: string };
  'profile:update': { userId: string; changes: Partial<User> };
}

const userEvents = new TypedEventEmitter<UserEvents>();

// TypeScript verifie les types
userEvents.on('login', ({ userId, timestamp }) => {
  console.log(`User ${userId} logged in at ${timestamp}`);
});

userEvents.emit('login', {
  userId: '123',
  timestamp: new Date(),
});
```

## Observable (RxJS-like)

```typescript
type Subscriber<T> = {
  next: (value: T) => void;
  error?: (err: Error) => void;
  complete?: () => void;
};

type Unsubscribe = () => void;

class Observable<T> {
  constructor(
    private producer: (subscriber: Subscriber<T>) => Unsubscribe | void,
  ) {}

  subscribe(subscriber: Subscriber<T>): Unsubscribe {
    const cleanup = this.producer(subscriber);
    return cleanup ?? (() => {});
  }

  // Operateurs
  map<R>(fn: (value: T) => R): Observable<R> {
    return new Observable(subscriber => {
      return this.subscribe({
        next: value => subscriber.next(fn(value)),
        error: subscriber.error,
        complete: subscriber.complete,
      });
    });
  }

  filter(predicate: (value: T) => boolean): Observable<T> {
    return new Observable(subscriber => {
      return this.subscribe({
        next: value => {
          if (predicate(value)) subscriber.next(value);
        },
        error: subscriber.error,
        complete: subscriber.complete,
      });
    });
  }

  debounce(ms: number): Observable<T> {
    return new Observable(subscriber => {
      let timeoutId: NodeJS.Timeout;

      const unsubscribe = this.subscribe({
        next: value => {
          clearTimeout(timeoutId);
          timeoutId = setTimeout(() => subscriber.next(value), ms);
        },
        error: subscriber.error,
        complete: subscriber.complete,
      });

      return () => {
        clearTimeout(timeoutId);
        unsubscribe();
      };
    });
  }
}

// Factory functions
function fromEvent<T>(
  element: EventTarget,
  eventName: string,
): Observable<T> {
  return new Observable(subscriber => {
    const handler = (event: Event) => subscriber.next(event as unknown as T);
    element.addEventListener(eventName, handler);
    return () => element.removeEventListener(eventName, handler);
  });
}

function interval(ms: number): Observable<number> {
  return new Observable(subscriber => {
    let count = 0;
    const id = setInterval(() => subscriber.next(count++), ms);
    return () => clearInterval(id);
  });
}

// Usage
const clicks = fromEvent<MouseEvent>(document, 'click')
  .map(e => ({ x: e.clientX, y: e.clientY }))
  .filter(pos => pos.x > 100)
  .debounce(300);

const unsubscribe = clicks.subscribe({
  next: pos => console.log(`Clicked at ${pos.x}, ${pos.y}`),
});
```

## PubSub (decouple)

```typescript
class PubSub {
  private static channels = new Map<string, Set<Function>>();

  static subscribe<T>(channel: string, callback: (data: T) => void): () => void {
    if (!this.channels.has(channel)) {
      this.channels.set(channel, new Set());
    }
    this.channels.get(channel)!.add(callback);

    return () => this.unsubscribe(channel, callback);
  }

  static unsubscribe(channel: string, callback: Function): void {
    this.channels.get(channel)?.delete(callback);
  }

  static publish<T>(channel: string, data: T): void {
    this.channels.get(channel)?.forEach(callback => callback(data));
  }

  static clear(channel?: string): void {
    if (channel) {
      this.channels.delete(channel);
    } else {
      this.channels.clear();
    }
  }
}

// Usage - composants decouple
// Component A
PubSub.publish('user:updated', { id: '123', name: 'John' });

// Component B (ne connait pas A)
PubSub.subscribe('user:updated', (user) => {
  console.log('User updated:', user);
});
```

## Anti-patterns

```typescript
// MAUVAIS: Observer qui modifie le subject
class BadObserver implements Observer<number> {
  constructor(private stock: Stock) {}

  update(price: number): void {
    if (price > 100) {
      this.stock.price = 100; // Boucle infinie potentielle!
    }
  }
}

// MAUVAIS: Memory leak - oublier unsubscribe
class LeakyComponent {
  constructor(emitter: EventEmitter<string>) {
    emitter.subscribe(this); // Jamais unsubscribe = fuite memoire
  }
}

// MAUVAIS: Ordre de notification important
class OrderDependentObserver {
  update(data: unknown): void {
    // Depend d'un autre observer execute avant
    // L'ordre n'est pas garanti!
  }
}

// MAUVAIS: Observer synchrone bloquant
class SlowObserver implements Observer<unknown> {
  update(data: unknown): void {
    // Bloque tous les autres observers
    heavyComputation(); // 5 secondes...
  }
}
```

## Tests unitaires

```typescript
import { describe, it, expect, vi } from 'vitest';

describe('EventEmitter', () => {
  it('should notify all subscribers', () => {
    const emitter = new EventEmitter<string>();
    const callback1 = vi.fn();
    const callback2 = vi.fn();

    emitter.subscribe({ update: callback1 });
    emitter.subscribe({ update: callback2 });
    emitter.notify('hello');

    expect(callback1).toHaveBeenCalledWith('hello');
    expect(callback2).toHaveBeenCalledWith('hello');
  });

  it('should allow unsubscribe', () => {
    const emitter = new EventEmitter<string>();
    const callback = vi.fn();
    const observer = { update: callback };

    emitter.subscribe(observer);
    emitter.unsubscribe(observer);
    emitter.notify('hello');

    expect(callback).not.toHaveBeenCalled();
  });
});

describe('TypedEventEmitter', () => {
  it('should handle typed events', () => {
    interface Events {
      message: string;
      count: number;
    }
    const emitter = new TypedEventEmitter<Events>();
    const callback = vi.fn();

    emitter.on('message', callback);
    emitter.emit('message', 'hello');

    expect(callback).toHaveBeenCalledWith('hello');
  });

  it('should return unsubscribe function', () => {
    const emitter = new TypedEventEmitter<{ test: string }>();
    const callback = vi.fn();

    const unsubscribe = emitter.on('test', callback);
    unsubscribe();
    emitter.emit('test', 'data');

    expect(callback).not.toHaveBeenCalled();
  });

  it('should support once', () => {
    const emitter = new TypedEventEmitter<{ test: string }>();
    const callback = vi.fn();

    emitter.once('test', callback);
    emitter.emit('test', 'first');
    emitter.emit('test', 'second');

    expect(callback).toHaveBeenCalledTimes(1);
    expect(callback).toHaveBeenCalledWith('first');
  });
});

describe('Observable', () => {
  it('should support map operator', () => {
    const results: number[] = [];

    const source = new Observable<number>(subscriber => {
      subscriber.next(1);
      subscriber.next(2);
      subscriber.next(3);
    });

    source.map(x => x * 2).subscribe({
      next: value => results.push(value),
    });

    expect(results).toEqual([2, 4, 6]);
  });

  it('should support filter operator', () => {
    const results: number[] = [];

    const source = new Observable<number>(subscriber => {
      [1, 2, 3, 4, 5].forEach(n => subscriber.next(n));
    });

    source.filter(x => x % 2 === 0).subscribe({
      next: value => results.push(value),
    });

    expect(results).toEqual([2, 4]);
  });
});
```

## Quand utiliser

- Systemes d'evenements
- UI reactive (etat -> vue)
- Notifications en temps reel
- Decouplage entre modules

## Patterns lies

- **Mediator** : Centralise la communication
- **Event Sourcing** : Stocke les evenements
- **CQRS** : Separe lecture/ecriture avec events

## Sources

- [Refactoring Guru - Observer](https://refactoring.guru/design-patterns/observer)
- [ReactiveX](https://reactivex.io/)
