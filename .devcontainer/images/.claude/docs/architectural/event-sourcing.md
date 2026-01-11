# Event Sourcing

> Persister l'état comme une séquence d'événements au lieu d'un snapshot.

**Auteur :** Martin Fowler, Greg Young

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRADITIONAL vs EVENT SOURCING                 │
│                                                                  │
│  TRADITIONAL (CRUD)              EVENT SOURCING                 │
│  ┌─────────────────┐            ┌─────────────────────────────┐ │
│  │  Current State  │            │       Event Stream           │ │
│  │                 │            │                              │ │
│  │  Balance: $100  │            │  [AccountCreated: $0]       │ │
│  │                 │            │  [MoneyDeposited: +$150]    │ │
│  │  (only latest)  │            │  [MoneyWithdrawn: -$50]     │ │
│  │                 │            │  [MoneyDeposited: +$20]     │ │
│  │                 │            │  [MoneyWithdrawn: -$20]     │ │
│  └─────────────────┘            │                              │ │
│                                 │  → Replay = Balance: $100   │ │
│  Pas d'historique               └─────────────────────────────┘ │
│                                  Historique complet             │
└─────────────────────────────────────────────────────────────────┘
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      EVENT SOURCING SYSTEM                       │
│                                                                  │
│  ┌──────────┐    ┌──────────────┐    ┌──────────────────────┐  │
│  │ Command  │───▶│   Aggregate  │───▶│    Event Store       │  │
│  │          │    │              │    │                      │  │
│  │CreateOrder    │  Order       │    │  ┌────────────────┐  │  │
│  └──────────┘    │  ├─validate()│    │  │ OrderCreated   │  │  │
│                  │  └─apply()   │    │  │ ItemAdded      │  │  │
│                  └──────────────┘    │  │ ItemRemoved    │  │  │
│                                      │  │ OrderShipped   │  │  │
│                                      │  └────────────────┘  │  │
│                                      └──────────────────────┘  │
│                                               │                 │
│                                               │ Project         │
│                                               ▼                 │
│                                      ┌──────────────────────┐  │
│                                      │    Projections       │  │
│                                      │  ┌────────────────┐  │  │
│                                      │  │ OrderView (SQL)│  │  │
│                                      │  │ OrderSearch    │  │  │
│                                      │  │ (Elastic)      │  │  │
│                                      │  │ Analytics      │  │  │
│                                      │  └────────────────┘  │  │
│                                      └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Implémentation

### Événements

```typescript
// Base event interface
interface DomainEvent {
  id: string;
  aggregateId: string;
  aggregateType: string;
  version: number;
  timestamp: Date;
  payload: unknown;
}

// Événements du domaine Order
interface OrderCreatedEvent extends DomainEvent {
  type: 'OrderCreated';
  payload: {
    customerId: string;
    items: OrderItem[];
  };
}

interface ItemAddedEvent extends DomainEvent {
  type: 'ItemAdded';
  payload: {
    productId: string;
    quantity: number;
    price: number;
  };
}

interface OrderShippedEvent extends DomainEvent {
  type: 'OrderShipped';
  payload: {
    trackingNumber: string;
    carrier: string;
  };
}

type OrderEvent = OrderCreatedEvent | ItemAddedEvent | OrderShippedEvent;
```

### Aggregate

```typescript
class Order {
  private id: string;
  private customerId: string;
  private items: OrderItem[] = [];
  private status: OrderStatus = 'pending';
  private version: number = 0;

  // Événements non commitésprivate uncommittedEvents: OrderEvent[] = [];

  // Reconstruit l'état depuis les événements
  static fromEvents(events: OrderEvent[]): Order {
    const order = new Order();
    for (const event of events) {
      order.apply(event);
      order.version = event.version;
    }
    return order;
  }

  // Commandes métier
  addItem(productId: string, quantity: number, price: number): void {
    if (this.status !== 'pending') {
      throw new Error('Cannot add items to shipped order');
    }

    const event: ItemAddedEvent = {
      id: generateId(),
      aggregateId: this.id,
      aggregateType: 'Order',
      type: 'ItemAdded',
      version: this.version + 1,
      timestamp: new Date(),
      payload: { productId, quantity, price },
    };

    this.apply(event);
    this.uncommittedEvents.push(event);
  }

  ship(trackingNumber: string, carrier: string): void {
    if (this.status !== 'pending') {
      throw new Error('Order already shipped');
    }

    const event: OrderShippedEvent = {
      id: generateId(),
      aggregateId: this.id,
      aggregateType: 'Order',
      type: 'OrderShipped',
      version: this.version + 1,
      timestamp: new Date(),
      payload: { trackingNumber, carrier },
    };

    this.apply(event);
    this.uncommittedEvents.push(event);
  }

  // Applique un événement (modifie l'état)
  private apply(event: OrderEvent): void {
    switch (event.type) {
      case 'OrderCreated':
        this.id = event.aggregateId;
        this.customerId = event.payload.customerId;
        this.items = event.payload.items;
        break;

      case 'ItemAdded':
        this.items.push({
          productId: event.payload.productId,
          quantity: event.payload.quantity,
          price: event.payload.price,
        });
        break;

      case 'OrderShipped':
        this.status = 'shipped';
        break;
    }
    this.version = event.version;
  }

  getUncommittedEvents(): OrderEvent[] {
    return [...this.uncommittedEvents];
  }

  markEventsAsCommitted(): void {
    this.uncommittedEvents = [];
  }
}
```

### Event Store

```typescript
interface EventStore {
  append(events: DomainEvent[]): Promise<void>;
  getEvents(aggregateId: string): Promise<DomainEvent[]>;
  getEventsAfter(position: number): Promise<DomainEvent[]>;
  subscribe(handler: (event: DomainEvent) => void): void;
}

class PostgresEventStore implements EventStore {
  async append(events: DomainEvent[]): Promise<void> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      for (const event of events) {
        // Optimistic concurrency via version
        const result = await client.query(`
          INSERT INTO events (
            id, aggregate_id, aggregate_type, type, version, timestamp, payload
          ) VALUES ($1, $2, $3, $4, $5, $6, $7)
          ON CONFLICT (aggregate_id, version) DO NOTHING
          RETURNING id
        `, [
          event.id,
          event.aggregateId,
          event.aggregateType,
          event.type,
          event.version,
          event.timestamp,
          JSON.stringify(event.payload),
        ]);

        if (result.rowCount === 0) {
          throw new ConcurrencyError('Version conflict');
        }
      }

      await client.query('COMMIT');
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  async getEvents(aggregateId: string): Promise<DomainEvent[]> {
    const result = await this.pool.query(`
      SELECT * FROM events
      WHERE aggregate_id = $1
      ORDER BY version ASC
    `, [aggregateId]);

    return result.rows.map(this.rowToEvent);
  }
}
```

### Projections

```typescript
class OrderProjection {
  constructor(
    private eventStore: EventStore,
    private readDb: Database
  ) {
    eventStore.subscribe(event => this.handle(event));
  }

  private async handle(event: DomainEvent): Promise<void> {
    switch (event.type) {
      case 'OrderCreated':
        await this.readDb.orders.insert({
          id: event.aggregateId,
          customerId: event.payload.customerId,
          status: 'pending',
          totalAmount: 0,
          createdAt: event.timestamp,
        });
        break;

      case 'ItemAdded':
        await this.readDb.orderItems.insert({
          orderId: event.aggregateId,
          productId: event.payload.productId,
          quantity: event.payload.quantity,
          price: event.payload.price,
        });
        // Update total
        await this.readDb.orders.updateTotal(event.aggregateId);
        break;

      case 'OrderShipped':
        await this.readDb.orders.update(event.aggregateId, {
          status: 'shipped',
          shippedAt: event.timestamp,
        });
        break;
    }
  }

  // Rebuild projection from scratch
  async rebuild(): Promise<void> {
    await this.readDb.orders.truncate();
    const events = await this.eventStore.getEventsAfter(0);
    for (const event of events) {
      await this.handle(event);
    }
  }
}
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Audit trail requis | CRUD simple |
| Compliance (finance, santé) | Pas de besoin historique |
| Debug / Replay | Équipe inexpérimentée |
| Analytics temporelles | Performance critique |
| Undo/Redo nécessaire | Volume énorme |

## Avantages

- **Audit complet** : Chaque changement tracé
- **Replay** : Reconstruire état à tout moment
- **Debug** : Comprendre ce qui s'est passé
- **Projections multiples** : Vues optimisées
- **Temporal queries** : "État à date X ?"
- **Event-driven** : Réagir aux changements

## Inconvénients

- **Complexité** : Pattern avancé
- **Volume** : Beaucoup d'événements
- **Schéma évolution** : Événements immuables
- **Eventual consistency** : Projections asynchrones
- **Courbe d'apprentissage** : Paradigme différent

## Exemples réels

| Entreprise | Usage |
|------------|-------|
| **LMAX** | Trading (millions events/sec) |
| **Microsoft** | Azure (Event Grid) |
| **LinkedIn** | Kafka (event backbone) |
| **Netflix** | Zuul (request events) |
| **Uber** | Trip events |

## Migration path

### Depuis CRUD

```
Phase 1: Dual-write (CRUD + Events)
Phase 2: Event-first (CRUD from projection)
Phase 3: Pure Event Sourcing
```

### Patterns complémentaires

```
Event Sourcing + CQRS
         │
         ├── Commands → Write side → Events
         │
         └── Queries → Read side ← Projections
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| CQRS | Souvent combiné |
| Saga | Transactions distribuées |
| Event-Driven | Architecture sous-jacente |
| Snapshot | Optimisation performance |

## Sources

- [Martin Fowler - Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)
- [Greg Young - Event Sourcing](https://cqrs.files.wordpress.com/2010/11/cqrs_documents.pdf)
- [EventStoreDB](https://www.eventstore.com/)
- [Axon Framework](https://axoniq.io/)
