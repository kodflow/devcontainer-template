# Value Object Pattern

## Definition

A **Value Object** is an immutable domain object defined entirely by its attributes, with no conceptual identity. Two Value Objects with the same attributes are considered equal.

```
Value Object = Attributes + Immutability + Equality by Value + Self-Validation
```

**Key characteristics:**

- **Immutability**: Cannot be changed after creation
- **Equality**: Compared by attribute values, not reference
- **Self-Validation**: Always valid after construction
- **Side-effect free**: Operations return new instances
- **Replaceability**: Can be freely substituted when equal

## TypeScript Implementation

```typescript
// Base Value Object
abstract class ValueObject<T extends Record<string, unknown>> {
  protected readonly props: Readonly<T>;

  protected constructor(props: T) {
    this.props = Object.freeze(props);
  }

  equals(other: ValueObject<T>): boolean {
    if (other === null || other === undefined) return false;
    return JSON.stringify(this.props) === JSON.stringify(other.props);
  }

  // Deep equality for complex objects
  protected deepEquals(other: ValueObject<T>): boolean {
    return this.hashCode() === other.hashCode();
  }

  hashCode(): string {
    return JSON.stringify(this.props);
  }
}

// Email Value Object
class Email extends ValueObject<{ value: string }> {
  private static readonly EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  private constructor(value: string) {
    super({ value });
  }

  static create(value: string): Result<Email, ValidationError> {
    if (!value || value.trim() === '') {
      return Result.fail(new ValidationError('Email cannot be empty'));
    }

    const normalized = value.toLowerCase().trim();

    if (!Email.EMAIL_REGEX.test(normalized)) {
      return Result.fail(new ValidationError('Invalid email format'));
    }

    return Result.ok(new Email(normalized));
  }

  get value(): string {
    return this.props.value;
  }

  get domain(): string {
    return this.props.value.split('@')[1];
  }

  // Returns new instance - immutable operation
  changeDomain(newDomain: string): Result<Email, ValidationError> {
    const localPart = this.props.value.split('@')[0];
    return Email.create(`${localPart}@${newDomain}`);
  }
}

// Money Value Object - Complex example
class Money extends ValueObject<{ amount: number; currency: Currency }> {
  private constructor(amount: number, currency: Currency) {
    super({ amount, currency });
  }

  static create(amount: number, currency: Currency): Result<Money, ValidationError> {
    if (!Number.isFinite(amount)) {
      return Result.fail(new ValidationError('Amount must be a finite number'));
    }

    // Round to currency precision
    const precision = currency.decimalPlaces;
    const rounded = Math.round(amount * 10 ** precision) / 10 ** precision;

    return Result.ok(new Money(rounded, currency));
  }

  static zero(currency: Currency): Money {
    return new Money(0, currency);
  }

  get amount(): number { return this.props.amount; }
  get currency(): Currency { return this.props.currency; }

  add(other: Money): Result<Money, DomainError> {
    if (!this.props.currency.equals(other.currency)) {
      return Result.fail(new DomainError('Cannot add different currencies'));
    }
    return Money.create(this.props.amount + other.amount, this.props.currency);
  }

  subtract(other: Money): Result<Money, DomainError> {
    if (!this.props.currency.equals(other.currency)) {
      return Result.fail(new DomainError('Cannot subtract different currencies'));
    }
    return Money.create(this.props.amount - other.amount, this.props.currency);
  }

  multiply(factor: number): Result<Money, ValidationError> {
    return Money.create(this.props.amount * factor, this.props.currency);
  }

  isPositive(): boolean { return this.props.amount > 0; }
  isNegative(): boolean { return this.props.amount < 0; }
  isZero(): boolean { return this.props.amount === 0; }

  format(): string {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: this.props.currency.code,
    }).format(this.props.amount);
  }
}

// Address Value Object - Composite
class Address extends ValueObject<{
  street: string;
  city: string;
  postalCode: string;
  country: Country;
}> {
  private constructor(
    street: string,
    city: string,
    postalCode: string,
    country: Country
  ) {
    super({ street, city, postalCode, country });
  }

  static create(
    street: string,
    city: string,
    postalCode: string,
    country: Country
  ): Result<Address, ValidationError> {
    const errors: string[] = [];

    if (!street?.trim()) errors.push('Street is required');
    if (!city?.trim()) errors.push('City is required');
    if (!postalCode?.trim()) errors.push('Postal code is required');
    if (!country.validatePostalCode(postalCode)) {
      errors.push('Invalid postal code for country');
    }

    if (errors.length > 0) {
      return Result.fail(new ValidationError(errors.join('; ')));
    }

    return Result.ok(new Address(street.trim(), city.trim(), postalCode.trim(), country));
  }

  get street(): string { return this.props.street; }
  get city(): string { return this.props.city; }
  get postalCode(): string { return this.props.postalCode; }
  get country(): Country { return this.props.country; }

  format(): string {
    return `${this.street}, ${this.city} ${this.postalCode}, ${this.country.name}`;
  }
}
```

## OOP vs FP Comparison

| Aspect | OOP Value Object | FP Value Object |
|--------|-----------------|-----------------|
| Structure | Class with private constructor | Branded type or newtype |
| Validation | Factory method | Smart constructor |
| Operations | Instance methods | Pure functions |
| Composition | Inheritance | Type composition |

```typescript
// FP-style Value Object using Effect
import { Brand, Data } from 'effect';
import * as S from '@effect/schema/Schema';

// Branded type for type safety
type Email = string & Brand.Brand<'Email'>;

const EmailSchema = S.String.pipe(
  S.pattern(/^[^\s@]+@[^\s@]+\.[^\s@]+$/),
  S.brand('Email')
);

const createEmail = S.decodeUnknown(EmailSchema);

// Using Data for structural equality
class Money extends Data.Class<{ amount: number; currency: string }> {
  add(other: Money): Money {
    if (this.currency !== other.currency) {
      throw new Error('Currency mismatch');
    }
    return new Money({ amount: this.amount + other.amount, currency: this.currency });
  }
}

// Automatic equality
const m1 = new Money({ amount: 100, currency: 'USD' });
const m2 = new Money({ amount: 100, currency: 'USD' });
console.log(m1 === m2); // false (reference)
console.log(Data.equals(m1, m2)); // true (structural)
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **Effect** | Branded types, Data | `npm i effect` |
| **@effect/schema** | Validation schemas | `npm i @effect/schema` |
| **zod** | Runtime validation | `npm i zod` |
| **io-ts** | Codec validation | `npm i io-ts` |
| **neverthrow** | Result type | `npm i neverthrow` |

## Anti-patterns

1. **Mutable Value Object**: Adding setters breaks immutability

   ```typescript
   // BAD
   class Email {
     private value: string;
     setValue(v: string) { this.value = v; } // Mutation!
   }
   ```

2. **Invalid Construction**: Allowing invalid state

   ```typescript
   // BAD - No validation
   const email = new Email('not-an-email');

   // GOOD - Factory with validation
   const email = Email.create('user@example.com');
   ```

3. **Primitive Obsession**: Using primitives instead of Value Objects

   ```typescript
   // BAD
   function sendEmail(to: string, amount: number, currency: string) {}

   // GOOD
   function sendEmail(to: Email, amount: Money) {}
   ```

4. **Missing Equality**: Not implementing proper equality

   ```typescript
   // BAD - Reference comparison
   email1 === email2

   // GOOD - Value comparison
   email1.equals(email2)
   ```

## When to Use

- Attribute combinations that appear together (Email, Money, Address)
- Concepts that are defined by their values, not identity
- Measurements, quantities, descriptors
- Whenever you need immutability guarantees

## See Also

- [Entity](./entity.md) - For objects with identity
- [Aggregate](./aggregate.md) - Contains Value Objects
- [Specification](./specification.md) - Uses Value Objects for rules
