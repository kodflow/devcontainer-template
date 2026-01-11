---
name: apply
description: |
  Execute a validated Claude Code plan.
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

# Apply - Execute Claude Code Plan

$ARGUMENTS

---

## Description

Exécute un plan validé par `/plan`. Implémente étape par étape avec suivi de progression.

**Principe** : Le plan a été validé → Exécuter fidèlement

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
═══════════════════════════════════════════════
  /apply - Execute Claude Code Plan
═══════════════════════════════════════════════

Usage: /apply [options]

Options:
  (none)            Exécute le plan complet
  --step <n>        Exécute l'étape N seulement
  --dry-run         Simule l'exécution
  --continue        Reprend après interruption
  --help            Affiche cette aide

Prérequis:
  - Plan créé via /plan
  - Plan approuvé par l'utilisateur

Workflow:
  /plan "feature" → (approve) → /apply

Exemples:
  /apply                    Exécuter tout le plan
  /apply --step 2           Étape 2 seulement
  /apply --dry-run          Voir ce qui serait fait
  /apply --continue         Reprendre après erreur

═══════════════════════════════════════════════
```

---

## Workflow (4 phases)

### Phase 1 : Vérification du plan

**Checks obligatoires :**

1. Plan existe (en mémoire ou fichier)
2. Plan a été validé par l'utilisateur
3. Pas de modifications conflictuelles depuis le plan

```
═══════════════════════════════════════════════
  /apply - Pre-flight Check
═══════════════════════════════════════════════

  Plan: "Add JWT authentication to API"
  Steps: 4
  Files: 6 to modify, 2 to create

  Checks:
    ✓ Plan loaded
    ✓ User approved
    ✓ No conflicts detected

  Ready to execute.

═══════════════════════════════════════════════
```

---

### Phase 2 : Initialisation TodoWrite

**Créer la todo list pour suivi :**

```yaml
TodoWrite:
  todos:
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
```

---

### Phase 3 : Exécution séquentielle

**Pour chaque étape du plan :**

1. **Marquer in_progress** dans TodoWrite
2. **Lire les fichiers** concernés
3. **Appliquer les modifications** (Write/Edit)
4. **Vérifier** la syntaxe (post-hooks)
5. **Marquer completed** dans TodoWrite

**Progress output :**

```
═══════════════════════════════════════════════
  Executing Step 1/4: Create auth middleware
═══════════════════════════════════════════════

  [■■■■□□□□□□] 40%

  Actions:
    ✓ Read src/middleware/index.ts
    ✓ Create src/middleware/auth.ts
    → Validate syntax...

═══════════════════════════════════════════════
```

---

### Phase 4 : Validation finale

**Après toutes les étapes :**

1. Vérifier que tous les fichiers sont valides
2. Exécuter les tests si définis dans le plan
3. Générer un résumé

```
═══════════════════════════════════════════════
  ✓ Plan executed successfully
═══════════════════════════════════════════════

  Summary:
    ✓ Step 1: Create auth middleware
    ✓ Step 2: Add JWT utilities
    ✓ Step 3: Update routes
    ✓ Step 4: Add tests

  Files modified: 6
  Files created: 2
  Tests added: 8

  Next steps:
    → Run tests: npm test
    → Review changes: /review
    → Commit: /git --commit

═══════════════════════════════════════════════
```

---

## --step N

Exécute uniquement l'étape N :

```
/apply --step 2

═══════════════════════════════════════════════
  Executing Step 2 only: Add JWT utilities
═══════════════════════════════════════════════

  ✓ Created src/utils/jwt.ts
  ✓ Created src/types/auth.ts
  ✓ Syntax validated

  Note: Other steps skipped. Run /apply to complete.

═══════════════════════════════════════════════
```

---

## --dry-run

Simule sans modifier :

```
/apply --dry-run

═══════════════════════════════════════════════
  /apply --dry-run (no changes)
═══════════════════════════════════════════════

  Would execute:

  Step 1: Create auth middleware
    CREATE src/middleware/auth.ts (45 lines)
    MODIFY src/middleware/index.ts (+2 lines)

  Step 2: Add JWT utilities
    CREATE src/utils/jwt.ts (120 lines)
    CREATE src/types/auth.ts (35 lines)

  Step 3: Update routes
    MODIFY src/routes/api.ts (+15 lines)
    MODIFY src/routes/index.ts (+3 lines)

  Step 4: Add tests
    CREATE tests/auth.test.ts (80 lines)
    CREATE tests/jwt.test.ts (60 lines)

  Total: 8 files, ~360 lines

  Run /apply to execute for real.

═══════════════════════════════════════════════
```

---

## --continue

Reprend après interruption ou erreur :

```
/apply --continue

═══════════════════════════════════════════════
  /apply --continue
═══════════════════════════════════════════════

  Previous state:
    ✓ Step 1: Complete
    ✓ Step 2: Complete
    ✗ Step 3: Failed (syntax error)
    ○ Step 4: Pending

  Resuming from Step 3...

═══════════════════════════════════════════════
```

---

## Gestion des erreurs

| Erreur | Action |
|--------|--------|
| Syntax error | Fix automatique via post-hooks, retry |
| File conflict | Afficher diff, demander confirmation |
| Test failure | Proposer fix ou rollback |
| Unexpected | Pause, afficher état, attendre instruction |

**En cas d'échec :**

```
═══════════════════════════════════════════════
  ✗ Step 3 failed
═══════════════════════════════════════════════

  Error: TypeScript compilation error
  File: src/routes/api.ts:45

  Property 'userId' does not exist on type 'Request'

  Options:
    1. /apply --continue  (after manual fix)
    2. Let me fix it automatically
    3. /plan --revise (update the plan)

═══════════════════════════════════════════════
```

---

## GARDE-FOUS (ABSOLUS)

| Action | Status |
|--------|--------|
| Exécuter sans plan validé | ❌ **INTERDIT** |
| Skip une étape silencieusement | ❌ **INTERDIT** |
| Modifier des fichiers hors plan | ❌ **INTERDIT** |
| Continuer après erreur critique | ❌ **INTERDIT** |
| Force apply sur main/master | ⚠ **WARNING** |

---

## Intégration post-apply

| Action suivante | Commande |
|-----------------|----------|
| Vérifier les changements | `/review` |
| Exécuter les tests | `npm test` / `go test` |
| Commiter | `/git --commit` |
| Créer PR | `/git --commit` (auto PR) |

---

## Voir aussi

- `/plan <description>` - Crée le plan à exécuter
- `/review` - Review après implémentation
- `/git --commit` - Commit les changements
