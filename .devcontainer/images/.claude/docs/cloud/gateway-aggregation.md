# Gateway Aggregation Pattern

> Agreger plusieurs requetes backend en une seule requete client.

## Principe

```
                                    ┌─────────────────────────┐
                                    │    API GATEWAY          │
                                    │    (Aggregation)        │
┌─────────┐    1 requete            │                         │
│  Client │ ───────────────────────▶│  ┌───────────────────┐  │
└─────────┘                         │  │   Orchestrator    │  │
     ▲                              │  └─────────┬─────────┘  │
     │                              │            │            │
     │    1 reponse agregee         │    ┌───────┼───────┐    │
     └──────────────────────────────│    │       │       │    │
                                    │    ▼       ▼       ▼    │
                                    │  ┌───┐   ┌───┐   ┌───┐  │
                                    │  │ A │   │ B │   │ C │  │
                                    │  └───┘   └───┘   └───┘  │
                                    └─────────────────────────┘
                                           │       │       │
                                           ▼       ▼       ▼
                                    ┌─────────────────────────┐
                                    │      Backend Services    │
                                    └─────────────────────────┘
```

## Probleme resolu

```
AVANT (N requetes client):
┌────────┐                 ┌─────────┐
│ Client │ ──────────────▶ │ User    │
│        │ ──────────────▶ │ Orders  │
│        │ ──────────────▶ │ Payment │
│        │ ──────────────▶ │ Reviews │
└────────┘                 └─────────┘

APRES (1 requete agregee):
┌────────┐        ┌─────────┐        ┌─────────┐
│ Client │ ──────▶│ Gateway │ ──────▶│ Backend │
└────────┘        └─────────┘        └─────────┘
```

## Exemple TypeScript

```typescript
interface AggregationConfig {
  endpoints: {
    name: string;
    url: string;
    timeout?: number;
    required?: boolean;
  }[];
  parallelExecution: boolean;
}

class GatewayAggregator {
  constructor(private readonly config: AggregationConfig) {}

  async aggregate<T extends Record<string, any>>(
    context: RequestContext,
  ): Promise<T> {
    if (this.config.parallelExecution) {
      return this.aggregateParallel(context);
    }
    return this.aggregateSequential(context);
  }

  private async aggregateParallel<T>(context: RequestContext): Promise<T> {
    const promises = this.config.endpoints.map(async (endpoint) => {
      try {
        const response = await this.fetchWithTimeout(
          endpoint.url,
          endpoint.timeout ?? 5000,
          context,
        );
        return { name: endpoint.name, data: response, error: null };
      } catch (error) {
        if (endpoint.required) {
          throw error;
        }
        return { name: endpoint.name, data: null, error };
      }
    });

    const results = await Promise.all(promises);

    return results.reduce((acc, result) => {
      acc[result.name] = result.data;
      return acc;
    }, {} as T);
  }

  private async aggregateSequential<T>(context: RequestContext): Promise<T> {
    const result: Record<string, any> = {};

    for (const endpoint of this.config.endpoints) {
      try {
        result[endpoint.name] = await this.fetchWithTimeout(
          endpoint.url,
          endpoint.timeout ?? 5000,
          context,
        );
      } catch (error) {
        if (endpoint.required) throw error;
        result[endpoint.name] = null;
      }
    }

    return result as T;
  }

  private async fetchWithTimeout(
    url: string,
    timeout: number,
    context: RequestContext,
  ): Promise<any> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);

    try {
      const response = await fetch(url, {
        headers: { Authorization: context.authToken },
        signal: controller.signal,
      });
      return response.json();
    } finally {
      clearTimeout(timer);
    }
  }
}
```

## Usage

```typescript
// Configuration de l'agregation pour une page profil
const profileAggregator = new GatewayAggregator({
  parallelExecution: true,
  endpoints: [
    { name: 'user', url: '/api/users/{id}', required: true },
    { name: 'orders', url: '/api/users/{id}/orders', required: false },
    { name: 'reviews', url: '/api/users/{id}/reviews', required: false },
    { name: 'recommendations', url: '/api/recommend/{id}', timeout: 2000 },
  ],
});

// Endpoint agrege
app.get('/api/profile/:id', async (req, res) => {
  const profile = await profileAggregator.aggregate({
    authToken: req.headers.authorization,
    params: { id: req.params.id },
  });

  res.json(profile);
});

// Reponse agregee
// {
//   user: { id: 1, name: "John" },
//   orders: [{ id: 101, total: 99.99 }],
//   reviews: [{ rating: 5, comment: "..." }],
//   recommendations: [{ productId: 42 }]
// }
```

## Strategies de gestion d'erreur

| Strategie | Description | Cas d'usage |
|-----------|-------------|-------------|
| **Fail Fast** | Echouer si un service requis echoue | Donnees critiques |
| **Partial Response** | Retourner les donnees disponibles | Dashboard |
| **Fallback** | Utiliser cache/defaut si echec | UX optimale |
| **Timeout Racing** | Retourner ce qui arrive avant timeout | Performance |

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Aggregation synchrone | Latence = sum(latences) | Execution parallele |
| Sans timeout | Requete bloquee indefiniment | Timeout par endpoint |
| Trop de services | Fragilite, lenteur | Limiter a 5-7 max |
| Couplage fort | Gateway dependant du format | Transformation flexible |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Gateway Routing | Complementaire |
| Backend for Frontend (BFF) | Specialisation |
| Facade | Pattern GoF similaire |
| Circuit Breaker | Protection des appels |

## Sources

- [Microsoft - Gateway Aggregation](https://learn.microsoft.com/en-us/azure/architecture/patterns/gateway-aggregation)
- [Netflix Zuul](https://github.com/Netflix/zuul)
