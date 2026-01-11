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

## Exemple Go

```go
package geode

import (
	"context"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// GeodeConfig defines configuration for a geode.
type GeodeConfig struct {
	Region             string
	Endpoint           string
	IsPrimary          bool
	ReplicationTargets []string
}

// DataItem represents a data item with version and region info.
type DataItem struct {
	ID        string
	Data      interface{}
	Version   int64
	Region    string
	Timestamp time.Time
}

// Database defines database operations.
type Database interface {
	Upsert(ctx context.Context, item *DataItem) error
	Find(ctx context.Context, id string) (*DataItem, error)
}

// ReplicationClient handles replication to other geodes.
type ReplicationClient interface {
	Send(ctx context.Context, target string, item *DataItem) error
	QueueRetry(ctx context.Context, target string, item *DataItem) error
}

// GeodeDataStore manages data with multi-region replication.
type GeodeDataStore struct {
	config            GeodeConfig
	localDB           Database
	replicationClient ReplicationClient
}

// NewGeodeDataStore creates a new GeodeDataStore.
func NewGeodeDataStore(config GeodeConfig, db Database, replClient ReplicationClient) *GeodeDataStore {
	return &GeodeDataStore{
		config:            config,
		localDB:           db,
		replicationClient: replClient,
	}
}

// Write writes data locally and replicates to other geodes.
func (gds *GeodeDataStore) Write(ctx context.Context, id string, data interface{}) (*DataItem, error) {
	item := &DataItem{
		ID:        id,
		Data:      data,
		Version:   time.Now().UnixNano(),
		Region:    gds.config.Region,
		Timestamp: time.Now(),
	}
	
	// Write local
	if err := gds.localDB.Upsert(ctx, item); err != nil {
		return nil, fmt.Errorf("local write failed: %w", err)
	}
	
	// Async replication
	go gds.replicateAsync(context.Background(), item)
	
	return item, nil
}

// Read reads from local geode.
func (gds *GeodeDataStore) Read(ctx context.Context, id string) (*DataItem, error) {
	return gds.localDB.Find(ctx, id)
}

func (gds *GeodeDataStore) replicateAsync(ctx context.Context, item *DataItem) {
	var wg sync.WaitGroup
	
	for _, target := range gds.config.ReplicationTargets {
		wg.Add(1)
		go func(t string) {
			defer wg.Done()
			
			if err := gds.replicationClient.Send(ctx, t, item); err != nil {
				fmt.Printf("Replication to %s failed: %v
", t, err)
				// Queue for retry
				gds.replicationClient.QueueRetry(ctx, t, item)
			}
		}(target)
	}
	
	wg.Wait()
}

// HandleReplication handles incoming replication from other geodes.
func (gds *GeodeDataStore) HandleReplication(ctx context.Context, item *DataItem) error {
	existing, err := gds.localDB.Find(ctx, item.ID)
	if err != nil {
		// Not found, just insert
		return gds.localDB.Upsert(ctx, item)
	}
	
	// Conflict resolution: Last Write Wins
	if item.Version > existing.Version {
		return gds.localDB.Upsert(ctx, item)
	}
	
	return nil
}

// GeodeRouter routes requests to the closest healthy geode.
type GeodeRouter struct {
	geodes map[string]*GeodeConfig
	client *http.Client
}

// NewGeodeRouter creates a new GeodeRouter.
func NewGeodeRouter(geodes map[string]*GeodeConfig) *GeodeRouter {
	return &GeodeRouter{
		geodes: geodes,
		client: &http.Client{Timeout: 5 * time.Second},
	}
}

// Route returns the endpoint for the best geode.
func (gr *GeodeRouter) Route(r *http.Request) (string, error) {
	clientRegion := gr.detectClientRegion(r)
	healthyGeodes, err := gr.getHealthyGeodes()
	if err != nil {
		return "", fmt.Errorf("no healthy geodes: %w", err)
	}
	
	bestGeode := gr.findClosestGeode(clientRegion, healthyGeodes)
	if bestGeode == nil {
		return "", fmt.Errorf("no suitable geode found")
	}
	
	return bestGeode.Endpoint, nil
}

func (gr *GeodeRouter) detectClientRegion(r *http.Request) string {
	// Check CloudFlare header
	if region := r.Header.Get("CF-IPCountry"); region != "" {
		return region
	}
	if region := r.Header.Get("X-Client-Region"); region != "" {
		return region
	}
	return "US"
}

func (gr *GeodeRouter) getHealthyGeodes() ([]*GeodeConfig, error) {
	healthy := make([]*GeodeConfig, 0)
	
	for _, geode := range gr.geodes {
		if gr.checkHealth(geode) {
			healthy = append(healthy, geode)
		}
	}
	
	if len(healthy) == 0 {
		return nil, fmt.Errorf("no healthy geodes")
	}
	
	return healthy, nil
}

func (gr *GeodeRouter) findClosestGeode(region string, geodes []*GeodeConfig) *GeodeConfig {
	// Region mapping logic (simplified)
	regionMapping := map[string][]string{
		"FR": {"eu-west-1", "eu-central-1"},
		"DE": {"eu-central-1", "eu-west-1"},
		"US": {"us-east-1", "us-west-2"},
		"JP": {"ap-northeast-1", "ap-southeast-1"},
	}
	
	preferredRegions := regionMapping[region]
	if preferredRegions == nil {
		preferredRegions = []string{"us-east-1"}
	}
	
	for _, preferred := range preferredRegions {
		for _, geode := range geodes {
			if geode.Region == preferred {
				return geode
			}
		}
	}
	
	if len(geodes) > 0 {
		return geodes[0]
	}
	
	return nil
}

func (gr *GeodeRouter) checkHealth(geode *GeodeConfig) bool {
	resp, err := gr.client.Get(geode.Endpoint + "/health")
	if err != nil {
		return false
	}
	defer resp.Body.Close()
	
	return resp.StatusCode == http.StatusOK
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
