# Service Layer

> "Defines an application's boundary with a layer of services that establishes a set of available operations and coordinates the application's response in each operation." - Martin Fowler, PoEAA

## Concept

La Service Layer est une couche de coordination qui definit la frontiere de l'application. Elle orchestre les operations metier sans contenir de logique metier elle-meme (celle-ci reste dans le Domain Model).

## Responsabilites

1. **Coordination** : Orchestrer les appels entre domaine et infrastructure
2. **Transaction** : Gerer les limites transactionnelles
3. **Securite** : Appliquer les regles d'autorisation
4. **DTO Conversion** : Transformer entre domaine et presentation
5. **Facade** : Exposer une API simplifiee

## Implementation TypeScript

```typescript
// DTOs - Objets de transfert
interface PlaceOrderRequest {
  customerId: string;
  items: Array<{
    productId: string;
    quantity: number;
  }>;
  shippingAddressId: string;
}

interface PlaceOrderResponse {
  orderId: string;
  total: number;
  estimatedDelivery: string;
}

// Service Layer - Application Service
class OrderApplicationService {
  constructor(
    private readonly orderRepository: OrderRepository,
    private readonly customerRepository: CustomerRepository,
    private readonly productRepository: ProductRepository,
    private readonly inventoryService: InventoryService,
    private readonly paymentService: PaymentService,
    private readonly notificationService: NotificationService,
    private readonly eventPublisher: DomainEventPublisher,
  ) {}

  /**
   * Place une commande - Coordination sans logique metier
   */
  @Transactional()
  @Authorized('orders.create')
  async placeOrder(
    request: PlaceOrderRequest,
    currentUser: User,
  ): Promise<PlaceOrderResponse> {
    // 1. Charger les entites du domaine
    const customer = await this.customerRepository.findById(request.customerId);
    if (!customer) {
      throw new NotFoundError('Customer not found');
    }

    const address = customer.getAddress(request.shippingAddressId);
    if (!address) {
      throw new NotFoundError('Address not found');
    }

    // 2. Creer l'agregat Order via Factory
    const order = Order.create(customer);
    order.setShippingAddress(address);

    // 3. Ajouter les items (logique metier dans Order)
    for (const item of request.items) {
      const product = await this.productRepository.findById(item.productId);
      if (!product) {
        throw new NotFoundError(`Product ${item.productId} not found`);
      }
      order.addItem(product, item.quantity); // Validation dans Order
    }

    // 4. Soumettre la commande (logique metier dans Order)
    order.submit();

    // 5. Coordonner avec les services d'infrastructure
    await this.inventoryService.reserve(order.items);

    try {
      // 6. Persister
      await this.orderRepository.save(order);

      // 7. Publier les events du domaine
      const events = order.pullEvents();
      await this.eventPublisher.publishAll(events);

      // 8. Notifications (side effect)
      await this.notificationService.notifyOrderPlaced(order, customer);

    } catch (error) {
      // Compensation en cas d'echec
      await this.inventoryService.release(order.items);
      throw error;
    }

    // 9. Retourner DTO de reponse
    return {
      orderId: order.id,
      total: order.total.amount,
      estimatedDelivery: this.calculateDeliveryDate(address).toISOString(),
    };
  }

  /**
   * Annuler une commande
   */
  @Transactional()
  @Authorized('orders.cancel')
  async cancelOrder(
    orderId: string,
    reason: string,
    currentUser: User,
  ): Promise<void> {
    const order = await this.orderRepository.findById(orderId);
    if (!order) {
      throw new NotFoundError('Order not found');
    }

    // Verifier les droits
    if (!this.canCancelOrder(order, currentUser)) {
      throw new ForbiddenError('Cannot cancel this order');
    }

    // Logique metier dans le domaine
    order.cancel(reason);

    // Coordination compensation
    if (order.isPaid) {
      await this.paymentService.refund(order.paymentId);
    }
    await this.inventoryService.release(order.items);

    // Persistance
    await this.orderRepository.save(order);

    // Events
    await this.eventPublisher.publishAll(order.pullEvents());
  }

  /**
   * Query - Recuperer les commandes d'un client
   */
  @Authorized('orders.read')
  async getCustomerOrders(
    customerId: string,
    pagination: PaginationParams,
  ): Promise<PaginatedResult<OrderSummaryDTO>> {
    const orders = await this.orderRepository.findByCustomerId(
      customerId,
      pagination,
    );

    return {
      items: orders.items.map(OrderSummaryDTO.fromDomain),
      total: orders.total,
      page: pagination.page,
      pageSize: pagination.pageSize,
    };
  }

  private canCancelOrder(order: Order, user: User): boolean {
    return order.customerId === user.id || user.hasRole('admin');
  }

  private calculateDeliveryDate(address: Address): Date {
    // Logique de calcul...
    return new Date(Date.now() + 5 * 24 * 60 * 60 * 1000);
  }
}
```

## Service Layer vs Domain Service

```typescript
// Application Service (Service Layer)
// - Coordination, transactions, securite
// - Ne contient PAS de logique metier
class OrderApplicationService {
  async placeOrder(request: PlaceOrderRequest) {
    // Coordonne mais ne decide pas
    const order = Order.create(customer);
    order.addItem(product, qty); // Delegation au domaine
    await this.repository.save(order);
  }
}

// Domain Service
// - Logique metier qui ne va pas dans une entite
// - Operations cross-aggregate
class PricingDomainService {
  calculateDiscount(order: Order, customer: Customer): Money {
    // Logique metier pure
    if (customer.isVIP && order.total.amount > 1000) {
      return order.total.multiply(0.15);
    }
    return Money.zero();
  }
}
```

## Comparaison avec alternatives

| Aspect | Service Layer | Transaction Script | Facade |
|--------|--------------|-------------------|--------|
| Logique metier | Dans Domain Model | Dans le script | Dans le Facade |
| Coordination | Oui | Oui | Non |
| Transactions | Oui | Oui | Non |
| Granularite | Use cases | Operations | Simplification |

## Quand utiliser

**Utiliser Service Layer quand :**

- Application avec Domain Model
- Besoin de coordination transactionnelle
- Multiple clients (web, API, CLI)
- Securite au niveau use case
- Tests d'integration importants

**Eviter Service Layer quand :**

- CRUD simple (utiliser Transaction Script)
- Une seule interface utilisateur
- Pas de Domain Model

## Relation avec DDD

En DDD, la Service Layer correspond aux **Application Services** :

```
┌─────────────────────────────────────────────┐
│              Interface Layer                │
│         (Controllers, GraphQL, CLI)         │
├─────────────────────────────────────────────┤
│           Application Layer                 │  ← Service Layer
│    (Application Services, Use Cases)        │
├─────────────────────────────────────────────┤
│              Domain Layer                   │
│  (Entities, Value Objects, Domain Services) │
├─────────────────────────────────────────────┤
│          Infrastructure Layer               │
│    (Repositories, External Services)        │
└─────────────────────────────────────────────┘
```

## Patterns associes

- **Facade** : Simplification d'interface (sans coordination)
- **Domain Model** : Logique metier
- **Repository** : Acces aux donnees
- **Unit of Work** : Gestion des transactions
- **DTO** : Transfert de donnees

## Decorateurs utiles

```typescript
// Transaction management
function Transactional() {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    const original = descriptor.value;
    descriptor.value = async function (...args: any[]) {
      return await this.unitOfWork.executeInTransaction(() =>
        original.apply(this, args),
      );
    };
  };
}

// Authorization
function Authorized(permission: string) {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    const original = descriptor.value;
    descriptor.value = async function (...args: any[]) {
      const user = args.find((a) => a instanceof User);
      if (!user?.hasPermission(permission)) {
        throw new ForbiddenError(`Missing permission: ${permission}`);
      }
      return original.apply(this, args);
    };
  };
}
```

## Sources

- Martin Fowler, PoEAA, Chapter 9
- [Service Layer - martinfowler.com](https://martinfowler.com/eaaCatalog/serviceLayer.html)
- Eric Evans, DDD - Application Layer
