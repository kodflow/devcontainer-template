# Gateway

> "An object that encapsulates access to an external system or resource." - Martin Fowler, PoEAA

## Concept

Le Gateway est un objet qui encapsule l'acces a un systeme externe ou une ressource. Il fournit une API simple et coherente pour interagir avec des services tiers, des bases de donnees, ou des systemes legacy.

## Types de Gateways

1. **Table Data Gateway** : Acces a une table de base de donnees
2. **Row Data Gateway** : Acces a une ligne de base de donnees
3. **Service Gateway** : Acces a un service externe
4. **Messaging Gateway** : Acces a un systeme de messaging

## Service Gateway - Implementation TypeScript

```typescript
// Interface Gateway - Abstraction du service externe
interface PaymentGateway {
  charge(amount: Money, paymentMethod: PaymentMethod): Promise<PaymentResult>;
  refund(transactionId: string, amount?: Money): Promise<RefundResult>;
  getTransaction(transactionId: string): Promise<Transaction>;
}

// Implementation concrete - Stripe
class StripePaymentGateway implements PaymentGateway {
  private client: Stripe;

  constructor(apiKey: string) {
    this.client = new Stripe(apiKey, { apiVersion: '2023-10-16' });
  }

  async charge(amount: Money, paymentMethod: PaymentMethod): Promise<PaymentResult> {
    try {
      const paymentIntent = await this.client.paymentIntents.create({
        amount: amount.toCents(),
        currency: amount.currency.toLowerCase(),
        payment_method: paymentMethod.token,
        confirm: true,
        return_url: 'https://example.com/return',
      });

      return {
        success: paymentIntent.status === 'succeeded',
        transactionId: paymentIntent.id,
        status: this.mapStatus(paymentIntent.status),
        raw: paymentIntent,
      };
    } catch (error) {
      if (error instanceof Stripe.errors.StripeCardError) {
        return {
          success: false,
          error: error.message,
          code: error.code,
        };
      }
      throw new PaymentGatewayError('Stripe charge failed', error);
    }
  }

  async refund(transactionId: string, amount?: Money): Promise<RefundResult> {
    try {
      const refund = await this.client.refunds.create({
        payment_intent: transactionId,
        amount: amount?.toCents(),
      });

      return {
        success: refund.status === 'succeeded',
        refundId: refund.id,
        amount: Money.fromCents(refund.amount, refund.currency),
      };
    } catch (error) {
      throw new PaymentGatewayError('Stripe refund failed', error);
    }
  }

  async getTransaction(transactionId: string): Promise<Transaction> {
    const intent = await this.client.paymentIntents.retrieve(transactionId);
    return this.mapToTransaction(intent);
  }

  private mapStatus(stripeStatus: string): PaymentStatus {
    const mapping: Record<string, PaymentStatus> = {
      succeeded: PaymentStatus.Completed,
      processing: PaymentStatus.Pending,
      requires_action: PaymentStatus.RequiresAction,
      canceled: PaymentStatus.Cancelled,
    };
    return mapping[stripeStatus] || PaymentStatus.Unknown;
  }

  private mapToTransaction(intent: Stripe.PaymentIntent): Transaction {
    return {
      id: intent.id,
      amount: Money.fromCents(intent.amount, intent.currency),
      status: this.mapStatus(intent.status),
      createdAt: new Date(intent.created * 1000),
      metadata: intent.metadata,
    };
  }
}

// Implementation alternative - PayPal
class PayPalPaymentGateway implements PaymentGateway {
  private client: PayPalClient;

  constructor(clientId: string, clientSecret: string, sandbox: boolean) {
    this.client = new PayPalClient(clientId, clientSecret, sandbox);
  }

  async charge(amount: Money, paymentMethod: PaymentMethod): Promise<PaymentResult> {
    const order = await this.client.orders.create({
      intent: 'CAPTURE',
      purchase_units: [
        {
          amount: {
            currency_code: amount.currency,
            value: amount.toString(),
          },
        },
      ],
    });

    const capture = await this.client.orders.capture(order.id);

    return {
      success: capture.status === 'COMPLETED',
      transactionId: capture.id,
      status: this.mapStatus(capture.status),
    };
  }

  // ... autres methodes
}
```

## Gateway avec Resilience

```typescript
// Gateway avec Circuit Breaker et Retry
class ResilientPaymentGateway implements PaymentGateway {
  private circuitBreaker: CircuitBreaker;
  private retryPolicy: RetryPolicy;

  constructor(
    private readonly innerGateway: PaymentGateway,
    options: ResilienceOptions = {},
  ) {
    this.circuitBreaker = new CircuitBreaker({
      failureThreshold: options.failureThreshold || 5,
      resetTimeout: options.resetTimeout || 30000,
    });

    this.retryPolicy = new RetryPolicy({
      maxRetries: options.maxRetries || 3,
      backoff: 'exponential',
      retryableErrors: [NetworkError, TimeoutError],
    });
  }

  async charge(amount: Money, paymentMethod: PaymentMethod): Promise<PaymentResult> {
    return this.circuitBreaker.execute(async () => {
      return this.retryPolicy.execute(async () => {
        return this.innerGateway.charge(amount, paymentMethod);
      });
    });
  }

  async refund(transactionId: string, amount?: Money): Promise<RefundResult> {
    return this.circuitBreaker.execute(async () => {
      return this.retryPolicy.execute(async () => {
        return this.innerGateway.refund(transactionId, amount);
      });
    });
  }

  async getTransaction(transactionId: string): Promise<Transaction> {
    return this.circuitBreaker.execute(async () => {
      return this.innerGateway.getTransaction(transactionId);
    });
  }

  getCircuitState(): CircuitState {
    return this.circuitBreaker.getState();
  }
}
```

## Messaging Gateway

```typescript
// Interface Messaging Gateway
interface MessagingGateway {
  publish<T>(topic: string, message: T): Promise<void>;
  subscribe<T>(topic: string, handler: (message: T) => Promise<void>): Promise<void>;
  unsubscribe(topic: string): Promise<void>;
}

// Implementation Kafka
class KafkaMessagingGateway implements MessagingGateway {
  private producer: KafkaProducer;
  private consumer: KafkaConsumer;
  private subscriptions = new Map<string, KafkaConsumer>();

  constructor(brokers: string[], clientId: string) {
    const kafka = new Kafka({ brokers, clientId });
    this.producer = kafka.producer();
    this.consumer = kafka.consumer({ groupId: `${clientId}-group` });
  }

  async connect(): Promise<void> {
    await this.producer.connect();
    await this.consumer.connect();
  }

  async publish<T>(topic: string, message: T): Promise<void> {
    await this.producer.send({
      topic,
      messages: [
        {
          key: message.id || crypto.randomUUID(),
          value: JSON.stringify(message),
          timestamp: Date.now().toString(),
        },
      ],
    });
  }

  async subscribe<T>(
    topic: string,
    handler: (message: T) => Promise<void>,
  ): Promise<void> {
    await this.consumer.subscribe({ topic, fromBeginning: false });

    await this.consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        const parsed = JSON.parse(message.value!.toString()) as T;
        await handler(parsed);
      },
    });
  }

  async unsubscribe(topic: string): Promise<void> {
    // Implementation specifique Kafka
  }

  async disconnect(): Promise<void> {
    await this.producer.disconnect();
    await this.consumer.disconnect();
  }
}

// Implementation RabbitMQ
class RabbitMQMessagingGateway implements MessagingGateway {
  private connection: Connection;
  private channel: Channel;

  constructor(private readonly url: string) {}

  async connect(): Promise<void> {
    this.connection = await amqp.connect(this.url);
    this.channel = await this.connection.createChannel();
  }

  async publish<T>(exchange: string, message: T): Promise<void> {
    await this.channel.assertExchange(exchange, 'topic', { durable: true });
    this.channel.publish(
      exchange,
      '',
      Buffer.from(JSON.stringify(message)),
      { persistent: true },
    );
  }

  // ... autres methodes
}
```

## HTTP Gateway

```typescript
// Gateway pour API externe
interface WeatherGateway {
  getCurrentWeather(city: string): Promise<Weather>;
  getForecast(city: string, days: number): Promise<Forecast>;
}

class OpenWeatherGateway implements WeatherGateway {
  private httpClient: HttpClient;
  private cache: Cache;

  constructor(
    private readonly apiKey: string,
    private readonly baseUrl: string = 'https://api.openweathermap.org/data/2.5',
  ) {
    this.httpClient = new HttpClient({
      timeout: 5000,
      retries: 3,
    });
    this.cache = new Cache({ ttl: 600 }); // 10 min
  }

  async getCurrentWeather(city: string): Promise<Weather> {
    const cacheKey = `weather:${city}`;
    const cached = await this.cache.get<Weather>(cacheKey);
    if (cached) return cached;

    const response = await this.httpClient.get<OpenWeatherResponse>(
      `${this.baseUrl}/weather`,
      {
        params: {
          q: city,
          appid: this.apiKey,
          units: 'metric',
        },
      },
    );

    const weather = this.mapToWeather(response);
    await this.cache.set(cacheKey, weather);
    return weather;
  }

  async getForecast(city: string, days: number): Promise<Forecast> {
    const response = await this.httpClient.get<OpenWeatherForecastResponse>(
      `${this.baseUrl}/forecast`,
      {
        params: {
          q: city,
          appid: this.apiKey,
          units: 'metric',
          cnt: days * 8, // 3h intervals
        },
      },
    );

    return this.mapToForecast(response);
  }

  private mapToWeather(response: OpenWeatherResponse): Weather {
    return {
      temperature: response.main.temp,
      humidity: response.main.humidity,
      description: response.weather[0].description,
      windSpeed: response.wind.speed,
      timestamp: new Date(),
    };
  }
}
```

## Comparaison avec alternatives

| Aspect | Gateway | Adapter | Facade |
|--------|---------|---------|--------|
| Objectif | Acces externe | Compatibilite | Simplification |
| Direction | Sortant | Bidirectionnel | Interne |
| Abstraction | Systeme externe | Interface | Sous-systeme |
| Testabilite | Mockable | Mockable | Moins important |

## Quand utiliser

**Utiliser Gateway quand :**

- Integration avec services externes
- Besoin d'abstraction des details techniques
- Multiples implementations possibles (Stripe/PayPal)
- Testabilite importante (mocking)
- Resilience requise (retry, circuit breaker)

**Eviter Gateway quand :**

- Acces simple et direct suffit
- Un seul service externe sans changement prevu
- Performance ultra-critique (overhead)

## Relation avec DDD

Le Gateway vit dans l'**Infrastructure Layer** et implemente une interface du domaine :

```
┌─────────────────────────────────────────────┐
│              Domain Layer                   │
│   - Interface PaymentGateway (Port)         │
├─────────────────────────────────────────────┤
│          Infrastructure Layer               │
│   - StripePaymentGateway (Adapter)          │
│   - PayPalPaymentGateway (Adapter)          │
└─────────────────────────────────────────────┘
```

C'est le pattern **Ports & Adapters** (Hexagonal Architecture).

## Patterns associes

- **Adapter** : Convertit interfaces incompatibles
- **Facade** : Simplifie l'acces (interne)
- **Proxy** : Controle l'acces
- **Anti-Corruption Layer** : Isole du legacy
- **Circuit Breaker** : Resilience

## Sources

- Martin Fowler, PoEAA, Chapter 18
- [Gateway - martinfowler.com](https://martinfowler.com/eaaCatalog/gateway.html)
