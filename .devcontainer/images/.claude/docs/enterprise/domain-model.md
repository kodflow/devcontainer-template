# Domain Model

> "An object model of the domain that incorporates both behavior and data." - Martin Fowler, PoEAA

## Concept

Le Domain Model est un modele objet qui represente les concepts metier avec leurs comportements et regles. Contrairement a l'Anemic Domain Model (anti-pattern), un Rich Domain Model encapsule la logique metier directement dans les entites.

## Rich vs Anemic Domain Model

```typescript
// ANTI-PATTERN: Anemic Domain Model
// Entite sans comportement = simple structure de donnees
class AnemicOrder {
  id: string;
  items: OrderItem[];
  status: string;
  total: number;
}

// Logique externe dans un service
class OrderService {
  addItem(order: AnemicOrder, product: Product, qty: number) {
    order.items.push({ product, qty });
    order.total = this.recalculate(order);
  }
}

// CORRECT: Rich Domain Model
// Entite avec comportement et invariants
class Order {
  private readonly items: OrderItem[] = [];
  private status: OrderStatus = OrderStatus.Draft;

  addItem(product: Product, quantity: number): void {
    this.ensureDraft();
    this.ensureValidQuantity(quantity);

    const existing = this.findItem(product.id);
    if (existing) {
      existing.increaseQuantity(quantity);
    } else {
      this.items.push(OrderItem.create(product, quantity));
    }
  }

  private ensureDraft(): void {
    if (this.status !== OrderStatus.Draft) {
      throw new DomainError('Cannot modify non-draft order');
    }
  }
}
```

## Implementation TypeScript Complete

```typescript
// Value Objects - Immutables, compares par valeur
class Money {
  private constructor(
    public readonly amount: number,
    public readonly currency: string,
  ) {
    if (amount < 0) throw new DomainError('Amount cannot be negative');
  }

  static of(amount: number, currency = 'EUR'): Money {
    return new Money(amount, currency);
  }

  static zero(currency = 'EUR'): Money {
    return new Money(0, currency);
  }

  add(other: Money): Money {
    this.ensureSameCurrency(other);
    return new Money(this.amount + other.amount, this.currency);
  }

  multiply(factor: number): Money {
    return new Money(this.amount * factor, this.currency);
  }

  equals(other: Money): boolean {
    return this.amount === other.amount && this.currency === other.currency;
  }

  private ensureSameCurrency(other: Money): void {
    if (this.currency !== other.currency) {
      throw new DomainError('Currency mismatch');
    }
  }
}

// Entity - Identite unique, mutable
class OrderItem {
  private constructor(
    public readonly id: string,
    public readonly productId: string,
    public readonly productName: string,
    private _quantity: number,
    public readonly unitPrice: Money,
  ) {}

  static create(product: Product, quantity: number): OrderItem {
    return new OrderItem(
      crypto.randomUUID(),
      product.id,
      product.name,
      quantity,
      product.price,
    );
  }

  get quantity(): number {
    return this._quantity;
  }

  get subtotal(): Money {
    return this.unitPrice.multiply(this._quantity);
  }

  increaseQuantity(amount: number): void {
    if (amount <= 0) throw new DomainError('Amount must be positive');
    this._quantity += amount;
  }

  decreaseQuantity(amount: number): void {
    if (amount <= 0) throw new DomainError('Amount must be positive');
    if (amount > this._quantity) {
      throw new DomainError('Cannot decrease below zero');
    }
    this._quantity -= amount;
  }
}

// Aggregate Root - Point d'entree, protege les invariants
class Order {
  private readonly items: OrderItem[] = [];
  private status: OrderStatus = OrderStatus.Draft;
  private readonly events: DomainEvent[] = [];

  private constructor(
    public readonly id: string,
    public readonly customerId: string,
    public readonly createdAt: Date,
  ) {}

  static create(customerId: string): Order {
    const order = new Order(crypto.randomUUID(), customerId, new Date());
    order.events.push(new OrderCreated(order.id, customerId));
    return order;
  }

  // Comportements metier
  addItem(product: Product, quantity: number): void {
    this.ensureDraft();
    if (quantity <= 0) {
      throw new DomainError('Quantity must be positive');
    }
    if (!product.isAvailable) {
      throw new DomainError(`Product ${product.name} is not available`);
    }

    const existing = this.items.find((i) => i.productId === product.id);
    if (existing) {
      existing.increaseQuantity(quantity);
    } else {
      this.items.push(OrderItem.create(product, quantity));
    }

    this.events.push(new ItemAddedToOrder(this.id, product.id, quantity));
  }

  removeItem(productId: string): void {
    this.ensureDraft();
    const index = this.items.findIndex((i) => i.productId === productId);
    if (index === -1) throw new DomainError('Item not found');
    this.items.splice(index, 1);
  }

  submit(): void {
    this.ensureDraft();
    if (this.items.length === 0) {
      throw new DomainError('Cannot submit empty order');
    }
    this.status = OrderStatus.Submitted;
    this.events.push(new OrderSubmitted(this.id, this.total));
  }

  cancel(reason: string): void {
    if (this.status === OrderStatus.Shipped) {
      throw new DomainError('Cannot cancel shipped order');
    }
    this.status = OrderStatus.Cancelled;
    this.events.push(new OrderCancelled(this.id, reason));
  }

  // Calculs derives
  get total(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.subtotal),
      Money.zero(),
    );
  }

  get itemCount(): number {
    return this.items.reduce((sum, item) => sum + item.quantity, 0);
  }

  get isDraft(): boolean {
    return this.status === OrderStatus.Draft;
  }

  // Protection des invariants
  private ensureDraft(): void {
    if (!this.isDraft) {
      throw new DomainError('Order is not in draft status');
    }
  }

  // Domain Events
  pullEvents(): DomainEvent[] {
    const events = [...this.events];
    this.events.length = 0;
    return events;
  }
}

enum OrderStatus {
  Draft = 'draft',
  Submitted = 'submitted',
  Paid = 'paid',
  Shipped = 'shipped',
  Delivered = 'delivered',
  Cancelled = 'cancelled',
}
```

## Comparaison avec alternatives

| Aspect | Domain Model | Transaction Script | Active Record |
|--------|--------------|-------------------|---------------|
| Encapsulation | Forte | Aucune | Partielle |
| Testabilite | Excellente | Moyenne | Moyenne |
| Complexite initiale | Elevee | Faible | Faible |
| Evolution | Facile | Difficile | Moyenne |
| Persistance | Separee | Dans le script | Dans l'objet |

## Quand utiliser

**Utiliser Domain Model quand :**

- Logique metier complexe avec regles multiples
- Invariants a proteger strictement
- Domaine riche en comportements
- Evolution frequente des regles
- Equipe experimentee en OOP/DDD
- Tests unitaires importants

**Eviter Domain Model quand :**

- CRUD simple sans logique
- Prototype rapide
- Equipe junior sans formation DDD
- Domaine stable et simple

## Relation avec DDD

Le Domain Model est le **coeur du DDD** :

```typescript
// Building Blocks DDD
// 1. Value Object - Money, Address, Email
// 2. Entity - Order, Customer, Product
// 3. Aggregate - Order (root) + OrderItems (enfants)
// 4. Domain Event - OrderSubmitted, PaymentReceived
// 5. Domain Service - PricingService (logique cross-aggregate)

// Le Domain Model implemente ces concepts
class Order /* Aggregate Root */ {
  // Contient des Value Objects
  private shippingAddress: Address;

  // Contient des Entities enfants
  private items: OrderItem[];

  // Emet des Domain Events
  private events: DomainEvent[];
}
```

## Patterns associes

- **Repository** : Persistance du Domain Model
- **Unit of Work** : Gestion des transactions
- **Data Mapper** : Mapping objet-relationnel
- **Factory** : Creation complexe d'agregats
- **Domain Events** : Communication entre agregats

## Sources

- Martin Fowler, PoEAA, Chapter 9
- Eric Evans, Domain-Driven Design (Blue Book)
- Vaughn Vernon, Implementing Domain-Driven Design
- [Domain Model - martinfowler.com](https://martinfowler.com/eaaCatalog/domainModel.html)
