# Identity Map

> "Ensures that each object gets loaded only once by keeping every loaded object in a map. Looks up objects using the map when referring to them." - Martin Fowler, PoEAA

## Concept

Identity Map est un cache qui stocke tous les objets charges depuis la base de donnees, indexes par leur identite. Il garantit qu'il n'y a qu'une seule instance de chaque objet en memoire pendant une session.

## Objectifs

1. **Unicite** : Une seule instance par entite
2. **Performance** : Eviter les requetes repetees
3. **Coherence** : Modifications visibles partout
4. **Integration** : Fonctionne avec Unit of Work

## Implementation TypeScript

```typescript
// Identity Map generique
class IdentityMap<T extends { id: string }> {
  private map = new Map<string, T>();

  get(id: string): T | undefined {
    return this.map.get(id);
  }

  add(entity: T): void {
    if (!entity.id) {
      throw new Error('Entity must have an id');
    }
    this.map.set(entity.id, entity);
  }

  has(id: string): boolean {
    return this.map.has(id);
  }

  remove(id: string): boolean {
    return this.map.delete(id);
  }

  clear(): void {
    this.map.clear();
  }

  getAll(): T[] {
    return Array.from(this.map.values());
  }

  size(): number {
    return this.map.size;
  }
}

// Identity Map par type d'entite
class TypedIdentityMap {
  private maps = new Map<string, IdentityMap<any>>();

  private getMap<T extends Entity>(type: new (...args: any[]) => T): IdentityMap<T> {
    const typeName = type.name;
    if (!this.maps.has(typeName)) {
      this.maps.set(typeName, new IdentityMap<T>());
    }
    return this.maps.get(typeName)!;
  }

  get<T extends Entity>(type: new (...args: any[]) => T, id: string): T | undefined {
    return this.getMap(type).get(id);
  }

  add<T extends Entity>(entity: T): void {
    this.getMap(entity.constructor as new () => T).add(entity);
  }

  has<T extends Entity>(type: new (...args: any[]) => T, id: string): boolean {
    return this.getMap(type).has(id);
  }

  remove<T extends Entity>(type: new (...args: any[]) => T, id: string): boolean {
    return this.getMap(type).remove(id);
  }

  clearAll(): void {
    this.maps.clear();
  }

  clearType<T extends Entity>(type: new (...args: any[]) => T): void {
    this.getMap(type).clear();
  }
}
```

## Integration avec Repository

```typescript
class OrderRepository {
  constructor(
    private readonly db: Database,
    private readonly mapper: OrderDataMapper,
    private readonly identityMap: TypedIdentityMap,
  ) {}

  async findById(id: string): Promise<Order | null> {
    // 1. Chercher dans l'Identity Map d'abord
    const cached = this.identityMap.get(Order, id);
    if (cached) {
      return cached;
    }

    // 2. Charger depuis la DB
    const order = await this.mapper.findById(id);
    if (order) {
      // 3. Ajouter a l'Identity Map
      this.identityMap.add(order);
    }

    return order;
  }

  async findByCustomerId(customerId: string): Promise<Order[]> {
    // Query DB
    const orders = await this.mapper.findByCustomerId(customerId);

    // Ajouter/mettre a jour l'Identity Map
    return orders.map((order) => {
      const cached = this.identityMap.get(Order, order.id);
      if (cached) {
        // Retourner l'instance existante
        return cached;
      }
      this.identityMap.add(order);
      return order;
    });
  }

  async save(order: Order): Promise<void> {
    await this.mapper.save(order);
    // S'assurer que l'Identity Map est a jour
    if (!this.identityMap.has(Order, order.id)) {
      this.identityMap.add(order);
    }
  }

  async delete(order: Order): Promise<void> {
    await this.mapper.delete(order.id);
    this.identityMap.remove(Order, order.id);
  }
}
```

## Identity Map avec Lazy Loading

```typescript
class OrderWithLazyCustomer {
  private _customer?: Customer;
  private _customerId: string;

  constructor(
    public readonly id: string,
    customerId: string,
    private readonly identityMap: TypedIdentityMap,
    private readonly customerLoader: (id: string) => Promise<Customer>,
  ) {
    this._customerId = customerId;
  }

  async getCustomer(): Promise<Customer> {
    if (this._customer) {
      return this._customer;
    }

    // Check Identity Map first
    const cached = this.identityMap.get(Customer, this._customerId);
    if (cached) {
      this._customer = cached;
      return cached;
    }

    // Load and cache
    const customer = await this.customerLoader(this._customerId);
    this.identityMap.add(customer);
    this._customer = customer;
    return customer;
  }
}
```

## Session-Scoped Identity Map

```typescript
// Identity Map lie a une session/requete
class Session {
  private readonly identityMap = new TypedIdentityMap();
  private readonly unitOfWork: UnitOfWork;

  constructor(db: Database, mappers: MapperRegistry) {
    this.unitOfWork = new UnitOfWork(db, mappers);
  }

  getIdentityMap(): TypedIdentityMap {
    return this.identityMap;
  }

  // Factory pour repositories avec la meme Identity Map
  getOrderRepository(): OrderRepository {
    return new OrderRepository(this.db, this.orderMapper, this.identityMap);
  }

  getCustomerRepository(): CustomerRepository {
    return new CustomerRepository(this.db, this.customerMapper, this.identityMap);
  }

  async commit(): Promise<void> {
    await this.unitOfWork.commit();
  }

  close(): void {
    this.identityMap.clearAll();
  }
}

// Usage dans un request handler
async function handleRequest(req: Request, res: Response) {
  const session = new Session(db, mappers);

  try {
    const orderRepo = session.getOrderRepository();
    const customerRepo = session.getCustomerRepository();

    // Meme Identity Map = memes instances
    const order = await orderRepo.findById(req.params.id);
    const customer = await customerRepo.findById(order.customerId);

    // Si on recharge order.customer, on obtient la meme instance
    const sameCustomer = await order.getCustomer();
    console.log(customer === sameCustomer); // true

    await session.commit();
    res.json(order);
  } finally {
    session.close();
  }
}
```

## Comparaison avec alternatives

| Aspect | Identity Map | Simple Cache | No Cache |
|--------|--------------|--------------|----------|
| Unicite garantie | Oui | Non | Non |
| Coherence | Oui | Non | Oui (DB) |
| Performance | Bonne | Bonne | Mauvaise |
| Memoire | Session-bound | Configurable | Minimale |
| Complexite | Moyenne | Faible | Aucune |

## Quand utiliser

**Utiliser Identity Map quand :**

- ORM avec Domain Model
- Relations entre entites
- Modifications multiples de memes objets
- Besoin de coherence en memoire
- Unit of Work

**Eviter Identity Map quand :**

- CRUD simple sans relations
- Requetes read-only pures
- Objets immutables (Value Objects)
- Long-running processes (memoire)

## Relation avec DDD

L'Identity Map supporte l'**identite des Entities** :

```typescript
// En DDD, deux entites avec meme ID sont identiques
const order1 = await orderRepo.findById('order-123');
const order2 = await orderRepo.findById('order-123');

// Avec Identity Map: meme instance
console.log(order1 === order2); // true

// Les modifications sont visibles partout
order1.addItem(product, 2);
console.log(order2.items.length); // Aussi mis a jour
```

## Problemes potentiels

```typescript
// ATTENTION: Memory leaks avec sessions longues
class LongRunningProcess {
  private session = new Session();

  async process(): Promise<void> {
    for (const id of this.allOrderIds) {
      // Identity Map grandit indefiniment!
      const order = await this.session.orderRepo.findById(id);
      await this.processOrder(order);
    }
    // Clear periodiquement
    if (this.processedCount % 1000 === 0) {
      this.session.getIdentityMap().clearAll();
    }
  }
}

// ATTENTION: Stale data avec sessions longues
// Recharger depuis DB si necessaire
async function refreshEntity<T extends Entity>(
  repo: Repository<T>,
  entity: T,
  identityMap: IdentityMap<T>,
): Promise<T> {
  identityMap.remove(entity.id);
  return repo.findById(entity.id);
}
```

## Patterns associes

- **Unit of Work** : Utilise Identity Map pour tracking
- **Repository** : Integre Identity Map
- **Lazy Load** : Verifie Identity Map avant chargement
- **Data Mapper** : Alimente l'Identity Map

## Frameworks et ORMs

| Framework | Identity Map |
|-----------|--------------|
| TypeORM | EntityManager (par defaut) |
| MikroORM | EntityManager (explicite) |
| Hibernate | First-Level Cache |
| Entity Framework | DbContext tracking |
| Prisma | Non (stateless) |

## Sources

- Martin Fowler, PoEAA, Chapter 11
- [Identity Map - martinfowler.com](https://martinfowler.com/eaaCatalog/identityMap.html)
