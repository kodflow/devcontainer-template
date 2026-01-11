# Lazy Load

> "An object that doesn't contain all of the data you need but knows how to get it." - Martin Fowler, PoEAA

## Concept

Lazy Load est un pattern qui differe le chargement des donnees jusqu'au moment ou elles sont reellement necessaires. Cela ameliore les performances en evitant de charger des donnees qui ne seront peut-etre jamais utilisees.

## Quatre variantes

1. **Lazy Initialization** : Champ initialise a null, charge au premier acces
2. **Virtual Proxy** : Objet proxy qui charge le vrai objet a la demande
3. **Value Holder** : Wrapper generique qui encapsule le chargement
4. **Ghost** : Objet partiellement charge qui se complete lui-meme

## Lazy Initialization

```typescript
class Order {
  private _customer?: Customer;
  private readonly customerId: string;

  constructor(
    public readonly id: string,
    customerId: string,
    private readonly customerLoader: CustomerLoader,
  ) {
    this.customerId = customerId;
  }

  // Lazy initialization classique
  async getCustomer(): Promise<Customer> {
    if (!this._customer) {
      this._customer = await this.customerLoader.load(this.customerId);
    }
    return this._customer;
  }

  // Version synchrone avec Promise caching
  private customerPromise?: Promise<Customer>;

  getCustomerAsync(): Promise<Customer> {
    if (!this.customerPromise) {
      this.customerPromise = this.customerLoader.load(this.customerId);
    }
    return this.customerPromise;
  }
}
```

## Virtual Proxy

```typescript
// Interface commune
interface Customer {
  id: string;
  name: string;
  email: string;
  getOrders(): Promise<Order[]>;
}

// Implementation reelle
class RealCustomer implements Customer {
  constructor(
    public readonly id: string,
    public readonly name: string,
    public readonly email: string,
    private readonly orderRepository: OrderRepository,
  ) {}

  async getOrders(): Promise<Order[]> {
    return this.orderRepository.findByCustomerId(this.id);
  }
}

// Virtual Proxy
class CustomerProxy implements Customer {
  private realCustomer?: RealCustomer;

  constructor(
    public readonly id: string,
    private readonly loader: (id: string) => Promise<RealCustomer>,
  ) {}

  private async ensureLoaded(): Promise<RealCustomer> {
    if (!this.realCustomer) {
      this.realCustomer = await this.loader(this.id);
    }
    return this.realCustomer;
  }

  get name(): string {
    throw new Error('Use getNameAsync() for lazy loaded property');
  }

  async getNameAsync(): Promise<string> {
    const customer = await this.ensureLoaded();
    return customer.name;
  }

  get email(): string {
    throw new Error('Use getEmailAsync() for lazy loaded property');
  }

  async getEmailAsync(): Promise<string> {
    const customer = await this.ensureLoaded();
    return customer.email;
  }

  async getOrders(): Promise<Order[]> {
    const customer = await this.ensureLoaded();
    return customer.getOrders();
  }
}

// Factory qui retourne proxy ou objet reel
class CustomerFactory {
  constructor(
    private readonly repository: CustomerRepository,
    private readonly eagerLoad: boolean = false,
  ) {}

  async create(id: string): Promise<Customer> {
    if (this.eagerLoad) {
      return this.repository.findById(id);
    }
    return new CustomerProxy(id, (id) => this.repository.findById(id));
  }
}
```

## Value Holder

```typescript
// Generic Value Holder
class Lazy<T> {
  private value?: T;
  private loaded = false;
  private loading?: Promise<T>;

  constructor(private readonly loader: () => Promise<T>) {}

  async get(): Promise<T> {
    if (this.loaded) {
      return this.value!;
    }

    // Eviter les chargements multiples concurrents
    if (!this.loading) {
      this.loading = this.loader().then((result) => {
        this.value = result;
        this.loaded = true;
        this.loading = undefined;
        return result;
      });
    }

    return this.loading;
  }

  isLoaded(): boolean {
    return this.loaded;
  }

  reset(): void {
    this.value = undefined;
    this.loaded = false;
    this.loading = undefined;
  }
}

// Usage dans une entite
class Order {
  public readonly customer: Lazy<Customer>;
  public readonly items: Lazy<OrderItem[]>;

  constructor(
    public readonly id: string,
    customerId: string,
    private readonly loaders: {
      customerLoader: (id: string) => Promise<Customer>;
      itemsLoader: (orderId: string) => Promise<OrderItem[]>;
    },
  ) {
    this.customer = new Lazy(() => loaders.customerLoader(customerId));
    this.items = new Lazy(() => loaders.itemsLoader(this.id));
  }
}

// Usage
const order = await orderRepository.findById('123');
// Customer et items non charges

const customer = await order.customer.get(); // Charge maintenant
const items = await order.items.get(); // Charge maintenant
```

## Ghost

```typescript
// Ghost - Objet partiellement charge
class ProductGhost {
  private loaded = false;

  // Proprietes toujours disponibles (ID)
  constructor(public readonly id: string) {}

  // Proprietes lazy
  private _name?: string;
  private _description?: string;
  private _price?: Money;
  private _stock?: number;

  private async ensureLoaded(): Promise<void> {
    if (!this.loaded) {
      const data = await this.loader(this.id);
      this._name = data.name;
      this._description = data.description;
      this._price = Money.of(data.price);
      this._stock = data.stock;
      this.loaded = true;
    }
  }

  async getName(): Promise<string> {
    await this.ensureLoaded();
    return this._name!;
  }

  async getDescription(): Promise<string> {
    await this.ensureLoaded();
    return this._description!;
  }

  async getPrice(): Promise<Money> {
    await this.ensureLoaded();
    return this._price!;
  }

  async getStock(): Promise<number> {
    await this.ensureLoaded();
    return this._stock!;
  }

  private loader: (id: string) => Promise<ProductData>;

  setLoader(loader: (id: string) => Promise<ProductData>): void {
    this.loader = loader;
  }
}

// Mapper qui cree des ghosts
class ProductMapper {
  // Charge completement
  async findById(id: string): Promise<Product> {
    const row = await this.db.queryOne('SELECT * FROM products WHERE id = ?', [id]);
    return this.toDomain(row);
  }

  // Charge comme ghost (juste l'ID)
  createGhost(id: string): ProductGhost {
    const ghost = new ProductGhost(id);
    ghost.setLoader(async (id) => {
      const row = await this.db.queryOne('SELECT * FROM products WHERE id = ?', [id]);
      return row;
    });
    return ghost;
  }
}
```

## Lazy Load avec TypeScript Decorators

```typescript
// Decorator pour proprietes lazy
function Lazy() {
  return function (target: any, propertyKey: string) {
    const privateKey = `_${propertyKey}`;
    const loaderKey = `${propertyKey}Loader`;

    Object.defineProperty(target, propertyKey, {
      get: async function () {
        if (this[privateKey] === undefined) {
          if (typeof this[loaderKey] !== 'function') {
            throw new Error(`Loader ${loaderKey} not defined`);
          }
          this[privateKey] = await this[loaderKey]();
        }
        return this[privateKey];
      },
      enumerable: true,
      configurable: true,
    });
  };
}

class Order {
  @Lazy()
  customer!: Customer;

  private async customerLoader(): Promise<Customer> {
    return this.customerRepo.findById(this.customerId);
  }
}
```

## Comparaison des variantes

| Variante | Complexite | Use Case | Avantage |
|----------|------------|----------|----------|
| Lazy Init | Faible | Simple, un champ | Simple a implementer |
| Virtual Proxy | Moyenne | Interface complete | Transparent pour le client |
| Value Holder | Moyenne | Generique, reutilisable | Type-safe, reutilisable |
| Ghost | Elevee | Objets complexes | Un seul chargement |

## Quand utiliser

**Utiliser Lazy Load quand :**

- Relations one-to-many ou many-to-many
- Donnees rarement accedees
- Donnees volumineuses (LOB, collections)
- Performance critique

**Eviter Lazy Load quand :**

- Donnees toujours necessaires (eager load)
- N+1 queries problem (batch loading)
- Contexte deconnecte (DTOs)

## Probleme N+1 et solutions

```typescript
// PROBLEME: N+1 queries
const orders = await orderRepo.findAll(); // 1 query
for (const order of orders) {
  const customer = await order.customer.get(); // N queries!
}

// SOLUTION 1: Eager loading
const orders = await orderRepo.findAllWithCustomers(); // 1-2 queries

// SOLUTION 2: Batch loading (DataLoader pattern)
class CustomerDataLoader {
  private batch: Map<string, Promise<Customer>[]> = new Map();

  load(id: string): Promise<Customer> {
    return new Promise((resolve) => {
      if (!this.batch.has(id)) {
        this.batch.set(id, []);
      }
      this.batch.get(id)!.push(resolve);

      // Batch execute on next tick
      setImmediate(() => this.executeBatch());
    });
  }

  private async executeBatch() {
    const ids = Array.from(this.batch.keys());
    const customers = await this.customerRepo.findByIds(ids);

    for (const customer of customers) {
      const resolvers = this.batch.get(customer.id) || [];
      resolvers.forEach((resolve) => resolve(customer));
    }
    this.batch.clear();
  }
}
```

## Relation avec DDD

En DDD, Lazy Load s'applique aux **references entre Aggregates** :

```typescript
class Order /* Aggregate Root */ {
  // Eager: Dans le meme aggregate
  private items: OrderItem[];

  // Lazy: Reference a un autre aggregate
  private customerId: CustomerId;
  private customer: Lazy<Customer>;
}
```

## Sources

- Martin Fowler, PoEAA, Chapter 11
- [Lazy Load - martinfowler.com](https://martinfowler.com/eaaCatalog/lazyLoad.html)
