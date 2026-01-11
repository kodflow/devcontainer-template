# Lens Pattern

## Definition

A **Lens** is a composable getter/setter pair that provides a functional way to focus on and manipulate nested data structures immutably. It solves the problem of updating deeply nested immutable data.

```
Lens<S, A> = {
  get: (s: S) => A,
  set: (a: A) => (s: S) => S
}
```

**Key characteristics:**
- **Composable**: Lenses can be combined to focus deeper
- **Immutable updates**: Returns new structures, doesn't mutate
- **Bidirectional**: Can both read and write
- **Type-safe**: Full type inference for nested access
- **Reusable**: Same lens for get and set operations

## Lens Laws

1. **Get-Put**: `set(get(s))(s) === s` (setting what you get changes nothing)
2. **Put-Get**: `get(set(a)(s)) === a` (you get what you set)
3. **Put-Put**: `set(a2)(set(a1)(s)) === set(a2)(s)` (setting twice = setting once)

## TypeScript Implementation

```typescript
// Basic Lens type
interface Lens<S, A> {
  get: (s: S) => A;
  set: (a: A) => (s: S) => S;
}

// Lens creation helper
const lens = <S, A>(
  get: (s: S) => A,
  set: (a: A) => (s: S) => S
): Lens<S, A> => ({ get, set });

// Modify using lens
const modify = <S, A>(
  lens: Lens<S, A>,
  f: (a: A) => A
) => (s: S): S =>
  lens.set(f(lens.get(s)))(s);

// Compose lenses
const compose = <A, B, C>(
  outer: Lens<A, B>,
  inner: Lens<B, C>
): Lens<A, C> => lens(
  (a: A) => inner.get(outer.get(a)),
  (c: C) => (a: A) => outer.set(inner.set(c)(outer.get(a)))(a)
);

// Prop lens - create lens for object property
const prop = <S, K extends keyof S>(key: K): Lens<S, S[K]> => lens(
  (s) => s[key],
  (a) => (s) => ({ ...s, [key]: a })
);

// Index lens - create lens for array index
const index = <A>(i: number): Lens<A[], A | undefined> => lens(
  (arr) => arr[i],
  (a) => (arr) => a === undefined
    ? [...arr.slice(0, i), ...arr.slice(i + 1)]
    : [...arr.slice(0, i), a, ...arr.slice(i + 1)]
);
```

## Usage Examples

```typescript
// Domain types
interface Address {
  street: string;
  city: string;
  country: string;
}

interface Company {
  name: string;
  address: Address;
}

interface User {
  id: string;
  name: string;
  company: Company;
}

// Create lenses
const userCompanyLens = prop<User, 'company'>('company');
const companyAddressLens = prop<Company, 'address'>('address');
const addressCityLens = prop<Address, 'city'>('city');

// Compose for deep access
const userCityLens = compose(
  compose(userCompanyLens, companyAddressLens),
  addressCityLens
);

// Usage
const user: User = {
  id: '1',
  name: 'Alice',
  company: {
    name: 'Acme',
    address: {
      street: '123 Main',
      city: 'Boston',
      country: 'USA'
    }
  }
};

// Get nested value
const city = userCityLens.get(user); // 'Boston'

// Set nested value (returns new user)
const updatedUser = userCityLens.set('New York')(user);
// user.company.address.city is still 'Boston'
// updatedUser.company.address.city is 'New York'

// Modify nested value
const uppercaseCity = modify(userCityLens, city => city.toUpperCase())(user);
// uppercaseCity.company.address.city is 'BOSTON'
```

## Using monocle-ts

```typescript
import { Lens, Optional, Prism } from 'monocle-ts';
import { pipe } from 'fp-ts/function';
import * as O from 'fp-ts/Option';

// Create lenses with fromProp
const userCompany = Lens.fromProp<User>()('company');
const companyAddress = Lens.fromProp<Company>()('address');
const addressCity = Lens.fromProp<Address>()('city');

// Compose with .compose()
const userCity = userCompany.compose(companyAddress).compose(addressCity);

// Operations
const getCity = userCity.get(user);
const setCity = userCity.set('Chicago')(user);
const modifyCity = userCity.modify(c => c.toUpperCase())(user);

// Optional - for potentially missing values
interface Profile { nickname?: string }
interface Account { profile?: Profile }

const accountProfile = Optional.fromNullableProp<Account>()('profile');
const profileNickname = Optional.fromNullableProp<Profile>()('nickname');

const accountNickname = accountProfile.compose(profileNickname);

const account: Account = { profile: { nickname: 'bob' } };
const nickname = accountNickname.getOption(account); // O.some('bob')

const emptyAccount: Account = {};
const noNickname = accountNickname.getOption(emptyAccount); // O.none

// Prism - for sum types
type Shape =
  | { type: 'circle'; radius: number }
  | { type: 'rectangle'; width: number; height: number };

const circlePrism = Prism.fromPredicate<Shape, Extract<Shape, { type: 'circle' }>>(
  (s): s is Extract<Shape, { type: 'circle' }> => s.type === 'circle'
);

const shapes: Shape[] = [
  { type: 'circle', radius: 10 },
  { type: 'rectangle', width: 5, height: 3 }
];

// Get only circles
const circles = shapes.map(s => circlePrism.getOption(s)).filter(O.isSome);
```

## Using Effect (Optics)

```typescript
import { Optic, pipe } from 'effect';

// Create optics
const user = Optic.id<User>();
const company = user.at('company');
const address = company.at('address');
const city = address.at('city');

// Get value
const cityValue = Optic.get(city)(user);

// Set value
const updatedUser = Optic.replace(city)('Chicago')(user);

// Modify value
const modifiedUser = Optic.modify(city)(c => c.toUpperCase())(user);

// Optional access
interface Config {
  database?: {
    host?: string;
    port?: number;
  };
}

const config = Optic.id<Config>();
const dbHost = config.at('database').at('host');

// Safe access to optional fields
const host = pipe(
  { database: { host: 'localhost' } },
  Optic.getOption(dbHost)
); // Option.some('localhost')
```

## Optic Types

| Optic | Get | Set | Use Case |
|-------|-----|-----|----------|
| **Lens** | Always | Always | Product types (objects) |
| **Prism** | Maybe | Always | Sum types (unions) |
| **Optional** | Maybe | Always | Optional fields |
| **Iso** | Always | Always | Isomorphic types |
| **Traversal** | Multiple | Multiple | Collections |

```typescript
// Traversal - focus on multiple elements
import { Traversal } from 'monocle-ts';

interface Order {
  items: OrderItem[];
}

interface OrderItem {
  price: number;
}

const orderItems = Lens.fromProp<Order>()('items');
const itemsTraversal = Traversal.fromTraversable(A.Traversable)<OrderItem>();
const itemPrice = Lens.fromProp<OrderItem>()('price');

// Compose lens + traversal + lens
const allPrices = orderItems.composeTraversal(itemsTraversal).composeLens(itemPrice);

// Modify all prices
const discountedOrder = allPrices.modify(p => p * 0.9)(order);
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **monocle-ts** | Full optics library | `npm i monocle-ts` |
| **Effect** | Built-in optics | `npm i effect` |
| **partial.lenses** | Lightweight lenses | `npm i partial.lenses` |
| **shades** | TypeScript lenses | `npm i shades` |
| **immer** | Alternative (proxies) | `npm i immer` |

## Lens vs Spread Operator

```typescript
// Without lens - deeply nested update
const updateCity = (user: User, newCity: string): User => ({
  ...user,
  company: {
    ...user.company,
    address: {
      ...user.company.address,
      city: newCity
    }
  }
});

// With lens - clean and reusable
const updateCity = (user: User, newCity: string): User =>
  userCityLens.set(newCity)(user);

// Lens advantage: reusable for multiple operations
const getCity = userCityLens.get(user);
const setCity = userCityLens.set('NYC')(user);
const upperCity = modify(userCityLens, s => s.toUpperCase())(user);
```

## Anti-patterns

1. **Creating Lenses Inline**: Loses reusability
   ```typescript
   // BAD
   lens(u => u.company.address.city, c => u => ({ ...u, ... }))(user)

   // GOOD
   const userCityLens = compose(userCompany, companyAddress, addressCity);
   userCityLens.get(user);
   ```

2. **Over-using for Simple Cases**: Unnecessary complexity
   ```typescript
   // BAD - Overkill for single property
   const nameLens = prop<User, 'name'>('name');
   nameLens.set('Bob')(user);

   // OK for simple cases
   const updated = { ...user, name: 'Bob' };
   ```

3. **Mutating Through Lens**: Breaking immutability
   ```typescript
   // BAD
   const address = addressLens.get(user);
   address.city = 'NYC'; // Mutation!
   ```

## When to Use

- Deeply nested immutable updates
- Reusable accessor/mutator logic
- Complex state management
- Working with immutable data structures
- Redux reducers with nested state

## See Also

- [Composition](./composition.md) - Lenses are composable
- [Option](./option.md) - Optional optics return Option
- [Monad](./monad.md) - Some optics are monadic
