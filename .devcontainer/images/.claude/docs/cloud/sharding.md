# Sharding Pattern

> Partitionner horizontalement les donnees pour scalabilite et performance.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │                  SHARDING                    │
                    └─────────────────────────────────────────────┘

  AVANT (Single Node):
  ┌─────────────────────────────────────────────────────────────┐
  │                        DATABASE                              │
  │  Users: 10M rows | Orders: 50M rows | Products: 1M rows     │
  │  [Performance degradee, SPOF, limite verticale]             │
  └─────────────────────────────────────────────────────────────┘

  APRES (Sharded):
                         ┌─────────────┐
                         │   Router    │
                         │ (Shard Key) │
                         └──────┬──────┘
                                │
         ┌──────────────────────┼──────────────────────┐
         │                      │                      │
         ▼                      ▼                      ▼
  ┌─────────────┐       ┌─────────────┐       ┌─────────────┐
  │  Shard 0    │       │  Shard 1    │       │  Shard 2    │
  │  A-H users  │       │  I-P users  │       │  Q-Z users  │
  │  3.3M rows  │       │  3.3M rows  │       │  3.4M rows  │
  └─────────────┘       └─────────────┘       └─────────────┘
```

## Strategies de partitionnement

```
1. RANGE SHARDING (par plage)
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │ 0-999   │ │1000-1999│ │2000-2999│
   └─────────┘ └─────────┘ └─────────┘
   + Simple a implementer
   - Hotspots possibles (dernieres IDs)

2. HASH SHARDING (par hash)
   shard = hash(user_id) % num_shards
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │ hash%3=0│ │ hash%3=1│ │ hash%3=2│
   └─────────┘ └─────────┘ └─────────┘
   + Distribution uniforme
   - Resharding complexe

3. DIRECTORY SHARDING (lookup table)
   ┌──────────┐
   │ Lookup   │ user_123 -> shard_2
   │ Service  │ user_456 -> shard_1
   └──────────┘
   + Flexibilite totale
   - SPOF potentiel, latence
```

## Exemple Go

```go
package sharding

import (
	"context"
	"fmt"
	"hash/fnv"
)

// ShardConfig defines a shard configuration.
type ShardConfig struct {
	ID   int
	Host string
	Port int
}

// ShardRouter routes keys to shards.
type ShardRouter struct {
	shards []ShardConfig
}

// NewShardRouter creates a new ShardRouter.
func NewShardRouter(shards []ShardConfig) *ShardRouter {
	return &ShardRouter{
		shards: shards,
	}
}

// GetShardForKey returns the shard for a given key using hash-based sharding.
func (sr *ShardRouter) GetShardForKey(key string) ShardConfig {
	hash := sr.hashKey(key)
	shardIndex := hash % uint32(len(sr.shards))
	return sr.shards[shardIndex]
}

func (sr *ShardRouter) hashKey(key string) uint32 {
	h := fnv.New32a()
	h.Write([]byte(key))
	return h.Sum32()
}

// User represents a user entity.
type User struct {
	ID    string
	Name  string
	Email string
}

// Database defines database operations for a shard.
type Database interface {
	FindUserByID(ctx context.Context, userID string) (*User, error)
	CreateUser(ctx context.Context, user *User) (*User, error)
	FindUserByEmail(ctx context.Context, email string) (*User, error)
}

// ShardedUserRepository manages users across multiple shards.
type ShardedUserRepository struct {
	router      *ShardRouter
	connections map[int]Database
}

// NewShardedUserRepository creates a new ShardedUserRepository.
func NewShardedUserRepository(router *ShardRouter) *ShardedUserRepository {
	return &ShardedUserRepository{
		router:      router,
		connections: make(map[int]Database),
	}
}

// FindByID finds a user by ID.
func (sur *ShardedUserRepository) FindByID(ctx context.Context, userID string) (*User, error) {
	shard := sur.router.GetShardForKey(userID)
	db, err := sur.getConnection(shard)
	if err != nil {
		return nil, fmt.Errorf("getting shard connection: %w", err)
	}

	return db.FindUserByID(ctx, userID)
}

// Create creates a new user.
func (sur *ShardedUserRepository) Create(ctx context.Context, user *User) (*User, error) {
	shard := sur.router.GetShardForKey(user.ID)
	db, err := sur.getConnection(shard)
	if err != nil {
		return nil, fmt.Errorf("getting shard connection: %w", err)
	}

	return db.CreateUser(ctx, user)
}

// FindByEmail finds a user by email (cross-shard query - expensive!).
func (sur *ShardedUserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	// Must query all shards
	type result struct {
		user *User
		err  error
	}

	results := make(chan result, len(sur.connections))

	for _, db := range sur.connections {
		go func(database Database) {
			user, err := database.FindUserByEmail(ctx, email)
			results <- result{user: user, err: err}
		}(db)
	}

	// Collect results
	for i := 0; i < len(sur.connections); i++ {
		res := <-results
		if res.err != nil {
			continue
		}
		if res.user != nil {
			return res.user, nil
		}
	}

	return nil, nil
}

func (sur *ShardedUserRepository) getConnection(shard ShardConfig) (Database, error) {
	if db, exists := sur.connections[shard.ID]; exists {
		return db, nil
	}

	// In production, connect to actual database
	// db := connectToDatabase(shard.Host, shard.Port)
	// sur.connections[shard.ID] = db
	// return db, nil

	return nil, fmt.Errorf("connection not initialized for shard %d", shard.ID)
}
```

## Consistent Hashing

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
```

## Choix de Shard Key

| Critere | Bonne shard key | Mauvaise shard key |
|---------|-----------------|-------------------|
| Cardinalite | user_id (unique) | country (peu de valeurs) |
| Distribution | UUID, hash | timestamp (hotspot) |
| Requetes | Incluent shard key | Cross-shard joins |
| Croissance | Uniforme | Un shard grandit plus |

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| > 1TB de donnees | Oui |
| Limites verticales atteintes | Oui |
| Read/write throughput eleve | Oui |
| Donnees partitionnables naturellement | Oui |
| Beaucoup de cross-shard queries | Non |
| Transactions ACID requises | Non (ou avec precaution) |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| CQRS | Read replicas par shard |
| Event Sourcing | Partitionnement par aggregate |
| Materialized View | Vues cross-shard |
| Leader Election | Coordination inter-shards |

## Sources

- [Microsoft - Sharding](https://learn.microsoft.com/en-us/azure/architecture/patterns/sharding)
- [AWS - Database Sharding](https://aws.amazon.com/blogs/database/sharding-with-amazon-relational-database-service/)
- [MongoDB Sharding](https://www.mongodb.com/docs/manual/sharding/)
