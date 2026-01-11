# Domain-Driven Design Patterns

Patterns tactiques et stratégiques de DDD - Eric Evans.

## Building Blocks (Tactical)

### 1. Entity

> Objet avec identité unique et cycle de vie.

```typescript
abstract class Entity<T> {
  protected readonly _id: T;

  constructor(id: T) {
    this._id = id;
  }

  get id(): T {
    return this._id;
  }

  equals(other: Entity<T>): boolean {
    if (other === null || other === undefined) return false;
    if (this === other) return true;
    return this._id === other._id;
  }
}

class User extends Entity<UserId> {
  private _email: Email;
  private _name: string;
  private _role: UserRole;

  constructor(id: UserId, email: Email, name: string) {
    super(id);
    this._email = email;
    this._name = name;
    this._role = UserRole.MEMBER;
  }

  changeEmail(newEmail: Email) {
    // Business rule: validate email change
    if (this._role === UserRole.ADMIN) {
      throw new Error('Admin email cannot be changed');
    }
    this._email = newEmail;
  }

  promote() {
    this._role = UserRole.ADMIN;
  }
}
```

**Caractéristiques :**
- Identité stable dans le temps
- Mutable (peut changer d'état)
- Égalité basée sur l'ID

**Quand :** Utilisateurs, commandes, produits, comptes.
**Lié à :** Value Object, Aggregate.

---

### 2. Value Object

> Objet immutable défini par ses attributs.

```typescript
class Money {
  private constructor(
    public readonly amount: number,
    public readonly currency: string,
  ) {
    if (amount < 0) throw new Error('Amount cannot be negative');
  }

  static of(amount: number, currency: string): Money {
    return new Money(amount, currency);
  }

  static zero(currency = 'EUR'): Money {
    return new Money(0, currency);
  }

  add(other: Money): Money {
    if (this.currency !== other.currency) {
      throw new Error('Cannot add different currencies');
    }
    return new Money(this.amount + other.amount, this.currency);
  }

  multiply(factor: number): Money {
    return new Money(this.amount * factor, this.currency);
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency;
  }
}

class Address {
  constructor(
    public readonly street: string,
    public readonly city: string,
    public readonly zipCode: string,
    public readonly country: string,
  ) {
    Object.freeze(this);
  }

  equals(other: Address): boolean {
    return (
      this.street === other.street &&
      this.city === other.city &&
      this.zipCode === other.zipCode &&
      this.country === other.country
    );
  }

  withStreet(street: string): Address {
    return new Address(street, this.city, this.zipCode, this.country);
  }
}
```

**Caractéristiques :**
- Immutable
- Égalité par valeur (tous les attributs)
- Pas d'identité propre
- Auto-validant

**Quand :** Montants, adresses, dates, coordonnées, emails.
**Lié à :** Entity.

---

### 3. Aggregate

> Cluster d'objets avec une racine cohérente.

```typescript
// Aggregate Root
class Order extends Entity<OrderId> {
  private _items: OrderItem[] = [];
  private _status: OrderStatus = OrderStatus.DRAFT;
  private _customer: CustomerId;

  constructor(id: OrderId, customerId: CustomerId) {
    super(id);
    this._customer = customerId;
  }

  // All access goes through the root
  addItem(product: ProductId, quantity: number, unitPrice: Money) {
    if (this._status !== OrderStatus.DRAFT) {
      throw new Error('Cannot modify submitted order');
    }
    const existing = this._items.find((i) => i.productId.equals(product));
    if (existing) {
      existing.increaseQuantity(quantity);
    } else {
      this._items.push(new OrderItem(product, quantity, unitPrice));
    }
  }

  removeItem(product: ProductId) {
    if (this._status !== OrderStatus.DRAFT) {
      throw new Error('Cannot modify submitted order');
    }
    this._items = this._items.filter((i) => !i.productId.equals(product));
  }

  submit(): DomainEvent[] {
    if (this._items.length === 0) {
      throw new Error('Cannot submit empty order');
    }
    this._status = OrderStatus.SUBMITTED;
    return [new OrderSubmitted(this._id, this.total)];
  }

  get total(): Money {
    return this._items.reduce(
      (sum, item) => sum.add(item.subtotal),
      Money.zero(),
    );
  }

  get items(): readonly OrderItem[] {
    return this._items;
  }
}

// Part of the aggregate (not accessible directly)
class OrderItem {
  constructor(
    public readonly productId: ProductId,
    private _quantity: number,
    public readonly unitPrice: Money,
  ) {}

  increaseQuantity(amount: number) {
    this._quantity += amount;
  }

  get quantity(): number {
    return this._quantity;
  }

  get subtotal(): Money {
    return this.unitPrice.multiply(this._quantity);
  }
}
```

**Règles :**
- Une seule racine d'agrégat
- Références externes uniquement vers la racine (par ID)
- Invariants garantis dans les limites de l'agrégat
- Modifications atomiques

**Quand :** Cohérence transactionnelle, invariants complexes.
**Lié à :** Entity, Repository.

---

### 4. Repository

> Abstraction de la persistence des agrégats.

```typescript
interface Repository<T extends Entity<ID>, ID> {
  findById(id: ID): Promise<T | null>;
  save(entity: T): Promise<void>;
  delete(id: ID): Promise<void>;
}

interface OrderRepository extends Repository<Order, OrderId> {
  findByCustomer(customerId: CustomerId): Promise<Order[]>;
  findPendingOrders(): Promise<Order[]>;
}

// Implementation
class PostgresOrderRepository implements OrderRepository {
  constructor(private db: Database) {}

  async findById(id: OrderId): Promise<Order | null> {
    const row = await this.db.query('SELECT * FROM orders WHERE id = ?', [id.value]);
    if (!row) return null;
    return this.toEntity(row);
  }

  async save(order: Order): Promise<void> {
    await this.db.transaction(async (tx) => {
      await tx.upsert('orders', this.toRow(order));
      await tx.delete('order_items', { order_id: order.id.value });
      for (const item of order.items) {
        await tx.insert('order_items', this.itemToRow(order.id, item));
      }
    });
  }

  async findByCustomer(customerId: CustomerId): Promise<Order[]> {
    const rows = await this.db.query('SELECT * FROM orders WHERE customer_id = ?', [customerId.value]);
    return Promise.all(rows.map((r) => this.toEntity(r)));
  }

  private toEntity(row: any): Order {
    // Reconstitute aggregate from data
  }
}
```

**Caractéristiques :**
- Interface orientée collection
- Un repository par agrégat
- Abstrait le stockage

**Quand :** Accès aux agrégats, isolation persistence.
**Lié à :** Aggregate, Unit of Work.

---

### 5. Domain Service

> Logique métier qui n'appartient à aucune entité.

```typescript
class TransferService {
  constructor(
    private accountRepo: AccountRepository,
    private eventPublisher: DomainEventPublisher,
  ) {}

  async transfer(
    fromAccountId: AccountId,
    toAccountId: AccountId,
    amount: Money,
  ): Promise<void> {
    const fromAccount = await this.accountRepo.findById(fromAccountId);
    const toAccount = await this.accountRepo.findById(toAccountId);

    if (!fromAccount || !toAccount) {
      throw new Error('Account not found');
    }

    // Business logic that spans two aggregates
    fromAccount.withdraw(amount);
    toAccount.deposit(amount);

    await this.accountRepo.save(fromAccount);
    await this.accountRepo.save(toAccount);

    await this.eventPublisher.publish(
      new MoneyTransferred(fromAccountId, toAccountId, amount),
    );
  }
}

class PricingService {
  calculatePrice(product: Product, customer: Customer): Money {
    let price = product.basePrice;

    // Business rules that involve multiple entities
    if (customer.isVIP()) {
      price = price.multiply(0.9); // 10% discount
    }

    if (product.isOnSale()) {
      price = price.multiply(0.85); // Additional 15% off
    }

    return price;
  }
}
```

**Caractéristiques :**
- Stateless
- Opérations sur plusieurs entités
- Logique qui n'appartient pas naturellement à une entité

**Quand :** Transferts, calculs cross-entity, validations complexes.
**Lié à :** Entity, Application Service.

---

### 6. Domain Event

> Notification d'un fait significatif du domaine.

```typescript
interface DomainEvent {
  readonly occurredAt: Date;
  readonly aggregateId: string;
}

class OrderPlaced implements DomainEvent {
  readonly occurredAt = new Date();

  constructor(
    public readonly aggregateId: string,
    public readonly orderId: OrderId,
    public readonly customerId: CustomerId,
    public readonly total: Money,
    public readonly items: ReadonlyArray<{ productId: string; quantity: number }>,
  ) {}
}

class PaymentReceived implements DomainEvent {
  readonly occurredAt = new Date();

  constructor(
    public readonly aggregateId: string,
    public readonly paymentId: PaymentId,
    public readonly orderId: OrderId,
    public readonly amount: Money,
  ) {}
}

// Event publisher
class DomainEventPublisher {
  private handlers = new Map<string, ((event: DomainEvent) => Promise<void>)[]>();

  subscribe<T extends DomainEvent>(
    eventType: new (...args: any[]) => T,
    handler: (event: T) => Promise<void>,
  ) {
    const typeName = eventType.name;
    if (!this.handlers.has(typeName)) {
      this.handlers.set(typeName, []);
    }
    this.handlers.get(typeName)!.push(handler as any);
  }

  async publish(event: DomainEvent) {
    const handlers = this.handlers.get(event.constructor.name) || [];
    await Promise.all(handlers.map((h) => h(event)));
  }
}
```

**Caractéristiques :**
- Immutable
- Passé (quelque chose s'est passé)
- Nommé en langage ubiquitaire

**Quand :** Découplage, event sourcing, notifications.
**Lié à :** Event Sourcing, CQRS.

---

### 7. Factory

> Création d'objets complexes du domaine.

```typescript
class OrderFactory {
  create(customerId: CustomerId, items: CreateOrderItem[]): Order {
    const orderId = OrderId.generate();
    const order = new Order(orderId, customerId);

    for (const item of items) {
      order.addItem(item.productId, item.quantity, item.unitPrice);
    }

    return order;
  }

  reconstitute(data: OrderData): Order {
    // Rebuild from persistence data
    const order = new Order(
      new OrderId(data.id),
      new CustomerId(data.customerId),
    );

    // Bypass invariant checks for reconstitution
    order.restoreState({
      status: data.status,
      items: data.items.map((i) => new OrderItem(/* ... */)),
    });

    return order;
  }
}

// Factory method in aggregate
class User extends Entity<UserId> {
  static register(email: Email, password: string): User {
    const user = new User(UserId.generate(), email);
    user.setPassword(password);
    user.addEvent(new UserRegistered(user.id, email));
    return user;
  }
}
```

**Quand :** Création complexe, reconstitution, invariants à l'initialisation.
**Lié à :** Aggregate, Repository.

---

### 8. Specification

> Encapsuler une règle métier réutilisable.

```typescript
interface Specification<T> {
  isSatisfiedBy(candidate: T): boolean;
  and(other: Specification<T>): Specification<T>;
  or(other: Specification<T>): Specification<T>;
  not(): Specification<T>;
}

abstract class CompositeSpecification<T> implements Specification<T> {
  abstract isSatisfiedBy(candidate: T): boolean;

  and(other: Specification<T>): Specification<T> {
    return new AndSpecification(this, other);
  }

  or(other: Specification<T>): Specification<T> {
    return new OrSpecification(this, other);
  }

  not(): Specification<T> {
    return new NotSpecification(this);
  }
}

// Concrete specifications
class IsVIPCustomer extends CompositeSpecification<Customer> {
  isSatisfiedBy(customer: Customer): boolean {
    return customer.totalPurchases > 10000 && customer.memberSince.getFullYear() < 2020;
  }
}

class HasValidEmail extends CompositeSpecification<Customer> {
  isSatisfiedBy(customer: Customer): boolean {
    return customer.emailVerified && !customer.email.isBounced();
  }
}

// Usage
const eligibleForPromotion = new IsVIPCustomer().and(new HasValidEmail());

const eligibleCustomers = customers.filter((c) => eligibleForPromotion.isSatisfiedBy(c));

// Query specification
class CustomersByCountry extends CompositeSpecification<Customer> {
  constructor(private country: string) {
    super();
  }

  isSatisfiedBy(customer: Customer): boolean {
    return customer.address.country === this.country;
  }

  toSql(): string {
    return `country = '${this.country}'`;
  }
}
```

**Quand :** Règles métier composables, filtrage, validation.
**Lié à :** Strategy, Query Object.

---

## Strategic Patterns

### 9. Bounded Context

> Limite explicite où un modèle s'applique.

```typescript
// Sales Context
namespace SalesContext {
  class Customer {
    constructor(
      public readonly id: CustomerId,
      public readonly name: string,
      public readonly creditLimit: Money,
    ) {}
  }

  class Order {
    // Sales-specific order model
  }
}

// Shipping Context
namespace ShippingContext {
  class Customer {
    constructor(
      public readonly id: CustomerId,
      public readonly name: string,
      public readonly shippingAddress: Address,
    ) {}
  }

  class Shipment {
    // Shipping-specific model
  }
}

// Different models for the same concept "Customer"
// Each context has its own ubiquitous language
```

**Caractéristiques :**
- Limites claires
- Modèle cohérent à l'intérieur
- Langage ubiquitaire spécifique

**Quand :** Grands systèmes, équipes multiples.
**Lié à :** Context Map, Anti-Corruption Layer.

---

### 10. Context Map

> Relations entre bounded contexts.

```typescript
// Different relationship types:

// 1. Shared Kernel - Shared code between contexts
namespace SharedKernel {
  class Money {
    /* Shared value object */
  }
  class UserId {
    /* Shared identifier */
  }
}

// 2. Customer-Supplier - One context depends on another
// Supplier (upstream) - Catalog Context
namespace CatalogContext {
  interface ProductService {
    getProduct(id: ProductId): Promise<ProductDTO>;
  }
}

// Customer (downstream) - Order Context uses Catalog
namespace OrderContext {
  class OrderService {
    constructor(private catalogService: CatalogContext.ProductService) {}
  }
}

// 3. Conformist - Downstream adopts upstream model
// 4. Anti-Corruption Layer - Translation between contexts
// 5. Open Host Service - Well-defined API for integration
// 6. Published Language - Standard interchange format
```

**Types de relations :**
- **Partnership** : Coopération étroite
- **Shared Kernel** : Code partagé
- **Customer-Supplier** : Dépendance dirigée
- **Conformist** : Adoption du modèle upstream
- **ACL** : Traduction/protection
- **Open Host Service** : API publique
- **Published Language** : Format standard (JSON, XML)
- **Separate Ways** : Pas d'intégration

**Quand :** Visualiser les dépendances, planifier l'intégration.
**Lié à :** Bounded Context.

---

### 11. Anti-Corruption Layer (ACL)

> Couche de traduction entre contextes.

```typescript
// External/Legacy system
namespace LegacySystem {
  interface LegacyCustomer {
    CUST_ID: string;
    FIRST_NM: string;
    LAST_NM: string;
    ADDR_LINE1: string;
    ADDR_CITY: string;
  }
}

// Our domain model
namespace OurDomain {
  class Customer extends Entity<CustomerId> {
    constructor(
      id: CustomerId,
      public name: CustomerName,
      public address: Address,
    ) {
      super(id);
    }
  }
}

// Anti-Corruption Layer
class CustomerACL {
  translateFromLegacy(legacy: LegacySystem.LegacyCustomer): OurDomain.Customer {
    return new OurDomain.Customer(
      new CustomerId(legacy.CUST_ID),
      new CustomerName(legacy.FIRST_NM, legacy.LAST_NM),
      new Address(legacy.ADDR_LINE1, legacy.ADDR_CITY, '', ''),
    );
  }

  translateToLegacy(customer: OurDomain.Customer): LegacySystem.LegacyCustomer {
    return {
      CUST_ID: customer.id.value,
      FIRST_NM: customer.name.firstName,
      LAST_NM: customer.name.lastName,
      ADDR_LINE1: customer.address.street,
      ADDR_CITY: customer.address.city,
    };
  }
}

// Facade using ACL
class LegacyCustomerAdapter {
  constructor(
    private legacyApi: LegacyCustomerAPI,
    private acl: CustomerACL,
  ) {}

  async findCustomer(id: CustomerId): Promise<OurDomain.Customer | null> {
    const legacy = await this.legacyApi.getCustomer(id.value);
    if (!legacy) return null;
    return this.acl.translateFromLegacy(legacy);
  }
}
```

**Quand :** Intégration legacy, protection du modèle.
**Lié à :** Adapter, Facade.

---

### 12. Domain Events for Integration

> Événements pour communication inter-contextes.

```typescript
// Integration Event (cross-context)
interface IntegrationEvent {
  eventId: string;
  occurredAt: Date;
  source: string;
}

class OrderPlacedIntegrationEvent implements IntegrationEvent {
  eventId = crypto.randomUUID();
  occurredAt = new Date();
  source = 'sales-context';

  constructor(
    public readonly orderId: string,
    public readonly customerId: string,
    public readonly items: Array<{ productId: string; quantity: number }>,
    public readonly total: number,
    public readonly currency: string,
  ) {}
}

// Event bus for cross-context communication
class IntegrationEventBus {
  async publish(event: IntegrationEvent) {
    await this.messageBroker.publish('integration-events', {
      type: event.constructor.name,
      payload: event,
    });
  }

  subscribe(eventType: string, handler: (event: any) => Promise<void>) {
    this.messageBroker.subscribe('integration-events', async (msg) => {
      if (msg.type === eventType) {
        await handler(msg.payload);
      }
    });
  }
}

// Handler in another context
class ShippingContext {
  constructor(eventBus: IntegrationEventBus) {
    eventBus.subscribe('OrderPlacedIntegrationEvent', async (event) => {
      // Create shipment when order is placed
      await this.createShipment(event.orderId, event.customerId);
    });
  }
}
```

**Quand :** Communication async entre contextes, découplage.
**Lié à :** Event-Driven Architecture.

---

## Event Sourcing & CQRS

### 13. Event Sourcing

> Stocker les événements au lieu de l'état.

```typescript
interface EventStore {
  append(aggregateId: string, events: DomainEvent[], expectedVersion: number): Promise<void>;
  getEvents(aggregateId: string): Promise<DomainEvent[]>;
}

abstract class EventSourcedAggregate extends Entity<string> {
  private _version = 0;
  private _uncommittedEvents: DomainEvent[] = [];

  protected apply(event: DomainEvent) {
    this.when(event);
    this._uncommittedEvents.push(event);
  }

  protected abstract when(event: DomainEvent): void;

  loadFromHistory(events: DomainEvent[]) {
    for (const event of events) {
      this.when(event);
      this._version++;
    }
  }

  get uncommittedEvents(): DomainEvent[] {
    return [...this._uncommittedEvents];
  }

  get version(): number {
    return this._version;
  }

  markEventsAsCommitted() {
    this._uncommittedEvents = [];
  }
}

class Order extends EventSourcedAggregate {
  private status: OrderStatus = OrderStatus.DRAFT;
  private items: Map<string, number> = new Map();

  static create(orderId: string, customerId: string): Order {
    const order = new Order(orderId);
    order.apply(new OrderCreated(orderId, customerId));
    return order;
  }

  addItem(productId: string, quantity: number) {
    this.apply(new ItemAdded(this.id, productId, quantity));
  }

  protected when(event: DomainEvent) {
    if (event instanceof OrderCreated) {
      this.status = OrderStatus.DRAFT;
    } else if (event instanceof ItemAdded) {
      const current = this.items.get(event.productId) || 0;
      this.items.set(event.productId, current + event.quantity);
    }
  }
}

// Repository for event-sourced aggregate
class EventSourcedOrderRepository {
  constructor(private eventStore: EventStore) {}

  async save(order: Order) {
    await this.eventStore.append(
      order.id,
      order.uncommittedEvents,
      order.version,
    );
    order.markEventsAsCommitted();
  }

  async findById(id: string): Promise<Order | null> {
    const events = await this.eventStore.getEvents(id);
    if (events.length === 0) return null;

    const order = new Order(id);
    order.loadFromHistory(events);
    return order;
  }
}
```

**Avantages :**
- Audit trail complet
- Debug temporal
- Rebuild d'état
- Analytics

**Quand :** Audit requis, undo/redo, analytics temporelles.
**Lié à :** CQRS, Event Store.

---

### 14. CQRS (Command Query Responsibility Segregation)

> Séparer lectures et écritures.

```typescript
// Command side
interface Command {
  execute(): Promise<void>;
}

class PlaceOrderCommand implements Command {
  constructor(
    private orderRepo: OrderRepository,
    private orderId: string,
    private customerId: string,
    private items: OrderItemDTO[],
  ) {}

  async execute() {
    const order = Order.create(this.orderId, this.customerId);
    for (const item of this.items) {
      order.addItem(item.productId, item.quantity);
    }
    await this.orderRepo.save(order);
  }
}

// Query side - optimized read model
interface OrderReadModel {
  id: string;
  customerName: string;
  status: string;
  total: number;
  itemCount: number;
  createdAt: Date;
}

class OrderQueryService {
  constructor(private readDb: ReadDatabase) {}

  async findById(id: string): Promise<OrderReadModel | null> {
    return this.readDb.query('SELECT * FROM order_view WHERE id = ?', [id]);
  }

  async findByCustomer(customerId: string): Promise<OrderReadModel[]> {
    return this.readDb.query('SELECT * FROM order_view WHERE customer_id = ?', [customerId]);
  }

  async getOrderSummary(): Promise<OrderSummary> {
    return this.readDb.query('SELECT COUNT(*), SUM(total) FROM order_view');
  }
}

// Projector - builds read model from events
class OrderProjector {
  constructor(private readDb: ReadDatabase) {}

  async handle(event: DomainEvent) {
    if (event instanceof OrderCreated) {
      await this.readDb.insert('order_view', {
        id: event.orderId,
        customer_id: event.customerId,
        status: 'draft',
        total: 0,
        item_count: 0,
        created_at: event.occurredAt,
      });
    } else if (event instanceof ItemAdded) {
      await this.readDb.execute(`
        UPDATE order_view
        SET item_count = item_count + 1
        WHERE id = ?
      `, [event.aggregateId]);
    }
  }
}
```

**Avantages :**
- Optimisation lectures/écritures indépendantes
- Scaling séparé
- Modèles de lecture spécialisés

**Quand :** Lectures >> écritures, vues multiples, scaling.
**Lié à :** Event Sourcing.

---

## Tableau de décision

| Besoin | Pattern |
|--------|---------|
| Objet avec identité | Entity |
| Objet par valeur | Value Object |
| Cohérence transactionnelle | Aggregate |
| Accès aux agrégats | Repository |
| Logique cross-entity | Domain Service |
| Notification fait passé | Domain Event |
| Création complexe | Factory |
| Règle métier réutilisable | Specification |
| Limite de modèle | Bounded Context |
| Relations inter-contextes | Context Map |
| Protection contre legacy | Anti-Corruption Layer |
| Audit / History | Event Sourcing |
| Optimiser reads/writes | CQRS |

## Sources

- [Domain-Driven Design - Eric Evans](https://www.domainlanguage.com/ddd/)
- [Implementing DDD - Vaughn Vernon](https://www.informit.com/store/implementing-domain-driven-design-9780321834577)
- [DDD Reference](https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_2015-03.pdf)
