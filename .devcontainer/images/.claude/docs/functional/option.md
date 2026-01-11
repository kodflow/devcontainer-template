# Option / Maybe Pattern

## Definition

**Option** (also called Maybe) is a type that represents an optional value: either a value exists (Some/Just) or it doesn't (None/Nothing). It eliminates null/undefined errors at compile time.

```
Option<A> = Some<A> | None
Maybe<A> = Just<A> | Nothing
```

**Key characteristics:**
- **Null-safety**: No null pointer exceptions
- **Explicit optionality**: Optional values in type signature
- **Composable**: Chain operations on optional values
- **Short-circuit**: None propagates through chains
- **Forces handling**: Must deal with absence explicitly

## TypeScript Implementation

```typescript
// Option type
type Option<A> = Some<A> | None<A>;

class Some<A> {
  readonly _tag = 'Some';
  constructor(readonly value: A) {}

  isSome(): this is Some<A> { return true; }
  isNone(): this is None<A> { return false; }

  map<B>(f: (a: A) => B): Option<B> {
    return new Some(f(this.value));
  }

  flatMap<B>(f: (a: A) => Option<B>): Option<B> {
    return f(this.value);
  }

  filter(predicate: (a: A) => boolean): Option<A> {
    return predicate(this.value) ? this : none();
  }

  getOrElse(_defaultValue: A): A {
    return this.value;
  }

  getOrElseL(_thunk: () => A): A {
    return this.value;
  }

  orElse(_alternative: () => Option<A>): Option<A> {
    return this;
  }

  match<B>(handlers: { some: (a: A) => B; none: () => B }): B {
    return handlers.some(this.value);
  }

  toNullable(): A | null {
    return this.value;
  }
}

class None<A> {
  readonly _tag = 'None';
  private static readonly INSTANCE = new None<never>();

  static instance<A>(): Option<A> {
    return None.INSTANCE as Option<A>;
  }

  isSome(): this is Some<A> { return false; }
  isNone(): this is None<A> { return true; }

  map<B>(_f: (a: A) => B): Option<B> {
    return none();
  }

  flatMap<B>(_f: (a: A) => Option<B>): Option<B> {
    return none();
  }

  filter(_predicate: (a: A) => boolean): Option<A> {
    return none();
  }

  getOrElse(defaultValue: A): A {
    return defaultValue;
  }

  getOrElseL(thunk: () => A): A {
    return thunk();
  }

  orElse(alternative: () => Option<A>): Option<A> {
    return alternative();
  }

  match<B>(handlers: { some: (a: A) => B; none: () => B }): B {
    return handlers.none();
  }

  toNullable(): A | null {
    return null;
  }
}

// Constructors
const some = <A>(value: A): Option<A> => new Some(value);
const none = <A = never>(): Option<A> => None.instance();

const fromNullable = <A>(value: A | null | undefined): Option<A> =>
  value === null || value === undefined ? none() : some(value);

const fromPredicate = <A>(
  value: A,
  predicate: (a: A) => boolean
): Option<A> =>
  predicate(value) ? some(value) : none();

// Combine Options
const combine = <T extends readonly Option<unknown>[]>(
  options: T
): Option<{ [K in keyof T]: T[K] extends Option<infer U> ? U : never }> => {
  const values: unknown[] = [];

  for (const option of options) {
    if (option.isNone()) return none();
    values.push((option as Some<unknown>).value);
  }

  return some(values as any);
};
```

## Usage Examples

```typescript
// Basic usage
const findUser = (id: string): Option<User> =>
  fromNullable(users.get(id));

const getUserName = (id: string): string =>
  findUser(id)
    .map(user => user.name)
    .getOrElse('Anonymous');

// Chaining operations
interface Company { ceo: User | null }
interface User { email: string | null; company: Company | null }

const getCeoEmail = (user: User): Option<string> =>
  fromNullable(user.company)
    .flatMap(company => fromNullable(company.ceo))
    .flatMap(ceo => fromNullable(ceo.email));

// vs null checks
const getCeoEmailUnsafe = (user: User): string | null => {
  if (user.company === null) return null;
  if (user.company.ceo === null) return null;
  return user.company.ceo.email;
};

// Array operations with Option
const numbers = [1, 2, 3, 4, 5];

const findEven = (arr: number[]): Option<number> =>
  fromNullable(arr.find(n => n % 2 === 0));

const findOdd = (arr: number[]): Option<number> =>
  fromNullable(arr.find(n => n % 2 !== 0));

// First matching value
const firstEvenOrOdd = findEven(numbers).orElse(() => findOdd(numbers));

// Filter example
const getAdultUser = (id: string): Option<User> =>
  findUser(id).filter(user => user.age >= 18);

// Conditional transformation
const applyDiscount = (
  userId: string,
  amount: number
): Option<Money> =>
  findUser(userId)
    .filter(user => user.isPremium)
    .map(user => calculateDiscount(user, amount));
```

## Using fp-ts

```typescript
import { pipe } from 'fp-ts/function';
import * as O from 'fp-ts/Option';
import * as A from 'fp-ts/Array';

// Basic operations
const findUser = (id: string): O.Option<User> =>
  pipe(
    users.get(id),
    O.fromNullable
  );

const getUserEmail = (id: string): string =>
  pipe(
    findUser(id),
    O.map(user => user.email),
    O.getOrElse(() => 'no-email@example.com')
  );

// Chain multiple Options
const getCompanyCeoEmail = (user: User): O.Option<string> =>
  pipe(
    O.fromNullable(user.company),
    O.flatMap(c => O.fromNullable(c.ceo)),
    O.flatMap(ceo => O.fromNullable(ceo.email))
  );

// Working with arrays
const users: User[] = [/* ... */];

const premiumEmails = pipe(
  users,
  A.filter(u => u.isPremium),
  A.map(u => u.email),
  A.filterMap(O.fromNullable) // Remove nulls
);

// Applicative - combine Options
const createOrder = (
  userId: string,
  productId: string
): O.Option<Order> =>
  pipe(
    O.Do,
    O.apS('user', findUser(userId)),
    O.apS('product', findProduct(productId)),
    O.map(({ user, product }) => new Order(user, product))
  );

// Alternative patterns
const getConfigValue = (key: string): O.Option<string> =>
  pipe(
    O.fromNullable(process.env[key]),
    O.alt(() => O.fromNullable(configFile[key])),
    O.alt(() => O.some(defaults[key]))
  );

// Refinement
interface Admin extends User { readonly role: 'admin' }

const isAdmin = (user: User): user is Admin => user.role === 'admin';

const getAdmin = (id: string): O.Option<Admin> =>
  pipe(
    findUser(id),
    O.filter(isAdmin)
  );
```

## Using Effect

```typescript
import { Option, pipe } from 'effect';

// Basic operations
const findUser = (id: string): Option.Option<User> =>
  Option.fromNullable(users.get(id));

const getUserName = (id: string): string =>
  pipe(
    findUser(id),
    Option.map(user => user.name),
    Option.getOrElse(() => 'Anonymous')
  );

// Match pattern
const greetUser = (id: string): string =>
  pipe(
    findUser(id),
    Option.match({
      onNone: () => 'Hello, stranger!',
      onSome: (user) => `Hello, ${user.name}!`
    })
  );

// Combining with Effect for errors
import { Effect } from 'effect';

const getUserOrFail = (id: string): Effect.Effect<User, NotFoundError> =>
  pipe(
    findUser(id),
    Effect.fromOption(() => new NotFoundError('User', id))
  );
```

## OOP vs FP Comparison

| Aspect | OOP (null) | FP (Option) |
|--------|-----------|-------------|
| Type safety | Runtime errors | Compile-time safety |
| Documentation | Comments, conventions | Type signature |
| Composition | Null checks | flatMap/chain |
| Default values | ?? operator | getOrElse |
| Conditional | if (x !== null) | map/filter |

```typescript
// OOP style - null checks
function getOrderTotal(userId: string): number | null {
  const user = findUser(userId);
  if (user === null) return null;

  const order = user.currentOrder;
  if (order === null) return null;

  return order.total;
}

// FP style - Option
const getOrderTotal = (userId: string): Option<number> =>
  findUser(userId)
    .flatMap(user => fromNullable(user.currentOrder))
    .map(order => order.total);

// FP with fp-ts
const getOrderTotal = (userId: string) =>
  pipe(
    findUser(userId),
    O.flatMap(user => O.fromNullable(user.currentOrder)),
    O.map(order => order.total)
  );
```

## Option vs Either

| Use Case | Option | Either |
|----------|--------|--------|
| Value might not exist | Yes | Use when error info needed |
| Need error details | No | Yes |
| Null replacement | Yes | Overkill |
| Validation | No | Yes |
| API errors | No | Yes |

```typescript
// Option - just absence
const findUser = (id: string): Option<User> => { /* ... */ };

// Either - when you need to know why
const findUserWithError = (id: string): Either<NotFoundError, User> => { /* ... */ };
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **fp-ts** | Full Option type | `npm i fp-ts` |
| **Effect** | Modern Option | `npm i effect` |
| **purify-ts** | Simple Maybe | `npm i purify-ts` |
| **true-myth** | Rust-like Option | `npm i true-myth` |

## Anti-patterns

1. **Immediate Unwrapping**: Losing safety
   ```typescript
   // BAD
   const name = findUser(id).getOrElse(null);
   if (name) { /* ... */ }

   // GOOD
   findUser(id).map(user => {
     // Safe access to user
   });
   ```

2. **Optional Properties Instead**: Missing the point
   ```typescript
   // BAD - Optional in data model
   interface User { email?: string }

   // GOOD - Option in operations
   interface User { email: string }
   const getUserEmail = (id: string): Option<Email>
   ```

3. **Nested Options**: Over-wrapping
   ```typescript
   // BAD
   Option<Option<User>>

   // GOOD - Use flatMap
   findUser(id).flatMap(findRelatedUser);
   ```

## When to Use

- Replacing null/undefined
- Optional function parameters
- Dictionary/Map lookups
- Array find operations
- Chaining optional operations

## See Also

- [Monad](./monad.md) - Option is a monad
- [Either](./either.md) - When error information needed
- [Lens](./lens.md) - Optional property access
