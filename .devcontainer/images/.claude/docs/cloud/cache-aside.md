# Cache-Aside Pattern

> Charger les donnees dans le cache a la demande depuis le data store.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │              CACHE-ASIDE FLOW               │
                    └─────────────────────────────────────────────┘

  READ (Cache Hit):
  ┌─────────┐  1. Get    ┌─────────┐
  │  Client │ ─────────▶ │  Cache  │ ──▶ Data found, return
  └─────────┘            └─────────┘

  READ (Cache Miss):
  ┌─────────┐  1. Get    ┌─────────┐  2. Miss
  │  Client │ ─────────▶ │  Cache  │ ─────────┐
  └─────────┘            └─────────┘          │
       ▲                      ▲               ▼
       │                      │          ┌─────────┐
       │   5. Return data     │ 4. Set   │   DB    │
       └──────────────────────┴──────────┴─────────┘
                                  3. Read

  WRITE (Write-Through):
  ┌─────────┐  1. Write  ┌─────────┐  2. Write  ┌─────────┐
  │  Client │ ─────────▶ │  Cache  │ ─────────▶ │   DB    │
  └─────────┘            └─────────┘            └─────────┘

  WRITE (Cache-Aside):
  ┌─────────┐  1. Write  ┌─────────┐
  │  Client │ ─────────▶ │   DB    │
  └─────────┘            └─────────┘
       │  2. Invalidate      │
       └────────────────────▶│
                        ┌─────────┐
                        │  Cache  │ (entry removed)
                        └─────────┘
```

## Variantes

| Pattern | Description | Coherence |
|---------|-------------|-----------|
| **Cache-Aside** | App gere le cache manuellement | Eventuelle |
| **Read-Through** | Cache charge depuis DB automatiquement | Eventuelle |
| **Write-Through** | Ecriture synchrone cache + DB | Forte |
| **Write-Behind** | Ecriture asynchrone vers DB | Eventuelle |

## Exemple Go

```go
package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"
)

// CacheService defines cache operations.
type CacheService interface {
	Get(ctx context.Context, key string, dest interface{}) error
	Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error
	Delete(ctx context.Context, key string) error
}

// Database represents database operations.
type Database interface {
	FindUserByID(ctx context.Context, id string) (*User, error)
	UpdateUser(ctx context.Context, id string, data map[string]interface{}) (*User, error)
	DeleteUser(ctx context.Context, id string) error
}

// User represents a user entity.
type User struct {
	ID       string    `json:"id"`
	Name     string    `json:"name"`
	Email    string    `json:"email"`
	CreateAt time.Time `json:"created_at"`
}

// UserRepository implements cache-aside pattern for users.
type UserRepository struct {
	cache Cache Service
	db    Database
	ttl   time.Duration
}

// NewUserRepository creates a new UserRepository.
func NewUserRepository(cache CacheService, db Database, ttl time.Duration) *UserRepository {
	return &UserRepository{
		cache: cache,
		db:    db,
		ttl:   ttl,
	}
}

// FindByID finds a user by ID using cache-aside pattern.
func (r *UserRepository) FindByID(ctx context.Context, id string) (*User, error) {
	cacheKey := fmt.Sprintf("user:%s", id)

	// 1. Try cache first
	var user User
	err := r.cache.Get(ctx, cacheKey, &user)
	if err == nil {
		return &user, nil // Cache hit
	}

	// 2. Cache miss - load from DB
	dbUser, err := r.db.FindUserByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("finding user from db: %w", err)
	}
	if dbUser == nil {
		return nil, nil
	}

	// 3. Populate cache for next time
	if err := r.cache.Set(ctx, cacheKey, dbUser, r.ttl); err != nil {
		// Log but don't fail - cache is optional
		fmt.Printf("failed to cache user %s: %v
", id, err)
	}

	return dbUser, nil
}

// Update updates a user and invalidates the cache.
func (r *UserRepository) Update(ctx context.Context, id string, data map[string]interface{}) (*User, error) {
	// 1. Update database first
	user, err := r.db.UpdateUser(ctx, id, data)
	if err != nil {
		return nil, fmt.Errorf("updating user: %w", err)
	}

	// 2. Invalidate cache (don't update - avoid race conditions)
	cacheKey := fmt.Sprintf("user:%s", id)
	if err := r.cache.Delete(ctx, cacheKey); err != nil {
		fmt.Printf("failed to invalidate cache for user %s: %v
", id, err)
	}

	return user, nil
}

// Delete deletes a user and invalidates the cache.
func (r *UserRepository) Delete(ctx context.Context, id string) error {
	if err := r.db.DeleteUser(ctx, id); err != nil {
		return fmt.Errorf("deleting user: %w", err)
	}

	cacheKey := fmt.Sprintf("user:%s", id)
	if err := r.cache.Delete(ctx, cacheKey); err != nil {
		fmt.Printf("failed to invalidate cache for user %s: %v
", id, err)
	}

	return nil
}
```

## Implementation Redis (Go)

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Strategies TTL

| Donnee | TTL recommande | Raison |
|--------|----------------|--------|
| Configuration | 5-15 min | Change rarement |
| User profile | 1-24 h | Mise a jour rare |
| Product catalog | 15-60 min | Updates reguliers |
| Session | 30 min - 24h | Securite |
| Real-time data | 1-60 sec | Fraicheur critique |

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Lectures >> Ecritures | Oui |
| Donnees peu volatiles | Oui |
| Tolerance a coherence eventuelle | Oui |
| Donnees en temps reel strict | Non |
| Ecritures frequentes | Non (invalidation excessive) |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Read-Through | Cache charge auto |
| Write-Through | Coherence forte |
| Refresh-Ahead | Pre-chargement proactif |
| Circuit Breaker | Fallback si cache down |

## Sources

- [Microsoft - Cache-Aside](https://learn.microsoft.com/en-us/azure/architecture/patterns/cache-aside)
- [AWS ElastiCache Best Practices](https://docs.aws.amazon.com/AmazonElastiCache/latest/mem-ug/BestPractices.html)
