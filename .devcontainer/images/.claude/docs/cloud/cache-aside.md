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

## Exemple TypeScript

```typescript
interface CacheService {
  get<T>(key: string): Promise<T | null>;
  set<T>(key: string, value: T, ttlSeconds?: number): Promise<void>;
  delete(key: string): Promise<void>;
}

class UserRepository {
  constructor(
    private cache: CacheService,
    private db: Database,
    private ttl = 3600, // 1 hour
  ) {}

  async findById(id: string): Promise<User | null> {
    const cacheKey = `user:${id}`;

    // 1. Try cache first
    const cached = await this.cache.get<User>(cacheKey);
    if (cached) {
      return cached; // Cache hit
    }

    // 2. Cache miss - load from DB
    const user = await this.db.users.findById(id);
    if (!user) {
      return null;
    }

    // 3. Populate cache for next time
    await this.cache.set(cacheKey, user, this.ttl);

    return user;
  }

  async update(id: string, data: Partial<User>): Promise<User> {
    // 1. Update database first
    const user = await this.db.users.update(id, data);

    // 2. Invalidate cache (don't update - avoid race conditions)
    await this.cache.delete(`user:${id}`);

    return user;
  }

  async delete(id: string): Promise<void> {
    await this.db.users.delete(id);
    await this.cache.delete(`user:${id}`);
  }
}
```

## Implementation avec Redis

```typescript
import { Redis } from 'ioredis';

class RedisCacheService implements CacheService {
  constructor(private redis: Redis) {}

  async get<T>(key: string): Promise<T | null> {
    const data = await this.redis.get(key);
    return data ? JSON.parse(data) : null;
  }

  async set<T>(key: string, value: T, ttlSeconds = 3600): Promise<void> {
    await this.redis.setex(key, ttlSeconds, JSON.stringify(value));
  }

  async delete(key: string): Promise<void> {
    await this.redis.del(key);
  }

  // Pattern: Cache avec Stale-While-Revalidate
  async getWithSWR<T>(
    key: string,
    fetcher: () => Promise<T>,
    ttl: number,
    staleWindow: number,
  ): Promise<T> {
    const cached = await this.redis.get(key);

    if (cached) {
      const { data, timestamp } = JSON.parse(cached);
      const age = Date.now() - timestamp;

      // Fresh: return immediately
      if (age < ttl * 1000) {
        return data;
      }

      // Stale but within window: return stale, refresh async
      if (age < (ttl + staleWindow) * 1000) {
        this.refreshAsync(key, fetcher, ttl); // Fire and forget
        return data;
      }
    }

    // Expired or missing: fetch synchronously
    return this.fetchAndCache(key, fetcher, ttl);
  }

  private async refreshAsync<T>(
    key: string,
    fetcher: () => Promise<T>,
    ttl: number,
  ): Promise<void> {
    try {
      await this.fetchAndCache(key, fetcher, ttl);
    } catch (e) {
      console.error('Background refresh failed:', e);
    }
  }

  private async fetchAndCache<T>(
    key: string,
    fetcher: () => Promise<T>,
    ttl: number,
  ): Promise<T> {
    const data = await fetcher();
    await this.redis.setex(
      key,
      ttl,
      JSON.stringify({ data, timestamp: Date.now() }),
    );
    return data;
  }
}
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
