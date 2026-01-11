# Data Mapper

> "A layer of Mappers that moves data between objects and a database while keeping them independent of each other and the mapper itself." - Martin Fowler, PoEAA

## Concept

Data Mapper est un pattern qui separe completement les objets du domaine de la logique de persistance. Les objets metier n'ont aucune connaissance de la base de donnees, et inversement.

## Principes cles

1. **Separation totale** : Domain Model ignore la DB
2. **Bidirectionnel** : Mapping domaine <-> DB dans les deux sens
3. **Encapsulation** : Le mapper connait les deux mondes
4. **Testabilite** : Domain Model testable sans DB

## Implementation TypeScript

```typescript
// Domain Model - Aucune dependance sur la DB
class Order {
  private constructor(
    public readonly id: string,
    public readonly customerId: string,
    private readonly items: OrderItem[],
    private status: OrderStatus,
    public readonly createdAt: Date,
    private version: number,
  ) {}

  static create(customerId: string): Order {
    return new Order(
      crypto.randomUUID(),
      customerId,
      [],
      OrderStatus.Draft,
      new Date(),
      1,
    );
  }

  // Factory pour reconstitution depuis la DB
  static reconstitute(
    id: string,
    customerId: string,
    items: OrderItem[],
    status: OrderStatus,
    createdAt: Date,
    version: number,
  ): Order {
    return new Order(id, customerId, items, status, createdAt, version);
  }

  addItem(product: Product, quantity: number): void {
    if (this.status !== OrderStatus.Draft) {
      throw new DomainError('Cannot modify non-draft order');
    }
    this.items.push(OrderItem.create(product, quantity));
  }

  submit(): void {
    if (this.items.length === 0) {
      throw new DomainError('Cannot submit empty order');
    }
    this.status = OrderStatus.Submitted;
  }

  get total(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.subtotal),
      Money.zero(),
    );
  }

  // Expose state for mapper (package-private in ideal world)
  getState(): OrderState {
    return {
      id: this.id,
      customerId: this.customerId,
      items: this.items.map((i) => i.getState()),
      status: this.status,
      createdAt: this.createdAt,
      version: this.version,
    };
  }
}

// Data Mapper - Traduit entre domaine et DB
class OrderDataMapper {
  constructor(
    private readonly db: Database,
    private readonly orderItemMapper: OrderItemDataMapper,
  ) {}

  async findById(id: string): Promise<Order | null> {
    // Query
    const row = await this.db.queryOne(
      'SELECT * FROM orders WHERE id = ?',
      [id],
    );
    if (!row) return null;

    // Map items
    const items = await this.orderItemMapper.findByOrderId(id);

    // Reconstitute domain object
    return Order.reconstitute(
      row.id,
      row.customer_id,
      items,
      row.status as OrderStatus,
      new Date(row.created_at),
      row.version,
    );
  }

  async findByCustomerId(customerId: string): Promise<Order[]> {
    const rows = await this.db.query(
      'SELECT * FROM orders WHERE customer_id = ? ORDER BY created_at DESC',
      [customerId],
    );

    return Promise.all(
      rows.map(async (row) => {
        const items = await this.orderItemMapper.findByOrderId(row.id);
        return Order.reconstitute(
          row.id,
          row.customer_id,
          items,
          row.status as OrderStatus,
          new Date(row.created_at),
          row.version,
        );
      }),
    );
  }

  async insert(order: Order): Promise<void> {
    const state = order.getState();

    await this.db.execute(
      `INSERT INTO orders (id, customer_id, status, created_at, version)
       VALUES (?, ?, ?, ?, ?)`,
      [state.id, state.customerId, state.status, state.createdAt, state.version],
    );

    for (const item of state.items) {
      await this.orderItemMapper.insert(state.id, item);
    }
  }

  async update(order: Order): Promise<void> {
    const state = order.getState();

    // Optimistic locking
    const result = await this.db.execute(
      `UPDATE orders
       SET status = ?, version = version + 1
       WHERE id = ? AND version = ?`,
      [state.status, state.id, state.version],
    );

    if (result.affectedRows === 0) {
      throw new OptimisticLockError('Order was modified by another process');
    }

    // Update items (simple strategy: delete and reinsert)
    await this.orderItemMapper.deleteByOrderId(state.id);
    for (const item of state.items) {
      await this.orderItemMapper.insert(state.id, item);
    }
  }

  async delete(id: string): Promise<void> {
    await this.orderItemMapper.deleteByOrderId(id);
    await this.db.execute('DELETE FROM orders WHERE id = ?', [id]);
  }
}

class OrderItemDataMapper {
  constructor(private readonly db: Database) {}

  async findByOrderId(orderId: string): Promise<OrderItem[]> {
    const rows = await this.db.query(
      'SELECT * FROM order_items WHERE order_id = ?',
      [orderId],
    );

    return rows.map((row) =>
      OrderItem.reconstitute(
        row.id,
        row.product_id,
        row.product_name,
        row.quantity,
        Money.of(row.unit_price, row.currency),
      ),
    );
  }

  async insert(orderId: string, item: OrderItemState): Promise<void> {
    await this.db.execute(
      `INSERT INTO order_items
       (id, order_id, product_id, product_name, quantity, unit_price, currency)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [
        item.id,
        orderId,
        item.productId,
        item.productName,
        item.quantity,
        item.unitPrice.amount,
        item.unitPrice.currency,
      ],
    );
  }

  async deleteByOrderId(orderId: string): Promise<void> {
    await this.db.execute('DELETE FROM order_items WHERE order_id = ?', [orderId]);
  }
}
```

## Comparaison avec alternatives

| Aspect | Data Mapper | Active Record | Table Data Gateway |
|--------|-------------|---------------|-------------------|
| Couplage domaine-DB | Aucun | Fort | Moyen |
| Complexite | Elevee | Faible | Faible |
| Testabilite domaine | Excellente | Moyenne | N/A |
| ORM integration | Naturelle | Native | Manuelle |
| Domain Model rich | Oui | Difficile | Non |

## Quand utiliser

**Utiliser Data Mapper quand :**

- Domain Model riche avec logique complexe
- Tests unitaires du domaine sans DB
- Schema DB different du modele objet
- Multiple sources de donnees
- ORM (Hibernate, TypeORM, etc.)

**Eviter Data Mapper quand :**

- CRUD simple
- Schema DB = modele objet
- Performance critique (overhead mapping)
- Equipe non familiere avec le pattern

## Relation avec DDD

Data Mapper est **essentiel en DDD** pour maintenir l'isolation du domaine :

```typescript
// Repository utilise Data Mapper en interne
class OrderRepository {
  constructor(private readonly mapper: OrderDataMapper) {}

  async findById(id: OrderId): Promise<Order | null> {
    return this.mapper.findById(id.value);
  }

  async save(order: Order): Promise<void> {
    const exists = await this.mapper.findById(order.id);
    if (exists) {
      await this.mapper.update(order);
    } else {
      await this.mapper.insert(order);
    }
  }
}
```

## Mapping complexe

```typescript
// Value Objects embedded
class CustomerDataMapper {
  private toDomain(row: any): Customer {
    return Customer.reconstitute(
      row.id,
      row.name,
      Email.create(row.email),
      new Address(
        row.street,
        row.city,
        row.postal_code,
        row.country,
      ),
    );
  }

  private toRow(customer: Customer): any {
    const state = customer.getState();
    return {
      id: state.id,
      name: state.name,
      email: state.email.value,
      street: state.address.street,
      city: state.address.city,
      postal_code: state.address.postalCode,
      country: state.address.country,
    };
  }
}

// Inheritance mapping (Single Table)
class EmployeeDataMapper {
  async findById(id: string): Promise<Employee | null> {
    const row = await this.db.queryOne(
      'SELECT * FROM employees WHERE id = ?',
      [id],
    );
    if (!row) return null;

    switch (row.type) {
      case 'salaried':
        return SalariedEmployee.reconstitute(
          row.id,
          row.name,
          Money.of(row.salary),
        );
      case 'contractor':
        return ContractorEmployee.reconstitute(
          row.id,
          row.name,
          Money.of(row.hourly_rate),
        );
      default:
        throw new Error(`Unknown employee type: ${row.type}`);
    }
  }
}
```

## Patterns associes

- **Repository** : Abstraction au-dessus du Data Mapper
- **Unit of Work** : Tracking des changements
- **Identity Map** : Cache des objets charges
- **Lazy Load** : Chargement differe des relations

## Sources

- Martin Fowler, PoEAA, Chapter 10
- [Data Mapper - martinfowler.com](https://martinfowler.com/eaaCatalog/dataMapper.html)
