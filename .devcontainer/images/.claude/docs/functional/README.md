# Functional Programming Patterns

Patterns de programmation fonctionnelle.

## Core Concepts

### 1. Pure Function

> Fonction sans effets de bord, même entrée = même sortie.

```go
// Pure - no side effects, deterministic
function add(a: number, b: number): number {
  return a + b;
}

function calculateDiscount(price: number, rate: number): number {
  return price * (1 - rate);
}

// Impure - side effects
let total = 0;
function addToTotal(n: number): void {
  total += n; // Mutation!
}

function getRandomDiscount(price: number): number {
  return price * Math.random(); // Non-deterministic!
}

function logPrice(price: number): number {
  console.log(price); // Side effect!
  return price;
}

// Making impure code pure with dependency injection
function calculateWithLogging(
  price: number,
  logger: (msg: string) => void,
): number {
  const result = price * 0.9;
  logger(`Calculated: ${result}`); // Effect handled by caller
  return result;
}
```

**Avantages :** Testable, prévisible, parallelisable.
**Quand :** Toujours privilégier les fonctions pures.

---

### 2. Immutability

> Ne jamais modifier, toujours créer une nouvelle version.

```go
// Mutable - BAD
const user = { name: 'John', age: 30 };
user.age = 31; // Mutation!

// Immutable - GOOD
const user1 = { name: 'John', age: 30 };
const user2 = { ...user1, age: 31 }; // New object

// Immutable array operations
const numbers = [1, 2, 3];

// BAD
numbers.push(4); // Mutates

// GOOD
const newNumbers = [...numbers, 4]; // New array

// Deep immutability
interface User {
  readonly name: string;
  readonly address: {
    readonly street: string;
    readonly city: string;
  };
}

function updateCity(user: User, city: string): User {
  return {
    ...user,
    address: {
      ...user.address,
      city,
    },
  };
}

// With Immer for complex updates
import produce from 'immer';

const nextState = produce(user, (draft) => {
  draft.address.city = 'Paris'; // Looks mutable, but creates new object
});
```

**Avantages :** Pas de surprises, time-travel, concurrency safe.
**Quand :** État partagé, React/Redux, données critiques.

---

### 3. Higher-Order Functions

> Fonctions qui prennent/retournent des fonctions.

```go
// Function that returns a function
function multiply(factor: number): (n: number) => number {
  return (n: number) => n * factor;
}

const double = multiply(2);
const triple = multiply(3);
console.log(double(5)); // 10
console.log(triple(5)); // 15

// Function that takes a function
function map<T, U>(arr: T[], fn: (item: T) => U): U[] {
  const result: U[] = [];
  for (const item of arr) {
    result.push(fn(item));
  }
  return result;
}

function filter<T>(arr: T[], predicate: (item: T) => boolean): T[] {
  const result: T[] = [];
  for (const item of arr) {
    if (predicate(item)) {
      result.push(item);
    }
  }
  return result;
}

function reduce<T, U>(arr: T[], fn: (acc: U, item: T) => U, initial: U): U {
  let result = initial;
  for (const item of arr) {
    result = fn(result, item);
  }
  return result;
}

// Composition
const processUsers = pipe(
  filter((u: User) => u.active),
  map((u) => u.name),
  reduce((acc, name) => `${acc}, ${name}`, ''),
);
```

**Quand :** Abstraction de comportement, callbacks, composition.
**Lié à :** Currying, Composition.

---

### 4. Currying

> Transformer f(a, b, c) en f(a)(b)(c).

```go
// Regular function
function add(a: number, b: number, c: number): number {
  return a + b + c;
}

// Curried version
function curriedAdd(a: number) {
  return function (b: number) {
    return function (c: number) {
      return a + b + c;
    };
  };
}

// Arrow syntax
const curriedAdd2 = (a: number) => (b: number) => (c: number) => a + b + c;

// Usage - partial application
const add5 = curriedAdd(5);
const add5and10 = add5(10);
console.log(add5and10(3)); // 18

// Generic curry utility
function curry<T extends (...args: any[]) => any>(fn: T) {
  return function curried(...args: any[]): any {
    if (args.length >= fn.length) {
      return fn(...args);
    }
    return (...moreArgs: any[]) => curried(...args, ...moreArgs);
  };
}

// Usage
const curriedFetch = curry(
  (method: string, url: string, body: object) => fetch(url, { method, body: JSON.stringify(body) }),
);

const postTo = curriedFetch('POST');
const postToUsers = postTo('/api/users');
await postToUsers({ name: 'John' });
```

**Quand :** Configuration partielle, composition, point-free style.
**Lié à :** Partial Application.

---

### 5. Function Composition

> Combiner des fonctions simples en complexes.

```go
// Basic composition
function compose<A, B, C>(f: (b: B) => C, g: (a: A) => B): (a: A) => C {
  return (a: A) => f(g(a));
}

// Pipe (left to right)
function pipe<T>(...fns: Array<(arg: T) => T>): (arg: T) => T {
  return (arg: T) => fns.reduce((acc, fn) => fn(acc), arg);
}

// Variadic pipe with type safety
type Pipe = {
  <A, B>(f1: (a: A) => B): (a: A) => B;
  <A, B, C>(f1: (a: A) => B, f2: (b: B) => C): (a: A) => C;
  <A, B, C, D>(f1: (a: A) => B, f2: (b: B) => C, f3: (c: C) => D): (a: A) => D;
  // ... more overloads
};

// Usage
const processOrder = pipe(
  validateOrder,
  calculateTax,
  applyDiscount,
  formatForDisplay,
);

const result = processOrder(order);

// Async composition
const pipeAsync = <T>(...fns: Array<(arg: T) => Promise<T> | T>) => {
  return async (arg: T): Promise<T> => {
    let result = arg;
    for (const fn of fns) {
      result = await fn(result);
    }
    return result;
  };
};

const processAsync = pipeAsync(
  fetchUser,
  validatePermissions,
  loadUserData,
  formatResponse,
);
```

**Quand :** Pipelines de données, transformations, middleware.
**Lié à :** Higher-Order Functions, Currying.

---

## Algebraic Data Types

### 6. Option/Maybe

> Représenter l'absence de valeur de manière safe.

```go
type Option<T> = Some<T> | None;

class Some<T> {
  readonly _tag = 'Some';
  constructor(readonly value: T) {}

  map<U>(fn: (value: T) => U): Option<U> {
    return new Some(fn(this.value));
  }

  flatMap<U>(fn: (value: T) => Option<U>): Option<U> {
    return fn(this.value);
  }

  getOrElse(_default: T): T {
    return this.value;
  }

  fold<U>(onNone: () => U, onSome: (value: T) => U): U {
    return onSome(this.value);
  }
}

class None {
  readonly _tag = 'None';

  map<U>(_fn: (value: never) => U): Option<U> {
    return this;
  }

  flatMap<U>(_fn: (value: never) => Option<U>): Option<U> {
    return this;
  }

  getOrElse<T>(defaultValue: T): T {
    return defaultValue;
  }

  fold<U>(onNone: () => U, _onSome: (value: never) => U): U {
    return onNone();
  }
}

const none: None = new None();

function some<T>(value: T): Option<T> {
  return new Some(value);
}

// Usage
function findUser(id: string): Option<User> {
  const user = db.get(id);
  return user ? some(user) : none;
}

const userName = findUser('123')
  .map((user) => user.name)
  .getOrElse('Unknown');

// Chaining
const email = findUser('123')
  .flatMap((user) => findAddress(user.addressId))
  .map((address) => address.email)
  .getOrElse('no-email@example.com');
```

**Quand :** Valeurs potentiellement absentes, éviter null checks.
**Lié à :** Either, Monad.

---

### 7. Either

> Représenter succès ou échec avec contexte.

```go
type Either<L, R> = Left<L> | Right<R>;

class Left<L> {
  readonly _tag = 'Left';
  constructor(readonly value: L) {}

  map<U>(_fn: (value: never) => U): Either<L, U> {
    return this as any;
  }

  flatMap<U>(_fn: (value: never) => Either<L, U>): Either<L, U> {
    return this as any;
  }

  mapLeft<U>(fn: (value: L) => U): Either<U, never> {
    return new Left(fn(this.value));
  }

  fold<U>(onLeft: (l: L) => U, _onRight: (r: never) => U): U {
    return onLeft(this.value);
  }
}

class Right<R> {
  readonly _tag = 'Right';
  constructor(readonly value: R) {}

  map<U>(fn: (value: R) => U): Either<never, U> {
    return new Right(fn(this.value));
  }

  flatMap<L, U>(fn: (value: R) => Either<L, U>): Either<L, U> {
    return fn(this.value);
  }

  mapLeft<U>(_fn: (value: never) => U): Either<U, R> {
    return this as any;
  }

  fold<U>(_onLeft: (l: never) => U, onRight: (r: R) => U): U {
    return onRight(this.value);
  }
}

function left<L>(value: L): Either<L, never> {
  return new Left(value);
}

function right<R>(value: R): Either<never, R> {
  return new Right(value);
}

// Usage
type ValidationError = { field: string; message: string };

function validateEmail(email: string): Either<ValidationError, string> {
  if (!email.includes('@')) {
    return left({ field: 'email', message: 'Invalid email' });
  }
  return right(email);
}

function validateAge(age: number): Either<ValidationError, number> {
  if (age < 0 || age > 150) {
    return left({ field: 'age', message: 'Invalid age' });
  }
  return right(age);
}

// Chaining validations
const result = validateEmail('john@example.com')
  .flatMap((email) =>
    validateAge(30).map((age) => ({
      email,
      age,
    })),
  )
  .fold(
    (error) => `Error in ${error.field}: ${error.message}`,
    (user) => `Valid user: ${user.email}, ${user.age}`,
  );
```

**Quand :** Gestion d'erreurs, validation, résultats avec contexte.
**Lié à :** Option, Result.

---

### 8. Result/Try

> Encapsuler les opérations qui peuvent échouer.

```go
type Result<T, E = Error> = Ok<T> | Err<E>;

class Ok<T> {
  readonly _tag = 'Ok';
  constructor(readonly value: T) {}

  isOk(): this is Ok<T> {
    return true;
  }

  isErr(): boolean {
    return false;
  }

  map<U>(fn: (value: T) => U): Result<U, never> {
    return new Ok(fn(this.value));
  }

  flatMap<U, E>(fn: (value: T) => Result<U, E>): Result<U, E> {
    return fn(this.value);
  }

  unwrap(): T {
    return this.value;
  }

  unwrapOr(_default: T): T {
    return this.value;
  }
}

class Err<E> {
  readonly _tag = 'Err';
  constructor(readonly error: E) {}

  isOk(): boolean {
    return false;
  }

  isErr(): this is Err<E> {
    return true;
  }

  map<U>(_fn: (value: never) => U): Result<U, E> {
    return this as any;
  }

  flatMap<U>(_fn: (value: never) => Result<U, E>): Result<U, E> {
    return this as any;
  }

  unwrap(): never {
    throw this.error;
  }

  unwrapOr<T>(defaultValue: T): T {
    return defaultValue;
  }
}

function ok<T>(value: T): Result<T, never> {
  return new Ok(value);
}

function err<E>(error: E): Result<never, E> {
  return new Err(error);
}

// Try wrapper for exceptions
function tryCatch<T>(fn: () => T): Result<T, Error> {
  try {
    return ok(fn());
  } catch (e) {
    return err(e instanceof Error ? e : new Error(String(e)));
  }
}

// Async version
async function tryCatchAsync<T>(fn: () => Promise<T>): Promise<Result<T, Error>> {
  try {
    return ok(await fn());
  } catch (e) {
    return err(e instanceof Error ? e : new Error(String(e)));
  }
}

// Usage
const parseResult = tryCatch(() => JSON.parse(jsonString));

const data = parseResult
  .map((json) => json.data)
  .unwrapOr({ default: true });
```

**Quand :** Exceptions, parsing, I/O, operations risquées.
**Lié à :** Either.

---

## Monads

### 9. Monad Pattern

> Container avec flatMap pour chaînage.

```go
interface Monad<T> {
  map<U>(fn: (value: T) => U): Monad<U>;
  flatMap<U>(fn: (value: T) => Monad<U>): Monad<U>;
}

// Identity Monad
class Identity<T> implements Monad<T> {
  constructor(private readonly value: T) {}

  static of<T>(value: T): Identity<T> {
    return new Identity(value);
  }

  map<U>(fn: (value: T) => U): Identity<U> {
    return new Identity(fn(this.value));
  }

  flatMap<U>(fn: (value: T) => Identity<U>): Identity<U> {
    return fn(this.value);
  }

  get(): T {
    return this.value;
  }
}

// IO Monad - defer side effects
class IO<T> {
  constructor(private readonly effect: () => T) {}

  static of<T>(value: T): IO<T> {
    return new IO(() => value);
  }

  map<U>(fn: (value: T) => U): IO<U> {
    return new IO(() => fn(this.effect()));
  }

  flatMap<U>(fn: (value: T) => IO<U>): IO<U> {
    return new IO(() => fn(this.effect()).run());
  }

  run(): T {
    return this.effect();
  }
}

// Usage
const readFile = (path: string): IO<string> =>
  new IO(() => fs.readFileSync(path, 'utf-8'));

const writeFile = (path: string, content: string): IO<void> =>
  new IO(() => fs.writeFileSync(path, content));

const program = readFile('input.txt')
  .map((content) => content.toUpperCase())
  .flatMap((content) => writeFile('output.txt', content));

// Nothing happens until:
program.run();
```

**Lois monadiques :**

1. Left identity: `of(a).flatMap(f) === f(a)`
2. Right identity: `m.flatMap(of) === m`
3. Associativity: `m.flatMap(f).flatMap(g) === m.flatMap(x => f(x).flatMap(g))`

**Quand :** Chaînage de contextes, composition d'effets.
**Lié à :** Option, Either, IO.

---

### 10. Reader Monad

> Injection de dépendances fonctionnelle.

```go
class Reader<E, A> {
  constructor(readonly run: (env: E) => A) {}

  static of<E, A>(value: A): Reader<E, A> {
    return new Reader(() => value);
  }

  static ask<E>(): Reader<E, E> {
    return new Reader((env) => env);
  }

  map<B>(fn: (a: A) => B): Reader<E, B> {
    return new Reader((env) => fn(this.run(env)));
  }

  flatMap<B>(fn: (a: A) => Reader<E, B>): Reader<E, B> {
    return new Reader((env) => fn(this.run(env)).run(env));
  }
}

// Dependencies
interface Env {
  logger: { log: (msg: string) => void };
  db: { query: (sql: string) => Promise<any[]> };
  config: { apiUrl: string };
}

// Functions using Reader
const logMessage = (msg: string): Reader<Env, void> =>
  Reader.ask<Env>().map((env) => env.logger.log(msg));

const getUsers = (): Reader<Env, Promise<User[]>> =>
  Reader.ask<Env>().map((env) => env.db.query('SELECT * FROM users'));

const fetchFromApi = (path: string): Reader<Env, Promise<Response>> =>
  Reader.ask<Env>().map((env) => fetch(`${env.config.apiUrl}${path}`));

// Compose
const program = logMessage('Starting')
  .flatMap(() => getUsers())
  .flatMap((usersPromise) =>
    Reader.ask<Env>().map(async (env) => {
      const users = await usersPromise;
      env.logger.log(`Found ${users.length} users`);
      return users;
    }),
  );

// Run with environment
const env: Env = {
  logger: console,
  db: myDatabase,
  config: { apiUrl: 'https://api.example.com' },
};

program.run(env);
```

**Quand :** Configuration, dependency injection, environnement.
**Lié à :** Monad, Dependency Injection.

---

### 11. State Monad

> Gérer l'état de manière pure.

```go
class State<S, A> {
  constructor(readonly runState: (state: S) => [A, S]) {}

  static of<S, A>(value: A): State<S, A> {
    return new State((state) => [value, state]);
  }

  static get<S>(): State<S, S> {
    return new State((state) => [state, state]);
  }

  static put<S>(newState: S): State<S, void> {
    return new State(() => [undefined as any, newState]);
  }

  static modify<S>(fn: (state: S) => S): State<S, void> {
    return new State((state) => [undefined as any, fn(state)]);
  }

  map<B>(fn: (a: A) => B): State<S, B> {
    return new State((state) => {
      const [a, newState] = this.runState(state);
      return [fn(a), newState];
    });
  }

  flatMap<B>(fn: (a: A) => State<S, B>): State<S, B> {
    return new State((state) => {
      const [a, newState] = this.runState(state);
      return fn(a).runState(newState);
    });
  }

  run(initialState: S): [A, S] {
    return this.runState(initialState);
  }

  eval(initialState: S): A {
    return this.run(initialState)[0];
  }

  exec(initialState: S): S {
    return this.run(initialState)[1];
  }
}

// Example: Counter
interface CounterState {
  count: number;
  log: string[];
}

const increment = (): State<CounterState, number> =>
  State.get<CounterState>().flatMap((state) =>
    State.put({ ...state, count: state.count + 1 }).map(() => state.count + 1),
  );

const log = (msg: string): State<CounterState, void> =>
  State.modify<CounterState>((state) => ({
    ...state,
    log: [...state.log, msg],
  }));

const program = log('Starting')
  .flatMap(() => increment())
  .flatMap((n) => log(`Count is ${n}`))
  .flatMap(() => increment())
  .flatMap((n) => log(`Count is ${n}`));

const [result, finalState] = program.run({ count: 0, log: [] });
// finalState = { count: 2, log: ['Starting', 'Count is 1', 'Count is 2'] }
```

**Quand :** État dans contexte pur, simulations, parsers.
**Lié à :** Monad.

---

## Patterns Avancés

### 12. Lens

> Accès et modification immutable de structures imbriquées.

```go
interface Lens<S, A> {
  get: (s: S) => A;
  set: (a: A) => (s: S) => S;
}

const lens = <S, A>(
  get: (s: S) => A,
  set: (a: A) => (s: S) => S,
): Lens<S, A> => ({
  get,
  set,
});

// Compose lenses
const compose = <S, A, B>(outer: Lens<S, A>, inner: Lens<A, B>): Lens<S, B> =>
  lens(
    (s) => inner.get(outer.get(s)),
    (b) => (s) => outer.set(inner.set(b)(outer.get(s)))(s),
  );

// Modify through lens
const over = <S, A>(l: Lens<S, A>, fn: (a: A) => A) => (s: S): S =>
  l.set(fn(l.get(s)))(s);

// Example
interface Address {
  street: string;
  city: string;
}

interface Person {
  name: string;
  address: Address;
}

const addressLens: Lens<Person, Address> = lens(
  (p) => p.address,
  (a) => (p) => ({ ...p, address: a }),
);

const cityLens: Lens<Address, string> = lens(
  (a) => a.city,
  (c) => (a) => ({ ...a, city: c }),
);

const personCityLens = compose(addressLens, cityLens);

const person: Person = {
  name: 'John',
  address: { street: '123 Main', city: 'Paris' },
};

const newPerson = personCityLens.set('London')(person);
// { name: 'John', address: { street: '123 Main', city: 'London' } }
```

**Quand :** Immutabilité profonde, Redux, état complexe.
**Lié à :** Immutability.

---

### 13. Functor

> Container qui supporte map.

```go
interface Functor<T> {
  map<U>(fn: (value: T) => U): Functor<U>;
}

// Array is a functor
[1, 2, 3].map((x) => x * 2); // [2, 4, 6]

// Promise is a functor
Promise.resolve(5).then((x) => x * 2); // Promise<10>

// Custom functor
class Box<T> implements Functor<T> {
  constructor(private readonly value: T) {}

  map<U>(fn: (value: T) => U): Box<U> {
    return new Box(fn(this.value));
  }

  fold<U>(fn: (value: T) => U): U {
    return fn(this.value);
  }
}

// Usage
const result = new Box(5)
  .map((x) => x * 2)
  .map((x) => x + 1)
  .fold((x) => `Result: ${x}`);
// "Result: 11"
```

**Lois :**

1. Identity: `f.map(x => x) === f`
2. Composition: `f.map(g).map(h) === f.map(x => h(g(x)))`

**Quand :** Transformation de valeurs dans contexte.
**Lié à :** Monad, Applicative.

---

### 14. Applicative

> Functor avec application dans contexte.

```go
interface Applicative<T> extends Functor<T> {
  ap<U>(fn: Applicative<(value: T) => U>): Applicative<U>;
}

// Option as Applicative
class Some<T> implements Applicative<T> {
  constructor(readonly value: T) {}

  map<U>(fn: (value: T) => U): Some<U> {
    return new Some(fn(this.value));
  }

  ap<U>(fn: Applicative<(value: T) => U>): Applicative<U> {
    if (fn instanceof Some) {
      return new Some(fn.value(this.value));
    }
    return none;
  }

  static of<T>(value: T): Some<T> {
    return new Some(value);
  }
}

// Lift function to work with Applicatives
function liftA2<A, B, C>(
  fn: (a: A) => (b: B) => C,
  fa: Applicative<A>,
  fb: Applicative<B>,
): Applicative<C> {
  return fb.ap(fa.map(fn));
}

// Usage - combine two Options
const add = (a: number) => (b: number) => a + b;

const result = liftA2(
  add,
  Some.of(5),
  Some.of(3),
); // Some(8)

// Validation with multiple errors
const validateForm = liftA2(
  (name: string) => (email: string) => ({ name, email }),
  validateName(form.name),
  validateEmail(form.email),
);
```

**Quand :** Combiner plusieurs contextes, validation parallèle.
**Lié à :** Functor, Monad.

---

### 15. Transducer

> Composition de transformations réutilisables.

```go
type Reducer<A, B> = (acc: A, value: B) => A;
type Transducer<A, B> = <R>(reducer: Reducer<R, B>) => Reducer<R, A>;

// Basic transducers
const map =
  <A, B>(fn: (a: A) => B): Transducer<A, B> =>
  <R>(reducer: Reducer<R, B>): Reducer<R, A> =>
    (acc, value) => reducer(acc, fn(value));

const filter =
  <A>(predicate: (a: A) => boolean): Transducer<A, A> =>
  <R>(reducer: Reducer<R, A>): Reducer<R, A> =>
    (acc, value) => (predicate(value) ? reducer(acc, value) : acc);

const take =
  <A>(n: number): Transducer<A, A> =>
  <R>(reducer: Reducer<R, A>): Reducer<R, A> => {
    let taken = 0;
    return (acc, value) => {
      if (taken < n) {
        taken++;
        return reducer(acc, value);
      }
      return acc;
    };
  };

// Compose transducers
const compose = <A, B, C>(t1: Transducer<A, B>, t2: Transducer<B, C>): Transducer<A, C> =>
  <R>(reducer: Reducer<R, C>) => t1(t2(reducer));

// Usage
const transducer = compose(
  filter((x: number) => x % 2 === 0),
  map((x: number) => x * 2),
);

const result = [1, 2, 3, 4, 5].reduce(
  transducer((acc: number[], x) => [...acc, x]),
  [],
);
// [4, 8]

// Works with any collection/stream
function transduce<A, B, R>(
  transducer: Transducer<A, B>,
  reducer: Reducer<R, B>,
  initial: R,
  collection: Iterable<A>,
): R {
  const xf = transducer(reducer);
  let acc = initial;
  for (const item of collection) {
    acc = xf(acc, item);
  }
  return acc;
}
```

**Quand :** Pipelines efficaces, streams, collections infinies.
**Lié à :** Composition, Iterator.

---

## Tableau de décision

| Besoin | Pattern |
|--------|---------|
| Éviter null | Option/Maybe |
| Succès ou erreur | Either/Result |
| Chaîner contextes | Monad |
| Dependency injection | Reader |
| État pur | State |
| Modification imbriquée | Lens |
| Transformer dans contexte | Functor |
| Combiner contextes | Applicative |
| Pipelines efficaces | Transducer |
| Configuration partielle | Currying |
| Combiner fonctions | Composition |

## Sources

- [Professor Frisby's Guide to FP](https://mostly-adequate.gitbook.io/mostly-adequate-guide/)
- [Functional Programming in TypeScript](https://github.com/gcanti/fp-ts)
- [Learn You a Haskell](http://learnyouahaskell.com/)
