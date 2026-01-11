---
name: apply
description: |
  Execute a validated Claude Code plan with RLM decomposition.
  Implements the steps defined by /plan with progress tracking.
  Use when: plan is approved and ready for implementation.
allowed-tools:
  - "Read(**/*)"
  - "Write(**/*)"
  - "Edit(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "Bash(*)"
  - "Task(*)"
  - "TodoWrite(*)"
  - "mcp__playwright__*"
---

# /apply - Execute Claude Code Plan (RLM Architecture)

$ARGUMENTS

---

## Overview

Exécute un plan validé par `/plan` avec patterns **RLM** :

- **Peek** - Vérifier plan et état du code avant exécution
- **Decompose** - Étapes déjà définies par /plan
- **Parallelize** - Validations simultanées post-step
- **Synthesize** - Rapport consolidé

**Principe** : Le plan a été validé → Exécuter fidèlement avec validation continue.

---

## Arguments

| Pattern | Action |
|---------|--------|
| (none) | Exécute le plan en cours |
| `--step <n>` | Exécute uniquement l'étape N |
| `--dry-run` | Simule sans modifier de fichiers |
| `--continue` | Reprend après interruption |
| `--help` | Affiche l'aide |

---

## --help

```
═══════════════════════════════════════════════════════════════
  /apply - Execute Claude Code Plan (RLM)
═══════════════════════════════════════════════════════════════

Usage: /apply [options]

Options:
  (none)            Exécute le plan complet
  --step <n>        Exécute l'étape N seulement
  --dry-run         Simule l'exécution
  --continue        Reprend après interruption
  --help            Affiche cette aide

RLM Patterns:
  1. Peek     - Vérifier plan + état code
  2. Parallelize - Validations simultanées
  3. Synthesize - Rapport consolidé

Prérequis:
  - Plan créé via /plan
  - Plan approuvé par l'utilisateur

Exemples:
  /apply                    Exécuter tout le plan
  /apply --step 2           Étape 2 seulement
  /apply --dry-run          Voir ce qui serait fait
  /apply --continue         Reprendre après erreur

═══════════════════════════════════════════════════════════════
```

---

## Phase 1 : Peek (RLM Pattern)

**Vérifications AVANT toute exécution :**

```yaml
peek_workflow:
  1_plan_check:
    action: "Vérifier que le plan existe et est validé"
    tools: [Read]
    checks:
      - "Plan en mémoire ou fichier /tmp/.claude-plan-*.md"
      - "Plan marqué comme approuvé"
      - "Étapes clairement définies"

  2_codebase_scan:
    action: "Scanner l'état actuel du codebase"
    tools: [Glob, Grep]
    checks:
      - "Fichiers cibles existent"
      - "Pas de modifications conflictuelles depuis le plan"
      - "Dépendances requises présentes"

  3_conflict_detect:
    action: "Détecter les conflits potentiels"
    tools: [Bash(git status)]
    checks:
      - "Pas de changements non commités sur les fichiers cibles"
      - "Pas de merge en cours"
```

**Output Phase 1 :**

```
═══════════════════════════════════════════════════════════════
  /apply - Peek Analysis
═══════════════════════════════════════════════════════════════

  Plan   : "Add JWT authentication to API"
  Steps  : 4
  Files  : 6 to modify, 2 to create

  Peek Results:
    ✓ Plan loaded and approved
    ✓ Target files accessible
    ✓ No conflicting changes
    ✓ Dependencies available

  Ready to execute.

═══════════════════════════════════════════════════════════════
```

---

## Phase 2 : Initialisation TodoWrite

**Créer la todo list basée sur les étapes du plan :**

```yaml
TodoWrite:
  todos:
    - content: "Peek: Vérification pré-exécution"
      status: "completed"
      activeForm: "Vérifiant pré-requis"
    - content: "Step 1: Create auth middleware"
      status: "pending"
      activeForm: "Creating auth middleware"
    - content: "Step 2: Add JWT utilities"
      status: "pending"
      activeForm: "Adding JWT utilities"
    - content: "Step 3: Update routes"
      status: "pending"
      activeForm: "Updating routes"
    - content: "Step 4: Add tests"
      status: "pending"
      activeForm: "Adding tests"
    - content: "Synthesize: Validation finale"
      status: "pending"
      activeForm: "Validant le résultat"
```

---

## Phase 3 : Exécution avec Parallelize

**Pour chaque étape du plan :**

### Step 3.1 : Marquer et lire

```yaml
step_start:
  1_mark: "Marquer étape in_progress dans TodoWrite"
  2_peek: "Lire les fichiers concernés avant modification"
```

### Step 3.2 : Appliquer les modifications

```yaml
step_apply:
  actions:
    - "Write/Edit selon le plan"
    - "Suivre les instructions exactes du plan"
    - "Ne pas dévier du plan approuvé"
```

### Step 3.3 : Parallelize (validation post-step)

**Lancer les validations en PARALLÈLE après chaque étape :**

```yaml
parallel_validation:
  agents:
    - task: "Syntax check"
      action: "Vérifier syntaxe des fichiers modifiés"
      tools: [post-hooks]

    - task: "Import check"
      action: "Vérifier imports valides"
      tools: [Bash(linter)]

    - task: "Test related"
      action: "Exécuter tests liés aux fichiers modifiés"
      tools: [Bash(test)]

  mode: "PARALLEL (single message, multiple calls)"
```

**IMPORTANT** : Lancer TOUTES les validations dans UN SEUL message.

### Step 3.4 : Décision

```yaml
step_decision:
  on_success:
    - "Marquer étape completed"
    - "Passer à l'étape suivante"

  on_failure:
    - "Analyser l'erreur"
    - "Proposer fix ou rollback"
    - "Attendre instruction utilisateur"
```

**Output par étape :**

```
═══════════════════════════════════════════════════════════════
  Executing Step 2/4: Add JWT utilities
═══════════════════════════════════════════════════════════════

  Actions:
    ✓ Create src/utils/jwt.ts
    ✓ Create src/types/auth.ts

  Validation (parallel):
    ├─ Syntax : ✓ Valid
    ├─ Imports: ✓ Resolved
    └─ Tests  : ✓ 3 new tests pass

  Status: COMPLETE → Next step

═══════════════════════════════════════════════════════════════
```

---

## Phase 4 : Synthesize (RLM Pattern)

**Après toutes les étapes, synthèse finale :**

```yaml
synthesize_workflow:
  1_collect_results:
    action: "Rassembler tous les résultats d'étapes"
    data:
      - "Fichiers créés/modifiés"
      - "Tests ajoutés/passés"
      - "Erreurs rencontrées/corrigées"

  2_final_validation:
    action: "Validation complète du projet"
    parallel:
      - "npm test" # Full test suite
      - "npm run lint" # Full lint
      - "npm run build" # Full build

  3_generate_report:
    action: "Générer rapport consolidé"
    format: "Structured markdown"
```

**Output Final :**

```
═══════════════════════════════════════════════════════════════
  /apply - Plan Executed Successfully
═══════════════════════════════════════════════════════════════

  Plan: "Add JWT authentication to API"

  Steps Completed:
    ✓ Step 1: Create auth middleware
    ✓ Step 2: Add JWT utilities
    ✓ Step 3: Update routes
    ✓ Step 4: Add tests

  Summary:
    Files modified : 6
    Files created  : 2
    Tests added    : 8
    Tests passing  : 8/8
    Lint errors    : 0
    Build          : SUCCESS

  Next steps:
    → Review changes: git diff
    → Commit: /git --commit
    → Or rollback: git checkout .

═══════════════════════════════════════════════════════════════
```

---

## --step N

Exécute uniquement l'étape N avec validation :

```yaml
step_only:
  1_peek: "Vérifier pré-requis pour cette étape"
  2_execute: "Exécuter l'étape N"
  3_validate: "Validation parallèle post-étape"
  4_report: "Rapport partiel"
```

---

## --dry-run

Simule sans modifier avec peek complet :

```yaml
dry_run:
  1_peek: "Analyse complète du plan"
  2_simulate: "Afficher ce qui serait fait"
  3_no_write: "Aucune modification"
```

**Output :**

```
═══════════════════════════════════════════════════════════════
  /apply --dry-run (no changes)
═══════════════════════════════════════════════════════════════

  Would execute:

  Step 1: Create auth middleware
    CREATE src/middleware/auth.ts (45 lines)
    MODIFY src/middleware/index.ts (+2 lines)

  Step 2: Add JWT utilities
    CREATE src/utils/jwt.ts (120 lines)
    CREATE src/types/auth.ts (35 lines)

  ...

  Total: 8 files, ~360 lines

  Run /apply to execute for real.

═══════════════════════════════════════════════════════════════
```

---

## --continue

Reprend après interruption avec peek de l'état :

```yaml
continue_workflow:
  1_peek: "Analyser l'état actuel vs plan"
  2_detect: "Identifier étapes complétées"
  3_resume: "Reprendre à la prochaine étape"
```

---

## Gestion des erreurs

| Erreur | Action |
|--------|--------|
| Syntax error | Fix automatique via post-hooks, retry |
| File conflict | Afficher diff, demander confirmation |
| Test failure | Proposer fix ou rollback |
| Unexpected | Pause, afficher état, attendre instruction |

---

## GARDE-FOUS (ABSOLUS)

| Action | Status | Raison |
|--------|--------|--------|
| Exécuter sans plan validé | ❌ **INTERDIT** | Approbation requise |
| Skip Phase 1 (Peek) | ❌ **INTERDIT** | Vérifier état avant exécution |
| Skip une étape silencieusement | ❌ **INTERDIT** | Traçabilité |
| Modifier des fichiers hors plan | ❌ **INTERDIT** | Scope défini |
| Continuer après erreur critique | ❌ **INTERDIT** | Intégrité |

### Parallélisation légitime

| Élément | Parallèle? | Raison |
|---------|------------|--------|
| Étapes du plan (step 1 → 2 → 3) | ❌ Séquentiel | Dépendances entre étapes |
| Validations post-étape (lint+test+build) | ✅ Parallèle | Indépendantes |
| Validation finale | ✅ Parallèle | Checks indépendants |

---

## Intégration

| Avant /apply | Après /apply |
|--------------|--------------|
| `/plan <description>` | `/review` |
| User approval | `/git --commit` |

**Workflow :**

```
/plan "Add feature"  →  (approve)  →  /apply  →  /git --commit
```
