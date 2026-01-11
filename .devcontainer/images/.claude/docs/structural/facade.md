# Facade Pattern

> Fournir une interface simplifiee a un ensemble de classes complexes.

## Intention

Fournir une interface unifiee a un ensemble d'interfaces d'un sous-systeme.
La facade definit une interface de plus haut niveau qui rend le sous-systeme
plus facile a utiliser.

## Structure

```typescript
// 1. Sous-systeme complexe
class VideoFile {
  constructor(public filename: string) {}
}

class VideoCodec {
  decode(file: VideoFile): Buffer {
    console.log('Decoding video...');
    return Buffer.alloc(0);
  }
}

class AudioCodec {
  decode(file: VideoFile): Buffer {
    console.log('Decoding audio...');
    return Buffer.alloc(0);
  }
}

class VideoMixer {
  mix(video: Buffer, audio: Buffer): Buffer {
    console.log('Mixing video and audio...');
    return Buffer.concat([video, audio]);
  }
}

class Encoder {
  encode(data: Buffer, format: string): Buffer {
    console.log(`Encoding to ${format}...`);
    return data;
  }
}

class FileWriter {
  write(data: Buffer, filename: string): void {
    console.log(`Writing to ${filename}...`);
  }
}

// 2. Facade
class VideoConverter {
  private videoCodec = new VideoCodec();
  private audioCodec = new AudioCodec();
  private mixer = new VideoMixer();
  private encoder = new Encoder();
  private writer = new FileWriter();

  convert(filename: string, format: string): void {
    console.log(`Converting ${filename} to ${format}`);

    const file = new VideoFile(filename);
    const video = this.videoCodec.decode(file);
    const audio = this.audioCodec.decode(file);
    const mixed = this.mixer.mix(video, audio);
    const encoded = this.encoder.encode(mixed, format);

    const outputName = filename.replace(/\.[^.]+$/, `.${format}`);
    this.writer.write(encoded, outputName);

    console.log('Conversion complete!');
  }
}

// Usage simplifie
const converter = new VideoConverter();
converter.convert('movie.avi', 'mp4');
```

## Cas d'usage concrets

### Facade pour E-commerce

```typescript
// Sous-systemes
class InventoryService {
  checkStock(productId: string): boolean { return true; }
  reserveStock(productId: string, qty: number): void {}
  releaseStock(productId: string, qty: number): void {}
}

class PaymentService {
  authorize(amount: number, card: Card): string { return 'auth_123'; }
  capture(authId: string): void {}
  refund(authId: string): void {}
}

class ShippingService {
  calculateCost(address: Address): number { return 10; }
  createLabel(order: Order): string { return 'SHIP_123'; }
  schedulePickup(labelId: string): void {}
}

class NotificationService {
  sendEmail(to: string, template: string, data: object): void {}
  sendSMS(phone: string, message: string): void {}
}

// Facade
class OrderFacade {
  constructor(
    private inventory: InventoryService,
    private payment: PaymentService,
    private shipping: ShippingService,
    private notification: NotificationService,
  ) {}

  async placeOrder(order: Order): Promise<OrderResult> {
    // 1. Verifier stock
    for (const item of order.items) {
      if (!this.inventory.checkStock(item.productId)) {
        throw new Error(`Out of stock: ${item.productId}`);
      }
    }

    // 2. Reserver stock
    for (const item of order.items) {
      this.inventory.reserveStock(item.productId, item.quantity);
    }

    try {
      // 3. Paiement
      const authId = this.payment.authorize(order.total, order.card);
      this.payment.capture(authId);

      // 4. Livraison
      const shippingCost = this.shipping.calculateCost(order.address);
      const labelId = this.shipping.createLabel(order);
      this.shipping.schedulePickup(labelId);

      // 5. Notifications
      this.notification.sendEmail(
        order.customer.email,
        'order_confirmation',
        { orderId: order.id, trackingId: labelId },
      );

      return {
        success: true,
        orderId: order.id,
        trackingId: labelId,
      };
    } catch (error) {
      // Rollback
      for (const item of order.items) {
        this.inventory.releaseStock(item.productId, item.quantity);
      }
      throw error;
    }
  }

  async cancelOrder(orderId: string): Promise<void> {
    // Logique complexe simplifiee
  }

  async getOrderStatus(orderId: string): Promise<OrderStatus> {
    // Agregation de plusieurs services
    return { status: 'processing' };
  }
}
```

### Facade pour API Client

```typescript
// Sous-systemes
class AuthClient {
  async getToken(): Promise<string> { return 'token'; }
  async refreshToken(): Promise<string> { return 'new_token'; }
}

class HttpClient {
  async request(config: RequestConfig): Promise<Response> {
    return fetch(config.url, config);
  }
}

class RetryPolicy {
  async execute<T>(fn: () => Promise<T>): Promise<T> {
    // Logique de retry
    return fn();
  }
}

class CircuitBreaker {
  async execute<T>(fn: () => Promise<T>): Promise<T> {
    // Logique circuit breaker
    return fn();
  }
}

// Facade
class ApiClient {
  private auth = new AuthClient();
  private http = new HttpClient();
  private retry = new RetryPolicy();
  private circuit = new CircuitBreaker();

  async get<T>(path: string): Promise<T> {
    return this.request<T>('GET', path);
  }

  async post<T>(path: string, body: unknown): Promise<T> {
    return this.request<T>('POST', path, body);
  }

  private async request<T>(
    method: string,
    path: string,
    body?: unknown,
  ): Promise<T> {
    return this.circuit.execute(() =>
      this.retry.execute(async () => {
        const token = await this.auth.getToken();

        const response = await this.http.request({
          method,
          url: `https://api.example.com${path}`,
          headers: { Authorization: `Bearer ${token}` },
          body: body ? JSON.stringify(body) : undefined,
        });

        if (!response.ok) {
          throw new Error(`API Error: ${response.status}`);
        }

        return response.json();
      }),
    );
  }
}

// Usage simple
const api = new ApiClient();
const users = await api.get<User[]>('/users');
```

## Variantes

### Facade avec options

```typescript
interface ConverterOptions {
  quality?: 'low' | 'medium' | 'high';
  watermark?: string;
  outputDir?: string;
}

class ConfigurableVideoConverter {
  private options: Required<ConverterOptions>;

  constructor(options: ConverterOptions = {}) {
    this.options = {
      quality: options.quality ?? 'medium',
      watermark: options.watermark ?? '',
      outputDir: options.outputDir ?? './output',
    };
  }

  convert(filename: string, format: string): void {
    // Utilise this.options
  }
}
```

### Facade avec acces aux sous-systemes

```typescript
class VideoConverter {
  // Sous-systemes exposes pour cas avances
  public readonly encoder: Encoder;
  public readonly mixer: VideoMixer;

  constructor() {
    this.encoder = new Encoder();
    this.mixer = new VideoMixer();
  }

  // Methodes simplifiees pour cas courants
  convert(filename: string, format: string): void {
    // ...
  }

  // Les utilisateurs avances peuvent acceder directement
  // aux sous-systemes si necessaire
}
```

## Anti-patterns

```typescript
// MAUVAIS: Facade qui devient God Object
class GodFacade {
  // Trop de responsabilites
  createUser() {}
  processPayment() {}
  sendNotification() {}
  generateReport() {}
  backupDatabase() {}
  // ...50 autres methodes
}

// MAUVAIS: Facade qui expose trop de details
class LeakyFacade {
  getInventoryService(): InventoryService {
    return this.inventory; // Fuite d'abstraction
  }
}

// MAUVAIS: Facade sans valeur ajoutee
class UselessFacade {
  doSomething() {
    this.service.doSomething(); // Simple delegation
  }
}
```

## Tests unitaires

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('OrderFacade', () => {
  let facade: OrderFacade;
  let mockInventory: InventoryService;
  let mockPayment: PaymentService;
  let mockShipping: ShippingService;
  let mockNotification: NotificationService;

  beforeEach(() => {
    mockInventory = {
      checkStock: vi.fn().mockReturnValue(true),
      reserveStock: vi.fn(),
      releaseStock: vi.fn(),
    };
    mockPayment = {
      authorize: vi.fn().mockReturnValue('auth_123'),
      capture: vi.fn(),
      refund: vi.fn(),
    };
    mockShipping = {
      calculateCost: vi.fn().mockReturnValue(10),
      createLabel: vi.fn().mockReturnValue('SHIP_123'),
      schedulePickup: vi.fn(),
    };
    mockNotification = {
      sendEmail: vi.fn(),
      sendSMS: vi.fn(),
    };

    facade = new OrderFacade(
      mockInventory,
      mockPayment,
      mockShipping,
      mockNotification,
    );
  });

  it('should orchestrate order placement', async () => {
    const order = createTestOrder();

    const result = await facade.placeOrder(order);

    expect(result.success).toBe(true);
    expect(mockInventory.checkStock).toHaveBeenCalled();
    expect(mockPayment.authorize).toHaveBeenCalled();
    expect(mockShipping.createLabel).toHaveBeenCalled();
    expect(mockNotification.sendEmail).toHaveBeenCalled();
  });

  it('should rollback on payment failure', async () => {
    mockPayment.authorize = vi.fn().mockImplementation(() => {
      throw new Error('Payment failed');
    });

    const order = createTestOrder();

    await expect(facade.placeOrder(order)).rejects.toThrow('Payment failed');
    expect(mockInventory.releaseStock).toHaveBeenCalled();
  });

  it('should reject out of stock items', async () => {
    mockInventory.checkStock = vi.fn().mockReturnValue(false);

    const order = createTestOrder();

    await expect(facade.placeOrder(order)).rejects.toThrow('Out of stock');
    expect(mockPayment.authorize).not.toHaveBeenCalled();
  });
});

describe('VideoConverter', () => {
  it('should convert video files', () => {
    const consoleSpy = vi.spyOn(console, 'log');
    const converter = new VideoConverter();

    converter.convert('test.avi', 'mp4');

    expect(consoleSpy).toHaveBeenCalledWith('Conversion complete!');
  });
});
```

## Quand utiliser

- Simplifier l'acces a un sous-systeme complexe
- Reduire le couplage entre client et sous-systeme
- Definir des points d'entree dans les couches
- Orchestrer plusieurs services

## Patterns lies

- **Adapter** : Interface differente vs interface simplifiee
- **Mediator** : Centralise communication entre composants
- **Singleton** : Facade souvent en instance unique

## Sources

- [Refactoring Guru - Facade](https://refactoring.guru/design-patterns/facade)
