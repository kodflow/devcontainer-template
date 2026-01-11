# Bounded Context Pattern

## Definition

A **Bounded Context** is a semantic boundary within which a domain model is defined and applicable. It represents a linguistic boundary where terms have specific, unambiguous meanings, and models are internally consistent.

```
Bounded Context = Model Boundary + Ubiquitous Language + Team Ownership + Integration Points
```

**Key characteristics:**

- **Linguistic boundary**: Same term can mean different things in different contexts
- **Model consistency**: One model per context, no ambiguity
- **Team alignment**: Often maps to team ownership
- **Explicit boundaries**: Clear interfaces between contexts
- **Autonomous**: Can evolve independently

## Context Map Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                        CONTEXT MAP                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐    Shared Kernel    ┌──────────────┐          │
│  │   Orders     │◄──────────────────►│   Shipping   │          │
│  │   Context    │                     │   Context    │          │
│  └──────┬───────┘                     └──────────────┘          │
│         │                                                        │
│         │ Customer/Supplier                                      │
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────┐                     ┌──────────────┐          │
│  │   Billing    │                     │   Catalog    │          │
│  │   Context    │    Conformist       │   Context    │          │
│  └──────┬───────┘◄────────────────────┴──────────────┘          │
│         │                                                        │
│         │ Anti-Corruption Layer                                  │
│         ▼                                                        │
│  ┌──────────────┐                                                │
│  │   External   │                                                │
│  │   Payment    │                                                │
│  └──────────────┘                                                │
└─────────────────────────────────────────────────────────────────┘
```

## TypeScript Implementation

### Context Definition

```typescript
// Each context has its own domain model
// orders-context/domain/Order.ts
namespace OrdersContext {
  export class Order extends AggregateRoot<OrderId> {
    private _customerId: CustomerId;
    private _items: OrderItem[];
    private _status: OrderStatus;

    // Order-specific behavior
    confirm(): Result<void, DomainError> { }
    cancel(): Result<void, DomainError> { }
  }

  // Customer in Orders context - minimal, order-focused
  export class Customer extends Entity<CustomerId> {
    private _name: string;
    private _shippingAddress: Address;
    // Only what Orders context needs
  }
}

// billing-context/domain/Customer.ts
namespace BillingContext {
  export class Customer extends AggregateRoot<CustomerId> {
    private _billingAddress: Address;
    private _paymentMethods: PaymentMethod[];
    private _creditLimit: Money;

    // Billing-specific behavior
    charge(amount: Money): Result<Payment, BillingError> { }
    addPaymentMethod(method: PaymentMethod): Result<void, ValidationError> { }
  }

  // Order in Billing context - just for invoicing
  export interface OrderReference {
    orderId: string;
    totalAmount: Money;
    orderDate: Date;
  }
}
```

### Anti-Corruption Layer (ACL)

```typescript
// Protect your domain from external/legacy systems
// billing-context/infrastructure/PaymentGatewayACL.ts

// External payment gateway response (their model)
interface ExternalPaymentResponse {
  transaction_id: string;
  status_code: number;
  amount_cents: number;
  currency_iso: string;
  error_msg?: string;
}

// Our domain model
class PaymentResult {
  constructor(
    readonly transactionId: TransactionId,
    readonly status: PaymentStatus,
    readonly amount: Money,
    readonly error?: PaymentError
  ) {}
}

// Anti-Corruption Layer - translates between models
class PaymentGatewayACL {
  constructor(private readonly gateway: ExternalPaymentGateway) {}

  async processPayment(
    amount: Money,
    method: PaymentMethod
  ): Promise<Result<PaymentResult, PaymentError>> {
    try {
      // Translate to external format
      const request = this.toExternalRequest(amount, method);

      // Call external service
      const response = await this.gateway.charge(request);

      // Translate back to our domain model
      return this.toDomainResult(response);
    } catch (error) {
      return Result.fail(new PaymentError('Gateway communication failed'));
    }
  }

  private toExternalRequest(amount: Money, method: PaymentMethod): ExternalPaymentRequest {
    return {
      amount_cents: Math.round(amount.amount * 100),
      currency_iso: amount.currency.code,
      payment_token: method.token,
    };
  }

  private toDomainResult(response: ExternalPaymentResponse): Result<PaymentResult, PaymentError> {
    if (response.status_code !== 200) {
      return Result.fail(new PaymentError(response.error_msg ?? 'Payment failed'));
    }

    return Result.ok(new PaymentResult(
      TransactionId.from(response.transaction_id),
      PaymentStatus.Completed,
      Money.create(response.amount_cents / 100, response.currency_iso)
    ));
  }
}
```

### Context Integration via Events

```typescript
// Shared integration events (in shared kernel or separate package)
// integration-events/OrderConfirmedIntegrationEvent.ts
interface OrderConfirmedIntegrationEvent {
  eventId: string;
  occurredAt: Date;
  orderId: string;
  customerId: string;
  totalAmount: { amount: number; currency: string };
  items: Array<{ productId: string; quantity: number }>;
}

// Orders Context - publishes event
class OrdersContextEventPublisher {
  constructor(private readonly messageBus: MessageBus) {}

  async publishOrderConfirmed(event: OrderConfirmedEvent): Promise<void> {
    // Translate domain event to integration event
    const integrationEvent: OrderConfirmedIntegrationEvent = {
      eventId: event.eventId,
      occurredAt: event.occurredAt,
      orderId: event.orderId.value,
      customerId: event.customerId.value,
      totalAmount: {
        amount: event.totalAmount.amount,
        currency: event.totalAmount.currency.code,
      },
      items: event.items.map(i => ({
        productId: i.productId,
        quantity: i.quantity,
      })),
    };

    await this.messageBus.publish('orders.order-confirmed', integrationEvent);
  }
}

// Billing Context - consumes event
class BillingContextEventHandler {
  constructor(
    private readonly invoiceService: InvoiceService,
    private readonly customerRepository: CustomerRepository
  ) {}

  async handleOrderConfirmed(event: OrderConfirmedIntegrationEvent): Promise<void> {
    // Translate integration event to billing domain
    const customer = await this.customerRepository.findById(
      CustomerId.from(event.customerId)
    );

    const orderRef: OrderReference = {
      orderId: event.orderId,
      totalAmount: Money.create(event.totalAmount.amount, event.totalAmount.currency),
      orderDate: event.occurredAt,
    };

    // Use billing domain logic
    await this.invoiceService.createInvoice(customer, orderRef);
  }
}
```

### Shared Kernel

```typescript
// shared-kernel/domain/Money.ts
// Shared between contexts that need identical money handling
export class Money {
  private constructor(
    readonly amount: number,
    readonly currency: Currency
  ) {}

  static create(amount: number, currencyCode: string): Money {
    return new Money(
      Math.round(amount * 100) / 100,
      Currency.fromCode(currencyCode)
    );
  }

  add(other: Money): Money {
    this.assertSameCurrency(other);
    return Money.create(this.amount + other.amount, this.currency.code);
  }

  // ... other operations
}

// shared-kernel/domain/Address.ts
export class Address {
  constructor(
    readonly street: string,
    readonly city: string,
    readonly postalCode: string,
    readonly country: Country
  ) {}
}
```

## Context Mapping Patterns

| Pattern | Description | Use When |
|---------|-------------|----------|
| **Shared Kernel** | Shared code between contexts | Close collaboration needed |
| **Customer/Supplier** | Upstream serves downstream | Clear dependency direction |
| **Conformist** | Downstream adopts upstream model | No negotiation power |
| **Anti-Corruption Layer** | Translation layer | Protecting from external/legacy |
| **Open Host Service** | Published API for multiple consumers | Many downstream contexts |
| **Published Language** | Shared schema/protocol | Standard integration format |
| **Separate Ways** | No integration | Contexts truly independent |

## Module Structure

```
src/
├── orders-context/
│   ├── domain/
│   │   ├── Order.ts
│   │   ├── OrderItem.ts
│   │   └── Customer.ts          # Orders' view of Customer
│   ├── application/
│   │   └── OrderService.ts
│   ├── infrastructure/
│   │   ├── TypeOrmOrderRepository.ts
│   │   └── EventPublisher.ts
│   └── api/
│       └── OrderController.ts
│
├── billing-context/
│   ├── domain/
│   │   ├── Invoice.ts
│   │   ├── Customer.ts          # Billing's view of Customer
│   │   └── Payment.ts
│   ├── application/
│   │   └── InvoiceService.ts
│   ├── infrastructure/
│   │   ├── PaymentGatewayACL.ts  # Anti-Corruption Layer
│   │   └── EventHandler.ts
│   └── api/
│       └── InvoiceController.ts
│
├── shared-kernel/
│   ├── domain/
│   │   ├── Money.ts
│   │   └── Address.ts
│   └── infrastructure/
│       └── MessageBus.ts
│
└── integration-events/
    ├── OrderConfirmedEvent.ts
    └── PaymentReceivedEvent.ts
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **NestJS Modules** | Context isolation | `npm i @nestjs/core` |
| **RabbitMQ** | Event-based integration | `npm i amqplib` |
| **Apache Kafka** | Event streaming | `npm i kafkajs` |
| **GraphQL Federation** | API composition | `npm i @apollo/federation` |

## Anti-patterns

1. **Shared Database**: Multiple contexts writing to same tables

   ```
   // BAD - Tight coupling via database
   Orders Context ──┐
                    ├──► customers table
   Billing Context ─┘
   ```

2. **Model Bleeding**: Using another context's internal model

   ```typescript
   // BAD - Billing using Orders' internal model
   import { Order } from '../orders-context/domain/Order';
   ```

3. **Big Ball of Mud**: No clear boundaries

   ```typescript
   // BAD - Everything in one "domain"
   class OrderBillingShippingService { }
   ```

4. **Sync Integration**: Direct synchronous calls between contexts

   ```typescript
   // BAD - Tight coupling
   class OrderService {
     confirm(order: Order) {
       this.billingService.createInvoice(order); // Direct call
     }
   }
   ```

## When to Use

- Large domains with distinct sub-domains
- Multiple teams working on same system
- Different parts of system evolve at different rates
- Need to integrate with external systems
- Terms have different meanings in different parts of business

## See Also

- [Aggregate](./aggregate.md) - Lives within bounded context
- [Domain Event](./domain-event.md) - Cross-context communication
- [Repository](./repository.md) - Context-specific persistence
