# Design Patterns - Complete Reference

Base de données exhaustive des design patterns pour les agents Claude.

---

## Catégories

| # | Catégorie | Fichiers | Description |
|---|-----------|----------|-------------|
| 1 | [principles/](principles/) | 7 | SOLID, DRY, KISS, YAGNI, GRASP, Defensive |
| 2 | [creational/](creational/) | 4 | Factory, Builder, Singleton, Prototype |
| 3 | [structural/](structural/) | 5 | Adapter, Decorator, Proxy, Facade, Composite |
| 4 | [behavioral/](behavioral/) | 6 | Observer, Strategy, Command, State, Chain |
| 5 | [performance/](performance/) | 9 | Pool, Cache, Lazy, Memoization, Buffer |
| 6 | [concurrency/](concurrency/) | 9 | Thread Pool, Actor, Mutex, Pipeline, COW |
| 7 | [architectural/](architectural/) | 10 | Hexagonal, Microservices, CQRS, Event Sourcing |
| 8 | [enterprise/](enterprise/) | 13 | PoEAA - Transaction Script, Domain Model, DTO |
| 9 | [messaging/](messaging/) | 11 | EIP - Pipes, Router, Aggregator, Outbox |
| 10 | [ddd/](ddd/) | 9 | Entity, Value Object, Aggregate, Repository |
| 11 | [cloud/](cloud/) | 22 | Circuit Breaker, Saga, Sharding, Cache-Aside |
| 12 | [resilience/](resilience/) | 7 | Retry, Timeout, Bulkhead, Rate Limiting |
| 13 | [security/](security/) | 9 | OAuth, JWT, RBAC, ABAC, Secrets |
| 14 | [functional/](functional/) | 6 | Monad, Either, Option, Lens, Composition |
| 15 | [devops/](devops/) | 9 | GitOps, IaC, Blue-Green, Canary, Feature Toggles |
| 16 | [testing/](testing/) | 9 | Mock, Stub, Fixture, Property-Based, Contracts |
| 17 | [refactoring/](refactoring/) | 2 | Branch by Abstraction, Strangler Fig |
| 18 | [integration/](integration/) | 6 | API Gateway, BFF, Service Mesh, Sidecar |

Total : 155 fichiers markdown - 300+ patterns documentés

---

## Index Alphabétique Complet

### A

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Abstract Factory | creational | Familles d'objets liés |
| Active Record | enterprise | Objet = row DB |
| Actor Model | concurrency | Concurrence par messages |
| Adapter | structural | Convertir interfaces |
| Aggregator | messaging | Combiner messages |
| Aggregate | ddd | Cluster d'entités |
| Ambassador | cloud | Proxy helper services |
| Anti-Corruption Layer | integration | Isoler legacy |
| API Gateway | integration | Point d'entrée unique |
| Application Controller | enterprise | Workflow UI |
| Applicative Functor | functional | Séquençage d'effets |
| Async/Await | concurrency | Asynchrone simplifié |

### B

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Backend for Frontend (BFF) | integration | Backend par client |
| Barrier | concurrency | Synchronisation threads |
| Blue-Green Deployment | devops | Zero-downtime deploy |
| Branch by Abstraction | refactoring | Migration progressive |
| Bridge | structural | Abstraction/implémentation |
| Buffer | performance | Stockage temporaire |
| Builder | creational | Construction complexe |
| Bulkhead | resilience | Isolation ressources |

### C

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Cache-Aside | cloud | Cache on-demand |
| Canary Deployment | devops | Déploiement progressif |
| Chain of Responsibility | behavioral | Pipeline handlers |
| Copy-on-Write | concurrency | Copie différée écriture |
| Choreography | architectural | Orchestration décentralisée |
| Circuit Breaker | resilience | Prévenir pannes cascade |
| Claim Check | messaging | Message + référence payload |
| Class Table Inheritance | enterprise | Héritage = tables |
| Client Session State | enterprise | État côté client |
| Coarse-Grained Lock | concurrency | Lock sur groupe |
| Command | behavioral | Encapsuler requêtes |
| Command Message | messaging | Message = commande |
| Competing Consumers | messaging | Consommateurs parallèles |
| Composite | structural | Structures arborescentes |
| Composition | functional | f(g(x)) |
| Concrete Table Inheritance | enterprise | Classe = table |
| Content Enricher | messaging | Enrichir message |
| Content Filter | messaging | Filtrer contenu |
| Content-Based Router | messaging | Router par contenu |
| Correlation Identifier | messaging | Lier requête/réponse |
| CQRS | architectural | Séparer lecture/écriture |
| Currying | functional | f(a,b) → f(a)(b) |

### D

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Data Mapper | enterprise | Mapping objet-DB |
| Defensive Programming | principles | Validation défensive |
| Design by Contract | principles | Pré/post conditions |
| Data Transfer Object (DTO) | enterprise | Transférer données |
| Dead Letter Channel | messaging | Messages en erreur |
| Debounce | performance | Délai avant exécution |
| Decorator | structural | Ajouter comportements |
| Dependency Injection | structural | Inverser dépendances |
| Domain Event | ddd | Événement métier |
| Domain Model | enterprise | Logique métier riche |
| Domain Service | ddd | Logique sans entité |
| Double-Checked Locking | concurrency | Lazy singleton thread-safe |
| Durable Subscriber | messaging | Subscription persistante |
| Dynamic Router | messaging | Routage dynamique |

### E

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Embedded Value | enterprise | Value Object en colonne |
| Entity | ddd | Objet avec identité |
| Envelope Wrapper | messaging | Encapsuler message |
| Event Message | messaging | Notification événement |
| Event Sourcing | architectural | Historique d'événements |
| Event-Driven Architecture | architectural | Architecture événementielle |
| Event-Driven Consumer | messaging | Consommateur événementiel |
| External Configuration Store | cloud | Config externalisée |

### F

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Facade | structural | Interface simplifiée |
| Factory | ddd | Créer aggregates |
| Factory Method | creational | Déléguer création |
| Fail-Fast | principles | Échouer immédiatement |
| Feature Toggle | devops | Activation conditionnelle |
| Federated Identity | security | Auth déléguée |
| Fixture | testing | Données de test |
| Flyweight | structural | Partager état commun |
| Foreign Key Mapping | enterprise | FK en référence |
| Front Controller | enterprise | Point d'entrée unique |
| Functor | functional | map() sur container |
| Future/Promise | concurrency | Valeur asynchrone |

### G

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Gateway | enterprise | Accès système externe |
| GRASP (9 patterns) | principles | Attribution responsabilités |
| Guard Clause | principles | Validation early return |
| Gateway Aggregation | cloud | Agréger requêtes |
| Gateway Offloading | cloud | Décharger gateway |
| Gateway Routing | cloud | Router requêtes |
| Geode | cloud | Multi-région |
| GitOps | devops | Git = source de vérité |
| Guaranteed Delivery | messaging | Livraison garantie |
| Guard Clause | principles | Validation early return |

### H

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Half-Sync/Half-Async | concurrency | Sync + Async combinés |
| Health Check | resilience | Vérifier état service |
| Hexagonal Architecture | architectural | Ports & Adapters |

### I

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Idempotent Receiver | messaging | Traitement unique |
| Identity Field | enterprise | ID en attribut |
| Identity Map | enterprise | Cache objets chargés |
| Immutable Infrastructure | devops | Infra remplacée, pas modifiée |
| Implicit Lock | concurrency | Lock automatique |
| Infrastructure as Code | devops | Infra en code |
| Inheritance Mappers | enterprise | Stratégies héritage DB |
| Integration Patterns | enterprise | Patterns d'intégration |
| Interpreter | behavioral | Interpréter grammaire |
| Invalid Message Channel | messaging | Messages invalides |
| Iterator | behavioral | Parcours collection |

### J-K

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| JWT | security | Token auto-contenu |

### L

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Layer Supertype | enterprise | Classe de base couche |
| Layered Architecture | architectural | Architecture en couches |
| Lazy Load | performance | Chargement différé |
| Leader Election | cloud | Élire coordinateur |
| Lock | concurrency | Exclusion mutuelle |

### M

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Mapper | enterprise | Conversion objets |
| Materialized View | cloud | Vue pré-calculée |
| Mediator | behavioral | Réduire couplage |
| Memento | behavioral | Sauvegarder état |
| Memoization | performance | Cache résultats fonction |
| Message | messaging | Unité de communication |
| Message Broker | messaging | Intermédiaire messages |
| Message Bus | messaging | Bus de messages |
| Message Channel | messaging | Canal de transport |
| Message Dispatcher | messaging | Distribuer messages |
| Message Endpoint | messaging | Point de connexion |
| Message Expiration | messaging | Durée de vie message |
| Message Filter | messaging | Filtrer messages |
| Message History | messaging | Historique routage |
| Message Router | messaging | Router messages |
| Message Sequence | messaging | Ordre des messages |
| Message Store | messaging | Stocker messages |
| Message Translator | messaging | Traduire format |
| Messaging Bridge | messaging | Connecter systèmes |
| Messaging Gateway | messaging | Abstraction messaging |
| Messaging Mapper | messaging | Mapper messages |
| Metadata Mapping | enterprise | Mapping par métadonnées |
| Microservices | architectural | Services indépendants |
| Mock | testing | Simuler comportement |
| Model View Controller (MVC) | enterprise | Séparation UI |
| Module | ddd | Regrouper concepts |
| Monad | functional | Chaînage + contexte |
| Money | enterprise | Valeur monétaire |
| Monitor | concurrency | Lock + condition |
| Monolith | architectural | Application unique |
| Multiton | creational | Pool de singletons |
| Mutex | concurrency | Verrou exclusif |

### N

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Normalizer | messaging | Standardiser format |
| Null Object | behavioral | Éviter null checks |

### O

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| OAuth | security | Délégation d'accès |
| Object Mother | testing | Factory d'objets test |
| Object Pool | performance | Réutiliser objets |
| Observer | behavioral | Notification changements |
| Optimistic Lock | concurrency | Détecter conflits |
| Optimistic Offline Lock | enterprise | Lock optimiste |
| Outbox | messaging | Fiabilité événements |

### P

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Page Controller | enterprise | Controller par page |
| Pessimistic Lock | concurrency | Prévenir conflits |
| Pessimistic Offline Lock | enterprise | Lock pessimiste |
| Pipes and Filters | messaging | Pipeline traitement |
| Plugin | enterprise | Extension dynamique |
| Point-to-Point Channel | messaging | Un émetteur, un récepteur |
| Polling Consumer | messaging | Polling messages |
| Priority Queue | cloud | File prioritaire |
| Process Manager | messaging | Orchestrer workflow |
| Producer-Consumer | concurrency | File entre threads |
| Prototype | creational | Cloner objets |
| Proxy | structural | Contrôler accès |
| Publish-Subscribe | messaging | Multi-abonnés |
| Publisher Confirms | messaging | Confirmation publication |

### Q

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Quarantine | cloud | Isoler assets suspects |
| Query Object | enterprise | Construire requêtes |
| Queue-Based Load Leveling | cloud | Lisser la charge |

### R

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Rate Limiting | resilience | Limiter débit |
| RBAC | security | Contrôle par rôles |
| Read-Through Cache | performance | Cache transparent lecture |
| Read-Write Lock | concurrency | Lock lecture/écriture |
| Recipient List | messaging | Liste destinataires |
| Record Set | enterprise | Collection rows |
| Registry | enterprise | Accès global objets |
| Remote Facade | enterprise | API simplifiée distante |
| Repository | ddd | Accès aggregates |
| Request-Reply | messaging | Requête/réponse |
| Resequencer | messaging | Réordonner messages |
| Retry | resilience | Réessayer en erreur |
| Return Address | messaging | Adresse de retour |
| Ring Buffer | performance | Buffer circulaire |
| Routing Slip | messaging | Itinéraire message |
| Row Data Gateway | enterprise | Gateway par row |

### S

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Saga | cloud | Transactions distribuées |
| Scatter-Gather | messaging | Distribuer et collecter |
| Scheduler Agent Supervisor | cloud | Coordonner tâches |
| Selective Consumer | messaging | Filtrer à réception |
| Semaphore | concurrency | Limiter accès concurrent |
| Separated Interface | enterprise | Interface séparée |
| Serialized LOB | enterprise | Sérialiser objets |
| Server Session State | enterprise | État côté serveur |
| Service Activator | messaging | Activer service |
| Service Layer | enterprise | Couche de services |
| Service Locator | enterprise | Localiser services |
| Service Stub | enterprise | Stub de service |
| Service Mesh | integration | Communication inter-services |
| Sharding | cloud | Partitionner données |
| Sidecar | integration | Container auxiliaire |
| Single Table Inheritance | enterprise | Héritage = 1 table |
| Singleton | creational | Instance unique |
| Smart Proxy | messaging | Proxy intelligent |
| Specification | ddd | Règle métier |
| Splitter | messaging | Diviser message |
| State | behavioral | Comportement par état |
| Static Content Hosting | cloud | Contenu statique cloud |
| Strangler Fig | cloud | Migration progressive |
| Strategy | behavioral | Algorithmes variables |
| Stub | testing | Réponse prédéfinie |
| Supervisor | concurrency | Gérer erreurs actors |

### T

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Table Data Gateway | enterprise | Gateway par table |
| Table Module | enterprise | Module par table |
| Template Method | behavioral | Squelette algorithme |
| Template View | enterprise | Vue avec template |
| Test Double | testing | Remplaçant pour tests |
| Thread Pool | concurrency | Pool de threads |
| Throttling | resilience | Limiter consommation |
| Timeout | resilience | Limiter durée |
| Transaction Script | enterprise | Script par transaction |
| Transactional Client | messaging | Client transactionnel |
| Transactional Outbox | messaging | Outbox transactionnel |
| Transform View | enterprise | Transformation vue |
| Two Step View | enterprise | Vue en 2 étapes |

### U

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Ubiquitous Language | ddd | Langage commun |
| Unit of Work | enterprise | Regrouper modifications |

### V

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Valet Key | cloud | Accès temporaire |
| Value Object | ddd | Objet sans identité |
| Virtual Proxy | structural | Lazy load via proxy |
| Visitor | behavioral | Opérations sur structure |

### W

| Pattern | Catégorie | Usage |
|---------|-----------|-------|
| Wire Tap | messaging | Intercepter messages |
| Write-Behind Cache | performance | Écriture asynchrone |
| Write-Through Cache | performance | Écriture synchrone |

---

## Patterns par Problème

### Validation / Robustesse

| Problème | Patterns |
|----------|----------|
| Variables nulles/invalides | Guard Clause, Null Object |
| Conditions imbriquées | Guard Clause, Early Return |
| Invariants métier | Design by Contract, Assertions |
| Données externes | Input Validation, Type Guards |
| Dépendances manquantes | Fail-Fast, Dependency Validation |
| Modifications accidentelles | Immutability, Copy-on-Write |

### Création d'objets

| Problème | Patterns |
|----------|----------|
| Construction complexe | Builder |
| Familles d'objets | Abstract Factory |
| Déléguer création | Factory Method |
| Objets coûteux réutilisables | Object Pool |
| Copie efficace | Prototype |
| Instance unique | Singleton, Multiton |

### Performance

| Problème | Patterns |
|----------|----------|
| Objets coûteux | Object Pool, Flyweight |
| Données fréquentes | Cache-Aside, Memoization |
| I/O lent | Buffer, Lazy Load |
| Appels répétés | Debounce, Throttle |

### Concurrence

| Problème | Patterns |
|----------|----------|
| Threads coûteux | Thread Pool |
| Partage de données | Lock, Mutex, Semaphore |
| Communication inter-thread | Producer-Consumer, Actor |
| Async simplifié | Future/Promise, Async/Await |

### Résilience

| Problème | Patterns |
|----------|----------|
| Pannes en cascade | Circuit Breaker |
| Erreurs temporaires | Retry, Timeout |
| Isolation | Bulkhead |
| Monitoring | Health Check |

### Distribution

| Problème | Patterns |
|----------|----------|
| Transactions distribuées | Saga, Outbox |
| Communication | Message Queue, Pub/Sub |
| Scalabilité | Sharding, CQRS |
| Multi-région | Geode |

### Sécurité

| Problème | Patterns |
|----------|----------|
| Authentification | OAuth, JWT, OIDC |
| Autorisation | RBAC, ABAC |
| Secrets | Vault, Sealed Secrets |

### Refactoring / Migration

| Problème | Patterns |
|----------|----------|
| Migration sans branches longues | Branch by Abstraction |
| Remplacement système legacy | Strangler Fig |
| Déploiement progressif | Feature Toggle, Canary |
| Test nouvelle implémentation | Parallel Run, Dark Launch |
| Rollback instantané | Feature Toggle |

---

## Relations entre Patterns

```
                    PRINCIPES
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
    CREATIONAL      STRUCTURAL      BEHAVIORAL
        │               │               │
        └───────────────┼───────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
   ENTERPRISE         DDD           FUNCTIONAL
        │               │               │
        └───────────────┼───────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
  ARCHITECTURAL     MESSAGING        CLOUD
        │               │               │
        └───────────────┼───────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
   RESILIENCE       SECURITY        DEVOPS
```

---

## Sources

- [Gang of Four - Design Patterns](https://en.wikipedia.org/wiki/Design_Patterns)
- [Martin Fowler - PoEAA](https://martinfowler.com/eaaCatalog/)
- [Enterprise Integration Patterns](https://www.enterpriseintegrationpatterns.com/)
- [Microsoft Azure Patterns](https://learn.microsoft.com/en-us/azure/architecture/patterns/)
- [microservices.io](https://microservices.io/patterns/)
- [Refactoring Guru](https://refactoring.guru/design-patterns)
