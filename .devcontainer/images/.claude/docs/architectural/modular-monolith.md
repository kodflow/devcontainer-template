# Modular Monolith

> Un monolithe structuré en modules indépendants avec des frontières claires.

**Position :** Entre Monolith classique et Microservices

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                     MODULAR MONOLITH                             │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    SHARED KERNEL                         │    │
│  │              (Common types, Utilities)                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│       ┌──────────────────────┼──────────────────────┐           │
│       │                      │                      │           │
│  ┌────┴────┐           ┌─────┴────┐           ┌─────┴────┐     │
│  │  ORDER  │           │   USER   │           │ INVENTORY│     │
│  │ MODULE  │           │  MODULE  │           │  MODULE  │     │
│  │         │           │          │           │          │     │
│  │┌───────┐│   API     │┌────────┐│   API     │┌────────┐│     │
│  ││Domain ││◀─────────▶││ Domain ││◀─────────▶││ Domain ││     │
│  ││       ││           ││        ││           ││        ││     │
│  │├───────┤│           │├────────┤│           │├────────┤│     │
│  ││  App  ││           ││  App   ││           ││  App   ││     │
│  │├───────┤│           │├────────┤│           │├────────┤│     │
│  ││Infra  ││           ││ Infra  ││           ││ Infra  ││     │
│  │└───────┘│           │└────────┘│           │└────────┘│     │
│  │    │    │           │    │     │           │    │     │     │
│  │    ▼    │           │    ▼     │           │    ▼     │     │
│  │┌───────┐│           │┌────────┐│           │┌────────┐│     │
│  ││Order  ││           ││ User   ││           ││Inventory│     │
│  ││Schema ││           ││ Schema ││           ││ Schema ││     │
│  │└───────┘│           │└────────┘│           │└────────┘│     │
│  └─────────┘           └──────────┘           └──────────┘     │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    SHARED DATABASE                       │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Structure de fichiers

```
src/
├── modules/
│   ├── orders/                    # Module Orders
│   │   ├── domain/
│   │   │   ├── Order.ts
│   │   │   ├── OrderItem.ts
│   │   │   └── OrderService.ts
│   │   ├── application/
│   │   │   ├── CreateOrderUseCase.ts
│   │   │   └── GetOrderUseCase.ts
│   │   ├── infrastructure/
│   │   │   ├── OrderRepository.ts
│   │   │   └── OrderController.ts
│   │   ├── api/                   # API publique du module
│   │   │   ├── OrderModuleApi.ts  # Interface
│   │   │   └── OrderModuleImpl.ts # Implémentation
│   │   └── index.ts               # Export public
│   │
│   ├── users/                     # Module Users
│   │   ├── domain/
│   │   ├── application/
│   │   ├── infrastructure/
│   │   ├── api/
│   │   │   └── UserModuleApi.ts
│   │   └── index.ts
│   │
│   └── inventory/                 # Module Inventory
│       └── ...
│
├── shared/                        # Shared Kernel
│   ├── types/
│   ├── errors/
│   └── utils/
│
└── main.ts                        # Composition root
```

## Communication inter-modules

### Via API publique

```typescript
// modules/orders/api/OrderModuleApi.ts
export interface OrderModuleApi {
  createOrder(request: CreateOrderRequest): Promise<OrderResponse>;
  getOrder(orderId: string): Promise<OrderResponse | null>;
  cancelOrder(orderId: string): Promise<void>;
}

// modules/orders/api/OrderModuleImpl.ts
export class OrderModuleImpl implements OrderModuleApi {
  constructor(
    private createOrderUseCase: CreateOrderUseCase,
    private getOrderUseCase: GetOrderUseCase,
    private cancelOrderUseCase: CancelOrderUseCase
  ) {}

  async createOrder(request: CreateOrderRequest): Promise<OrderResponse> {
    const order = await this.createOrderUseCase.execute(request);
    return OrderResponse.fromDomain(order);
  }

  async getOrder(orderId: string): Promise<OrderResponse | null> {
    return this.getOrderUseCase.execute(orderId);
  }
}

// Usage depuis un autre module
class ShippingService {
  constructor(private orderModule: OrderModuleApi) {}

  async shipOrder(orderId: string): Promise<void> {
    const order = await this.orderModule.getOrder(orderId);
    // ...
  }
}
```

### Via événements internes

```typescript
// shared/events/EventBus.ts
interface InternalEventBus {
  publish<T>(event: DomainEvent<T>): void;
  subscribe<T>(eventType: string, handler: (event: DomainEvent<T>) => void): void;
}

// modules/orders/domain/OrderService.ts
class OrderService {
  constructor(private eventBus: InternalEventBus) {}

  async createOrder(request: CreateOrderRequest): Promise<Order> {
    const order = new Order(/* ... */);
    await this.orderRepo.save(order);

    // Publish internal event
    this.eventBus.publish({
      type: 'order.created',
      payload: { orderId: order.id, customerId: order.customerId },
    });

    return order;
  }
}

// modules/inventory/handlers/OrderCreatedHandler.ts
class OrderCreatedHandler {
  constructor(eventBus: InternalEventBus) {
    eventBus.subscribe('order.created', this.handle.bind(this));
  }

  async handle(event: OrderCreatedEvent): Promise<void> {
    // Reserve inventory
    await this.inventoryService.reserve(event.payload.items);
  }
}
```

## Règles d'isolation

```typescript
// eslint-plugin-module-boundaries (exemple)
const rules = {
  // Un module ne peut importer que son API publique
  'no-direct-import': {
    allow: [
      'modules/*/api/*',    // API publiques OK
      'shared/*',            // Shared kernel OK
    ],
    deny: [
      'modules/*/domain/*',      // Domain interne interdit
      'modules/*/infrastructure/*', // Infra interne interdit
    ],
  },
};

// Exemple de violation
// modules/orders/application/CreateOrderUseCase.ts
import { UserRepository } from '../../users/infrastructure/UserRepository';
// ❌ INTERDIT: accès direct à l'infra d'un autre module

import { UserModuleApi } from '../../users/api/UserModuleApi';
// ✅ OK: utilisation de l'API publique
```

## Composition Root

```typescript
// main.ts - Assembly des modules
async function bootstrap(): Promise<void> {
  // Infrastructure
  const db = new Database(config.database);
  const eventBus = new InMemoryEventBus();

  // Modules
  const userModule = UserModule.create(db, eventBus);
  const inventoryModule = InventoryModule.create(db, eventBus);
  const orderModule = OrderModule.create(
    db,
    eventBus,
    userModule.api,        // Injection de l'API
    inventoryModule.api    // Injection de l'API
  );

  // HTTP Server
  const app = express();
  app.use('/api/users', userModule.router);
  app.use('/api/orders', orderModule.router);
  app.use('/api/inventory', inventoryModule.router);

  app.listen(3000);
}
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Équipe 5-30 devs | Équipe < 5 (overkill) |
| Domaine complexe | CRUD simple |
| Pas prêt pour microservices | DevOps mature |
| Préparation future split | Déjà microservices |
| Tests importants | Prototype rapide |

## Avantages

- **Simplicité opérationnelle** : Un seul déploiement
- **Structure claire** : Frontières explicites
- **Refactoring facile** : Tout dans un repo
- **Tests intégrés** : Tests end-to-end simples
- **Préparation microservices** : Extraction future facile
- **Transactions** : ACID possible

## Inconvénients

- **Discipline requise** : Respecter les frontières
- **Scaling uniforme** : Pas de scale par module
- **Deploy tout ou rien** : Un module = tout redéployer
- **Couplage technique** : Même stack
- **Base partagée** : Schéma peut devenir couplé

## Exemples réels

| Entreprise | Usage |
|------------|-------|
| **Shopify** | Modular monolith Ruby |
| **Basecamp** | Majestic Monolith |
| **GitHub** | Modular Rails |
| **GitLab** | Modular Ruby monolith |
| **Stripe** | Ruby modules |

## Migration path

### Depuis Monolith classique

```
Phase 1: Identifier bounded contexts (DDD)
Phase 2: Extraire modules avec interfaces
Phase 3: Ajouter règles d'isolation (linting)
Phase 4: Migrer données vers schémas séparés
Phase 5: Implémenter event bus interne
```

### Vers Microservices

```
Phase 1: Chaque module a sa propre DB schema
Phase 2: Remplacer appels sync par async (events)
Phase 3: Containeriser modules indépendamment
Phase 4: Extraire en services séparés
Phase 5: Ajouter API Gateway
```

## Comparaison

```
┌───────────────────────────────────────────────────────────────┐
│                                                                │
│  Monolith         Modular Monolith      Microservices         │
│                                                                │
│  ┌─────────┐     ┌─────────────────┐   ┌───┐ ┌───┐ ┌───┐    │
│  │         │     │ ┌───┐ ┌───┐     │   │ A │ │ B │ │ C │    │
│  │   ALL   │     │ │ A │ │ B │     │   └───┘ └───┘ └───┘    │
│  │   IN    │     │ └───┘ └───┘     │     │     │     │      │
│  │   ONE   │     │ ┌───┐           │     └─────┼─────┘      │
│  │         │     │ │ C │           │           │            │
│  └─────────┘     │ └───┘           │      [Network]         │
│                  └─────────────────┘                         │
│                                                                │
│  No boundaries   Clear boundaries     Separate processes     │
│  1 deploy        1 deploy            N deploys               │
│  1 DB            1 DB (schemas)       N DBs                   │
└───────────────────────────────────────────────────────────────┘
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Hexagonal | Architecture de chaque module |
| DDD | Bounded Contexts = Modules |
| Microservices | Évolution possible |
| Event-Driven | Communication inter-modules |

## Sources

- [Kamil Grzybek - Modular Monolith](https://www.kamilgrzybek.com/design/modular-monolith-primer/)
- [Simon Brown - Modular Monoliths](https://www.youtube.com/watch?v=5OjqD-ow8GE)
- [Shopify Engineering](https://shopify.engineering/deconstructing-monolith-designing-software-maximizes-developer-productivity)
- [DHH - The Majestic Monolith](https://m.signalvnoise.com/the-majestic-monolith/)
