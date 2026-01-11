# Repository (PoEAA)

> "Mediates between the domain and data mapping layers using a collection-like interface for accessing domain objects." - Martin Fowler, PoEAA

## Concept

Le Repository agit comme une collection en memoire d'objets du domaine. Il cache les details de l'acces aux donnees et fournit une interface orientee domaine pour la persistance.

## Principes cles

1. **Collection-like** : Interface comme une collection (add, remove, find)
2. **Domain-centric** : Methodes de recherche basees sur le domaine
3. **Encapsulation** : Cache les details de persistance
4. **Un par Aggregate** : En DDD, un Repository par Aggregate Root

## Implementation TypeScript

```typescript
// Interface Repository - Contrat abstrait
interface Repository<T, ID> {
  findById(id: ID): Promise<T | null>;
  findAll(): Promise<T[]>;
  save(entity: T): Promise<void>;
  delete(entity: T): Promise<void>;
  exists(id: ID): Promise<boolean>;
}

// Repository specifique au domaine
interface OrderRepository extends Repository<Order, OrderId> {
  findByCustomerId(customerId: CustomerId): Promise<Order[]>;
  findByStatus(status: OrderStatus): Promise<Order[]>;
  findPendingOlderThan(date: Date): Promise<Order[]>;
  nextId(): OrderId;
}

// Implementation concrete
class PostgresOrderRepository implements OrderRepository {
  constructor(
    private readonly db: Database,
    private readonly mapper: OrderDataMapper,
    private readonly identityMap: IdentityMap<Order>,
  ) {}

  async findById(id: OrderId): Promise<Order | null> {
    // Check identity map first
    const cached = this.identityMap.get(id.value);
    if (cached) return cached;

    // Load from DB
    const order = await this.mapper.findById(id.value);
    if (order) {
      this.identityMap.add(order);
    }
    return order;
  }

  async findAll(): Promise<Order[]> {
    return this.mapper.findAll();
  }

  async findByCustomerId(customerId: CustomerId): Promise<Order[]> {
    return this.mapper.findByCustomerId(customerId.value);
  }

  async findByStatus(status: OrderStatus): Promise<Order[]> {
    return this.mapper.findByStatus(status);
  }

  async findPendingOlderThan(date: Date): Promise<Order[]> {
    const rows = await this.db.query(
      `SELECT * FROM orders
       WHERE status = 'pending' AND created_at < ?`,
      [date],
    );
    return Promise.all(rows.map((r) => this.mapper.toDomain(r)));
  }

  async save(order: Order): Promise<void> {
    const exists = await this.exists(OrderId.from(order.id));
    if (exists) {
      await this.mapper.update(order);
    } else {
      await this.mapper.insert(order);
    }
    this.identityMap.add(order);
  }

  async delete(order: Order): Promise<void> {
    await this.mapper.delete(order.id);
    this.identityMap.remove(order.id);
  }

  async exists(id: OrderId): Promise<boolean> {
    const result = await this.db.queryOne(
      'SELECT 1 FROM orders WHERE id = ?',
      [id.value],
    );
    return result !== null;
  }

  nextId(): OrderId {
    return OrderId.generate();
  }
}
```

## Repository avec Specification Pattern

```typescript
// Specification pattern pour queries complexes
interface Specification<T> {
  isSatisfiedBy(entity: T): boolean;
  toSql(): { where: string; params: any[] };
}

class OrderByCustomerSpec implements Specification<Order> {
  constructor(private readonly customerId: CustomerId) {}

  isSatisfiedBy(order: Order): boolean {
    return order.customerId.equals(this.customerId);
  }

  toSql(): { where: string; params: any[] } {
    return {
      where: 'customer_id = ?',
      params: [this.customerId.value],
    };
  }
}

class OrderMinAmountSpec implements Specification<Order> {
  constructor(private readonly minAmount: Money) {}

  isSatisfiedBy(order: Order): boolean {
    return order.total.isGreaterThanOrEqual(this.minAmount);
  }

  toSql(): { where: string; params: any[] } {
    return {
      where: 'total_amount >= ?',
      params: [this.minAmount.amount],
    };
  }
}

// Composite specifications
class AndSpec<T> implements Specification<T> {
  constructor(
    private readonly left: Specification<T>,
    private readonly right: Specification<T>,
  ) {}

  isSatisfiedBy(entity: T): boolean {
    return this.left.isSatisfiedBy(entity) && this.right.isSatisfiedBy(entity);
  }

  toSql(): { where: string; params: any[] } {
    const l = this.left.toSql();
    const r = this.right.toSql();
    return {
      where: `(${l.where}) AND (${r.where})`,
      params: [...l.params, ...r.params],
    };
  }
}

// Repository avec Specification
interface OrderRepository {
  findSatisfying(spec: Specification<Order>): Promise<Order[]>;
}

class PostgresOrderRepository {
  async findSatisfying(spec: Specification<Order>): Promise<Order[]> {
    const { where, params } = spec.toSql();
    const rows = await this.db.query(
      `SELECT * FROM orders WHERE ${where}`,
      params,
    );
    return Promise.all(rows.map((r) => this.mapper.toDomain(r)));
  }
}

// Usage
const spec = new AndSpec(
  new OrderByCustomerSpec(customerId),
  new OrderMinAmountSpec(Money.of(100)),
);
const orders = await orderRepository.findSatisfying(spec);
```

## Repository en memoire pour tests

```typescript
class InMemoryOrderRepository implements OrderRepository {
  private orders = new Map<string, Order>();
  private idCounter = 0;

  async findById(id: OrderId): Promise<Order | null> {
    return this.orders.get(id.value) || null;
  }

  async findAll(): Promise<Order[]> {
    return Array.from(this.orders.values());
  }

  async findByCustomerId(customerId: CustomerId): Promise<Order[]> {
    return Array.from(this.orders.values()).filter((o) =>
      o.customerId.equals(customerId),
    );
  }

  async findByStatus(status: OrderStatus): Promise<Order[]> {
    return Array.from(this.orders.values()).filter((o) =>
      o.status === status,
    );
  }

  async save(order: Order): Promise<void> {
    this.orders.set(order.id, order);
  }

  async delete(order: Order): Promise<void> {
    this.orders.delete(order.id);
  }

  async exists(id: OrderId): Promise<boolean> {
    return this.orders.has(id.value);
  }

  nextId(): OrderId {
    return OrderId.from(`order-${++this.idCounter}`);
  }

  // Test helpers
  clear(): void {
    this.orders.clear();
    this.idCounter = 0;
  }

  count(): number {
    return this.orders.size;
  }
}
```

## Comparaison avec alternatives

| Aspect | Repository | DAO | Active Record |
|--------|------------|-----|---------------|
| Abstraction | Collection | CRUD table | Self-persisting |
| Focus | Domaine | Donnees | Commodite |
| Queries | Domain-centric | SQL-centric | Mixed |
| Testabilite | Excellente | Moyenne | Moyenne |
| DDD compatible | Oui | Non | Non |

## Quand utiliser

**Utiliser Repository quand :**

- Domain Model avec agregats
- Besoin de testabilite (in-memory repos)
- Queries orientees domaine
- Multiple sources de donnees possibles
- DDD architecture

**Eviter Repository quand :**

- CRUD simple (overkill)
- Queries complexes SQL (utiliser Query Objects)
- Pas de Domain Model

## Relation avec DDD

Le Repository est un **building block DDD essentiel** :

```
┌─────────────────────────────────────────────┐
│              Application Layer              │
│   (Uses Repository interface)               │
├─────────────────────────────────────────────┤
│              Domain Layer                   │
│   - Repository Interface (contrat)          │
│   - Aggregate Roots                         │
├─────────────────────────────────────────────┤
│          Infrastructure Layer               │
│   - Repository Implementation               │
│   - Data Mapper, ORM                        │
└─────────────────────────────────────────────┘
```

**Regles DDD :**

1. Un Repository par Aggregate Root
2. Interface dans le Domain Layer
3. Implementation dans l'Infrastructure Layer
4. Retourne des Aggregates complets

## Anti-patterns a eviter

```typescript
// EVITER: Repository generique qui expose tout
interface BadRepository<T> {
  query(sql: string): Promise<T[]>; // Fuite d'abstraction
}

// EVITER: Repository pour entites non-root
interface OrderItemRepository {} // OrderItem n'est pas un Aggregate Root

// EVITER: Business logic dans le repository
class BadOrderRepository {
  async submitOrder(id: string) {
    const order = await this.findById(id);
    order.status = 'submitted'; // Logique metier hors du domaine!
    await this.save(order);
  }
}
```

## Patterns associes

- **Data Mapper** : Implementation sous-jacente
- **Unit of Work** : Tracking des changements
- **Identity Map** : Cache des objets
- **Specification** : Queries complexes
- **Query Object** : Alternative pour queries reporting

## Sources

- Martin Fowler, PoEAA, Chapter 10
- Eric Evans, DDD - Repositories
- [Repository - martinfowler.com](https://martinfowler.com/eaaCatalog/repository.html)
