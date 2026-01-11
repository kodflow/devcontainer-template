# Bulkhead Pattern

> Isoler les ressources pour empecher qu'une defaillance ne se propage a l'ensemble du systeme.

---

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                    BULKHEAD PATTERN                              │
│                                                                  │
│  Sans Bulkhead:                Avec Bulkhead:                   │
│                                                                  │
│  ┌──────────────────┐          ┌───────┐ ┌───────┐ ┌───────┐   │
│  │   Shared Pool    │          │Pool A │ │Pool B │ │Pool C │   │
│  │ ┌──┐┌──┐┌──┐┌──┐ │          │ ┌──┐  │ │ ┌──┐  │ │ ┌──┐  │   │
│  │ │T1││T2││T3││T4│ │          │ │T1│  │ │ │T2│  │ │ │T3│  │   │
│  │ └──┘└──┘└──┘└──┘ │          │ └──┘  │ │ └──┘  │ │ └──┘  │   │
│  └──────────────────┘          └───────┘ └───────┘ └───────┘   │
│         │                           │         │         │       │
│         ▼                           ▼         ▼         ▼       │
│  Si un service bloque,      Service A lent n'affecte pas       │
│  TOUT le pool est epuise    B et C (isolation)                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Types de Bulkhead

| Type | Description | Usage |
|------|-------------|-------|
| **Thread Pool** | Pool de threads dedie par service | Java, .NET |
| **Semaphore** | Limite le nombre d'appels concurrents | Node.js, async |
| **Connection Pool** | Pool de connexions dedie | Database, HTTP |
| **Process Isolation** | Processus separes | Microservices |

---

## Implementation TypeScript - Semaphore

```typescript
class Semaphore {
  private permits: number;
  private readonly queue: Array<() => void> = [];

  constructor(private readonly maxPermits: number) {
    this.permits = maxPermits;
  }

  async acquire(): Promise<void> {
    if (this.permits > 0) {
      this.permits--;
      return;
    }

    return new Promise((resolve) => {
      this.queue.push(resolve);
    });
  }

  release(): void {
    if (this.queue.length > 0) {
      const next = this.queue.shift()!;
      next();
    } else {
      this.permits++;
    }
  }

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await fn();
    } finally {
      this.release();
    }
  }

  get availablePermits(): number {
    return this.permits;
  }

  get waitingCount(): number {
    return this.queue.length;
  }
}
```

---

## Bulkhead avec timeout et rejet

```typescript
class BulkheadRejectedError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'BulkheadRejectedError';
  }
}

interface BulkheadOptions {
  maxConcurrent: number;    // Executions simultanees max
  maxWaiting: number;       // Taille de la file d'attente
  waitTimeout: number;      // Temps max d'attente en queue (ms)
}

class Bulkhead {
  private running = 0;
  private readonly queue: Array<{
    resolve: () => void;
    reject: (error: Error) => void;
    timeoutId: NodeJS.Timeout;
  }> = [];

  constructor(private readonly options: BulkheadOptions) {}

  async execute<T>(fn: () => Promise<T>): Promise<T> {
    // Verifier si on peut executer immediatement
    if (this.running < this.options.maxConcurrent) {
      this.running++;
      try {
        return await fn();
      } finally {
        this.running--;
        this.processQueue();
      }
    }

    // Verifier si la queue est pleine
    if (this.queue.length >= this.options.maxWaiting) {
      throw new BulkheadRejectedError(
        `Bulkhead queue full (${this.options.maxWaiting} waiting)`,
      );
    }

    // Attendre dans la queue
    await this.waitInQueue();

    try {
      return await fn();
    } finally {
      this.running--;
      this.processQueue();
    }
  }

  private waitInQueue(): Promise<void> {
    return new Promise((resolve, reject) => {
      const timeoutId = setTimeout(() => {
        const index = this.queue.findIndex((item) => item.resolve === resolve);
        if (index !== -1) {
          this.queue.splice(index, 1);
          reject(new BulkheadRejectedError(
            `Timeout waiting for bulkhead (${this.options.waitTimeout}ms)`,
          ));
        }
      }, this.options.waitTimeout);

      this.queue.push({ resolve, reject, timeoutId });
    });
  }

  private processQueue(): void {
    if (this.queue.length > 0 && this.running < this.options.maxConcurrent) {
      const next = this.queue.shift()!;
      clearTimeout(next.timeoutId);
      this.running++;
      next.resolve();
    }
  }

  getMetrics(): { running: number; waiting: number } {
    return {
      running: this.running,
      waiting: this.queue.length,
    };
  }
}
```

---

## Bulkhead par service

```typescript
class ServiceBulkheads {
  private readonly bulkheads = new Map<string, Bulkhead>();
  private readonly defaultOptions: BulkheadOptions = {
    maxConcurrent: 10,
    maxWaiting: 100,
    waitTimeout: 5000,
  };

  constructor(
    private readonly configs: Map<string, Partial<BulkheadOptions>> = new Map(),
  ) {}

  getBulkhead(serviceName: string): Bulkhead {
    if (!this.bulkheads.has(serviceName)) {
      const config = this.configs.get(serviceName) ?? {};
      this.bulkheads.set(
        serviceName,
        new Bulkhead({ ...this.defaultOptions, ...config }),
      );
    }
    return this.bulkheads.get(serviceName)!;
  }

  async executeFor<T>(serviceName: string, fn: () => Promise<T>): Promise<T> {
    return this.getBulkhead(serviceName).execute(fn);
  }

  getAllMetrics(): Record<string, { running: number; waiting: number }> {
    const metrics: Record<string, { running: number; waiting: number }> = {};
    for (const [name, bulkhead] of this.bulkheads) {
      metrics[name] = bulkhead.getMetrics();
    }
    return metrics;
  }
}

// Usage
const bulkheads = new ServiceBulkheads(
  new Map([
    ['payment-service', { maxConcurrent: 5, maxWaiting: 20 }],
    ['inventory-service', { maxConcurrent: 20, maxWaiting: 50 }],
    ['notification-service', { maxConcurrent: 50, maxWaiting: 200 }],
  ]),
);

async function processOrder(order: Order) {
  // Chaque service a son propre bulkhead
  const payment = await bulkheads.executeFor('payment-service', () =>
    paymentClient.charge(order),
  );

  const inventory = await bulkheads.executeFor('inventory-service', () =>
    inventoryClient.reserve(order.items),
  );

  await bulkheads.executeFor('notification-service', () =>
    notifyUser(order.userId, 'Order confirmed'),
  );

  return { payment, inventory };
}
```

---

## Bulkhead avec Connection Pool

```typescript
interface PooledConnection {
  execute<T>(query: string): Promise<T>;
  release(): void;
}

class ConnectionPoolBulkhead {
  private readonly available: PooledConnection[] = [];
  private readonly inUse = new Set<PooledConnection>();
  private readonly waiting: Array<(conn: PooledConnection) => void> = [];

  constructor(
    private readonly maxConnections: number,
    private readonly factory: () => Promise<PooledConnection>,
  ) {}

  async acquire(): Promise<PooledConnection> {
    // Connexion disponible
    if (this.available.length > 0) {
      const conn = this.available.pop()!;
      this.inUse.add(conn);
      return conn;
    }

    // Creer une nouvelle connexion si possible
    if (this.inUse.size < this.maxConnections) {
      const conn = await this.factory();
      this.inUse.add(conn);
      return conn;
    }

    // Attendre une connexion disponible
    return new Promise((resolve) => {
      this.waiting.push(resolve);
    });
  }

  release(conn: PooledConnection): void {
    this.inUse.delete(conn);

    if (this.waiting.length > 0) {
      const next = this.waiting.shift()!;
      this.inUse.add(conn);
      next(conn);
    } else {
      this.available.push(conn);
    }
  }

  async execute<T>(fn: (conn: PooledConnection) => Promise<T>): Promise<T> {
    const conn = await this.acquire();
    try {
      return await fn(conn);
    } finally {
      this.release(conn);
    }
  }
}
```

---

## Decorator Bulkhead

```typescript
function BulkheadProtected(options: BulkheadOptions) {
  const bulkhead = new Bulkhead(options);

  return function (
    target: object,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (...args: unknown[]) {
      return bulkhead.execute(() => originalMethod.apply(this, args));
    };

    return descriptor;
  };
}

// Usage
class OrderService {
  @BulkheadProtected({ maxConcurrent: 10, maxWaiting: 50, waitTimeout: 5000 })
  async processPayment(orderId: string): Promise<PaymentResult> {
    return paymentGateway.charge(orderId);
  }
}
```

---

## Configuration recommandee

| Service | maxConcurrent | maxWaiting | Justification |
|---------|---------------|------------|---------------|
| Payment Gateway | 5-10 | 20-50 | Service critique, limiter |
| Database | 10-20 | 50-100 | Selon pool DB |
| Cache | 50-100 | 200 | Rapide, plus permissif |
| External API | 10-20 | 30-50 | Rate limiting externe |
| File I/O | 5-10 | 20 | I/O bound |

---

## Quand utiliser

- Services avec SLAs differents
- Protection contre les slow consumers
- Isolation des dependances critiques
- Prevention de l'epuisement des ressources
- Microservices avec dependances multiples

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [Circuit Breaker](circuit-breaker.md) | Utiliser ensemble |
| [Timeout](timeout.md) | Timeout dans le bulkhead |
| [Rate Limiting](rate-limiting.md) | Limite differente (debit vs concurrence) |
| Thread Pool | Implementation alternative |

---

## Sources

- [Microsoft - Bulkhead Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/bulkhead)
- [Release It! - Michael Nygard](https://pragprog.com/titles/mnee2/release-it-second-edition/)
- [Resilience4j - Bulkhead](https://resilience4j.readme.io/docs/bulkhead)
