# Retry Pattern

> Reessayer automatiquement les operations echouees avec backoff exponentiel et jitter.

---

## Principe

```
┌────────────────────────────────────────────────────────────────┐
│                      RETRY WITH BACKOFF                         │
│                                                                 │
│  Attempt 1    Attempt 2      Attempt 3        Attempt 4        │
│     │            │              │                │             │
│     ▼            ▼              ▼                ▼             │
│  ┌─────┐      ┌─────┐        ┌─────┐          ┌─────┐         │
│  │FAIL │─────►│FAIL │───────►│FAIL │─────────►│ OK  │         │
│  └─────┘      └─────┘        └─────┘          └─────┘         │
│     │            │              │                              │
│     ▼            ▼              ▼                              │
│   100ms        200ms          400ms     (exponential backoff)  │
│   ±50ms        ±100ms         ±200ms    (jitter)               │
└────────────────────────────────────────────────────────────────┘
```

---

## Strategies de backoff

| Strategie | Formule | Usage |
|-----------|---------|-------|
| **Constant** | `delay` | Tests, rate limiting |
| **Linear** | `delay * attempt` | Progression douce |
| **Exponential** | `delay * 2^attempt` | Standard recommande |
| **Exponential + Jitter** | `delay * 2^attempt * random(0.5-1.5)` | Production (evite thundering herd) |

---

## Implementation TypeScript

```typescript
interface RetryOptions {
  maxAttempts: number;
  baseDelay: number;       // Delai initial en ms
  maxDelay: number;        // Delai maximum en ms
  backoffMultiplier: number;
  jitter: boolean;
  retryableErrors?: (error: Error) => boolean;
}

const defaultOptions: RetryOptions = {
  maxAttempts: 3,
  baseDelay: 100,
  maxDelay: 10000,
  backoffMultiplier: 2,
  jitter: true,
};

class RetryError extends Error {
  constructor(
    message: string,
    public readonly attempts: number,
    public readonly lastError: Error,
  ) {
    super(message);
    this.name = 'RetryError';
  }
}

async function retry<T>(
  fn: () => Promise<T>,
  options: Partial<RetryOptions> = {},
): Promise<T> {
  const opts = { ...defaultOptions, ...options };
  let lastError: Error | null = null;

  for (let attempt = 1; attempt <= opts.maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error as Error;

      // Verifier si l'erreur est retryable
      if (opts.retryableErrors && !opts.retryableErrors(lastError)) {
        throw lastError;
      }

      // Dernier essai: propager l'erreur
      if (attempt === opts.maxAttempts) {
        throw new RetryError(
          `Failed after ${attempt} attempts`,
          attempt,
          lastError,
        );
      }

      // Calculer le delai avec backoff
      const delay = calculateDelay(attempt, opts);
      console.log(`Attempt ${attempt} failed, retrying in ${delay}ms...`);
      await sleep(delay);
    }
  }

  throw lastError;
}

function calculateDelay(attempt: number, opts: RetryOptions): number {
  // Exponential backoff
  let delay = opts.baseDelay * Math.pow(opts.backoffMultiplier, attempt - 1);

  // Appliquer le maximum
  delay = Math.min(delay, opts.maxDelay);

  // Ajouter le jitter (±50%)
  if (opts.jitter) {
    const jitterFactor = 0.5 + Math.random();
    delay = Math.floor(delay * jitterFactor);
  }

  return delay;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
```

---

## Decorator pour retry

```typescript
function Retryable(options: Partial<RetryOptions> = {}) {
  return function (
    target: object,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: unknown[]) {
      return retry(() => originalMethod.apply(this, args), options);
    };

    return descriptor;
  };
}

// Usage
class ApiClient {
  @Retryable({ maxAttempts: 5, baseDelay: 200 })
  async fetchUser(id: string): Promise<User> {
    const response = await fetch(`/api/users/${id}`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return response.json();
  }
}
```

---

## Erreurs retryables

```typescript
// Definir quelles erreurs meritent un retry
const isRetryable = (error: Error): boolean => {
  // Erreurs reseau
  if (error.name === 'TypeError' && error.message.includes('fetch')) {
    return true;
  }

  // Erreurs HTTP specifiques
  if (error instanceof HttpError) {
    const retryableCodes = [408, 429, 500, 502, 503, 504];
    return retryableCodes.includes(error.status);
  }

  // Erreurs de timeout
  if (error.name === 'TimeoutError') {
    return true;
  }

  // Erreurs de lock/conflit
  if (error.message.includes('lock') || error.message.includes('conflict')) {
    return true;
  }

  return false;
};

// Usage
await retry(
  () => apiCall(),
  { retryableErrors: isRetryable },
);
```

---

## Retry avec cancellation

```typescript
async function retryWithAbort<T>(
  fn: (signal: AbortSignal) => Promise<T>,
  options: RetryOptions & { signal?: AbortSignal },
): Promise<T> {
  const { signal, ...retryOpts } = options;

  return retry(async () => {
    // Verifier l'annulation avant chaque tentative
    if (signal?.aborted) {
      throw new Error('Operation cancelled');
    }
    return fn(signal ?? new AbortController().signal);
  }, retryOpts);
}

// Usage avec timeout global
const controller = new AbortController();
const timeout = setTimeout(() => controller.abort(), 30000);

try {
  const result = await retryWithAbort(
    (signal) => fetch('/api/data', { signal }),
    { maxAttempts: 5, signal: controller.signal },
  );
} finally {
  clearTimeout(timeout);
}
```

---

## Configuration recommandee

| Scenario | maxAttempts | baseDelay | maxDelay |
|----------|-------------|-----------|----------|
| API interne | 3 | 100ms | 1s |
| API externe | 5 | 200ms | 10s |
| Database | 3 | 50ms | 500ms |
| File system | 3 | 100ms | 1s |
| Message queue | 5 | 500ms | 30s |

---

## Quand utiliser

- Erreurs transitoires (reseau, timeouts)
- Rate limiting (429 Too Many Requests)
- Services temporairement indisponibles (503)
- Conflits de lock optimiste
- Connexions base de donnees interrompues

---

## Quand NE PAS utiliser

- Erreurs de validation (400)
- Authentification echouee (401, 403)
- Ressource non trouvee (404)
- Erreurs de logique metier
- Operations non-idempotentes sans precaution

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [Circuit Breaker](circuit-breaker.md) | Utiliser ensemble (retry avant circuit) |
| [Timeout](timeout.md) | Limiter chaque tentative |
| [Rate Limiting](rate-limiting.md) | Respecter les limites du service |
| Idempotency | Prerequis pour retry securise |

---

## Sources

- [AWS - Exponential Backoff](https://docs.aws.amazon.com/general/latest/gr/api-retries.html)
- [Google Cloud - Retry Strategy](https://cloud.google.com/storage/docs/retry-strategy)
- [Microsoft - Retry Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/retry)
