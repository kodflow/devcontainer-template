---
name: plan
description: |
  Enter Claude Code planning mode for implementation strategy.
  Analyzes codebase, designs approach, creates step-by-step plan.
  Use when: starting a new feature, refactoring, or complex task.
allowed-tools:
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "Task(*)"
  - "WebFetch(*)"
  - "WebSearch(*)"
  - "mcp__github__*"
  - "mcp__playwright__*"
---

# Plan - Claude Code Planning Mode

$ARGUMENTS

---

## Description

Entre en **mode planning** pour concevoir une stratégie d'implémentation avant d'écrire du code.

**Principe** : Planifier → Valider → Implémenter (jamais l'inverse)

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<description>` | Planifie l'implémentation de la feature/fix |
| `--context` | Charge le .context.md généré par /search |
| `--help` | Affiche l'aide |

---

## --help

```
═══════════════════════════════════════════════
  /plan - Claude Code Planning Mode
═══════════════════════════════════════════════

Usage: /plan <description> [options]

Options:
  <description>     Ce qu'il faut implémenter
  --context         Utilise .context.md comme base
  --help            Affiche cette aide

Workflow:
  1. /search <topic>     Recherche documentation
  2. /plan <feature>     Planifie l'implémentation
  3. (user approves)     Validation du plan
  4. /apply              Exécute le plan

Exemples:
  /plan "Add user authentication with JWT"
  /plan "Refactor database layer" --context
  /plan "Fix memory leak in worker process"

═══════════════════════════════════════════════
```

---

## Workflow (5 phases)

### Phase 1 : Analyse du contexte

**Actions automatiques :**

1. Lire le `.context.md` si présent (généré par /search)
2. Analyser la structure du projet (Glob)
3. Identifier les fichiers pertinents (Grep)
4. Détecter le langage et les patterns existants

**Output Phase 1 :**
```
═══════════════════════════════════════════════
  /plan - Context Analysis
═══════════════════════════════════════════════

  Project     : <name>
  Language    : <detected>
  Framework   : <detected>

  Context loaded:
    ✓ .context.md (from /search)
    ✓ 15 relevant files identified
    ✓ Existing patterns analyzed

═══════════════════════════════════════════════
```

---

### Phase 2 : Exploration du codebase (RLM Pattern)

**Utiliser le Task agent Explore :**

```yaml
Task:
  subagent_type: Explore
  prompt: |
    Analyze codebase for: <description>
    Find:
    - Related files and functions
    - Existing patterns to follow
    - Potential conflicts
    - Test coverage
```

**Paralléliser si multi-domaine :**

- Agent 1: Frontend analysis
- Agent 2: Backend analysis
- Agent 3: Database/API analysis

---

### Phase 2.5 : Consultation Design Patterns (OBLIGATOIRE)

**Consulter la base de patterns `.claude/docs/` :**

```yaml
pattern_consultation:
  1_identify_category:
    - "Création d'objets?" → creational/README.md
    - "Performance/Cache?" → performance/README.md
    - "Concurrence?" → concurrency/README.md
    - "Architecture?" → architectural/*.md
    - "Intégration?" → messaging/README.md
    - "Sécurité?" → security/README.md
    - "Tests?" → testing/README.md

  2_read_patterns:
    action: "Read(.claude/docs/<category>/README.md)"
    output: "2-3 patterns applicables"

  3_integrate:
    action: "Ajouter au plan avec justification"
    format: |
      ## Patterns Utilisés
      | Pattern | Justification | Référence |
      |---------|---------------|-----------|
      | Builder | Création Order complexe | creational/README.md |
      | Repository | Accès données | ddd/README.md |
```

**Output Phase 2.5 :**
```
═══════════════════════════════════════════════
  Pattern Analysis
═══════════════════════════════════════════════

  Patterns identifiés:
    ✓ Object Pool (performance) - Pour connexions DB
    ✓ Repository (DDD) - Pour accès données
    ✓ Circuit Breaker (cloud) - Pour appels externes

  Références consultées:
    → .claude/docs/performance/README.md
    → .claude/docs/ddd/README.md
    → .claude/docs/cloud/circuit-breaker.md

═══════════════════════════════════════════════
```

---

### Phase 3 : Conception du plan

**Créer un plan structuré :**

```markdown
# Implementation Plan: <description>

## Overview
<2-3 phrases résumant l'approche>

## Design Patterns Applied
| Pattern | Category | Justification | Reference |
|---------|----------|---------------|-----------|
| <Pattern> | <Category> | <Why> | .claude/docs/<file> |

## Prerequisites
- [ ] <Dépendance ou setup requis>
- [ ] <Autre prérequis>

## Implementation Steps

### Step 1: <Titre>
**Files:** `src/file1.ts`, `src/file2.ts`
**Actions:**
1. <Action spécifique>
2. <Action spécifique>

**Code pattern:**
```<lang>
// Example of what will be implemented
```

### Step 2: <Titre>
...

## Testing Strategy
- [ ] Unit tests for <component>
- [ ] Integration test for <flow>

## Rollback Plan
<Comment annuler si problème>

## Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| <Risk> | <Solution> |
```

---

### Phase 4 : Écriture du plan

**Sauvegarder dans un fichier temporaire :**

```bash
# Emplacement du plan
/tmp/.claude-plan-<session>.md
```

**Ou utiliser EnterPlanMode :**

Le skill peut trigger `EnterPlanMode` pour utiliser le système natif de Claude Code.

---

### Phase 5 : Demande de validation

**OBLIGATOIRE : Attendre l'approbation utilisateur**

```
═══════════════════════════════════════════════
  Plan ready for review
═══════════════════════════════════════════════

  Summary:
    • 4 implementation steps
    • 6 files to modify
    • 2 new files to create
    • 8 tests to add

  Estimated complexity: MEDIUM

  Actions:
    → Review the plan above
    → Run /apply to execute
    → Or modify the plan manually

═══════════════════════════════════════════════
```

---

## Intégration avec autres commandes

| Avant /plan | Après /plan |
|-------------|-------------|
| `/search <topic>` | `/apply` |
| Génère .context.md | Exécute le plan |

**Workflow complet :**

```
/search "JWT authentication best practices"
    ↓
.context.md généré
    ↓
/plan "Add JWT auth to API" --context
    ↓
Plan créé et affiché
    ↓
User: "OK, go ahead"
    ↓
/apply
    ↓
Implémentation exécutée
```

---

## GARDE-FOUS (ABSOLUS)

| Action | Status |
|--------|--------|
| Implémenter sans plan approuvé | ❌ **INTERDIT** |
| Skip l'analyse du codebase | ❌ **INTERDIT** |
| Plan sans steps concrets | ❌ **INTERDIT** |
| Plan sans rollback strategy | ⚠ **WARNING** |

---

## Output Format

Le plan doit toujours inclure :

1. **Overview** - Résumé en 2-3 phrases
2. **Prerequisites** - Ce qui doit exister avant
3. **Steps** - Actions numérotées avec fichiers
4. **Testing** - Comment valider
5. **Risks** - Ce qui peut mal tourner

---

## Voir aussi

- `/search <query>` - Recherche documentation avant planning
- `/apply` - Exécute le plan validé
- `/review` - Review du code après implémentation
