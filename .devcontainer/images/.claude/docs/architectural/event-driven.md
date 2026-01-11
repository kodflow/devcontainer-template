# Event-Driven Architecture

> Architecture où les composants communiquent via des événements asynchrones.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│               SYNCHRONE vs EVENT-DRIVEN                          │
│                                                                  │
│  SYNCHRONE (Request/Response)     EVENT-DRIVEN                  │
│  ┌──────┐  request  ┌──────┐     ┌──────┐   ┌─────────┐        │
│  │  A   │──────────▶│  B   │     │  A   │──▶│  Event  │        │
│  │      │◀──────────│      │     │      │   │  Bus    │        │
│  └──────┘  response └──────┘     └──────┘   └────┬────┘        │
│                                                   │              │
│  A attend B                            ┌─────────┼─────────┐    │
│  Couplage fort                         ▼         ▼         ▼    │
│                                    ┌──────┐ ┌──────┐ ┌──────┐  │
│                                    │  B   │ │  C   │ │  D   │  │
│                                    └──────┘ └──────┘ └──────┘  │
│                                    A ne connaît pas B, C, D     │
└─────────────────────────────────────────────────────────────────┘
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   EVENT-DRIVEN ARCHITECTURE                      │
│                                                                  │
│  ┌─────────────┐     ┌─────────────────────────────────────┐   │
│  │  Producer   │────▶│           EVENT BROKER              │   │
│  │  (Order)    │     │         (Kafka / RabbitMQ)          │   │
│  └─────────────┘     │                                     │   │
│                      │   ┌───────────────────────────────┐ │   │
│  ┌─────────────┐     │   │         TOPICS/QUEUES         │ │   │
│  │  Producer   │────▶│   │  ┌───────┐ ┌───────┐ ┌─────┐  │ │   │
│  │  (Payment)  │     │   │  │orders │ │payment│ │ship │  │ │   │
│  └─────────────┘     │   │  └───────┘ └───────┘ └─────┘  │ │   │
│                      │   └───────────────────────────────┘ │   │
│                      └───────────────┬─────────────────────┘   │
│                                      │                          │
│              ┌───────────────────────┼───────────────────┐     │
│              │                       │                   │     │
│              ▼                       ▼                   ▼     │
│     ┌─────────────┐         ┌─────────────┐     ┌───────────┐ │
│     │  Consumer   │         │  Consumer   │     │ Consumer  │ │
│     │  (Email)    │         │ (Analytics) │     │ (Inventory│ │
│     └─────────────┘         └─────────────┘     └───────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Types d'événements

### Domain Events

```typescript
// Événements métier (passé, immutable)
interface OrderCreatedEvent {
  type: 'order.created';
  data: {
    orderId: string;
    customerId: string;
    items: OrderItem[];
    total: number;
  };
  metadata: {
    timestamp: Date;
    correlationId: string;
    causationId: string;
  };
}

interface PaymentCompletedEvent {
  type: 'payment.completed';
  data: {
    paymentId: string;
    orderId: string;
    amount: number;
    method: string;
  };
}
```

### Integration Events

```typescript
// Événements inter-services
interface CustomerCreatedIntegrationEvent {
  type: 'integration.customer.created';
  data: {
    customerId: string;
    email: string;
    name: string;
  };
  source: 'customer-service';
  version: '1.0';
}
```

### Commands vs Events

```typescript
// Command = Intention (impératif, peut échouer)
interface CreateOrderCommand {
  type: 'CreateOrder';
  payload: {
    customerId: string;
    items: OrderItem[];
  };
}

// Event = Fait passé (indicatif, immutable)
interface OrderCreatedEvent {
  type: 'OrderCreated';
  payload: {
    orderId: string;
    customerId: string;
    items: OrderItem[];
    createdAt: Date;
  };
}
```

## Implémentation avec Kafka

```typescript
import { Kafka, Producer, Consumer } from 'kafkajs';

// Configuration
const kafka = new Kafka({
  clientId: 'order-service',
  brokers: ['kafka:9092'],
});

// Producer
class EventPublisher {
  private producer: Producer;

  async initialize(): Promise<void> {
    this.producer = kafka.producer();
    await this.producer.connect();
  }

  async publish<T extends DomainEvent>(event: T): Promise<void> {
    await this.producer.send({
      topic: event.type.split('.')[0], // 'order' for 'order.created'
      messages: [{
        key: event.data.aggregateId,
        value: JSON.stringify(event),
        headers: {
          'event-type': event.type,
          'correlation-id': event.metadata.correlationId,
          'timestamp': event.metadata.timestamp.toISOString(),
        },
      }],
    });
  }
}

// Consumer
class EventSubscriber {
  private consumer: Consumer;

  async subscribe(
    topic: string,
    groupId: string,
    handler: (event: DomainEvent) => Promise<void>
  ): Promise<void> {
    this.consumer = kafka.consumer({ groupId });
    await this.consumer.connect();
    await this.consumer.subscribe({ topic, fromBeginning: false });

    await this.consumer.run({
      eachMessage: async ({ message }) => {
        const event = JSON.parse(message.value.toString());
        try {
          await handler(event);
        } catch (error) {
          // Dead letter queue ou retry
          await this.handleError(event, error);
        }
      },
    });
  }

  private async handleError(event: DomainEvent, error: Error): Promise<void> {
    console.error(`Failed to process ${event.type}:`, error);
    // Send to DLQ
    await this.publisher.publish({
      type: 'dlq.failed',
      data: { originalEvent: event, error: error.message },
    });
  }
}
```

## Patterns Event-Driven

### Choreography

```
┌────────┐   OrderCreated   ┌────────┐
│ Order  │─────────────────▶│Payment │
│Service │                  │Service │
└────────┘                  └────────┘
                                │
                        PaymentComplete
                                │
    ┌───────────────────────────┼────────────────────────┐
    ▼                           ▼                        ▼
┌────────┐              ┌────────┐                ┌────────┐
│Shipping│              │ Email  │                │Inventory
│Service │              │Service │                │Service │
└────────┘              └────────┘                └────────┘

Décentralisé, pas de coordinateur
```

### Orchestration

```
┌────────────────────────────────────────┐
│            ORDER SAGA                   │
│                                        │
│  ┌──────────────────────────────────┐  │
│  │         Orchestrator             │  │
│  │                                  │  │
│  │  1. CreateOrder                  │  │
│  │  2. ReserveInventory             │  │
│  │  3. ProcessPayment               │  │
│  │  4. ShipOrder                    │  │
│  │                                  │  │
│  └──────────────────────────────────┘  │
│       │         │           │          │
│       ▼         ▼           ▼          │
│  ┌────────┐ ┌────────┐ ┌────────┐     │
│  │Order   │ │Inventory│ │Payment │     │
│  │Service │ │Service  │ │Service │     │
│  └────────┘ └────────┘ └────────┘     │
└────────────────────────────────────────┘

Centralisé, logique dans orchestrator
```

### Event Sourcing + Event-Driven

```
┌──────────────────────────────────────────────────────────────┐
│                                                               │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐   │
│  │ Command  │───▶│Aggregate │───▶│    Event Store       │   │
│  └──────────┘    └──────────┘    └──────────────────────┘   │
│                                           │                   │
│                                           │ Publish           │
│                                           ▼                   │
│                                  ┌──────────────────────┐    │
│                                  │    Event Bus         │    │
│                                  └──────────────────────┘    │
│                                           │                   │
│              ┌────────────────────────────┼──────────────┐   │
│              ▼                            ▼              ▼   │
│       ┌──────────┐               ┌──────────┐    ┌──────────┐
│       │Projection│               │ Notifier │    │Analytics │
│       └──────────┘               └──────────┘    └──────────┘
└──────────────────────────────────────────────────────────────┘
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Découplage requis | Transactions ACID simples |
| Haute disponibilité | Faible latence critique |
| Scale horizontal | Petite équipe |
| Résilience | Pas besoin asynchrone |
| Intégrations multiples | Flux linéaire simple |

## Avantages

- **Découplage** : Services indépendants
- **Scalabilité** : Consumers parallèles
- **Résilience** : Pannes isolées
- **Extensibilité** : Ajouter consumers sans modifier producer
- **Audit** : Log centralisé d'événements
- **Replay** : Rejouer les événements

## Inconvénients

- **Complexité** : Debug difficile
- **Eventual consistency** : Pas de ACID
- **Ordre** : Garantir l'ordre peut être complexe
- **Monitoring** : Observabilité nécessaire
- **Idempotency** : Gérer les doublons

## Exemples réels

| Entreprise | Usage |
|------------|-------|
| **LinkedIn** | Kafka (backbone) |
| **Uber** | Events pour matching |
| **Netflix** | Event-driven microservices |
| **Airbnb** | Real-time notifications |
| **Twitter** | Timeline updates |

## Migration path

### Depuis Synchrone

```
Phase 1: Identifier bounded contexts
Phase 2: Ajouter broker (Kafka/RabbitMQ)
Phase 3: Dual-write (sync + async)
Phase 4: Migrer vers async
Phase 5: Supprimer appels synchrones
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Event Sourcing | Events persistés |
| CQRS | Séparation read/write |
| Saga | Transactions distribuées |
| Circuit Breaker | Résilience consumers |

## Sources

- [Martin Fowler - Event-Driven](https://martinfowler.com/articles/201701-event-driven.html)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Enterprise Integration Patterns](https://www.enterpriseintegrationpatterns.com/)
