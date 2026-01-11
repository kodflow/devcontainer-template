# Timeout Pattern

> Limiter le temps d'attente d'une operation pour eviter le blocage des ressources.

---

## Principe

```
┌─────────────────────────────────────────────────────────────┐
│                       TIMEOUT PATTERN                        │
│                                                              │
│  ┌─────────┐                    ┌─────────────────┐         │
│  │ Caller  │───────────────────►│ Remote Service  │         │
│  └─────────┘                    └─────────────────┘         │
│       │                               │                      │
│       │         Timeout!              │                      │
│       │◄──────────────────────────────│                      │
│       │                               │                      │
│       ▼                               │  (Still processing)  │
│  Handle timeout                       │                      │
│  (fallback, error)                    ▼                      │
└─────────────────────────────────────────────────────────────┘
```

---

## Types de timeouts

| Type | Description | Usage |
|------|-------------|-------|
| **Connection timeout** | Temps pour etablir la connexion | HTTP, TCP, DB |
| **Read timeout** | Temps pour recevoir les donnees | APIs, streams |
| **Request timeout** | Temps total de la requete | End-to-end |
| **Idle timeout** | Temps d'inactivite accepte | Connexions persistantes |

---

## Implementation TypeScript

### Timeout basique avec Promise.race

```typescript
class TimeoutError extends Error {
  constructor(message: string, public readonly timeoutMs: number) {
    super(message);
    this.name = 'TimeoutError';
  }
}

async function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  message = 'Operation timed out',
): Promise<T> {
  let timeoutId: NodeJS.Timeout;

  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new TimeoutError(message, timeoutMs));
    }, timeoutMs);
  });

  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    clearTimeout(timeoutId);
  }
}

// Usage
const result = await withTimeout(
  fetch('https://api.example.com/data'),
  5000,
  'API call timed out',
);
```

---

### Timeout avec AbortController

```typescript
async function fetchWithTimeout(
  url: string,
  options: RequestInit = {},
  timeoutMs = 5000,
): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    return response;
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new TimeoutError('Request aborted due to timeout', timeoutMs);
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
  }
}

// Usage
try {
  const response = await fetchWithTimeout('/api/users', {}, 3000);
  const data = await response.json();
} catch (error) {
  if (error instanceof TimeoutError) {
    console.log('Request timed out, using cached data');
    return getCachedData();
  }
  throw error;
}
```

---

### Timeout avec deadline propagation

```typescript
interface RequestContext {
  deadline: number;  // Timestamp absolu
  remainingTime(): number;
  isExpired(): boolean;
}

function createContext(timeoutMs: number): RequestContext {
  const deadline = Date.now() + timeoutMs;
  return {
    deadline,
    remainingTime: () => Math.max(0, deadline - Date.now()),
    isExpired: () => Date.now() >= deadline,
  };
}

async function processWithDeadline<T>(
  ctx: RequestContext,
  fn: (ctx: RequestContext) => Promise<T>,
): Promise<T> {
  if (ctx.isExpired()) {
    throw new TimeoutError('Deadline exceeded', 0);
  }

  return withTimeout(fn(ctx), ctx.remainingTime());
}

// Usage - Propagation de deadline entre services
async function handleRequest(ctx: RequestContext) {
  // Etape 1: Valider (utilise une partie du temps)
  const validationResult = await processWithDeadline(ctx, async (c) => {
    return validate(data);
  });

  // Etape 2: Persister (utilise le temps restant)
  const persistResult = await processWithDeadline(ctx, async (c) => {
    return database.save(validationResult);
  });

  return persistResult;
}

// Le contexte avec deadline de 5s est partage entre les etapes
const ctx = createContext(5000);
await handleRequest(ctx);
```

---

### Timeout hierarchique

```typescript
class TimeoutManager {
  private readonly globalTimeout: number;
  private readonly operationTimeouts: Map<string, number>;

  constructor(globalTimeout = 30000) {
    this.globalTimeout = globalTimeout;
    this.operationTimeouts = new Map([
      ['database', 5000],
      ['external_api', 10000],
      ['file_io', 3000],
      ['cache', 1000],
    ]);
  }

  getTimeout(operation: string): number {
    return this.operationTimeouts.get(operation) ?? this.globalTimeout;
  }

  async execute<T>(operation: string, fn: () => Promise<T>): Promise<T> {
    const timeout = this.getTimeout(operation);
    return withTimeout(fn(), timeout, `${operation} timed out after ${timeout}ms`);
  }
}

// Usage
const timeoutManager = new TimeoutManager(30000);

async function processOrder(order: Order) {
  // Chaque operation a son propre timeout
  const user = await timeoutManager.execute('database', () =>
    db.findUser(order.userId),
  );

  const inventory = await timeoutManager.execute('external_api', () =>
    inventoryService.check(order.items),
  );

  const cache = await timeoutManager.execute('cache', () =>
    redis.set(`order:${order.id}`, order),
  );

  return { user, inventory };
}
```

---

### Timeout avec cleanup

```typescript
interface CleanupHandler {
  cleanup: () => Promise<void>;
}

async function withTimeoutAndCleanup<T>(
  operation: () => Promise<T> & Partial<CleanupHandler>,
  timeoutMs: number,
): Promise<T> {
  const controller = new AbortController();
  const result = operation();

  try {
    return await withTimeout(result, timeoutMs);
  } catch (error) {
    // En cas de timeout, nettoyer les ressources
    if (error instanceof TimeoutError && 'cleanup' in result) {
      await (result as CleanupHandler).cleanup();
    }
    throw error;
  }
}

// Usage avec une transaction DB
async function executeTransaction() {
  const txn = await db.beginTransaction();

  const operation = Object.assign(
    (async () => {
      await txn.execute('INSERT INTO orders ...');
      await txn.execute('UPDATE inventory ...');
      await txn.commit();
      return { success: true };
    })(),
    {
      cleanup: async () => {
        await txn.rollback();
      },
    },
  );

  return withTimeoutAndCleanup(operation, 5000);
}
```

---

## Configuration recommandee

| Operation | Timeout | Justification |
|-----------|---------|---------------|
| Health check | 1-2s | Doit etre rapide |
| Cache lookup | 100-500ms | En memoire |
| Database query | 3-10s | Selon complexite |
| API interne | 5-10s | Meme reseau |
| API externe | 10-30s | Latence variable |
| File upload | 60-300s | Selon taille |

---

## Quand utiliser

- Tout appel reseau (HTTP, gRPC, TCP)
- Requetes base de donnees
- Operations de fichiers distants
- Appels a des services tiers
- Toute operation pouvant bloquer indefiniment

---

## Bonnes pratiques

| Pratique | Raison |
|----------|--------|
| Toujours definir un timeout | Eviter les blocages infinis |
| Propager les deadlines | Coherence end-to-end |
| Timeout < keep-alive | Eviter les connexions zombies |
| Cleanup sur timeout | Liberer les ressources |
| Logger les timeouts | Debugging et alerting |

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [Circuit Breaker](circuit-breaker.md) | Timeout contribue aux failures |
| [Retry](retry.md) | Timeout par tentative |
| [Bulkhead](bulkhead.md) | Limiter les threads bloques |
| Graceful Degradation | Fallback sur timeout |

---

## Sources

- [Google SRE - Handling Overload](https://sre.google/sre-book/handling-overload/)
- [AWS - Timeouts and Retries](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/)
- [Microservices Patterns - Chris Richardson](https://microservices.io/patterns/reliability/circuit-breaker.html)
