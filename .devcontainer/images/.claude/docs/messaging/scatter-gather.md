# Scatter-Gather Pattern

Distribuer une requete a plusieurs services et collecter leurs reponses.

## Vue d'ensemble

```
                         +-------------+
              +--------->| Service A   |--------+
              |          +-------------+        |
              |                                 v
+----------+  |          +-------------+    +------------+
| Request  |--+--------->| Service B   |--->| Aggregator |---> Response
+----------+  |          +-------------+    +------------+
              |                                 ^
              |          +-------------+        |
              +--------->| Service C   |--------+
                         +-------------+

           SCATTER                      GATHER
```

---

## Implementation de base

```typescript
interface ScatterGatherConfig {
  destinations: string[];
  timeout: number;
  minResponses?: number;      // Minimum pour succes
  aggregationStrategy: 'all' | 'first' | 'majority' | 'best';
}

interface ScatterResult<T> {
  source: string;
  response?: T;
  error?: Error;
  latencyMs: number;
}

class ScatterGather<TRequest, TResponse> {
  constructor(
    private config: ScatterGatherConfig,
    private channel: MessageChannel
  ) {}

  async scatter(request: TRequest): Promise<ScatterResult<TResponse>[]> {
    const correlationId = crypto.randomUUID();
    const startTime = Date.now();
    const results: ScatterResult<TResponse>[] = [];

    // Creer une Promise pour chaque destination
    const responsePromises = this.config.destinations.map(async (dest) => {
      const destStartTime = Date.now();
      try {
        const response = await this.sendAndWait<TResponse>(
          dest,
          request,
          correlationId
        );
        return {
          source: dest,
          response,
          latencyMs: Date.now() - destStartTime,
        };
      } catch (error) {
        return {
          source: dest,
          error: error as Error,
          latencyMs: Date.now() - destStartTime,
        };
      }
    });

    // Attendre avec timeout
    const settled = await Promise.allSettled(
      responsePromises.map(p => this.withTimeout(p, this.config.timeout))
    );

    return settled.map((result, index) => {
      if (result.status === 'fulfilled') {
        return result.value;
      }
      return {
        source: this.config.destinations[index],
        error: new Error('Timeout'),
        latencyMs: this.config.timeout,
      };
    });
  }

  private async sendAndWait<R>(
    destination: string,
    request: TRequest,
    correlationId: string
  ): Promise<R> {
    return new Promise((resolve, reject) => {
      const replyQueue = `reply.${correlationId}`;

      // Setup temporary reply queue
      this.channel.subscribe(replyQueue, (msg) => {
        if (msg.correlationId === correlationId) {
          resolve(msg.payload as R);
        }
      });

      // Send request
      this.channel.send(destination, {
        payload: request,
        correlationId,
        replyTo: replyQueue,
      });
    });
  }

  private withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
    return Promise.race([
      promise,
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error('Timeout')), ms)
      ),
    ]);
  }
}
```

---

## Strategies d'aggregation

```typescript
type AggregationStrategy<T, R> = (results: ScatterResult<T>[]) => R;

// Best Price - retourne le meilleur resultat
const bestPriceStrategy: AggregationStrategy<PriceQuote, PriceQuote> = (results) => {
  const validResults = results
    .filter(r => r.response && !r.error)
    .map(r => r.response!);

  if (validResults.length === 0) {
    throw new NoValidResponsesError();
  }

  return validResults.reduce((min, quote) =>
    quote.price < min.price ? quote : min
  );
};

// Combine All - agrege toutes les reponses
const combineAllStrategy: AggregationStrategy<SearchResult, CombinedResults> = (results) => {
  const validResults = results
    .filter(r => r.response)
    .map(r => r.response!);

  return {
    items: validResults.flatMap(r => r.items),
    sources: results.map(r => ({
      name: r.source,
      success: !r.error,
      latencyMs: r.latencyMs,
    })),
    totalResults: validResults.reduce((sum, r) => sum + r.items.length, 0),
  };
};

// Fastest - premier resultat valide
const fastestStrategy: AggregationStrategy<unknown, unknown> = (results) => {
  const sorted = [...results]
    .filter(r => r.response)
    .sort((a, b) => a.latencyMs - b.latencyMs);

  if (sorted.length === 0) {
    throw new NoValidResponsesError();
  }

  return sorted[0].response;
};

// Quorum - majorite necessaire
const quorumStrategy = <T>(
  requiredVotes: number,
  compareFn: (a: T, b: T) => boolean
): AggregationStrategy<T, T> => (results) => {
  const validResults = results.filter(r => r.response).map(r => r.response!);

  // Compter les votes pour chaque reponse unique
  const votes = new Map<T, number>();
  for (const result of validResults) {
    let found = false;
    for (const [existing, count] of votes) {
      if (compareFn(existing, result)) {
        votes.set(existing, count + 1);
        found = true;
        break;
      }
    }
    if (!found) {
      votes.set(result, 1);
    }
  }

  // Trouver le quorum
  for (const [result, count] of votes) {
    if (count >= requiredVotes) {
      return result;
    }
  }

  throw new QuorumNotReachedError(requiredVotes, validResults.length);
};
```

---

## Exemple: Comparateur de prix

```typescript
interface PriceRequest {
  productId: string;
  quantity: number;
}

interface PriceQuote {
  supplierId: string;
  productId: string;
  unitPrice: number;
  totalPrice: number;
  currency: string;
  validUntil: Date;
  inStock: boolean;
  deliveryDays: number;
}

class PriceComparator {
  private scatterGather: ScatterGather<PriceRequest, PriceQuote>;

  constructor(suppliers: string[]) {
    this.scatterGather = new ScatterGather({
      destinations: suppliers,
      timeout: 5000,
      minResponses: 1,
      aggregationStrategy: 'all',
    }, channel);
  }

  async getBestPrice(request: PriceRequest): Promise<PriceComparisonResult> {
    const results = await this.scatterGather.scatter(request);

    const validQuotes = results
      .filter(r => r.response && r.response.inStock)
      .map(r => r.response!);

    if (validQuotes.length === 0) {
      throw new NoAvailableSupplierError(request.productId);
    }

    const sortedByPrice = [...validQuotes].sort((a, b) => a.totalPrice - b.totalPrice);
    const sortedByDelivery = [...validQuotes].sort((a, b) => a.deliveryDays - b.deliveryDays);

    return {
      cheapest: sortedByPrice[0],
      fastest: sortedByDelivery[0],
      allQuotes: sortedByPrice,
      supplierStats: results.map(r => ({
        supplier: r.source,
        responded: !!r.response,
        latencyMs: r.latencyMs,
        error: r.error?.message,
      })),
    };
  }
}
```

---

## Avec RabbitMQ/Kafka

```typescript
// RabbitMQ - Direct Reply-To
class RabbitMQScatterGather {
  async scatter<T, R>(destinations: string[], request: T): Promise<R[]> {
    const correlationId = crypto.randomUUID();
    const results: R[] = [];

    return new Promise(async (resolve) => {
      // Consumer sur amq.rabbitmq.reply-to
      await this.channel.consume(
        'amq.rabbitmq.reply-to',
        (msg) => {
          if (msg.properties.correlationId === correlationId) {
            results.push(JSON.parse(msg.content.toString()));
            if (results.length === destinations.length) {
              resolve(results);
            }
          }
        },
        { noAck: true }
      );

      // Envoyer a toutes les destinations
      for (const dest of destinations) {
        this.channel.sendToQueue(dest, Buffer.from(JSON.stringify(request)), {
          correlationId,
          replyTo: 'amq.rabbitmq.reply-to',
        });
      }

      // Timeout
      setTimeout(() => resolve(results), 5000);
    });
  }
}

// Kafka - Request-Reply avec topic temporaire
class KafkaScatterGather {
  async scatter<T, R>(groupTopics: string[], request: T): Promise<R[]> {
    const correlationId = crypto.randomUUID();
    const replyTopic = `replies.${correlationId}`;

    // Creer topic temporaire
    await this.admin.createTopics({
      topics: [{ topic: replyTopic, numPartitions: 1 }],
    });

    try {
      // Consumer pour les reponses
      const consumer = this.kafka.consumer({ groupId: correlationId });
      await consumer.subscribe({ topic: replyTopic });

      const results: R[] = [];
      const resultPromise = new Promise<R[]>((resolve) => {
        consumer.run({
          eachMessage: async ({ message }) => {
            results.push(JSON.parse(message.value!.toString()));
            if (results.length === groupTopics.length) {
              resolve(results);
            }
          },
        });
        setTimeout(() => resolve(results), 5000);
      });

      // Envoyer requetes
      await this.producer.send({
        topic: 'scatter-requests',
        messages: groupTopics.map(topic => ({
          key: correlationId,
          value: JSON.stringify({ request, replyTopic, targetTopic: topic }),
        })),
      });

      return await resultPromise;
    } finally {
      await this.admin.deleteTopics({ topics: [replyTopic] });
    }
  }
}
```

---

## Cas d'erreur

```typescript
class ResilientScatterGather<T, R> {
  async scatterWithFallback(
    request: T,
    fallbackFn: () => R
  ): Promise<R> {
    try {
      const results = await this.scatter(request);
      const valid = results.filter(r => r.response);

      if (valid.length < this.config.minResponses) {
        console.warn(`Insufficient responses: ${valid.length}/${this.config.minResponses}`);
        return fallbackFn();
      }

      return this.aggregate(results);
    } catch (error) {
      if (error instanceof TimeoutError) {
        return fallbackFn();
      }
      throw error;
    }
  }

  async scatterWithCircuitBreaker(request: T): Promise<R> {
    // Filtrer les destinations avec circuit ouvert
    const healthyDestinations = this.config.destinations.filter(
      dest => !this.circuitBreaker.isOpen(dest)
    );

    if (healthyDestinations.length === 0) {
      throw new AllCircuitsOpenError();
    }

    const results = await this.scatter(request, healthyDestinations);

    // Mettre a jour les circuit breakers
    for (const result of results) {
      if (result.error) {
        this.circuitBreaker.recordFailure(result.source);
      } else {
        this.circuitBreaker.recordSuccess(result.source);
      }
    }

    return this.aggregate(results);
  }
}
```

---

## Patterns complementaires

- **Splitter-Aggregator** - Division/recombinaison
- **Circuit Breaker** - Protection contre pannes
- **Timeout** - Limiter attente
- **Competing Consumers** - Scale les services
