# Circuit Breaker Pattern

> Prévenir les pannes en cascade dans les systèmes distribués.

## Principe

```
        ┌──────────────────────────────────────────────────────┐
        │                    CIRCUIT BREAKER                    │
        │                                                       │
        │   CLOSED ──────▶ OPEN ──────▶ HALF-OPEN              │
        │     │              │              │                   │
        │     │ failures     │ timeout      │ success           │
        │     │ > threshold  │ expires      │ → CLOSED          │
        │     │              │              │ failure           │
        │     │              │              │ → OPEN            │
        │     ▼              ▼              ▼                   │
        └──────────────────────────────────────────────────────┘

┌─────────┐         ┌──────────────┐         ┌─────────┐
│ Service │ ──────▶ │Circuit Breaker│ ──────▶ │ Remote  │
│   A     │         │              │         │ Service │
└─────────┘         └──────────────┘         └─────────┘
```

## États

| État | Comportement |
|------|--------------|
| **CLOSED** | Requêtes passent normalement. Compte les échecs. |
| **OPEN** | Requêtes échouent immédiatement (fail fast). |
| **HALF-OPEN** | Permet quelques requêtes test. |

## Exemple TypeScript

```typescript
class CircuitBreaker {
  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';
  private failures = 0;
  private lastFailure: Date | null = null;

  constructor(
    private readonly threshold = 5,
    private readonly timeout = 30000, // 30s
  ) {}

  async call<T>(fn: () => Promise<T>): Promise<T> {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailure!.getTime() > this.timeout) {
        this.state = 'HALF_OPEN';
      } else {
        throw new CircuitOpenError();
      }
    }

    try {
      const result = await fn();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess() {
    this.failures = 0;
    this.state = 'CLOSED';
  }

  private onFailure() {
    this.failures++;
    this.lastFailure = new Date();

    if (this.failures >= this.threshold) {
      this.state = 'OPEN';
    }
  }
}
```

## Usage

```typescript
const breaker = new CircuitBreaker(5, 30000);

async function callExternalService(id: string) {
  return breaker.call(async () => {
    const response = await fetch(`https://api.example.com/users/${id}`);
    if (!response.ok) throw new Error('Service unavailable');
    return response.json();
  });
}

// Utilisation avec fallback
async function getUser(id: string) {
  try {
    return await callExternalService(id);
  } catch (error) {
    if (error instanceof CircuitOpenError) {
      return getCachedUser(id); // Fallback
    }
    throw error;
  }
}
```

## Configuration recommandée

| Paramètre | Valeur typique | Description |
|-----------|----------------|-------------|
| `threshold` | 5-10 | Échecs avant ouverture |
| `timeout` | 30-60s | Temps avant HALF_OPEN |
| `halfOpenRequests` | 1-3 | Requêtes test en HALF_OPEN |

## Librairies

| Langage | Librairie |
|---------|-----------|
| Node.js | `opossum`, `cockatiel` |
| Java | Resilience4j, Hystrix (deprecated) |
| Go | `sony/gobreaker` |
| Python | `pybreaker` |

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Retry | Avant circuit breaker |
| Bulkhead | Isolation des ressources |
| Fallback | Alternative quand circuit ouvert |
| Health Check | Monitoring du circuit |

## Sources

- [Microsoft - Circuit Breaker](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)
- [Martin Fowler - Circuit Breaker](https://martinfowler.com/bliki/CircuitBreaker.html)
