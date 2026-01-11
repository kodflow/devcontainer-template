# Ambassador Pattern

> Creer des services proxy pour gerer les communications entre clients et services.

## Principe

```
                          ┌──────────────────────────────┐
                          │         AMBASSADOR           │
                          │                              │
┌─────────┐               │  ┌─────────┐   ┌─────────┐  │   ┌─────────┐
│  Client │ ─────────────▶│  │  Proxy  │───│ Logging │  │──▶│ Service │
└─────────┘               │  └─────────┘   └─────────┘  │   └─────────┘
                          │       │                     │
                          │       ▼                     │
                          │  ┌─────────┐   ┌─────────┐  │
                          │  │ Retry   │   │ Monitor │  │
                          │  └─────────┘   └─────────┘  │
                          └──────────────────────────────┘
```

L'Ambassador agit comme un sidecar qui decharge les fonctionnalites cross-cutting du service principal.

## Responsabilites

| Fonction | Description |
|----------|-------------|
| **Logging** | Journalisation des requetes/reponses |
| **Retry** | Relances automatiques |
| **Circuit Breaking** | Protection pannes cascade |
| **Authentication** | Verification tokens |
| **Rate Limiting** | Controle du debit |
| **Monitoring** | Metriques et traces |

## Exemple TypeScript

```typescript
interface AmbassadorConfig {
  retries: number;
  timeout: number;
  logging: boolean;
  circuitBreaker?: CircuitBreakerConfig;
}

class Ambassador {
  private circuitBreaker: CircuitBreaker;

  constructor(
    private readonly targetUrl: string,
    private readonly config: AmbassadorConfig,
  ) {
    if (config.circuitBreaker) {
      this.circuitBreaker = new CircuitBreaker(config.circuitBreaker);
    }
  }

  async forward<T>(request: Request): Promise<T> {
    const startTime = Date.now();

    // Logging entree
    if (this.config.logging) {
      console.log(`[Ambassador] ${request.method} ${request.url}`);
    }

    // Retry wrapper
    let lastError: Error;
    for (let attempt = 0; attempt <= this.config.retries; attempt++) {
      try {
        const response = await this.executeWithTimeout(request);

        // Logging sortie
        if (this.config.logging) {
          console.log(`[Ambassador] Response in ${Date.now() - startTime}ms`);
        }

        return response;
      } catch (error) {
        lastError = error as Error;
        if (attempt < this.config.retries) {
          await this.delay(Math.pow(2, attempt) * 100);
        }
      }
    }

    throw lastError!;
  }

  private async executeWithTimeout(request: Request): Promise<any> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.config.timeout);

    try {
      if (this.circuitBreaker) {
        return await this.circuitBreaker.call(() =>
          fetch(this.targetUrl + request.url, {
            ...request,
            signal: controller.signal,
          })
        );
      }

      return await fetch(this.targetUrl + request.url, {
        ...request,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeout);
    }
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
```

## Usage avec Kubernetes Sidecar

```yaml
# Deployment avec Ambassador sidecar
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
        - name: main-service
          image: my-service:latest
          ports:
            - containerPort: 8080
        - name: ambassador
          image: envoy:latest
          ports:
            - containerPort: 9000
```

## Cas d'usage

| Scenario | Benefice |
|----------|----------|
| Microservices legacy | Ajouter resilience sans modifier le code |
| Multi-cloud | Abstraction des specifites cloud |
| Compliance | Logging centralise pour audit |
| Migration | Transition progressive vers nouveaux protocoles |

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Ambassador trop lourd | Latence excessive | Garder leger, deleguer au mesh |
| Logique metier | Couplage fort | Ambassador = cross-cutting seulement |
| Sans monitoring | Debugging difficile | Toujours exposer des metriques |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Sidecar | Implementation concrete |
| Circuit Breaker | Fonctionnalite embarquee |
| Gateway | Alternative centralisee |
| Service Mesh | Evolution a grande echelle |

## Sources

- [Microsoft - Ambassador Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/ambassador)
- [Envoy Proxy](https://www.envoyproxy.io/)
