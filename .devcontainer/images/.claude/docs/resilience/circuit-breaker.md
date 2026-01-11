# Circuit Breaker Pattern

> Prevenir les pannes en cascade en arretant les appels vers un service defaillant.

---

## Principe

```
        ┌──────────────────────────────────────────────────────┐
        │                    CIRCUIT BREAKER                    │
        │                                                       │
        │   CLOSED ──────► OPEN ──────► HALF-OPEN              │
        │     │              │              │                   │
        │     │ failures     │ timeout      │ success           │
        │     │ > threshold  │ expires      │ → CLOSED          │
        │     │              │              │ failure           │
        │     │              │              │ → OPEN            │
        │     ▼              ▼              ▼                   │
        └──────────────────────────────────────────────────────┘

┌─────────┐         ┌──────────────┐         ┌─────────┐
│ Service │ ──────► │Circuit Breaker│ ──────► │ Remote  │
│   A     │         │              │         │ Service │
└─────────┘         └──────────────┘         └─────────┘
```

---

## Etats

| Etat | Comportement |
|------|--------------|
| **CLOSED** | Requetes passent normalement. Compte les echecs. |
| **OPEN** | Requetes echouent immediatement (fail fast). |
| **HALF-OPEN** | Permet quelques requetes test pour verifier la recovery. |

---

## Implementation TypeScript

```typescript
type CircuitState = 'CLOSED' | 'OPEN' | 'HALF_OPEN';

class CircuitBreakerError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'CircuitBreakerError';
  }
}

interface CircuitBreakerOptions {
  failureThreshold: number;    // Echecs avant ouverture
  successThreshold: number;    // Succes pour fermer
  timeout: number;             // Temps avant HALF_OPEN (ms)
  halfOpenRequests: number;    // Requetes test en HALF_OPEN
}

class CircuitBreaker {
  private state: CircuitState = 'CLOSED';
  private failures = 0;
  private successes = 0;
  private lastFailureTime: number | null = null;
  private halfOpenAttempts = 0;

  constructor(private readonly options: CircuitBreakerOptions) {}

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    if (!this.canExecute()) {
      throw new CircuitBreakerError('Circuit is OPEN');
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

  private canExecute(): boolean {
    if (this.state === 'CLOSED') {
      return true;
    }

    if (this.state === 'OPEN') {
      const elapsed = Date.now() - (this.lastFailureTime ?? 0);
      if (elapsed >= this.options.timeout) {
        this.transitionTo('HALF_OPEN');
        return true;
      }
      return false;
    }

    // HALF_OPEN: permettre un nombre limite de requetes
    return this.halfOpenAttempts < this.options.halfOpenRequests;
  }

  private onSuccess(): void {
    if (this.state === 'HALF_OPEN') {
      this.successes++;
      if (this.successes >= this.options.successThreshold) {
        this.transitionTo('CLOSED');
      }
    } else {
      this.failures = 0;
    }
  }

  private onFailure(): void {
    this.failures++;
    this.lastFailureTime = Date.now();

    if (this.state === 'HALF_OPEN') {
      this.transitionTo('OPEN');
    } else if (this.failures >= this.options.failureThreshold) {
      this.transitionTo('OPEN');
    }
  }

  private transitionTo(newState: CircuitState): void {
    console.log(`Circuit: ${this.state} → ${newState}`);
    this.state = newState;

    if (newState === 'CLOSED') {
      this.failures = 0;
      this.successes = 0;
    } else if (newState === 'HALF_OPEN') {
      this.halfOpenAttempts = 0;
      this.successes = 0;
    }
  }

  getState(): CircuitState {
    return this.state;
  }
}
```

---

## Usage avec fallback

```typescript
const circuitBreaker = new CircuitBreaker({
  failureThreshold: 5,
  successThreshold: 2,
  timeout: 30000,
  halfOpenRequests: 3,
});

async function getUserWithFallback(userId: string): Promise<User> {
  try {
    return await circuitBreaker.execute(async () => {
      const response = await fetch(`https://api.example.com/users/${userId}`);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return response.json();
    });
  } catch (error) {
    if (error instanceof CircuitBreakerError) {
      // Circuit ouvert: utiliser le cache
      return getCachedUser(userId);
    }
    throw error;
  }
}
```

---

## Configuration recommandee

| Parametre | Valeur typique | Description |
|-----------|----------------|-------------|
| `failureThreshold` | 5-10 | Echecs consecutifs avant ouverture |
| `successThreshold` | 2-3 | Succes en HALF_OPEN pour fermer |
| `timeout` | 30-60s | Duree avant passage en HALF_OPEN |
| `halfOpenRequests` | 1-3 | Requetes test en HALF_OPEN |

---

## Quand utiliser

- Appels vers des services externes (APIs, databases)
- Microservices avec dependances reseau
- Integration avec des systemes tiers instables
- Protection contre les pannes en cascade

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [Retry](retry.md) | Utiliser avant le circuit breaker |
| [Timeout](timeout.md) | Limiter le temps par tentative |
| [Bulkhead](bulkhead.md) | Isolation complementaire |
| [Health Check](health-check.md) | Monitoring du circuit |

---

## Librairies

| Langage | Librairie |
|---------|-----------|
| Node.js | `opossum`, `cockatiel` |
| Java | Resilience4j |
| Go | `sony/gobreaker` |
| Python | `pybreaker` |
| .NET | Polly |

---

## Sources

- [Microsoft - Circuit Breaker](https://learn.microsoft.com/en-us/azure/architecture/patterns/circuit-breaker)
- [Martin Fowler - Circuit Breaker](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Release It! - Michael Nygard](https://pragprog.com/titles/mnee2/release-it-second-edition/)
