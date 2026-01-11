# Object Mother

> Factory centralisee pour objets de test pre-configures.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                      Object Mother Pattern                       │
│                                                                  │
│   UserMother.john()        ──► Predefined "John" user           │
│   UserMother.admin()       ──► Any admin user                   │
│   UserMother.random()      ──► Random valid user                │
│   UserMother.withOrders()  ──► User with related objects        │
│                                                                  │
│   Benefits: Named scenarios, Consistent test data, Readable     │
└─────────────────────────────────────────────────────────────────┘
```

## Implementation TypeScript

```typescript
import { faker } from '@faker-js/faker';

interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'member' | 'guest';
  active: boolean;
  createdAt: Date;
}

class UserMother {
  // Named personas
  static john(): User {
    return {
      id: 'john-id',
      email: 'john.doe@test.com',
      name: 'John Doe',
      role: 'member',
      active: true,
      createdAt: new Date('2024-01-01'),
    };
  }

  static jane(): User {
    return {
      id: 'jane-id',
      email: 'jane.smith@test.com',
      name: 'Jane Smith',
      role: 'member',
      active: true,
      createdAt: new Date('2024-01-02'),
    };
  }

  // Role-based
  static admin(): User {
    return {
      id: faker.string.uuid(),
      email: 'admin@test.com',
      name: 'Admin User',
      role: 'admin',
      active: true,
      createdAt: new Date(),
    };
  }

  static guest(): User {
    return {
      id: faker.string.uuid(),
      email: 'guest@test.com',
      name: 'Guest User',
      role: 'guest',
      active: false,
      createdAt: new Date(),
    };
  }

  // State-based
  static inactive(): User {
    return {
      ...this.john(),
      id: 'inactive-user-id',
      active: false,
    };
  }

  static deleted(): User {
    return {
      ...this.john(),
      id: 'deleted-user-id',
      active: false,
      deletedAt: new Date(),
    } as User & { deletedAt: Date };
  }

  // Random valid data
  static random(): User {
    return {
      id: faker.string.uuid(),
      email: faker.internet.email(),
      name: faker.person.fullName(),
      role: faker.helpers.arrayElement(['admin', 'member', 'guest']),
      active: faker.datatype.boolean(),
      createdAt: faker.date.past(),
    };
  }

  // Multiple users
  static randomList(count: number): User[] {
    return Array.from({ length: count }, () => this.random());
  }

  // With customization
  static with(overrides: Partial<User>): User {
    return { ...this.john(), ...overrides };
  }
}
```

## Object Mother with Relationships

```typescript
interface Order {
  id: string;
  userId: string;
  items: OrderItem[];
  status: 'pending' | 'confirmed' | 'shipped';
  total: number;
}

interface OrderItem {
  productId: string;
  name: string;
  quantity: number;
  price: number;
}

class ProductMother {
  static widget(): OrderItem {
    return {
      productId: 'widget-id',
      name: 'Widget',
      quantity: 1,
      price: 29.99,
    };
  }

  static gadget(): OrderItem {
    return {
      productId: 'gadget-id',
      name: 'Gadget',
      quantity: 1,
      price: 49.99,
    };
  }

  static random(): OrderItem {
    return {
      productId: faker.string.uuid(),
      name: faker.commerce.productName(),
      quantity: faker.number.int({ min: 1, max: 10 }),
      price: parseFloat(faker.commerce.price()),
    };
  }
}

class OrderMother {
  static pending(): Order {
    const items = [ProductMother.widget()];
    return {
      id: 'pending-order-id',
      userId: UserMother.john().id,
      items,
      status: 'pending',
      total: items.reduce((sum, i) => sum + i.quantity * i.price, 0),
    };
  }

  static confirmed(): Order {
    return {
      ...this.pending(),
      id: 'confirmed-order-id',
      status: 'confirmed',
    };
  }

  static shipped(): Order {
    return {
      ...this.pending(),
      id: 'shipped-order-id',
      status: 'shipped',
    };
  }

  static forUser(user: User): Order {
    return {
      ...this.pending(),
      id: faker.string.uuid(),
      userId: user.id,
    };
  }

  static withItems(items: OrderItem[]): Order {
    return {
      ...this.pending(),
      id: faker.string.uuid(),
      items,
      total: items.reduce((sum, i) => sum + i.quantity * i.price, 0),
    };
  }

  static expensive(): Order {
    const items = Array.from({ length: 10 }, () => ({
      ...ProductMother.random(),
      price: 999.99,
      quantity: 5,
    }));
    return this.withItems(items);
  }
}
```

## Combining with Builder

```typescript
class UserMother {
  private static builder(): UserBuilder {
    return new UserBuilder();
  }

  static john(): User {
    return this.builder()
      .withId('john-id')
      .withEmail('john.doe@test.com')
      .withName('John Doe')
      .build();
  }

  static admin(): User {
    return this.builder().asAdmin().withName('Admin User').build();
  }

  static johnAsAdmin(): User {
    return this.builder()
      .withId('john-id')
      .withEmail('john.doe@test.com')
      .withName('John Doe')
      .asAdmin()
      .build();
  }

  static custom(): UserBuilder {
    return this.builder();
  }
}

// Usage
const admin = UserMother.admin();
const customUser = UserMother.custom().withEmail('custom@test.com').inactive().build();
```

## Scenario-Based Mothers

```typescript
class ScenarioMother {
  // Complete scenario with all related objects
  static userWithPendingOrders() {
    const user = UserMother.john();
    const orders = [OrderMother.forUser(user), OrderMother.forUser(user)];

    return { user, orders };
  }

  static userWithNoOrders() {
    const user = UserMother.jane();
    return { user, orders: [] };
  }

  static adminWithFullAccess() {
    const user = UserMother.admin();
    const permissions = ['read', 'write', 'delete', 'admin'];
    const accessToken = 'admin-token-123';

    return { user, permissions, accessToken };
  }

  static expiredSession() {
    const user = UserMother.john();
    const session = {
      id: 'expired-session',
      userId: user.id,
      expiresAt: new Date(Date.now() - 1000), // Expired
    };

    return { user, session };
  }
}

// Usage in tests
describe('OrderService', () => {
  test('should list user orders', async () => {
    const { user, orders } = ScenarioMother.userWithPendingOrders();

    // Setup
    await userRepo.save(user);
    for (const order of orders) {
      await orderRepo.save(order);
    }

    const service = new OrderService(orderRepo);
    const result = await service.listForUser(user.id);

    expect(result).toHaveLength(2);
  });

  test('should return empty for user with no orders', async () => {
    const { user, orders } = ScenarioMother.userWithNoOrders();

    await userRepo.save(user);

    const service = new OrderService(orderRepo);
    const result = await service.listForUser(user.id);

    expect(result).toHaveLength(0);
  });
});
```

## Database Seeding with Mothers

```typescript
class TestDatabaseSeeder {
  constructor(
    private userRepo: UserRepository,
    private orderRepo: OrderRepository,
  ) {}

  async seedBasic(): Promise<void> {
    await this.userRepo.save(UserMother.john());
    await this.userRepo.save(UserMother.jane());
    await this.userRepo.save(UserMother.admin());
  }

  async seedWithOrders(): Promise<void> {
    await this.seedBasic();

    const john = UserMother.john();
    await this.orderRepo.save(OrderMother.forUser(john));
    await this.orderRepo.save(OrderMother.forUser(john));
  }

  async seedStressTest(): Promise<void> {
    const users = UserMother.randomList(100);
    for (const user of users) {
      await this.userRepo.save(user);
      const orderCount = faker.number.int({ min: 0, max: 10 });
      for (let i = 0; i < orderCount; i++) {
        await this.orderRepo.save(OrderMother.forUser(user));
      }
    }
  }
}
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `@faker-js/faker` | Donnees aleatoires realistes |
| `fishery` | Factory with traits |
| `factory-girl` | ActiveRecord-style factories |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| IDs dupliques | Conflits en DB | UUIDs ou IDs uniques par scenario |
| Donnees mutables | Tests dependants | Toujours retourner nouvelles instances |
| Mothers trop specifiques | Explosion de methodes | Combiner avec Builder |
| Pas de scenarios | Setup repete | Ajouter ScenarioMother |
| Donnees irrealistes | Bugs non detectes | Faker pour donnees valides |

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| Personas recurrentes (John, Jane) | Oui |
| Scenarios metier types | Oui |
| Donnees de test coherentes | Oui |
| Objets tres variables | Builder prefere |
| Donnees uniques par test | random() methods |

## Patterns lies

- **Test Data Builder** : Flexibilite complementaire
- **Fixture** : Object Mothers peuplent les fixtures
- **Factory** : Pattern sous-jacent

## Sources

- [Object Mother - Martin Fowler](https://martinfowler.com/bliki/ObjectMother.html)
- [Growing Object-Oriented Software](http://www.growing-object-oriented-software.com/)
