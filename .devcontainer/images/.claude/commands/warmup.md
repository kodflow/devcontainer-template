---
name: warmup
description: |
  Project context pre-loading with RLM decomposition.
  Reads CLAUDE.md hierarchy using funnel strategy (root → leaves).
  Use when: starting a session, preparing for complex tasks, or updating documentation.
allowed-tools:
  - "Read(**/*)"
  - "Glob(**/*)"
  - "mcp__grepai__*"
  - "Grep(**/*)"
  - "Write(**/*)"
  - "Edit(**/*)"
  - "Task(*)"
  - "TodoWrite(*)"
  - "Bash(git:*)"
---

# /warmup - Project Context Pre-loading (RLM Architecture)

$ARGUMENTS

---

## Overview

Préchargement du contexte projet avec patterns **RLM** :

- **Peek** - Découvrir la hiérarchie CLAUDE.md
- **Funnel** - Lecture en entonnoir (racine → feuilles)
- **Parallelize** - Analyse parallèle par domaine
- **Synthesize** - Contexte consolidé prêt à l'emploi

**Principe** : Charger le contexte → Être plus efficace sur les tâches

---

## Arguments

| Pattern | Action |
|---------|--------|
| (none) | Précharge tout le contexte projet |
| `--update` | Met à jour tous les CLAUDE.md (analyse code) |
| `--dry-run` | Affiche ce qui serait mis à jour (avec --update) |
| `--help` | Affiche l'aide |

---

## --help

```
═══════════════════════════════════════════════════════════════
  /warmup - Project Context Pre-loading (RLM)
═══════════════════════════════════════════════════════════════

Usage: /warmup [options]

Options:
  (none)            Précharge le contexte complet
  --update          Met à jour tous les CLAUDE.md
  --dry-run         Affiche les changements (avec --update)
  --help            Affiche cette aide

RLM Patterns:
  1. Peek       - Découvrir la hiérarchie CLAUDE.md
  2. Funnel     - Lecture entonnoir (root → leaves)
  3. Parallelize - Analyse par domaine
  4. Synthesize - Contexte consolidé

Exemples:
  /warmup                       Précharge le contexte
  /warmup --update              Met à jour la documentation
  /warmup --update --dry-run    Preview des changements

Workflow:
  /warmup → /plan → /do → /git

═══════════════════════════════════════════════════════════════
```

**SI `$ARGUMENTS` contient `--help`** : Afficher l'aide ci-dessus et STOP.

---

## Mode Normal (Préchargement)

### Phase 1 : Peek (Découverte hiérarchie)

```yaml
peek_workflow:
  1_discover:
    action: "Découvrir tous les CLAUDE.md du projet"
    tool: Glob
    pattern: "**/CLAUDE.md"
    output: [claude_files]

  2_build_tree:
    action: "Construire l'arbre de contexte par profondeur"
    algorithm: |
      POUR chaque fichier:
        depth = path.count('/') - base.count('/')
      Trier par profondeur croissante
      depth 0: /CLAUDE.md (racine)
      depth 1: /src/CLAUDE.md, /.devcontainer/CLAUDE.md
      depth 2+: sous-dossiers

  3_detect_project:
    action: "Identifier le type de projet"
    tools: [Glob]
    patterns:
      - "go.mod" → Go
      - "package.json" → Node.js
      - "Cargo.toml" → Rust
      - "pyproject.toml" → Python
      - "*.tf" → Terraform
```

**Output Phase 1 :**

```
═══════════════════════════════════════════════════════════════
  /warmup - Peek Analysis
═══════════════════════════════════════════════════════════════

  Project: /workspace
  Type   : <detected_type>

  CLAUDE.md Hierarchy (<n> files):
    depth 0 : /CLAUDE.md (project root)
    depth 1 : /.devcontainer/CLAUDE.md, /src/CLAUDE.md
    depth 2 : /.devcontainer/features/CLAUDE.md
    ...

  Strategy: Funnel (root → leaves, decreasing detail)

═══════════════════════════════════════════════════════════════
```

---

### Phase 2 : Funnel (Lecture en entonnoir)

```yaml
funnel_strategy:
  principle: "Lire du plus général au plus spécifique"

  levels:
    depth_0:
      files: ["/CLAUDE.md"]
      extract: ["project_rules", "structure", "workflow", "safeguards"]
      detail_level: "HIGH"

    depth_1:
      files: ["src/CLAUDE.md", ".devcontainer/CLAUDE.md"]
      extract: ["conventions", "key_files", "domain_rules"]
      detail_level: "MEDIUM"

    depth_2_plus:
      files: ["**/CLAUDE.md"]
      extract: ["specific_rules", "attention_points"]
      detail_level: "LOW"

  extraction_rules:
    include:
      - "Règles MANDATORY/ABSOLUES"
      - "Structure du dossier"
      - "Conventions spécifiques"
      - "GARDE-FOUS"
    exclude:
      - "Exemples de code complets"
      - "Détails d'implémentation"
      - "Longs blocs de code"
```

**Algorithme de lecture :**

```
POUR profondeur DE 0 À max_profondeur:
    fichiers = filtrer(claude_files, profondeur)

    PARALLÈLE POUR chaque fichier DANS fichiers:
        contenu = Read(fichier)
        contexte[fichier] = extraire_essentiel(contenu, niveau_détail)

    consolider(contexte, profondeur)
```

---

### Phase 3 : Parallelize (Analyse par domaine)

```yaml
parallel_analysis:
  mode: "PARALLEL (single message, 4 Task calls)"

  agents:
    - task: "source-analyzer"
      type: "Explore"
      scope: "src/"
      prompt: |
        Analyser la structure du code source:
        - Packages/modules principaux
        - Patterns architecturaux détectés
        - Points d'attention (TODO, FIXME, HACK)
        Return: {packages[], patterns[], attention_points[]}

    - task: "config-analyzer"
      type: "Explore"
      scope: ".devcontainer/"
      prompt: |
        Analyser la configuration DevContainer:
        - Features installées
        - Services configurés
        - MCP servers disponibles
        Return: {features[], services[], mcp_servers[]}

    - task: "test-analyzer"
      type: "Explore"
      scope: "tests/ OR **/*_test.go OR **/*.test.ts"
      prompt: |
        Analyser la couverture de tests:
        - Fichiers de test trouvés
        - Patterns de test utilisés
        Return: {test_files[], patterns[], coverage_estimate}

    - task: "docs-analyzer"
      type: "Explore"
      scope: ".claude/docs/"
      prompt: |
        Analyser la base de connaissances:
        - Catégories de patterns disponibles
        - Nombre de patterns par catégorie
        Return: {categories[], pattern_count}
```

**IMPORTANT** : Lancer les 4 agents dans UN SEUL message.

---

### Phase 4 : Synthesize (Contexte consolidé)

```yaml
synthesize_workflow:
  1_merge:
    action: "Fusionner les résultats des agents"
    inputs:
      - "context_tree (Phase 2)"
      - "source_analysis (Phase 3)"
      - "config_analysis (Phase 3)"
      - "test_analysis (Phase 3)"
      - "docs_analysis (Phase 3)"

  2_prioritize:
    action: "Prioriser les informations"
    levels:
      - CRITICAL: "Règles absolues, garde-fous, conventions obligatoires"
      - HIGH: "Structure projet, patterns utilisés, MCP disponibles"
      - MEDIUM: "Features, services, couverture tests"
      - LOW: "Détails spécifiques, points d'attention mineurs"

  3_format:
    action: "Formater le contexte pour session"
    output: "Session context ready"
```

**Output Final (Mode Normal) :**

```
═══════════════════════════════════════════════════════════════
  /warmup - Context Loaded Successfully
═══════════════════════════════════════════════════════════════

  Project: <project_name>
  Type   : <detected_type>

  Context Summary:
    ├─ CLAUDE.md files read: <n>
    ├─ Source packages: <n>
    ├─ Test files: <n>
    ├─ Design patterns: <n>
    └─ MCP servers: <n>

  Key Rules Loaded:
    ✓ MCP-FIRST: Always use MCP before CLI
    ✓ GREPAI-FIRST: Semantic search before Grep
    ✓ Code in /src: All code MUST be in /src
    ✓ SAFEGUARDS: Never delete .claude/ or .devcontainer/

  Attention Points Detected:
    ├─ <n> TODO items in src/
    ├─ <n> FIXME in config
    └─ <n> deprecated APIs flagged

  Ready for:
    → /plan <feature>
    → /review
    → /do <task>

═══════════════════════════════════════════════════════════════
```

---

## Mode --update (Mise à jour documentation)

### Phase 1 : Scan complet du code

```yaml
scan_workflow:
  1_discover_code:
    action: "Scanner tous les fichiers de code"
    tools: [Glob]
    patterns:
      - "src/**/*.go"
      - "src/**/*.ts"
      - "src/**/*.py"
      - "**/*.sh"
    exclude:
      - "vendor/"
      - "node_modules/"
      - ".git/"

  2_extract_metadata:
    action: "Extraire les métadonnées par dossier"
    parallel_per_directory:
      - "Fonctions/types publics"
      - "Patterns utilisés"
      - "TODO/FIXME/HACK"
      - "Imports critiques"
      - "Éléments obsolètes"

  3_check_claude_files:
    action: "Vérifier cohérence avec CLAUDE.md existants"
    for_each: claude_files
    checks:
      - "Structure documentée vs structure réelle"
      - "Fichiers mentionnés existent encore"
      - "Conventions documentées respectées"
      - "Informations obsolètes à supprimer"
```

---

### Phase 2 : Détection des obsolescences

```yaml
obsolete_detection:
  file_references:
    description: "Fichiers mentionnés dans CLAUDE.md mais supprimés"
    action: |
      POUR chaque CLAUDE.md:
        extraire les chemins de fichiers mentionnés
        vérifier que chaque fichier existe
        marquer comme obsolète si non trouvé

  structure_changes:
    description: "Structure de dossier changée"
    action: |
      POUR chaque CLAUDE.md avec section 'Structure':
        comparer la structure documentée vs réelle
        identifier les différences

  api_changes:
    description: "APIs/fonctions renommées ou supprimées"
    action: |
      utiliser grepai pour chercher les références
      si 0 résultat → possiblement obsolète

  deprecated_patterns:
    description: "Patterns dépréciés encore documentés"
    action: |
      vérifier les imports/usages dans le code
      comparer avec ce qui est documenté
```

---

### Phase 3 : Génération des mises à jour

```yaml
update_generation:
  for_each: directory_with_claude_md

  format: |
    # <Directory Name>

    ## Purpose
    <Description courte du rôle du dossier>

    ## Structure
    ```text
    <arborescence actuelle>
    ```

    ## Key Files
    | File | Description |
    |------|-------------|
    | <file> | <description> |

    ## Conventions
    - <convention 1>
    - <convention 2>

    ## Attention Points
    - <point d'attention détecté dans le code>

  constraints:
    max_lines: 60
    no_implementation_details: true
    no_obsolete_info: true
    maintain_existing_structure: true
```

---

### Phase 4 : Application des changements

```yaml
apply_workflow:
  dry_run:
    condition: "--dry-run flag present"
    action: "Afficher les différences sans modifier"
    output: |
      ═══════════════════════════════════════════════════════════
        /warmup --update --dry-run
      ═══════════════════════════════════════════════════════════

      Files to update:
        ├─ /src/CLAUDE.md
        │   - Remove: "<file>" (deleted)
        │   + Add: "<file>" (new)
        │
        └─ /.devcontainer/features/CLAUDE.md
            + Add: New feature detected

      Total: <n> files, <n> changes
      Run without --dry-run to apply.
      ═══════════════════════════════════════════════════════════

  interactive:
    condition: "No --dry-run flag"
    for_each_file:
      action: "Afficher diff et demander confirmation"
      tool: AskUserQuestion
      options:
        - "Apply this change"
        - "Skip this file"
        - "Edit manually"
        - "Apply all remaining"

    on_apply:
      action: "Écrire le fichier mis à jour"
      tool: Edit or Write
      backup: true

  validation:
    post_apply:
      - "Verify file < 60 lines"
      - "Verify no obsolete references"
      - "Verify structure section matches reality"
```

**Output Final (Mode --update) :**

```
═══════════════════════════════════════════════════════════════
  /warmup --update - Documentation Updated
═══════════════════════════════════════════════════════════════

  Files analyzed: <n> source files, <n> CLAUDE.md

  Changes applied:
    ✓ /src/CLAUDE.md - Updated structure
    ✓ /src/handlers/CLAUDE.md - Removed obsolete refs
    ○ /tests/CLAUDE.md - Skipped (user choice)

  Obsolete items removed:
    - <obsolete_file> reference
    - <old_function> signature

  New attention points added:
    + <n> TODO items documented
    + <n> FIXME flagged

  Validation:
    ✓ All CLAUDE.md < 60 lines
    ✓ Structure sections match reality
    ✓ No broken file references

═══════════════════════════════════════════════════════════════
```

---

## GARDE-FOUS (ABSOLUS)

| Action | Status | Raison |
|--------|--------|--------|
| Skip Phase 1 (Peek) | ❌ **INTERDIT** | Découverte hiérarchie obligatoire |
| Modifier .claude/commands/ | ❌ **INTERDIT** | Fichiers protégés |
| Supprimer CLAUDE.md | ❌ **INTERDIT** | Seule mise à jour autorisée |
| CLAUDE.md > 60 lignes | ❌ **INTERDIT** | Convention projet |
| Lecture aléatoire | ❌ **INTERDIT** | Funnel (root→leaves) obligatoire |
| Détails d'implémentation | ❌ **INTERDIT** | Contexte, pas code |
| --update sans backup | ⚠ **WARNING** | Risque de perte |

---

## Intégration Workflow

```
/warmup                     # Précharger contexte
    ↓
/plan "feature X"           # Planifier avec contexte
    ↓
/do                         # Exécuter le plan
    ↓
/warmup --update            # Mettre à jour doc
    ↓
/git --commit               # Commiter les changements
```

**Intégration avec autres skills :**

| Avant /warmup | Après /warmup |
|---------------|---------------|
| Container start | /plan, /review, /do |
| /init | Toute tâche complexe |

---

## Design Patterns Applied

| Pattern | Category | Usage |
|---------|----------|-------|
| Cache-Aside | Cloud | Vérifier cache avant chargement |
| Lazy Loading | Performance | Charger par phases (funnel) |
| Progressive Disclosure | DevOps | Détail croissant par profondeur |

**Références :**
- `.claude/docs/cloud/cache-aside.md`
- `.claude/docs/performance/lazy-load.md`
- `.claude/docs/devops/feature-toggles.md`
