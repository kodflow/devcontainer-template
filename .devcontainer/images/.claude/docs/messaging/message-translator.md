# Message Translator Patterns

Patterns de transformation et enrichissement des messages.

## Vue d'ensemble

```
+------------+     +------------------+     +------------+
|  Format A  |---->| Message Translator|---->|  Format B  |
+------------+     +------------------+     +------------+
                          |
              +-----------+-----------+
              |           |           |
         Envelope    Enricher     Filter
          Wrapper
```

---

## Message Translator

> Convertit un message d'un format vers un autre.

### Schema

```
+----------------+        +----------------+
|  Legacy Order  |        |  Modern Order  |
|  ORDER_ID: 123 |  --->  |  id: "123"     |
|  CUST_NM: "X"  |        |  customer: {   |
|  TOT_AMT: 1000 |        |    name: "X"   |
+----------------+        |  }             |
                          |  total: 10.00  |
                          +----------------+
```

### Implementation

```typescript
interface MessageTranslator<TSource, TTarget> {
  translate(source: TSource): TTarget;
  canTranslate(source: unknown): source is TSource;
}

// Translator generique avec validation
class ValidatingTranslator<S, T> implements MessageTranslator<S, T> {
  constructor(
    private translateFn: (source: S) => T,
    private validator: (source: unknown) => source is S
  ) {}

  canTranslate(source: unknown): source is S {
    return this.validator(source);
  }

  translate(source: S): T {
    if (!this.canTranslate(source)) {
      throw new TranslationError('Invalid source format');
    }
    return this.translateFn(source);
  }
}

// Exemple: Legacy vers Modern
interface LegacyOrder {
  ORDER_ID: string;
  CUST_NO: string;
  CUST_NM: string;
  TOT_AMT: number; // en centimes
  ITEMS: Array<{ PROD_ID: string; QTY: number; UNIT_PRC: number }>;
}

interface ModernOrder {
  id: string;
  customer: { id: string; name: string };
  total: number;
  items: Array<{ productId: string; quantity: number; price: number }>;
}

const legacyToModernTranslator: MessageTranslator<LegacyOrder, ModernOrder> = {
  canTranslate: (source): source is LegacyOrder => {
    return source !== null &&
           typeof source === 'object' &&
           'ORDER_ID' in source;
  },

  translate: (legacy: LegacyOrder): ModernOrder => ({
    id: legacy.ORDER_ID,
    customer: {
      id: legacy.CUST_NO,
      name: legacy.CUST_NM,
    },
    total: legacy.TOT_AMT / 100,
    items: legacy.ITEMS.map(item => ({
      productId: item.PROD_ID,
      quantity: item.QTY,
      price: item.UNIT_PRC / 100,
    })),
  }),
};
```

**Quand :** Integration legacy, migration, formats multiples.
**Lie a :** Adapter pattern, Normalizer.

---

## Envelope Wrapper

> Ajoute des metadonnees de transport au message.

### Envelope Schema

```
+-------------+          +---------------------------+
|  Payload    |          |  Envelope                 |
|  {          |   --->   |  header: {                |
|    data...  |          |    messageId, timestamp,  |
|  }          |          |    source, version...     |
|             |          |  }                        |
+-------------+          |  body: { data... }        |
                         +---------------------------+
```

### Envelope Implementation

```typescript
interface EnvelopeHeader {
  messageId: string;
  correlationId?: string;
  causationId?: string;
  timestamp: Date;
  source: string;
  destination?: string;
  version: string;
  contentType: string;
  ttl?: number;
  priority?: 'low' | 'normal' | 'high' | 'urgent';
}

interface Envelope<T> {
  header: EnvelopeHeader;
  body: T;
}

class EnvelopeWrapper {
  constructor(private source: string, private version: string = '1.0') {}

  wrap<T>(
    message: T,
    options: Partial<EnvelopeHeader> = {}
  ): Envelope<T> {
    return {
      header: {
        messageId: crypto.randomUUID(),
        timestamp: new Date(),
        source: this.source,
        version: this.version,
        contentType: 'application/json',
        ...options,
      },
      body: message,
    };
  }

  unwrap<T>(envelope: Envelope<T>): T {
    return envelope.body;
  }

  // Extraire uniquement le header pour logging/tracing
  extractHeader(envelope: Envelope<unknown>): EnvelopeHeader {
    return envelope.header;
  }
}

// Usage avec tracing distribue
class TracingEnvelopeWrapper extends EnvelopeWrapper {
  wrap<T>(message: T, parentId?: string): Envelope<T> {
    const envelope = super.wrap(message);

    if (parentId) {
      envelope.header.causationId = parentId;
      envelope.header.correlationId = parentId;
    }

    // Integration OpenTelemetry
    const span = trace.getActiveSpan();
    if (span) {
      envelope.header['traceId'] = span.spanContext().traceId;
      envelope.header['spanId'] = span.spanContext().spanId;
    }

    return envelope;
  }
}
```

**Quand :** Transport agnostique, tracing, audit.
**Lie a :** Correlation Identifier, Message Header.

---

## Content Enricher

> Ajoute des donnees manquantes depuis des sources externes.

### Schema

```
+----------------+       +----------------+       +------------------+
| Partial Order  | ----> |    Enricher   | ----> |  Complete Order  |
| customerId: X  |       |       |        |       | customerId: X    |
| items: [...]   |       |       v        |       | customer: {...}  |
+----------------+       | +----------+   |       | items: [...]     |
                         | | Customer |   |       | itemDetails:[...]|
                         | | Service  |   |       +------------------+
                         | +----------+   |
                         | +----------+   |
                         | | Product  |   |
                         | | Service  |   |
                         | +----------+   |
                         +----------------+
```

### Implementation

```typescript
interface EnrichmentSource<TKey, TData> {
  fetch(key: TKey): Promise<TData | null>;
  fetchBatch(keys: TKey[]): Promise<Map<TKey, TData>>;
}

class ContentEnricher<TMessage, TEnriched> {
  private enrichments: Array<{
    keyExtractor: (msg: TMessage) => unknown;
    source: EnrichmentSource<unknown, unknown>;
    merger: (msg: TMessage, data: unknown) => Partial<TEnriched>;
  }> = [];

  addEnrichment<TKey, TData>(
    keyExtractor: (msg: TMessage) => TKey,
    source: EnrichmentSource<TKey, TData>,
    merger: (msg: TMessage, data: TData | null) => Partial<TEnriched>
  ): this {
    this.enrichments.push({ keyExtractor, source, merger });
    return this;
  }

  async enrich(message: TMessage): Promise<TEnriched> {
    let enriched = { ...message } as unknown as TEnriched;

    await Promise.all(
      this.enrichments.map(async ({ keyExtractor, source, merger }) => {
        const key = keyExtractor(message);
        const data = await source.fetch(key);
        const partial = merger(message, data);
        enriched = { ...enriched, ...partial };
      })
    );

    return enriched;
  }
}

// Usage concret
const orderEnricher = new ContentEnricher<PartialOrder, EnrichedOrder>()
  .addEnrichment(
    (order) => order.customerId,
    customerService,
    (order, customer) => ({
      customer: customer ? {
        name: customer.name,
        email: customer.email,
        tier: customer.membershipTier,
      } : null,
    })
  )
  .addEnrichment(
    (order) => order.items.map(i => i.productId),
    productService,
    (order, products) => ({
      items: order.items.map(item => ({
        ...item,
        name: products?.get(item.productId)?.name,
        price: products?.get(item.productId)?.price,
      })),
    })
  );

const enrichedOrder = await orderEnricher.enrich(partialOrder);
```

**Quand :** Donnees partielles, agregation, denormalisation.
**Lie a :** Content Filter, Aggregator.

---

## Content Filter

> Supprime les donnees non necessaires ou sensibles.

### Schema

```
+------------------+       +------------------+
| Full Customer    |       | Filtered Output  |
| id, name, email  | ----> | id, name         |
| ssn, creditCard  |       | (sans sensibles) |
| internalNotes    |       |                  |
+------------------+       +------------------+
```

### Implementation

```typescript
type FilterProjection<T, R> = (input: T) => R;

class ContentFilter<TInput, TOutput> {
  constructor(private projection: FilterProjection<TInput, TOutput>) {}

  filter(message: TInput): TOutput {
    return this.projection(message);
  }

  // Pipeline de filtres
  static chain<A, B, C>(
    first: ContentFilter<A, B>,
    second: ContentFilter<B, C>
  ): ContentFilter<A, C> {
    return new ContentFilter((input: A) =>
      second.filter(first.filter(input))
    );
  }
}

// Filtres predefinies pour securite
const sensitiveDataFilter = new ContentFilter<FullCustomer, PublicCustomer>(
  (customer) => ({
    id: customer.id,
    name: customer.name,
    // Exclut: ssn, creditCard, password, internalNotes
  })
);

const piiFilter = new ContentFilter<UserData, AnonymizedData>(
  (user) => ({
    ...user,
    email: user.email.replace(/(.{2}).*@/, '$1***@'),
    phone: user.phone?.replace(/\d(?=\d{4})/g, '*'),
    name: `${user.name.charAt(0)}***`,
  })
);

// Composition
const secureExportFilter = ContentFilter.chain(
  sensitiveDataFilter,
  piiFilter
);
```

**Quand :** Securite, privacy, reduction de payload.
**Lie a :** Content Enricher, Message Filter.

---

## Cas d'erreur

```typescript
class ResilientEnricher {
  async enrichWithFallback<T, E>(
    message: T,
    enricher: ContentEnricher<T, E>,
    fallbackData: Partial<E>
  ): Promise<E> {
    try {
      return await enricher.enrich(message);
    } catch (error) {
      if (error instanceof EnrichmentTimeoutError) {
        // Continuer avec donnees partielles
        return { ...message, ...fallbackData } as E;
      }
      if (error instanceof SourceUnavailableError) {
        // Log et utiliser cache
        const cached = await this.cache.get(message);
        if (cached) return cached;
        return { ...message, ...fallbackData } as E;
      }
      throw error;
    }
  }
}
```

---

## Tableau de decision

| Pattern | Cas d'usage | Direction |
|---------|-------------|-----------|
| Translator | Conversion format | A -> B |
| Envelope | Metadonnees transport | + metadata |
| Enricher | Ajouter donnees | + data |
| Filter | Retirer donnees | - data |

---

## Patterns complementaires

- **Normalizer** - Multiples formats vers canonique
- **Canonical Data Model** - Format standard
- **Claim Check** - Stocker payload large
- **Pipes and Filters** - Chainer transformations
