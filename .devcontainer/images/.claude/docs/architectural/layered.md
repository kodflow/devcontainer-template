# Layered Architecture (N-Tier)

> Organiser le code en couches horizontales avec des responsabilités distinctes.

**Aussi appelé :** N-Tier, Multi-tier, Onion (variante)

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                    LAYERED ARCHITECTURE                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  PRESENTATION LAYER                      │    │
│  │              (Controllers, Views, APIs)                  │    │
│  │                                                          │    │
│  │  • Gère les requêtes HTTP                               │    │
│  │  • Valide les entrées                                   │    │
│  │  • Formate les réponses                                 │    │
│  └──────────────────────────┬──────────────────────────────┘    │
│                             │ Dépend de                          │
│                             ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   BUSINESS LAYER                         │    │
│  │              (Services, Use Cases, Logic)                │    │
│  │                                                          │    │
│  │  • Logique métier                                       │    │
│  │  • Règles de validation                                 │    │
│  │  • Orchestration                                        │    │
│  └──────────────────────────┬──────────────────────────────┘    │
│                             │ Dépend de                          │
│                             ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                 PERSISTENCE LAYER                        │    │
│  │              (Repositories, DAOs, ORM)                   │    │
│  │                                                          │    │
│  │  • Accès aux données                                    │    │
│  │  • Mapping objet-relationnel                            │    │
│  │  • Queries                                              │    │
│  └──────────────────────────┬──────────────────────────────┘    │
│                             │ Dépend de                          │
│                             ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   DATABASE LAYER                         │    │
│  │              (PostgreSQL, MongoDB, Redis)                │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘

Règle: Une couche ne peut appeler que la couche immédiatement en dessous
```

## Structure de fichiers

```
src/
├── presentation/                # Couche présentation
│   ├── controllers/
│   │   ├── UserController.ts
│   │   └── OrderController.ts
│   ├── middleware/
│   │   ├── AuthMiddleware.ts
│   │   └── ValidationMiddleware.ts
│   ├── dto/                     # Data Transfer Objects
│   │   ├── CreateUserDTO.ts
│   │   └── OrderResponseDTO.ts
│   └── routes/
│       └── index.ts
│
├── business/                    # Couche métier
│   ├── services/
│   │   ├── UserService.ts
│   │   └── OrderService.ts
│   ├── validators/
│   │   └── OrderValidator.ts
│   └── rules/
│       └── PricingRules.ts
│
├── persistence/                 # Couche persistance
│   ├── repositories/
│   │   ├── UserRepository.ts
│   │   └── OrderRepository.ts
│   ├── entities/
│   │   ├── UserEntity.ts
│   │   └── OrderEntity.ts
│   └── migrations/
│       └── ...
│
└── shared/                      # Cross-cutting concerns
    ├── config/
    ├── utils/
    └── types/
```

## Implémentation

### Presentation Layer

```typescript
// presentation/controllers/UserController.ts
import { Request, Response } from 'express';
import { UserService } from '../../business/services/UserService';
import { CreateUserDTO, UserResponseDTO } from '../dto/UserDTO';

export class UserController {
  constructor(private userService: UserService) {}

  async create(req: Request, res: Response): Promise<void> {
    // Validation des entrées (DTO)
    const dto = CreateUserDTO.fromRequest(req.body);

    // Appel de la couche business
    const user = await this.userService.createUser(dto);

    // Formatage de la réponse
    res.status(201).json(UserResponseDTO.fromEntity(user));
  }

  async getById(req: Request, res: Response): Promise<void> {
    const { id } = req.params;

    const user = await this.userService.getUserById(id);

    if (!user) {
      res.status(404).json({ error: 'User not found' });
      return;
    }

    res.json(UserResponseDTO.fromEntity(user));
  }
}
```

### Business Layer

```typescript
// business/services/UserService.ts
import { User } from '../../shared/types/User';
import { UserRepository } from '../../persistence/repositories/UserRepository';
import { CreateUserDTO } from '../../presentation/dto/UserDTO';
import { EmailService } from './EmailService';

export class UserService {
  constructor(
    private userRepository: UserRepository,
    private emailService: EmailService
  ) {}

  async createUser(dto: CreateUserDTO): Promise<User> {
    // Validation métier
    await this.validateEmail(dto.email);

    // Création de l'utilisateur
    const user: User = {
      id: generateId(),
      email: dto.email,
      name: dto.name,
      createdAt: new Date(),
    };

    // Persistance
    await this.userRepository.save(user);

    // Side effects
    await this.emailService.sendWelcome(user.email);

    return user;
  }

  async getUserById(id: string): Promise<User | null> {
    return this.userRepository.findById(id);
  }

  private async validateEmail(email: string): Promise<void> {
    const existing = await this.userRepository.findByEmail(email);
    if (existing) {
      throw new DuplicateEmailError(email);
    }
  }
}
```

### Persistence Layer

```typescript
// persistence/repositories/UserRepository.ts
import { Pool } from 'pg';
import { User } from '../../shared/types/User';
import { UserEntity } from '../entities/UserEntity';

export class UserRepository {
  constructor(private db: Pool) {}

  async save(user: User): Promise<void> {
    const entity = UserEntity.fromDomain(user);

    await this.db.query(`
      INSERT INTO users (id, email, name, created_at)
      VALUES ($1, $2, $3, $4)
    `, [entity.id, entity.email, entity.name, entity.createdAt]);
  }

  async findById(id: string): Promise<User | null> {
    const result = await this.db.query(
      'SELECT * FROM users WHERE id = $1',
      [id]
    );

    if (result.rows.length === 0) {
      return null;
    }

    return UserEntity.toDomain(result.rows[0]);
  }

  async findByEmail(email: string): Promise<User | null> {
    const result = await this.db.query(
      'SELECT * FROM users WHERE email = $1',
      [email]
    );

    return result.rows.length > 0
      ? UserEntity.toDomain(result.rows[0])
      : null;
  }
}
```

## Variantes

### 3-Tier classique

```
┌───────────────────┐
│   Presentation    │  UI / API
├───────────────────┤
│     Business      │  Logique métier
├───────────────────┤
│       Data        │  Base de données
└───────────────────┘
```

### 4-Tier avec Intégration

```
┌───────────────────┐
│   Presentation    │  UI / API
├───────────────────┤
│     Business      │  Logique métier
├───────────────────┤
│   Integration     │  APIs externes, messaging
├───────────────────┤
│       Data        │  Base de données
└───────────────────┘
```

### Onion / Clean Architecture

```
        ┌───────────────────────────────────┐
        │           Infrastructure          │
        │  ┌───────────────────────────┐   │
        │  │       Application         │   │
        │  │  ┌───────────────────┐   │   │
        │  │  │      Domain       │   │   │
        │  │  │                   │   │   │
        │  │  │   (Entities)      │   │   │
        │  │  │                   │   │   │
        │  │  └───────────────────┘   │   │
        │  │    (Use Cases)           │   │
        │  └───────────────────────────┘   │
        │  (DB, Web, External Services)    │
        └───────────────────────────────────┘

Dépendances: vers le centre (Domain)
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Applications CRUD | Domaine très complexe |
| Équipes traditionnelles | Microservices |
| APIs simples | Haute performance |
| Prototypes évolutifs | Scaling horizontal |
| Applications web classiques | Event-driven |

## Avantages

- **Simplicité** : Facile à comprendre
- **Séparation** : Responsabilités claires
- **Testabilité** : Couches isolables
- **Maintenabilité** : Changements localisés
- **Standard** : Pattern bien connu

## Inconvénients

- **Overhead** : Mapping entre couches
- **Rigidité** : Structure parfois contraignante
- **Performance** : Traversée des couches
- **Couplage** : Dépendances descendantes
- **Monolithe** : Tendance au monolithe

## Exemples réels

| Framework | Architecture |
|-----------|--------------|
| **Spring MVC** | Controller-Service-Repository |
| **ASP.NET MVC** | Controller-Service-Data |
| **Django** | Views-Models-Templates |
| **Rails** | MVC traditionnel |
| **NestJS** | Controller-Service-Repository |

## Migration path

### Vers Hexagonal

```
1. Extraire interfaces des repositories
2. Inverser les dépendances (DIP)
3. Créer un vrai Domain layer
4. Séparer ports (interfaces) et adapters (implem)
```

### Vers Microservices

```
1. Identifier bounded contexts
2. Séparer en modules indépendants
3. Extraire en services
4. Remplacer appels par API/Events
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Hexagonal | Évolution avec inversion dépendances |
| Clean Architecture | Variante avec cercles |
| MVC | Sous-pattern de presentation |
| Repository | Pattern de la couche data |

## Sources

- [Martin Fowler - PresentationDomainDataLayering](https://martinfowler.com/bliki/PresentationDomainDataLayering.html)
- [Microsoft - N-tier Architecture](https://docs.microsoft.com/en-us/azure/architecture/guide/architecture-styles/n-tier)
- [Clean Architecture - Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
