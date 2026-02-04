# Design Patterns Knowledge Base

## Purpose

Base de connaissances de 300+ patterns. **Consultée automatiquement** par `/plan` et `/review`.

## Structure

```
.claude/docs/
├── README.md              # INDEX PRINCIPAL
├── principles/            # SOLID, DRY, KISS, YAGNI
├── creational/            # Factory, Builder, Singleton
├── structural/            # Adapter, Decorator, Proxy
├── behavioral/            # Observer, Strategy, Command
├── performance/           # Cache, Lazy Load, Pool
├── concurrency/           # Thread Pool, Actor, Mutex
├── enterprise/            # PoEAA (40+ patterns)
├── messaging/             # EIP (31 patterns)
├── ddd/                   # Aggregate, Entity, Repository
├── functional/            # Monad, Either, Lens
├── architectural/         # Hexagonal, CQRS, Event Sourcing
├── cloud/                 # Circuit Breaker, Saga
├── resilience/            # Retry, Timeout, Bulkhead
├── security/              # OAuth, JWT, RBAC
├── testing/               # Mock, Stub, Fixture
├── devops/                # GitOps, IaC, Blue-Green
└── integration/           # API Gateway, BFF
```

## Quick Pattern Lookup

| Problème | Pattern | Catégorie |
|----------|---------|-----------|
| Création complexe | Builder | creational/ |
| Objets coûteux | Object Pool | performance/ |
| Race conditions | Mutex | concurrency/ |
| Pannes cascade | Circuit Breaker | cloud/ |
| Transactions distribuées | Saga | cloud/ |
| Auth | OAuth/JWT | security/ |
| Tests isolation | Mock/Stub | testing/ |

## Usage (Agents)

**Workflow :**
1. Consulter `README.md` → identifier catégorie
2. Lire `<catégorie>/README.md` → tableau de décision
3. Lire pattern spécifique → exemples Go

## Pattern Format

Chaque fichier DOIT contenir :

| Section | Obligatoire |
|---------|-------------|
| `# Nom` | ✓ |
| `> Description` | ✓ |
| Code Go | ✓ |
| Quand utiliser | ✓ |
| Patterns liés | ✓ |

**Templates :** `TEMPLATE-PATTERN.md`, `TEMPLATE-README.md`

## Sources

- GoF (23 patterns)
- Martin Fowler PoEAA (40+)
- Enterprise Integration Patterns (65)
- DDD (Eric Evans)
