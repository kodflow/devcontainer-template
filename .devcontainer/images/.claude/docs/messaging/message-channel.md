# Message Channel Patterns

Patterns de canaux de communication pour le messaging.

## Vue d'ensemble

```
+-------------------+     +-------------------+
|    Producer A     |     |    Producer B     |
+--------+----------+     +--------+----------+
         |                         |
         v                         v
+------------------------------------------+
|              MESSAGE CHANNEL              |
|  +------------------------------------+  |
|  |  Point-to-Point  |  Pub/Sub        |  |
|  |    [Queue]       |   [Topic]       |  |
|  +------------------------------------+  |
+------------------------------------------+
         |                         |
         v                         v
+--------+----------+     +--------+----------+
|   Consumer 1      |     |   Consumer 2      |
+-------------------+     +-------------------+
```

---

## Point-to-Point Channel

> Un message est consomme par exactement un consumer.

### Schema

```
Producer ---> [  Queue  ] ---> Consumer A
                   |
                   X (not delivered to Consumer B)
```

### Implementation RabbitMQ/Kafka

```typescript
// RabbitMQ - Queue directe
interface PointToPointConfig {
  queue: string;
  durable: boolean;
  exclusive: boolean;
  autoDelete: boolean;
}

class PointToPointChannel {
  private channel: AMQPChannel;

  constructor(private config: PointToPointConfig) {}

  async send<T>(message: T): Promise<void> {
    await this.channel.assertQueue(this.config.queue, {
      durable: this.config.durable,
    });

    this.channel.sendToQueue(
      this.config.queue,
      Buffer.from(JSON.stringify(message)),
      { persistent: true }
    );
  }

  async consume(handler: (msg: unknown) => Promise<void>): Promise<void> {
    await this.channel.consume(this.config.queue, async (msg) => {
      if (!msg) return;

      try {
        const content = JSON.parse(msg.content.toString());
        await handler(content);
        this.channel.ack(msg);
      } catch (error) {
        // Requeue on failure
        this.channel.nack(msg, false, true);
      }
    });
  }
}

// Kafka - Consumer Group (simule P2P)
class KafkaPointToPoint {
  async consume(groupId: string, topic: string) {
    const consumer = this.kafka.consumer({ groupId });
    await consumer.subscribe({ topic });

    // Chaque message va a un seul consumer du groupe
    await consumer.run({
      eachMessage: async ({ message }) => {
        await this.processMessage(message);
      }
    });
  }
}
```

### Cas d'erreur

```typescript
class ResilientP2PChannel {
  private retryCount = 3;
  private deadLetterQueue: string;

  async processWithRetry(message: Message): Promise<void> {
    let attempts = 0;

    while (attempts < this.retryCount) {
      try {
        await this.handler(message);
        return;
      } catch (error) {
        attempts++;
        if (attempts >= this.retryCount) {
          await this.sendToDeadLetter(message, error);
          throw new MaxRetriesExceededError(message.id);
        }
        await this.delay(Math.pow(2, attempts) * 1000);
      }
    }
  }
}
```

**Quand :** Work queues, job processing, commands.
**Lie a :** Competing Consumers, Dead Letter Channel.

---

## Publish-Subscribe Channel

> Un message est envoye a tous les subscribers actifs.

### Pub-Sub Schema

```
Producer ---> [ Topic/Exchange ] ---> Subscriber A
                     |
                     +--------------> Subscriber B
                     |
                     +--------------> Subscriber C
```

### Implementation

```typescript
// RabbitMQ - Fanout Exchange
class PubSubChannel {
  private exchange: string;

  async publish<T>(event: T): Promise<void> {
    await this.channel.assertExchange(this.exchange, 'fanout', {
      durable: true
    });

    this.channel.publish(
      this.exchange,
      '', // routing key ignored for fanout
      Buffer.from(JSON.stringify(event))
    );
  }

  async subscribe(handler: (event: unknown) => Promise<void>): Promise<void> {
    // Chaque subscriber a sa propre queue
    const { queue } = await this.channel.assertQueue('', { exclusive: true });
    await this.channel.bindQueue(queue, this.exchange, '');

    await this.channel.consume(queue, async (msg) => {
      if (!msg) return;
      const event = JSON.parse(msg.content.toString());
      await handler(event);
      this.channel.ack(msg);
    });
  }
}

// Kafka - Topic avec multiple consumer groups
class KafkaPubSub {
  async publish(topic: string, event: unknown): Promise<void> {
    await this.producer.send({
      topic,
      messages: [{ value: JSON.stringify(event) }]
    });
  }

  // Chaque service utilise un groupId different
  async subscribe(groupId: string, topic: string): Promise<void> {
    const consumer = this.kafka.consumer({ groupId });
    await consumer.subscribe({ topic, fromBeginning: false });
  }
}
```

### Topic Filtering

```typescript
// RabbitMQ - Topic Exchange avec routing keys
class TopicPubSub {
  async publish(routingKey: string, event: unknown): Promise<void> {
    await this.channel.assertExchange('events', 'topic');
    this.channel.publish('events', routingKey, Buffer.from(JSON.stringify(event)));
  }

  async subscribe(pattern: string, handler: Function): Promise<void> {
    const { queue } = await this.channel.assertQueue('');
    // Pattern: orders.* ou orders.# ou orders.created
    await this.channel.bindQueue(queue, 'events', pattern);
    await this.channel.consume(queue, handler);
  }
}

// Usage
await pubsub.subscribe('orders.created', handleOrderCreated);
await pubsub.subscribe('orders.*', handleAllOrderEvents);
await pubsub.subscribe('orders.#', handleOrdersAndSubtopics);
```

### Pub-Sub Error Handling

```typescript
class ReliablePubSub {
  private subscriptionStore: SubscriptionStore;

  async subscribeWithRecovery(
    subscriberId: string,
    topic: string,
    handler: Function
  ): Promise<void> {
    // Sauvegarder la position de lecture
    const lastOffset = await this.subscriptionStore.getLastOffset(subscriberId);

    await this.subscribe(topic, async (event, offset) => {
      try {
        await handler(event);
        await this.subscriptionStore.saveOffset(subscriberId, offset);
      } catch (error) {
        // Log mais continue pour ne pas bloquer les autres
        console.error(`Failed to process event at ${offset}`, error);
        await this.errorHandler.handle(event, error);
      }
    }, { startOffset: lastOffset });
  }
}
```

**Quand :** Events, notifications, broadcasting, decoupling.
**Lie a :** Observer, Event-Driven Architecture.

---

## Tableau de decision

| Caracteristique | Point-to-Point | Publish-Subscribe |
|-----------------|----------------|-------------------|
| Destinataires | Un seul | Tous les abonnes |
| Cas d'usage | Commands, Jobs | Events, Notifications |
| Garantie | Exactement un traitement | Chaque abonne recoit |
| Scaling | Competing consumers | Multiple groups |
| Couplage | Plus fort | Plus faible |

---

## Patterns complementaires

- **Competing Consumers** - Scale P2P horizontalement
- **Durable Subscriber** - Pub/Sub avec persistance
- **Message Filter** - Filtrer les messages reçus
- **Dead Letter Channel** - Gerer les echecs
