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

## Exemple TypeScript

```typescript
interface ShardConfig {
  id: number;
  host: string;
  port: number;
}

class ShardRouter {
  constructor(private shards: ShardConfig[]) {}

  // Hash-based sharding
  getShardForKey(key: string): ShardConfig {
    const hash = this.hashKey(key);
    const shardIndex = hash % this.shards.length;
    return this.shards[shardIndex];
  }

  private hashKey(key: string): number {
    // Consistent hashing (simplified)
    let hash = 0;
    for (let i = 0; i < key.length; i++) {
      hash = (hash * 31 + key.charCodeAt(i)) >>> 0;
    }
    return hash;
  }
}

class ShardedUserRepository {
  private connections: Map<number, Database> = new Map();

  constructor(private router: ShardRouter) {}

  async findById(userId: string): Promise<User | null> {
    const shard = this.router.getShardForKey(userId);
    const db = await this.getConnection(shard);
    return db.users.findById(userId);
  }

  async create(user: User): Promise<User> {
    const shard = this.router.getShardForKey(user.id);
    const db = await this.getConnection(shard);
    return db.users.create(user);
  }

  // Cross-shard query (expensive!)
  async findByEmail(email: string): Promise<User | null> {
    // Must query all shards
    const results = await Promise.all(
      Array.from(this.connections.values()).map((db) =>
        db.users.findByEmail(email),
      ),
    );
    return results.find((u) => u !== null) ?? null;
  }

  private async getConnection(shard: ShardConfig): Promise<Database> {
    if (!this.connections.has(shard.id)) {
      const db = await Database.connect(shard.host, shard.port);
      this.connections.set(shard.id, db);
    }
    return this.connections.get(shard.id)!;
  }
}
```

## Consistent Hashing

```typescript
class ConsistentHashRing {
  private ring: Map<number, ShardConfig> = new Map();
  private sortedKeys: number[] = [];

  constructor(
    shards: ShardConfig[],
    private virtualNodes = 150,
  ) {
    for (const shard of shards) {
      this.addShard(shard);
    }
  }

  addShard(shard: ShardConfig): void {
    for (let i = 0; i < this.virtualNodes; i++) {
      const key = this.hash(`${shard.id}:${i}`);
      this.ring.set(key, shard);
      this.sortedKeys.push(key);
    }
    this.sortedKeys.sort((a, b) => a - b);
  }

  removeShard(shardId: number): void {
    for (let i = 0; i < this.virtualNodes; i++) {
      const key = this.hash(`${shardId}:${i}`);
      this.ring.delete(key);
      this.sortedKeys = this.sortedKeys.filter((k) => k !== key);
    }
  }

  getShardForKey(key: string): ShardConfig {
    const hash = this.hash(key);

    // Find first node >= hash
    for (const nodeKey of this.sortedKeys) {
      if (nodeKey >= hash) {
        return this.ring.get(nodeKey)!;
      }
    }

    // Wrap around to first node
    return this.ring.get(this.sortedKeys[0])!;
  }

  private hash(key: string): number {
    // Use crypto hash in production
    let hash = 0;
    for (let i = 0; i < key.length; i++) {
      hash = (hash * 31 + key.charCodeAt(i)) >>> 0;
    }
    return hash;
  }
}
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
