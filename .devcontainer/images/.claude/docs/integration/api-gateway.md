# API Gateway Pattern

> Point d'entree unique pour tous les clients, centralisant authentification, routage et policies.

---

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                      API GATEWAY                                 │
│                                                                  │
│   Clients              Gateway                Services           │
│                                                                  │
│  ┌────────┐         ┌─────────────┐        ┌──────────┐         │
│  │  Web   │────────►│             │───────►│ Users    │         │
│  └────────┘         │             │        └──────────┘         │
│                     │             │                              │
│  ┌────────┐         │  ┌───────┐  │        ┌──────────┐         │
│  │ Mobile │────────►│  │ Auth  │  │───────►│ Orders   │         │
│  └────────┘         │  │ Rate  │  │        └──────────┘         │
│                     │  │ Route │  │                              │
│  ┌────────┐         │  │ Cache │  │        ┌──────────┐         │
│  │  IoT   │────────►│  └───────┘  │───────►│ Products │         │
│  └────────┘         │             │        └──────────┘         │
│                     └─────────────┘                              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Responsabilites

| Fonction | Description |
|----------|-------------|
| **Routing** | Diriger les requetes vers les bons services |
| **Authentication** | Valider les tokens, API keys |
| **Authorization** | Verifier les permissions |
| **Rate Limiting** | Limiter le debit par client |
| **Caching** | Cache des reponses |
| **Request/Response Transformation** | Adapter les formats |
| **Load Balancing** | Distribuer la charge |
| **SSL Termination** | Gerer les certificats |
| **Logging/Metrics** | Observabilite centralisee |

---

## Implementation TypeScript

### Gateway basique

```typescript
import express, { Request, Response, NextFunction } from 'express';
import httpProxy from 'http-proxy-middleware';

interface RouteConfig {
  path: string;
  target: string;
  auth: boolean;
  rateLimit?: { windowMs: number; max: number };
  cache?: { ttl: number };
}

class ApiGateway {
  private readonly app = express();
  private readonly routes: RouteConfig[] = [];

  constructor(private readonly config: { port: number }) {
    this.setupMiddleware();
  }

  private setupMiddleware(): void {
    this.app.use(express.json());
    this.app.use(this.loggingMiddleware);
    this.app.use(this.corsMiddleware);
  }

  private loggingMiddleware = (req: Request, res: Response, next: NextFunction) => {
    const start = Date.now();
    res.on('finish', () => {
      console.log({
        method: req.method,
        path: req.path,
        status: res.statusCode,
        duration: Date.now() - start,
        ip: req.ip,
      });
    });
    next();
  };

  private corsMiddleware = (req: Request, res: Response, next: NextFunction) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') {
      return res.sendStatus(200);
    }
    next();
  };

  registerRoute(config: RouteConfig): void {
    this.routes.push(config);

    const middlewares: express.RequestHandler[] = [];

    // Authentication
    if (config.auth) {
      middlewares.push(this.authMiddleware);
    }

    // Rate limiting
    if (config.rateLimit) {
      middlewares.push(this.createRateLimiter(config.rateLimit));
    }

    // Caching
    if (config.cache) {
      middlewares.push(this.createCacheMiddleware(config.cache));
    }

    // Proxy
    const proxy = httpProxy.createProxyMiddleware({
      target: config.target,
      changeOrigin: true,
      pathRewrite: { [`^${config.path}`]: '' },
    });

    this.app.use(config.path, ...middlewares, proxy);
  }

  private authMiddleware = async (req: Request, res: Response, next: NextFunction) => {
    const token = req.headers.authorization?.replace('Bearer ', '');

    if (!token) {
      return res.status(401).json({ error: 'Missing authorization token' });
    }

    try {
      const user = await this.validateToken(token);
      (req as any).user = user;
      next();
    } catch (error) {
      res.status(401).json({ error: 'Invalid token' });
    }
  };

  private async validateToken(token: string): Promise<User> {
    // Valider avec le service d'authentification
    const response = await fetch('http://auth-service/validate', {
      headers: { Authorization: `Bearer ${token}` },
    });

    if (!response.ok) throw new Error('Invalid token');
    return response.json();
  }

  private createRateLimiter(config: { windowMs: number; max: number }) {
    const requests = new Map<string, number[]>();

    return (req: Request, res: Response, next: NextFunction) => {
      const key = req.ip;
      const now = Date.now();
      const windowStart = now - config.windowMs;

      let timestamps = requests.get(key) ?? [];
      timestamps = timestamps.filter((t) => t > windowStart);

      if (timestamps.length >= config.max) {
        return res.status(429).json({ error: 'Too many requests' });
      }

      timestamps.push(now);
      requests.set(key, timestamps);
      next();
    };
  }

  private createCacheMiddleware(config: { ttl: number }) {
    const cache = new Map<string, { data: any; expires: number }>();

    return (req: Request, res: Response, next: NextFunction) => {
      if (req.method !== 'GET') return next();

      const key = req.originalUrl;
      const cached = cache.get(key);

      if (cached && cached.expires > Date.now()) {
        return res.json(cached.data);
      }

      const originalJson = res.json.bind(res);
      res.json = (data: any) => {
        cache.set(key, { data, expires: Date.now() + config.ttl });
        return originalJson(data);
      };

      next();
    };
  }

  start(): void {
    this.app.listen(this.config.port, () => {
      console.log(`API Gateway running on port ${this.config.port}`);
    });
  }
}
```

---

### Configuration et usage

```typescript
const gateway = new ApiGateway({ port: 3000 });

// Routes publiques
gateway.registerRoute({
  path: '/api/products',
  target: 'http://product-service:8080',
  auth: false,
  cache: { ttl: 60000 }, // 1 minute
});

// Routes authentifiees
gateway.registerRoute({
  path: '/api/users',
  target: 'http://user-service:8080',
  auth: true,
  rateLimit: { windowMs: 60000, max: 100 },
});

gateway.registerRoute({
  path: '/api/orders',
  target: 'http://order-service:8080',
  auth: true,
  rateLimit: { windowMs: 60000, max: 50 },
});

// Routes admin (rate limit strict)
gateway.registerRoute({
  path: '/api/admin',
  target: 'http://admin-service:8080',
  auth: true,
  rateLimit: { windowMs: 60000, max: 10 },
});

gateway.start();
```

---

### Request/Response Transformation

```typescript
interface TransformConfig {
  request?: (req: Request) => Request;
  response?: (data: any) => any;
}

class TransformingGateway extends ApiGateway {
  registerTransformRoute(
    config: RouteConfig & { transform: TransformConfig },
  ): void {
    this.app.use(config.path, async (req, res, next) => {
      // Transform request
      if (config.transform.request) {
        config.transform.request(req);
      }

      // Intercept response
      if (config.transform.response) {
        const originalJson = res.json.bind(res);
        res.json = (data: any) => {
          const transformed = config.transform.response!(data);
          return originalJson(transformed);
        };
      }

      next();
    });
  }
}

// Usage: Adapter un legacy API
gateway.registerTransformRoute({
  path: '/api/v2/users',
  target: 'http://legacy-user-service:8080',
  auth: true,
  transform: {
    request: (req) => {
      // Convertir snake_case en camelCase
      if (req.body) {
        req.body = snakeToCamel(req.body);
      }
      return req;
    },
    response: (data) => {
      // Ajouter des champs, masquer d'autres
      return {
        ...camelToSnake(data),
        _links: {
          self: `/api/v2/users/${data.id}`,
        },
      };
    },
  },
});
```

---

### API Aggregation

```typescript
class AggregatingGateway extends ApiGateway {
  registerAggregateRoute(
    path: string,
    aggregator: (req: Request) => Promise<any>,
  ): void {
    this.app.get(path, async (req, res) => {
      try {
        const data = await aggregator(req);
        res.json(data);
      } catch (error) {
        res.status(500).json({ error: 'Aggregation failed' });
      }
    });
  }
}

// Usage: Dashboard agregation
gateway.registerAggregateRoute('/api/dashboard', async (req) => {
  const userId = (req as any).user.id;

  // Appels paralleles a plusieurs services
  const [user, orders, notifications] = await Promise.all([
    fetch(`http://user-service/users/${userId}`).then((r) => r.json()),
    fetch(`http://order-service/users/${userId}/orders?limit=5`).then((r) => r.json()),
    fetch(`http://notification-service/users/${userId}/unread`).then((r) => r.json()),
  ]);

  return {
    user: { id: user.id, name: user.name },
    recentOrders: orders,
    unreadNotifications: notifications.count,
    lastLogin: user.lastLoginAt,
  };
});
```

---

## Technologies

| Technologie | Type | Usage |
|-------------|------|-------|
| Kong | Open Source | Feature-rich, plugins |
| AWS API Gateway | Managed | Serverless, AWS integration |
| Apigee | Enterprise | Google Cloud, analytics |
| Traefik | Cloud Native | Docker/K8s native |
| NGINX | Web Server | Reverse proxy, load balancing |
| Express Gateway | Node.js | JavaScript ecosystem |

---

## Quand utiliser

- Microservices avec plusieurs clients
- Besoin de centraliser l'authentification
- Rate limiting et quotas par client
- Aggregation de donnees de plusieurs services
- Versionning d'API

---

## Quand NE PAS utiliser

- Application monolithique simple
- Communication service-to-service uniquement
- Latence critique (chaque hop ajoute du delai)
- Equipe trop petite pour maintenir

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [BFF](bff.md) | BFF derriere le gateway |
| [Sidecar](sidecar.md) | Alternative pour certaines fonctions |
| [Rate Limiting](../resilience/rate-limiting.md) | Implemente dans le gateway |
| [Circuit Breaker](../resilience/circuit-breaker.md) | Protection des backends |

---

## Sources

- [Microsoft - API Gateway](https://learn.microsoft.com/en-us/azure/architecture/microservices/design/gateway)
- [Kong - What is an API Gateway](https://konghq.com/learning-center/api-gateway)
- [NGINX - API Gateway](https://www.nginx.com/learn/api-gateway/)
