# Gateway Offloading Pattern

> Decharger les fonctionnalites partagees des services vers le gateway.

## Principe

```
┌────────────────────────────────────────────────────────────────────┐
│                         API GATEWAY                                 │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │    SSL      │  │    Auth     │  │   Logging   │  │   Rate    │  │
│  │ Termination │  │   (OAuth)   │  │  & Tracing  │  │  Limiting │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘  │
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │
│  │   Caching   │  │ Compression │  │    CORS     │  │  Metrics  │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘  │
└────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
     ┌────────────────────────┬────────────────────────┐
     │                        │                        │
     ▼                        ▼                        ▼
┌─────────┐             ┌─────────┐             ┌─────────┐
│ Service │             │ Service │             │ Service │
│    A    │             │    B    │             │    C    │
│ (leger) │             │ (leger) │             │ (leger) │
└─────────┘             └─────────┘             └─────────┘
```

## Fonctionnalites dechargeables

| Fonctionnalite | Avantage au Gateway | Complexite |
|----------------|---------------------|------------|
| **SSL Termination** | Certificats centralises | Faible |
| **Authentication** | Politique uniforme | Moyenne |
| **Rate Limiting** | Protection globale | Faible |
| **Caching** | Reduction charge backend | Moyenne |
| **Compression** | Bande passante optimisee | Faible |
| **CORS** | Configuration unique | Faible |
| **Request Validation** | Rejet precoce | Moyenne |
| **Response Transformation** | Format uniforme | Haute |

## Exemple TypeScript

```typescript
interface OffloadingMiddleware {
  name: string;
  execute: (ctx: GatewayContext, next: () => Promise<void>) => Promise<void>;
}

class GatewayOffloader {
  private middlewares: OffloadingMiddleware[] = [];

  use(middleware: OffloadingMiddleware): this {
    this.middlewares.push(middleware);
    return this;
  }

  async handle(request: Request): Promise<Response> {
    const ctx = new GatewayContext(request);

    const executeMiddleware = async (index: number): Promise<void> => {
      if (index < this.middlewares.length) {
        await this.middlewares[index].execute(ctx, () =>
          executeMiddleware(index + 1)
        );
      }
    };

    await executeMiddleware(0);
    return ctx.response;
  }
}

// Middlewares d'offloading
const sslTermination: OffloadingMiddleware = {
  name: 'ssl-termination',
  async execute(ctx, next) {
    // SSL gere par le load balancer/gateway
    ctx.request.headers.set('X-Forwarded-Proto', 'https');
    await next();
  },
};

const authMiddleware: OffloadingMiddleware = {
  name: 'authentication',
  async execute(ctx, next) {
    const token = ctx.request.headers.get('Authorization');

    if (!token) {
      ctx.response = new Response('Unauthorized', { status: 401 });
      return;
    }

    const user = await validateToken(token);
    ctx.user = user;
    ctx.request.headers.set('X-User-Id', user.id);

    await next();
  },
};

const rateLimiter: OffloadingMiddleware = {
  name: 'rate-limiting',
  async execute(ctx, next) {
    const key = ctx.user?.id ?? ctx.request.headers.get('X-Forwarded-For');

    if (await isRateLimited(key)) {
      ctx.response = new Response('Too Many Requests', { status: 429 });
      return;
    }

    await incrementCounter(key);
    await next();
  },
};

const caching: OffloadingMiddleware = {
  name: 'caching',
  async execute(ctx, next) {
    if (ctx.request.method === 'GET') {
      const cached = await cache.get(ctx.request.url);
      if (cached) {
        ctx.response = new Response(cached, {
          headers: { 'X-Cache': 'HIT' },
        });
        return;
      }
    }

    await next();

    if (ctx.request.method === 'GET' && ctx.response.ok) {
      await cache.set(ctx.request.url, await ctx.response.clone().text());
    }
  },
};

const compression: OffloadingMiddleware = {
  name: 'compression',
  async execute(ctx, next) {
    await next();

    const acceptEncoding = ctx.request.headers.get('Accept-Encoding') ?? '';

    if (acceptEncoding.includes('gzip') && ctx.response.body) {
      const compressed = await gzip(await ctx.response.text());
      ctx.response = new Response(compressed, {
        headers: { 'Content-Encoding': 'gzip' },
      });
    }
  },
};
```

## Configuration Gateway

```typescript
// Setup du gateway avec offloading
const gateway = new GatewayOffloader()
  .use(sslTermination)
  .use(authMiddleware)
  .use(rateLimiter)
  .use(caching)
  .use(compression)
  .use(logging)
  .use(metrics);

// Les services backend restent simples
// Plus besoin de gerer : SSL, auth, rate limit, cache, compression
```

## Benefices

| Aspect | Sans Offloading | Avec Offloading |
|--------|-----------------|-----------------|
| **Code service** | Complexe | Simple |
| **Certificats SSL** | N services | 1 gateway |
| **Policies auth** | Dupliquees | Centralisees |
| **Mise a jour** | N deploiements | 1 deploiement |
| **Monitoring** | Fragmente | Unifie |

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Gateway trop charge | SPOF, latence | Distribuer, scaler |
| Logique metier | Couplage | Garder cross-cutting seulement |
| Sans fallback | Gateway down = tout down | Resilience, multi-instance |
| Over-caching | Donnees stales | TTL adapte, invalidation |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Gateway Routing | Complementaire |
| Gateway Aggregation | Complementaire |
| Ambassador | Alternative distribuee |
| Service Mesh | Evolution a grande echelle |

## Sources

- [Microsoft - Gateway Offloading](https://learn.microsoft.com/en-us/azure/architecture/patterns/gateway-offloading)
- [Kong Gateway](https://konghq.com/)
- [Nginx](https://nginx.org/en/docs/)
