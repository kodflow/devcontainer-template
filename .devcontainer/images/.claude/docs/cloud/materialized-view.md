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

## Exemple Go

```go
package materializedview

import (
	"context"
	"encoding/json"
	"fmt"
	"time"
)

// OrderStats represents aggregated order statistics for a user.
type OrderStats struct {
	UserID            string    `json:"userId"`
	TotalOrders       int       `json:"totalOrders"`
	TotalAmount       float64   `json:"totalAmount"`
	AverageOrderValue float64   `json:"averageOrderValue"`
	LastOrderDate     time.Time `json:"lastOrderDate"`
}

// Database defines database operations.
type Database interface {
	Query(ctx context.Context, query string, args ...interface{}) ([]map[string]interface{}, error)
	Exec(ctx context.Context, query string, args ...interface{}) error
}

// Cache defines cache operations.
type Cache interface {
	HSet(ctx context.Context, key string, values map[string]interface{}) error
	HGetAll(ctx context.Context, key string) (map[string]string, error)
	HIncrBy(ctx context.Context, key, field string, increment int64) error
	HIncrByFloat(ctx context.Context, key, field string, increment float64) error
}

// MaterializedViewService manages materialized views.
type MaterializedViewService struct {
	db    Database
	cache Cache
}

// NewMaterializedViewService creates a new MaterializedViewService.
func NewMaterializedViewService(db Database, cache Cache) *MaterializedViewService {
	return &MaterializedViewService{
		db:    db,
		cache: cache,
	}
}

// RefreshUserOrderStats refreshes user order statistics (complete refresh).
func (mvs *MaterializedViewService) RefreshUserOrderStats(ctx context.Context) error {
	query := `
		SELECT
			user_id,
			COUNT(*) as total_orders,
			SUM(amount) as total_amount,
			AVG(amount) as average_order_value,
			MAX(created_at) as last_order_date
		FROM orders
		WHERE status = 'completed'
		GROUP BY user_id
	`

	rows, err := mvs.db.Query(ctx, query)
	if err != nil {
		return fmt.Errorf("querying order stats: %w", err)
	}

	// Store in cache
	for _, row := range rows {
		userID := row["user_id"].(string)
		key := fmt.Sprintf("user_stats:%s", userID)
		
		values := map[string]interface{}{
			"totalOrders":       row["total_orders"],
			"totalAmount":       row["total_amount"],
			"averageOrderValue": row["average_order_value"],
			"lastOrderDate":     row["last_order_date"].(time.Time).Format(time.RFC3339),
		}
		
		if err := mvs.cache.HSet(ctx, key, values); err != nil {
			return fmt.Errorf("caching stats for user %s: %w", userID, err)
		}
	}

	return nil
}

// GetUserStats retrieves user statistics from cache.
func (mvs *MaterializedViewService) GetUserStats(ctx context.Context, userID string) (*OrderStats, error) {
	key := fmt.Sprintf("user_stats:%s", userID)
	
	data, err := mvs.cache.HGetAll(ctx, key)
	if err != nil {
		return nil, fmt.Errorf("getting stats from cache: %w", err)
	}

	if len(data) == 0 {
		return nil, nil
	}

	lastOrderDate, err := time.Parse(time.RFC3339, data["lastOrderDate"])
	if err != nil {
		return nil, fmt.Errorf("parsing last order date: %w", err)
	}

	stats := &OrderStats{
		UserID:        userID,
		LastOrderDate: lastOrderDate,
	}
	
	// Parse numeric fields
	fmt.Sscanf(data["totalOrders"], "%d", &stats.TotalOrders)
	fmt.Sscanf(data["totalAmount"], "%f", &stats.TotalAmount)
	fmt.Sscanf(data["averageOrderValue"], "%f", &stats.AverageOrderValue)

	return stats, nil
}

// OnOrderCompleted updates stats incrementally after order completion.
func (mvs *MaterializedViewService) OnOrderCompleted(ctx context.Context, userID string, amount float64, createdAt time.Time) error {
	key := fmt.Sprintf("user_stats:%s", userID)

	// Atomic increment
	if err := mvs.cache.HIncrBy(ctx, key, "totalOrders", 1); err != nil {
		return fmt.Errorf("incrementing total orders: %w", err)
	}

	if err := mvs.cache.HIncrByFloat(ctx, key, "totalAmount", amount); err != nil {
		return fmt.Errorf("incrementing total amount: %w", err)
	}

	// Update last order date
	values := map[string]interface{}{
		"lastOrderDate": createdAt.Format(time.RFC3339),
	}
	if err := mvs.cache.HSet(ctx, key, values); err != nil {
		return fmt.Errorf("updating last order date: %w", err)
	}

	// Recalculate average
	stats, err := mvs.GetUserStats(ctx, userID)
	if err != nil {
		return fmt.Errorf("getting user stats: %w", err)
	}

	if stats != nil && stats.TotalOrders > 0 {
		newAvg := stats.TotalAmount / float64(stats.TotalOrders)
		avgValues := map[string]interface{}{
			"averageOrderValue": fmt.Sprintf("%f", newAvg),
		}
		if err := mvs.cache.HSet(ctx, key, avgValues); err != nil {
			return fmt.Errorf("updating average: %w", err)
		}
	}

	return nil
}
```

## Implementation DB (Go)

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
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
