# Strategy Pattern

> Definir une famille d'algorithmes interchangeables.

## Intention

Definir une famille d'algorithmes, encapsuler chacun d'eux et les rendre
interchangeables. Strategy permet de modifier l'algorithme independamment
des clients qui l'utilisent.

## Structure

```typescript
// 1. Interface Strategy
interface PaymentStrategy {
  pay(amount: number): Promise<PaymentResult>;
  validate(): boolean;
}

interface PaymentResult {
  success: boolean;
  transactionId?: string;
  error?: string;
}

// 2. Strategies concretes
class CreditCardStrategy implements PaymentStrategy {
  constructor(
    private cardNumber: string,
    private cvv: string,
    private expiryDate: string,
  ) {}

  validate(): boolean {
    return (
      this.cardNumber.length === 16 &&
      this.cvv.length === 3 &&
      this.isValidExpiry()
    );
  }

  private isValidExpiry(): boolean {
    const [month, year] = this.expiryDate.split('/');
    const expiry = new Date(2000 + parseInt(year), parseInt(month));
    return expiry > new Date();
  }

  async pay(amount: number): Promise<PaymentResult> {
    if (!this.validate()) {
      return { success: false, error: 'Invalid card details' };
    }
    // Integration avec gateway de paiement
    console.log(`Processing credit card payment of $${amount}`);
    return { success: true, transactionId: `CC_${Date.now()}` };
  }
}

class PayPalStrategy implements PaymentStrategy {
  constructor(private email: string) {}

  validate(): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.email);
  }

  async pay(amount: number): Promise<PaymentResult> {
    if (!this.validate()) {
      return { success: false, error: 'Invalid PayPal email' };
    }
    console.log(`Processing PayPal payment of $${amount} to ${this.email}`);
    return { success: true, transactionId: `PP_${Date.now()}` };
  }
}

class CryptoStrategy implements PaymentStrategy {
  constructor(
    private walletAddress: string,
    private currency: 'BTC' | 'ETH',
  ) {}

  validate(): boolean {
    return this.walletAddress.length >= 26;
  }

  async pay(amount: number): Promise<PaymentResult> {
    const cryptoAmount = await this.convertToCrypto(amount);
    console.log(`Sending ${cryptoAmount} ${this.currency}`);
    return { success: true, transactionId: `CRYPTO_${Date.now()}` };
  }

  private async convertToCrypto(usd: number): Promise<number> {
    // Appel API pour conversion
    return usd / 50000; // Exemple simplifie
  }
}

// 3. Context
class PaymentProcessor {
  private strategy: PaymentStrategy;

  constructor(strategy: PaymentStrategy) {
    this.strategy = strategy;
  }

  setStrategy(strategy: PaymentStrategy): void {
    this.strategy = strategy;
  }

  async checkout(amount: number): Promise<PaymentResult> {
    if (!this.strategy.validate()) {
      return { success: false, error: 'Payment method validation failed' };
    }
    return this.strategy.pay(amount);
  }
}
```

## Usage

```typescript
// Selection de strategie a l'execution
const processor = new PaymentProcessor(
  new CreditCardStrategy('4111111111111111', '123', '12/25'),
);

// Changer de strategie dynamiquement
processor.setStrategy(new PayPalStrategy('user@example.com'));

// Ou selon le choix utilisateur
function createPaymentStrategy(method: string, data: unknown): PaymentStrategy {
  switch (method) {
    case 'credit_card':
      return new CreditCardStrategy(data.number, data.cvv, data.expiry);
    case 'paypal':
      return new PayPalStrategy(data.email);
    case 'crypto':
      return new CryptoStrategy(data.wallet, data.currency);
    default:
      throw new Error(`Unknown payment method: ${method}`);
  }
}
```

## Variantes

### Strategy avec fonctions

```typescript
type SortStrategy<T> = (items: T[]) => T[];

const quickSort: SortStrategy<number> = items => {
  if (items.length <= 1) return items;
  const pivot = items[0];
  const left = items.slice(1).filter(x => x < pivot);
  const right = items.slice(1).filter(x => x >= pivot);
  return [...quickSort(left), pivot, ...quickSort(right)];
};

const mergeSort: SortStrategy<number> = items => {
  if (items.length <= 1) return items;
  const mid = Math.floor(items.length / 2);
  const left = mergeSort(items.slice(0, mid));
  const right = mergeSort(items.slice(mid));
  return merge(left, right);
};

// Context simplifie
class Sorter<T> {
  constructor(private strategy: SortStrategy<T>) {}

  sort(items: T[]): T[] {
    return this.strategy([...items]);
  }

  setStrategy(strategy: SortStrategy<T>): void {
    this.strategy = strategy;
  }
}

// Usage
const sorter = new Sorter(quickSort);
sorter.sort([3, 1, 4, 1, 5]);
sorter.setStrategy(mergeSort);
```

### Strategy avec Map

```typescript
interface CompressionStrategy {
  compress(data: Buffer): Buffer;
  decompress(data: Buffer): Buffer;
}

class CompressionContext {
  private strategies = new Map<string, CompressionStrategy>();

  register(name: string, strategy: CompressionStrategy): void {
    this.strategies.set(name, strategy);
  }

  compress(data: Buffer, algorithm: string): Buffer {
    const strategy = this.strategies.get(algorithm);
    if (!strategy) throw new Error(`Unknown algorithm: ${algorithm}`);
    return strategy.compress(data);
  }

  decompress(data: Buffer, algorithm: string): Buffer {
    const strategy = this.strategies.get(algorithm);
    if (!strategy) throw new Error(`Unknown algorithm: ${algorithm}`);
    return strategy.decompress(data);
  }
}

// Usage
const ctx = new CompressionContext();
ctx.register('gzip', new GzipStrategy());
ctx.register('brotli', new BrotliStrategy());
ctx.compress(data, 'gzip');
```

### Strategy avec validation

```typescript
interface ValidationStrategy {
  validate(value: unknown): ValidationResult;
}

interface ValidationResult {
  valid: boolean;
  errors: string[];
}

class CompositeValidator implements ValidationStrategy {
  constructor(private strategies: ValidationStrategy[]) {}

  validate(value: unknown): ValidationResult {
    const errors: string[] = [];

    for (const strategy of this.strategies) {
      const result = strategy.validate(value);
      if (!result.valid) {
        errors.push(...result.errors);
      }
    }

    return { valid: errors.length === 0, errors };
  }
}

// Strategies individuelles
class RequiredValidator implements ValidationStrategy {
  constructor(private field: string) {}

  validate(value: Record<string, unknown>): ValidationResult {
    if (!value[this.field]) {
      return { valid: false, errors: [`${this.field} is required`] };
    }
    return { valid: true, errors: [] };
  }
}

class EmailValidator implements ValidationStrategy {
  constructor(private field: string) {}

  validate(value: Record<string, unknown>): ValidationResult {
    const email = value[this.field] as string;
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return { valid: false, errors: [`${this.field} is not a valid email`] };
    }
    return { valid: true, errors: [] };
  }
}

// Usage
const userValidator = new CompositeValidator([
  new RequiredValidator('email'),
  new EmailValidator('email'),
  new RequiredValidator('password'),
]);

const result = userValidator.validate({ email: 'invalid', password: '' });
// { valid: false, errors: ['email is not a valid email', 'password is required'] }
```

## Anti-patterns

```typescript
// MAUVAIS: Strategy avec etat partage
class StatefulStrategy implements PaymentStrategy {
  private lastTransaction: string; // Etat = problemes de concurrence

  async pay(amount: number): Promise<PaymentResult> {
    this.lastTransaction = generateId();
    return { success: true, transactionId: this.lastTransaction };
  }
}

// MAUVAIS: Context qui connait les implementations
class BadContext {
  checkout(method: string, amount: number): void {
    if (method === 'credit_card') {
      // Logique specifique credit card
    } else if (method === 'paypal') {
      // Logique specifique PayPal
    }
    // Devrait utiliser une strategy!
  }
}

// MAUVAIS: Strategy trop granulaire
interface TooGranularStrategy {
  step1(): void;
  step2(): void;
  step3(): void;
  // Si tous les steps sont toujours executes ensemble,
  // une seule methode suffit
}
```

## Tests unitaires

```typescript
import { describe, it, expect, vi } from 'vitest';

describe('PaymentStrategies', () => {
  describe('CreditCardStrategy', () => {
    it('should validate correct card details', () => {
      const strategy = new CreditCardStrategy(
        '4111111111111111',
        '123',
        '12/25',
      );
      expect(strategy.validate()).toBe(true);
    });

    it('should reject invalid card number', () => {
      const strategy = new CreditCardStrategy('123', '123', '12/25');
      expect(strategy.validate()).toBe(false);
    });

    it('should process payment successfully', async () => {
      const strategy = new CreditCardStrategy(
        '4111111111111111',
        '123',
        '12/25',
      );
      const result = await strategy.pay(100);

      expect(result.success).toBe(true);
      expect(result.transactionId).toMatch(/^CC_/);
    });
  });

  describe('PayPalStrategy', () => {
    it('should validate correct email', () => {
      const strategy = new PayPalStrategy('user@example.com');
      expect(strategy.validate()).toBe(true);
    });

    it('should reject invalid email', () => {
      const strategy = new PayPalStrategy('invalid-email');
      expect(strategy.validate()).toBe(false);
    });
  });
});

describe('PaymentProcessor', () => {
  it('should use the provided strategy', async () => {
    const mockStrategy: PaymentStrategy = {
      validate: vi.fn().mockReturnValue(true),
      pay: vi.fn().mockResolvedValue({ success: true }),
    };

    const processor = new PaymentProcessor(mockStrategy);
    await processor.checkout(100);

    expect(mockStrategy.validate).toHaveBeenCalled();
    expect(mockStrategy.pay).toHaveBeenCalledWith(100);
  });

  it('should allow strategy change at runtime', async () => {
    const strategy1: PaymentStrategy = {
      validate: () => true,
      pay: vi.fn().mockResolvedValue({ success: true, transactionId: '1' }),
    };
    const strategy2: PaymentStrategy = {
      validate: () => true,
      pay: vi.fn().mockResolvedValue({ success: true, transactionId: '2' }),
    };

    const processor = new PaymentProcessor(strategy1);
    await processor.checkout(100);
    expect(strategy1.pay).toHaveBeenCalled();

    processor.setStrategy(strategy2);
    await processor.checkout(200);
    expect(strategy2.pay).toHaveBeenCalled();
  });

  it('should fail if validation fails', async () => {
    const strategy: PaymentStrategy = {
      validate: () => false,
      pay: vi.fn(),
    };

    const processor = new PaymentProcessor(strategy);
    const result = await processor.checkout(100);

    expect(result.success).toBe(false);
    expect(strategy.pay).not.toHaveBeenCalled();
  });
});
```

## Quand utiliser

- Plusieurs variantes d'un algorithme
- Eviter les conditionnels multiples (switch/if-else)
- Familles d'algorithmes relates
- Algorithme doit varier independamment du client

## Patterns lies

- **State** : Change de comportement selon l'etat (implicite)
- **Template Method** : Algorithme fixe avec etapes variables
- **Command** : Encapsule une action, pas un algorithme

## Sources

- [Refactoring Guru - Strategy](https://refactoring.guru/design-patterns/strategy)
