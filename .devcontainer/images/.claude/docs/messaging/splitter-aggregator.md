# Splitter-Aggregator Pattern

Diviser un message composite en parties et les recombiner.

## Vue d'ensemble

```
                    +----------+
                    | Splitter |
+------------+      |          |      +-----------+
| Composite  |----->|  Split   |----->| Message 1 |--+
| Message    |      |          |      +-----------+  |
| [A, B, C]  |      +----------+      +-----------+  |    +------------+
+------------+                   +--->| Message 2 |--+--->| Aggregator |
                                      +-----------+  |    |            |
                                      +-----------+  |    | Combine    |
                                 +--->| Message 3 |--+    +-----+------+
                                      +-----------+             |
                                                                v
                                                         +------------+
                                                         | Result     |
                                                         | [R1,R2,R3] |
                                                         +------------+
```

---

## Splitter Pattern

> Divise un message en plusieurs messages individuels.

### Schema

```
Order { items: [A, B, C] }
           |
           v
    +-----------+
    | Splitter  |
    +-----------+
     /    |    \
    v     v     v
Item A  Item B  Item C
(+ metadata correlation)
```

### Implementation

```typescript
interface SplitResult<T> {
  correlationId: string;
  sequenceNumber: number;
  sequenceSize: number;
  isLast: boolean;
  payload: T;
  originalMessageId: string;
}

class Splitter<TComposite, TPart> {
  constructor(
    private extractParts: (composite: TComposite) => TPart[],
    private enrichPart?: (part: TPart, composite: TComposite, index: number) => TPart
  ) {}

  split(message: { id: string; payload: TComposite }): SplitResult<TPart>[] {
    const parts = this.extractParts(message.payload);
    const correlationId = crypto.randomUUID();

    return parts.map((part, index) => ({
      correlationId,
      sequenceNumber: index,
      sequenceSize: parts.length,
      isLast: index === parts.length - 1,
      originalMessageId: message.id,
      payload: this.enrichPart
        ? this.enrichPart(part, message.payload, index)
        : part,
    }));
  }
}

// Exemple: Splitter de commande
interface Order {
  orderId: string;
  customerId: string;
  items: OrderItem[];
  shippingAddress: Address;
}

interface OrderItemMessage {
  orderId: string;
  customerId: string;
  item: OrderItem;
  shippingAddress: Address;
}

const orderSplitter = new Splitter<Order, OrderItemMessage>(
  (order) => order.items.map(item => ({
    orderId: order.orderId,
    customerId: order.customerId,
    item,
    shippingAddress: order.shippingAddress,
  }))
);

// Usage avec RabbitMQ
async function splitAndPublish(order: Order): Promise<void> {
  const splitMessages = orderSplitter.split({ id: order.orderId, payload: order });

  for (const msg of splitMessages) {
    await channel.publish('order-items', '', Buffer.from(JSON.stringify(msg)), {
      headers: {
        'x-correlation-id': msg.correlationId,
        'x-sequence-number': msg.sequenceNumber,
        'x-sequence-size': msg.sequenceSize,
      }
    });
  }
}
```

**Quand :** Traitement parallele, distribution de charge, batch processing.
**Lie a :** Aggregator, Scatter-Gather.

---

## Aggregator Pattern

> Combine plusieurs messages relies en un seul.

### Schema

```
Result A --+
           |    +------------+
Result B --+--->| Aggregator |---> Combined Result
           |    +------------+
Result C --+         |
                     v
              Completion Strategy:
              - All received?
              - Timeout?
              - First N?
```

### Implementation

```typescript
interface AggregationContext<T, R> {
  correlationId: string;
  expectedCount: number;
  receivedParts: T[];
  startedAt: Date;
  timeoutMs: number;
}

type CompletionStrategy<T> = (context: AggregationContext<T, unknown>) => boolean;
type AggregationFunction<T, R> = (parts: T[]) => R;

class Aggregator<TPart, TResult> {
  private contexts = new Map<string, AggregationContext<TPart, TResult>>();

  constructor(
    private completionStrategy: CompletionStrategy<TPart>,
    private aggregateFn: AggregationFunction<TPart, TResult>,
    private defaultTimeout: number = 30000
  ) {
    // Cleanup des aggregations expirees
    setInterval(() => this.cleanupExpired(), 5000);
  }

  add(message: SplitResult<TPart>): TResult | null {
    const { correlationId, sequenceSize, payload } = message;

    if (!this.contexts.has(correlationId)) {
      this.contexts.set(correlationId, {
        correlationId,
        expectedCount: sequenceSize,
        receivedParts: [],
        startedAt: new Date(),
        timeoutMs: this.defaultTimeout,
      });
    }

    const context = this.contexts.get(correlationId)!;
    context.receivedParts.push(payload);

    if (this.completionStrategy(context)) {
      this.contexts.delete(correlationId);
      return this.aggregateFn(context.receivedParts);
    }

    return null;
  }

  private cleanupExpired(): void {
    const now = Date.now();
    for (const [id, context] of this.contexts) {
      if (now - context.startedAt.getTime() > context.timeoutMs) {
        this.handleTimeout(context);
        this.contexts.delete(id);
      }
    }
  }

  private handleTimeout(context: AggregationContext<TPart, TResult>): void {
    console.error(`Aggregation timeout: ${context.correlationId}`, {
      received: context.receivedParts.length,
      expected: context.expectedCount,
    });
  }
}

// Strategies de completion
const allReceivedStrategy: CompletionStrategy<unknown> = (ctx) =>
  ctx.receivedParts.length >= ctx.expectedCount;

const majorityStrategy: CompletionStrategy<unknown> = (ctx) =>
  ctx.receivedParts.length > ctx.expectedCount / 2;

const timeoutOrAllStrategy = (timeoutMs: number): CompletionStrategy<unknown> => (ctx) =>
  ctx.receivedParts.length >= ctx.expectedCount ||
  Date.now() - ctx.startedAt.getTime() > timeoutMs;
```

### Exemple complet

```typescript
// Aggregation des resultats de traitement d'items
interface ItemProcessingResult {
  itemId: string;
  success: boolean;
  warehouseLocation?: string;
  error?: string;
}

interface OrderProcessingResult {
  orderId: string;
  allSuccessful: boolean;
  itemResults: ItemProcessingResult[];
  processedAt: Date;
}

const orderResultAggregator = new Aggregator<
  SplitResult<ItemProcessingResult>,
  OrderProcessingResult
>(
  allReceivedStrategy,
  (parts) => {
    const results = parts.map(p => p.payload);
    return {
      orderId: parts[0].payload.orderId,
      allSuccessful: results.every(r => r.success),
      itemResults: results,
      processedAt: new Date(),
    };
  }
);

// Consumer
async function consumeItemResults(): Promise<void> {
  channel.consume('item-results', async (msg) => {
    const result = JSON.parse(msg.content.toString());
    const aggregated = orderResultAggregator.add(result);

    if (aggregated) {
      // Ordre complet, publier le resultat
      await channel.publish('order-results', '',
        Buffer.from(JSON.stringify(aggregated))
      );
    }

    channel.ack(msg);
  });
}
```

**Quand :** Apres Splitter, collecter reponses, batch results.
**Lie a :** Splitter, Scatter-Gather.

---

## Cas d'erreur

```typescript
class ResilientAggregator<T, R> extends Aggregator<T, R> {
  private deadLetterQueue: MessageQueue;

  protected handleTimeout(context: AggregationContext<T, R>): void {
    // Option 1: Agreger avec ce qu'on a
    if (context.receivedParts.length > 0) {
      const partialResult = this.aggregateFn(context.receivedParts);
      this.publishPartialResult(partialResult, context);
    }

    // Option 2: Envoyer en dead letter
    this.deadLetterQueue.send({
      type: 'aggregation_timeout',
      correlationId: context.correlationId,
      received: context.receivedParts.length,
      expected: context.expectedCount,
      partialData: context.receivedParts,
    });
  }

  protected handleDuplicate(message: SplitResult<T>): void {
    console.warn(`Duplicate message received: ${message.correlationId}:${message.sequenceNumber}`);
    // Ignorer le duplicate - idempotence
  }
}
```

---

## Tableau de decision

| Scenario | Pattern | Strategie |
|----------|---------|-----------|
| Batch processing | Splitter | Par item |
| Collect all results | Aggregator | Wait all |
| Partial results OK | Aggregator | Timeout |
| Best effort | Aggregator | Majority |

---

## Patterns complementaires

- **Scatter-Gather** - Splitter + Aggregator combines
- **Composed Message Processor** - Transformation en pipeline
- **Correlation Identifier** - Lier les parties
- **Resequencer** - Reordonner les messages
