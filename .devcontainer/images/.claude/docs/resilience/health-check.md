# Health Check Pattern

> Verifier l'etat de sante d'un service pour permettre la detection et la recuperation automatique.

---

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                     HEALTH CHECK TYPES                           │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │   LIVENESS   │  │  READINESS   │  │   STARTUP    │           │
│  │              │  │              │  │              │           │
│  │  "Am I       │  │  "Can I      │  │  "Am I       │           │
│  │   alive?"    │  │   serve?"    │  │   ready?"    │           │
│  │              │  │              │  │              │           │
│  │  → Restart   │  │  → No traffic│  │  → Wait      │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                  │
│  Kubernetes:                                                     │
│  livenessProbe     readinessProbe    startupProbe               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Types de probes

| Type | Question | Action si echec | Usage |
|------|----------|-----------------|-------|
| **Liveness** | Le processus fonctionne? | Restart container | Deadlocks, crashes |
| **Readiness** | Peut recevoir du trafic? | Retirer du load balancer | Warmup, dependencies |
| **Startup** | A demarre correctement? | Attendre ou restart | Slow startup |

---

## Implementation TypeScript

### Interface Health Check

```typescript
interface HealthStatus {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: Date;
  duration: number;
  details?: Record<string, ComponentHealth>;
}

interface ComponentHealth {
  status: 'healthy' | 'degraded' | 'unhealthy';
  message?: string;
  duration?: number;
  lastCheck?: Date;
}

interface HealthCheck {
  name: string;
  check(): Promise<ComponentHealth>;
  critical: boolean;  // Si true, fait passer le service en unhealthy
}
```

---

### Health Check Manager

```typescript
class HealthCheckManager {
  private readonly checks: HealthCheck[] = [];
  private lastStatus: HealthStatus | null = null;
  private checkInterval: NodeJS.Timeout | null = null;

  register(check: HealthCheck): void {
    this.checks.push(check);
  }

  async getHealth(): Promise<HealthStatus> {
    const start = Date.now();
    const details: Record<string, ComponentHealth> = {};
    let overallStatus: HealthStatus['status'] = 'healthy';

    await Promise.all(
      this.checks.map(async (check) => {
        try {
          const checkStart = Date.now();
          const result = await check.check();
          result.duration = Date.now() - checkStart;
          result.lastCheck = new Date();
          details[check.name] = result;

          if (result.status === 'unhealthy' && check.critical) {
            overallStatus = 'unhealthy';
          } else if (result.status === 'degraded' && overallStatus !== 'unhealthy') {
            overallStatus = 'degraded';
          }
        } catch (error) {
          details[check.name] = {
            status: 'unhealthy',
            message: (error as Error).message,
            lastCheck: new Date(),
          };
          if (check.critical) {
            overallStatus = 'unhealthy';
          }
        }
      }),
    );

    this.lastStatus = {
      status: overallStatus,
      timestamp: new Date(),
      duration: Date.now() - start,
      details,
    };

    return this.lastStatus;
  }

  startPeriodicCheck(intervalMs = 30000): void {
    this.checkInterval = setInterval(() => {
      this.getHealth().catch(console.error);
    }, intervalMs);
  }

  stop(): void {
    if (this.checkInterval) {
      clearInterval(this.checkInterval);
    }
  }
}
```

---

### Health Checks specifiques

```typescript
// Database Health Check
class DatabaseHealthCheck implements HealthCheck {
  name = 'database';
  critical = true;

  constructor(private readonly db: Database) {}

  async check(): Promise<ComponentHealth> {
    try {
      await this.db.query('SELECT 1');
      return { status: 'healthy' };
    } catch (error) {
      return {
        status: 'unhealthy',
        message: `Database connection failed: ${(error as Error).message}`,
      };
    }
  }
}

// Redis Health Check
class RedisHealthCheck implements HealthCheck {
  name = 'redis';
  critical = false;  // Non-critique, fallback possible

  constructor(private readonly redis: RedisClient) {}

  async check(): Promise<ComponentHealth> {
    try {
      await this.redis.ping();
      return { status: 'healthy' };
    } catch (error) {
      return {
        status: 'degraded',
        message: `Redis unavailable: ${(error as Error).message}`,
      };
    }
  }
}

// External API Health Check
class ExternalApiHealthCheck implements HealthCheck {
  name = 'payment-gateway';
  critical = false;

  constructor(
    private readonly url: string,
    private readonly timeout = 5000,
  ) {}

  async check(): Promise<ComponentHealth> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const response = await fetch(`${this.url}/health`, {
        signal: controller.signal,
      });

      if (response.ok) {
        return { status: 'healthy' };
      }

      return {
        status: 'degraded',
        message: `API returned ${response.status}`,
      };
    } catch (error) {
      return {
        status: 'unhealthy',
        message: (error as Error).message,
      };
    } finally {
      clearTimeout(timeoutId);
    }
  }
}

// Disk Space Health Check
class DiskSpaceHealthCheck implements HealthCheck {
  name = 'disk-space';
  critical = true;

  constructor(
    private readonly path: string,
    private readonly minFreeBytes: number,
    private readonly warnFreeBytes: number,
  ) {}

  async check(): Promise<ComponentHealth> {
    const stats = await checkDiskSpace(this.path);

    if (stats.free < this.minFreeBytes) {
      return {
        status: 'unhealthy',
        message: `Only ${formatBytes(stats.free)} free (minimum: ${formatBytes(this.minFreeBytes)})`,
      };
    }

    if (stats.free < this.warnFreeBytes) {
      return {
        status: 'degraded',
        message: `Low disk space: ${formatBytes(stats.free)} free`,
      };
    }

    return { status: 'healthy' };
  }
}

// Memory Health Check
class MemoryHealthCheck implements HealthCheck {
  name = 'memory';
  critical = false;

  constructor(private readonly maxUsagePercent = 90) {}

  async check(): Promise<ComponentHealth> {
    const usage = process.memoryUsage();
    const heapUsedPercent = (usage.heapUsed / usage.heapTotal) * 100;

    if (heapUsedPercent > this.maxUsagePercent) {
      return {
        status: 'degraded',
        message: `High memory usage: ${heapUsedPercent.toFixed(1)}%`,
      };
    }

    return { status: 'healthy' };
  }
}
```

---

### Endpoints HTTP

```typescript
import express from 'express';

function createHealthEndpoints(
  app: express.Application,
  healthManager: HealthCheckManager,
) {
  // Liveness - juste verifier que le process repond
  app.get('/health/live', (req, res) => {
    res.status(200).json({ status: 'alive' });
  });

  // Readiness - verifier les dependances
  app.get('/health/ready', async (req, res) => {
    const health = await healthManager.getHealth();

    const statusCode = health.status === 'unhealthy' ? 503 : 200;
    res.status(statusCode).json(health);
  });

  // Startup - pour les slow starts
  app.get('/health/startup', async (req, res) => {
    if (!startupComplete) {
      return res.status(503).json({ status: 'starting' });
    }

    const health = await healthManager.getHealth();
    const statusCode = health.status === 'unhealthy' ? 503 : 200;
    res.status(statusCode).json(health);
  });

  // Detailed health (admin only)
  app.get('/health', async (req, res) => {
    const health = await healthManager.getHealth();
    res.status(health.status === 'unhealthy' ? 503 : 200).json(health);
  });
}
```

---

## Kubernetes Configuration

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
    - name: app
      image: myapp:latest
      ports:
        - containerPort: 3000

      # Liveness: restart si echec
      livenessProbe:
        httpGet:
          path: /health/live
          port: 3000
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 5
        failureThreshold: 3

      # Readiness: retirer du service si echec
      readinessProbe:
        httpGet:
          path: /health/ready
          port: 3000
        initialDelaySeconds: 5
        periodSeconds: 5
        timeoutSeconds: 3
        failureThreshold: 3

      # Startup: pour les slow starts
      startupProbe:
        httpGet:
          path: /health/startup
          port: 3000
        initialDelaySeconds: 0
        periodSeconds: 5
        timeoutSeconds: 3
        failureThreshold: 30  # 30 * 5s = 2.5min max startup
```

---

## Configuration recommandee

| Probe | initialDelay | period | timeout | failureThreshold |
|-------|--------------|--------|---------|------------------|
| Liveness | 10-30s | 10-15s | 5s | 3 |
| Readiness | 5-10s | 5-10s | 3s | 3 |
| Startup | 0s | 5-10s | 3s | 30 |

---

## Quand utiliser

- Orchestration Kubernetes
- Load balancers (AWS ALB, nginx)
- Service mesh (Istio, Linkerd)
- Monitoring et alerting
- Auto-scaling decisions

---

## Bonnes pratiques

| Pratique | Raison |
|----------|--------|
| Liveness = simple | Eviter les false positives |
| Readiness = dependencies | Verifier vraie disponibilite |
| Startup pour slow init | Eviter kill premature |
| Cache les checks | Performance |
| Timeout < period | Eviter accumulation |

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [Circuit Breaker](circuit-breaker.md) | Health influence le circuit |
| [Retry](retry.md) | Health checks retryables |
| Watchdog | Complementaire |
| Self-healing | Base de la recuperation |

---

## Sources

- [Kubernetes - Configure Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Microsoft - Health Endpoint Monitoring](https://learn.microsoft.com/en-us/azure/architecture/patterns/health-endpoint-monitoring)
- [Google SRE - Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
