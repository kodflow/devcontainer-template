# Gateway Routing Pattern

> Router les requetes vers les services backend appropries.

## Principe

```
┌────────────────────────────────────────────────────────────────┐
│                        API GATEWAY                              │
│                                                                 │
│    Routing Rules:                                               │
│    /api/users/*     ──▶  User Service                          │
│    /api/orders/*    ──▶  Order Service                         │
│    /api/products/*  ──▶  Product Service                       │
│    /v2/*            ──▶  New API Version                       │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
         │               │                │               │
         ▼               ▼                ▼               ▼
    ┌─────────┐    ┌─────────┐     ┌─────────┐     ┌─────────┐
    │  User   │    │  Order  │     │ Product │     │  API    │
    │ Service │    │ Service │     │ Service │     │   v2    │
    └─────────┘    └─────────┘     └─────────┘     └─────────┘
```

## Types de routage

| Type | Description | Exemple |
|------|-------------|---------|
| **Path-based** | Route selon le chemin URL | `/api/users/*` → User Service |
| **Header-based** | Route selon headers | `X-Version: 2` → API v2 |
| **Query-based** | Route selon query params | `?region=eu` → EU cluster |
| **Method-based** | Route selon methode HTTP | `POST /orders` → Write Service |
| **Weight-based** | Distribution ponderee | 90% stable, 10% canary |

## Exemple TypeScript

```typescript
interface RoutingRule {
  name: string;
  match: (request: Request) => boolean;
  target: string;
  weight?: number;
  transform?: (request: Request) => Request;
}

class GatewayRouter {
  private rules: RoutingRule[] = [];

  addRule(rule: RoutingRule): this {
    this.rules.push(rule);
    return this;
  }

  async route(request: Request): Promise<Response> {
    const matchedRules = this.rules.filter(rule => rule.match(request));

    if (matchedRules.length === 0) {
      return new Response('Not Found', { status: 404 });
    }

    // Selection de la route (avec support poids)
    const selectedRule = this.selectByWeight(matchedRules);

    // Transformation optionnelle
    const targetRequest = selectedRule.transform
      ? selectedRule.transform(request)
      : request;

    // Forward vers le service
    return this.forward(targetRequest, selectedRule.target);
  }

  private selectByWeight(rules: RoutingRule[]): RoutingRule {
    const totalWeight = rules.reduce((sum, r) => sum + (r.weight ?? 100), 0);
    let random = Math.random() * totalWeight;

    for (const rule of rules) {
      random -= rule.weight ?? 100;
      if (random <= 0) return rule;
    }

    return rules[0];
  }

  private async forward(request: Request, target: string): Promise<Response> {
    const url = new URL(request.url);
    const targetUrl = `${target}${url.pathname}${url.search}`;

    return fetch(targetUrl, {
      method: request.method,
      headers: request.headers,
      body: request.body,
    });
  }
}
```

## Configuration des routes

```typescript
const router = new GatewayRouter();

// Path-based routing
router.addRule({
  name: 'user-service',
  match: (req) => new URL(req.url).pathname.startsWith('/api/users'),
  target: 'http://user-service:8080',
  transform: (req) => {
    const url = new URL(req.url);
    url.pathname = url.pathname.replace('/api/users', '/users');
    return new Request(url.toString(), req);
  },
});

// Header-based versioning
router.addRule({
  name: 'api-v2',
  match: (req) => req.headers.get('API-Version') === '2',
  target: 'http://api-v2:8080',
});

// Canary deployment (10% traffic)
router.addRule({
  name: 'orders-canary',
  match: (req) => new URL(req.url).pathname.startsWith('/api/orders'),
  target: 'http://order-service-canary:8080',
  weight: 10,
});

router.addRule({
  name: 'orders-stable',
  match: (req) => new URL(req.url).pathname.startsWith('/api/orders'),
  target: 'http://order-service:8080',
  weight: 90,
});

// Region-based routing
router.addRule({
  name: 'eu-region',
  match: (req) => {
    const geo = req.headers.get('CF-IPCountry');
    return ['FR', 'DE', 'ES', 'IT'].includes(geo ?? '');
  },
  target: 'http://api-eu.internal:8080',
});
```

## Strategies avancees

### A/B Testing

```typescript
router.addRule({
  name: 'ab-test-checkout',
  match: (req) => {
    const userId = extractUserId(req);
    return hashUserId(userId) % 100 < 50; // 50% groupe A
  },
  target: 'http://checkout-variant-a:8080',
});
```

### Blue-Green Deployment

```typescript
const deploymentConfig = {
  active: 'blue', // ou 'green'
};

router.addRule({
  name: 'blue-green',
  match: () => true,
  target: deploymentConfig.active === 'blue'
    ? 'http://service-blue:8080'
    : 'http://service-green:8080',
});
```

### Circuit Breaker Integration

```typescript
router.addRule({
  name: 'with-circuit-breaker',
  match: (req) => req.url.includes('/critical'),
  target: 'http://critical-service:8080',
  transform: async (req) => {
    if (circuitBreaker.isOpen()) {
      throw new ServiceUnavailableError();
    }
    return req;
  },
});
```

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Regles trop specifiques | Maintenance difficile | Grouper par service |
| Logique metier | Couplage gateway/domaine | Routage technique seulement |
| Sans fallback | Echec silencieux | Route par defaut + monitoring |
| Ordre non deterministe | Comportement imprevisible | Priorite explicite |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Gateway Aggregation | Complementaire |
| Gateway Offloading | Complementaire |
| Service Discovery | Resolution dynamique |
| Load Balancer | Distribution intra-service |

## Sources

- [Microsoft - Gateway Routing](https://learn.microsoft.com/en-us/azure/architecture/patterns/gateway-routing)
- [Traefik](https://traefik.io/traefik/)
- [Kong Routing](https://docs.konghq.com/gateway/latest/get-started/configure-routes/)
