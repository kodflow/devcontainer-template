# Aggregate Pattern

## Definition

An **Aggregate** is a cluster of domain objects (Entities and Value Objects) treated as a single unit for data changes. It has a root Entity (Aggregate Root) that controls access and maintains invariants across the cluster.

```
Aggregate = Root Entity + Child Entities + Value Objects + Invariants + Consistency Boundary
```

**Key characteristics:**
- **Aggregate Root**: Single entry point for all modifications
- **Consistency Boundary**: Transactional consistency within aggregate
- **Invariants**: Business rules enforced across the cluster
- **Identity**: Referenced only by root's identity
- **Encapsulation**: Internal structure hidden from outside

## TypeScript Implementation

```typescript
// Aggregate Root base class
abstract class AggregateRoot<TId> extends Entity<TId> {
  private _domainEvents: DomainEvent[] = [];
  private _version: number = 0;

  protected constructor(id: TId) {
    super(id);
  }

  get version(): number {
    return this._version;
  }

  protected addDomainEvent(event: DomainEvent): void {
    this._domainEvents.push(event);
  }

  pullDomainEvents(): DomainEvent[] {
    const events = [...this._domainEvents];
    this._domainEvents = [];
    return events;
  }

  incrementVersion(): void {
    this._version++;
  }
}

// Order Aggregate - Complete example
class Order extends AggregateRoot<OrderId> {
  private _customerId: CustomerId;
  private _items: OrderItem[] = [];
  private _status: OrderStatus;
  private _shippingAddress: Address;
  private _createdAt: Date;

  private constructor(
    id: OrderId,
    customerId: CustomerId,
    shippingAddress: Address
  ) {
    super(id);
    this._customerId = customerId;
    this._shippingAddress = shippingAddress;
    this._status = OrderStatus.Draft;
    this._createdAt = new Date();
  }

  // Factory method
  static create(
    customerId: CustomerId,
    shippingAddress: Address
  ): Result<Order, ValidationError> {
    const id = OrderId.generate();
    const order = new Order(id, customerId, shippingAddress);

    order.addDomainEvent(new OrderCreatedEvent(id, customerId));

    return Result.ok(order);
  }

  // Business operation with invariant enforcement
  addItem(
    productId: ProductId,
    quantity: Quantity,
    unitPrice: Money
  ): Result<void, DomainError> {
    // Invariant: Cannot modify confirmed orders
    if (this._status !== OrderStatus.Draft) {
      return Result.fail(
        new DomainError('Cannot add items to a non-draft order')
      );
    }

    // Invariant: Maximum 10 items per order
    if (this._items.length >= 10) {
      return Result.fail(
        new DomainError('Order cannot have more than 10 items')
      );
    }

    // Check if item already exists
    const existingItem = this._items.find(i => i.productId.equals(productId));

    if (existingItem) {
      existingItem.increaseQuantity(quantity);
    } else {
      const itemResult = OrderItem.create(productId, quantity, unitPrice);
      if (itemResult.isFailure) {
        return Result.fail(itemResult.error);
      }
      this._items.push(itemResult.value);
    }

    this.addDomainEvent(new OrderItemAddedEvent(this.id, productId, quantity));

    return Result.ok(undefined);
  }

  removeItem(productId: ProductId): Result<void, DomainError> {
    if (this._status !== OrderStatus.Draft) {
      return Result.fail(
        new DomainError('Cannot remove items from a non-draft order')
      );
    }

    const index = this._items.findIndex(i => i.productId.equals(productId));
    if (index === -1) {
      return Result.fail(new DomainError('Item not found'));
    }

    this._items.splice(index, 1);
    this.addDomainEvent(new OrderItemRemovedEvent(this.id, productId));

    return Result.ok(undefined);
  }

  confirm(): Result<void, DomainError> {
    // Invariant: Order must have items
    if (this._items.length === 0) {
      return Result.fail(new DomainError('Cannot confirm empty order'));
    }

    // Invariant: Must be in Draft status
    if (this._status !== OrderStatus.Draft) {
      return Result.fail(new DomainError('Order already confirmed'));
    }

    this._status = OrderStatus.Confirmed;
    this.addDomainEvent(new OrderConfirmedEvent(this.id, this.totalAmount));

    return Result.ok(undefined);
  }

  cancel(reason: string): Result<void, DomainError> {
    if (this._status === OrderStatus.Shipped) {
      return Result.fail(new DomainError('Cannot cancel shipped order'));
    }

    this._status = OrderStatus.Cancelled;
    this.addDomainEvent(new OrderCancelledEvent(this.id, reason));

    return Result.ok(undefined);
  }

  // Computed properties
  get totalAmount(): Money {
    return this._items.reduce(
      (sum, item) => sum.add(item.subtotal).value!,
      Money.zero(Currency.USD)
    );
  }

  get itemCount(): number {
    return this._items.reduce((sum, item) => sum + item.quantity.value, 0);
  }

  // Read-only access to internal entities
  get items(): ReadonlyArray<OrderItem> {
    return [...this._items];
  }

  get status(): OrderStatus { return this._status; }
  get customerId(): CustomerId { return this._customerId; }
  get shippingAddress(): Address { return this._shippingAddress; }
}

// Child Entity - part of aggregate
class OrderItem extends Entity<OrderItemId> {
  private _productId: ProductId;
  private _quantity: Quantity;
  private _unitPrice: Money;

  private constructor(
    id: OrderItemId,
    productId: ProductId,
    quantity: Quantity,
    unitPrice: Money
  ) {
    super(id);
    this._productId = productId;
    this._quantity = quantity;
    this._unitPrice = unitPrice;
  }

  static create(
    productId: ProductId,
    quantity: Quantity,
    unitPrice: Money
  ): Result<OrderItem, ValidationError> {
    const id = OrderItemId.generate();
    return Result.ok(new OrderItem(id, productId, quantity, unitPrice));
  }

  // Only accessible through aggregate root
  increaseQuantity(additional: Quantity): void {
    this._quantity = this._quantity.add(additional);
  }

  get subtotal(): Money {
    return this._unitPrice.multiply(this._quantity.value).value!;
  }

  get productId(): ProductId { return this._productId; }
  get quantity(): Quantity { return this._quantity; }
  get unitPrice(): Money { return this._unitPrice; }
}
```

## Aggregate Design Rules

1. **Reference by Identity Only**: External aggregates reference only by root ID
2. **Modify One Aggregate Per Transaction**: Eventual consistency between aggregates
3. **Keep Aggregates Small**: Prefer smaller aggregates for concurrency
4. **Use Domain Events**: For cross-aggregate communication

```typescript
// Cross-aggregate reference - by ID only
class Order extends AggregateRoot<OrderId> {
  private _customerId: CustomerId; // Reference by ID, not Customer object

  // NOT this:
  // private _customer: Customer; // BAD - crosses aggregate boundary
}

// Cross-aggregate communication via events
class OrderConfirmedHandler implements DomainEventHandler<OrderConfirmedEvent> {
  constructor(private inventoryService: InventoryService) {}

  async handle(event: OrderConfirmedEvent): Promise<void> {
    // Update another aggregate based on event
    await this.inventoryService.reserveStock(event.orderId, event.items);
  }
}
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **@nestjs/cqrs** | Event sourcing | `npm i @nestjs/cqrs` |
| **eventstore-db** | Event store | `npm i @eventstore/db-client` |
| **uuid** | ID generation | `npm i uuid` |
| **Effect** | Functional aggregates | `npm i effect` |

## Anti-patterns

1. **God Aggregate**: Too many entities in one aggregate
   ```typescript
   // BAD - Too large, concurrency issues
   class Customer extends AggregateRoot {
     orders: Order[];
     reviews: Review[];
     wishlist: WishlistItem[];
   }
   ```

2. **Anemic Aggregate**: No business logic, just data container
   ```typescript
   // BAD - Logic in services instead of aggregate
   class Order {
     items: OrderItem[];
     status: string;
   }

   class OrderService {
     addItem(order: Order, item: OrderItem) { /* logic here */ }
   }
   ```

3. **Cross-Aggregate Transaction**: Modifying multiple aggregates in one transaction
   ```typescript
   // BAD
   async confirmOrder(orderId: OrderId): Promise<void> {
     const order = await this.orderRepo.findById(orderId);
     const customer = await this.customerRepo.findById(order.customerId);

     order.confirm();
     customer.addLoyaltyPoints(100); // Different aggregate!

     await this.unitOfWork.commit(); // Single transaction - BAD
   }
   ```

4. **Exposing Internals**: Returning mutable collections
   ```typescript
   // BAD
   get items(): OrderItem[] { return this._items; }

   // GOOD
   get items(): ReadonlyArray<OrderItem> { return [...this._items]; }
   ```

## When to Use

- Group of objects that change together
- Business rules span multiple entities
- Need transactional consistency for a set of objects
- Complex domain with many relationships

## See Also

- [Entity](./entity.md) - Aggregate root is an entity
- [Value Object](./value-object.md) - Aggregates contain value objects
- [Repository](./repository.md) - Persists aggregates
- [Domain Event](./domain-event.md) - Cross-aggregate communication
