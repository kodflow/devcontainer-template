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

## Categories

### Resilience et stabilite

| Pattern | Description | Cas d'usage |
|---------|-------------|-------------|
| **Circuit Breaker** | Coupe les appels vers services defaillants | API externe instable |
| **Saga** | Transactions distribuees avec compensation | E-commerce multi-services |
| **Retry** | Reessaie les operations transitoires | Erreurs reseau temporaires |
| **Bulkhead** | Isole les ressources par domaine | Eviter contamination |

### Gestion des donnees

| Pattern | Description | Cas d'usage |
|---------|-------------|-------------|
| **Cache-Aside** | Cache a la demande avec TTL | Lecture intensive DB |
| **Sharding** | Partitionnement horizontal | Grandes volumetries |
| **Materialized View** | Vues pre-calculees | Queries analytiques |
| **CQRS** | Separation read/write | Domaines complexes |
| **Event Sourcing** | Historique evenementiel | Audit, replay |

### Messaging et queues

| Pattern | Description | Cas d'usage |
|---------|-------------|-------------|
| **Priority Queue** | Traitement par priorite | SLA differencies |
| **Queue Load Leveling** | Lissage de charge | Pics previsibles |
| **Competing Consumers** | Parallelisation traitement | Scalabilite horizontale |

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
