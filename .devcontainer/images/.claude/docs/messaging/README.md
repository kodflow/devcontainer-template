# Messaging Patterns (EIP)

Enterprise Integration Patterns - Gregor Hohpe & Bobby Woolf.

## Message Construction

### 1. Command Message

> Message qui demande une action.

```typescript
interface CommandMessage<T = unknown> {
  type: 'command';
  command: string;
  payload: T;
  correlationId: string;
  replyTo?: string;
}

// Usage
const command: CommandMessage<CreateOrderPayload> = {
  type: 'command',
  command: 'CreateOrder',
  payload: { customerId: '123', items: [...] },
  correlationId: crypto.randomUUID(),
  replyTo: 'order-responses',
};

await messageBus.send('orders', command);
```

**Quand :** Déclencher des actions, CQRS commands.
**Lié à :** Document Message, Event Message.

---

### 2. Event Message

> Notification d'un fait passé.

```typescript
interface EventMessage<T = unknown> {
  type: 'event';
  event: string;
  payload: T;
  timestamp: Date;
  aggregateId: string;
  version: number;
}

const event: EventMessage<OrderCreatedPayload> = {
  type: 'event',
  event: 'OrderCreated',
  payload: { orderId: '456', total: 99.99 },
  timestamp: new Date(),
  aggregateId: '456',
  version: 1,
};

await eventBus.publish('order-events', event);
```

**Quand :** Event sourcing, notifications, découplage.
**Lié à :** Command Message, Observer.

---

### 3. Document Message

> Message contenant des données.

```typescript
interface DocumentMessage<T = unknown> {
  type: 'document';
  documentType: string;
  content: T;
  metadata: {
    source: string;
    timestamp: Date;
    version: string;
  };
}

const doc: DocumentMessage<CustomerData> = {
  type: 'document',
  documentType: 'CustomerProfile',
  content: {
    id: '123',
    name: 'John Doe',
    email: 'john@example.com',
  },
  metadata: {
    source: 'crm-system',
    timestamp: new Date(),
    version: '1.0',
  },
};
```

**Quand :** Transfert de données, synchronisation.
**Lié à :** Command Message.

---

### 4. Request-Reply

> Message avec attente de réponse.

```typescript
class RequestReplyClient {
  private pending = new Map<string, Deferred<any>>();

  constructor(private channel: MessageChannel) {
    this.channel.subscribe('replies', (msg) => {
      const deferred = this.pending.get(msg.correlationId);
      if (deferred) {
        deferred.resolve(msg.payload);
        this.pending.delete(msg.correlationId);
      }
    });
  }

  async request<T, R>(destination: string, payload: T): Promise<R> {
    const correlationId = crypto.randomUUID();
    const deferred = new Deferred<R>();
    this.pending.set(correlationId, deferred);

    await this.channel.send(destination, {
      payload,
      correlationId,
      replyTo: 'replies',
    });

    return deferred.promise;
  }
}

// Usage
const result = await client.request('calculator', { operation: 'add', a: 1, b: 2 });
```

**Quand :** RPC over messaging, queries.
**Lié à :** Correlation Identifier.

---

### 5. Correlation Identifier

> Lier requête et réponse.

```typescript
interface CorrelatedMessage {
  correlationId: string;
  causationId?: string; // ID du message qui a causé celui-ci
}

class MessageTracker {
  private correlations = new Map<string, Message[]>();

  track(message: CorrelatedMessage) {
    if (!this.correlations.has(message.correlationId)) {
      this.correlations.set(message.correlationId, []);
    }
    this.correlations.get(message.correlationId)!.push(message);
  }

  getConversation(correlationId: string): Message[] {
    return this.correlations.get(correlationId) || [];
  }
}
```

**Quand :** Suivi de transactions, debugging distribué.
**Lié à :** Request-Reply.

---

### 6. Message Sequence

> Ensemble de messages ordonnés.

```typescript
interface SequencedMessage {
  sequenceId: string;
  sequenceNumber: number;
  sequenceSize: number;
  isLast: boolean;
  payload: Buffer;
}

class SequenceAssembler {
  private buffers = new Map<string, Map<number, Buffer>>();

  add(msg: SequencedMessage): Buffer | null {
    if (!this.buffers.has(msg.sequenceId)) {
      this.buffers.set(msg.sequenceId, new Map());
    }

    this.buffers.get(msg.sequenceId)!.set(msg.sequenceNumber, msg.payload);

    if (msg.isLast) {
      const parts = this.buffers.get(msg.sequenceId)!;
      if (parts.size === msg.sequenceSize) {
        const sorted = [...parts.entries()].sort((a, b) => a[0] - b[0]);
        this.buffers.delete(msg.sequenceId);
        return Buffer.concat(sorted.map((p) => p[1]));
      }
    }

    return null;
  }
}
```

**Quand :** Gros messages, streaming.
**Lié à :** Splitter, Aggregator.

---

### 7. Message Expiration

> TTL sur les messages.

```typescript
interface ExpirableMessage {
  expiresAt: Date;
  payload: unknown;
}

class ExpirationFilter {
  filter(message: ExpirableMessage): boolean {
    return new Date() < message.expiresAt;
  }
}

// Dead Letter Queue for expired messages
class MessageProcessor {
  constructor(
    private handler: (msg: any) => Promise<void>,
    private deadLetterQueue: MessageQueue,
  ) {}

  async process(msg: ExpirableMessage) {
    if (new Date() >= msg.expiresAt) {
      await this.deadLetterQueue.send({
        original: msg,
        reason: 'expired',
        expiredAt: new Date(),
      });
      return;
    }
    await this.handler(msg);
  }
}
```

**Quand :** Timeouts, données périssables.
**Lié à :** Dead Letter Channel.

---

## Message Routing

### 8. Content-Based Router

> Router selon le contenu du message.

```typescript
class ContentBasedRouter {
  private routes = new Map<string, string>();

  addRoute(predicate: (msg: any) => boolean, destination: string) {
    // Implementation with predicates
  }

  route(message: any): string {
    // Route by message type
    switch (message.type) {
      case 'order':
        return message.priority === 'high' ? 'express-queue' : 'standard-queue';
      case 'return':
        return 'returns-queue';
      default:
        return 'default-queue';
    }
  }
}

// Usage
const router = new ContentBasedRouter();
const destination = router.route(message);
await messageBus.send(destination, message);
```

**Quand :** Routing dynamique, règles métier.
**Lié à :** Message Filter, Recipient List.

---

### 9. Message Filter

> Supprimer les messages non désirés.

```typescript
type Predicate<T> = (message: T) => boolean;

class MessageFilter<T> {
  constructor(private predicate: Predicate<T>) {}

  filter(messages: T[]): T[] {
    return messages.filter(this.predicate);
  }

  async* filterStream(stream: AsyncIterable<T>): AsyncGenerator<T> {
    for await (const message of stream) {
      if (this.predicate(message)) {
        yield message;
      }
    }
  }
}

// Usage
const validOrderFilter = new MessageFilter<Order>(
  (order) => order.items.length > 0 && order.total > 0,
);
```

**Quand :** Validation, nettoyage, sécurité.
**Lié à :** Content-Based Router.

---

### 10. Recipient List

> Envoyer à plusieurs destinataires.

```typescript
class RecipientList {
  constructor(private destinations: string[]) {}

  async send(message: any, channel: MessageChannel) {
    await Promise.all(
      this.destinations.map((dest) => channel.send(dest, message)),
    );
  }

  // Dynamic recipient list based on message
  static fromMessage(message: any): RecipientList {
    const destinations: string[] = [];

    if (message.requiresInventory) {
      destinations.push('inventory-service');
    }
    if (message.requiresPayment) {
      destinations.push('payment-service');
    }
    if (message.requiresShipping) {
      destinations.push('shipping-service');
    }

    return new RecipientList(destinations);
  }
}
```

**Quand :** Multicast, notifications multiples.
**Lié à :** Publish-Subscribe.

---

### 11. Splitter

> Diviser un message en plusieurs.

```typescript
class OrderSplitter {
  split(order: Order): OrderItemMessage[] {
    return order.items.map((item, index) => ({
      originalOrderId: order.id,
      sequenceNumber: index,
      totalItems: order.items.length,
      item,
      customer: order.customer,
    }));
  }
}

// Generic splitter
class Splitter<T, U> {
  constructor(private splitFn: (message: T) => U[]) {}

  split(message: T): U[] {
    return this.splitFn(message);
  }
}
```

**Quand :** Traitement parallèle, distribution.
**Lié à :** Aggregator.

---

### 12. Aggregator

> Combiner plusieurs messages en un.

```typescript
class Aggregator<T, R> {
  private buffers = new Map<string, { items: T[]; expectedCount: number }>();

  constructor(
    private correlationFn: (msg: T) => string,
    private completionFn: (msgs: T[]) => boolean,
    private aggregateFn: (msgs: T[]) => R,
  ) {}

  add(message: T): R | null {
    const correlationId = this.correlationFn(message);

    if (!this.buffers.has(correlationId)) {
      this.buffers.set(correlationId, { items: [], expectedCount: 0 });
    }

    const buffer = this.buffers.get(correlationId)!;
    buffer.items.push(message);

    if (this.completionFn(buffer.items)) {
      this.buffers.delete(correlationId);
      return this.aggregateFn(buffer.items);
    }

    return null;
  }
}

// Usage
const orderAggregator = new Aggregator<OrderItemResult, OrderResult>(
  (msg) => msg.originalOrderId,
  (msgs) => msgs.length === msgs[0].totalItems,
  (msgs) => ({
    orderId: msgs[0].originalOrderId,
    results: msgs.map((m) => m.result),
  }),
);
```

**Quand :** Après Splitter, attente réponses multiples.
**Lié à :** Splitter, Scatter-Gather.

---

### 13. Scatter-Gather

> Envoyer et collecter les réponses.

```typescript
class ScatterGather<T, R> {
  constructor(
    private destinations: string[],
    private timeout: number,
  ) {}

  async scatter(message: T): Promise<R[]> {
    const correlationId = crypto.randomUUID();
    const responses: R[] = [];
    const responsePromises: Promise<R>[] = [];

    for (const dest of this.destinations) {
      responsePromises.push(
        this.sendAndWait(dest, message, correlationId),
      );
    }

    const results = await Promise.allSettled(responsePromises);

    return results
      .filter((r): r is PromiseFulfilledResult<R> => r.status === 'fulfilled')
      .map((r) => r.value);
  }

  private async sendAndWait(dest: string, msg: T, correlationId: string): Promise<R> {
    // Implementation with timeout
    return Promise.race([
      this.channel.request(dest, msg, correlationId),
      this.timeoutPromise(),
    ]);
  }
}

// Usage - Price comparison
const priceChecker = new ScatterGather<Product, PriceQuote>(
  ['supplier-a', 'supplier-b', 'supplier-c'],
  5000,
);
const quotes = await priceChecker.scatter(product);
const bestPrice = quotes.reduce((min, q) => q.price < min.price ? q : min);
```

**Quand :** Comparaison, best-of, quorum.
**Lié à :** Recipient List, Aggregator.

---

### 14. Routing Slip

> Itinéraire dynamique pour le message.

```typescript
interface RoutingSlip {
  steps: string[];
  currentStep: number;
  history: { step: string; timestamp: Date; result: any }[];
}

interface RoutedMessage {
  payload: any;
  routingSlip: RoutingSlip;
}

class RoutingSlipProcessor {
  async process(message: RoutedMessage) {
    const { routingSlip } = message;

    if (routingSlip.currentStep >= routingSlip.steps.length) {
      return message; // Complete
    }

    const currentStep = routingSlip.steps[routingSlip.currentStep];
    const result = await this.executeStep(currentStep, message.payload);

    routingSlip.history.push({
      step: currentStep,
      timestamp: new Date(),
      result,
    });
    routingSlip.currentStep++;

    // Forward to next processor or return
    if (routingSlip.currentStep < routingSlip.steps.length) {
      const nextStep = routingSlip.steps[routingSlip.currentStep];
      await this.channel.send(nextStep, message);
    }

    return message;
  }
}
```

**Quand :** Workflows dynamiques, pipelines.
**Lié à :** Process Manager.

---

### 15. Process Manager

> Orchestrer un workflow complexe.

```typescript
interface ProcessState {
  processId: string;
  currentStep: string;
  data: Record<string, any>;
  startedAt: Date;
  completedSteps: string[];
}

class OrderProcessManager {
  private processes = new Map<string, ProcessState>();

  async handleMessage(message: any) {
    const state = this.processes.get(message.processId) || this.createProcess(message);

    switch (state.currentStep) {
      case 'created':
        await this.validateOrder(state, message);
        break;
      case 'validated':
        await this.reserveInventory(state, message);
        break;
      case 'inventory_reserved':
        await this.processPayment(state, message);
        break;
      case 'payment_processed':
        await this.shipOrder(state, message);
        break;
      case 'shipped':
        this.completeProcess(state);
        break;
    }
  }

  private async validateOrder(state: ProcessState, message: any) {
    await this.send('validation-service', { orderId: state.processId, ...message });
    state.currentStep = 'validating';
  }

  // ... other steps
}
```

**Quand :** Sagas, orchestration, long-running processes.
**Lié à :** Saga, Routing Slip.

---

## Message Transformation

### 16. Message Translator

> Convertir entre formats.

```typescript
interface MessageTranslator<S, T> {
  translate(source: S): T;
}

class XmlToJsonTranslator implements MessageTranslator<string, object> {
  translate(xml: string): object {
    // Parse XML to JSON
    return parseXml(xml);
  }
}

class LegacyOrderTranslator implements MessageTranslator<LegacyOrder, ModernOrder> {
  translate(legacy: LegacyOrder): ModernOrder {
    return {
      id: legacy.ORDER_ID,
      customer: {
        id: legacy.CUST_NO,
        name: `${legacy.FIRST_NM} ${legacy.LAST_NM}`,
      },
      items: legacy.ITEMS.map((i) => ({
        productId: i.PROD_ID,
        quantity: i.QTY,
        price: i.UNIT_PRC / 100, // Convert cents to dollars
      })),
      total: legacy.TOT_AMT / 100,
    };
  }
}
```

**Quand :** Intégration legacy, formats multiples.
**Lié à :** Adapter, Canonical Data Model.

---

### 17. Envelope Wrapper

> Ajouter des métadonnées au message.

```typescript
interface Envelope<T> {
  header: {
    messageId: string;
    timestamp: Date;
    source: string;
    version: string;
    contentType: string;
  };
  body: T;
}

class EnvelopeWrapper {
  wrap<T>(message: T, source: string): Envelope<T> {
    return {
      header: {
        messageId: crypto.randomUUID(),
        timestamp: new Date(),
        source,
        version: '1.0',
        contentType: 'application/json',
      },
      body: message,
    };
  }

  unwrap<T>(envelope: Envelope<T>): T {
    return envelope.body;
  }
}
```

**Quand :** Métadonnées, transport agnostique.
**Lié à :** Message, Header.

---

### 18. Content Enricher

> Ajouter des données manquantes.

```typescript
class OrderEnricher {
  constructor(
    private customerService: CustomerService,
    private productService: ProductService,
  ) {}

  async enrich(order: PartialOrder): Promise<EnrichedOrder> {
    const customer = await this.customerService.find(order.customerId);
    const products = await Promise.all(
      order.items.map((i) => this.productService.find(i.productId)),
    );

    return {
      ...order,
      customer: {
        name: customer.name,
        email: customer.email,
        address: customer.shippingAddress,
      },
      items: order.items.map((item, i) => ({
        ...item,
        productName: products[i].name,
        unitPrice: products[i].price,
      })),
      enrichedAt: new Date(),
    };
  }
}
```

**Quand :** Données partielles, agrégation.
**Lié à :** Content Filter.

---

### 19. Content Filter

> Supprimer des données non nécessaires.

```typescript
class SensitiveDataFilter {
  filter(order: FullOrder): PublicOrder {
    return {
      id: order.id,
      status: order.status,
      items: order.items.map((i) => ({
        name: i.productName,
        quantity: i.quantity,
      })),
      // Exclude: customer.creditCard, customer.ssn, internalNotes
    };
  }
}

// Generic filter
class ContentFilter<T, R> {
  constructor(private projection: (input: T) => R) {}

  filter(message: T): R {
    return this.projection(message);
  }
}
```

**Quand :** Sécurité, privacy, réduire taille.
**Lié à :** Content Enricher.

---

### 20. Normalizer

> Transformer formats variés en format canonique.

```typescript
interface CanonicalOrder {
  id: string;
  customer: { id: string; name: string };
  items: { sku: string; qty: number; price: number }[];
}

class OrderNormalizer {
  normalize(order: unknown, source: string): CanonicalOrder {
    switch (source) {
      case 'legacy':
        return this.fromLegacy(order as LegacyOrder);
      case 'partner-a':
        return this.fromPartnerA(order as PartnerAOrder);
      case 'web':
        return this.fromWeb(order as WebOrder);
      default:
        throw new Error(`Unknown source: ${source}`);
    }
  }

  private fromLegacy(order: LegacyOrder): CanonicalOrder {
    return {
      id: order.ORDER_NO,
      customer: { id: order.CUST_ID, name: order.CUST_NAME },
      items: order.LINES.map((l) => ({
        sku: l.ITEM_NO,
        qty: l.QUANTITY,
        price: l.AMOUNT,
      })),
    };
  }

  // ... other transformers
}
```

**Quand :** Sources multiples, intégration.
**Lié à :** Canonical Data Model, Translator.

---

## Message Endpoints

### 21. Polling Consumer

> Consumer qui interroge périodiquement.

```typescript
class PollingConsumer {
  private running = false;

  constructor(
    private queue: MessageQueue,
    private handler: (msg: any) => Promise<void>,
    private interval: number = 1000,
  ) {}

  start() {
    this.running = true;
    this.poll();
  }

  stop() {
    this.running = false;
  }

  private async poll() {
    while (this.running) {
      try {
        const message = await this.queue.receive({ timeout: this.interval });
        if (message) {
          await this.handler(message);
          await this.queue.ack(message);
        }
      } catch (error) {
        console.error('Polling error:', error);
        await this.delay(this.interval);
      }
    }
  }

  private delay(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
```

**Quand :** Queues sans push, batch processing.
**Lié à :** Event-Driven Consumer.

---

### 22. Event-Driven Consumer

> Consumer réactif aux événements.

```typescript
class EventDrivenConsumer {
  constructor(
    private channel: MessageChannel,
    private handler: (msg: any) => Promise<void>,
  ) {}

  subscribe(queue: string) {
    this.channel.on('message', async (message) => {
      if (message.queue === queue) {
        try {
          await this.handler(message);
          await this.channel.ack(message);
        } catch (error) {
          await this.channel.nack(message);
        }
      }
    });
  }
}

// With backpressure
class BackpressureConsumer {
  private processing = 0;

  constructor(
    private channel: MessageChannel,
    private handler: (msg: any) => Promise<void>,
    private maxConcurrent: number = 10,
  ) {}

  subscribe(queue: string) {
    this.channel.on('message', async (message) => {
      if (this.processing >= this.maxConcurrent) {
        await this.channel.nack(message, { requeue: true });
        return;
      }

      this.processing++;
      try {
        await this.handler(message);
        await this.channel.ack(message);
      } finally {
        this.processing--;
      }
    });
  }
}
```

**Quand :** Real-time, réactif, scalable.
**Lié à :** Polling Consumer.

---

### 23. Competing Consumers

> Plusieurs consumers sur la même queue.

```typescript
class CompetingConsumers {
  private consumers: Consumer[] = [];

  constructor(
    private queue: MessageQueue,
    private handler: (msg: any) => Promise<void>,
    private concurrency: number,
  ) {}

  start() {
    for (let i = 0; i < this.concurrency; i++) {
      const consumer = new Consumer(this.queue, this.handler, i);
      consumer.start();
      this.consumers.push(consumer);
    }
  }

  stop() {
    this.consumers.forEach((c) => c.stop());
  }
}

// Each message goes to exactly one consumer
// Queue handles distribution and load balancing
```

**Quand :** Scalabilité horizontale, load balancing.
**Lié à :** Message Dispatcher.

---

### 24. Message Dispatcher

> Router les messages vers les handlers appropriés.

```typescript
type MessageHandler = (message: any) => Promise<void>;

class MessageDispatcher {
  private handlers = new Map<string, MessageHandler[]>();

  register(messageType: string, handler: MessageHandler) {
    if (!this.handlers.has(messageType)) {
      this.handlers.set(messageType, []);
    }
    this.handlers.get(messageType)!.push(handler);
  }

  async dispatch(message: { type: string; payload: any }) {
    const handlers = this.handlers.get(message.type) || [];
    await Promise.all(handlers.map((h) => h(message.payload)));
  }
}

// Usage
const dispatcher = new MessageDispatcher();
dispatcher.register('OrderCreated', handleOrderCreated);
dispatcher.register('OrderCreated', sendConfirmationEmail);
dispatcher.register('PaymentReceived', handlePayment);
```

**Quand :** Command handlers, event handlers.
**Lié à :** Observer, Mediator.

---

### 25. Selective Consumer

> Consumer qui filtre les messages.

```typescript
class SelectiveConsumer {
  constructor(
    private channel: MessageChannel,
    private selector: (msg: any) => boolean,
    private handler: (msg: any) => Promise<void>,
  ) {}

  subscribe(queue: string) {
    this.channel.subscribe(queue, {
      // Some brokers support server-side filtering
      filter: 'header.priority = "high"',
    });

    this.channel.on('message', async (message) => {
      // Client-side filtering for complex logic
      if (!this.selector(message)) {
        await this.channel.ack(message); // Acknowledge but don't process
        return;
      }
      await this.handler(message);
    });
  }
}

// Usage
const highPriorityConsumer = new SelectiveConsumer(
  channel,
  (msg) => msg.priority === 'high',
  handleHighPriority,
);
```

**Quand :** Filtrage messages, spécialisation.
**Lié à :** Message Filter.

---

### 26. Durable Subscriber

> Subscription qui survit aux déconnexions.

```typescript
class DurableSubscriber {
  constructor(
    private clientId: string,
    private subscriptionName: string,
  ) {}

  async subscribe(topic: string, handler: (msg: any) => Promise<void>) {
    const subscription = await this.broker.createDurableSubscription({
      clientId: this.clientId,
      subscriptionName: this.subscriptionName,
      topic,
    });

    // Messages are stored even when disconnected
    // On reconnect, receive missed messages

    subscription.on('message', async (msg) => {
      await handler(msg);
      await subscription.ack(msg);
    });
  }
}

// Usage - survives disconnection
const subscriber = new DurableSubscriber('order-service-1', 'order-events');
await subscriber.subscribe('orders.*', handleOrderEvent);
```

**Quand :** Fiabilité, offline, reprise.
**Lié à :** Guaranteed Delivery.

---

### 27. Idempotent Receiver

> Handler qui gère les duplicates.

```typescript
class IdempotentReceiver {
  constructor(
    private processedIds: Set<string> | RedisSet,
    private handler: (msg: any) => Promise<void>,
  ) {}

  async handle(message: { id: string; payload: any }) {
    // Check if already processed
    if (await this.processedIds.has(message.id)) {
      console.log(`Message ${message.id} already processed, skipping`);
      return;
    }

    // Process message
    await this.handler(message.payload);

    // Mark as processed
    await this.processedIds.add(message.id);
  }
}

// With expiration for cleanup
class IdempotentReceiverWithTTL {
  constructor(
    private redis: Redis,
    private ttlSeconds: number = 86400, // 24 hours
  ) {}

  async handle(message: { id: string; payload: any }, handler: Function) {
    const key = `processed:${message.id}`;

    // Try to set key (only succeeds if not exists)
    const wasNew = await this.redis.setnx(key, '1');
    if (!wasNew) {
      return; // Already processed
    }

    await this.redis.expire(key, this.ttlSeconds);
    await handler(message.payload);
  }
}
```

**Quand :** At-least-once delivery, retries.
**Lié à :** Guaranteed Delivery.

---

## Channel Patterns

### 28. Point-to-Point Channel

> Un message va à un seul consumer.

```typescript
class PointToPointChannel {
  private queue: Message[] = [];
  private waiting: ((msg: Message) => void)[] = [];

  send(message: Message) {
    const waiter = this.waiting.shift();
    if (waiter) {
      waiter(message);
    } else {
      this.queue.push(message);
    }
  }

  receive(): Promise<Message> {
    const message = this.queue.shift();
    if (message) {
      return Promise.resolve(message);
    }
    return new Promise((resolve) => {
      this.waiting.push(resolve);
    });
  }
}
```

**Quand :** Commands, job queues, work distribution.
**Lié à :** Publish-Subscribe.

---

### 29. Publish-Subscribe Channel

> Un message va à tous les subscribers.

```typescript
class PublishSubscribeChannel {
  private subscribers = new Map<string, ((msg: Message) => void)[]>();

  subscribe(topic: string, handler: (msg: Message) => void) {
    if (!this.subscribers.has(topic)) {
      this.subscribers.set(topic, []);
    }
    this.subscribers.get(topic)!.push(handler);

    return () => {
      const handlers = this.subscribers.get(topic)!;
      const index = handlers.indexOf(handler);
      if (index > -1) handlers.splice(index, 1);
    };
  }

  publish(topic: string, message: Message) {
    const handlers = this.subscribers.get(topic) || [];
    handlers.forEach((handler) => handler(message));

    // Support wildcards
    for (const [pattern, patternHandlers] of this.subscribers) {
      if (this.matchesTopic(pattern, topic)) {
        patternHandlers.forEach((h) => h(message));
      }
    }
  }

  private matchesTopic(pattern: string, topic: string): boolean {
    // orders.* matches orders.created, orders.deleted
    // orders.# matches orders.created.success
    const regex = pattern.replace(/\*/g, '[^.]+').replace(/#/g, '.+');
    return new RegExp(`^${regex}$`).test(topic);
  }
}
```

**Quand :** Events, notifications, broadcasting.
**Lié à :** Observer.

---

### 30. Dead Letter Channel

> Queue pour messages non traitables.

```typescript
class DeadLetterChannel {
  constructor(private dlq: MessageQueue) {}

  async sendToDeadLetter(
    message: any,
    error: Error,
    attempts: number,
  ) {
    await this.dlq.send({
      originalMessage: message,
      error: {
        name: error.name,
        message: error.message,
        stack: error.stack,
      },
      failedAt: new Date(),
      attempts,
    });
  }
}

class MessageProcessor {
  constructor(
    private handler: (msg: any) => Promise<void>,
    private dlc: DeadLetterChannel,
    private maxRetries: number = 3,
  ) {}

  async process(message: any) {
    let attempts = 0;

    while (attempts < this.maxRetries) {
      try {
        await this.handler(message);
        return;
      } catch (error) {
        attempts++;
        if (attempts >= this.maxRetries) {
          await this.dlc.sendToDeadLetter(message, error, attempts);
        }
      }
    }
  }
}
```

**Quand :** Error handling, debugging, retry exhaust.
**Lié à :** Guaranteed Delivery.

---

### 31. Guaranteed Delivery

> Assurer la livraison du message.

```typescript
class GuaranteedDelivery {
  constructor(
    private store: MessageStore,
    private channel: MessageChannel,
  ) {}

  async send(destination: string, message: any) {
    const id = crypto.randomUUID();

    // 1. Persist before sending
    await this.store.save({
      id,
      destination,
      message,
      status: 'pending',
      createdAt: new Date(),
    });

    try {
      // 2. Send message
      await this.channel.send(destination, { id, ...message });

      // 3. Mark as sent (or wait for ack)
      await this.store.updateStatus(id, 'sent');
    } catch (error) {
      // Will be retried by recovery process
      await this.store.updateStatus(id, 'failed');
      throw error;
    }
  }

  // Recovery process for failed messages
  async recoverPendingMessages() {
    const pending = await this.store.findByStatus('pending', 'failed');
    for (const msg of pending) {
      await this.send(msg.destination, msg.message);
    }
  }
}
```

**Quand :** Fiabilité critique, transactions.
**Lié à :** Outbox Pattern, Transactional Messaging.

---

## Tableau de décision

| Besoin | Pattern |
|--------|---------|
| Action à exécuter | Command Message |
| Notification fait | Event Message |
| Requête/réponse | Request-Reply |
| Lier messages | Correlation Identifier |
| Router dynamiquement | Content-Based Router |
| Filtrer messages | Message Filter |
| Envoyer à plusieurs | Recipient List |
| Diviser message | Splitter |
| Combiner messages | Aggregator |
| Comparer sources | Scatter-Gather |
| Workflow dynamique | Routing Slip |
| Orchestration | Process Manager |
| Convertir format | Message Translator |
| Ajouter métadonnées | Envelope Wrapper |
| Enrichir données | Content Enricher |
| Traitement par lot | Polling Consumer |
| Réactif | Event-Driven Consumer |
| Scaling horizontal | Competing Consumers |
| Router handlers | Message Dispatcher |
| Filtrer à la réception | Selective Consumer |
| Survie déconnexion | Durable Subscriber |
| Gérer duplicates | Idempotent Receiver |
| Un seul destinataire | Point-to-Point |
| Broadcast | Publish-Subscribe |
| Erreurs | Dead Letter Channel |
| Fiabilité | Guaranteed Delivery |

## Sources

- [Enterprise Integration Patterns](https://www.enterpriseintegrationpatterns.com/)
- [Gregor Hohpe - EIP Book](https://www.amazon.com/Enterprise-Integration-Patterns-Designing-Deploying/dp/0321200683)
