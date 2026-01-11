# Monad Pattern

## Definition

A **Monad** is a design pattern that allows structuring programs generically while chaining operations with context. It wraps values in a computational context (like optionality, errors, or async) and provides a way to compose operations on wrapped values.

```
Monad = Type Constructor + unit (of/return) + flatMap (bind/chain)
```

**Monad Laws:**

1. **Left Identity**: `of(a).flatMap(f)` === `f(a)`
2. **Right Identity**: `m.flatMap(of)` === `m`
3. **Associativity**: `m.flatMap(f).flatMap(g)` === `m.flatMap(x => f(x).flatMap(g))`

## Core Monads

| Monad | Context | Purpose |
|-------|---------|---------|
| **Maybe/Option** | Optionality | Handle null/undefined |
| **Either/Result** | Error handling | Success or failure |
| **IO** | Side effects | Defer execution |
| **Task/Future** | Async | Handle promises |
| **Reader** | Dependencies | Dependency injection |
| **State** | Mutable state | Thread state through |
| **List/Array** | Non-determinism | Multiple values |

## TypeScript Implementation

```typescript
// Generic Monad Interface
interface Monad<A> {
  flatMap<B>(f: (a: A) => Monad<B>): Monad<B>;
  map<B>(f: (a: A) => B): Monad<B>;
}

// Maybe Monad
abstract class Maybe<A> implements Monad<A> {
  abstract flatMap<B>(f: (a: A) => Maybe<B>): Maybe<B>;
  abstract map<B>(f: (a: A) => B): Maybe<B>;
  abstract getOrElse(defaultValue: A): A;
  abstract isSome(): boolean;
  abstract isNone(): boolean;

  static of<A>(value: A): Maybe<A> {
    return value === null || value === undefined
      ? None.instance<A>()
      : new Some(value);
  }

  static none<A>(): Maybe<A> {
    return None.instance<A>();
  }
}

class Some<A> extends Maybe<A> {
  constructor(private readonly value: A) {
    super();
  }

  flatMap<B>(f: (a: A) => Maybe<B>): Maybe<B> {
    return f(this.value);
  }

  map<B>(f: (a: A) => B): Maybe<B> {
    return Maybe.of(f(this.value));
  }

  getOrElse(_defaultValue: A): A {
    return this.value;
  }

  isSome(): boolean { return true; }
  isNone(): boolean { return false; }
}

class None<A> extends Maybe<A> {
  private static readonly INSTANCE = new None<never>();

  static instance<A>(): Maybe<A> {
    return None.INSTANCE as Maybe<A>;
  }

  flatMap<B>(_f: (a: A) => Maybe<B>): Maybe<B> {
    return None.instance<B>();
  }

  map<B>(_f: (a: A) => B): Maybe<B> {
    return None.instance<B>();
  }

  getOrElse(defaultValue: A): A {
    return defaultValue;
  }

  isSome(): boolean { return false; }
  isNone(): boolean { return true; }
}

// Either Monad
abstract class Either<E, A> implements Monad<A> {
  abstract flatMap<B>(f: (a: A) => Either<E, B>): Either<E, B>;
  abstract map<B>(f: (a: A) => B): Either<E, B>;
  abstract mapLeft<F>(f: (e: E) => F): Either<F, A>;
  abstract isRight(): boolean;
  abstract isLeft(): boolean;

  static right<E, A>(value: A): Either<E, A> {
    return new Right(value);
  }

  static left<E, A>(error: E): Either<E, A> {
    return new Left(error);
  }
}

class Right<E, A> extends Either<E, A> {
  constructor(private readonly value: A) {
    super();
  }

  flatMap<B>(f: (a: A) => Either<E, B>): Either<E, B> {
    return f(this.value);
  }

  map<B>(f: (a: A) => B): Either<E, B> {
    return Either.right(f(this.value));
  }

  mapLeft<F>(_f: (e: E) => F): Either<F, A> {
    return Either.right(this.value);
  }

  isRight(): boolean { return true; }
  isLeft(): boolean { return false; }
}

class Left<E, A> extends Either<E, A> {
  constructor(private readonly error: E) {
    super();
  }

  flatMap<B>(_f: (a: A) => Either<E, B>): Either<E, B> {
    return Either.left(this.error);
  }

  map<B>(_f: (a: A) => B): Either<E, B> {
    return Either.left(this.error);
  }

  mapLeft<F>(f: (e: E) => F): Either<F, A> {
    return Either.left(f(this.error));
  }

  isRight(): boolean { return false; }
  isLeft(): boolean { return true; }
}

// IO Monad - Deferred side effects
class IO<A> implements Monad<A> {
  constructor(private readonly effect: () => A) {}

  static of<A>(value: A): IO<A> {
    return new IO(() => value);
  }

  static from<A>(effect: () => A): IO<A> {
    return new IO(effect);
  }

  flatMap<B>(f: (a: A) => IO<B>): IO<B> {
    return new IO(() => f(this.effect()).run());
  }

  map<B>(f: (a: A) => B): IO<B> {
    return new IO(() => f(this.effect()));
  }

  run(): A {
    return this.effect();
  }
}
```

## Usage Examples

```typescript
// Maybe - handling optional values
const findUser = (id: string): Maybe<User> =>
  Maybe.of(users.get(id));

const findOrder = (user: User): Maybe<Order> =>
  Maybe.of(user.orders[0]);

const getOrderTotal = (order: Order): Maybe<Money> =>
  Maybe.of(order.total);

// Chain operations - short-circuits on None
const userOrderTotal = findUser('123')
  .flatMap(findOrder)
  .flatMap(getOrderTotal)
  .getOrElse(Money.zero());

// Either - error handling
const parseEmail = (input: string): Either<ValidationError, Email> => {
  if (!input.includes('@')) {
    return Either.left(new ValidationError('Invalid email'));
  }
  return Either.right(new Email(input));
};

const validateAge = (age: number): Either<ValidationError, number> => {
  if (age < 18) {
    return Either.left(new ValidationError('Must be 18+'));
  }
  return Either.right(age);
};

// Compose validations
const registerUser = (email: string, age: number): Either<ValidationError, User> =>
  parseEmail(email)
    .flatMap(validEmail =>
      validateAge(age)
        .map(validAge => new User(validEmail, validAge))
    );

// IO - side effects
const readFile = (path: string): IO<string> =>
  IO.from(() => fs.readFileSync(path, 'utf-8'));

const writeFile = (path: string, content: string): IO<void> =>
  IO.from(() => fs.writeFileSync(path, content));

const program: IO<void> = readFile('input.txt')
  .map(content => content.toUpperCase())
  .flatMap(upper => writeFile('output.txt', upper));

// Nothing happens until we run
program.run();
```

## Using fp-ts

```typescript
import { pipe } from 'fp-ts/function';
import * as O from 'fp-ts/Option';
import * as E from 'fp-ts/Either';
import * as TE from 'fp-ts/TaskEither';

// Option (Maybe)
const findUser = (id: string): O.Option<User> =>
  pipe(
    users.get(id),
    O.fromNullable
  );

const getUserEmail = pipe(
  findUser('123'),
  O.map(user => user.email),
  O.getOrElse(() => 'unknown@example.com')
);

// Either
const parseNumber = (s: string): E.Either<string, number> =>
  pipe(
    parseInt(s, 10),
    n => isNaN(n) ? E.left('Not a number') : E.right(n)
  );

// TaskEither (async + error handling)
const fetchUser = (id: string): TE.TaskEither<Error, User> =>
  TE.tryCatch(
    () => fetch(`/api/users/${id}`).then(r => r.json()),
    (error) => new Error(String(error))
  );

const program = pipe(
  fetchUser('123'),
  TE.map(user => user.name),
  TE.getOrElse(() => async () => 'Anonymous')
);

// Run async
program().then(console.log);
```

## Using Effect

```typescript
import { Effect, pipe } from 'effect';

// Effect is a powerful monad combining IO, Either, Reader, and more
const program = pipe(
  Effect.succeed(42),
  Effect.map(n => n * 2),
  Effect.flatMap(n =>
    n > 50
      ? Effect.fail(new Error('Too large'))
      : Effect.succeed(n)
  )
);

// With dependencies (Reader monad pattern)
interface UserService {
  getUser: (id: string) => Effect.Effect<User, NotFoundError>;
}

const getUserName = (id: string) =>
  Effect.gen(function* (_) {
    const userService = yield* _(Effect.service(UserService));
    const user = yield* _(userService.getUser(id));
    return user.name;
  });
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **fp-ts** | Comprehensive FP | `npm i fp-ts` |
| **Effect** | Modern FP runtime | `npm i effect` |
| **neverthrow** | Simple Result type | `npm i neverthrow` |
| **purify-ts** | Lightweight FP | `npm i purify-ts` |
| **ts-results** | Rust-like Result | `npm i ts-results` |

## Anti-patterns

1. **Monad Hell**: Too many nested flatMaps

   ```typescript
   // BAD
   a.flatMap(b =>
     c.flatMap(d =>
       e.flatMap(f => /* ... */)
     )
   )

   // GOOD - Use do-notation or generators
   Effect.gen(function* () {
     const b = yield* a;
     const d = yield* c;
     const f = yield* e;
   });
   ```

2. **Escaping the Monad**: Unwrapping too early

   ```typescript
   // BAD - Loses safety
   const value = maybe.getOrElse(null);
   if (value) { /* ... */ }

   // GOOD - Stay in monad
   maybe.map(value => /* ... */);
   ```

3. **Ignoring Errors**: Not handling Left/None cases

   ```typescript
   // BAD
   const result = either.flatMap(/* ... */);
   // Never checks if Left

   // GOOD
   either.fold(
     error => handleError(error),
     value => handleSuccess(value)
   );
   ```

## When to Use

- Sequential operations that may fail
- Handling null/undefined safely
- Managing side effects explicitly
- Composing async operations
- Dependency injection (Reader)

## See Also

- [Either](./either.md) - Error handling monad
- [Option](./option.md) - Optional value monad
- [Composition](./composition.md) - Composing monadic functions
