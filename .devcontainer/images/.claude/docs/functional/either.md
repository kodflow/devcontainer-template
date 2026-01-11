# Either / Result Pattern

## Definition

**Either** (also known as Result) is a type that represents one of two possible values: a success value (Right) or an error value (Left). It provides type-safe error handling without exceptions.

```
Either<E, A> = Left<E> | Right<A>
Result<T, E> = Ok<T> | Err<E>
```

**Key characteristics:**

- **Explicit errors**: Errors are part of the type signature
- **Composable**: Chain operations that may fail
- **Short-circuit**: First error stops the chain
- **No exceptions**: Errors as values, not control flow
- **Biased**: Right-biased (map/flatMap operate on Right)

## TypeScript Implementation

```typescript
// Result type (Either with different naming)
type Result<T, E> = Ok<T, E> | Err<T, E>;

class Ok<T, E> {
  readonly _tag = 'Ok';
  constructor(readonly value: T) {}

  isOk(): this is Ok<T, E> { return true; }
  isErr(): this is Err<T, E> { return false; }

  map<U>(f: (value: T) => U): Result<U, E> {
    return new Ok(f(this.value));
  }

  mapErr<F>(_f: (error: E) => F): Result<T, F> {
    return new Ok(this.value);
  }

  flatMap<U>(f: (value: T) => Result<U, E>): Result<U, E> {
    return f(this.value);
  }

  unwrap(): T {
    return this.value;
  }

  unwrapOr(_defaultValue: T): T {
    return this.value;
  }

  match<U>(handlers: { ok: (value: T) => U; err: (error: E) => U }): U {
    return handlers.ok(this.value);
  }
}

class Err<T, E> {
  readonly _tag = 'Err';
  constructor(readonly error: E) {}

  isOk(): this is Ok<T, E> { return false; }
  isErr(): this is Err<T, E> { return true; }

  map<U>(_f: (value: T) => U): Result<U, E> {
    return new Err(this.error);
  }

  mapErr<F>(f: (error: E) => F): Result<T, F> {
    return new Err(f(this.error));
  }

  flatMap<U>(_f: (value: T) => Result<U, E>): Result<U, E> {
    return new Err(this.error);
  }

  unwrap(): never {
    throw new Error(`Called unwrap on Err: ${this.error}`);
  }

  unwrapOr(defaultValue: T): T {
    return defaultValue;
  }

  match<U>(handlers: { ok: (value: T) => U; err: (error: E) => U }): U {
    return handlers.err(this.error);
  }
}

// Helper functions
const ok = <T, E = never>(value: T): Result<T, E> => new Ok(value);
const err = <T = never, E = unknown>(error: E): Result<T, E> => new Err(error);

// Combine multiple Results
function combine<T extends readonly Result<unknown, unknown>[]>(
  results: T
): Result<
  { [K in keyof T]: T[K] extends Result<infer U, unknown> ? U : never },
  T[number] extends Result<unknown, infer E> ? E : never
> {
  const values: unknown[] = [];

  for (const result of results) {
    if (result.isErr()) {
      return result as any;
    }
    values.push(result.value);
  }

  return ok(values as any);
}
```

## Domain Usage Examples

```typescript
// Error types
class ValidationError {
  constructor(readonly field: string, readonly message: string) {}
}

class NotFoundError {
  constructor(readonly resource: string, readonly id: string) {}
}

class AuthorizationError {
  constructor(readonly action: string) {}
}

type DomainError = ValidationError | NotFoundError | AuthorizationError;

// Validation functions
const validateEmail = (email: string): Result<Email, ValidationError> => {
  if (!email.includes('@')) {
    return err(new ValidationError('email', 'Invalid email format'));
  }
  return ok(new Email(email));
};

const validatePassword = (password: string): Result<Password, ValidationError> => {
  if (password.length < 8) {
    return err(new ValidationError('password', 'Password too short'));
  }
  if (!/[A-Z]/.test(password)) {
    return err(new ValidationError('password', 'Must contain uppercase'));
  }
  return ok(new Password(password));
};

const validateAge = (age: number): Result<Age, ValidationError> => {
  if (age < 0 || age > 150) {
    return err(new ValidationError('age', 'Invalid age'));
  }
  return ok(new Age(age));
};

// Compose validations
const createUser = (
  email: string,
  password: string,
  age: number
): Result<User, ValidationError> => {
  return validateEmail(email).flatMap(validEmail =>
    validatePassword(password).flatMap(validPassword =>
      validateAge(age).map(validAge =>
        new User(validEmail, validPassword, validAge)
      )
    )
  );
};

// Alternative: Collect all errors
const createUserValidated = (
  email: string,
  password: string,
  age: number
): Result<User, ValidationError[]> => {
  const emailResult = validateEmail(email);
  const passwordResult = validatePassword(password);
  const ageResult = validateAge(age);

  const errors: ValidationError[] = [];

  if (emailResult.isErr()) errors.push(emailResult.error);
  if (passwordResult.isErr()) errors.push(passwordResult.error);
  if (ageResult.isErr()) errors.push(ageResult.error);

  if (errors.length > 0) {
    return err(errors);
  }

  return ok(new User(
    emailResult.unwrap(),
    passwordResult.unwrap(),
    ageResult.unwrap()
  ));
};

// Service layer usage
class UserService {
  async findById(id: UserId): Promise<Result<User, NotFoundError>> {
    const user = await this.repository.findById(id);
    if (!user) {
      return err(new NotFoundError('User', id.value));
    }
    return ok(user);
  }

  async updateEmail(
    userId: UserId,
    newEmail: string
  ): Promise<Result<User, DomainError>> {
    // Chain multiple operations
    return (await this.findById(userId))
      .flatMap(user => {
        if (!user.canUpdateEmail) {
          return err(new AuthorizationError('update email'));
        }
        return ok(user);
      })
      .flatMap(user =>
        validateEmail(newEmail).map(email => {
          user.email = email;
          return user;
        })
      );
  }
}
```

## Using fp-ts

```typescript
import { pipe } from 'fp-ts/function';
import * as E from 'fp-ts/Either';
import * as TE from 'fp-ts/TaskEither';
import * as A from 'fp-ts/Apply';

// Basic Either
const parseNumber = (s: string): E.Either<string, number> => {
  const n = parseInt(s, 10);
  return isNaN(n) ? E.left('Not a number') : E.right(n);
};

const divide = (a: number, b: number): E.Either<string, number> =>
  b === 0 ? E.left('Division by zero') : E.right(a / b);

// Chaining
const calculate = (a: string, b: string): E.Either<string, number> =>
  pipe(
    parseNumber(a),
    E.flatMap(numA =>
      pipe(
        parseNumber(b),
        E.flatMap(numB => divide(numA, numB))
      )
    )
  );

// Parallel validation (collect all errors)
const validateUserParallel = (email: string, password: string) =>
  pipe(
    E.Do,
    E.apS('email', validateEmail(email)),
    E.apS('password', validatePassword(password)),
    E.map(({ email, password }) => new User(email, password))
  );

// TaskEither for async operations
const fetchUser = (id: string): TE.TaskEither<Error, User> =>
  TE.tryCatch(
    () => fetch(`/api/users/${id}`).then(r => r.json()),
    (error) => new Error(String(error))
  );

const updateUser = (user: User): TE.TaskEither<Error, User> =>
  TE.tryCatch(
    () => fetch(`/api/users/${user.id}`, {
      method: 'PUT',
      body: JSON.stringify(user)
    }).then(r => r.json()),
    (error) => new Error(String(error))
  );

// Chain async operations
const fetchAndUpdate = (id: string, email: string): TE.TaskEither<Error, User> =>
  pipe(
    fetchUser(id),
    TE.map(user => ({ ...user, email })),
    TE.flatMap(updateUser)
  );
```

## Using Effect

```typescript
import { Effect, pipe } from 'effect';

// Define error types
class ParseError {
  readonly _tag = 'ParseError';
  constructor(readonly input: string) {}
}

class DivisionError {
  readonly _tag = 'DivisionError';
}

// Functions return Effect with typed errors
const parseNumber = (s: string): Effect.Effect<number, ParseError> => {
  const n = parseInt(s, 10);
  return isNaN(n)
    ? Effect.fail(new ParseError(s))
    : Effect.succeed(n);
};

const divide = (a: number, b: number): Effect.Effect<number, DivisionError> =>
  b === 0
    ? Effect.fail(new DivisionError())
    : Effect.succeed(a / b);

// Compose with generators (like async/await)
const calculate = (a: string, b: string) =>
  Effect.gen(function* (_) {
    const numA = yield* _(parseNumber(a));
    const numB = yield* _(parseNumber(b));
    return yield* _(divide(numA, numB));
  });

// Handle errors
const program = pipe(
  calculate('10', '2'),
  Effect.catchTags({
    ParseError: (e) => Effect.succeed(`Invalid input: ${e.input}`),
    DivisionError: () => Effect.succeed('Cannot divide by zero'),
  })
);
```

## OOP vs FP Comparison

| Aspect | OOP (Exceptions) | FP (Either/Result) |
|--------|-----------------|-------------------|
| Error visibility | Hidden | In type signature |
| Composition | try-catch nesting | flatMap chaining |
| Control flow | throw/catch | Pattern matching |
| Performance | Stack unwinding | No overhead |
| Testing | Mock exceptions | Simple assertions |

```typescript
// OOP style
function processOrder(order: Order): Order {
  if (!order.isValid()) {
    throw new ValidationError('Invalid order');
  }
  if (!inventory.hasStock(order)) {
    throw new StockError('Out of stock');
  }
  return order.process();
}

// FP style
const processOrder = (order: Order): Result<Order, OrderError> =>
  pipe(
    validateOrder(order),
    flatMap(checkStock),
    map(process)
  );
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **fp-ts** | Full Either type | `npm i fp-ts` |
| **Effect** | Modern Result | `npm i effect` |
| **neverthrow** | Simple Result | `npm i neverthrow` |
| **ts-results** | Rust-like Result | `npm i ts-results` |
| **oxide.ts** | Rust-inspired | `npm i oxide.ts` |

## Anti-patterns

1. **Unwrapping Too Early**: Losing type safety

   ```typescript
   // BAD
   const user = result.unwrap(); // Throws on Err!

   // GOOD
   result.match({
     ok: user => handleUser(user),
     err: error => handleError(error)
   });
   ```

2. **Mixing with Exceptions**: Inconsistent error handling

   ```typescript
   // BAD
   const result = validate(data);
   if (result.isOk()) {
     throw new Error('Something else'); // Exception!
   }
   ```

3. **Ignoring Error Types**: Generic error handling

   ```typescript
   // BAD
   Result<User, Error> // Too broad

   // GOOD
   Result<User, ValidationError | NotFoundError>
   ```

## When to Use

- Functions that can fail predictably
- Validation logic
- API responses
- Domain operations with business errors
- Anywhere exceptions would be caught

## See Also

- [Monad](./monad.md) - Either is a monad
- [Option](./option.md) - For optional values (no error info)
- [Composition](./composition.md) - Composing Result-returning functions
