# Domain Service Pattern

## Definition

A **Domain Service** encapsulates domain logic that doesn't naturally fit within an Entity or Value Object. It represents operations or business rules that involve multiple domain objects or require external coordination.

```
Domain Service = Stateless + Domain Logic + Cross-Entity Operations
```

**Key characteristics:**

- **Stateless**: No internal state, operates on domain objects
- **Domain-focused**: Contains business logic, not infrastructure
- **Operation-centric**: Named after domain actions (verbs)
- **Cross-aggregate**: Coordinates between multiple aggregates
- **Interface-driven**: Often defined as interfaces for DI

## TypeScript Implementation

```typescript
// Domain Service Interface
interface TransferService {
  transfer(
    from: Account,
    to: Account,
    amount: Money
  ): Result<Transfer, TransferError>;
}

// Domain Service Implementation
class MoneyTransferService implements TransferService {
  constructor(
    private readonly exchangeRateService: ExchangeRateService,
    private readonly transferPolicyService: TransferPolicyService
  ) {}

  transfer(
    from: Account,
    to: Account,
    amount: Money
  ): Result<Transfer, TransferError> {
    // Validate transfer policy
    const policyResult = this.transferPolicyService.validate(from, to, amount);
    if (policyResult.isFailure) {
      return Result.fail(policyResult.error);
    }

    // Handle currency conversion if needed
    let transferAmount = amount;
    if (!from.currency.equals(to.currency)) {
      const convertResult = this.exchangeRateService.convert(
        amount,
        to.currency
      );
      if (convertResult.isFailure) {
        return Result.fail(new TransferError('Currency conversion failed'));
      }
      transferAmount = convertResult.value;
    }

    // Perform the transfer (domain logic)
    const debitResult = from.debit(amount);
    if (debitResult.isFailure) {
      return Result.fail(debitResult.error);
    }

    const creditResult = to.credit(transferAmount);
    if (creditResult.isFailure) {
      // Rollback debit
      from.credit(amount);
      return Result.fail(creditResult.error);
    }

    // Create transfer record
    return Transfer.create(from.id, to.id, amount, transferAmount);
  }
}

// Order Pricing Domain Service
interface PricingService {
  calculateTotal(order: Order, customer: Customer): Result<Money, PricingError>;
  applyDiscount(
    order: Order,
    discountCode: DiscountCode
  ): Result<Money, PricingError>;
}

class OrderPricingService implements PricingService {
  constructor(
    private readonly discountRepository: DiscountRepository,
    private readonly taxService: TaxService
  ) {}

  calculateTotal(order: Order, customer: Customer): Result<Money, PricingError> {
    let total = order.subtotal;

    // Apply customer tier discount
    const tierDiscount = this.calculateTierDiscount(customer.tier, total);
    total = total.subtract(tierDiscount).value!;

    // Apply bulk discount
    if (order.itemCount >= 10) {
      const bulkDiscount = total.multiply(0.05).value!;
      total = total.subtract(bulkDiscount).value!;
    }

    // Calculate tax
    const taxResult = this.taxService.calculate(total, customer.address);
    if (taxResult.isFailure) {
      return Result.fail(new PricingError('Tax calculation failed'));
    }

    total = total.add(taxResult.value).value!;

    return Result.ok(total);
  }

  async applyDiscount(
    order: Order,
    discountCode: DiscountCode
  ): Promise<Result<Money, PricingError>> {
    const discount = await this.discountRepository.findByCode(discountCode);

    if (!discount) {
      return Result.fail(new PricingError('Invalid discount code'));
    }

    if (discount.isExpired()) {
      return Result.fail(new PricingError('Discount code expired'));
    }

    if (!discount.isApplicableTo(order)) {
      return Result.fail(new PricingError('Discount not applicable to order'));
    }

    const discountAmount = discount.calculate(order.subtotal);
    return Result.ok(order.subtotal.subtract(discountAmount).value!);
  }

  private calculateTierDiscount(tier: CustomerTier, amount: Money): Money {
    const rates: Record<CustomerTier, number> = {
      [CustomerTier.Bronze]: 0,
      [CustomerTier.Silver]: 0.05,
      [CustomerTier.Gold]: 0.10,
      [CustomerTier.Platinum]: 0.15,
    };

    return amount.multiply(rates[tier]).value!;
  }
}

// Inventory Allocation Domain Service
interface InventoryAllocationService {
  allocate(
    order: Order,
    inventory: Inventory
  ): Result<Allocation[], AllocationError>;

  deallocate(allocation: Allocation): Result<void, AllocationError>;
}

class FIFOInventoryAllocationService implements InventoryAllocationService {
  allocate(
    order: Order,
    inventory: Inventory
  ): Result<Allocation[], AllocationError> {
    const allocations: Allocation[] = [];

    for (const item of order.items) {
      const batches = inventory.getBatchesForProduct(item.productId);
      let remainingQuantity = item.quantity.value;

      // FIFO allocation strategy
      for (const batch of batches.sortByDate('asc')) {
        if (remainingQuantity <= 0) break;

        const allocateQty = Math.min(remainingQuantity, batch.availableQuantity);

        const allocationResult = Allocation.create(
          order.id,
          batch.id,
          item.productId,
          Quantity.create(allocateQty).value!
        );

        if (allocationResult.isFailure) {
          // Rollback previous allocations
          allocations.forEach(a => this.deallocate(a));
          return Result.fail(allocationResult.error);
        }

        batch.reserve(allocateQty);
        allocations.push(allocationResult.value);
        remainingQuantity -= allocateQty;
      }

      if (remainingQuantity > 0) {
        // Rollback and fail
        allocations.forEach(a => this.deallocate(a));
        return Result.fail(
          new AllocationError(`Insufficient stock for ${item.productId.value}`)
        );
      }
    }

    return Result.ok(allocations);
  }

  deallocate(allocation: Allocation): Result<void, AllocationError> {
    allocation.batch.release(allocation.quantity.value);
    return Result.ok(undefined);
  }
}
```

## OOP vs FP Comparison

```typescript
// FP-style Domain Service using Effect
import { Effect, pipe } from 'effect';

// Pure function approach
const transfer = (
  exchangeRateService: ExchangeRateService,
  transferPolicyService: TransferPolicyService
) => (
  from: Account,
  to: Account,
  amount: Money
): Effect.Effect<Transfer, TransferError> =>
  pipe(
    // Validate policy
    transferPolicyService.validate(from, to, amount),
    Effect.flatMap(() =>
      // Convert currency if needed
      from.currency.equals(to.currency)
        ? Effect.succeed(amount)
        : exchangeRateService.convert(amount, to.currency)
    ),
    Effect.flatMap(transferAmount =>
      pipe(
        // Debit and credit
        Effect.all([
          Effect.try(() => from.debit(amount)),
          Effect.try(() => to.credit(transferAmount))
        ]),
        Effect.flatMap(() => Transfer.create(from.id, to.id, amount, transferAmount))
      )
    )
  );

// Using Effect Service pattern
class TransferService extends Effect.Tag('TransferService')<
  TransferService,
  {
    transfer: (
      from: Account,
      to: Account,
      amount: Money
    ) => Effect.Effect<Transfer, TransferError>;
  }
>() {}
```

## Domain Service vs Application Service

| Aspect | Domain Service | Application Service |
|--------|---------------|---------------------|
| Layer | Domain | Application |
| Focus | Business rules | Use case orchestration |
| Dependencies | Domain objects only | Repositories, external services |
| Stateless | Yes | Yes |
| Example | `PricingService` | `OrderApplicationService` |

```typescript
// Application Service (uses Domain Service)
class OrderApplicationService {
  constructor(
    private readonly orderRepo: OrderRepository,
    private readonly customerRepo: CustomerRepository,
    private readonly pricingService: PricingService, // Domain Service
    private readonly eventBus: EventBus
  ) {}

  async checkout(orderId: OrderId): Promise<Result<void, CheckoutError>> {
    const order = await this.orderRepo.findById(orderId);
    const customer = await this.customerRepo.findById(order.customerId);

    // Delegate to domain service
    const totalResult = this.pricingService.calculateTotal(order, customer);
    if (totalResult.isFailure) {
      return Result.fail(totalResult.error);
    }

    order.setTotal(totalResult.value);
    order.confirm();

    await this.orderRepo.save(order);

    return Result.ok(undefined);
  }
}
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **Effect** | Functional services | `npm i effect` |
| **inversify** | DI container | `npm i inversify` |
| **tsyringe** | Lightweight DI | `npm i tsyringe` |
| **neverthrow** | Result type | `npm i neverthrow` |

## Anti-patterns

1. **Stateful Service**: Maintaining internal state

   ```typescript
   // BAD
   class PricingService {
     private cachedRates: Map<string, number>; // State!
   }
   ```

2. **Anemic Service**: Just delegates to entities

   ```typescript
   // BAD - No actual domain logic
   class OrderService {
     addItem(order: Order, item: Item) {
       order.addItem(item); // Just delegation
     }
   }
   ```

3. **Infrastructure in Domain Service**: Database or API calls

   ```typescript
   // BAD - Infrastructure concern
   class PricingService {
     async calculate(order: Order) {
       const rates = await fetch('/api/rates'); // Infrastructure!
     }
   }
   ```

4. **God Service**: Too many responsibilities

   ```typescript
   // BAD - Too broad
   class OrderDomainService {
     calculatePrice() { }
     validateInventory() { }
     processPayment() { }
     sendNotification() { }
   }
   ```

## When to Use

- Logic involves multiple aggregates
- Operation doesn't belong to any single entity
- Complex calculations or transformations
- Business rules that span domain objects

## See Also

- [Entity](./entity.md) - Primary domain logic holder
- [Aggregate](./aggregate.md) - Coordinates entities
- [Domain Event](./domain-event.md) - Published by services
