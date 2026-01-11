# Design Patterns Knowledge Base

## Purpose

Base de connaissances exhaustive (250+ patterns) pour les agents Claude.
**Cette documentation DOIT être consultée** lors des phases de conception et review.

## Location

```
.claude/docs/
├── README.md              # INDEX PRINCIPAL - Toujours consulter en premier
├── CLAUDE.md              # Ce fichier - Instructions pour agents
├── TEMPLATE-PATTERN.md    # Template pour nouveaux patterns
├── TEMPLATE-README.md     # Template pour index de catégorie
├── principles/            # SOLID, DRY, KISS, YAGNI, GRASP, Defensive
├── creational/            # Factory, Builder, Singleton, Prototype
├── structural/            # Adapter, Decorator, Proxy, Facade, Composite
├── behavioral/            # Observer, Strategy, Command, State, Chain
├── performance/           # Cache, Lazy Load, Memoization, Buffer, Pool
├── concurrency/           # Thread Pool, Actor, Mutex, Pipeline, COW
├── enterprise/            # PoEAA (40+ patterns Martin Fowler)
├── messaging/             # EIP (31 patterns d'intégration)
├── ddd/                   # Aggregate, Entity, Value Object, Repository
├── functional/            # Monad, Functor, Either, Option, Lens
├── architectural/         # Hexagonal, CQRS, Event Sourcing, Serverless
├── cloud/                 # Circuit Breaker, Saga, Sharding, Cache-Aside
├── resilience/            # Retry, Timeout, Bulkhead, Rate Limiting
├── security/              # OAuth, JWT, RBAC, ABAC, Secrets
├── testing/               # Mock, Stub, Fixture, Property-Based
├── devops/                # GitOps, IaC, Blue-Green, Canary
├── integration/           # API Gateway, BFF, Service Mesh
└── refactoring/           # Branch by Abstraction, Strangler Fig
```

**Stats :** 155 fichiers - 300+ patterns documentés

---

## MANDATORY: Quand consulter les patterns

### Lors de `/plan` (Phase 2 - Conception)

```yaml
triggers:
  - "Créer une nouvelle feature"
  - "Refactoriser du code"
  - "Résoudre un problème architectural"
  - "Optimiser les performances"
  - "Implémenter de la concurrence"

actions:
  1. Lire docs/README.md pour identifier la catégorie
  2. Consulter le fichier de la catégorie (ex: performance/README.md)
  3. Identifier 1-3 patterns applicables
  4. Intégrer dans le plan avec justification
```

### Lors de `/review` (Analyse qualité)

```yaml
triggers:
  - "Review de code"
  - "Analyse de PR"
  - "Audit de qualité"

actions:
  1. Identifier les patterns utilisés dans le code
  2. Vérifier s'ils sont correctement implémentés
  3. Suggérer des patterns alternatifs si pertinent
  4. Référencer docs/ dans les suggestions
```

### Lors de développement général

```yaml
triggers:
  - User demande "comment implémenter X"
  - User mentionne un problème récurrent
  - Code smell détecté (duplication, couplage, etc.)

actions:
  1. Consulter le tableau "Patterns par Problème" dans README.md
  2. Lire le pattern correspondant
  3. Adapter l'exemple au contexte du projet
```

---

## How to Use (pour les agents)

### 1. Recherche par problème

```
User: "J'ai besoin de gérer du cache"

Agent:
  → Lire docs/README.md section "Patterns par Problème"
  → Trouver: Cache-Aside, Memoization, Write-Through
  → Lire docs/performance/README.md section Cache
  → Proposer la solution adaptée au contexte
```

### 2. Recherche par catégorie

```
User: "Comment structurer mes tests"

Agent:
  → Lire docs/testing/README.md
  → Identifier: Mock, Stub, Fake, Fixture, Builder
  → Proposer la combinaison appropriée
```

### 3. Validation d'architecture

```
User: "Review mon architecture"

Agent:
  → Lire docs/architectural/README.md
  → Lire docs/principles/ (SOLID, etc.)
  → Vérifier cohérence avec patterns standards
  → Suggérer améliorations
```

---

## Pattern Selection Guide

### Décision rapide

| Problème | → | Pattern | → | Fichier |
|----------|---|---------|---|---------|
| Création complexe | → | Builder | → | creational/README.md |
| Objets coûteux | → | Object Pool | → | performance/README.md |
| Race conditions | → | Mutex/Semaphore | → | concurrency/README.md |
| Pannes cascade | → | Circuit Breaker | → | cloud/circuit-breaker.md |
| Transactions distribuées | → | Saga | → | cloud/saga.md |
| Authentification | → | OAuth/JWT | → | security/README.md |
| Logique métier riche | → | DDD patterns | → | ddd/README.md |
| Tests isolation | → | Mock/Stub | → | testing/README.md |

### Hiérarchie de consultation

```
1. README.md (index, vue d'ensemble)
   ↓
2. principles/ (fondamentaux, toujours applicables)
   ↓
3. Catégorie spécifique (creational, behavioral, etc.)
   ↓
4. Pattern spécifique (fichier détaillé)
```

---

## Integration dans les Skills

### /plan

```markdown
## Phase 2 : Conception

**Étape obligatoire :** Consultation patterns

1. Identifier la nature du problème
2. Consulter `.claude/docs/README.md`
3. Lire les patterns pertinents
4. Intégrer dans le plan :
   - Pattern choisi
   - Justification
   - Référence au fichier docs/
```

### /review

```markdown
## Analyse patterns

1. Identifier patterns existants dans le code
2. Comparer avec best practices (docs/)
3. Dans le rapport :
   - "Pattern X correctement utilisé ✓"
   - "Suggère Pattern Y pour [problème]"
   - Référence: docs/category/file.md
```

---

## Format des patterns

Chaque pattern documenté contient :

```markdown
### Nom du Pattern

> Description courte (1 ligne)

```go
// Exemple de code fonctionnel
```

**Quand :** Cas d'usage
**Lié à :** Patterns connexes
```

Chaque catégorie contient :

```markdown
## Tableau de décision

| Besoin | Pattern |
|--------|---------|
| ... | ... |
```

---

## Sources référencées

- Gang of Four (GoF) - 23 patterns
- Martin Fowler PoEAA - 40+ patterns
- Enterprise Integration Patterns - 65 patterns
- Microsoft Azure Architecture Patterns
- DDD (Eric Evans, Vaughn Vernon)
- Functional Programming patterns

---

## Structure obligatoire des patterns

Chaque fichier pattern DOIT contenir :

| Section | Obligatoire | Description |
|---------|-------------|-------------|
| Titre H1 | ✓ | `# Nom du Pattern` |
| Description | ✓ | `> Description courte` |
| Exemple Go | ✓ | Code fonctionnel |
| Quand utiliser | ✓ | Cas d'usage |
| Patterns liés | ✓ | Relations |
| Sources | ⚠ | Recommandé |

→ Voir templates : `TEMPLATE-PATTERN.md`, `TEMPLATE-README.md`

### Créer un nouveau pattern

1. Copier `TEMPLATE-PATTERN.md` dans la catégorie appropriée
2. Renommer avec le nom du pattern (kebab-case)
3. Remplir toutes les sections
4. Mettre à jour le README.md de la catégorie
5. Valider la structure avec les templates
