---
name: improve
description: |
  Documentation Quality Assurance for Design Patterns Knowledge Base.
  Audits pattern documentation for consistency, completeness, and freshness.
  Scope: /workspace/.devcontainer/images/.claude/docs/ directory only.
allowed-tools:
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "Write(**/*)"
  - "Edit(**/*)"
  - "Task(*)"
  - "WebSearch(*)"
  - "WebFetch(*)"
---

# /improve - Documentation Quality Assurance

$ARGUMENTS

---

## Configuration

```yaml
# Chemin absolu vers la documentation (après build Docker)
DOCS_ROOT: /workspace/.devcontainer/images/.claude/docs

# Structure attendue
paths:
  docs: "${DOCS_ROOT}"
  templates:
    pattern: "${DOCS_ROOT}/TEMPLATE-PATTERN.md"
    readme: "${DOCS_ROOT}/TEMPLATE-README.md"
  index: "${DOCS_ROOT}/README.md"
  config: "${DOCS_ROOT}/CLAUDE.md"
  categories:
    - "${DOCS_ROOT}/principles/"
    - "${DOCS_ROOT}/creational/"
    - "${DOCS_ROOT}/structural/"
    - "${DOCS_ROOT}/behavioral/"
    - "${DOCS_ROOT}/performance/"
    - "${DOCS_ROOT}/concurrency/"
    - "${DOCS_ROOT}/enterprise/"
    - "${DOCS_ROOT}/messaging/"
    - "${DOCS_ROOT}/ddd/"
    - "${DOCS_ROOT}/functional/"
    - "${DOCS_ROOT}/architectural/"
    - "${DOCS_ROOT}/cloud/"
    - "${DOCS_ROOT}/resilience/"
    - "${DOCS_ROOT}/security/"
    - "${DOCS_ROOT}/testing/"
    - "${DOCS_ROOT}/devops/"
    - "${DOCS_ROOT}/integration/"
    - "${DOCS_ROOT}/refactoring/"
```

**IMPORTANT:** Toutes les opérations DOIVENT utiliser `/workspace/.devcontainer/images/.claude/docs/` comme racine.

---

## Help

Si `--help` est passé en argument, afficher cette aide et s'arrêter :

```
/improve --help
```

```
═══════════════════════════════════════════════════════════════
  /improve - Design Patterns Documentation QA
═══════════════════════════════════════════════════════════════

  DESCRIPTION
    Audit et amélioration de la base de connaissances Design Patterns.
    Vérifie la cohérence, complétude et fraîcheur de la documentation.

  USAGE
    /improve [OPTIONS]

  OPTIONS
    --help              Affiche cette aide
    --check             Audit sans modification (dry-run)
    --fix               Corriger automatiquement les problèmes
    --report            Générer un rapport détaillé markdown
    --structure         Vérifier uniquement la structure des fichiers
    --freshness         Vérifier uniquement si les concepts sont à jour
    --missing           Identifier les patterns manquants
    --category <name>   Auditer une catégorie spécifique
                        Ex: /improve --category cloud

  EXAMPLES
    /improve                    # Audit complet
    /improve --check            # Voir les problèmes sans corriger
    /improve --fix              # Corriger automatiquement
    /improve --category ddd     # Auditer uniquement ddd/
    /improve --missing          # Lister patterns manquants

  SCORING
    A+ : 100%     Complet
    A  : 90-99%   Très bon
    B  : 70-89%   Acceptable
    C  : 50-69%   À améliorer
    F  : <50%     Incomplet

  FILES
    Root:       /workspace/.devcontainer/images/.claude/docs/
    Templates:  TEMPLATE-PATTERN.md, TEMPLATE-README.md
    Config:     CLAUDE.md (instructions agents)
    Index:      README.md (index principal)

═══════════════════════════════════════════════════════════════
```

**IMPORTANT:** Si `$ARGUMENTS` contient `--help`, afficher l'aide ci-dessus et STOP.

---

## Workflow

```yaml
# Détection des arguments
args_parsing:
  --help: "Afficher aide et STOP"
  --check: "mode = dry-run"
  --fix: "mode = auto-fix"
  --report: "mode = report"
  --structure: "scope = structure_only"
  --freshness: "scope = freshness_only"
  --missing: "scope = missing_only"
  --category <name>: "filter = category_name"
  default: "mode = check, scope = all"

# Workflow principal (si pas --help)
improve_workflow:
  phase_1_inventory:
    action: "Scanner tous les fichiers .md dans /workspace/.devcontainer/images/.claude/docs/"
    tools: [Glob]
    path: "/workspace/.devcontainer/images/.claude/docs"
    pattern: "**/*.md"
    output: "file_list, category_map"

  phase_2_structure_check:
    skip_if: "scope == freshness_only || scope == missing_only"
    action: "Vérifier la structure de chaque fichier"
    checks:
      pattern_files:
        - "Titre H1 présent: ^# .+"
        - "Description blockquote: ^> .+"
        - "Exemple TypeScript: ```typescript"
        - "Section Quand: ## Quand ou **Quand**"
        - "Patterns liés: ## Patterns liés ou **Lié à**"
        - "Sources (recommandé): ## Sources"
      readme_files:
        - "Titre catégorie: ^# .+"
        - "Table des patterns: | Pattern |"
        - "Tableau de décision: | Besoin | ou | Problème |"
    output: "structure_issues[]"

  phase_3_consistency_check:
    skip_if: "scope != all"
    action: "Vérifier la cohérence entre fichiers"
    checks:
      - "Format des tableaux uniforme"
      - "Nommage des sections consistant"
      - "Liens internes valides"
      - "Patterns référencés existent"
    output: "consistency_issues[]"

  phase_4_completeness_check:
    skip_if: "scope == structure_only || scope == freshness_only"
    action: "Identifier patterns manquants"
    method:
      - "Comparer avec GoF (23 patterns)"
      - "Comparer avec PoEAA (40+ patterns)"
      - "Comparer avec EIP (65 patterns)"
      - "Vérifier mentions dans README non documentées"
      - "Identifier patterns liés non documentés"
    output: "missing_patterns[]"

  phase_5_freshness_check:
    skip_if: "scope == structure_only || scope == missing_only"
    action: "Vérifier que les concepts sont à jour"
    method:
      - "WebSearch: '{pattern} best practices 2024 2025'"
      - "Vérifier syntaxe TypeScript moderne"
      - "Comparer avec documentation officielle"
    output: "outdated_patterns[]"

  phase_6_output:
    modes:
      check: "Afficher rapport, ne pas modifier"
      fix: "Corriger automatiquement, rapport des changements"
      report: "Générer rapport markdown détaillé"
```

---

## Structure Standard

### Fichiers pattern (*.md sauf README)

| Section | Pattern Regex | Obligatoire |
|---------|---------------|-------------|
| Titre H1 | `^# .+` | ✓ |
| Description | `^> .+` | ✓ |
| Exemple TypeScript | ` ```typescript` | ✓ |
| Quand utiliser | `## Quand` ou `**Quand**` | ✓ |
| Patterns liés | `## Patterns liés` ou `**Lié à**` | ✓ |
| Sources | `## Sources` | Recommandé |

### Fichiers README.md (index catégorie)

| Section | Obligatoire |
|---------|-------------|
| Titre catégorie H1 | ✓ |
| Table des patterns documentés | ✓ |
| Résumé de chaque pattern | ✓ |
| Tableau de décision | ✓ |
| Sources | Recommandé |

---

## Agents Parallèles

Pour les audits complets, utiliser Task tool :

```yaml
agents:
  structure-auditor:
    type: "Explore"
    prompt: |
      Audit structure of all .md files in /workspace/.devcontainer/images/.claude/docs/{category}/
      Check required sections per /workspace/.devcontainer/images/.claude/docs/TEMPLATE-PATTERN.md
      Return: {file, issues[], score}

  consistency-checker:
    type: "Explore"
    prompt: |
      Check consistency across pattern files in /workspace/.devcontainer/images/.claude/docs/
      Verify: table formats, section names, link validity
      Return: {issues[], suggestions[]}

  freshness-validator:
    type: "general-purpose"
    prompt: |
      For each pattern in /workspace/.devcontainer/images/.claude/docs/, verify current best practices
      Use WebSearch for recent updates
      Return: {pattern, status, updates_needed[]}

  missing-detector:
    type: "Explore"
    prompt: |
      Compare documented patterns in /workspace/.devcontainer/images/.claude/docs/ against catalogs:
      - GoF: 23 patterns
      - PoEAA: 40+ patterns
      - EIP: 65 patterns
      - Azure/Cloud: 40+ patterns
      Return: {missing[], priority}
```

---

## Output Format

### Mode --check (défaut)

```
═══════════════════════════════════════════════════════════════
  /improve - Documentation Audit Report
═══════════════════════════════════════════════════════════════

  Scanned: {count} files in {categories} categories

  Structure Issues:   {n}
  Consistency Issues: {n}
  Missing Patterns:   {n}
  Outdated Patterns:  {n}

  Overall Score: {grade} ({percent}%)

═══════════════════════════════════════════════════════════════

## Structure Issues

| File | Issue | Severity |
|------|-------|----------|
| ... | ... | High/Medium/Low |

## Missing Patterns

| Pattern | Category | Priority | Source |
|---------|----------|----------|--------|
| ... | ... | High/Medium | GoF/PoEAA/EIP |

## Suggested Fixes

1. ...
2. ...

═══════════════════════════════════════════════════════════════
```

### Mode --fix

```
═══════════════════════════════════════════════════════════════
  /improve --fix - Auto-Fix Report
═══════════════════════════════════════════════════════════════

  Fixed:     {n} issues
  Created:   {n} new files
  Updated:   {n} existing files
  Remaining: {n} (require manual review)

  Changes:
  - [FIXED] Added "Patterns liés" to cloud/saga.md
  - [CREATED] behavioral/memento.md
  - [UPDATED] README.md index table

═══════════════════════════════════════════════════════════════
```

---

## Référentiels

### Sources canoniques

| Source | Patterns | Catégories |
|--------|----------|------------|
| GoF | 23 | creational/, structural/, behavioral/ |
| PoEAA (Fowler) | 40+ | enterprise/ |
| EIP | 65 | messaging/ |
| Azure Patterns | 40+ | cloud/, resilience/ |
| DDD (Evans) | 15+ | ddd/ |
| SOLID/GRASP | 14 | principles/ |

### Priorité de vérification fraîcheur

```yaml
high_evolution:    # Vérifier souvent
  - cloud/*
  - security/*
  - devops/*

medium_evolution:  # Vérifier périodiquement
  - architectural/*
  - testing/*

stable:            # Rarement modifiés
  - principles/*
  - creational/*
  - structural/*
  - behavioral/*
```

---

## GARDE-FOUS

| Action | Status |
|--------|--------|
| Supprimer des fichiers | INTERDIT |
| Modifier sans justification | INTERDIT |
| Ignorer erreurs de structure | INTERDIT |
| Créer patterns sans recherche | INTERDIT |
| Valider sans vérifier sources | WARNING |

---

## Templates

Utiliser ces templates pour créer/corriger :

- **Nouveau pattern:** Copier `/workspace/.devcontainer/images/.claude/docs/TEMPLATE-PATTERN.md`
- **Nouveau README:** Copier `/workspace/.devcontainer/images/.claude/docs/TEMPLATE-README.md`

Les templates définissent la structure obligatoire.

---

## Chemins de référence

| Élément | Chemin absolu |
|---------|---------------|
| Racine docs | `/workspace/.devcontainer/images/.claude/docs/` |
| Index principal | `/workspace/.devcontainer/images/.claude/docs/README.md` |
| Config agent | `/workspace/.devcontainer/images/.claude/docs/CLAUDE.md` |
| Template pattern | `/workspace/.devcontainer/images/.claude/docs/TEMPLATE-PATTERN.md` |
| Template README | `/workspace/.devcontainer/images/.claude/docs/TEMPLATE-README.md` |
| Catégories | `/workspace/.devcontainer/images/.claude/docs/{category}/` |
