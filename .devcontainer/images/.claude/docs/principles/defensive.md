# Defensive Programming Patterns

Patterns pour protéger le code contre les erreurs et données invalides.

## 1. Guard Clauses (Early Return)

> Valider les préconditions en début de fonction et sortir immédiatement si invalide.

```typescript
// ❌ MAUVAIS - Nested conditions
function processOrder(order: Order | null, user: User | null) {
  if (order) {
    if (user) {
      if (order.items.length > 0) {
        if (user.isActive) {
          // Logic buried deep
          return calculateTotal(order);
        } else {
          throw new Error('User inactive');
        }
      } else {
        throw new Error('Empty order');
      }
    } else {
      throw new Error('No user');
    }
  } else {
    throw new Error('No order');
  }
}

// ✅ BON - Guard clauses
function processOrder(order: Order | null, user: User | null) {
  // Guards - validate all preconditions first
  if (!order) throw new Error('No order');
  if (!user) throw new Error('No user');
  if (order.items.length === 0) throw new Error('Empty order');
  if (!user.isActive) throw new Error('User inactive');

  // Happy path - logic is clear and flat
  return calculateTotal(order);
}
```

**Règle :** Toutes les validations en haut, logique métier en bas.

---

## 2. Assertion / Precondition

> Vérifier les invariants avec des assertions explicites.

```typescript
function assert(condition: boolean, message: string): asserts condition {
  if (!condition) {
    throw new AssertionError(message);
  }
}

function assertDefined<T>(value: T | null | undefined, name: string): asserts value is T {
  if (value === null || value === undefined) {
    throw new AssertionError(`${name} must be defined`);
  }
}

function assertPositive(value: number, name: string): asserts value {
  if (value <= 0) {
    throw new AssertionError(`${name} must be positive, got ${value}`);
  }
}

// Usage
function divide(a: number, b: number): number {
  assertDefined(a, 'numerator');
  assertDefined(b, 'denominator');
  assert(b !== 0, 'Cannot divide by zero');

  return a / b;
}

function withdraw(account: Account, amount: number): void {
  assertDefined(account, 'account');
  assertPositive(amount, 'amount');
  assert(account.balance >= amount, 'Insufficient funds');

  account.balance -= amount;
}
```

---

## 3. Null Object Pattern

> Remplacer null par un objet neutre avec comportement par défaut.

```typescript
// Interface
interface Logger {
  log(message: string): void;
  error(message: string): void;
}

// Real implementation
class ConsoleLogger implements Logger {
  log(message: string) { console.log(message); }
  error(message: string) { console.error(message); }
}

// Null Object - does nothing but is safe to use
class NullLogger implements Logger {
  log(_message: string) { /* no-op */ }
  error(_message: string) { /* no-op */ }
}

// Usage - no null checks needed
class OrderService {
  constructor(private logger: Logger = new NullLogger()) {}

  process(order: Order) {
    this.logger.log(`Processing order ${order.id}`);
    // ... logic
    this.logger.log('Order processed');
  }
}

// Both work without null checks
new OrderService(new ConsoleLogger()).process(order);
new OrderService().process(order); // Uses NullLogger
```

**Autres exemples :**
```typescript
// Null User
class GuestUser implements User {
  readonly id = 'guest';
  readonly name = 'Guest';
  hasPermission(_perm: string) { return false; }
}

// Null Collection
const emptyList: readonly never[] = Object.freeze([]);

// Null Money
class ZeroMoney implements Money {
  readonly amount = 0;
  add(other: Money) { return other; }
  multiply(_factor: number) { return this; }
}
```

---

## 4. Optional Chaining & Nullish Coalescing

> Accès sécurisé aux propriétés potentiellement nulles.

```typescript
// Optional chaining (?.)
const street = user?.address?.street; // undefined if any is null

// Nullish coalescing (??)
const name = user?.name ?? 'Anonymous'; // 'Anonymous' only if null/undefined

// Combined with method calls
const upper = user?.name?.toUpperCase() ?? 'N/A';

// With arrays
const firstItem = items?.[0];

// With function calls
const result = callback?.();

// ❌ ATTENTION: ?? vs ||
const count1 = value || 10;  // 10 if value is 0, '', false, null, undefined
const count2 = value ?? 10;  // 10 only if value is null or undefined

// ✅ Préférer ?? pour les valeurs qui peuvent être 0 ou ''
const port = config.port ?? 3000;  // Correct: 0 is valid
const name = config.name ?? 'default';  // Correct: '' might be valid
```

---

## 5. Default Values Pattern

> Fournir des valeurs par défaut sûres.

```typescript
// Function parameters
function createUser(
  name: string,
  email: string,
  role: Role = 'member',
  active: boolean = true,
) {
  return { name, email, role, active };
}

// Object destructuring with defaults
function processConfig({
  timeout = 5000,
  retries = 3,
  baseUrl = 'https://api.example.com',
}: Partial<Config> = {}) {
  // All values guaranteed
}

// Default object pattern
const DEFAULT_CONFIG: Config = {
  timeout: 5000,
  retries: 3,
  baseUrl: 'https://api.example.com',
};

function init(userConfig: Partial<Config> = {}) {
  const config = { ...DEFAULT_CONFIG, ...userConfig };
  // All values guaranteed
}

// Builder with defaults
class RequestBuilder {
  private config: RequestConfig = {
    method: 'GET',
    headers: {},
    timeout: 30000,
    retries: 0,
  };

  method(m: Method) { this.config.method = m; return this; }
  timeout(ms: number) { this.config.timeout = ms; return this; }
  // ... always has valid defaults
}
```

---

## 6. Fail-Fast Pattern

> Échouer immédiatement avec message clair plutôt que propager l'erreur.

```typescript
class DatabaseConnection {
  constructor(config: DbConfig) {
    // Fail fast - validate everything at construction
    if (!config.host) {
      throw new ConfigError('Database host is required');
    }
    if (!config.port || config.port < 1 || config.port > 65535) {
      throw new ConfigError(`Invalid port: ${config.port}`);
    }
    if (!config.database) {
      throw new ConfigError('Database name is required');
    }

    // If we get here, config is valid
    this.connect(config);
  }
}

// Fail fast in factory
class UserFactory {
  static create(data: unknown): User {
    // Validate and fail fast
    if (!isObject(data)) {
      throw new ValidationError('User data must be an object');
    }
    if (typeof data.email !== 'string') {
      throw new ValidationError('Email is required');
    }
    if (!isValidEmail(data.email)) {
      throw new ValidationError(`Invalid email format: ${data.email}`);
    }

    // Only create if valid
    return new User(data as UserData);
  }
}
```

---

## 7. Input Validation Pattern

> Valider toutes les entrées aux frontières du système.

```typescript
import { z } from 'zod';

// Schema-based validation
const UserSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(100),
  age: z.number().int().min(0).max(150).optional(),
  role: z.enum(['admin', 'user', 'guest']).default('user'),
});

type User = z.infer<typeof UserSchema>;

// Validate at boundary
function createUser(input: unknown): User {
  // Throws ZodError with details if invalid
  return UserSchema.parse(input);
}

// Safe parse (no throw)
function tryCreateUser(input: unknown): User | null {
  const result = UserSchema.safeParse(input);
  if (result.success) {
    return result.data;
  }
  console.error('Validation failed:', result.error.issues);
  return null;
}

// Validation with custom refinements
const OrderSchema = z.object({
  items: z.array(z.object({
    productId: z.string().uuid(),
    quantity: z.number().int().positive(),
  })).min(1, 'Order must have at least one item'),

  shippingDate: z.date().refine(
    (date) => date > new Date(),
    'Shipping date must be in the future'
  ),
});
```

---

## 8. Type Narrowing / Type Guards

> Réduire progressivement les types possibles.

```typescript
// Type guard function
function isString(value: unknown): value is string {
  return typeof value === 'string';
}

function isUser(value: unknown): value is User {
  return (
    typeof value === 'object' &&
    value !== null &&
    'id' in value &&
    'email' in value
  );
}

// Usage
function processValue(value: unknown) {
  if (isString(value)) {
    // TypeScript knows value is string here
    console.log(value.toUpperCase());
  }

  if (isUser(value)) {
    // TypeScript knows value is User here
    console.log(value.email);
  }
}

// Discriminated unions
type Result<T> =
  | { success: true; data: T }
  | { success: false; error: Error };

function handleResult<T>(result: Result<T>) {
  if (result.success) {
    // TypeScript knows result.data exists
    console.log(result.data);
  } else {
    // TypeScript knows result.error exists
    console.error(result.error.message);
  }
}

// Assertion function
function assertIsUser(value: unknown): asserts value is User {
  if (!isUser(value)) {
    throw new TypeError('Expected User object');
  }
}

function processUser(value: unknown) {
  assertIsUser(value);
  // TypeScript knows value is User after assertion
  console.log(value.email);
}
```

---

## 9. Immutable by Default

> Rendre les données immutables pour éviter les modifications accidentelles.

```typescript
// Readonly types
interface User {
  readonly id: string;
  readonly email: string;
  readonly createdAt: Date;
  name: string; // Only name is mutable
}

// Deep readonly
type DeepReadonly<T> = {
  readonly [P in keyof T]: T[P] extends object
    ? DeepReadonly<T[P]>
    : T[P];
};

// Freeze objects
const CONFIG = Object.freeze({
  apiUrl: 'https://api.example.com',
  timeout: 5000,
});

// CONFIG.apiUrl = 'x'; // Error at runtime

// Immutable updates
function updateUser(user: User, updates: Partial<User>): User {
  return { ...user, ...updates };
}

// With Immer for complex updates
import produce from 'immer';

const nextState = produce(state, (draft) => {
  draft.users[0].name = 'New Name';
  draft.users.push({ id: '2', name: 'New User' });
});
// Original state unchanged
```

---

## 10. Dependency Validation

> Valider que toutes les dépendances sont présentes et valides au démarrage.

```typescript
class Application {
  private readonly db: Database;
  private readonly cache: Cache;
  private readonly logger: Logger;

  constructor(deps: ApplicationDependencies) {
    // Validate all dependencies at startup
    this.db = this.validateDependency(deps.db, 'Database');
    this.cache = this.validateDependency(deps.cache, 'Cache');
    this.logger = this.validateDependency(deps.logger, 'Logger');
  }

  private validateDependency<T>(dep: T | undefined, name: string): T {
    if (!dep) {
      throw new DependencyError(`${name} is required but was not provided`);
    }
    return dep;
  }

  async start() {
    // Verify connections work
    await this.verifyDependencies();
    this.logger.log('Application started');
  }

  private async verifyDependencies() {
    const checks = [
      this.db.ping().catch(() => { throw new Error('Database unavailable'); }),
      this.cache.ping().catch(() => { throw new Error('Cache unavailable'); }),
    ];
    await Promise.all(checks);
  }
}

// Factory with validation
class ServiceFactory {
  static create(config: ServiceConfig): Service {
    // Validate config
    const validated = this.validateConfig(config);

    // Validate environment
    this.validateEnvironment();

    // Create with validated dependencies
    return new Service(validated);
  }

  private static validateConfig(config: ServiceConfig): ValidatedConfig {
    const errors: string[] = [];

    if (!config.apiKey) errors.push('API key is required');
    if (!config.endpoint) errors.push('Endpoint is required');
    if (config.timeout && config.timeout < 0) errors.push('Timeout must be positive');

    if (errors.length > 0) {
      throw new ConfigurationError(`Invalid config: ${errors.join(', ')}`);
    }

    return config as ValidatedConfig;
  }

  private static validateEnvironment() {
    const required = ['NODE_ENV', 'API_SECRET'];
    const missing = required.filter((key) => !process.env[key]);

    if (missing.length > 0) {
      throw new EnvironmentError(`Missing env vars: ${missing.join(', ')}`);
    }
  }
}
```

---

## 11. Contract / Design by Contract

> Définir préconditions, postconditions et invariants.

```typescript
class BankAccount {
  private _balance: number;

  constructor(initialBalance: number) {
    // Precondition
    this.requireNonNegative(initialBalance, 'Initial balance');
    this._balance = initialBalance;
  }

  get balance(): number {
    return this._balance;
  }

  deposit(amount: number): void {
    // Preconditions
    this.requirePositive(amount, 'Deposit amount');

    const oldBalance = this._balance;
    this._balance += amount;

    // Postcondition
    this.ensure(
      this._balance === oldBalance + amount,
      'Balance should increase by deposit amount'
    );

    // Invariant
    this.checkInvariant();
  }

  withdraw(amount: number): void {
    // Preconditions
    this.requirePositive(amount, 'Withdrawal amount');
    this.require(
      amount <= this._balance,
      `Insufficient funds: ${amount} > ${this._balance}`
    );

    const oldBalance = this._balance;
    this._balance -= amount;

    // Postcondition
    this.ensure(
      this._balance === oldBalance - amount,
      'Balance should decrease by withdrawal amount'
    );

    // Invariant
    this.checkInvariant();
  }

  // Invariant: balance should never be negative
  private checkInvariant(): void {
    this.ensure(this._balance >= 0, 'Balance invariant violated');
  }

  // Helpers
  private require(condition: boolean, message: string): void {
    if (!condition) throw new PreconditionError(message);
  }

  private requirePositive(value: number, name: string): void {
    this.require(value > 0, `${name} must be positive`);
  }

  private requireNonNegative(value: number, name: string): void {
    this.require(value >= 0, `${name} must be non-negative`);
  }

  private ensure(condition: boolean, message: string): void {
    if (!condition) throw new PostconditionError(message);
  }
}
```

---

## Tableau de décision

| Problème | Pattern |
|----------|---------|
| Conditions imbriquées | Guard Clauses |
| Vérifier invariants | Assertions |
| Éviter null checks | Null Object |
| Accès propriétés nullables | Optional Chaining |
| Valeurs manquantes | Default Values |
| Erreurs silencieuses | Fail-Fast |
| Données externes | Input Validation |
| Types inconnus | Type Guards |
| Modifications accidentelles | Immutability |
| Dépendances manquantes | Dependency Validation |
| Garanties formelles | Design by Contract |

## Sources

- [Defensive Programming - Wikipedia](https://en.wikipedia.org/wiki/Defensive_programming)
- [Design by Contract - Bertrand Meyer](https://en.wikipedia.org/wiki/Design_by_contract)
- [Guard Clause - Refactoring Guru](https://refactoring.guru/replace-nested-conditional-with-guard-clauses)
