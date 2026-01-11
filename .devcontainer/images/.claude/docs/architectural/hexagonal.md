# Hexagonal Architecture (Ports & Adapters)

> Isoler le cœur métier des détails techniques.

**Auteur :** Alistair Cockburn (2005)

## Principe

```
                    ┌─────────────────────────────────────┐
                    │           ADAPTERS (Driving)         │
                    │  REST API │ CLI │ gRPC │ GraphQL    │
                    └─────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │             PORTS (In)               │
                    │      Interfaces d'entrée             │
                    └─────────────────────────────────────┘
                                      │
                                      ▼
          ┌───────────────────────────────────────────────────────┐
          │                                                       │
          │                    DOMAIN CORE                        │
          │                                                       │
          │   ┌─────────────┐   ┌─────────────┐   ┌───────────┐  │
          │   │   Entities  │   │   Services  │   │   Rules   │  │
          │   └─────────────┘   └─────────────┘   └───────────┘  │
          │                                                       │
          └───────────────────────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │             PORTS (Out)              │
                    │      Interfaces de sortie            │
                    └─────────────────────────────────────┘
                                      │
                                      ▼
                    ┌─────────────────────────────────────┐
                    │          ADAPTERS (Driven)           │
                    │  PostgreSQL │ Redis │ S3 │ Email    │
                    └─────────────────────────────────────┘
```

## Structure de fichiers

```
src/
├── domain/                    # Cœur métier (AUCUNE dépendance externe)
│   ├── entities/
│   │   └── User.ts
│   ├── services/
│   │   └── UserService.ts
│   ├── repositories/          # Interfaces (Ports Out)
│   │   └── UserRepository.ts
│   └── errors/
│       └── UserNotFoundError.ts
│
├── application/               # Use Cases / Ports In
│   ├── commands/
│   │   └── CreateUserCommand.ts
│   ├── queries/
│   │   └── GetUserQuery.ts
│   └── handlers/
│       └── CreateUserHandler.ts
│
├── infrastructure/            # Adapters (implémentations)
│   ├── persistence/
│   │   ├── PostgresUserRepository.ts
│   │   └── InMemoryUserRepository.ts
│   ├── http/
│   │   └── UserController.ts
│   └── messaging/
│       └── RabbitMQPublisher.ts
│
└── main.ts                    # Composition root (DI)
```

## Exemple

### Port (Interface)

```typescript
// domain/repositories/UserRepository.ts
export interface UserRepository {
  findById(id: string): Promise<User | null>;
  save(user: User): Promise<void>;
  delete(id: string): Promise<void>;
}
```

### Domain Service

```typescript
// domain/services/UserService.ts
export class UserService {
  constructor(private readonly userRepo: UserRepository) {}

  async createUser(email: string, name: string): Promise<User> {
    const existing = await this.userRepo.findByEmail(email);
    if (existing) {
      throw new UserAlreadyExistsError(email);
    }

    const user = new User(generateId(), email, name);
    await this.userRepo.save(user);
    return user;
  }
}
```

### Adapter (Implémentation)

```typescript
// infrastructure/persistence/PostgresUserRepository.ts
export class PostgresUserRepository implements UserRepository {
  constructor(private readonly db: Pool) {}

  async findById(id: string): Promise<User | null> {
    const result = await this.db.query(
      'SELECT * FROM users WHERE id = $1',
      [id]
    );
    return result.rows[0] ? this.toDomain(result.rows[0]) : null;
  }

  async save(user: User): Promise<void> {
    await this.db.query(
      'INSERT INTO users (id, email, name) VALUES ($1, $2, $3)',
      [user.id, user.email, user.name]
    );
  }
}
```

### Test (avec Mock Adapter)

```typescript
// tests/UserService.test.ts
describe('UserService', () => {
  it('should create user', async () => {
    const mockRepo = new InMemoryUserRepository();
    const service = new UserService(mockRepo);

    const user = await service.createUser('test@example.com', 'Test');

    expect(user.email).toBe('test@example.com');
    expect(await mockRepo.findById(user.id)).toBeDefined();
  });
});
```

## Quand utiliser

| ✅ Utiliser | ❌ Éviter |
|-------------|-----------|
| Applications métier complexes | CRUD simple |
| Longue durée de vie | Prototypes/MVPs |
| Tests importants | Scripts one-shot |
| Équipes multiples | Projets solo courts |
| Changements d'infra prévisibles | Stack figé |

## Avantages

- **Testabilité** : Domain testable sans DB/HTTP
- **Flexibilité** : Changer de DB = un adapter
- **Clarté** : Séparation claire des responsabilités
- **Indépendance** : Le métier ne dépend de rien

## Inconvénients

- **Verbosité** : Plus de fichiers/interfaces
- **Overhead** : Mapping entre couches
- **Courbe d'apprentissage** : Concepts à maîtriser

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Clean Architecture | Évolution avec plus de couches |
| DIP (SOLID) | Fondement du pattern |
| Adapter (GoF) | Implémentation des ports |
| Repository | Port typique pour la persistance |

## Frameworks qui supportent Hexagonal

| Langage | Framework |
|---------|-----------|
| TypeScript | NestJS, ts-arch |
| Java | Spring (modules) |
| Go | go-kit, structure manuelle |
| Python | FastAPI + structure manuelle |

## Sources

- [Alistair Cockburn - Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture/)
- [Netflix Tech Blog](https://netflixtechblog.com/)
- [microservices.io](https://microservices.io/patterns/microservices.html)
