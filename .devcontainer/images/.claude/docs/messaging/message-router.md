# Message Router Patterns

Patterns de routage dynamique des messages.

## Vue d'ensemble

```
                    +-------------------+
                    |   MESSAGE ROUTER  |
                    |                   |
Message In -------->|  [Route Logic]    |
                    |                   |
                    +---+-------+-------+
                        |       |       |
                        v       v       v
                    Queue A  Queue B  Queue C
```

---

## Content-Based Router

> Route les messages selon leur contenu.

### Schema

```
             +------------------------+
             |  Content-Based Router  |
Message ---->|                        |
             |  if type == "order"    |---> Order Queue
             |  if type == "payment"  |---> Payment Queue
             |  if type == "shipping" |---> Shipping Queue
             +------------------------+
```

### Implementation

```typescript
type RoutingRule<T> = {
  predicate: (msg: T) => boolean;
  destination: string;
};

class ContentBasedRouter<T> {
  private rules: RoutingRule<T>[] = [];
  private defaultDestination: string;

  constructor(defaultDest: string) {
    this.defaultDestination = defaultDest;
  }

  addRule(predicate: (msg: T) => boolean, destination: string): this {
    this.rules.push({ predicate, destination });
    return this;
  }

  route(message: T): string {
    for (const rule of this.rules) {
      if (rule.predicate(message)) {
        return rule.destination;
      }
    }
    return this.defaultDestination;
  }
}

// Usage avec RabbitMQ
class OrderRouter {
  private router = new ContentBasedRouter<Order>('default-queue')
    .addRule(
      (order) => order.priority === 'urgent' && order.total > 10000,
      'vip-express-queue'
    )
    .addRule(
      (order) => order.priority === 'urgent',
      'express-queue'
    )
    .addRule(
      (order) => order.type === 'subscription',
      'subscription-queue'
    )
    .addRule(
      (order) => order.region === 'EU',
      'eu-orders-queue'
    );

  async routeOrder(order: Order): Promise<void> {
    const destination = this.router.route(order);
    await this.channel.sendToQueue(destination, order);
  }
}
```

### Avec Kafka Headers

```typescript
class KafkaContentRouter {
  async route(message: OrderMessage): Promise<void> {
    const topic = this.determineTopicByContent(message);

    await this.producer.send({
      topic,
      messages: [{
        key: message.orderId,
        value: JSON.stringify(message),
        headers: {
          'x-routed-by': 'content-router',
          'x-original-type': message.type
        }
      }]
    });
  }

  private determineTopicByContent(msg: OrderMessage): string {
    if (msg.items.some(i => i.requiresColdChain)) {
      return 'orders-cold-chain';
    }
    if (msg.isInternational) {
      return 'orders-international';
    }
    return 'orders-domestic';
  }
}
```

**Quand :** Routage par regles metier, segregation de charge.
**Lie a :** Message Filter, Recipient List.

---

## Dynamic Router

> Destination determinee au runtime depuis une source externe.

### Schema

```
             +-------------------+     +----------------+
             |  Dynamic Router   |<--->| Routing Config |
Message ---->|                   |     | (DB/Service)   |
             +--------+----------+     +----------------+
                      |
         +------------+------------+
         v            v            v
      Dest A       Dest B       Dest C
```

### Implementation

```typescript
interface RoutingConfig {
  getDestination(messageType: string, context: Record<string, unknown>): Promise<string>;
}

class DatabaseRoutingConfig implements RoutingConfig {
  async getDestination(messageType: string, context: Record<string, unknown>): Promise<string> {
    const rule = await this.db.query(
      `SELECT destination FROM routing_rules
       WHERE message_type = $1 AND is_active = true
       ORDER BY priority DESC LIMIT 1`,
      [messageType]
    );
    return rule?.destination ?? 'default-queue';
  }
}

class DynamicRouter {
  constructor(private config: RoutingConfig) {}

  async route<T extends { type: string }>(message: T): Promise<void> {
    const context = this.extractContext(message);
    const destination = await this.config.getDestination(message.type, context);

    await this.channel.send(destination, message);

    // Metrics pour monitoring
    this.metrics.increment('messages_routed', {
      type: message.type,
      destination
    });
  }

  private extractContext(message: unknown): Record<string, unknown> {
    return {
      timestamp: new Date(),
      source: message['source'],
      priority: message['priority']
    };
  }
}

// Hot-reload des regles
class HotReloadableRouter extends DynamicRouter {
  private cache = new Map<string, string>();
  private cacheExpiry = 60_000; // 1 minute

  async getDestinationCached(type: string, context: Record<string, unknown>): Promise<string> {
    const cacheKey = `${type}:${JSON.stringify(context)}`;

    if (!this.cache.has(cacheKey)) {
      const dest = await this.config.getDestination(type, context);
      this.cache.set(cacheKey, dest);
      setTimeout(() => this.cache.delete(cacheKey), this.cacheExpiry);
    }

    return this.cache.get(cacheKey)!;
  }
}
```

**Quand :** Regles changeantes, A/B testing, feature flags.
**Lie a :** Content-Based Router.

---

## Recipient List

> Envoie le message a une liste dynamique de destinataires.

### Schema

```
             +------------------+
             |  Recipient List  |
Message ---->|                  |
             |  Recipients:     |
             |  - Service A     |---> Service A
             |  - Service B     |---> Service B
             |  - Service C     |---> Service C
             +------------------+
```

### Implementation

```typescript
type RecipientResolver<T> = (message: T) => string[];

class RecipientList<T> {
  constructor(
    private resolver: RecipientResolver<T>,
    private channel: MessageChannel
  ) {}

  async distribute(message: T): Promise<DistributionResult> {
    const recipients = this.resolver(message);
    const results: { recipient: string; success: boolean; error?: Error }[] = [];

    await Promise.all(
      recipients.map(async (recipient) => {
        try {
          await this.channel.send(recipient, message);
          results.push({ recipient, success: true });
        } catch (error) {
          results.push({ recipient, success: false, error: error as Error });
        }
      })
    );

    return {
      total: recipients.length,
      successful: results.filter(r => r.success).length,
      failed: results.filter(r => !r.success),
    };
  }
}

// Resolver dynamique base sur le message
const orderRecipientResolver: RecipientResolver<Order> = (order) => {
  const recipients: string[] = ['order-service'];

  if (order.requiresPayment) {
    recipients.push('payment-service');
  }
  if (order.items.length > 0) {
    recipients.push('inventory-service');
  }
  if (order.shippingRequired) {
    recipients.push('shipping-service');
  }
  if (order.total > 1000) {
    recipients.push('fraud-detection-service');
  }

  return recipients;
};

// Usage
const recipientList = new RecipientList(orderRecipientResolver, channel);
const result = await recipientList.distribute(order);

if (result.failed.length > 0) {
  await alertService.notify('Distribution failures', result.failed);
}
```

### Avec garantie de livraison

```typescript
class GuaranteedRecipientList<T> {
  async distributeWithRetry(message: T, maxRetries = 3): Promise<void> {
    const recipients = this.resolver(message);
    const pending = new Set(recipients);
    let attempt = 0;

    while (pending.size > 0 && attempt < maxRetries) {
      const results = await Promise.allSettled(
        [...pending].map(r => this.channel.send(r, message))
      );

      results.forEach((result, index) => {
        if (result.status === 'fulfilled') {
          pending.delete([...pending][index]);
        }
      });

      if (pending.size > 0) {
        attempt++;
        await this.delay(Math.pow(2, attempt) * 1000);
      }
    }

    if (pending.size > 0) {
      throw new PartialDeliveryError([...pending]);
    }
  }
}
```

**Quand :** Multicast, notifications multiples, fan-out.
**Lie a :** Publish-Subscribe, Scatter-Gather.

---

## Cas d'erreur communs

```typescript
class ResilientRouter {
  async routeWithFallback<T>(message: T): Promise<void> {
    try {
      const destination = await this.dynamicRouter.getDestination(message);
      await this.channel.send(destination, message);
    } catch (error) {
      if (error instanceof RoutingConfigError) {
        // Fallback sur routage statique
        const fallbackDest = this.staticRouter.route(message);
        await this.channel.send(fallbackDest, message);
      } else if (error instanceof DestinationUnavailableError) {
        // Queue de parking
        await this.parkingQueue.send(message);
      } else {
        await this.deadLetterQueue.send(message, error);
      }
    }
  }
}
```

---

## Tableau de decision

| Pattern | Cas d'usage | Flexibilite | Complexite |
|---------|-------------|-------------|------------|
| Content-Based | Regles fixes | Moyenne | Basse |
| Dynamic | Regles changeantes | Haute | Moyenne |
| Recipient List | Multi-dest | Haute | Moyenne |

---

## Patterns complementaires

- **Message Filter** - Filtrer avant routage
- **Scatter-Gather** - Router puis collecter
- **Process Manager** - Orchestrer le routage
- **Dead Letter Channel** - Gerer echecs de routage
