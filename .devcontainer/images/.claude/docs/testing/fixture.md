# Test Fixtures

> Configuration et donnees partagees pour les tests.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                      Test Fixture Lifecycle                      │
│                                                                  │
│   beforeAll ──► beforeEach ──► Test ──► afterEach ──► afterAll  │
│       │             │           │           │             │      │
│       ▼             ▼           ▼           ▼             ▼      │
│   Setup once    Reset state   Execute   Cleanup       Teardown   │
│   (DB, server)  (clear data)   test     (rollback)   (close)    │
└─────────────────────────────────────────────────────────────────┘
```

## Fixture Class Pattern

```typescript
interface TestFixture {
  setup(): Promise<void>;
  teardown(): Promise<void>;
}

class DatabaseFixture implements TestFixture {
  db!: Database;
  userRepo!: UserRepository;
  orderRepo!: OrderRepository;

  async setup(): Promise<void> {
    this.db = await Database.connect(process.env.TEST_DATABASE_URL!);
    await this.db.migrate();

    this.userRepo = new UserRepository(this.db);
    this.orderRepo = new OrderRepository(this.db);

    await this.seed();
  }

  async teardown(): Promise<void> {
    await this.db.close();
  }

  private async seed(): Promise<void> {
    await this.userRepo.save(UserMother.john());
    await this.userRepo.save(UserMother.jane());
  }

  async reset(): Promise<void> {
    await this.db.truncateAll();
    await this.seed();
  }
}

// Usage
describe('OrderService', () => {
  const fixture = new DatabaseFixture();

  beforeAll(async () => {
    await fixture.setup();
  });

  afterAll(async () => {
    await fixture.teardown();
  });

  beforeEach(async () => {
    await fixture.reset();
  });

  test('should create order', async () => {
    const service = new OrderService(fixture.orderRepo, fixture.userRepo);
    const order = await service.create('john-id', [{ productId: '1', qty: 2 }]);

    expect(order.status).toBe('pending');
  });
});
```

## Composable Fixtures

```typescript
class HttpFixture implements TestFixture {
  server!: Server;
  baseUrl!: string;

  async setup(): Promise<void> {
    const app = createApp();
    this.server = await new Promise((resolve) => {
      const s = app.listen(0, () => resolve(s));
    });
    this.baseUrl = `http://localhost:${(this.server.address() as any).port}`;
  }

  async teardown(): Promise<void> {
    await new Promise((resolve) => this.server.close(resolve));
  }
}

class CompositeFixture implements TestFixture {
  private fixtures: TestFixture[] = [];

  add(fixture: TestFixture): this {
    this.fixtures.push(fixture);
    return this;
  }

  async setup(): Promise<void> {
    for (const fixture of this.fixtures) {
      await fixture.setup();
    }
  }

  async teardown(): Promise<void> {
    // Teardown in reverse order
    for (const fixture of [...this.fixtures].reverse()) {
      await fixture.teardown();
    }
  }
}

// Usage
describe('Integration Tests', () => {
  const dbFixture = new DatabaseFixture();
  const httpFixture = new HttpFixture();
  const fixture = new CompositeFixture().add(dbFixture).add(httpFixture);

  beforeAll(() => fixture.setup());
  afterAll(() => fixture.teardown());

  test('API should return users', async () => {
    const response = await fetch(`${httpFixture.baseUrl}/users`);
    const users = await response.json();

    expect(users).toHaveLength(2); // Seeded users
  });
});
```

## JSON Fixtures

```typescript
// fixtures/users.json
[
  {
    "id": "user-1",
    "name": "John Doe",
    "email": "john@test.com",
    "role": "admin"
  },
  {
    "id": "user-2",
    "name": "Jane Doe",
    "email": "jane@test.com",
    "role": "member"
  }
]

// fixtures/orders.json
[
  {
    "id": "order-1",
    "userId": "user-1",
    "items": [{ "productId": "prod-1", "quantity": 2 }],
    "status": "pending"
  }
]

// Fixture loader
import fs from 'fs/promises';
import path from 'path';

class JsonFixtureLoader {
  constructor(private fixturesDir: string = './fixtures') {}

  async load<T>(name: string): Promise<T> {
    const filePath = path.join(this.fixturesDir, `${name}.json`);
    const content = await fs.readFile(filePath, 'utf-8');
    return JSON.parse(content);
  }

  async loadAll<T>(name: string): Promise<T[]> {
    return this.load<T[]>(name);
  }
}

// Usage
describe('with JSON fixtures', () => {
  const loader = new JsonFixtureLoader();
  let users: User[];
  let orders: Order[];

  beforeAll(async () => {
    users = await loader.loadAll<User>('users');
    orders = await loader.loadAll<Order>('orders');
  });

  test('should have seeded users', () => {
    expect(users).toHaveLength(2);
    expect(users[0].name).toBe('John Doe');
  });
});
```

## Scoped Fixtures (Per-test data)

```typescript
class ScopedFixture<T> {
  private data: T | null = null;
  private cleanup: (() => Promise<void>) | null = null;

  async use(factory: () => Promise<{ data: T; cleanup: () => Promise<void> }>) {
    const result = await factory();
    this.data = result.data;
    this.cleanup = result.cleanup;
    return this.data;
  }

  get(): T {
    if (!this.data) {
      throw new Error('Fixture not initialized');
    }
    return this.data;
  }

  async dispose(): Promise<void> {
    if (this.cleanup) {
      await this.cleanup();
    }
    this.data = null;
    this.cleanup = null;
  }
}

// Usage
describe('OrderService', () => {
  const userFixture = new ScopedFixture<User>();

  afterEach(async () => {
    await userFixture.dispose();
  });

  test('admin can delete orders', async () => {
    const user = await userFixture.use(async () => {
      const data = await createUser({ role: 'admin' });
      return {
        data,
        cleanup: () => deleteUser(data.id),
      };
    });

    const service = new OrderService();
    await service.deleteOrder('order-1', user);

    expect(await service.getOrder('order-1')).toBeNull();
  });

  test('member cannot delete orders', async () => {
    const user = await userFixture.use(async () => {
      const data = await createUser({ role: 'member' });
      return {
        data,
        cleanup: () => deleteUser(data.id),
      };
    });

    const service = new OrderService();

    await expect(service.deleteOrder('order-1', user)).rejects.toThrow(
      'Forbidden',
    );
  });
});
```

## Transaction Rollback Fixture

```typescript
class TransactionFixture implements TestFixture {
  private db!: Database;
  private transaction!: Transaction;

  constructor(private connectionString: string) {}

  async setup(): Promise<void> {
    this.db = await Database.connect(this.connectionString);
    this.transaction = await this.db.beginTransaction();
  }

  async teardown(): Promise<void> {
    await this.transaction.rollback(); // Always rollback
    await this.db.close();
  }

  getConnection(): Database {
    return this.transaction as unknown as Database;
  }
}

// Usage - Each test is isolated via transaction rollback
describe('UserRepository', () => {
  const fixture = new TransactionFixture(process.env.TEST_DB_URL!);

  beforeAll(() => fixture.setup());
  afterAll(() => fixture.teardown());

  test('should create user', async () => {
    const repo = new UserRepository(fixture.getConnection());
    await repo.save({ id: '1', name: 'Test' });

    const user = await repo.findById('1');
    expect(user?.name).toBe('Test');
    // Transaction will be rolled back - no cleanup needed
  });
});
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `jest` | Built-in beforeAll/afterAll |
| `vitest` | Same lifecycle hooks |
| `testcontainers` | Container-based fixtures |
| `factory-girl` | Fixture factories |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Setup dans chaque test | Tests lents | beforeAll pour setup couteux |
| Pas de cleanup | State leak entre tests | afterEach/afterAll |
| Fixtures mutables partagees | Tests dependants | Reset ou copie profonde |
| Ordre des tests compte | Flaky tests | Isolation complete |
| Fixtures trop grosses | Slow tests | Fixtures minimales par suite |

## Quand utiliser

| Scenario | Type de Fixture |
|----------|-----------------|
| Database tests | Transaction rollback |
| API tests | HTTP server fixture |
| Complex object graphs | JSON fixtures + loaders |
| Per-test isolation | Scoped fixtures |
| Shared expensive resources | beforeAll setup |

## Patterns lies

- **Object Mother** : Factory pour objets de fixture
- **Test Data Builder** : Construction fluide de fixtures
- **Test Containers** : Fixtures avec containers Docker

## Sources

- [xUnit Test Patterns - Fixtures](http://xunitpatterns.com/test%20fixture%20-%20xUnit.html)
- [Jest Setup/Teardown](https://jestjs.io/docs/setup-teardown)
