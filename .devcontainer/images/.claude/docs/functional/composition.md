# Function Composition Pattern

## Definition

**Function Composition** is the act of combining simple functions to build more complex ones. The output of one function becomes the input of another, creating a pipeline of transformations.

```
compose(f, g)(x) = f(g(x))   // Right to left
pipe(f, g)(x) = g(f(x))      // Left to right (more readable)
```

**Key characteristics:**
- **Declarative**: Describes what, not how
- **Reusable**: Small functions combine freely
- **Testable**: Each function tested in isolation
- **Point-free**: Often eliminates intermediate variables
- **Type-safe**: TypeScript infers composed types

## TypeScript Implementation

```typescript
// Basic compose - right to left
const compose = <A, B, C>(
  f: (b: B) => C,
  g: (a: A) => B
) => (a: A): C => f(g(a));

// Basic pipe - left to right
const pipe = <A, B, C>(
  f: (a: A) => B,
  g: (b: B) => C
) => (a: A): C => g(f(a));

// Variadic pipe (up to 10 functions)
function pipeN<A, B>(f: (a: A) => B): (a: A) => B;
function pipeN<A, B, C>(
  f: (a: A) => B,
  g: (b: B) => C
): (a: A) => C;
function pipeN<A, B, C, D>(
  f: (a: A) => B,
  g: (b: B) => C,
  h: (c: C) => D
): (a: A) => D;
function pipeN<A, B, C, D, E>(
  f: (a: A) => B,
  g: (b: B) => C,
  h: (c: C) => D,
  i: (d: D) => E
): (a: A) => E;
function pipeN(...fns: Array<(x: unknown) => unknown>) {
  return (x: unknown) => fns.reduce((acc, fn) => fn(acc), x);
}

// Flow - immediate execution
const flow = <A>(initial: A, ...fns: Array<(x: A) => A>): A =>
  fns.reduce((acc, fn) => fn(acc), initial);
```

## Usage Examples

```typescript
// Simple transformations
const trim = (s: string) => s.trim();
const toLowerCase = (s: string) => s.toLowerCase();
const split = (sep: string) => (s: string) => s.split(sep);
const join = (sep: string) => (arr: string[]) => arr.join(sep);

// Compose transformations
const slugify = pipeN(
  trim,
  toLowerCase,
  split(' '),
  join('-')
);

slugify('  Hello World  '); // 'hello-world'

// Data processing pipeline
interface User {
  id: string;
  name: string;
  email: string;
  age: number;
}

const users: User[] = [
  { id: '1', name: 'Alice', email: 'alice@example.com', age: 30 },
  { id: '2', name: 'Bob', email: 'bob@example.com', age: 25 },
  { id: '3', name: 'Charlie', email: 'charlie@example.com', age: 35 }
];

// Reusable predicates and transformers
const isAdult = (u: User) => u.age >= 18;
const isOver30 = (u: User) => u.age > 30;
const getName = (u: User) => u.name;
const toUpperCase = (s: string) => s.toUpperCase();

// Compose into pipeline
const getAdultNamesUppercase = (users: User[]) =>
  users
    .filter(isAdult)
    .map(getName)
    .map(toUpperCase);

// Point-free style with compose
const getNameUpper = pipeN(getName, toUpperCase);
const adultsOnly = (users: User[]) => users.filter(isAdult);
const mapNames = (users: User[]) => users.map(getNameUpper);

const processUsers = pipeN(adultsOnly, mapNames);
```

## Using fp-ts

```typescript
import { pipe, flow } from 'fp-ts/function';
import * as A from 'fp-ts/Array';
import * as O from 'fp-ts/Option';
import * as E from 'fp-ts/Either';

// pipe - immediate execution with value
const result = pipe(
  '  Hello World  ',
  s => s.trim(),
  s => s.toLowerCase(),
  s => s.split(' '),
  arr => arr.join('-')
); // 'hello-world'

// flow - creates a function
const slugify = flow(
  (s: string) => s.trim(),
  s => s.toLowerCase(),
  s => s.split(' '),
  arr => arr.join('-')
);

slugify('  Hello World  '); // 'hello-world'

// Array operations
const getActiveAdminEmails = (users: User[]) =>
  pipe(
    users,
    A.filter(u => u.isActive),
    A.filter(u => u.role === 'admin'),
    A.map(u => u.email),
    A.uniq(S.Eq)
  );

// Option composition
const getFirstAdminEmail = (users: User[]) =>
  pipe(
    users,
    A.findFirst(u => u.role === 'admin'),
    O.map(u => u.email),
    O.getOrElse(() => 'no-admin@example.com')
  );

// Either composition
const processPayment = (orderId: string, amount: number) =>
  pipe(
    validateAmount(amount),                    // Either<Error, number>
    E.flatMap(amt => findOrder(orderId)),      // Either<Error, Order>
    E.flatMap(order => chargeCustomer(order)), // Either<Error, Payment>
    E.map(payment => payment.confirmation),    // Either<Error, string>
    E.fold(
      error => ({ success: false, error: error.message }),
      confirmation => ({ success: true, confirmation })
    )
  );
```

## Using Effect

```typescript
import { Effect, pipe } from 'effect';

// Composing effects
const program = pipe(
  Effect.succeed(10),
  Effect.map(n => n * 2),
  Effect.flatMap(n => n > 15 ? Effect.succeed(n) : Effect.fail('Too small')),
  Effect.map(n => `Result: ${n}`)
);

// With dependencies
interface Logger {
  log: (msg: string) => Effect.Effect<void>;
}

interface Database {
  query: (sql: string) => Effect.Effect<unknown[], Error>;
}

const fetchAndLog = pipe(
  Effect.service(Database),
  Effect.flatMap(db => db.query('SELECT * FROM users')),
  Effect.tap(users => pipe(
    Effect.service(Logger),
    Effect.flatMap(logger => logger.log(`Found ${users.length} users`))
  ))
);
```

## Composition Patterns

### Currying for Composition

```typescript
// Curried functions compose better
const add = (a: number) => (b: number) => a + b;
const multiply = (a: number) => (b: number) => a * b;

const add5 = add(5);
const double = multiply(2);

const transform = pipeN(add5, double); // (x + 5) * 2
transform(10); // 30
```

### Partial Application

```typescript
// Partially apply for reuse
const filter = <A>(predicate: (a: A) => boolean) => (arr: A[]) =>
  arr.filter(predicate);

const map = <A, B>(f: (a: A) => B) => (arr: A[]) =>
  arr.map(f);

const adults = filter<User>(u => u.age >= 18);
const names = map<User, string>(u => u.name);

const getAdultNames = pipeN(adults, names);
```

### Kleisli Composition (Monadic)

```typescript
import { pipe } from 'fp-ts/function';
import * as O from 'fp-ts/Option';
import { Kleisli } from 'fp-ts/Kleisli';

// Functions returning Option
const parseNumber = (s: string): O.Option<number> => {
  const n = parseInt(s, 10);
  return isNaN(n) ? O.none : O.some(n);
};

const half = (n: number): O.Option<number> =>
  n % 2 === 0 ? O.some(n / 2) : O.none;

// Compose with flatMap
const parseAndHalf = (s: string): O.Option<number> =>
  pipe(
    parseNumber(s),
    O.flatMap(half)
  );

// Using Kleisli composition
import * as K from 'fp-ts/Kleisli';

const parseAndHalfK = K.compose(O.Monad)(half, parseNumber);
```

## OOP vs FP Comparison

```typescript
// OOP - Method chaining (fluent interface)
class StringProcessor {
  constructor(private value: string) {}

  trim(): StringProcessor {
    return new StringProcessor(this.value.trim());
  }

  toLowerCase(): StringProcessor {
    return new StringProcessor(this.value.toLowerCase());
  }

  split(sep: string): ArrayProcessor {
    return new ArrayProcessor(this.value.split(sep));
  }
}

// Usage
new StringProcessor('  Hello World  ')
  .trim()
  .toLowerCase()
  .split(' ');

// FP - Function composition
const process = pipe(
  '  Hello World  ',
  trim,
  toLowerCase,
  split(' ')
);
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **fp-ts** | pipe, flow | `npm i fp-ts` |
| **Effect** | Effect composition | `npm i effect` |
| **ramda** | R.pipe, R.compose | `npm i ramda` |
| **lodash/fp** | _.flow | `npm i lodash` |
| **sanctuary** | S.pipe | `npm i sanctuary` |

## Anti-patterns

1. **Long Pipelines**: Hard to debug
   ```typescript
   // BAD - 20 steps, hard to trace errors
   pipe(data, f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, /* ... */);

   // GOOD - Break into named stages
   const stage1 = pipe(data, f1, f2, f3);
   const stage2 = pipe(stage1, f4, f5, f6);
   ```

2. **Impure Functions in Pipeline**: Side effects break reasoning
   ```typescript
   // BAD
   pipe(
     users,
     A.map(u => { console.log(u); return u; }), // Side effect!
     A.filter(isActive)
   );

   // GOOD - Use tap for side effects
   pipe(
     users,
     A.map(u => u),
     tap(users => console.log(users)),
     A.filter(isActive)
   );
   ```

3. **Type Inference Failure**: Missing type annotations
   ```typescript
   // BAD - TypeScript can't infer
   const process = flow(
     x => x.trim(), // x is unknown
     toLowerCase
   );

   // GOOD - Add type annotation
   const process = flow(
     (x: string) => x.trim(),
     toLowerCase
   );
   ```

## When to Use

- Data transformation pipelines
- Building complex operations from simple ones
- Avoiding intermediate variables
- Creating reusable function combinations
- Point-free programming style

## See Also

- [Monad](./monad.md) - Monadic composition with flatMap
- [Either](./either.md) - Composing fallible functions
- [Lens](./lens.md) - Composable optics
