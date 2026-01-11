# Microservices Architecture

> Décomposer une application en services indépendants, déployables séparément.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                          API Gateway                             │
└─────────────────────────────────────────────────────────────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
    ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
    │  User   │   │  Order  │   │ Product │   │ Payment │
    │ Service │   │ Service │   │ Service │   │ Service │
    └─────────┘   └─────────┘   └─────────┘   └─────────┘
         │              │              │              │
         ▼              ▼              ▼              ▼
    ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
    │ User DB │   │Order DB │   │Product  │   │Payment  │
    │(Postgres)│  │(MongoDB)│   │DB(Redis)│   │DB (SQL) │
    └─────────┘   └─────────┘   └─────────┘   └─────────┘
```

## Caractéristiques

| Aspect | Microservices |
|--------|---------------|
| Déploiement | Indépendant par service |
| Données | Base de données par service |
| Communication | API (REST, gRPC, Events) |
| Équipes | Autonomes par service |
| Scalabilité | Horizontale par service |
| Technologie | Polyglot possible |

## Quand utiliser

| ✅ Utiliser | ❌ Éviter |
|-------------|-----------|
| Grande équipe (>20 devs) | Petite équipe (<5) |
| Domaines bien définis | Domaine flou |
| Besoin de scale différent | Charge uniforme |
| Équipes autonomes | Équipe centralisée |
| Maturité DevOps | Pas de CI/CD |

## Patterns associés

### Communication

```
┌──────────────────────────────────────────────────────────┐
│                    Synchrone                              │
│  ┌─────────┐        REST/gRPC         ┌─────────┐        │
│  │Service A│ ─────────────────────▶  │Service B│        │
│  └─────────┘                          └─────────┘        │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│                    Asynchrone                             │
│  ┌─────────┐     ┌─────────┐          ┌─────────┐        │
│  │Service A│ ──▶ │  Queue  │ ──▶     │Service B│        │
│  └─────────┘     └─────────┘          └─────────┘        │
└──────────────────────────────────────────────────────────┘
```

### Service Discovery

```typescript
// Consul, Kubernetes DNS, etc.
const userService = await discovery.getService('user-service');
const response = await fetch(`${userService.url}/users/${id}`);
```

### Circuit Breaker

```typescript
// Voir cloud/circuit-breaker.md
const breaker = new CircuitBreaker(callUserService);
const user = await breaker.fire(userId);
```

### Saga Pattern

```typescript
// Transactions distribuées
// Voir cloud/saga.md
```

## Structure d'un microservice

```
user-service/
├── src/
│   ├── domain/           # Logique métier
│   ├── application/      # Use cases
│   ├── infrastructure/   # DB, HTTP, Messaging
│   └── main.ts
├── Dockerfile
├── k8s/
│   ├── deployment.yaml
│   └── service.yaml
├── tests/
└── package.json
```

## Anti-patterns

### Distributed Monolith

```
❌ Services trop couplés = pire que monolith

┌─────────┐   sync   ┌─────────┐   sync   ┌─────────┐
│Service A│ ◀──────▶ │Service B│ ◀──────▶ │Service C│
└─────────┘          └─────────┘          └─────────┘
     │                    │                    │
     └────────────────────┴────────────────────┘
              Tous dépendent les uns des autres
```

### Shared Database

```
❌ Base partagée = couplage caché

┌─────────┐   ┌─────────┐   ┌─────────┐
│Service A│   │Service B│   │Service C│
└────┬────┘   └────┬────┘   └────┬────┘
     │             │             │
     └─────────────┼─────────────┘
                   ▼
              ┌─────────┐
              │Shared DB│
              └─────────┘
```

## Migration depuis Monolith

```
Phase 1: Identifier les bounded contexts
Phase 2: Strangler Fig pattern
Phase 3: Extraire service par service
Phase 4: Découpler les données

┌─────────────────────────────────────────────┐
│               MONOLITH                       │
│  ┌───────┐  ┌───────┐  ┌───────┐           │
│  │ User  │  │ Order │  │Product│           │
│  │Module │  │Module │  │Module │           │
│  └───────┘  └───────┘  └───────┘           │
│                │                            │
│                ▼                            │
│           ┌─────────┐                       │
│           │   DB    │                       │
│           └─────────┘                       │
└─────────────────────────────────────────────┘
                    │
                    │ Strangler Fig
                    ▼
┌──────────┐  ┌──────────┐  ┌─────────────────┐
│  User    │  │  Order   │  │   MONOLITH      │
│ Service  │  │ Service  │  │  (shrinking)    │
└──────────┘  └──────────┘  └─────────────────┘
```

## Checklist avant adoption

- [ ] Équipe > 10 personnes ?
- [ ] Domaines clairement délimités ?
- [ ] Infrastructure Kubernetes/Docker ?
- [ ] CI/CD mature ?
- [ ] Monitoring/Observability en place ?
- [ ] Expérience systèmes distribués ?

## Sources

- [microservices.io](https://microservices.io/)
- [Martin Fowler - Microservices](https://martinfowler.com/articles/microservices.html)
- [Sam Newman - Building Microservices](https://samnewman.io/books/building_microservices/)
