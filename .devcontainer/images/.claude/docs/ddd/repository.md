# Repository Pattern (DDD)

## Definition

A **Repository** mediates between the domain and data mapping layers, acting as an in-memory collection of domain objects. It encapsulates persistence logic while providing a collection-like interface for accessing aggregates.

```
Repository = Collection Abstraction + Persistence Encapsulation + Query Isolation
```

**Key characteristics:**

- **Aggregate-centric**: One repository per aggregate root
- **Collection semantics**: Acts like an in-memory collection
- **Persistence ignorance**: Domain doesn't know about storage
- **Query encapsulation**: Complex queries hidden behind methods
- **Unit of Work integration**: Transaction boundary awareness

## TypeScript Implementation

```typescript
// Generic Repository Interface
interface Repository<T extends AggregateRoot<TId>, TId> {
  findById(id: TId): Promise<T | null>;
  save(aggregate: T): Promise<void>;
  delete(aggregate: T): Promise<void>;
  exists(id: TId): Promise<boolean>;
}

// Domain-specific Repository Interface
interface OrderRepository extends Repository<Order, OrderId> {
  findById(id: OrderId): Promise<Order | null>;
  findByCustomer(customerId: CustomerId): Promise<Order[]>;
  findPendingOrders(): Promise<Order[]>;
  findByStatus(status: OrderStatus): Promise<Order[]>;
  save(order: Order): Promise<void>;
  delete(order: Order): Promise<void>;
}

// Implementation with TypeORM
class TypeOrmOrderRepository implements OrderRepository {
  constructor(
    private readonly dataSource: DataSource,
    private readonly eventBus: EventBus
  ) {}

  async findById(id: OrderId): Promise<Order | null> {
    const orderEntity = await this.dataSource
      .getRepository(OrderEntity)
      .findOne({
        where: { id: id.value },
        relations: ['items']
      });

    if (!orderEntity) return null;

    return this.toDomain(orderEntity);
  }

  async findByCustomer(customerId: CustomerId): Promise<Order[]> {
    const entities = await this.dataSource
      .getRepository(OrderEntity)
      .find({
        where: { customerId: customerId.value },
        relations: ['items'],
        order: { createdAt: 'DESC' }
      });

    return entities.map(e => this.toDomain(e));
  }

  async findPendingOrders(): Promise<Order[]> {
    const entities = await this.dataSource
      .getRepository(OrderEntity)
      .find({
        where: { status: In(['draft', 'confirmed']) },
        relations: ['items']
      });

    return entities.map(e => this.toDomain(e));
  }

  async save(order: Order): Promise<void> {
    const entity = this.toEntity(order);

    // Optimistic locking
    const result = await this.dataSource
      .getRepository(OrderEntity)
      .save(entity);

    // Publish domain events after successful save
    const events = order.pullDomainEvents();
    for (const event of events) {
      await this.eventBus.publish(event);
    }

    order.incrementVersion();
  }

  async delete(order: Order): Promise<void> {
    await this.dataSource
      .getRepository(OrderEntity)
      .delete({ id: order.id.value });
  }

  async exists(id: OrderId): Promise<boolean> {
    const count = await this.dataSource
      .getRepository(OrderEntity)
      .count({ where: { id: id.value } });

    return count > 0;
  }

  // Mapper: Entity -> Domain
  private toDomain(entity: OrderEntity): Order {
    const items = entity.items.map(item =>
      OrderItem.reconstitute(
        OrderItemId.from(item.id).value!,
        ProductId.from(item.productId).value!,
        Quantity.create(item.quantity).value!,
        Money.create(item.unitPrice, Currency.USD).value!
      )
    );

    return Order.reconstitute(
      OrderId.from(entity.id).value!,
      CustomerId.from(entity.customerId).value!,
      items,
      entity.status as OrderStatus,
      Address.reconstitute(entity.shippingAddress),
      entity.createdAt,
      entity.version
    );
  }

  // Mapper: Domain -> Entity
  private toEntity(order: Order): OrderEntity {
    const entity = new OrderEntity();
    entity.id = order.id.value;
    entity.customerId = order.customerId.value;
    entity.status = order.status;
    entity.shippingAddress = order.shippingAddress.toJSON();
    entity.version = order.version;
    entity.items = order.items.map(item => {
      const itemEntity = new OrderItemEntity();
      itemEntity.id = item.id.value;
      itemEntity.productId = item.productId.value;
      itemEntity.quantity = item.quantity.value;
      itemEntity.unitPrice = item.unitPrice.amount;
      return itemEntity;
    });
    return entity;
  }
}

// Specification Pattern integration
interface OrderRepository {
  findBySpecification(spec: Specification<Order>): Promise<Order[]>;
}

class TypeOrmOrderRepository {
  async findBySpecification(spec: Specification<Order>): Promise<Order[]> {
    // Convert specification to query
    const queryBuilder = this.dataSource
      .getRepository(OrderEntity)
      .createQueryBuilder('order')
      .leftJoinAndSelect('order.items', 'items');

    spec.toQueryBuilder(queryBuilder);

    const entities = await queryBuilder.getMany();
    return entities.map(e => this.toDomain(e));
  }
}
```

## In-Memory Repository (Testing)

```typescript
class InMemoryOrderRepository implements OrderRepository {
  private orders: Map<string, Order> = new Map();
  private publishedEvents: DomainEvent[] = [];

  async findById(id: OrderId): Promise<Order | null> {
    return this.orders.get(id.value) ?? null;
  }

  async findByCustomer(customerId: CustomerId): Promise<Order[]> {
    return Array.from(this.orders.values())
      .filter(o => o.customerId.equals(customerId));
  }

  async findPendingOrders(): Promise<Order[]> {
    return Array.from(this.orders.values())
      .filter(o => o.status === OrderStatus.Draft ||
                   o.status === OrderStatus.Confirmed);
  }

  async save(order: Order): Promise<void> {
    // Clone to simulate persistence behavior
    this.orders.set(order.id.value, structuredClone(order));

    // Collect events for testing
    this.publishedEvents.push(...order.pullDomainEvents());
    order.incrementVersion();
  }

  async delete(order: Order): Promise<void> {
    this.orders.delete(order.id.value);
  }

  async exists(id: OrderId): Promise<boolean> {
    return this.orders.has(id.value);
  }

  // Test helpers
  clear(): void {
    this.orders.clear();
    this.publishedEvents = [];
  }

  getPublishedEvents(): DomainEvent[] {
    return [...this.publishedEvents];
  }
}
```

## OOP vs FP Comparison

```typescript
// FP-style Repository using Effect
import { Effect, Layer, Context } from 'effect';

// Service definition
class OrderRepository extends Context.Tag('OrderRepository')<
  OrderRepository,
  {
    findById: (id: OrderId) => Effect.Effect<Order | null, DatabaseError>;
    save: (order: Order) => Effect.Effect<void, DatabaseError>;
    delete: (order: Order) => Effect.Effect<void, DatabaseError>;
  }
>() {}

// Implementation as Layer
const OrderRepositoryLive = Layer.succeed(
  OrderRepository,
  {
    findById: (id) => Effect.tryPromise({
      try: () => dataSource.query(/* ... */),
      catch: (e) => new DatabaseError(e)
    }),
    save: (order) => Effect.tryPromise({
      try: () => dataSource.save(/* ... */),
      catch: (e) => new DatabaseError(e)
    }),
    delete: (order) => Effect.tryPromise({
      try: () => dataSource.delete(/* ... */),
      catch: (e) => new DatabaseError(e)
    })
  }
);

// Usage in domain service
const confirmOrder = (orderId: OrderId) =>
  Effect.gen(function* (_) {
    const repo = yield* _(OrderRepository);
    const order = yield* _(repo.findById(orderId));
    if (!order) return yield* _(Effect.fail(new NotFoundError()));

    order.confirm();
    yield* _(repo.save(order));
  });
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **TypeORM** | ORM with repository | `npm i typeorm` |
| **Prisma** | Type-safe ORM | `npm i prisma` |
| **MikroORM** | Data mapper ORM | `npm i @mikro-orm/core` |
| **Effect** | Functional services | `npm i effect` |

## Anti-patterns

1. **Generic Repository**: Over-abstracting with generic CRUD

   ```typescript
   // BAD - Not domain-driven
   interface Repository<T> {
     find(criteria: object): Promise<T[]>;
     save(entity: T): Promise<T>;
   }
   ```

2. **Exposing Query Details**: Leaking ORM into domain

   ```typescript
   // BAD - ORM concepts in domain
   interface OrderRepository {
     findByQueryBuilder(qb: QueryBuilder): Promise<Order[]>;
   }
   ```

3. **Multiple Aggregates**: One repository for multiple roots

   ```typescript
   // BAD
   interface OrderCustomerRepository {
     findOrder(id: OrderId): Promise<Order>;
     findCustomer(id: CustomerId): Promise<Customer>;
   }
   ```

4. **Missing Domain Events**: Not publishing events after save

   ```typescript
   // BAD - Events lost
   async save(order: Order): Promise<void> {
     await this.dataSource.save(entity);
     // Missing: order.pullDomainEvents() and publish
   }
   ```

## When to Use

- Persisting and retrieving aggregate roots
- Encapsulating complex query logic
- Abstracting data access technology
- Testing with in-memory implementations

## See Also

- [Aggregate](./aggregate.md) - Repository per aggregate root
- [Specification](./specification.md) - Query composition
- [Domain Event](./domain-event.md) - Published after save
