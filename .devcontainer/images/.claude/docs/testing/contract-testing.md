# Contract Testing

> Verification des contrats API entre services via tests consumer-driven.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                    Contract Testing Flow                         │
│                                                                  │
│   ┌──────────────┐         Contract         ┌──────────────┐   │
│   │   Consumer   │ ─────────────────────────►│   Provider   │   │
│   │  (Frontend)  │                           │   (Backend)  │   │
│   └──────────────┘                           └──────────────┘   │
│          │                                          │            │
│          ▼                                          ▼            │
│   1. Write consumer       3. Provider verifies                  │
│      expectations            against contract                    │
│          │                                          │            │
│          └──────────► 2. Publish contract ◄─────────┘            │
│                           (Pact Broker)                          │
└─────────────────────────────────────────────────────────────────┘
```

## Consumer Test (Pact)

```typescript
import { Pact, Matchers } from '@pact-foundation/pact';
import path from 'path';

const { like, eachLike, term } = Matchers;

describe('User API Consumer', () => {
  const provider = new Pact({
    consumer: 'OrderService',
    provider: 'UserService',
    port: 1234,
    log: path.resolve(__dirname, 'logs', 'pact.log'),
    dir: path.resolve(__dirname, 'pacts'),
    logLevel: 'warn',
  });

  beforeAll(() => provider.setup());
  afterAll(() => provider.finalize());
  afterEach(() => provider.verify());

  describe('GET /users/:id', () => {
    const expectedUser = {
      id: '123',
      name: 'John Doe',
      email: 'john@example.com',
      role: 'member',
    };

    beforeEach(() => {
      return provider.addInteraction({
        state: 'a user with id 123 exists',
        uponReceiving: 'a request for user 123',
        withRequest: {
          method: 'GET',
          path: '/users/123',
          headers: {
            Accept: 'application/json',
          },
        },
        willRespondWith: {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
          },
          body: like(expectedUser), // Matches structure, not exact values
        },
      });
    });

    test('should return user data', async () => {
      const client = new UserClient(`http://localhost:${provider.port}`);
      const user = await client.getUser('123');

      expect(user).toEqual(expectedUser);
    });
  });

  describe('GET /users/:id - not found', () => {
    beforeEach(() => {
      return provider.addInteraction({
        state: 'a user with id 999 does not exist',
        uponReceiving: 'a request for non-existent user 999',
        withRequest: {
          method: 'GET',
          path: '/users/999',
          headers: {
            Accept: 'application/json',
          },
        },
        willRespondWith: {
          status: 404,
          body: {
            error: 'User not found',
            code: 'USER_NOT_FOUND',
          },
        },
      });
    });

    test('should handle not found', async () => {
      const client = new UserClient(`http://localhost:${provider.port}`);

      await expect(client.getUser('999')).rejects.toThrow('User not found');
    });
  });
});
```

## Flexible Matching

```typescript
import { Matchers } from '@pact-foundation/pact';

const { like, eachLike, term, integer, boolean, iso8601DateTimeWithMillis } =
  Matchers;

// Type matchers
const userMatcher = {
  id: like('123'), // Any string
  name: like('John'), // Any string
  age: integer(25), // Any integer
  active: boolean(true), // Any boolean
  createdAt: iso8601DateTimeWithMillis('2024-01-01T00:00:00.000Z'),
  role: term({
    generate: 'member',
    matcher: '^(admin|member|guest)$', // Regex
  }),
};

// Array matcher
const userListMatcher = {
  users: eachLike(userMatcher, { min: 1 }), // At least one user
  total: integer(10),
  page: integer(1),
};

// Nested matchers
const orderMatcher = {
  id: like('order-123'),
  user: like(userMatcher),
  items: eachLike({
    productId: like('prod-1'),
    quantity: integer(1),
    price: like(29.99),
  }),
  status: term({
    generate: 'pending',
    matcher: '^(pending|confirmed|shipped|delivered)$',
  }),
};
```

## Provider Verification

```typescript
import { Verifier } from '@pact-foundation/pact';

describe('User Service Provider', () => {
  let server: Server;

  beforeAll(async () => {
    // Start the actual provider service
    server = await startServer(3000);
  });

  afterAll(async () => {
    await server.close();
  });

  test('validates the expectations of the consumer', async () => {
    const opts = {
      provider: 'UserService',
      providerBaseUrl: 'http://localhost:3000',

      // From Pact Broker
      pactBrokerUrl: process.env.PACT_BROKER_URL,
      pactBrokerToken: process.env.PACT_BROKER_TOKEN,
      publishVerificationResult: process.env.CI === 'true',
      providerVersion: process.env.GIT_SHA,

      // Or from local files
      // pactUrls: ['./pacts/orderservice-userservice.json'],

      // State handlers
      stateHandlers: {
        'a user with id 123 exists': async () => {
          await db.users.create({
            id: '123',
            name: 'John Doe',
            email: 'john@example.com',
            role: 'member',
          });
        },
        'a user with id 999 does not exist': async () => {
          await db.users.deleteMany({ id: '999' });
        },
      },

      // Request filters (add auth headers, etc.)
      requestFilter: (req, res, next) => {
        req.headers['Authorization'] = 'Bearer test-token';
        next();
      },
    };

    await new Verifier(opts).verifyProvider();
  });
});
```

## CI/CD Integration

```yaml
# .github/workflows/contract-tests.yml
name: Contract Tests

on: [push, pull_request]

jobs:
  consumer-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run consumer contract tests
        run: npm run test:contract:consumer

      - name: Publish pacts to broker
        run: |
          npx pact-broker publish ./pacts \
            --broker-base-url=${{ secrets.PACT_BROKER_URL }} \
            --broker-token=${{ secrets.PACT_BROKER_TOKEN }} \
            --consumer-app-version=${{ github.sha }} \
            --tag=${{ github.ref_name }}

  provider-tests:
    runs-on: ubuntu-latest
    needs: consumer-tests
    steps:
      - uses: actions/checkout@v4

      - name: Verify provider against pacts
        env:
          PACT_BROKER_URL: ${{ secrets.PACT_BROKER_URL }}
          PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}
          GIT_SHA: ${{ github.sha }}
        run: npm run test:contract:provider

      - name: Can I Deploy?
        run: |
          npx pact-broker can-i-deploy \
            --pacticipant=UserService \
            --version=${{ github.sha }} \
            --to-environment=production
```

## Schema-Based Contracts (Alternative)

```typescript
// OpenAPI schema validation
import SwaggerParser from '@apidevtools/swagger-parser';
import Ajv from 'ajv';

class OpenAPIContractValidator {
  private ajv = new Ajv({ allErrors: true });
  private schemas: Map<string, any> = new Map();

  async loadSpec(specPath: string): Promise<void> {
    const api = await SwaggerParser.validate(specPath);

    // Extract response schemas
    for (const [path, methods] of Object.entries(api.paths || {})) {
      for (const [method, operation] of Object.entries(methods as any)) {
        const responses = operation.responses || {};
        for (const [status, response] of Object.entries(responses)) {
          const schema = (response as any).content?.['application/json']?.schema;
          if (schema) {
            const key = `${method.toUpperCase()} ${path} ${status}`;
            this.schemas.set(key, schema);
          }
        }
      }
    }
  }

  validateResponse(method: string, path: string, status: number, body: any): boolean {
    const key = `${method} ${path} ${status}`;
    const schema = this.schemas.get(key);

    if (!schema) {
      throw new Error(`No schema found for ${key}`);
    }

    const validate = this.ajv.compile(schema);
    return validate(body) as boolean;
  }
}

// Usage in tests
test('API response matches OpenAPI schema', async () => {
  const validator = new OpenAPIContractValidator();
  await validator.loadSpec('./openapi.yaml');

  const response = await fetch('/users/123');
  const body = await response.json();

  expect(validator.validateResponse('GET', '/users/{id}', 200, body)).toBe(true);
});
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `@pact-foundation/pact` | Consumer-driven contracts |
| `pact-broker` | Contract storage/management |
| `@apidevtools/swagger-parser` | OpenAPI validation |
| `dredd` | API Blueprint testing |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Matchers trop stricts | Tests fragiles | `like()`, `term()` |
| Pas de state handlers | Provider verification echoue | Implementer tous les states |
| Oublier can-i-deploy | Deploy breaking changes | CI gate obligatoire |
| Tests synchrones | Race conditions | Async/await proper |
| Pacts non publies | Provider ne les voit pas | Publish en CI |

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| Microservices | Oui |
| API publique | Oui |
| Frontend/Backend separes | Oui |
| Monolithe | Non necessaire |
| Prototypage rapide | Trop overhead |

## Patterns lies

- **Test Doubles** : Mocks complementaires
- **Integration Tests** : Verification end-to-end
- **API Versioning** : Gestion changements contrats

## Sources

- [Pact Documentation](https://docs.pact.io/)
- [Consumer-Driven Contracts - Martin Fowler](https://martinfowler.com/articles/consumerDrivenContracts.html)
- [Contract Testing vs E2E Testing](https://pactflow.io/blog/contract-testing-vs-end-to-end-e2e-testing/)
