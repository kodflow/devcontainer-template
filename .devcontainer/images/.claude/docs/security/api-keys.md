# API Keys Authentication

> Authentification simple par cle secrete pour les APIs.

## Principe

```
┌─────────────┐                    ┌─────────────┐
│   Client    │  X-API-Key: xxx    │   Server    │
│             │───────────────────►│             │
│             │                    │ - Validate  │
│             │                    │ - Rate limit│
│             │                    │ - Log usage │
└─────────────┘                    └─────────────┘
```

## Implementation TypeScript

```typescript
import crypto from 'crypto';

interface ApiKey {
  id: string;
  hashedKey: string;
  name: string;
  ownerId: string;
  scopes: string[];
  rateLimit: number;
  createdAt: Date;
  expiresAt: Date | null;
  lastUsedAt: Date | null;
  revokedAt: Date | null;
}

class ApiKeyService {
  private readonly prefix = 'sk_live_'; // Prefix identifiable
  private readonly keyLength = 32;

  async generate(
    ownerId: string,
    name: string,
    scopes: string[],
    expiresInDays?: number,
  ): Promise<{ key: string; id: string }> {
    // Generate random key
    const rawKey = crypto.randomBytes(this.keyLength).toString('hex');
    const fullKey = `${this.prefix}${rawKey}`;

    // Hash for storage (never store plain key)
    const hashedKey = this.hash(fullKey);

    const apiKey: ApiKey = {
      id: crypto.randomUUID(),
      hashedKey,
      name,
      ownerId,
      scopes,
      rateLimit: 1000, // requests per hour
      createdAt: new Date(),
      expiresAt: expiresInDays
        ? new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000)
        : null,
      lastUsedAt: null,
      revokedAt: null,
    };

    await this.store.save(apiKey);

    // Key returned ONCE - user must save it
    return { key: fullKey, id: apiKey.id };
  }

  async validate(key: string): Promise<ApiKey | null> {
    // Check prefix
    if (!key.startsWith(this.prefix)) {
      return null;
    }

    const hashedKey = this.hash(key);
    const apiKey = await this.store.findByHash(hashedKey);

    if (!apiKey) return null;
    if (apiKey.revokedAt) return null;
    if (apiKey.expiresAt && new Date() > apiKey.expiresAt) return null;

    // Update last used (async, don't wait)
    this.store.updateLastUsed(apiKey.id).catch(console.error);

    return apiKey;
  }

  async revoke(id: string): Promise<void> {
    await this.store.update(id, { revokedAt: new Date() });
  }

  private hash(key: string): string {
    return crypto.createHash('sha256').update(key).digest('hex');
  }
}
```

## Middleware Express avec Rate Limiting

```typescript
import rateLimit from 'express-rate-limit';

function apiKeyMiddleware(apiKeyService: ApiKeyService) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const apiKey =
      req.headers['x-api-key'] ||
      req.headers.authorization?.replace('Bearer ', '');

    if (!apiKey || typeof apiKey !== 'string') {
      return res.status(401).json({
        error: 'API key required',
        code: 'MISSING_API_KEY',
      });
    }

    const key = await apiKeyService.validate(apiKey);

    if (!key) {
      return res.status(401).json({
        error: 'Invalid or expired API key',
        code: 'INVALID_API_KEY',
      });
    }

    // Attach to request
    req.apiKey = key;
    req.ownerId = key.ownerId;
    req.scopes = key.scopes;

    next();
  };
}

// Per-key rate limiting
class ApiKeyRateLimiter {
  private limits = new Map<string, { count: number; resetAt: number }>();

  async check(keyId: string, limit: number): Promise<{
    allowed: boolean;
    remaining: number;
    resetAt: number;
  }> {
    const now = Date.now();
    const windowMs = 60 * 60 * 1000; // 1 hour

    let data = this.limits.get(keyId);

    if (!data || now > data.resetAt) {
      data = { count: 0, resetAt: now + windowMs };
      this.limits.set(keyId, data);
    }

    data.count++;

    return {
      allowed: data.count <= limit,
      remaining: Math.max(0, limit - data.count),
      resetAt: data.resetAt,
    };
  }
}

// Combined middleware
function rateLimitedApiKey(
  apiKeyService: ApiKeyService,
  rateLimiter: ApiKeyRateLimiter,
) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const apiKey = req.headers['x-api-key'] as string;
    const key = await apiKeyService.validate(apiKey);

    if (!key) {
      return res.status(401).json({ error: 'Invalid API key' });
    }

    const { allowed, remaining, resetAt } = await rateLimiter.check(
      key.id,
      key.rateLimit,
    );

    res.setHeader('X-RateLimit-Limit', key.rateLimit);
    res.setHeader('X-RateLimit-Remaining', remaining);
    res.setHeader('X-RateLimit-Reset', Math.ceil(resetAt / 1000));

    if (!allowed) {
      return res.status(429).json({
        error: 'Rate limit exceeded',
        retryAfter: Math.ceil((resetAt - Date.now()) / 1000),
      });
    }

    req.apiKey = key;
    next();
  };
}
```

## Scope Validation

```typescript
function requireScopes(...requiredScopes: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    const keyScopes = req.scopes || [];

    const hasAllScopes = requiredScopes.every(
      (scope) => keyScopes.includes(scope) || keyScopes.includes('*'),
    );

    if (!hasAllScopes) {
      return res.status(403).json({
        error: 'Insufficient permissions',
        required: requiredScopes,
        actual: keyScopes,
      });
    }

    next();
  };
}

// Usage
app.get('/users', requireScopes('users:read'), getUsers);
app.post('/users', requireScopes('users:write'), createUser);
app.delete('/users/:id', requireScopes('users:delete'), deleteUser);
```

## Librairies recommandees

| Package | Usage |
|---------|-------|
| `uuid` | Generation IDs uniques |
| `express-rate-limit` | Rate limiting simple |
| `rate-limiter-flexible` | Rate limiting Redis |

## Erreurs communes

| Erreur | Impact | Solution |
|--------|--------|----------|
| Stocker key en clair | Breach = acces total | Hasher avec SHA-256 |
| Key dans URL params | Leakage logs/referer | Header `X-API-Key` |
| Pas de rate limiting | DoS, abuse | Limiter par key |
| Key sans expiration | Key compromise permanent | Expiration + rotation |
| Pas de scopes | Over-permission | Scopes granulaires |
| Key shared entre services | Blast radius large | Key par service/usage |

## Bonnes pratiques

```typescript
// 1. Prefixes identifiables
const prefixes = {
  live: 'sk_live_', // Production
  test: 'sk_test_', // Development
  pub: 'pk_', // Public (limited scope)
};

// 2. Key rotation
class KeyRotation {
  async rotate(oldKeyId: string): Promise<{ newKey: string }> {
    const oldKey = await this.store.get(oldKeyId);

    // Create new key with same config
    const { key } = await this.generate(
      oldKey.ownerId,
      `${oldKey.name} (rotated)`,
      oldKey.scopes,
    );

    // Grace period - old key valid for 24h
    await this.store.update(oldKeyId, {
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
    });

    return { newKey: key };
  }
}

// 3. Usage logging
interface ApiKeyUsage {
  keyId: string;
  endpoint: string;
  method: string;
  statusCode: number;
  timestamp: Date;
  ip: string;
}
```

## Quand utiliser

| Scenario | Recommande |
|----------|------------|
| APIs publiques (third-party) | Oui |
| Integrations simples | Oui |
| Machine-to-machine | Oui (ou Client Credentials) |
| User authentication | Non (preferer OAuth/sessions) |
| Browser/frontend | Non (key exposee) |

## Patterns lies

- **OAuth 2.0 Client Credentials** : Alternative plus securisee pour M2M
- **JWT** : Peut completer API keys pour authorization
- **Rate Limiting** : Indispensable avec API keys

## Sources

- [Stripe API Keys Design](https://stripe.com/docs/keys)
- [GitHub API Token Design](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
