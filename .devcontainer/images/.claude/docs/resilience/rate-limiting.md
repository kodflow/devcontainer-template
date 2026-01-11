# Rate Limiting Pattern

> Controler le debit des requetes pour proteger les services contre la surcharge.

---

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                     RATE LIMITING                                │
│                                                                  │
│   Incoming Requests          Rate Limiter           Service     │
│   ─────────────────         ────────────           ─────────    │
│                                                                  │
│   ●●●●●●●●●●●●●● ─────────► [Token Bucket] ─────────► □□□□□     │
│   (100 req/s)                  │    │               (max 50)    │
│                                │    │                            │
│                                │    └──► ✗ Rejected (429)       │
│                                │                                 │
│                                └────► ✓ Allowed (200)           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Algorithmes

| Algorithme | Description | Usage |
|------------|-------------|-------|
| **Token Bucket** | Tokens regeneres a taux constant | API rate limiting |
| **Leaky Bucket** | Queue qui se vide a taux constant | Traffic shaping |
| **Fixed Window** | Compteur par fenetre de temps fixe | Simple, mais burst |
| **Sliding Window Log** | Log des timestamps des requetes | Precis, plus de memoire |
| **Sliding Window Counter** | Approximation entre fenetres | Bon compromis |

---

## Implementation Token Bucket

```typescript
class TokenBucket {
  private tokens: number;
  private lastRefill: number;

  constructor(
    private readonly capacity: number,      // Nombre max de tokens
    private readonly refillRate: number,    // Tokens par seconde
  ) {
    this.tokens = capacity;
    this.lastRefill = Date.now();
  }

  tryConsume(tokensNeeded = 1): boolean {
    this.refill();

    if (this.tokens >= tokensNeeded) {
      this.tokens -= tokensNeeded;
      return true;
    }

    return false;
  }

  private refill(): void {
    const now = Date.now();
    const elapsed = (now - this.lastRefill) / 1000;
    const tokensToAdd = elapsed * this.refillRate;

    this.tokens = Math.min(this.capacity, this.tokens + tokensToAdd);
    this.lastRefill = now;
  }

  getAvailableTokens(): number {
    this.refill();
    return Math.floor(this.tokens);
  }
}

// Usage
const bucket = new TokenBucket(100, 10); // 100 tokens max, 10/s refill

function handleRequest(request: Request): Response {
  if (!bucket.tryConsume()) {
    return new Response('Too Many Requests', { status: 429 });
  }
  return processRequest(request);
}
```

---

## Implementation Sliding Window

```typescript
class SlidingWindowRateLimiter {
  private readonly requests: Map<string, number[]> = new Map();

  constructor(
    private readonly windowMs: number,     // Fenetre en ms
    private readonly maxRequests: number,  // Max requetes par fenetre
  ) {}

  isAllowed(key: string): boolean {
    const now = Date.now();
    const windowStart = now - this.windowMs;

    // Recuperer ou initialiser le log
    let timestamps = this.requests.get(key) ?? [];

    // Supprimer les requetes hors fenetre
    timestamps = timestamps.filter((ts) => ts > windowStart);

    if (timestamps.length >= this.maxRequests) {
      return false;
    }

    // Ajouter la requete courante
    timestamps.push(now);
    this.requests.set(key, timestamps);

    return true;
  }

  getRemainingRequests(key: string): number {
    const now = Date.now();
    const windowStart = now - this.windowMs;
    const timestamps = this.requests.get(key) ?? [];
    const validRequests = timestamps.filter((ts) => ts > windowStart);
    return Math.max(0, this.maxRequests - validRequests.length);
  }

  getResetTime(key: string): number {
    const timestamps = this.requests.get(key) ?? [];
    if (timestamps.length === 0) return 0;
    const oldest = Math.min(...timestamps);
    return Math.max(0, oldest + this.windowMs - Date.now());
  }
}
```

---

## Rate Limiter multi-niveau

```typescript
interface RateLimitConfig {
  perSecond?: number;
  perMinute?: number;
  perHour?: number;
  perDay?: number;
}

class MultiLevelRateLimiter {
  private readonly limiters: Array<{
    limiter: SlidingWindowRateLimiter;
    windowMs: number;
    max: number;
  }> = [];

  constructor(config: RateLimitConfig) {
    if (config.perSecond) {
      this.limiters.push({
        limiter: new SlidingWindowRateLimiter(1000, config.perSecond),
        windowMs: 1000,
        max: config.perSecond,
      });
    }
    if (config.perMinute) {
      this.limiters.push({
        limiter: new SlidingWindowRateLimiter(60000, config.perMinute),
        windowMs: 60000,
        max: config.perMinute,
      });
    }
    if (config.perHour) {
      this.limiters.push({
        limiter: new SlidingWindowRateLimiter(3600000, config.perHour),
        windowMs: 3600000,
        max: config.perHour,
      });
    }
    if (config.perDay) {
      this.limiters.push({
        limiter: new SlidingWindowRateLimiter(86400000, config.perDay),
        windowMs: 86400000,
        max: config.perDay,
      });
    }
  }

  isAllowed(key: string): { allowed: boolean; retryAfter?: number } {
    for (const { limiter, windowMs } of this.limiters) {
      if (!limiter.isAllowed(key)) {
        return {
          allowed: false,
          retryAfter: limiter.getResetTime(key),
        };
      }
    }
    return { allowed: true };
  }
}

// Usage
const limiter = new MultiLevelRateLimiter({
  perSecond: 10,
  perMinute: 100,
  perHour: 1000,
});

function handleApiRequest(userId: string, request: Request): Response {
  const result = limiter.isAllowed(userId);

  if (!result.allowed) {
    return new Response('Too Many Requests', {
      status: 429,
      headers: {
        'Retry-After': String(Math.ceil((result.retryAfter ?? 0) / 1000)),
      },
    });
  }

  return processRequest(request);
}
```

---

## Rate Limiter distribue (Redis)

```typescript
class RedisRateLimiter {
  constructor(
    private readonly redis: RedisClient,
    private readonly keyPrefix: string,
    private readonly windowMs: number,
    private readonly maxRequests: number,
  ) {}

  async isAllowed(key: string): Promise<{
    allowed: boolean;
    remaining: number;
    resetAt: number;
  }> {
    const fullKey = `${this.keyPrefix}:${key}`;
    const now = Date.now();
    const windowStart = now - this.windowMs;

    // Script Lua pour atomicite
    const script = `
      local key = KEYS[1]
      local windowStart = tonumber(ARGV[1])
      local now = tonumber(ARGV[2])
      local maxRequests = tonumber(ARGV[3])
      local windowMs = tonumber(ARGV[4])

      -- Supprimer les anciennes entrees
      redis.call('ZREMRANGEBYSCORE', key, '-inf', windowStart)

      -- Compter les requetes dans la fenetre
      local count = redis.call('ZCARD', key)

      if count < maxRequests then
        -- Ajouter la requete courante
        redis.call('ZADD', key, now, now .. ':' .. math.random())
        redis.call('PEXPIRE', key, windowMs)
        return {1, maxRequests - count - 1, 0}
      else
        -- Trouver le temps de reset
        local oldest = redis.call('ZRANGE', key, 0, 0, 'WITHSCORES')
        local resetAt = oldest[2] + windowMs - now
        return {0, 0, resetAt}
      end
    `;

    const result = await this.redis.eval(
      script,
      1,
      fullKey,
      windowStart,
      now,
      this.maxRequests,
      this.windowMs,
    ) as [number, number, number];

    return {
      allowed: result[0] === 1,
      remaining: result[1],
      resetAt: result[2],
    };
  }
}
```

---

## Middleware Express

```typescript
import { Request, Response, NextFunction } from 'express';

function rateLimitMiddleware(
  limiter: SlidingWindowRateLimiter,
  keyExtractor: (req: Request) => string = (req) => req.ip,
) {
  return (req: Request, res: Response, next: NextFunction) => {
    const key = keyExtractor(req);

    if (!limiter.isAllowed(key)) {
      const remaining = limiter.getRemainingRequests(key);
      const resetTime = limiter.getResetTime(key);

      res.set({
        'X-RateLimit-Limit': String(limiter.maxRequests),
        'X-RateLimit-Remaining': String(remaining),
        'X-RateLimit-Reset': String(Math.ceil(resetTime / 1000)),
        'Retry-After': String(Math.ceil(resetTime / 1000)),
      });

      return res.status(429).json({
        error: 'Too Many Requests',
        retryAfter: Math.ceil(resetTime / 1000),
      });
    }

    next();
  };
}

// Usage
const apiLimiter = new SlidingWindowRateLimiter(60000, 100);

app.use('/api', rateLimitMiddleware(apiLimiter));

// Rate limit par utilisateur
app.use('/api/premium', rateLimitMiddleware(
  new SlidingWindowRateLimiter(60000, 1000),
  (req) => req.user?.id ?? req.ip,
));
```

---

## Comparaison des algorithmes

| Algorithme | Precision | Memoire | Burst | Complexite |
|------------|-----------|---------|-------|------------|
| Token Bucket | Moyenne | O(1) | Permet burst | Simple |
| Leaky Bucket | Haute | O(n) | Lisse | Moyenne |
| Fixed Window | Basse | O(1) | Double burst possible | Simple |
| Sliding Log | Haute | O(n) | Precis | Complexe |
| Sliding Counter | Moyenne | O(1) | Approximatif | Moyenne |

---

## Quand utiliser

- APIs publiques (protection DoS)
- Endpoints couteux (generation, AI)
- Fair usage entre utilisateurs
- Prevention de l'abus
- Quota par tier de service

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [Bulkhead](bulkhead.md) | Limite concurrence vs debit |
| [Circuit Breaker](circuit-breaker.md) | Complementaire |
| Throttling | Synonyme cote client |
| Backpressure | Cote producteur |

---

## Sources

- [Rate Limiting Strategies](https://blog.cloudflare.com/counting-things-a-lot-of-different-things/)
- [Token Bucket Algorithm](https://en.wikipedia.org/wiki/Token_bucket)
- [Google Cloud - Rate Limiting](https://cloud.google.com/architecture/rate-limiting-strategies-techniques)
