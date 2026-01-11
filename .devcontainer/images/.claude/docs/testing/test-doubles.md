# Test Doubles

> Objets de substitution pour isoler le code sous test.

## Types de Test Doubles

```
┌─────────────────────────────────────────────────────────────────┐
│                      Test Doubles Spectrum                       │
│                                                                  │
│   Dummy ◄──── Stub ◄──── Spy ◄──── Mock ◄──── Fake             │
│     │          │          │          │          │               │
│   Placeholder  Returns    Records    Verifies   Working         │
│   (unused)     canned     calls      behavior   implementation  │
│                values                                            │
└─────────────────────────────────────────────────────────────────┘
```

| Type | Retourne | Verifie | Comportement |
|------|----------|---------|--------------|
| **Dummy** | Rien | Non | Remplit un parametre |
| **Stub** | Valeurs fixes | Non | Controle indirect input |
| **Spy** | Vraies valeurs | Appels | Observe sans remplacer |
| **Mock** | Configure | Interactions | Verifie comportement |
| **Fake** | Vraies valeurs | Non | Implementation simplifiee |

## Dummy

```typescript
// Dummy - Placeholder for unused dependencies
class DummyLogger implements Logger {
  log(message: string): void {
    // Does nothing - parameter required but not used in test
  }
  error(message: string): void {}
  warn(message: string): void {}
}

// Usage
test('should calculate total without logging', () => {
  const calculator = new Calculator(new DummyLogger());
  expect(calculator.add(2, 3)).toBe(5);
  // Logger is required by constructor but not relevant for this test
});
```

## Stub

```typescript
// Stub - Returns predefined values
class StubUserRepository implements UserRepository {
  private users: User[] = [];

  setUsers(users: User[]): void {
    this.users = users;
  }

  async findById(id: string): Promise<User | null> {
    return this.users.find((u) => u.id === id) || null;
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.users.find((u) => u.email === email) || null;
  }

  async save(user: User): Promise<void> {
    this.users.push(user);
  }
}

// Usage
test('should return user profile when user exists', async () => {
  const stub = new StubUserRepository();
  stub.setUsers([{ id: '1', name: 'John', email: 'john@test.com' }]);

  const service = new ProfileService(stub);
  const profile = await service.getProfile('1');

  expect(profile.name).toBe('John');
});

// Jest stub
test('with Jest stub', async () => {
  const repo = {
    findById: jest.fn().mockResolvedValue({ id: '1', name: 'John' }),
  };

  const service = new ProfileService(repo as any);
  const profile = await service.getProfile('1');

  expect(profile.name).toBe('John');
});
```

## Spy

```typescript
// Manual Spy - Records calls while using real implementation
function createSpy<T extends (...args: any[]) => any>(
  fn: T,
): T & { calls: Parameters<T>[]; callCount: number } {
  const calls: Parameters<T>[] = [];

  const spy = ((...args: Parameters<T>) => {
    calls.push(args);
    return fn(...args);
  }) as T & { calls: Parameters<T>[]; callCount: number };

  Object.defineProperty(spy, 'calls', { get: () => calls });
  Object.defineProperty(spy, 'callCount', { get: () => calls.length });

  return spy;
}

// Usage
test('should call repository with correct id', async () => {
  const realRepo = new UserRepository(db);
  const findByIdSpy = createSpy(realRepo.findById.bind(realRepo));
  realRepo.findById = findByIdSpy;

  const service = new ProfileService(realRepo);
  await service.getProfile('123');

  expect(findByIdSpy.callCount).toBe(1);
  expect(findByIdSpy.calls[0][0]).toBe('123');
});

// Jest spy
test('with Jest spy', async () => {
  const repo = new UserRepository(db);
  const spy = jest.spyOn(repo, 'findById');

  const service = new ProfileService(repo);
  await service.getProfile('123');

  expect(spy).toHaveBeenCalledWith('123');
  expect(spy).toHaveBeenCalledTimes(1);
});
```

## Mock

```typescript
// Manual Mock - Verifies interactions
class MockEmailService implements EmailService {
  private expectations: Array<{
    method: string;
    args?: any[];
    called: boolean;
  }> = [];

  async send(to: string, subject: string, body: string): Promise<void> {
    const expectation = this.expectations.find(
      (e) => e.method === 'send' && !e.called,
    );
    if (expectation) {
      expectation.called = true;
    }
  }

  expectSend(to: string, subject: string): this {
    this.expectations.push({
      method: 'send',
      args: [to, subject],
      called: false,
    });
    return this;
  }

  verify(): void {
    const unmet = this.expectations.filter((e) => !e.called);
    if (unmet.length > 0) {
      throw new Error(`Unmet expectations: ${JSON.stringify(unmet)}`);
    }
  }
}

// Usage
test('should send welcome email on registration', async () => {
  const mockEmail = new MockEmailService();
  mockEmail.expectSend('user@test.com', 'Welcome!');

  const service = new UserService(mockEmail);
  await service.register({ email: 'user@test.com', name: 'John' });

  mockEmail.verify(); // Throws if expectation not met
});

// Jest mock
test('with Jest mock', async () => {
  const mockEmail = {
    send: jest.fn().mockResolvedValue(undefined),
  };

  const service = new UserService(mockEmail as any);
  await service.register({ email: 'user@test.com', name: 'John' });

  expect(mockEmail.send).toHaveBeenCalledWith(
    'user@test.com',
    'Welcome!',
    expect.stringContaining('Thank you'),
  );
});
```

## Fake

```typescript
// Fake - Simplified working implementation
class FakeUserRepository implements UserRepository {
  private users = new Map<string, User>();
  private emailIndex = new Map<string, string>();

  async findById(id: string): Promise<User | null> {
    return this.users.get(id) || null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const id = this.emailIndex.get(email);
    return id ? this.users.get(id) || null : null;
  }

  async save(user: User): Promise<void> {
    this.users.set(user.id, { ...user });
    this.emailIndex.set(user.email, user.id);
  }

  async delete(id: string): Promise<void> {
    const user = this.users.get(id);
    if (user) {
      this.emailIndex.delete(user.email);
      this.users.delete(id);
    }
  }

  // Test helpers
  clear(): void {
    this.users.clear();
    this.emailIndex.clear();
  }

  seed(users: User[]): void {
    users.forEach((u) => this.save(u));
  }
}

// Usage - Fake behaves like real implementation
test('should create and retrieve user', async () => {
  const fake = new FakeUserRepository();
  const service = new UserService(fake);

  await service.createUser({ id: '1', email: 'test@test.com', name: 'Test' });
  const user = await service.getUser('1');

  expect(user?.email).toBe('test@test.com');
});
```

## Comparaison Jest

```typescript
// Complete example with all types
describe('OrderService', () => {
  // Dummy
  const dummyLogger = { log: () => {}, error: () => {} };

  // Stub
  const stubInventory = {
    checkStock: jest.fn().mockResolvedValue(true),
    reserve: jest.fn().mockResolvedValue('reservation-123'),
  };

  // Spy
  test('should log order creation', async () => {
    const spy = jest.spyOn(console, 'log');
    const service = new OrderService(stubInventory, console);

    await service.createOrder({ productId: '1', quantity: 1 });

    expect(spy).toHaveBeenCalledWith(expect.stringContaining('Order created'));
  });

  // Mock with verification
  test('should send confirmation email', async () => {
    const mockEmail = { send: jest.fn() };
    const service = new OrderService(stubInventory, dummyLogger, mockEmail);

    await service.createOrder({ productId: '1', quantity: 1 });

    expect(mockEmail.send).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'order_confirmation' }),
    );
  });

  // Fake
  test('integration with fake repository', async () => {
    const fakeRepo = new FakeOrderRepository();
    const service = new OrderService(fakeRepo);

    const orderId = await service.createOrder({ productId: '1', quantity: 1 });
    const order = await service.getOrder(orderId);

    expect(order.status).toBe('pending');
  });
});
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `jest` | Built-in mocking |
| `vitest` | Jest-compatible, faster |
| `sinon` | Standalone mocking library |
| `ts-mockito` | Type-safe mocking |
| `testdouble` | Modern test double library |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Trop de mocks | Tests fragiles | Preferer fakes pour integration |
| Mock implementation details | Couplage fort | Mocker interfaces, pas implementations |
| Oublier verify() | Faux positifs | Toujours verifier expectations |
| Stub sans assertion | Test inutile | Verifier le resultat |
| Fake trop complexe | Maintenance lourde | Garder simple, pas de bugs |

## Quand utiliser

| Situation | Test Double |
|-----------|-------------|
| Parametre requis non utilise | Dummy |
| Controler les donnees d'entree | Stub |
| Observer sans modifier | Spy |
| Verifier les interactions | Mock |
| Integration avec etat | Fake |

## Patterns lies

- **Fixture** : Setup des test doubles
- **Object Mother** : Factory de test doubles configures
- **Dependency Injection** : Permet substitution facile

## Sources

- [xUnit Test Patterns - Gerard Meszaros](http://xunitpatterns.com/)
- [Mocks Aren't Stubs - Martin Fowler](https://martinfowler.com/articles/mocksArentStubs.html)
