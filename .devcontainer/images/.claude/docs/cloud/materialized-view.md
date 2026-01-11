# Materialized View Pattern

> Pre-calculer et stocker des vues optimisees pour les requetes frequentes.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │            MATERIALIZED VIEW                 │
                    └─────────────────────────────────────────────┘

  SANS (requete complexe a chaque fois):
  ┌─────────┐   SELECT + JOIN + AGGREGATE   ┌─────────┐
  │  Client │ ──────────────────────────▶   │   DB    │
  └─────────┘        (lent, CPU)            └─────────┘

  AVEC (lecture directe):
  ┌─────────┐                               ┌─────────────────┐
  │  Client │ ───────── SELECT ──────────▶  │Materialized View│
  └─────────┘           (rapide)            └────────┬────────┘
                                                     │
                                              Pre-calculated
                                                     │
  ┌─────────┐   Write   ┌─────────┐   Refresh  ┌────▼────┐
  │ Writer  │ ────────▶ │   DB    │ ──────────▶│  View   │
  └─────────┘           └─────────┘            └─────────┘
```

## Strategies de rafraichissement

```
1. COMPLETE REFRESH (recreer)
   ┌────────┐       ┌──────────────┐
   │  Data  │ ────▶ │ DROP + CREATE│
   └────────┘       └──────────────┘
   + Simple
   - Lent, indisponibilite

2. INCREMENTAL REFRESH (delta)
   ┌────────┐       ┌──────────────┐
   │Changes │ ────▶ │ UPDATE VIEW  │
   └────────┘       └──────────────┘
   + Rapide
   - Complexe, pas toujours possible

3. ON-DEMAND (lazy)
   - Refresh quand requete detecte stale
   + Toujours frais
   - Latence premiere requete

4. SCHEDULED (cron)
   - Refresh toutes les X minutes
   + Predictible
   - Donnees potentiellement stale
```

## Exemple TypeScript

```typescript
interface OrderStats {
  userId: string;
  totalOrders: number;
  totalAmount: number;
  averageOrderValue: number;
  lastOrderDate: Date;
}

class MaterializedViewService {
  constructor(
    private db: Database,
    private cache: Redis,
  ) {}

  // Refresh complet
  async refreshUserOrderStats(): Promise<void> {
    const stats = await this.db.query<OrderStats[]>(`
      SELECT
        user_id as "userId",
        COUNT(*) as "totalOrders",
        SUM(amount) as "totalAmount",
        AVG(amount) as "averageOrderValue",
        MAX(created_at) as "lastOrderDate"
      FROM orders
      WHERE status = 'completed'
      GROUP BY user_id
    `);

    // Store in Redis as hash
    const pipeline = this.cache.pipeline();
    for (const stat of stats) {
      pipeline.hset(
        `user_stats:${stat.userId}`,
        'totalOrders',
        stat.totalOrders,
        'totalAmount',
        stat.totalAmount,
        'averageOrderValue',
        stat.averageOrderValue,
        'lastOrderDate',
        stat.lastOrderDate.toISOString(),
      );
    }
    await pipeline.exec();
  }

  // Lecture rapide
  async getUserStats(userId: string): Promise<OrderStats | null> {
    const data = await this.cache.hgetall(`user_stats:${userId}`);
    if (!Object.keys(data).length) return null;

    return {
      userId,
      totalOrders: parseInt(data.totalOrders),
      totalAmount: parseFloat(data.totalAmount),
      averageOrderValue: parseFloat(data.averageOrderValue),
      lastOrderDate: new Date(data.lastOrderDate),
    };
  }

  // Refresh incremental apres commande
  async onOrderCompleted(order: Order): Promise<void> {
    const key = `user_stats:${order.userId}`;

    // Atomic increment
    await this.cache.hincrby(key, 'totalOrders', 1);
    await this.cache.hincrbyfloat(key, 'totalAmount', order.amount);
    await this.cache.hset(key, 'lastOrderDate', order.createdAt.toISOString());

    // Recalculate average
    const stats = await this.cache.hgetall(key);
    const newAvg =
      parseFloat(stats.totalAmount) / parseInt(stats.totalOrders);
    await this.cache.hset(key, 'averageOrderValue', newAvg);
  }
}
```

## Implementation avec table DB

```typescript
class ProductSearchView {
  constructor(private db: Database) {}

  // Vue materialisee comme table
  async createView(): Promise<void> {
    await this.db.query(`
      CREATE TABLE IF NOT EXISTS product_search_view (
        product_id UUID PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category_name TEXT,
        brand_name TEXT,
        price DECIMAL(10,2),
        avg_rating DECIMAL(3,2),
        review_count INT,
        stock_quantity INT,
        search_vector TSVECTOR,
        updated_at TIMESTAMP DEFAULT NOW()
      );

      CREATE INDEX idx_product_search_vector
        ON product_search_view USING GIN(search_vector);
    `);
  }

  async refreshView(): Promise<void> {
    await this.db.query(`
      TRUNCATE product_search_view;

      INSERT INTO product_search_view
      SELECT
        p.id as product_id,
        p.name,
        p.description,
        c.name as category_name,
        b.name as brand_name,
        p.price,
        COALESCE(AVG(r.rating), 0) as avg_rating,
        COUNT(r.id) as review_count,
        COALESCE(s.quantity, 0) as stock_quantity,
        to_tsvector('french',
          p.name || ' ' ||
          COALESCE(p.description, '') || ' ' ||
          c.name || ' ' ||
          b.name
        ) as search_vector,
        NOW() as updated_at
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      LEFT JOIN brands b ON p.brand_id = b.id
      LEFT JOIN reviews r ON r.product_id = p.id
      LEFT JOIN stock s ON s.product_id = p.id
      GROUP BY p.id, c.name, b.name, s.quantity
    `);
  }

  async search(query: string, limit = 20): Promise<Product[]> {
    // Requete ultra-rapide sur vue pre-calculee
    return this.db.query(
      `
      SELECT * FROM product_search_view
      WHERE search_vector @@ plainto_tsquery('french', $1)
      ORDER BY ts_rank(search_vector, plainto_tsquery('french', $1)) DESC
      LIMIT $2
    `,
      [query, limit],
    );
  }
}
```

## Comparaison strategies

| Strategie | Latence lecture | Fraicheur | Complexite |
|-----------|-----------------|-----------|------------|
| Vue SQL standard | Haute | Temps reel | Basse |
| Materialized View DB | Basse | Selon refresh | Moyenne |
| Cache (Redis) | Tres basse | Selon TTL | Moyenne |
| Search Engine (ES) | Basse | Selon sync | Haute |

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Requetes analytiques complexes | Oui |
| Dashboards temps reel | Oui (avec refresh) |
| Recherche full-text | Oui |
| Donnees tres volatiles | Avec precaution |
| Transactions ACID requises | Non |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| CQRS | Read model = vue materialisee |
| Event Sourcing | Projections |
| Cache-Aside | Alternative plus simple |
| ETL | Pipelines de transformation |

## Sources

- [Microsoft - Materialized View](https://learn.microsoft.com/en-us/azure/architecture/patterns/materialized-view)
- [PostgreSQL Materialized Views](https://www.postgresql.org/docs/current/rules-materializedviews.html)
- [Martin Fowler - CQRS](https://martinfowler.com/bliki/CQRS.html)
