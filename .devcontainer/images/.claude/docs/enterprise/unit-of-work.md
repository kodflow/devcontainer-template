# Unit of Work

> "Maintains a list of objects affected by a business transaction and coordinates the writing out of changes and the resolution of concurrency problems." - Martin Fowler, PoEAA

## Concept

Unit of Work est un pattern qui garde trace de toutes les modifications effectuees lors d'une transaction metier et coordonne l'ecriture de ces modifications en une seule operation atomique.

## Responsabilites

1. **Tracking** : Suivre les objets nouveaux, modifies, supprimes
2. **Commit** : Persister tous les changements en une transaction
3. **Rollback** : Annuler les changements en cas d'erreur
4. **Concurrency** : Gerer les conflits de concurrence

## Implementation TypeScript

```typescript
// Interface Unit of Work
interface UnitOfWork {
  registerNew<T extends Entity>(entity: T): void;
  registerDirty<T extends Entity>(entity: T): void;
  registerClean<T extends Entity>(entity: T): void;
  registerDeleted<T extends Entity>(entity: T): void;
  commit(): Promise<void>;
  rollback(): void;
}

// Implementation concrete
class DefaultUnitOfWork implements UnitOfWork {
  private newEntities = new Map<string, Entity>();
  private dirtyEntities = new Map<string, Entity>();
  private deletedEntities = new Map<string, Entity>();
  private cleanEntities = new Map<string, Entity>();

  constructor(
    private readonly db: Database,
    private readonly mappers: MapperRegistry,
  ) {}

  registerNew<T extends Entity>(entity: T): void {
    if (!entity.id) throw new Error('Entity must have an ID');
    if (this.deletedEntities.has(entity.id)) {
      throw new Error('Cannot register deleted entity as new');
    }
    if (this.dirtyEntities.has(entity.id) || this.cleanEntities.has(entity.id)) {
      throw new Error('Entity already registered');
    }
    this.newEntities.set(entity.id, entity);
  }

  registerDirty<T extends Entity>(entity: T): void {
    if (!entity.id) throw new Error('Entity must have an ID');
    if (this.deletedEntities.has(entity.id)) {
      throw new Error('Cannot register deleted entity as dirty');
    }
    if (!this.newEntities.has(entity.id) && !this.dirtyEntities.has(entity.id)) {
      this.dirtyEntities.set(entity.id, entity);
    }
  }

  registerClean<T extends Entity>(entity: T): void {
    if (!entity.id) throw new Error('Entity must have an ID');
    this.cleanEntities.set(entity.id, entity);
  }

  registerDeleted<T extends Entity>(entity: T): void {
    if (!entity.id) throw new Error('Entity must have an ID');

    // Si c'est un nouvel objet, on l'enleve simplement
    if (this.newEntities.has(entity.id)) {
      this.newEntities.delete(entity.id);
      return;
    }

    this.dirtyEntities.delete(entity.id);
    this.cleanEntities.delete(entity.id);
    this.deletedEntities.set(entity.id, entity);
  }

  async commit(): Promise<void> {
    try {
      await this.db.beginTransaction();

      // 1. Insert new entities
      for (const entity of this.newEntities.values()) {
        const mapper = this.mappers.getMapper(entity.constructor);
        await mapper.insert(entity);
      }

      // 2. Update dirty entities
      for (const entity of this.dirtyEntities.values()) {
        const mapper = this.mappers.getMapper(entity.constructor);
        await mapper.update(entity);
      }

      // 3. Delete removed entities
      for (const entity of this.deletedEntities.values()) {
        const mapper = this.mappers.getMapper(entity.constructor);
        await mapper.delete(entity);
      }

      await this.db.commit();
      this.clear();
    } catch (error) {
      await this.db.rollback();
      throw error;
    }
  }

  rollback(): void {
    this.clear();
  }

  private clear(): void {
    this.newEntities.clear();
    this.dirtyEntities.clear();
    this.deletedEntities.clear();
    this.cleanEntities.clear();
  }
}

// MapperRegistry pour trouver le bon mapper
class MapperRegistry {
  private mappers = new Map<Function, DataMapper<any>>();

  register<T extends Entity>(type: new () => T, mapper: DataMapper<T>): void {
    this.mappers.set(type, mapper);
  }

  getMapper<T extends Entity>(type: Function): DataMapper<T> {
    const mapper = this.mappers.get(type);
    if (!mapper) throw new Error(`No mapper registered for ${type.name}`);
    return mapper;
  }
}
```

## Unit of Work avec Repositories

```typescript
// Repository qui utilise Unit of Work
class OrderRepository {
  constructor(
    private readonly uow: UnitOfWork,
    private readonly mapper: OrderDataMapper,
  ) {}

  async findById(id: string): Promise<Order | null> {
    const order = await this.mapper.findById(id);
    if (order) {
      this.uow.registerClean(order);
    }
    return order;
  }

  add(order: Order): void {
    this.uow.registerNew(order);
  }

  remove(order: Order): void {
    this.uow.registerDeleted(order);
  }
}

// Service qui coordonne
class OrderService {
  constructor(
    private readonly orderRepo: OrderRepository,
    private readonly productRepo: ProductRepository,
    private readonly uow: UnitOfWork,
  ) {}

  async placeOrder(customerId: string, items: CartItem[]): Promise<Order> {
    const order = Order.create(customerId);

    for (const item of items) {
      const product = await this.productRepo.findById(item.productId);
      if (!product) throw new NotFoundError('Product not found');

      product.reduceStock(item.quantity);
      // Product devient dirty automatiquement (voir ci-dessous)

      order.addItem(product, item.quantity);
    }

    order.submit();
    this.orderRepo.add(order);

    // Commit unique pour tout
    await this.uow.commit();

    return order;
  }
}
```

## Tracking automatique des changements

```typescript
// Entity avec tracking automatique
abstract class TrackedEntity {
  private _isDirty = false;
  private _uow?: UnitOfWork;

  attachTo(uow: UnitOfWork): void {
    this._uow = uow;
  }

  protected markDirty(): void {
    this._isDirty = true;
    if (this._uow) {
      this._uow.registerDirty(this);
    }
  }

  get isDirty(): boolean {
    return this._isDirty;
  }
}

class Product extends TrackedEntity {
  private _stock: number;

  get stock(): number {
    return this._stock;
  }

  reduceStock(quantity: number): void {
    if (quantity > this._stock) {
      throw new DomainError('Insufficient stock');
    }
    this._stock -= quantity;
    this.markDirty(); // Auto-tracking
  }
}

// Avec Proxy pour tracking transparent
function createTrackedProxy<T extends Entity>(
  entity: T,
  uow: UnitOfWork,
): T {
  return new Proxy(entity, {
    set(target, prop, value) {
      const oldValue = (target as any)[prop];
      if (oldValue !== value) {
        (target as any)[prop] = value;
        uow.registerDirty(target);
      }
      return true;
    },
  });
}
```

## Unit of Work avec Identity Map

```typescript
class UnitOfWorkWithIdentityMap implements UnitOfWork {
  private identityMap = new Map<string, Map<string, Entity>>();
  private newEntities = new Set<Entity>();
  private dirtyEntities = new Set<Entity>();
  private deletedEntities = new Set<Entity>();

  // Identity Map pour eviter les doublons
  getIdentityMap<T extends Entity>(type: new () => T): Map<string, T> {
    const typeName = type.name;
    if (!this.identityMap.has(typeName)) {
      this.identityMap.set(typeName, new Map());
    }
    return this.identityMap.get(typeName) as Map<string, T>;
  }

  findInIdentityMap<T extends Entity>(
    type: new () => T,
    id: string,
  ): T | undefined {
    return this.getIdentityMap(type).get(id) as T | undefined;
  }

  registerLoaded<T extends Entity>(entity: T): void {
    const map = this.getIdentityMap(entity.constructor as new () => T);
    map.set(entity.id, entity);
  }

  // ... reste de l'implementation
}
```

## Comparaison avec alternatives

| Aspect | Unit of Work | Transaction Script | Active Record |
|--------|--------------|-------------------|---------------|
| Tracking | Automatique | Manuel | Dans l'objet |
| Atomicite | Garantie | Manuelle | Par objet |
| Performance | Batch operations | Individual | Individual |
| Complexite | Elevee | Faible | Faible |

## Quand utiliser

**Utiliser Unit of Work quand :**

- Transactions impliquant plusieurs entites
- Besoin de batch inserts/updates
- ORM avec change tracking
- Optimistic locking complex

**Eviter Unit of Work quand :**

- CRUD simple
- Une seule entite par transaction
- Pas de Domain Model

## Relation avec DDD

Unit of Work s'aligne avec les **Aggregate boundaries** :

```typescript
// Un commit par Aggregate (pas cross-aggregate)
class OrderUnitOfWork {
  private order?: Order;

  async commit(): Promise<void> {
    if (!this.order) return;

    await this.db.beginTransaction();
    try {
      await this.orderMapper.save(this.order);
      // OrderItems sauves avec Order (meme aggregate)

      const events = this.order.pullEvents();
      await this.eventStore.append(events);

      await this.db.commit();
    } catch (e) {
      await this.db.rollback();
      throw e;
    }
  }
}
```

## Frameworks et ORMs

| Framework | Unit of Work |
|-----------|--------------|
| TypeORM | EntityManager |
| Prisma | Transaction ($transaction) |
| MikroORM | EntityManager + flush() |
| Hibernate | Session |
| Entity Framework | DbContext |

## Patterns associes

- **Identity Map** : Cache des objets charges
- **Data Mapper** : Persistance des entites
- **Repository** : Interface collection-like
- **Domain Events** : Publies au commit

## Sources

- Martin Fowler, PoEAA, Chapter 11
- [Unit of Work - martinfowler.com](https://martinfowler.com/eaaCatalog/unitOfWork.html)
