# Monolithic Architecture

> Une application unique contenant toute la logique métier.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                        MONOLITH                                  │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │    User     │  │    Order    │  │   Product   │              │
│  │   Module    │  │   Module    │  │   Module    │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│         │               │               │                        │
│         └───────────────┴───────────────┘                        │
│                         │                                        │
│                         ▼                                        │
│                  ┌─────────────┐                                 │
│                  │   Shared    │                                 │
│                  │  Database   │                                 │
│                  └─────────────┘                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Types de Monolith

### 1. Monolith classique (à éviter)

```
❌ Big Ball of Mud
┌─────────────────────────────────────┐
│  Code spaghetti, pas de structure   │
│  Tout dépend de tout               │
└─────────────────────────────────────┘
```

### 2. Monolith modulaire (recommandé)

```
✅ Bien structuré
┌─────────────────────────────────────────────────────────────┐
│                     MONOLITH MODULAIRE                       │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │    Users    │  │   Orders    │  │  Products   │          │
│  │  ┌───────┐  │  │  ┌───────┐  │  │  ┌───────┐  │          │
│  │  │Domain │  │  │  │Domain │  │  │  │Domain │  │          │
│  │  ├───────┤  │  │  ├───────┤  │  │  ├───────┤  │          │
│  │  │  API  │  │  │  │  API  │  │  │  │  API  │  │          │
│  │  ├───────┤  │  │  ├───────┤  │  │  ├───────┤  │          │
│  │  │  DB   │  │  │  │  DB   │  │  │  │  DB   │  │          │
│  │  └───────┘  │  │  └───────┘  │  │  └───────┘  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│        │                │                │                   │
│        └────── API publiques entre modules ──────┘          │
└─────────────────────────────────────────────────────────────┘
```

## Structure recommandée

```
src/
├── modules/
│   ├── users/
│   │   ├── domain/
│   │   │   ├── User.ts
│   │   │   └── UserService.ts
│   │   ├── api/
│   │   │   └── UserController.ts
│   │   ├── infra/
│   │   │   └── UserRepository.ts
│   │   └── index.ts          # API publique du module
│   │
│   ├── orders/
│   │   ├── domain/
│   │   ├── api/
│   │   ├── infra/
│   │   └── index.ts
│   │
│   └── products/
│       └── ...
│
├── shared/                    # Code vraiment partagé
│   ├── database/
│   └── utils/
│
└── main.ts
```

## Règles du Monolith Modulaire

### 1. Encapsulation des modules

```typescript
// ❌ Accès direct aux internals
import { UserRepository } from '../users/infra/UserRepository';

// ✅ Utiliser l'API publique
import { userModule } from '../users';
const user = await userModule.getUser(id);
```

### 2. Communication par interfaces

```typescript
// modules/users/index.ts (API publique)
export interface UserModule {
  getUser(id: string): Promise<User>;
  createUser(data: CreateUserDTO): Promise<User>;
}

export const userModule: UserModule = {
  getUser: (id) => userService.findById(id),
  createUser: (data) => userService.create(data),
};
```

### 3. Base de données par schéma

```sql
-- Schémas séparés par module
CREATE SCHEMA users;
CREATE SCHEMA orders;
CREATE SCHEMA products;

-- Chaque module accède uniquement à son schéma
```

## Quand utiliser

| ✅ Utiliser | ❌ Éviter |
|-------------|-----------|
| Startup / MVP | Équipe > 20 devs |
| Équipe < 10 personnes | Besoins de scale différents |
| Domaine pas encore clair | Bounded contexts évidents |
| Besoin de vitesse | Équipes autonomes requises |
| Budget infra limité | Haute disponibilité critique |

## Avantages

- **Simplicité** : Un seul déploiement
- **Performance** : Appels in-process
- **Transactions** : ACID native
- **Debugging** : Stack trace complète
- **Coût** : Moins d'infra

## Inconvénients

- **Scalabilité** : Tout scale ensemble
- **Déploiement** : Tout redéployer
- **Technologie** : Stack unique
- **Équipes** : Coordination nécessaire

## Migration vers Microservices

```
Étape 1: Monolith → Monolith Modulaire
Étape 2: Définir les bounded contexts
Étape 3: Strangler Fig (un module à la fois)
Étape 4: Microservices complets
```

## Anti-patterns

### Module Coupling

```typescript
// ❌ Modules trop couplés
class OrderService {
  constructor(
    private userRepo: UserRepository,    // Accès direct
    private productRepo: ProductRepository,
  ) {}
}

// ✅ Communication par événements/API
class OrderService {
  async createOrder(userId: string, productId: string) {
    const user = await userModule.getUser(userId);
    const product = await productModule.getProduct(productId);
    // ...
  }
}
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Hexagonal | Structure interne des modules |
| CQRS | Applicable par module |
| Event Sourcing | Pour la communication entre modules |
| Strangler Fig | Migration vers microservices |

## Sources

- [Modular Monolith - Kamil Grzybek](https://www.kamilgrzybek.com/design/modular-monolith-primer/)
- [Martin Fowler - Monolith First](https://martinfowler.com/bliki/MonolithFirst.html)
