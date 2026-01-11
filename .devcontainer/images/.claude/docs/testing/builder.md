# Test Data Builder

> Construction fluide d'objets de test avec valeurs par defaut sensees.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                    Test Data Builder                             │
│                                                                  │
│   new UserBuilder()                                              │
│     .withName("John")      ◄── Override specific fields         │
│     .withEmail("j@t.com")                                        │
│     .asAdmin()             ◄── Semantic presets                  │
│     .build()               ◄── Create instance                   │
│                                                                  │
│   Result: User with defaults + overrides                         │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation TypeScript

```typescript
interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'member' | 'guest';
  active: boolean;
  createdAt: Date;
  metadata?: Record<string, unknown>;
}

class UserBuilder {
  private props: User = {
    id: crypto.randomUUID(),
    email: 'default@test.com',
    name: 'Default User',
    role: 'member',
    active: true,
    createdAt: new Date(),
  };

  // Field-specific methods
  withId(id: string): this {
    this.props.id = id;
    return this;
  }

  withEmail(email: string): this {
    this.props.email = email;
    return this;
  }

  withName(name: string): this {
    this.props.name = name;
    return this;
  }

  withRole(role: User['role']): this {
    this.props.role = role;
    return this;
  }

  withMetadata(metadata: Record<string, unknown>): this {
    this.props.metadata = metadata;
    return this;
  }

  // Semantic presets
  asAdmin(): this {
    this.props.role = 'admin';
    return this;
  }

  asGuest(): this {
    this.props.role = 'guest';
    this.props.active = false;
    return this;
  }

  inactive(): this {
    this.props.active = false;
    return this;
  }

  // Build method
  build(): User {
    return { ...this.props };
  }

  // Build multiple
  buildMany(count: number): User[] {
    return Array.from({ length: count }, (_, i) =>
      new UserBuilder()
        .withId(`user-${i}`)
        .withEmail(`user${i}@test.com`)
        .withName(`User ${i}`)
        .build(),
    );
  }
}

// Usage
const admin = new UserBuilder().withName('Admin').asAdmin().build();

const inactiveUser = new UserBuilder().withEmail('old@test.com').inactive().build();

const users = new UserBuilder().buildMany(5);
```

## Generic Builder

```typescript
class Builder<T extends object> {
  protected props: Partial<T> = {};

  constructor(private defaults: T) {
    this.props = { ...defaults };
  }

  with<K extends keyof T>(key: K, value: T[K]): this {
    this.props[key] = value;
    return this;
  }

  merge(partial: Partial<T>): this {
    Object.assign(this.props, partial);
    return this;
  }

  build(): T {
    return { ...this.defaults, ...this.props } as T;
  }
}

// Usage
interface Product {
  id: string;
  name: string;
  price: number;
  stock: number;
}

const productDefaults: Product = {
  id: 'default-id',
  name: 'Default Product',
  price: 0,
  stock: 0,
};

const product = new Builder(productDefaults)
  .with('name', 'Widget')
  .with('price', 29.99)
  .with('stock', 100)
  .build();
```

## Builder with Relationships

```typescript
interface Order {
  id: string;
  userId: string;
  items: OrderItem[];
  status: 'pending' | 'confirmed' | 'shipped' | 'delivered';
  total: number;
  createdAt: Date;
}

interface OrderItem {
  productId: string;
  quantity: number;
  unitPrice: number;
}

class OrderItemBuilder {
  private props: OrderItem = {
    productId: 'default-product',
    quantity: 1,
    unitPrice: 10,
  };

  forProduct(productId: string, price: number): this {
    this.props.productId = productId;
    this.props.unitPrice = price;
    return this;
  }

  withQuantity(quantity: number): this {
    this.props.quantity = quantity;
    return this;
  }

  build(): OrderItem {
    return { ...this.props };
  }
}

class OrderBuilder {
  private props: Omit<Order, 'items' | 'total'> = {
    id: crypto.randomUUID(),
    userId: 'default-user',
    status: 'pending',
    createdAt: new Date(),
  };
  private items: OrderItem[] = [];

  forUser(userId: string): this {
    this.props.userId = userId;
    return this;
  }

  withItem(builder: OrderItemBuilder): this {
    this.items.push(builder.build());
    return this;
  }

  withItems(items: OrderItem[]): this {
    this.items = items;
    return this;
  }

  withStatus(status: Order['status']): this {
    this.props.status = status;
    return this;
  }

  confirmed(): this {
    return this.withStatus('confirmed');
  }

  shipped(): this {
    return this.withStatus('shipped');
  }

  build(): Order {
    const total = this.items.reduce(
      (sum, item) => sum + item.quantity * item.unitPrice,
      0,
    );
    return { ...this.props, items: this.items, total };
  }
}

// Usage
const order = new OrderBuilder()
  .forUser('user-123')
  .withItem(new OrderItemBuilder().forProduct('product-1', 29.99).withQuantity(2))
  .withItem(new OrderItemBuilder().forProduct('product-2', 49.99))
  .confirmed()
  .build();

console.log(order.total); // 109.97
```

## Builder with Validation

```typescript
class ValidatingUserBuilder extends UserBuilder {
  build(): User {
    const user = super.build();

    // Validation
    if (!user.email.includes('@')) {
      throw new Error('Invalid email in test data');
    }
    if (user.name.length < 2) {
      throw new Error('Name too short in test data');
    }

    return user;
  }
}

// Builder with schema validation
import { z } from 'zod';

class SchemaValidatedBuilder<T extends object> extends Builder<T> {
  constructor(
    defaults: T,
    private schema: z.ZodSchema<T>,
  ) {
    super(defaults);
  }

  build(): T {
    const data = super.build();
    return this.schema.parse(data);
  }
}
```

## Functional Builder Alternative

```typescript
// Factory function with overrides
const createUser = (overrides: Partial<User> = {}): User => ({
  id: crypto.randomUUID(),
  email: 'default@test.com',
  name: 'Default User',
  role: 'member',
  active: true,
  createdAt: new Date(),
  ...overrides,
});

// Preset factories
const createAdmin = (overrides: Partial<User> = {}): User =>
  createUser({ role: 'admin', ...overrides });

const createInactiveUser = (overrides: Partial<User> = {}): User =>
  createUser({ active: false, ...overrides });

// Usage
const user = createUser({ name: 'John', email: 'john@test.com' });
const admin = createAdmin({ name: 'Admin' });
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `@faker-js/faker` | Donnees realistes |
| `fishery` | Factory library |
| `factory.ts` | Type-safe factories |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Defaults mutables | State shared | Toujours copier |
| Trop de methodes | API complexe | Methodes semantiques |
| Pas de randomisation | Collisions ID | UUID par defaut |
| Builder sans build() | Oubli d'appel | Type guard |
| Validation dans tests | Tests fragiles | Validation optionnelle |

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| Objets avec beaucoup de champs | Oui |
| Variations frequentes | Oui |
| Relations complexes | Oui |
| Objets simples (2-3 champs) | Factory function suffit |
| Donnees fixes | JSON fixtures |

## Patterns lies

- **Object Mother** : Factory pre-configurees basees sur Builders
- **Fixture** : Builders populant les fixtures
- **Factory** : Pattern de creation sous-jacent

## Sources

- [Test Data Builders - Nat Pryce](http://www.natpryce.com/articles/000714.html)
- [Growing Object-Oriented Software](http://www.growing-object-oriented-software.com/)
