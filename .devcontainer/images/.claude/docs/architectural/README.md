# Architectural Patterns

Patterns d'architecture logicielle pour structurer les applications.

---

## Fichiers

| Fichier | Contenu | Usage |
|---------|---------|-------|
| [monolith.md](monolith.md) | Architecture monolithique | Simple, démarrage rapide |
| [modular-monolith.md](modular-monolith.md) | Monolithe modulaire | Structure sans distribution |
| [layered.md](layered.md) | Architecture en couches | Séparation responsabilités |
| [hexagonal.md](hexagonal.md) | Ports & Adapters | Isolation domaine |
| [microservices.md](microservices.md) | Services distribués | Scale et autonomie |
| [cqrs.md](cqrs.md) | Command Query Separation | Read/Write séparés |
| [event-sourcing.md](event-sourcing.md) | Historique événements | Audit, replay |
| [event-driven.md](event-driven.md) | Architecture événementielle | Découplage asynchrone |
| [serverless.md](serverless.md) | FaaS / Event-driven | Pay-per-use, auto-scale |

---

## Tableau de décision

| Architecture | Équipe | Complexité domaine | Scalabilité | DevOps |
|--------------|--------|-------------------|-------------|--------|
| **Monolith** | 1-10 | Simple/Moyenne | Verticale | Basique |
| **Modular Monolith** | 5-30 | Moyenne/Complexe | Verticale | Basique |
| **Layered (N-tier)** | 5-20 | Moyenne | Verticale | Basique |
| **Hexagonal** | 5-30 | Complexe | Verticale | Moyen |
| **Microservices** | 20+ | Complexe | Horizontale | Avancé |
| **Event Sourcing** | 10+ | Audit requis | Horizontale | Avancé |
| **Event-Driven** | 10+ | Asynchrone | Horizontale | Avancé |
| **Serverless** | 1-50 | Variable | Auto | Moyen |

---

## Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                 SPECTRE ARCHITECTURAL                            │
│                                                                  │
│  Monolith ──────────────────────────────────▶ Microservices     │
│                                                                  │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────────────┐ │
│  │Monolith │   │Modular  │   │Hexagonal│   │  Microservices  │ │
│  │         │   │Monolith │   │         │   │                 │ │
│  │ ┌─────┐ │   │┌─┐┌─┐┌─┐│   │  ┌───┐  │   │ ┌─┐ ┌─┐ ┌─┐    │ │
│  │ │     │ │   ││A││B││C││   │  │ D │  │   │ │S│ │S│ │S│    │ │
│  │ │     │ │   │└─┘└─┘└─┘│   │  │   │  │   │ │1│ │2│ │3│    │ │
│  │ └─────┘ │   │   │     │   │  └───┘  │   │ └─┘ └─┘ └─┘    │ │
│  └─────────┘   └─────────┘   └─────────┘   └─────────────────┘ │
│                                                                  │
│  Simple ◀───────────────────────────────────────────▶ Complexe │
│  Couplé ◀───────────────────────────────────────────▶ Découplé │
└─────────────────────────────────────────────────────────────────┘
```

---

## Flux de décision

```
                        Nouveau projet?
                             │
                             ▼
              ┌─── Domaine bien compris? ───┐
              │                              │
            Non                            Oui
              │                              │
              ▼                              ▼
          Monolith              ┌── Équipe > 20 devs? ──┐
          (explorer)            │                        │
                              Non                      Oui
                                │                        │
                                ▼                        ▼
                    ┌── Audit/Replay requis? ──┐    Microservices
                    │                           │
                  Oui                         Non
                    │                           │
                    ▼                           ▼
              Event Sourcing        ┌── Tests domaine critiques? ──┐
                    +               │                               │
              Event-Driven        Oui                             Non
                                    │                               │
                                    ▼                               ▼
                              Hexagonal /                   Modular Monolith
                              Clean Arch                    ou Layered
```

---

## Comparaison des architectures

### Couplage & Cohésion

| Architecture | Couplage | Cohésion | Testabilité |
|--------------|----------|----------|-------------|
| Monolith | Fort | Variable | Difficile |
| Modular Monolith | Moyen | Haute | Bonne |
| Layered | Moyen | Moyenne | Moyenne |
| Hexagonal | Faible | Haute | Excellente |
| Microservices | Faible | Haute | Excellente |
| Event-Driven | Très faible | Haute | Complexe |

### Coût & Complexité

| Architecture | Coût initial | Coût maintenance | Complexité ops |
|--------------|--------------|------------------|----------------|
| Monolith | Bas | Croissant | Bas |
| Modular Monolith | Moyen | Stable | Bas |
| Layered | Bas | Moyen | Bas |
| Hexagonal | Moyen | Stable | Moyen |
| Microservices | Élevé | Distribué | Élevé |
| Serverless | Bas | Pay-per-use | Moyen |

---

## Migration paths

### Monolith vers Microservices

```
Monolith → Modular Monolith → Microservices
    │              │                 │
    ▼              ▼                 ▼
1. Identifier     2. Séparer en     3. Extraire
   bounded           modules avec      services
   contexts          interfaces         un par un
                     claires          (Strangler Fig)
```

### Vers Event Sourcing

```
CRUD traditionnel → CQRS → Event Sourcing
       │              │           │
       ▼              ▼           ▼
   1. Séparer      2. Ajouter   3. Remplacer
      read/write      events       état par
      modèles         comme        stream
                      side-effect   d'events
```

---

## Patterns par problème

| Problème | Architecture recommandée |
|----------|-------------------------|
| MVP / Startup | Monolith |
| Domaine complexe | Hexagonal |
| Équipe > 20 devs | Microservices |
| Audit/Compliance | Event Sourcing |
| Haute disponibilité | Event-Driven |
| Variable workloads | Serverless |
| Legacy modernization | Modular Monolith |
| API simple | Layered |

---

## Combinaisons courantes

### Backend moderne

```
Hexagonal + CQRS + Event-Driven
           │
           ▼
┌──────────────────────────────────┐
│  ┌─────────────────────────────┐ │
│  │        API Layer            │ │
│  │  (REST / GraphQL / gRPC)    │ │
│  └─────────────────────────────┘ │
│              │                   │
│  ┌───────────┴───────────┐      │
│  │ Commands    Queries   │      │
│  │    │           │      │      │
│  │ Write DB   Read DB    │      │
│  │    │           │      │      │
│  │    └─── Events ───┘   │      │
│  └───────────────────────┘      │
└──────────────────────────────────┘
```

### Full Serverless

```
Serverless + Event-Driven
           │
           ▼
┌──────────────────────────────────┐
│  API Gateway                     │
│       │                          │
│  ┌────┴────┐                    │
│  │ Lambda  │◀── Events ──┐      │
│  └────┬────┘              │      │
│       │                   │      │
│  ┌────▼────┐    ┌────────▼────┐ │
│  │  DynamoDB   │ EventBridge  │ │
│  └─────────┘    └─────────────┘ │
└──────────────────────────────────┘
```

---

## Patterns liés par catégorie

| Catégorie | Patterns |
|-----------|----------|
| **Design** | DDD, Clean Architecture |
| **Communication** | REST, gRPC, GraphQL, Events |
| **Data** | CQRS, Event Sourcing, Saga |
| **Resilience** | Circuit Breaker, Bulkhead, Retry |
| **DevOps** | GitOps, Blue-Green, Canary |

---

## Sources

- [Martin Fowler - Software Architecture](https://martinfowler.com/architecture/)
- [Sam Newman - Building Microservices](https://samnewman.io/)
- [Alistair Cockburn - Hexagonal Architecture](https://alistair.cockburn.us/)
- [Eric Evans - Domain-Driven Design](https://domainlanguage.com/)
- [Microsoft - Architecture Patterns](https://docs.microsoft.com/en-us/azure/architecture/patterns/)
