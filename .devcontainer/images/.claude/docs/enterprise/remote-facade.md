# Remote Facade

> "Provides a coarse-grained facade on fine-grained objects to improve efficiency over a network." - Martin Fowler, PoEAA

## Concept

Remote Facade est une interface simplifiee qui expose des operations coarse-grained (grosses granularites) pour reduire le nombre d'appels reseau. Elle encapsule plusieurs appels fins en une seule operation.

## Probleme resolu

```typescript
// PROBLEME: Fine-grained API = nombreux appels reseau
const customer = await api.getCustomer(id);           // Call 1
const address = await api.getAddress(customer.addressId); // Call 2
const orders = await api.getOrders(customer.id);      // Call 3
const items = await Promise.all(                      // Call 4..N
  orders.map(o => api.getOrderItems(o.id))
);

// SOLUTION: Coarse-grained Remote Facade
const customerProfile = await api.getCustomerProfile(id); // 1 seul appel
// Contient: customer, address, recentOrders, etc.
```

## Implementation TypeScript

```typescript
// Fine-grained domain services (internes)
class OrderService {
  async create(customerId: string): Promise<Order> { ... }
  async addItem(orderId: string, productId: string, qty: number): Promise<void> { ... }
  async removeItem(orderId: string, itemId: string): Promise<void> { ... }
  async updateQuantity(orderId: string, itemId: string, qty: number): Promise<void> { ... }
  async setShippingAddress(orderId: string, address: Address): Promise<void> { ... }
  async setBillingAddress(orderId: string, address: Address): Promise<void> { ... }
  async applyDiscount(orderId: string, code: string): Promise<void> { ... }
  async submit(orderId: string): Promise<void> { ... }
}

class PaymentService {
  async createPaymentIntent(orderId: string): Promise<PaymentIntent> { ... }
  async processPayment(intentId: string, method: PaymentMethod): Promise<PaymentResult> { ... }
}

class NotificationService {
  async sendOrderConfirmation(orderId: string): Promise<void> { ... }
}

// Remote Facade - Coarse-grained interface
class OrderFacade {
  constructor(
    private readonly orderService: OrderService,
    private readonly paymentService: PaymentService,
    private readonly notificationService: NotificationService,
    private readonly customerRepository: CustomerRepository,
    private readonly productRepository: ProductRepository,
  ) {}

  /**
   * Place une commande complete en un seul appel
   * Remplace 5-10 appels fins par un seul appel coarse-grained
   */
  async placeOrder(request: PlaceOrderRequest): Promise<PlaceOrderResponse> {
    // Validation
    const customer = await this.customerRepository.findById(request.customerId);
    if (!customer) {
      throw new NotFoundError('Customer not found');
    }

    // Creation commande
    const order = await this.orderService.create(request.customerId);

    // Ajout items
    for (const item of request.items) {
      const product = await this.productRepository.findById(item.productId);
      if (!product) {
        throw new NotFoundError(`Product ${item.productId} not found`);
      }
      await this.orderService.addItem(order.id, item.productId, item.quantity);
    }

    // Addresses
    await this.orderService.setShippingAddress(order.id, request.shippingAddress);
    await this.orderService.setBillingAddress(
      order.id,
      request.billingAddress || request.shippingAddress,
    );

    // Discount
    if (request.discountCode) {
      await this.orderService.applyDiscount(order.id, request.discountCode);
    }

    // Submit
    await this.orderService.submit(order.id);

    // Payment
    const paymentIntent = await this.paymentService.createPaymentIntent(order.id);
    const paymentResult = await this.paymentService.processPayment(
      paymentIntent.id,
      request.paymentMethod,
    );

    if (!paymentResult.success) {
      throw new PaymentError(paymentResult.error);
    }

    // Notification
    await this.notificationService.sendOrderConfirmation(order.id);

    // Response DTO
    const updatedOrder = await this.orderService.findById(order.id);
    return {
      orderId: order.id,
      orderNumber: updatedOrder.orderNumber,
      total: updatedOrder.total.amount,
      currency: updatedOrder.total.currency,
      estimatedDelivery: this.calculateDeliveryDate(request.shippingAddress),
      paymentConfirmation: paymentResult.confirmationNumber,
    };
  }

  /**
   * Obtenir le profil complet d'un client
   */
  async getCustomerProfile(customerId: string): Promise<CustomerProfileResponse> {
    const [customer, addresses, recentOrders, preferences] = await Promise.all([
      this.customerRepository.findById(customerId),
      this.addressRepository.findByCustomerId(customerId),
      this.orderRepository.findRecentByCustomerId(customerId, 5),
      this.preferenceRepository.findByCustomerId(customerId),
    ]);

    if (!customer) {
      throw new NotFoundError('Customer not found');
    }

    return {
      id: customer.id,
      name: customer.name,
      email: customer.email,
      memberSince: customer.createdAt.toISOString(),
      addresses: addresses.map(AddressDTO.fromDomain),
      recentOrders: recentOrders.map(OrderSummaryDTO.fromDomain),
      preferences: PreferencesDTO.fromDomain(preferences),
      loyaltyPoints: customer.loyaltyPoints,
      tier: customer.loyaltyTier,
    };
  }

  /**
   * Checkout complet avec panier
   */
  async checkout(request: CheckoutRequest): Promise<CheckoutResponse> {
    return await this.db.transaction(async () => {
      // 1. Valider le panier
      const cart = await this.cartService.getCart(request.cartId);
      if (cart.isEmpty) {
        throw new ValidationError('Cart is empty');
      }

      // 2. Creer la commande depuis le panier
      const order = await this.orderService.createFromCart(cart);

      // 3. Appliquer shipping & billing
      await this.orderService.setAddresses(order.id, {
        shipping: request.shippingAddress,
        billing: request.billingAddress,
      });

      // 4. Calculer shipping
      const shippingOptions = await this.shippingService.calculateOptions(
        order,
        request.shippingAddress,
      );
      const selectedShipping = shippingOptions.find(
        (o) => o.id === request.shippingOptionId,
      );
      await this.orderService.setShipping(order.id, selectedShipping);

      // 5. Process payment
      const payment = await this.paymentService.process(
        order.id,
        request.paymentDetails,
      );

      // 6. Finalize
      await this.orderService.confirm(order.id);
      await this.cartService.clear(request.cartId);
      await this.inventoryService.reserve(order.items);

      // 7. Async notifications
      this.notificationService.sendOrderConfirmation(order.id);

      return {
        orderId: order.id,
        orderNumber: order.orderNumber,
        summary: OrderSummaryDTO.fromDomain(order),
        payment: PaymentConfirmationDTO.fromDomain(payment),
      };
    });
  }
}
```

## Remote Facade vs API Gateway

```typescript
// Remote Facade - Business logic aggregation
class OrderFacade {
  async placeOrder(request: PlaceOrderRequest): Promise<OrderResponse> {
    // Logique metier, coordination de services
  }
}

// API Gateway - Routing, auth, rate limiting (pas de logique metier)
class APIGateway {
  async route(request: HttpRequest): Promise<HttpResponse> {
    await this.authenticate(request);
    await this.rateLimit(request);
    return this.proxy(request);
  }
}
```

## Comparaison avec alternatives

| Aspect | Remote Facade | Fine-grained API | BFF |
|--------|--------------|------------------|-----|
| Appels reseau | Peu | Beaucoup | Peu |
| Couplage client | Faible | Fort | Faible |
| Flexibilite | Moyenne | Elevee | Elevee |
| Complexite serveur | Elevee | Faible | Moyenne |
| Performance | Meilleure | Variable | Bonne |

## Quand utiliser

**Utiliser Remote Facade quand :**

- Communication reseau couteuse (latence)
- Clients distants (mobile, SPA, microservices)
- Operations complexes multi-etapes
- Besoin de reduire la bande passante

**Eviter Remote Facade quand :**

- Clients locaux (monolithe)
- Operations simples
- Besoin de flexibilite maximale (GraphQL)

## Relation avec DDD

Remote Facade correspond aux **Application Services** exposes en API :

```
┌─────────────────────────────────────────────┐
│              Interface Layer                │
│   - REST Controllers                        │
│   - GraphQL Resolvers                       │
├─────────────────────────────────────────────┤
│           Application Layer                 │
│   - Remote Facades (Application Services)   │  ← ICI
│   - Orchestration, DTOs                     │
├─────────────────────────────────────────────┤
│              Domain Layer                   │
│   - Fine-grained Domain Services            │
│   - Entities, Value Objects                 │
├─────────────────────────────────────────────┤
│          Infrastructure Layer               │
│   - Repositories, External Services         │
└─────────────────────────────────────────────┘
```

## Patterns associes

- **Facade** : Version locale (in-process)
- **DTO** : Transport des donnees
- **Service Layer** : Couche de coordination
- **API Gateway** : Routing, auth (complementaire)
- **Backend for Frontend (BFF)** : Facade specifique par client

## Bonnes pratiques

```typescript
// 1. Idempotence pour retries
class OrderFacade {
  @Idempotent({ key: (req) => `order:${req.idempotencyKey}` })
  async placeOrder(request: PlaceOrderRequest): Promise<OrderResponse> {
    // Si meme idempotencyKey, retourne le resultat precedent
  }
}

// 2. Timeout et circuit breaker
class ResilientFacade {
  @Timeout(5000)
  @CircuitBreaker({ failureThreshold: 5, resetTimeout: 30000 })
  async placeOrder(request: PlaceOrderRequest): Promise<OrderResponse> {
    // Protection contre les defaillances
  }
}

// 3. Batch operations
class BatchFacade {
  async processOrders(requests: PlaceOrderRequest[]): Promise<BatchResult[]> {
    return Promise.all(
      requests.map(async (req) => {
        try {
          const result = await this.placeOrder(req);
          return { success: true, result };
        } catch (error) {
          return { success: false, error: error.message };
        }
      }),
    );
  }
}
```

## Sources

- Martin Fowler, PoEAA, Chapter 15
- [Remote Facade - martinfowler.com](https://martinfowler.com/eaaCatalog/remoteFacade.html)
