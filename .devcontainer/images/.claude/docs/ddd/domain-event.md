# Domain Event Pattern

## Definition

A **Domain Event** captures something significant that happened in the domain. It represents a fact - an immutable record of a past occurrence that domain experts care about.

```
Domain Event = Past Tense + Immutable + Business Significance + Timestamp
```

**Key characteristics:**

- **Past tense naming**: `OrderConfirmed`, not `ConfirmOrder`
- **Immutable**: Once created, never modified
- **Contains all context**: Self-sufficient information
- **Business-relevant**: Named in ubiquitous language
- **Decoupling mechanism**: Enables loose coupling between aggregates

## TypeScript Implementation

```typescript
// Base Domain Event
abstract class DomainEvent {
  readonly occurredAt: Date;
  readonly eventId: string;

  constructor() {
    this.occurredAt = new Date();
    this.eventId = crypto.randomUUID();
  }

  abstract get eventType(): string;
}

// Concrete Domain Events
class OrderCreatedEvent extends DomainEvent {
  readonly eventType = 'OrderCreated';

  constructor(
    readonly orderId: OrderId,
    readonly customerId: CustomerId,
    readonly items: ReadonlyArray<{ productId: string; quantity: number }>,
    readonly totalAmount: Money
  ) {
    super();
  }
}

class OrderConfirmedEvent extends DomainEvent {
  readonly eventType = 'OrderConfirmed';

  constructor(
    readonly orderId: OrderId,
    readonly confirmedAt: Date,
    readonly expectedDeliveryDate: Date
  ) {
    super();
  }
}

class OrderShippedEvent extends DomainEvent {
  readonly eventType = 'OrderShipped';

  constructor(
    readonly orderId: OrderId,
    readonly trackingNumber: string,
    readonly carrier: string,
    readonly shippedAt: Date
  ) {
    super();
  }
}

class PaymentReceivedEvent extends DomainEvent {
  readonly eventType = 'PaymentReceived';

  constructor(
    readonly orderId: OrderId,
    readonly paymentId: PaymentId,
    readonly amount: Money,
    readonly paymentMethod: PaymentMethod
  ) {
    super();
  }
}

// Aggregate raising events
class Order extends AggregateRoot<OrderId> {
  private _domainEvents: DomainEvent[] = [];

  static create(
    customerId: CustomerId,
    items: OrderItem[],
    shippingAddress: Address
  ): Result<Order, ValidationError> {
    const order = new Order(OrderId.generate(), customerId, items, shippingAddress);

    // Raise creation event
    order.addDomainEvent(new OrderCreatedEvent(
      order.id,
      customerId,
      items.map(i => ({ productId: i.productId.value, quantity: i.quantity.value })),
      order.totalAmount
    ));

    return Result.ok(order);
  }

  confirm(): Result<void, DomainError> {
    if (this._status !== OrderStatus.Pending) {
      return Result.fail(new DomainError('Order cannot be confirmed'));
    }

    this._status = OrderStatus.Confirmed;
    this._confirmedAt = new Date();

    // Raise confirmation event
    this.addDomainEvent(new OrderConfirmedEvent(
      this.id,
      this._confirmedAt,
      this.calculateExpectedDelivery()
    ));

    return Result.ok(undefined);
  }

  protected addDomainEvent(event: DomainEvent): void {
    this._domainEvents.push(event);
  }

  pullDomainEvents(): DomainEvent[] {
    const events = [...this._domainEvents];
    this._domainEvents = [];
    return events;
  }
}
```

## Event Handlers

```typescript
// Event Handler Interface
interface DomainEventHandler<T extends DomainEvent> {
  handle(event: T): Promise<void>;
}

// Concrete Handlers
class OrderConfirmedHandler implements DomainEventHandler<OrderConfirmedEvent> {
  constructor(
    private readonly inventoryService: InventoryService,
    private readonly notificationService: NotificationService
  ) {}

  async handle(event: OrderConfirmedEvent): Promise<void> {
    // Reserve inventory
    await this.inventoryService.reserveForOrder(event.orderId);

    // Send confirmation email
    await this.notificationService.sendOrderConfirmation(event.orderId);
  }
}

class PaymentReceivedHandler implements DomainEventHandler<PaymentReceivedEvent> {
  constructor(
    private readonly orderRepository: OrderRepository,
    private readonly invoiceService: InvoiceService
  ) {}

  async handle(event: PaymentReceivedEvent): Promise<void> {
    const order = await this.orderRepository.findById(event.orderId);
    if (!order) return;

    order.markAsPaid(event.paymentId);
    await this.orderRepository.save(order);

    // Generate invoice
    await this.invoiceService.generate(event.orderId, event.paymentId);
  }
}

// Event Bus / Dispatcher
class EventBus {
  private handlers: Map<string, DomainEventHandler<DomainEvent>[]> = new Map();

  subscribe<T extends DomainEvent>(
    eventType: string,
    handler: DomainEventHandler<T>
  ): void {
    const existing = this.handlers.get(eventType) ?? [];
    this.handlers.set(eventType, [...existing, handler as DomainEventHandler<DomainEvent>]);
  }

  async publish(event: DomainEvent): Promise<void> {
    const handlers = this.handlers.get(event.eventType) ?? [];

    await Promise.all(
      handlers.map(handler => handler.handle(event))
    );
  }

  async publishAll(events: DomainEvent[]): Promise<void> {
    for (const event of events) {
      await this.publish(event);
    }
  }
}
```

## Event Sourcing Integration

```typescript
// Event Store Interface
interface EventStore {
  append(aggregateId: string, events: DomainEvent[]): Promise<void>;
  getEvents(aggregateId: string): Promise<DomainEvent[]>;
  getEventsAfter(aggregateId: string, version: number): Promise<DomainEvent[]>;
}

// Event-Sourced Aggregate
abstract class EventSourcedAggregate<TId> extends AggregateRoot<TId> {
  private _version: number = 0;
  private _uncommittedEvents: DomainEvent[] = [];

  protected apply(event: DomainEvent): void {
    this.when(event);
    this._uncommittedEvents.push(event);
  }

  // Subclass implements state transitions
  protected abstract when(event: DomainEvent): void;

  // Reconstitute from event history
  static loadFromHistory<T extends EventSourcedAggregate<any>>(
    events: DomainEvent[]
  ): T {
    const aggregate = this.createEmpty() as T;

    for (const event of events) {
      aggregate.when(event);
      aggregate._version++;
    }

    return aggregate;
  }

  getUncommittedEvents(): DomainEvent[] {
    return [...this._uncommittedEvents];
  }

  markEventsAsCommitted(): void {
    this._uncommittedEvents = [];
  }
}

// Event-Sourced Order
class Order extends EventSourcedAggregate<OrderId> {
  private _customerId!: CustomerId;
  private _status!: OrderStatus;
  private _items: OrderItem[] = [];

  protected when(event: DomainEvent): void {
    switch (event.eventType) {
      case 'OrderCreated':
        this.whenOrderCreated(event as OrderCreatedEvent);
        break;
      case 'OrderConfirmed':
        this.whenOrderConfirmed(event as OrderConfirmedEvent);
        break;
      case 'OrderShipped':
        this.whenOrderShipped(event as OrderShippedEvent);
        break;
    }
  }

  private whenOrderCreated(event: OrderCreatedEvent): void {
    this._id = event.orderId;
    this._customerId = event.customerId;
    this._status = OrderStatus.Pending;
  }

  private whenOrderConfirmed(event: OrderConfirmedEvent): void {
    this._status = OrderStatus.Confirmed;
  }

  private whenOrderShipped(event: OrderShippedEvent): void {
    this._status = OrderStatus.Shipped;
  }
}
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **@nestjs/cqrs** | CQRS/Events | `npm i @nestjs/cqrs` |
| **eventstore-db** | Event Store | `npm i @eventstore/db-client` |
| **RabbitMQ** | Event messaging | `npm i amqplib` |
| **Effect** | FP event handling | `npm i effect` |

## Anti-patterns

1. **Technical Events**: Events about infrastructure, not domain

   ```typescript
   // BAD - Technical concern
   class DatabaseUpdatedEvent extends DomainEvent { }

   // GOOD - Business meaning
   class OrderPlacedEvent extends DomainEvent { }
   ```

2. **Mutable Events**: Modifying events after creation

   ```typescript
   // BAD
   event.orderId = newOrderId; // Mutation!

   // GOOD
   readonly orderId: OrderId; // Immutable
   ```

3. **Missing Context**: Event without enough information

   ```typescript
   // BAD - Not self-sufficient
   class OrderCreatedEvent {
     constructor(readonly orderId: OrderId) { }
   }

   // GOOD - Contains all needed context
   class OrderCreatedEvent {
     constructor(
       readonly orderId: OrderId,
       readonly customerId: CustomerId,
       readonly items: OrderItemSnapshot[],
       readonly totalAmount: Money
     ) { }
   }
   ```

4. **Coupling via Events**: Handler knowing too much about producer

   ```typescript
   // BAD - Tight coupling
   class OrderHandler {
     handle(event: OrderCreatedEvent) {
       const order = this.orderRepo.findById(event.orderId); // Fetching more data
     }
   }
   ```

## When to Use

- Communicate between aggregates
- Trigger side effects after state changes
- Build audit trails
- Implement eventual consistency
- Enable event sourcing

## See Also

- [Aggregate](./aggregate.md) - Raises domain events
- [Repository](./repository.md) - Publishes events after save
- [Domain Service](./domain-service.md) - Can handle events
