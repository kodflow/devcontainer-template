# Actor Model

Pattern de concurrence base sur des entites isolees communiquant par messages.

---

## Qu'est-ce que l'Actor Model ?

> Chaque actor est une unite independante avec son etat prive, traitant les messages sequentiellement.

```
+--------------------------------------------------------------+
|                       Actor Model                             |
|                                                               |
|  +------------------+         +------------------+            |
|  |    Actor A       |         |    Actor B       |            |
|  |------------------|         |------------------|            |
|  | State (private)  |         | State (private)  |            |
|  | +-------------+  |         | +-------------+  |            |
|  | | count: 42   |  |         | | items: []   |  |            |
|  | +-------------+  |         | +-------------+  |            |
|  |                  |         |                  |            |
|  | Mailbox:         |         | Mailbox:         |            |
|  | [msg1][msg2][..] |         | [msgX][msgY]     |            |
|  +--------+---------+         +---------+--------+            |
|           |                             |                     |
|           |        send(message)        |                     |
|           +---------------------------->|                     |
|           |                             |                     |
|           |<----------------------------+                     |
|                    reply(result)                              |
|                                                               |
|  Garanties:                                                   |
|  - Pas de shared state                                        |
|  - Messages traites un par un                                 |
|  - Communication asynchrone                                   |
+--------------------------------------------------------------+
```

**Pourquoi :**

- Elimine les race conditions (pas de shared state)
- Scalabilite naturelle (actors distribues)
- Fault tolerance (supervision)

---

## Implementation TypeScript

### Actor de base

```typescript
type Message = {
  type: string;
  payload?: unknown;
  replyTo?: (response: unknown) => void;
};

abstract class Actor {
  private mailbox: Message[] = [];
  private processing = false;

  protected abstract receive(message: Message): Promise<void>;

  send(message: Message): void {
    this.mailbox.push(message);
    this.processMailbox();
  }

  async ask<T>(type: string, payload?: unknown): Promise<T> {
    return new Promise((resolve) => {
      this.send({
        type,
        payload,
        replyTo: (response) => resolve(response as T),
      });
    });
  }

  private async processMailbox(): Promise<void> {
    if (this.processing) return;
    this.processing = true;

    while (this.mailbox.length > 0) {
      const message = this.mailbox.shift()!;
      try {
        await this.receive(message);
      } catch (error) {
        console.error('Actor error:', error);
        // Supervision strategy here
      }
    }

    this.processing = false;
  }
}
```

### Exemple: Counter Actor

```typescript
class CounterActor extends Actor {
  private count = 0;

  protected async receive(message: Message): Promise<void> {
    switch (message.type) {
      case 'increment':
        this.count += (message.payload as number) || 1;
        break;

      case 'decrement':
        this.count -= (message.payload as number) || 1;
        break;

      case 'get':
        message.replyTo?.(this.count);
        break;

      case 'reset':
        this.count = 0;
        break;
    }
  }
}

// Usage
const counter = new CounterActor();

counter.send({ type: 'increment', payload: 5 });
counter.send({ type: 'increment', payload: 3 });
counter.send({ type: 'decrement', payload: 2 });

const value = await counter.ask<number>('get');
console.log(value); // 6
```

---

## Actor System

```typescript
class ActorSystem {
  private actors = new Map<string, Actor>();

  register(name: string, actor: Actor): void {
    this.actors.set(name, actor);
  }

  lookup(name: string): Actor | undefined {
    return this.actors.get(name);
  }

  send(actorName: string, message: Message): void {
    const actor = this.actors.get(actorName);
    if (actor) {
      actor.send(message);
    } else {
      console.error(`Actor not found: ${actorName}`);
    }
  }

  async ask<T>(actorName: string, type: string, payload?: unknown): Promise<T> {
    const actor = this.actors.get(actorName);
    if (!actor) {
      throw new Error(`Actor not found: ${actorName}`);
    }
    return actor.ask<T>(type, payload);
  }
}

// Usage
const system = new ActorSystem();
system.register('counter', new CounterActor());
system.register('user-service', new UserServiceActor());

system.send('counter', { type: 'increment', payload: 10 });
```

---

## Supervision (Fault Tolerance)

```typescript
type SupervisionStrategy = 'restart' | 'stop' | 'escalate';

class SupervisedActor extends Actor {
  private children = new Map<string, SupervisedActor>();
  protected strategy: SupervisionStrategy = 'restart';

  protected spawn(name: string, actor: SupervisedActor): void {
    actor.parent = this;
    this.children.set(name, actor);
  }

  private parent?: SupervisedActor;

  protected onChildFailure(
    childName: string,
    error: Error,
  ): SupervisionStrategy {
    console.error(`Child ${childName} failed:`, error);
    return this.strategy;
  }

  private handleChildError(childName: string, error: Error): void {
    const decision = this.onChildFailure(childName, error);

    switch (decision) {
      case 'restart':
        const child = this.children.get(childName);
        if (child) {
          // Reset state, keep mailbox
          child.restart();
        }
        break;

      case 'stop':
        this.children.delete(childName);
        break;

      case 'escalate':
        if (this.parent) {
          // Propager l'erreur au parent
          throw error;
        }
        break;
    }
  }

  protected restart(): void {
    // Override pour reset l'etat
  }
}
```

---

## Typed Actors (meilleure type-safety)

```typescript
type MessageHandlers<TState> = {
  [K: string]: (state: TState, payload: unknown) => TState | Promise<TState>;
};

function createTypedActor<TState, THandlers extends MessageHandlers<TState>>(
  initialState: TState,
  handlers: THandlers,
) {
  let state = initialState;
  const mailbox: Array<{ type: keyof THandlers; payload: unknown }> = [];
  let processing = false;

  const processMailbox = async () => {
    if (processing) return;
    processing = true;

    while (mailbox.length > 0) {
      const { type, payload } = mailbox.shift()!;
      const handler = handlers[type as string];
      if (handler) {
        state = await handler(state, payload);
      }
    }

    processing = false;
  };

  return {
    send<K extends keyof THandlers>(
      type: K,
      payload: Parameters<THandlers[K]>[1],
    ): void {
      mailbox.push({ type, payload });
      processMailbox();
    },

    getState(): TState {
      return state;
    },
  };
}

// Usage avec types
const counterActor = createTypedActor(
  { count: 0 },
  {
    increment: (state, amount: number) => ({
      count: state.count + amount,
    }),
    decrement: (state, amount: number) => ({
      count: state.count - amount,
    }),
  },
);

counterActor.send('increment', 5);
counterActor.send('decrement', 2);
```

---

## Complexite et Trade-offs

| Aspect | Valeur |
|--------|--------|
| Envoi message | O(1) |
| Traitement | Sequentiel par actor |
| Memoire | O(actors * mailbox_size) |

### Avantages

- Pas de locks / race conditions
- Isolation des erreurs
- Scalabilite horizontale
- Modele mental simple

### Inconvenients

- Overhead messages vs appels directs
- Debugging plus complexe
- Latence (asynchrone)
- Mailbox peut deborder

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Etat partage concurrent | Oui |
| Systemes distribues | Oui |
| Haute resilience requise | Oui |
| Latence minimale critique | Non |
| Logique simple sans concurrence | Non |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Message Queue** | Infrastructure de messaging |
| **Event Sourcing** | Actors peuvent logger messages |
| **CQRS** | Actors pour read/write |
| **Saga** | Orchestration via actors |

---

## Sources

- [Akka Documentation](https://akka.io/docs/)
- [Actor Model - Wikipedia](https://en.wikipedia.org/wiki/Actor_model)
- [Microsoft Orleans](https://docs.microsoft.com/en-us/dotnet/orleans/)
- [Erlang/OTP](https://www.erlang.org/)
