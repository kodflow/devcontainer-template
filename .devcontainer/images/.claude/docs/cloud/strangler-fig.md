# Strangler Fig Pattern

> Migrer progressivement un systeme legacy en le remplacant incrementalement.

## Principe

```
                    ┌─────────────────────────────────────────────┐
                    │              STRANGLER FIG                   │
                    └─────────────────────────────────────────────┘

  Inspiration naturelle: Figuier etrangleur
  - Pousse autour d'un arbre existant
  - Le remplace progressivement
  - L'arbre original disparait

  Phase 1: COEXISTENCE
  ┌─────────────────────────────────────────────────────────┐
  │                        FACADE                           │
  └──────────────────────────┬──────────────────────────────┘
                             │
           ┌─────────────────┴─────────────────┐
           │                                   │
           ▼                                   ▼
  ┌─────────────────┐               ┌─────────────────┐
  │    LEGACY       │               │      NEW        │
  │   (monolith)    │               │   (services)    │
  │   ████████████  │               │   ░░░░          │
  └─────────────────┘               └─────────────────┘

  Phase 2: MIGRATION PROGRESSIVE
  ┌─────────────────────────────────────────────────────────┐
  │                        FACADE                           │
  └──────────────────────────┬──────────────────────────────┘
                             │
           ┌─────────────────┴─────────────────┐
           │                                   │
           ▼                                   ▼
  ┌─────────────────┐               ┌─────────────────┐
  │    LEGACY       │               │      NEW        │
  │   ████████      │               │   ░░░░░░░░░░░░  │
  └─────────────────┘               └─────────────────┘

  Phase 3: DECOMMISSION
  ┌─────────────────────────────────────────────────────────┐
  │                        FACADE                           │
  └──────────────────────────┬──────────────────────────────┘
                             │
                             ▼
                  ┌─────────────────┐
                  │      NEW        │
                  │   ░░░░░░░░░░░░  │
                  │   (complete)    │
                  └─────────────────┘
```

## Implementation TypeScript

```typescript
interface RoutingConfig {
  feature: string;
  useNew: boolean;
  percentage?: number; // Pour canary deployment
}

class StranglerFacade {
  private routingConfig: Map<string, RoutingConfig> = new Map();

  constructor(
    private legacyService: LegacyService,
    private newServices: Map<string, NewService>,
  ) {
    this.initializeRouting();
  }

  private initializeRouting(): void {
    // Configuration par feature
    this.routingConfig.set('users', { feature: 'users', useNew: true });
    this.routingConfig.set('orders', {
      feature: 'orders',
      useNew: true,
      percentage: 50,
    }); // Canary
    this.routingConfig.set('inventory', { feature: 'inventory', useNew: false }); // Still legacy
    this.routingConfig.set('reports', { feature: 'reports', useNew: false });
  }

  async handleRequest(
    feature: string,
    method: string,
    data: unknown,
  ): Promise<unknown> {
    const config = this.routingConfig.get(feature);

    if (!config) {
      throw new Error(`Unknown feature: ${feature}`);
    }

    const useNewService = this.shouldUseNewService(config);

    if (useNewService) {
      const service = this.newServices.get(feature);
      if (!service) {
        throw new Error(`New service not found for: ${feature}`);
      }
      return service.execute(method, data);
    }

    return this.legacyService.execute(feature, method, data);
  }

  private shouldUseNewService(config: RoutingConfig): boolean {
    if (!config.useNew) return false;

    // Canary: pourcentage du trafic
    if (config.percentage !== undefined) {
      return Math.random() * 100 < config.percentage;
    }

    return true;
  }

  // Migrer une feature
  enableNewService(feature: string, percentage = 100): void {
    this.routingConfig.set(feature, {
      feature,
      useNew: true,
      percentage,
    });
  }

  // Rollback si probleme
  disableNewService(feature: string): void {
    this.routingConfig.set(feature, {
      feature,
      useNew: false,
    });
  }
}
```

## Anti-Corruption Layer

```typescript
// Adapte les modeles legacy vers le nouveau format
interface LegacyUser {
  USR_ID: number;
  USR_NAME: string;
  USR_MAIL: string;
  USR_ACTIVE: 'Y' | 'N';
  CREATED_DT: string;
}

interface User {
  id: string;
  name: string;
  email: string;
  active: boolean;
  createdAt: Date;
}

class UserAntiCorruptionLayer {
  // Legacy -> New
  translateFromLegacy(legacy: LegacyUser): User {
    return {
      id: `user_${legacy.USR_ID}`,
      name: legacy.USR_NAME,
      email: legacy.USR_MAIL,
      active: legacy.USR_ACTIVE === 'Y',
      createdAt: new Date(legacy.CREATED_DT),
    };
  }

  // New -> Legacy (pour sync bidirectionnelle)
  translateToLegacy(user: User): LegacyUser {
    return {
      USR_ID: parseInt(user.id.replace('user_', '')),
      USR_NAME: user.name,
      USR_MAIL: user.email,
      USR_ACTIVE: user.active ? 'Y' : 'N',
      CREATED_DT: user.createdAt.toISOString().split('T')[0],
    };
  }
}
```

## Sync bidirectionnelle pendant migration

```typescript
class DualWriteService {
  constructor(
    private legacyRepo: LegacyUserRepository,
    private newRepo: UserRepository,
    private acl: UserAntiCorruptionLayer,
  ) {}

  async createUser(user: User): Promise<User> {
    // Ecrire dans les deux systemes
    const legacyUser = this.acl.translateToLegacy(user);

    const [, created] = await Promise.all([
      this.legacyRepo.create(legacyUser),
      this.newRepo.create(user),
    ]);

    return created;
  }

  async getUser(id: string): Promise<User> {
    // Lire du nouveau systeme, fallback sur legacy
    try {
      return await this.newRepo.findById(id);
    } catch {
      const legacyUser = await this.legacyRepo.findById(
        parseInt(id.replace('user_', '')),
      );
      return this.acl.translateFromLegacy(legacyUser);
    }
  }
}
```

## Feature flags pour migration

```typescript
class MigrationFeatureFlags {
  private flags: Map<string, boolean | number> = new Map();

  constructor(private configService: ConfigService) {
    this.loadFlags();
  }

  private async loadFlags(): Promise<void> {
    const config = await this.configService.get('migration');
    Object.entries(config).forEach(([key, value]) => {
      this.flags.set(key, value as boolean | number);
    });
  }

  isEnabled(feature: string): boolean {
    return this.flags.get(feature) === true;
  }

  getPercentage(feature: string): number {
    const value = this.flags.get(feature);
    return typeof value === 'number' ? value : 0;
  }

  // Toggle sans redeploy
  async enable(feature: string): Promise<void> {
    await this.configService.set(`migration.${feature}`, true);
    this.flags.set(feature, true);
  }

  async disable(feature: string): Promise<void> {
    await this.configService.set(`migration.${feature}`, false);
    this.flags.set(feature, false);
  }
}
```

## Phases de migration

```
┌─────────────────────────────────────────────────────────────────┐
│                    STRANGLER MIGRATION PHASES                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Phase 1: SETUP (2-4 semaines)                                 │
│  ├─ Facade/API Gateway en place                                │
│  ├─ Logging/monitoring unifie                                  │
│  └─ Premier service extrait (le plus simple)                   │
│                                                                 │
│  Phase 2: EXTRACT (iteratif, mois)                             │
│  ├─ Identifier bounded contexts                                │
│  ├─ Extraire service par service                               │
│  ├─ Dual-write pendant transition                              │
│  └─ Basculer trafic progressivement                            │
│                                                                 │
│  Phase 3: VALIDATE (par service)                               │
│  ├─ 100% trafic vers nouveau service                           │
│  ├─ Periode de soak test (1-4 semaines)                        │
│  └─ Monitoring comparatif                                      │
│                                                                 │
│  Phase 4: CLEANUP                                              │
│  ├─ Supprimer code legacy                                      │
│  ├─ Supprimer dual-write                                       │
│  └─ Documenter                                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Metriques de migration

```typescript
class MigrationMetrics {
  recordRequest(
    feature: string,
    target: 'legacy' | 'new',
    success: boolean,
    latencyMs: number,
  ): void {
    // Prometheus metrics
    requestCounter.inc({
      feature,
      target,
      status: success ? 'success' : 'error',
    });
    latencyHistogram.observe({ feature, target }, latencyMs);
  }

  getMigrationProgress(): Record<string, number> {
    // Pourcentage de trafic vers nouveau par feature
    return {
      users: 100,
      orders: 75,
      inventory: 0,
      reports: 25,
    };
  }
}
```

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Monolithe vers microservices | Oui |
| Modernisation progressive | Oui |
| Migration cloud | Oui |
| Systeme critique (zero downtime) | Oui |
| Petit projet simple | Non (overkill) |
| Deadline tres courte | Non (big bang plus rapide) |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Anti-Corruption Layer | Traduction entre domaines |
| Branch by Abstraction | Alternative similaire |
| Feature Flags | Controle de la migration |
| Facade | Point d'entree unique |

## Sources

- [Microsoft - Strangler Fig](https://learn.microsoft.com/en-us/azure/architecture/patterns/strangler-fig)
- [Martin Fowler - Strangler Fig Application](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Sam Newman - Monolith to Microservices](https://samnewman.io/books/monolith-to-microservices/)
