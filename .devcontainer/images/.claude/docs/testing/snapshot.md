# Snapshot Testing

> Capturer et comparer la sortie avec une reference enregistree.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                    Snapshot Testing Flow                         │
│                                                                  │
│   First Run:    Output ──────────► Save as snapshot             │
│                                                                  │
│   Next Runs:    Output ──► Compare ──► Match? ──► Pass          │
│                              │                                   │
│                              └──► Mismatch? ──► Fail or Update   │
└─────────────────────────────────────────────────────────────────┘
```

## Basic Snapshots (Jest)

```typescript
// Component snapshot
import { render } from '@testing-library/react';

describe('UserProfile', () => {
  test('renders correctly', () => {
    const { container } = render(
      <UserProfile
        user={{
          id: '123',
          name: 'John Doe',
          email: 'john@example.com',
          avatar: 'https://example.com/avatar.jpg',
        }}
      />,
    );

    expect(container).toMatchSnapshot();
  });

  test('renders loading state', () => {
    const { container } = render(<UserProfile loading={true} />);
    expect(container).toMatchSnapshot();
  });

  test('renders error state', () => {
    const { container } = render(
      <UserProfile error={new Error('Failed to load')} />,
    );
    expect(container).toMatchSnapshot();
  });
});
```

Generated snapshot file (`__snapshots__/UserProfile.test.tsx.snap`):
```
exports[`UserProfile renders correctly 1`] = `
<div>
  <div
    class="profile"
  >
    <img
      alt="John Doe"
      src="https://example.com/avatar.jpg"
    />
    <h1>
      John Doe
    </h1>
    <p>
      john@example.com
    </p>
  </div>
</div>
`;
```

## Inline Snapshots

```typescript
// Inline snapshots are stored in the test file
test('formatDate returns expected format', () => {
  expect(formatDate(new Date('2024-01-15'))).toMatchInlineSnapshot(
    `"January 15, 2024"`,
  );
});

test('serialize user', () => {
  const user = { id: '1', name: 'John' };
  expect(JSON.stringify(user, null, 2)).toMatchInlineSnapshot(`
    "{
      \\"id\\": \\"1\\",
      \\"name\\": \\"John\\"
    }"
  `);
});

// Automatically updated when running jest -u
```

## API Response Snapshots

```typescript
describe('API Responses', () => {
  test('GET /users returns expected structure', async () => {
    const response = await request(app).get('/users');

    // Snapshot the structure
    expect(response.body).toMatchSnapshot({
      users: expect.arrayContaining([
        expect.objectContaining({
          id: expect.any(String),
          createdAt: expect.any(String),
        }),
      ]),
    });
  });

  test('error response format', async () => {
    const response = await request(app).get('/users/invalid');

    expect(response.body).toMatchInlineSnapshot(`
      {
        "error": "User not found",
        "code": "USER_NOT_FOUND",
        "status": 404
      }
    `);
  });
});
```

## Property Matchers

```typescript
// Handle dynamic values that change between runs
test('user with dynamic values', () => {
  const user = createUser();

  expect(user).toMatchSnapshot({
    id: expect.any(String), // Ignore actual ID value
    createdAt: expect.any(Date), // Ignore actual date
    updatedAt: expect.any(Date),
  });
});

// Multiple levels
test('order with dynamic values', () => {
  const order = createOrder();

  expect(order).toMatchSnapshot({
    id: expect.any(String),
    createdAt: expect.any(Date),
    items: expect.arrayContaining([
      expect.objectContaining({
        id: expect.any(String),
      }),
    ]),
  });
});
```

## Custom Serializers

```typescript
// Customize how objects are serialized in snapshots
expect.addSnapshotSerializer({
  test: (val) => val instanceof Date,
  print: (val) => `Date(${(val as Date).toISOString()})`,
});

expect.addSnapshotSerializer({
  test: (val) => val && typeof val === 'object' && 'password' in val,
  print: (val, print) => {
    const { password, ...rest } = val as Record<string, unknown>;
    return print({ ...rest, password: '[REDACTED]' });
  },
});

// Custom serializer for React components
import { createSerializer } from '@emotion/jest';
expect.addSnapshotSerializer(createSerializer());

// Usage
test('component with emotion styles', () => {
  const { container } = render(<StyledButton>Click me</StyledButton>);
  expect(container).toMatchSnapshot();
});
```

## Snapshot Testing Strategies

```typescript
// 1. Component Snapshots - Full render
test('full component snapshot', () => {
  const { container } = render(<ComplexForm />);
  expect(container).toMatchSnapshot();
});

// 2. Partial Snapshots - Specific parts
test('form fields snapshot', () => {
  const { getByTestId } = render(<ComplexForm />);
  expect(getByTestId('email-field')).toMatchSnapshot();
  expect(getByTestId('password-field')).toMatchSnapshot();
});

// 3. Data Snapshots - API/Config output
test('config generation', () => {
  const config = generateConfig({ env: 'production' });
  expect(config).toMatchSnapshot();
});

// 4. Error Snapshots - Error messages
test('validation errors', () => {
  const errors = validateForm({
    email: 'invalid',
    password: '123',
  });
  expect(errors).toMatchInlineSnapshot(`
    [
      {
        "field": "email",
        "message": "Invalid email format"
      },
      {
        "field": "password",
        "message": "Password must be at least 8 characters"
      }
    ]
  `);
});
```

## Vitest Snapshots

```typescript
import { describe, expect, test } from 'vitest';

describe('snapshots with Vitest', () => {
  test('inline snapshot', () => {
    expect({ hello: 'world' }).toMatchInlineSnapshot(`
      {
        "hello": "world",
      }
    `);
  });

  test('file snapshot', () => {
    expect(renderComponent()).toMatchSnapshot();
  });

  // Vitest-specific: toMatchFileSnapshot
  test('save to specific file', async () => {
    const output = generateReport();
    await expect(output).toMatchFileSnapshot('./snapshots/report.txt');
  });
});
```

## CI/CD Integration

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test -- --ci

      - name: Check for uncommitted snapshot changes
        run: |
          if [ -n "$(git status --porcelain **/\*.snap)" ]; then
            echo "Snapshot files have changed. Please update and commit."
            git diff **/\*.snap
            exit 1
          fi
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `jest` | Built-in snapshot support |
| `vitest` | Jest-compatible snapshots |
| `@testing-library/react` | React component testing |
| `react-test-renderer` | React snapshot rendering |
| `@emotion/jest` | Emotion CSS serializer |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Snapshots trop grands | Review difficile | Snapshots partiels |
| Update sans review | Bugs masques | Review chaque update |
| Donnees dynamiques | Tests flaky | Property matchers |
| Commit auto-updates | Changements non voulus | CI check strict |
| Trop de snapshots | Maintenance lourde | Cibler elements stables |

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| UI components | Oui |
| API response format | Oui |
| Config/output generation | Oui |
| Highly dynamic content | Non |
| Logic testing | Non (assertions) |
| Frequent structure changes | Avec prudence |

## Best practices

```typescript
// 1. Name snapshots clearly
test('UserProfile: logged in user with avatar', () => { ... });

// 2. One concern per snapshot
test('header renders correctly', () => { ... });
test('content renders correctly', () => { ... });

// 3. Use inline for small, stable outputs
expect(result).toMatchInlineSnapshot(`"expected output"`);

// 4. Review every snapshot update
// git diff before committing

// 5. Clean up obsolete snapshots
// jest --updateSnapshot --testPathPattern=specific-file
```

## Patterns lies

- **Visual Regression** : Screenshot comparison
- **Contract Testing** : API structure validation
- **Golden Master** : Reference output testing

## Sources

- [Jest Snapshot Testing](https://jestjs.io/docs/snapshot-testing)
- [Effective Snapshot Testing](https://kentcdodds.com/blog/effective-snapshot-testing)
- [Vitest Snapshots](https://vitest.dev/guide/snapshot.html)
