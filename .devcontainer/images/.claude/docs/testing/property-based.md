# Property-Based Testing

> Tests generatifs qui verifient des proprietes sur des donnees aleatoires.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                   Property-Based Testing                         │
│                                                                  │
│   Traditional:  test(input1) → expected1                        │
│                 test(input2) → expected2                        │
│                                                                  │
│   Property:     forAll(inputs) → property holds                 │
│                                                                  │
│   Generator ──► Random Input ──► Function ──► Property Check    │
│       │                                            │             │
│       └────────────── Shrinking on failure ◄───────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## fast-check Basics

```typescript
import fc from 'fast-check';

describe('String operations', () => {
  // Property: reverse(reverse(s)) === s
  test('reverse is its own inverse', () => {
    fc.assert(
      fc.property(fc.string(), (s) => {
        const reversed = s.split('').reverse().join('');
        const doubleReversed = reversed.split('').reverse().join('');
        return doubleReversed === s;
      }),
    );
  });

  // Property: length is preserved
  test('reverse preserves length', () => {
    fc.assert(
      fc.property(fc.string(), (s) => {
        return s.split('').reverse().join('').length === s.length;
      }),
    );
  });
});

describe('Math operations', () => {
  // Property: addition is commutative
  test('a + b === b + a', () => {
    fc.assert(
      fc.property(fc.integer(), fc.integer(), (a, b) => {
        return a + b === b + a;
      }),
    );
  });

  // Property: addition is associative
  test('(a + b) + c === a + (b + c)', () => {
    fc.assert(
      fc.property(fc.integer(), fc.integer(), fc.integer(), (a, b, c) => {
        return (a + b) + c === a + (b + c);
      }),
    );
  });

  // Property: zero is identity
  test('a + 0 === a', () => {
    fc.assert(
      fc.property(fc.integer(), (a) => {
        return a + 0 === a;
      }),
    );
  });
});
```

## Arbitraries (Generators)

```typescript
import fc from 'fast-check';

// Built-in arbitraries
fc.integer(); // Any integer
fc.integer({ min: 0, max: 100 }); // Range
fc.nat(); // Natural numbers (>= 0)
fc.float(); // Floating point
fc.string(); // Any string
fc.string({ minLength: 1, maxLength: 10 }); // Constrained
fc.boolean(); // true/false
fc.date(); // Date objects
fc.uuid(); // UUIDs
fc.emailAddress(); // Valid emails
fc.ipV4(); // IP addresses

// Arrays and objects
fc.array(fc.integer()); // Array of integers
fc.array(fc.string(), { minLength: 1, maxLength: 5 }); // Constrained array
fc.record({ name: fc.string(), age: fc.nat() }); // Object

// Custom arbitrary
const userArbitrary = fc.record({
  id: fc.uuid(),
  email: fc.emailAddress(),
  name: fc.string({ minLength: 2, maxLength: 50 }),
  age: fc.integer({ min: 0, max: 120 }),
  role: fc.constantFrom('admin', 'member', 'guest'),
});

// Transformed arbitrary
const positiveEvenArbitrary = fc
  .nat()
  .filter((n) => n > 0)
  .map((n) => n * 2);

// Dependent arbitrary
const arrayWithIndex = fc.array(fc.string(), { minLength: 1 }).chain((arr) =>
  fc.record({
    array: fc.constant(arr),
    index: fc.integer({ min: 0, max: arr.length - 1 }),
  }),
);
```

## Common Properties

```typescript
import fc from 'fast-check';

// 1. Roundtrip / Serialization
describe('JSON serialization', () => {
  test('parse(stringify(x)) === x', () => {
    fc.assert(
      fc.property(fc.jsonValue(), (value) => {
        const serialized = JSON.stringify(value);
        const parsed = JSON.parse(serialized);
        return JSON.stringify(parsed) === serialized;
      }),
    );
  });
});

// 2. Idempotence
describe('sort function', () => {
  test('sort is idempotent', () => {
    fc.assert(
      fc.property(fc.array(fc.integer()), (arr) => {
        const sorted1 = [...arr].sort((a, b) => a - b);
        const sorted2 = [...sorted1].sort((a, b) => a - b);
        return JSON.stringify(sorted1) === JSON.stringify(sorted2);
      }),
    );
  });
});

// 3. Invariants
describe('array operations', () => {
  test('push increases length by 1', () => {
    fc.assert(
      fc.property(fc.array(fc.integer()), fc.integer(), (arr, elem) => {
        const originalLength = arr.length;
        const newArr = [...arr, elem];
        return newArr.length === originalLength + 1;
      }),
    );
  });

  test('filter result is subset', () => {
    fc.assert(
      fc.property(fc.array(fc.integer()), (arr) => {
        const filtered = arr.filter((x) => x > 0);
        return filtered.every((x) => arr.includes(x));
      }),
    );
  });
});

// 4. Oracle / Reference implementation
describe('binary search', () => {
  test('finds same result as linear search', () => {
    fc.assert(
      fc.property(
        fc.array(fc.integer()).map((arr) => arr.sort((a, b) => a - b)),
        fc.integer(),
        (sortedArr, target) => {
          const binaryResult = binarySearch(sortedArr, target);
          const linearResult = sortedArr.indexOf(target);
          return binaryResult === linearResult;
        },
      ),
    );
  });
});

// 5. Metamorphic testing
describe('calculator', () => {
  test('multiply by 2 equals add to self', () => {
    fc.assert(
      fc.property(fc.integer({ min: -1000, max: 1000 }), (n) => {
        return n * 2 === n + n;
      }),
    );
  });
});
```

## Domain-Specific Generators

```typescript
import fc from 'fast-check';

// E-commerce domain
const productArbitrary = fc.record({
  id: fc.uuid(),
  name: fc.string({ minLength: 1, maxLength: 100 }),
  price: fc.float({ min: 0.01, max: 10000, noNaN: true }),
  stock: fc.nat({ max: 1000 }),
  category: fc.constantFrom('electronics', 'clothing', 'food'),
});

const orderItemArbitrary = fc.record({
  productId: fc.uuid(),
  quantity: fc.integer({ min: 1, max: 100 }),
  unitPrice: fc.float({ min: 0.01, max: 10000, noNaN: true }),
});

const orderArbitrary = fc.record({
  id: fc.uuid(),
  userId: fc.uuid(),
  items: fc.array(orderItemArbitrary, { minLength: 1, maxLength: 20 }),
  status: fc.constantFrom('pending', 'confirmed', 'shipped', 'delivered'),
  createdAt: fc.date(),
});

// Test order total calculation
test('order total equals sum of items', () => {
  fc.assert(
    fc.property(orderArbitrary, (order) => {
      const calculatedTotal = order.items.reduce(
        (sum, item) => sum + item.quantity * item.unitPrice,
        0,
      );
      // Allow small floating point differences
      const orderTotal = calculateOrderTotal(order);
      return Math.abs(calculatedTotal - orderTotal) < 0.01;
    }),
  );
});
```

## Shrinking

```typescript
import fc from 'fast-check';

// fast-check automatically shrinks failing cases
test('example with shrinking', () => {
  fc.assert(
    fc.property(fc.array(fc.integer()), (arr) => {
      // This will fail for arrays with negative numbers
      return arr.every((x) => x >= 0);
    }),
    {
      // Shrinking tries to find minimal failing case
      // e.g., [1, -1, 2, 3, 4] shrinks to [-1]
    },
  );
});

// Custom shrinking
const customIntArbitrary = fc.integer().map((n, { context }) => ({
  value: n,
  shrinker: () => [0, 1, -1].filter((x) => Math.abs(x) < Math.abs(n)),
}));

// Report configuration
fc.assert(
  fc.property(fc.string(), (s) => s.length < 10),
  {
    verbose: true, // Show failing examples
    numRuns: 1000, // Run 1000 tests
    seed: 42, // Reproducible runs
  },
);
```

## Async Properties

```typescript
import fc from 'fast-check';

describe('async operations', () => {
  test('database roundtrip', async () => {
    await fc.assert(
      fc.asyncProperty(userArbitrary, async (user) => {
        await userRepo.save(user);
        const retrieved = await userRepo.findById(user.id);
        return retrieved?.email === user.email;
      }),
    );
  });

  test('API response validation', async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.uuid(),
        async (userId) => {
          const response = await api.getUser(userId);
          return response.status === 200 || response.status === 404;
        },
      ),
      { numRuns: 50 }, // Fewer runs for API tests
    );
  });
});
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `fast-check` | Property-based testing JS/TS |
| `jsverify` | Alternative (less maintained) |
| `@fast-check/jest` | Jest integration |
| `@fast-check/vitest` | Vitest integration |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Arbitraires trop larges | Tests lents, faux positifs | Constraindre les domaines |
| Ignorer shrinking | Debug difficile | Analyser minimal cases |
| Trop de numRuns | Tests lents | 100-1000 suffit souvent |
| Proprietes triviales | Tests inutiles | Tester vraies invariantes |
| Oublier edge cases | Bugs manques | Combiner avec example-based |

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| Algorithmes purs | Oui |
| Serialization/parsing | Oui |
| Transformations de donnees | Oui |
| Business logic complexe | Oui |
| UI testing | Non |
| Integration avec external | Avec prudence |

## Patterns lies

- **Parameterized Tests** : Version manuelle
- **Fuzzing** : Security testing similaire
- **Snapshot Testing** : Complementaire pour regression

## Sources

- [fast-check Documentation](https://fast-check.dev/)
- [Property-Based Testing with PropEr, Erlang, and Elixir](https://pragprog.com/titles/fhproper/property-based-testing-with-proper-erlang-and-elixir/)
- [Choosing Properties for Property-Based Testing](https://fsharpforfunandprofit.com/posts/property-based-testing-2/)
