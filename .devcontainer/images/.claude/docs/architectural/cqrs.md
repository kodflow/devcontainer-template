# CQRS - Command Query Responsibility Segregation

> Séparer les modèles de lecture et d'écriture.

**Auteur :** Greg Young (basé sur CQS de Bertrand Meyer)

## Principe

```
┌────────────────────────────────────────────────────────────────┐
│                           CLIENT                                │
└───────────────────────┬────────────────────┬───────────────────┘
                        │                    │
            ┌───────────▼───────┐  ┌─────────▼─────────┐
            │     COMMANDS      │  │      QUERIES      │
            │  (Write Model)    │  │   (Read Model)    │
            └───────────┬───────┘  └─────────┬─────────┘
                        │                    │
            ┌───────────▼───────┐  ┌─────────▼─────────┐
            │  Command Handler  │  │   Query Handler   │
            └───────────┬───────┘  └─────────┬─────────┘
                        │                    │
            ┌───────────▼───────┐  ┌─────────▼─────────┐
            │    Write DB       │  │     Read DB       │
            │  (Normalized)     │  │  (Denormalized)   │
            └───────────────────┘  └───────────────────┘
```

## Niveaux de CQRS

### Niveau 1 : Séparation logique

```typescript
// Même DB, modèles séparés
class UserCommandService {
  create(dto: CreateUserDTO): Promise<void>;
  update(id: string, dto: UpdateUserDTO): Promise<void>;
}

class UserQueryService {
  getById(id: string): Promise<UserDTO>;
  search(criteria: SearchCriteria): Promise<UserDTO[]>;
}
```

### Niveau 2 : Bases séparées

```typescript
// Write: PostgreSQL (normalized)
// Read: Elasticsearch (optimized for search)

class UserCommandHandler {
  async handle(cmd: CreateUserCommand) {
    await this.writeDb.insert(cmd.user);
    await this.eventBus.publish(new UserCreatedEvent(cmd.user));
  }
}

// Synchronisation via événements
class UserProjection {
  @OnEvent(UserCreatedEvent)
  async project(event: UserCreatedEvent) {
    await this.readDb.index(event.user);
  }
}
```

### Niveau 3 : Avec Event Sourcing

```
Commands → Event Store → Projections → Read Models
```

## Exemple complet

### Command

```typescript
// commands/CreateOrderCommand.ts
export class CreateOrderCommand {
  constructor(
    public readonly userId: string,
    public readonly items: OrderItem[],
  ) {}
}

// handlers/CreateOrderHandler.ts
export class CreateOrderHandler {
  constructor(
    private orderRepo: OrderRepository,
    private eventBus: EventBus,
  ) {}

  async handle(cmd: CreateOrderCommand): Promise<void> {
    const order = Order.create(cmd.userId, cmd.items);

    await this.orderRepo.save(order);
    await this.eventBus.publish(new OrderCreatedEvent(order));
  }
}
```

### Query

```typescript
// queries/GetOrderQuery.ts
export class GetOrderQuery {
  constructor(public readonly orderId: string) {}
}

// handlers/GetOrderHandler.ts
export class GetOrderHandler {
  constructor(private readDb: ReadDatabase) {}

  async handle(query: GetOrderQuery): Promise<OrderDTO> {
    // Lecture depuis vue dénormalisée (rapide)
    return this.readDb.orders.findById(query.orderId);
  }
}
```

### Projection (Sync read model)

```typescript
export class OrderProjection {
  constructor(private readDb: ReadDatabase) {}

  @OnEvent(OrderCreatedEvent)
  async onOrderCreated(event: OrderCreatedEvent) {
    const view: OrderView = {
      id: event.order.id,
      userId: event.order.userId,
      userName: await this.getUserName(event.order.userId),
      items: event.order.items,
      total: this.calculateTotal(event.order.items),
      createdAt: new Date(),
    };
    await this.readDb.orders.upsert(view);
  }
}
```

## Quand utiliser

| ✅ Utiliser | ❌ Éviter |
|-------------|-----------|
| Lecture >> Écriture | CRUD simple |
| Vues complexes | Données temps réel strict |
| Scalabilité lecture | Équipe petite |
| Domaine complexe | Prototype/MVP |

## Avantages

- **Performance** : Read model optimisé
- **Scalabilité** : Scale lecture indépendamment
- **Simplicité** : Modèles spécialisés
- **Flexibilité** : Vues multiples

## Inconvénients

- **Complexité** : Plus de code
- **Eventual Consistency** : Sync asynchrone
- **Debugging** : Plus difficile à suivre

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Event Sourcing | Souvent utilisé ensemble |
| Saga | Transactions distribuées |
| Mediator | Pour router commands/queries |

## Sources

- [Martin Fowler - CQRS](https://martinfowler.com/bliki/CQRS.html)
- [Microsoft - CQRS Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs)
