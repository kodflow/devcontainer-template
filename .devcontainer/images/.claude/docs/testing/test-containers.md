# Test Containers

> Infrastructure reelle dans des containers Docker pour les tests d'integration.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                    Testcontainers Architecture                   │
│                                                                  │
│   Test Suite                                                     │
│       │                                                          │
│       ├── beforeAll: Start containers                           │
│       │       │                                                  │
│       │       ▼                                                  │
│       │   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│       │   │  PostgreSQL │  │    Redis    │  │    Kafka    │    │
│       │   │  :5432      │  │  :6379      │  │  :9092      │    │
│       │   └─────────────┘  └─────────────┘  └─────────────┘    │
│       │                                                          │
│       ├── Tests run against real infrastructure                 │
│       │                                                          │
│       └── afterAll: Stop and cleanup containers                 │
└─────────────────────────────────────────────────────────────────┘
```

## Basic Setup

```typescript
import { GenericContainer, StartedTestContainer, Wait } from 'testcontainers';

describe('Database Integration', () => {
  let container: StartedTestContainer;
  let db: Database;

  beforeAll(async () => {
    // Start PostgreSQL container
    container = await new GenericContainer('postgres:15')
      .withEnvironment({
        POSTGRES_USER: 'test',
        POSTGRES_PASSWORD: 'test',
        POSTGRES_DB: 'testdb',
      })
      .withExposedPorts(5432)
      .withWaitStrategy(Wait.forLogMessage('ready to accept connections'))
      .start();

    // Connect to the container
    db = await Database.connect({
      host: container.getHost(),
      port: container.getMappedPort(5432),
      user: 'test',
      password: 'test',
      database: 'testdb',
    });

    // Run migrations
    await runMigrations(db);
  }, 60000); // Increase timeout for container startup

  afterAll(async () => {
    await db?.close();
    await container?.stop();
  });

  test('should insert and retrieve user', async () => {
    const repo = new UserRepository(db);

    await repo.save({
      id: '1',
      name: 'John',
      email: 'john@example.com',
    });

    const user = await repo.findById('1');
    expect(user?.name).toBe('John');
  });
});
```

## Pre-built Modules

```typescript
import { PostgreSqlContainer } from '@testcontainers/postgresql';
import { RedisContainer } from '@testcontainers/redis';
import { KafkaContainer } from '@testcontainers/kafka';
import { MongoDBContainer } from '@testcontainers/mongodb';

// PostgreSQL
const postgres = await new PostgreSqlContainer()
  .withDatabase('testdb')
  .withUsername('test')
  .withPassword('test')
  .start();

const connectionUri = postgres.getConnectionUri();

// Redis
const redis = await new RedisContainer().start();
const redisUrl = redis.getConnectionUrl();

// MongoDB
const mongodb = await new MongoDBContainer('mongo:6').start();
const mongoUri = mongodb.getConnectionString();

// Kafka
const kafka = await new KafkaContainer()
  .withExposedPorts(9093)
  .start();

const bootstrapServers = kafka.getBootstrapServers();
```

## Docker Compose

```typescript
import { DockerComposeEnvironment, StartedDockerComposeEnvironment } from 'testcontainers';

describe('Full Stack Integration', () => {
  let environment: StartedDockerComposeEnvironment;

  beforeAll(async () => {
    environment = await new DockerComposeEnvironment(
      './',
      'docker-compose.test.yml',
    )
      .withBuild()
      .withWaitStrategy('db', Wait.forHealthCheck())
      .withWaitStrategy('api', Wait.forHttp('/health', 3000))
      .up();
  }, 120000);

  afterAll(async () => {
    await environment?.down();
  });

  test('API health check', async () => {
    const apiContainer = environment.getContainer('api');
    const port = apiContainer.getMappedPort(3000);
    const host = apiContainer.getHost();

    const response = await fetch(`http://${host}:${port}/health`);
    expect(response.status).toBe(200);
  });
});
```

## Reusable Containers

```typescript
// Singleton pattern for expensive containers
class TestContainerManager {
  private static postgres: StartedTestContainer | null = null;
  private static redis: StartedTestContainer | null = null;

  static async getPostgres(): Promise<StartedTestContainer> {
    if (!this.postgres) {
      this.postgres = await new PostgreSqlContainer()
        .withReuse()
        .start();
    }
    return this.postgres;
  }

  static async getRedis(): Promise<StartedTestContainer> {
    if (!this.redis) {
      this.redis = await new RedisContainer()
        .withReuse()
        .start();
    }
    return this.redis;
  }

  static async stopAll(): Promise<void> {
    await Promise.all([
      this.postgres?.stop(),
      this.redis?.stop(),
    ]);
    this.postgres = null;
    this.redis = null;
  }
}

// Jest global setup
// globalSetup.ts
export default async function globalSetup() {
  await TestContainerManager.getPostgres();
  await TestContainerManager.getRedis();
}

// globalTeardown.ts
export default async function globalTeardown() {
  await TestContainerManager.stopAll();
}
```

## Wait Strategies

```typescript
import { Wait } from 'testcontainers';

// Wait for log message
const container = await new GenericContainer('custom-service')
  .withWaitStrategy(Wait.forLogMessage('Server started'))
  .start();

// Wait for HTTP endpoint
const container = await new GenericContainer('api-service')
  .withWaitStrategy(
    Wait.forHttp('/health', 8080)
      .withMethod('GET')
      .withStatusCodePredicate((code) => code === 200),
  )
  .start();

// Wait for port
const container = await new GenericContainer('service')
  .withWaitStrategy(Wait.forListeningPorts())
  .start();

// Wait for healthcheck
const container = await new GenericContainer('service')
  .withHealthCheck({
    test: ['CMD', 'curl', '-f', 'http://localhost:8080/health'],
    interval: 1000,
    timeout: 3000,
    retries: 5,
  })
  .withWaitStrategy(Wait.forHealthCheck())
  .start();

// Combined wait
const container = await new GenericContainer('service')
  .withWaitStrategy(
    Wait.forAll([
      Wait.forListeningPorts(),
      Wait.forLogMessage('Ready'),
    ]),
  )
  .start();
```

## Network and Volume

```typescript
import { Network, GenericContainer } from 'testcontainers';

describe('Multi-container setup', () => {
  let network: StartedNetwork;
  let db: StartedTestContainer;
  let api: StartedTestContainer;

  beforeAll(async () => {
    // Create network
    network = await new Network().start();

    // Start database with network alias
    db = await new GenericContainer('postgres:15')
      .withNetwork(network)
      .withNetworkAliases('database')
      .withEnvironment({
        POSTGRES_PASSWORD: 'test',
      })
      .start();

    // Start API connected to database
    api = await new GenericContainer('my-api:test')
      .withNetwork(network)
      .withEnvironment({
        DATABASE_URL: 'postgres://postgres:test@database:5432/postgres',
      })
      .withExposedPorts(3000)
      .start();
  });

  afterAll(async () => {
    await api?.stop();
    await db?.stop();
    await network?.stop();
  });

  test('API connects to database', async () => {
    const response = await fetch(
      `http://${api.getHost()}:${api.getMappedPort(3000)}/users`,
    );
    expect(response.status).toBe(200);
  });
});

// With volumes
const container = await new GenericContainer('my-app')
  .withBindMounts([
    { source: './fixtures', target: '/data', mode: 'ro' },
  ])
  .withTmpFs({ '/tmp': 'rw,noexec' })
  .start();
```

## Test Isolation

```typescript
// Per-test database isolation with transactions
describe('UserService', () => {
  let container: StartedTestContainer;
  let pool: Pool;

  beforeAll(async () => {
    container = await new PostgreSqlContainer().start();
    pool = new Pool({ connectionString: container.getConnectionUri() });
    await runMigrations(pool);
  });

  afterAll(async () => {
    await pool?.end();
    await container?.stop();
  });

  let client: PoolClient;

  beforeEach(async () => {
    client = await pool.connect();
    await client.query('BEGIN');
  });

  afterEach(async () => {
    await client.query('ROLLBACK');
    client.release();
  });

  test('creates user', async () => {
    const repo = new UserRepository(client);
    await repo.create({ name: 'John' });

    const users = await repo.findAll();
    expect(users).toHaveLength(1);
  });

  test('isolated from other tests', async () => {
    const repo = new UserRepository(client);
    const users = await repo.findAll();

    // Previous test's data was rolled back
    expect(users).toHaveLength(0);
  });
});
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `testcontainers` | Core library |
| `@testcontainers/postgresql` | PostgreSQL module |
| `@testcontainers/redis` | Redis module |
| `@testcontainers/kafka` | Kafka module |
| `@testcontainers/mongodb` | MongoDB module |
| `@testcontainers/localstack` | AWS local testing |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Timeout trop court | Tests fail au startup | Augmenter timeout beforeAll |
| Pas de cleanup | Resources leak | afterAll avec stop() |
| Port conflicts | Tests fail | Utiliser ports dynamiques |
| Slow tests | CI lent | Container reuse |
| No wait strategy | Connection errors | Proper wait strategies |

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| Tests d'integration DB | Oui |
| Tests avec message queues | Oui |
| Tests E2E local | Oui |
| Tests unitaires | Non (overkill) |
| CI sans Docker | Non possible |

## CI Configuration

```yaml
# .github/workflows/integration.yml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      docker:
        image: docker:dind
        options: --privileged

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Run integration tests
        run: npm run test:integration
        env:
          TESTCONTAINERS_RYUK_DISABLED: true
```

## Patterns lies

- **Fixture** : Setup des donnees dans containers
- **Contract Testing** : Verification des APIs
- **Fake** : Alternative plus legere

## Sources

- [Testcontainers Documentation](https://testcontainers.com/)
- [Testcontainers Node.js](https://node.testcontainers.org/)
- [Integration Testing Best Practices](https://martinfowler.com/bliki/IntegrationTest.html)
