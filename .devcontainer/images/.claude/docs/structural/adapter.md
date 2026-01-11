# Adapter Pattern

> Convertir l'interface d'une classe en une autre interface attendue par le client.

## Intention

Permettre a des classes avec des interfaces incompatibles de travailler
ensemble en encapsulant une classe existante avec une nouvelle interface.

## Structure

```typescript
// 1. Interface cible (ce que le client attend)
interface PaymentProcessor {
  charge(amount: number, currency: string): Promise<PaymentResult>;
  refund(transactionId: string, amount: number): Promise<RefundResult>;
}

interface PaymentResult {
  transactionId: string;
  status: 'success' | 'failed';
}

interface RefundResult {
  refundId: string;
  status: 'success' | 'failed';
}

// 2. Classe existante (interface incompatible)
class StripeAPI {
  createCharge(params: {
    amount: number;
    currency: string;
    source: string;
  }): Promise<StripeCharge> {
    // API Stripe reelle
    return Promise.resolve({
      id: 'ch_123',
      amount: params.amount,
      status: 'succeeded',
    });
  }

  createRefund(chargeId: string, amount: number): Promise<StripeRefund> {
    return Promise.resolve({
      id: 're_123',
      charge: chargeId,
      status: 'succeeded',
    });
  }
}

// 3. Adapter
class StripeAdapter implements PaymentProcessor {
  constructor(
    private stripe: StripeAPI,
    private defaultSource: string,
  ) {}

  async charge(amount: number, currency: string): Promise<PaymentResult> {
    const result = await this.stripe.createCharge({
      amount: Math.round(amount * 100), // Stripe utilise les centimes
      currency: currency.toLowerCase(),
      source: this.defaultSource,
    });

    return {
      transactionId: result.id,
      status: result.status === 'succeeded' ? 'success' : 'failed',
    };
  }

  async refund(transactionId: string, amount: number): Promise<RefundResult> {
    const result = await this.stripe.createRefund(
      transactionId,
      Math.round(amount * 100),
    );

    return {
      refundId: result.id,
      status: result.status === 'succeeded' ? 'success' : 'failed',
    };
  }
}
```

## Usage

```typescript
// Le client utilise l'interface generique
class PaymentService {
  constructor(private processor: PaymentProcessor) {}

  async processOrder(order: Order): Promise<void> {
    const result = await this.processor.charge(
      order.total,
      order.currency,
    );

    if (result.status === 'success') {
      order.transactionId = result.transactionId;
      order.status = 'paid';
    }
  }
}

// Configuration
const stripeAPI = new StripeAPI();
const adapter = new StripeAdapter(stripeAPI, 'tok_visa');
const paymentService = new PaymentService(adapter);
```

## Variantes

### Object Adapter (composition - recommande)

```typescript
class StripeAdapter implements PaymentProcessor {
  constructor(private stripe: StripeAPI) {} // Composition
  // ...
}
```

### Class Adapter (heritage - TypeScript limite)

```typescript
// Possible seulement avec classes, pas interfaces
class StripeClassAdapter extends StripeAPI implements PaymentProcessor {
  async charge(amount: number, currency: string): Promise<PaymentResult> {
    const result = await this.createCharge({
      amount: amount * 100,
      currency,
      source: 'default',
    });
    return { transactionId: result.id, status: 'success' };
  }
  // ...
}
```

### Two-Way Adapter

```typescript
interface ModernLogger {
  log(level: string, message: string, meta?: object): void;
}

interface LegacyLogger {
  info(message: string): void;
  error(message: string): void;
}

class TwoWayLoggerAdapter implements ModernLogger, LegacyLogger {
  constructor(
    private modern?: ModernLogger,
    private legacy?: LegacyLogger,
  ) {}

  // Interface moderne
  log(level: string, message: string, meta?: object): void {
    if (this.modern) {
      this.modern.log(level, message, meta);
    } else if (this.legacy) {
      level === 'error'
        ? this.legacy.error(message)
        : this.legacy.info(message);
    }
  }

  // Interface legacy
  info(message: string): void {
    this.log('info', message);
  }

  error(message: string): void {
    this.log('error', message);
  }
}
```

### Adapter avec cache

```typescript
class CachedPaymentAdapter implements PaymentProcessor {
  private cache = new Map<string, PaymentResult>();

  constructor(private adapter: PaymentProcessor) {}

  async charge(amount: number, currency: string): Promise<PaymentResult> {
    const key = `${amount}-${currency}`;

    // Pas de cache pour les charges (idem potent)
    return this.adapter.charge(amount, currency);
  }

  async refund(transactionId: string, amount: number): Promise<RefundResult> {
    return this.adapter.refund(transactionId, amount);
  }

  // Methode supplementaire pour consulter l'historique
  getHistory(): PaymentResult[] {
    return Array.from(this.cache.values());
  }
}
```

## Cas d'usage concrets

### Adapter pour API tierce

```typescript
// API externe avec format different
class ExternalWeatherAPI {
  getWeather(lat: number, lon: number): ExternalWeatherData {
    return {
      temp_c: 22,
      humidity_pct: 65,
      wind_kph: 15,
    };
  }
}

// Notre interface interne
interface WeatherData {
  temperature: number;
  humidity: number;
  windSpeed: number;
  unit: 'celsius' | 'fahrenheit';
}

class WeatherAdapter {
  constructor(private api: ExternalWeatherAPI) {}

  getWeather(lat: number, lon: number): WeatherData {
    const data = this.api.getWeather(lat, lon);
    return {
      temperature: data.temp_c,
      humidity: data.humidity_pct,
      windSpeed: data.wind_kph,
      unit: 'celsius',
    };
  }
}
```

### Adapter pour legacy code

```typescript
// Ancien systeme callback-based
class LegacyFileReader {
  read(path: string, callback: (err: Error | null, data: string) => void): void {
    // ...
  }
}

// Interface moderne Promise-based
interface FileReader {
  read(path: string): Promise<string>;
}

class FileReaderAdapter implements FileReader {
  constructor(private legacy: LegacyFileReader) {}

  read(path: string): Promise<string> {
    return new Promise((resolve, reject) => {
      this.legacy.read(path, (err, data) => {
        if (err) reject(err);
        else resolve(data);
      });
    });
  }
}
```

## Anti-patterns

```typescript
// MAUVAIS: Adapter qui fait trop
class OverloadedAdapter implements PaymentProcessor {
  async charge(amount: number, currency: string): Promise<PaymentResult> {
    // Validation - devrait etre ailleurs
    if (amount <= 0) throw new Error('Invalid amount');

    // Logging - cross-cutting concern
    console.log('Processing payment...');

    // Business logic - ne devrait pas etre ici
    const fee = amount * 0.03;
    const total = amount + fee;

    // Finalement l'adaptation
    return this.stripe.createCharge({ amount: total, currency, source: '' });
  }
}

// MAUVAIS: Adapter qui expose l'implementation
class LeakyAdapter implements PaymentProcessor {
  getStripeInstance(): StripeAPI {
    return this.stripe; // Fuite d'abstraction!
  }
}
```

## Tests unitaires

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('StripeAdapter', () => {
  let mockStripe: StripeAPI;
  let adapter: StripeAdapter;

  beforeEach(() => {
    mockStripe = {
      createCharge: vi.fn().mockResolvedValue({
        id: 'ch_123',
        status: 'succeeded',
      }),
      createRefund: vi.fn().mockResolvedValue({
        id: 're_123',
        status: 'succeeded',
      }),
    } as unknown as StripeAPI;

    adapter = new StripeAdapter(mockStripe, 'tok_test');
  });

  it('should convert amount to cents for Stripe', async () => {
    await adapter.charge(100, 'USD');

    expect(mockStripe.createCharge).toHaveBeenCalledWith({
      amount: 10000, // 100 * 100
      currency: 'usd',
      source: 'tok_test',
    });
  });

  it('should map Stripe status to our format', async () => {
    const result = await adapter.charge(50, 'EUR');

    expect(result).toEqual({
      transactionId: 'ch_123',
      status: 'success',
    });
  });

  it('should handle failed charges', async () => {
    mockStripe.createCharge = vi.fn().mockResolvedValue({
      id: 'ch_fail',
      status: 'failed',
    });

    const result = await adapter.charge(50, 'EUR');

    expect(result.status).toBe('failed');
  });
});
```

## Quand utiliser

- Integrer du code legacy ou bibliotheques tierces
- Uniformiser des interfaces incompatibles
- Isoler le code client des changements d'API
- Reutiliser des classes existantes sans les modifier

## Patterns lies

- **Bridge** : Separe abstraction/implementation (conception)
- **Decorator** : Ajoute des comportements (meme interface)
- **Facade** : Simplifie une interface complexe
- **Proxy** : Meme interface, controle d'acces

## Sources

- [Refactoring Guru - Adapter](https://refactoring.guru/design-patterns/adapter)
