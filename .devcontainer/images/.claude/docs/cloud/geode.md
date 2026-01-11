# Geode Pattern (Geodes / Deployment Stamps)

> Deployer des unites identiques dans plusieurs regions geographiques.

## Principe

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          GLOBAL TRAFFIC MANAGER                          │
│                         (DNS / Load Balancer)                            │
│                                                                          │
│   Route vers la region la plus proche / performante / disponible         │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   GEODE EU      │      │   GEODE US      │      │   GEODE ASIA    │
│                 │      │                 │      │                 │
│  ┌───────────┐  │      │  ┌───────────┐  │      │  ┌───────────┐  │
│  │  Service  │  │      │  │  Service  │  │      │  │  Service  │  │
│  │   Stack   │  │      │  │   Stack   │  │      │  │   Stack   │  │
│  └───────────┘  │      │  └───────────┘  │      │  └───────────┘  │
│  ┌───────────┐  │      │  ┌───────────┐  │      │  ┌───────────┐  │
│  │  Database │  │      │  │  Database │  │      │  │  Database │  │
│  │  (local)  │  │      │  │  (local)  │  │      │  │  (local)  │  │
│  └───────────┘  │      │  └───────────┘  │      │  └───────────┘  │
│  ┌───────────┐  │      │  ┌───────────┐  │      │  ┌───────────┐  │
│  │   Cache   │  │      │  │   Cache   │  │      │  │   Cache   │  │
│  └───────────┘  │      │  └───────────┘  │      │  └───────────┘  │
└─────────────────┘      └─────────────────┘      └─────────────────┘
         │                         │                         │
         └─────────────────────────┴─────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    │     REPLICATION LAYER       │
                    │  (Async / Eventual Consist) │
                    └─────────────────────────────┘
```

## Composants d'une Geode

| Composant | Description |
|-----------|-------------|
| **Application Stack** | Services identiques par region |
| **Local Database** | Base locale (replica ou partition) |
| **Cache Layer** | Redis/Memcached local |
| **Message Queue** | Kafka/RabbitMQ local |
| **Storage** | Blob storage regional |

## Exemple TypeScript

```typescript
interface GeodeConfig {
  region: string;
  endpoint: string;
  isPrimary: boolean;
  replicationTargets: string[];
}

interface DataItem {
  id: string;
  data: any;
  version: number;
  region: string;
  timestamp: Date;
}

class GeodeDataStore {
  constructor(
    private readonly config: GeodeConfig,
    private readonly localDb: Database,
    private readonly replicationClient: ReplicationClient,
  ) {}

  async write(id: string, data: any): Promise<DataItem> {
    const item: DataItem = {
      id,
      data,
      version: Date.now(),
      region: this.config.region,
      timestamp: new Date(),
    };

    // Write local
    await this.localDb.upsert(item);

    // Async replication to other geodes
    this.replicateAsync(item);

    return item;
  }

  async read(id: string): Promise<DataItem | null> {
    // Always read from local geode
    return this.localDb.find(id);
  }

  private async replicateAsync(item: DataItem): Promise<void> {
    // Fire-and-forget replication
    for (const target of this.config.replicationTargets) {
      this.replicationClient.send(target, item).catch((error) => {
        console.error(`Replication to ${target} failed:`, error);
        // Queue for retry
        this.queueForRetry(target, item);
      });
    }
  }

  async handleReplication(item: DataItem): Promise<void> {
    const existing = await this.localDb.find(item.id);

    // Conflict resolution: Last Write Wins
    if (!existing || item.version > existing.version) {
      await this.localDb.upsert(item);
    }
  }

  private async queueForRetry(target: string, item: DataItem): Promise<void> {
    await this.replicationClient.queueRetry(target, item);
  }
}

// Global Traffic Router
class GeodeRouter {
  constructor(private readonly geodes: Map<string, GeodeConfig>) {}

  async route(request: Request): Promise<string> {
    const clientRegion = this.detectClientRegion(request);
    const healthyGeodes = await this.getHealthyGeodes();

    // Route vers la geode la plus proche
    const bestGeode = this.findClosestGeode(clientRegion, healthyGeodes);

    if (!bestGeode) {
      throw new Error('No healthy geodes available');
    }

    return bestGeode.endpoint;
  }

  private detectClientRegion(request: Request): string {
    // Via header Cloudflare/AWS/GCP
    return (
      request.headers.get('CF-IPCountry') ??
      request.headers.get('X-Client-Region') ??
      'US'
    );
  }

  private async getHealthyGeodes(): Promise<GeodeConfig[]> {
    const healthChecks = await Promise.all(
      Array.from(this.geodes.values()).map(async (geode) => ({
        geode,
        healthy: await this.checkHealth(geode),
      })),
    );

    return healthChecks.filter((h) => h.healthy).map((h) => h.geode);
  }

  private findClosestGeode(
    region: string,
    geodes: GeodeConfig[],
  ): GeodeConfig | undefined {
    const regionMapping: Record<string, string[]> = {
      FR: ['eu-west-1', 'eu-central-1'],
      DE: ['eu-central-1', 'eu-west-1'],
      US: ['us-east-1', 'us-west-2'],
      JP: ['ap-northeast-1', 'ap-southeast-1'],
    };

    const preferredRegions = regionMapping[region] ?? ['us-east-1'];

    for (const preferred of preferredRegions) {
      const match = geodes.find((g) => g.region === preferred);
      if (match) return match;
    }

    return geodes[0];
  }

  private async checkHealth(geode: GeodeConfig): Promise<boolean> {
    try {
      const response = await fetch(`${geode.endpoint}/health`, {
        signal: AbortSignal.timeout(5000),
      });
      return response.ok;
    } catch {
      return false;
    }
  }
}
```

## Strategies de replication

| Strategie | Latence | Consistance | Cas d'usage |
|-----------|---------|-------------|-------------|
| **Sync** | Haute | Forte | Donnees critiques |
| **Async** | Basse | Eventual | Majorite des cas |
| **CRDT** | Basse | Eventual (auto-merge) | Compteurs, sets |
| **Event Sourcing** | Basse | Eventual + audit | Finance, audit |

## Infrastructure as Code

```hcl
# Terraform - Multi-region deployment
module "geode" {
  for_each = toset(["eu-west-1", "us-east-1", "ap-northeast-1"])

  source = "./modules/geode"

  region           = each.key
  app_version      = var.app_version
  instance_count   = var.instances_per_geode
  database_size    = var.db_size

  replication_targets = [
    for r in toset(["eu-west-1", "us-east-1", "ap-northeast-1"]) :
    r if r != each.key
  ]
}

resource "aws_route53_record" "global" {
  zone_id = var.zone_id
  name    = "api.example.com"
  type    = "A"

  latency_routing_policy {
    region = each.key
  }

  alias {
    name    = module.geode[each.key].alb_dns_name
    zone_id = module.geode[each.key].alb_zone_id
  }
}
```

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Sync replication | Latence globale | Async avec eventual consistency |
| Donnees non-partitionnees | Conflicts frequents | Partition par region/tenant |
| Sans conflict resolution | Perte de donnees | LWW ou CRDT |
| Geode non-autonome | Dependance inter-region | Self-contained stack |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| CQRS | Read models par region |
| Event Sourcing | Replication event-based |
| Sharding | Partition des donnees |
| Active-Active | Strategie HA |

## Sources

- [Microsoft - Geode Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/geodes)
- [Microsoft - Deployment Stamps](https://learn.microsoft.com/en-us/azure/architecture/patterns/deployment-stamp)
- [CRDTs](https://crdt.tech/)
