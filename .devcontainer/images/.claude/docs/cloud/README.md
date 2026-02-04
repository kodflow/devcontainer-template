# Cloud Design Patterns

> Patterns pour systemes distribues, resilience et scalabilite cloud.

## Vue d'ensemble

```
                        CLOUD PATTERNS
                              |
      +-----------+-----------+-----------+-----------+
      |           |           |           |           |
  Resilience   Data       Messaging   Security   Migration
      |           |           |           |           |
  Circuit     Cache       Priority    Valet      Strangler
  Breaker     Aside       Queue       Key        Fig
      |           |           |           |           |
  Retry       Sharding    Queue       Static     CQRS
              |           Load        Content
          Materialized   Leveling    Hosting
          View
              |
          Leader
          Election
```

## Tableau de decision

| Probleme | Pattern | Fichier |
|----------|---------|---------|
| Pannes en cascade | Circuit Breaker | [circuit-breaker.md](circuit-breaker.md) |
| Transactions distribuees | Saga | [saga.md](saga.md) |
| Latence lecture DB | Cache-Aside | [cache-aside.md](cache-aside.md) |
| Donnees volumineuses | Sharding | [sharding.md](sharding.md) |
| Coordination distribuee | Leader Election | [leader-election.md](leader-election.md) |
| Queries complexes lentes | Materialized View | [materialized-view.md](materialized-view.md) |
| Traitement par importance | Priority Queue | [priority-queue.md](priority-queue.md) |
| Pics de charge | Queue Load Leveling | [queue-load-leveling.md](queue-load-leveling.md) |
| Acces temporaire securise | Valet Key | [valet-key.md](valet-key.md) |
| Assets statiques | Static Content Hosting | [static-content-hosting.md](static-content-hosting.md) |
| Migration progressive | Strangler Fig | [strangler-fig.md](strangler-fig.md) |
| Cross-cutting concerns | Ambassador | [ambassador.md](ambassador.md) |
| Payloads volumineux | Claim Check | [claim-check.md](claim-check.md) |
| Annulation transactions | Compensating Transaction | [compensating-transaction.md](compensating-transaction.md) |
| Optimisation ressources | Compute Resource Consolidation | [compute-resource-consolidation.md](compute-resource-consolidation.md) |
| Configuration externe | External Configuration | [external-configuration.md](external-configuration.md) |
| Multiples appels backend | Gateway Aggregation | [gateway-aggregation.md](gateway-aggregation.md) |
| Decharge gateway | Gateway Offloading | [gateway-offloading.md](gateway-offloading.md) |
| Routage intelligent | Gateway Routing | [gateway-routing.md](gateway-routing.md) |
| Deploiement geographique | Geode | [geode.md](geode.md) |
| Actions distribuees | Scheduler Agent Supervisor | [scheduler-agent-supervisor.md](scheduler-agent-supervisor.md) |

## Categories

### Resilience et stabilite

| Pattern | Description | Cas d'usage |
|---------|-------------|-------------|
| **Circuit Breaker** | Coupe les appels vers services defaillants | API externe instable |
| **Saga** | Transactions distribuees avec compensation | E-commerce multi-services |
| **Retry** | Reessaie les operations transitoires | Erreurs reseau temporaires |
| **Bulkhead** | Isole les ressources par domaine | Eviter contamination |
| **Compensating Transaction** | Annule operations distribuees | Rollback multi-services |
| **Scheduler Agent Supervisor** | Coordonne actions distribuees | Workflows complexes |

### Gestion des donnees

| Pattern | Description | Cas d'usage |
|---------|-------------|-------------|
| **Cache-Aside** | Cache a la demande avec TTL | Lecture intensive DB |
| **Sharding** | Partitionnement horizontal | Grandes volumetries |
| **Materialized View** | Vues pre-calculees | Queries analytiques |
| **CQRS** | Separation read/write | Domaines complexes |
| **Event Sourcing** | Historique evenementiel | Audit, replay |
| **Claim Check** | Separe message du payload | Messages volumineux |
| **External Configuration** | Configuration externalisee | Multi-environnements |

### Messaging et queues

| Pattern | Description | Cas d'usage |
|---------|-------------|-------------|
| **Priority Queue** | Traitement par priorite | SLA differencies |
| **Queue Load Leveling** | Lissage de charge | Pics previsibles |
| **Competing Consumers** | Parallelisation traitement | Scalabilite horizontale |

### Gateway patterns

| Pattern | Description | Cas d'usage |
|---------|-------------|-------------|
| **Ambassador** | Proxy sidecar cross-cutting | Logging, retry, circuit breaking |
| **Gateway Aggregation** | Agrege requetes backend | Reduire latence client |
| **Gateway Offloading** | Decharge fonctions partagees | SSL, auth, compression |
| **Gateway Routing** | Route vers backends | Microservices facade |

### Infrastructure et scalabilite

| Pattern | Description | Cas d'usage |
|---------|-------------|-------------|
| **Compute Resource Consolidation** | Optimise utilisation ressources | Reduction couts cloud |
| **Geode** | Deploiement geographique | Latence globale |
| **Leader Election** | Coordination cluster | Instance maitre unique |

### Securite et acces

| Pattern | Description | Cas d'usage |
|---------|-------------|-------------|
| **Valet Key** | Tokens temporaires | Upload direct S3/Blob |
| **Gatekeeper** | Validation en peripherie | API Gateway |
| **Federated Identity** | SSO externe | OAuth/OIDC |

### Deploiement et migration

| Pattern | Description | Cas d'usage |
|---------|-------------|-------------|
| **Strangler Fig** | Migration incrementale | Monolithe vers microservices |
| **Static Content Hosting** | CDN pour assets | Performance frontend |
| **Sidecar** | Composant auxiliaire | Logging, proxy |

## Combinaisons frequentes

```
API Resiliente:
  Circuit Breaker + Retry + Cache-Aside + Bulkhead

E-commerce:
  Saga + Event Sourcing + CQRS + Priority Queue

Migration legacy:
  Strangler Fig + Anti-Corruption Layer + CQRS

Haute disponibilite:
  Leader Election + Sharding + Materialized View
```

## Arbre de decision

```
Quel est ton probleme principal?
|
+-- Performance lecture? --> Cache-Aside ou Materialized View
|
+-- Volume de donnees? --> Sharding
|
+-- Service instable? --> Circuit Breaker + Retry
|
+-- Transactions multi-services? --> Saga
|
+-- Pics de charge? --> Queue Load Leveling
|
+-- Migration legacy? --> Strangler Fig
|
+-- Acces fichiers direct? --> Valet Key + Static Content Hosting
|
+-- Coordination cluster? --> Leader Election
```

## Sources de reference

- [Azure Architecture Patterns](https://learn.microsoft.com/en-us/azure/architecture/patterns/)
- [AWS Architecture Patterns](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/)
- [GCP Architecture Patterns](https://cloud.google.com/architecture)
- [Martin Fowler - Patterns of EAA](https://martinfowler.com/eaaCatalog/)
- [microservices.io](https://microservices.io/patterns/)
