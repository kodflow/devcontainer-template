# Specification Pattern

## Definition

A **Specification** encapsulates business rules that can be combined and reused. It separates the statement of how to match a candidate from the candidate object itself, enabling composable and testable query/validation logic.

```
Specification = Business Rule + Composability + Reusability + Testability
```

**Key characteristics:**

- **Single responsibility**: One rule per specification
- **Composable**: AND, OR, NOT operations
- **Reusable**: Same spec for queries and validation
- **Testable**: Rules isolated and unit-testable
- **Domain-focused**: Named in ubiquitous language

## TypeScript Implementation

```typescript
// Base Specification Interface
interface Specification<T> {
  isSatisfiedBy(candidate: T): boolean;
  and(other: Specification<T>): Specification<T>;
  or(other: Specification<T>): Specification<T>;
  not(): Specification<T>;
}

// Abstract Base Class
abstract class CompositeSpecification<T> implements Specification<T> {
  abstract isSatisfiedBy(candidate: T): boolean;

  and(other: Specification<T>): Specification<T> {
    return new AndSpecification(this, other);
  }

  or(other: Specification<T>): Specification<T> {
    return new OrSpecification(this, other);
  }

  not(): Specification<T> {
    return new NotSpecification(this);
  }
}

// Composite Operators
class AndSpecification<T> extends CompositeSpecification<T> {
  constructor(
    private readonly left: Specification<T>,
    private readonly right: Specification<T>
  ) {
    super();
  }

  isSatisfiedBy(candidate: T): boolean {
    return this.left.isSatisfiedBy(candidate) &&
           this.right.isSatisfiedBy(candidate);
  }
}

class OrSpecification<T> extends CompositeSpecification<T> {
  constructor(
    private readonly left: Specification<T>,
    private readonly right: Specification<T>
  ) {
    super();
  }

  isSatisfiedBy(candidate: T): boolean {
    return this.left.isSatisfiedBy(candidate) ||
           this.right.isSatisfiedBy(candidate);
  }
}

class NotSpecification<T> extends CompositeSpecification<T> {
  constructor(private readonly spec: Specification<T>) {
    super();
  }

  isSatisfiedBy(candidate: T): boolean {
    return !this.spec.isSatisfiedBy(candidate);
  }
}

// Domain Specifications - Order Example
class OrderIsConfirmedSpec extends CompositeSpecification<Order> {
  isSatisfiedBy(order: Order): boolean {
    return order.status === OrderStatus.Confirmed;
  }
}

class OrderHasMinimumValueSpec extends CompositeSpecification<Order> {
  constructor(private readonly minimumValue: Money) {
    super();
  }

  isSatisfiedBy(order: Order): boolean {
    return order.totalAmount.isGreaterThanOrEqual(this.minimumValue);
  }
}

class OrderIsFromPremiumCustomerSpec extends CompositeSpecification<Order> {
  constructor(private readonly customerRepository: CustomerRepository) {
    super();
  }

  isSatisfiedBy(order: Order): boolean {
    const customer = this.customerRepository.findById(order.customerId);
    return customer?.tier === CustomerTier.Premium;
  }
}

class OrderIsEligibleForFreeShippingSpec extends CompositeSpecification<Order> {
  constructor(private readonly customerRepository: CustomerRepository) {
    super();
  }

  isSatisfiedBy(order: Order): boolean {
    // Compose existing specifications
    const hasMinValue = new OrderHasMinimumValueSpec(Money.create(100, 'USD'));
    const isPremium = new OrderIsFromPremiumCustomerSpec(this.customerRepository);

    // Free shipping: order >= $100 OR premium customer
    return hasMinValue.or(isPremium).isSatisfiedBy(order);
  }
}

// Product Specifications
class ProductIsInStockSpec extends CompositeSpecification<Product> {
  isSatisfiedBy(product: Product): boolean {
    return product.stockQuantity > 0;
  }
}

class ProductIsInCategorySpec extends CompositeSpecification<Product> {
  constructor(private readonly categoryId: CategoryId) {
    super();
  }

  isSatisfiedBy(product: Product): boolean {
    return product.categoryId.equals(this.categoryId);
  }
}

class ProductPriceInRangeSpec extends CompositeSpecification<Product> {
  constructor(
    private readonly minPrice: Money,
    private readonly maxPrice: Money
  ) {
    super();
  }

  isSatisfiedBy(product: Product): boolean {
    return product.price.isGreaterThanOrEqual(this.minPrice) &&
           product.price.isLessThanOrEqual(this.maxPrice);
  }
}
```

## Usage Examples

```typescript
// In-memory filtering
const orders: Order[] = await orderRepository.findAll();

const eligibleForShipping = new OrderIsConfirmedSpec()
  .and(new OrderHasMinimumValueSpec(Money.create(50, 'USD')));

const readyToShip = orders.filter(o => eligibleForShipping.isSatisfiedBy(o));

// Validation
class OrderService {
  private readonly freeShippingSpec: OrderIsEligibleForFreeShippingSpec;

  calculateShipping(order: Order): Money {
    if (this.freeShippingSpec.isSatisfiedBy(order)) {
      return Money.zero('USD');
    }
    return this.calculateStandardShipping(order);
  }
}

// Complex business rule
const premiumDiscount = new OrderIsConfirmedSpec()
  .and(new OrderHasMinimumValueSpec(Money.create(200, 'USD')))
  .and(new OrderIsFromPremiumCustomerSpec(customerRepo));

if (premiumDiscount.isSatisfiedBy(order)) {
  order.applyDiscount(Percentage.create(15));
}
```

## Query Specification (Repository Integration)

```typescript
// Specification that can be converted to query
interface QuerySpecification<T> extends Specification<T> {
  toQueryCriteria(): QueryCriteria;
}

abstract class QueryableSpecification<T>
  extends CompositeSpecification<T>
  implements QuerySpecification<T> {

  abstract toQueryCriteria(): QueryCriteria;
}

// Example with TypeORM
class OrderIsConfirmedQuerySpec extends QueryableSpecification<Order> {
  isSatisfiedBy(order: Order): boolean {
    return order.status === OrderStatus.Confirmed;
  }

  toQueryCriteria(): QueryCriteria {
    return { status: OrderStatus.Confirmed };
  }
}

class OrderHasMinimumValueQuerySpec extends QueryableSpecification<Order> {
  constructor(private readonly minimumValue: Money) {
    super();
  }

  isSatisfiedBy(order: Order): boolean {
    return order.totalAmount.isGreaterThanOrEqual(this.minimumValue);
  }

  toQueryCriteria(): QueryCriteria {
    return {
      totalAmount: { $gte: this.minimumValue.amount }
    };
  }
}

// Repository using specification
class TypeOrmOrderRepository {
  async findBySpecification(spec: QuerySpecification<Order>): Promise<Order[]> {
    const criteria = spec.toQueryCriteria();

    const entities = await this.repository.find({
      where: criteria
    });

    // Double-check in memory (for complex specs)
    return entities
      .map(e => this.toDomain(e))
      .filter(o => spec.isSatisfiedBy(o));
  }
}
```

## OOP vs FP Comparison

```typescript
// FP-style Specification using predicates
import { pipe } from 'fp-ts/function';
import * as A from 'fp-ts/Array';
import * as P from 'fp-ts/Predicate';

type Spec<T> = (t: T) => boolean;

// Combinators
const and = <T>(...specs: Spec<T>[]): Spec<T> =>
  (t) => specs.every(s => s(t));

const or = <T>(...specs: Spec<T>[]): Spec<T> =>
  (t) => specs.some(s => s(t));

const not = <T>(spec: Spec<T>): Spec<T> =>
  (t) => !spec(t);

// Domain specifications as functions
const isConfirmed: Spec<Order> = (o) => o.status === OrderStatus.Confirmed;

const hasMinValue = (min: Money): Spec<Order> =>
  (o) => o.totalAmount.isGreaterThanOrEqual(min);

const isPremiumCustomer = (repo: CustomerRepository): Spec<Order> =>
  (o) => repo.findById(o.customerId)?.tier === CustomerTier.Premium;

// Composition
const eligibleForDiscount = and(
  isConfirmed,
  hasMinValue(Money.create(200, 'USD')),
  isPremiumCustomer(customerRepo)
);

// Usage with fp-ts
const discountedOrders = pipe(
  orders,
  A.filter(eligibleForDiscount)
);
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **fp-ts** | Predicate combinators | `npm i fp-ts` |
| **Effect** | Functional specs | `npm i effect` |
| **class-validator** | Validation specs | `npm i class-validator` |
| **zod** | Schema validation | `npm i zod` |

## Anti-patterns

1. **God Specification**: Too many rules in one spec

   ```typescript
   // BAD
   class OrderIsValidSpec {
     isSatisfiedBy(order: Order): boolean {
       return order.status === 'confirmed' &&
              order.total > 0 &&
              order.items.length > 0 &&
              // ... 20 more conditions
     }
   }
   ```

2. **Leaking Implementation**: Exposing internal details

   ```typescript
   // BAD
   class OrderSpec {
     getStatusToCheck(): OrderStatus { } // Exposes internals
   }
   ```

3. **Non-Composable**: Specifications that can't be combined

   ```typescript
   // BAD - No composition support
   class OrderSpec {
     check(order: Order): boolean { return true; }
   }
   ```

4. **Side Effects**: Modifying state in specification

   ```typescript
   // BAD
   isSatisfiedBy(order: Order): boolean {
     order.markAsChecked(); // Side effect!
     return order.isValid;
   }
   ```

## When to Use

- Complex business rules that need composition
- Rules reused for both validation and querying
- Domain logic that should be testable in isolation
- Filtering collections by business criteria

## See Also

- [Repository](./repository.md) - Uses specifications for queries
- [Value Object](./value-object.md) - Rules often involve value objects
- [Domain Service](./domain-service.md) - Uses specifications for decisions
