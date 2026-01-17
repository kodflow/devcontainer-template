---
name: update
description: |
  DevContainer Environment Update from official template.
  Updates features, hooks, commands, and settings from kodflow/devcontainer-template.
  Use when: syncing local devcontainer with latest template improvements.
allowed-tools:
  - "Bash(curl:*)"
  - "Bash(git:*)"
  - "Read(**/*)"
  - "Write(.devcontainer/**/*)"
  - "WebFetch(*)"
  - "Task(*)"
---

# Update - DevContainer Environment Update

$ARGUMENTS

---

## Description

Met à jour l'environnement DevContainer depuis le template officiel.

**Bootstrap Pattern** : Ce fichier est la **source de vérité**. La commande
récupère d'abord la dernière version de ce fichier depuis le template,
puis exécute les mécaniques définies dans cette version fraîche.

**Composants mis à jour (depuis MANIFEST) :**

- **Features** - Language features et leurs RULES.md
- **Hooks** - Scripts Claude (format, lint, security, etc.)
- **Commands** - Commandes slash (/git, /search)
- **Agents** - Définitions d'agents (specialists, executors)
- **p10k** - Configuration Powerlevel10k
- **Settings** - Configuration Claude

**Source** : `github.com/kodflow/devcontainer-template` (MANIFEST section)

---

## Arguments

| Pattern | Action |
|---------|--------|
| (none) | Mise à jour complète |
| `--check` | Vérifie les mises à jour disponibles |
| `--component <name>` | Met à jour un composant spécifique |
| `--help` | Affiche l'aide |

### Composants disponibles

| Composant | Chemin | Source |
|-----------|--------|--------|
| `features` | `.devcontainer/features/languages/` | manifest.languages |
| `hooks` | `.devcontainer/images/.claude/scripts/` | manifest.scripts |
| `commands` | `.devcontainer/images/.claude/commands/` | manifest.commands |
| `agents` | `.devcontainer/images/.claude/agents/` | manifest.agents |
| `p10k` | `.devcontainer/images/.p10k.zsh` | manifest.config_files |
| `settings` | `.devcontainer/images/.claude/settings.json` | manifest.config_files |

---

## --help

```
═══════════════════════════════════════════════
  /update - DevContainer Environment Update
═══════════════════════════════════════════════

Usage: /update [options]

Options:
  (none)              Mise à jour complète
  --check             Vérifie les mises à jour
  --component <name>  Met à jour un composant
  --help              Affiche cette aide

Composants (from MANIFEST):
  features    Language features (RULES.md)
  hooks       Scripts Claude (format, lint...)
  commands    Commandes slash (/git, /search)
  agents      Agent definitions (specialists)
  p10k        Powerlevel10k config
  settings    Claude settings.json

Exemples:
  /update                       Tout mettre à jour
  /update --check               Voir les mises à jour
  /update --component hooks     Hooks seulement

Source: kodflow/devcontainer-template (main)
═══════════════════════════════════════════════
```

---

## Overview

Mise à jour de l'environnement DevContainer avec patterns **RLM** :

- **Bootstrap** - Récupérer la dernière version de ce fichier (source of truth)
- **Peek** - Vérifier connectivité et versions
- **Decompose** - Identifier les composants à mettre à jour
- **Parallelize** - Analyser les composants simultanément
- **Synthesize** - Appliquer les mises à jour et rapport consolidé

---

## Configuration

```yaml
REPO: "kodflow/devcontainer-template"
BRANCH: "main"
BASE_URL: "https://raw.githubusercontent.com/${REPO}/${BRANCH}"
UPDATE_MANIFEST: "${BASE_URL}/.devcontainer/images/.claude/commands/update.md"
```

---

## Phase 0 : Bootstrap (MANDATORY - Source of Truth)

**CRITIQUE : Cette phase doit TOUJOURS s'exécuter en premier.**

Le fichier `update.md` du repository template est la **source de vérité**.
Toute mise à jour doit d'abord récupérer la dernière version de ce fichier
pour garantir que les mécaniques appliquées sont à jour.

```yaml
bootstrap_workflow:
  description: |
    Récupérer la dernière version de update.md depuis le repository source.
    Ce fichier contient les listes de fichiers, les composants à mettre à jour,
    et les fichiers deprecated à supprimer.

  1_fetch_manifest:
    action: "Télécharger update.md depuis le template"
    tool: WebFetch
    url: "https://raw.githubusercontent.com/kodflow/devcontainer-template/main/.devcontainer/images/.claude/commands/update.md"
    output: "remote_update_content"

  2_extract_manifest:
    action: "Extraire les listes de composants depuis le fichier distant"
    parse:
      - languages: "Liste des langages supportés"
      - scripts: "Liste des scripts hooks"
      - commands: "Liste des commandes slash"
      - deprecated: "Fichiers à supprimer"

  3_apply_mechanics:
    action: "Utiliser les listes extraites pour les phases suivantes"
    rule: "Les phases 1-4 utilisent les données du manifest distant"
```

**Pourquoi ce pattern :**

| Problème sans Bootstrap | Solution avec Bootstrap |
|------------------------|------------------------|
| Listes hardcodées dans le fichier local | Listes dynamiques depuis le template |
| Nouveau langage non détecté | Langages mis à jour automatiquement |
| Nouveaux scripts ignorés | Scripts découverts via manifest |
| Fichiers deprecated oubliés | Liste deprecated à jour |

**Implémentation Bootstrap :**

```bash
# Récupérer le manifest distant (update.md = source of truth)
REMOTE_MANIFEST=$(curl -sL \
  "https://raw.githubusercontent.com/kodflow/devcontainer-template/main/.devcontainer/images/.claude/commands/update.md")

# Extraire la liste des langages (depuis la section Features du manifest)
LANGUAGES=$(echo "$REMOTE_MANIFEST" | \
  grep -oP 'for lang in \K[^;]+' | head -1)

# Extraire la liste des scripts (depuis la section Hooks du manifest)
SCRIPTS=$(echo "$REMOTE_MANIFEST" | \
  grep -oP 'for script in \K[^;]+' | head -1)

# Extraire la liste des commandes (depuis la section Commands du manifest)
COMMANDS=$(echo "$REMOTE_MANIFEST" | \
  grep -oP 'for cmd in \K[^;]+' | head -1)

# Extraire les fichiers deprecated (depuis la section Cleanup du manifest)
DEPRECATED=$(echo "$REMOTE_MANIFEST" | \
  grep -oP 'deprecated_files:.*?- "\K[^"]+' | tr '\n' ' ')
```

**Output Phase 0 :**

```
═══════════════════════════════════════════════════════════════
  /update - Bootstrap (Source of Truth)
═══════════════════════════════════════════════════════════════

  Fetching manifest from: kodflow/devcontainer-template (main)

  Manifest version: def5678 (2024-01-20)

  Discovered components:
    Languages : go nodejs python rust java ruby php elixir dart scala carbon cpp
    Scripts   : format imports lint security test commit-validate pre-validate
    Commands  : git search update plan review do test init improve
    Deprecated: .coderabbit.yaml

  Bootstrap: ✓ Ready to proceed

═══════════════════════════════════════════════════════════════
```

---

## Phase 1 : Peek (RLM Pattern)

**Vérifications AVANT toute mise à jour :**

```yaml
peek_workflow:
  1_connectivity:
    action: "Vérifier la connectivité GitHub"
    tools: [WebFetch, Bash(curl)]
    check: "API GitHub accessible"

  2_version_check:
    action: "Récupérer le dernier commit du template"
    tools: [WebFetch]
    url: "https://api.github.com/repos/kodflow/devcontainer-template/commits/main"

  3_local_version:
    action: "Lire la version locale"
    tools: [Read]
    file: ".devcontainer/.template-version"
```

**Output Phase 1 :**

```
═══════════════════════════════════════════════
  /update - Peek Analysis
═══════════════════════════════════════════════

  Connectivity: ✓ GitHub API accessible
  Local version  : abc1234 (2024-01-15)
  Remote version : def5678 (2024-01-20)

  Status: UPDATE AVAILABLE

═══════════════════════════════════════════════
```

---

## Phase 2 : Decompose (RLM Pattern)

**Identifier les composants à analyser :**

```yaml
decompose_workflow:
  components:
    features:
      path: ".devcontainer/features/languages/"
      files: ["*/RULES.md"]
      description: "Language features et conventions"
      source: "manifest.components.languages"

    hooks:
      path: ".devcontainer/images/.claude/scripts/"
      files: ["*.sh"]
      description: "Scripts Claude (format, lint, security)"
      source: "manifest.components.scripts"

    commands:
      path: ".devcontainer/images/.claude/commands/"
      files: ["*.md"]
      description: "Commandes slash (/git, /search)"
      source: "manifest.components.commands"

    agents:
      path: ".devcontainer/images/.claude/agents/"
      files: ["*.md"]
      description: "Agent definitions (specialists, executors)"
      source: "manifest.components.agents"

    p10k:
      path: ".devcontainer/images/.p10k.zsh"
      files: [".p10k.zsh"]
      description: "Configuration Powerlevel10k"
      source: "manifest.config_files[0]"

    settings:
      path: ".devcontainer/images/.claude/settings.json"
      files: ["settings.json"]
      description: "Configuration Claude"
      source: "manifest.config_files[1]"

  output: "6 composants à analyser (liste dynamique depuis manifest)"
```

---

## Phase 3 : Parallelize (RLM Pattern)

**Lancer 6 Task agents en PARALLÈLE pour analyser chaque composant :**

```yaml
parallel_analysis:
  mode: "PARALLEL (single message, 6 Task calls)"
  source: "Composants listés dans le MANIFEST distant"

  agents:
    - task: "features-analyzer"
      type: "Explore"
      model: "haiku"
      prompt: |
        Compare features/languages/ local vs remote
        Languages from MANIFEST: ${manifest.components.languages}
        For each language: check RULES.md differences
        Return: {language, status, changes[]}

    - task: "hooks-analyzer"
      type: "Explore"
      model: "haiku"
      prompt: |
        Compare .claude/scripts/ local vs remote
        Scripts from MANIFEST: ${manifest.components.scripts}
        For each script: check content differences
        Return: {script, status, changes[]}

    - task: "commands-analyzer"
      type: "Explore"
      model: "haiku"
      prompt: |
        Compare .claude/commands/ local vs remote
        Commands from MANIFEST: ${manifest.components.commands}
        For each command: check content differences
        Return: {command, status, changes[]}

    - task: "agents-analyzer"
      type: "Explore"
      model: "haiku"
      prompt: |
        Compare .claude/agents/ local vs remote
        Agents from MANIFEST: ${manifest.components.agents}
        For each agent: check content differences
        Return: {agent, status, changes[]}

    - task: "p10k-analyzer"
      type: "Explore"
      model: "haiku"
      prompt: |
        Compare .p10k.zsh local vs remote
        Return: {status, changes[]}

    - task: "settings-analyzer"
      type: "Explore"
      model: "haiku"
      prompt: |
        Compare settings.json local vs remote
        Return: {status, changes[]}
```

**IMPORTANT** : Lancer les 6 agents dans UN SEUL message.

**Output Phase 3 :**

```
═══════════════════════════════════════════════
  Component Analysis (Parallel) - from MANIFEST
═══════════════════════════════════════════════

  features:
    + languages/zig/           (new - in manifest)
    ~ languages/go/RULES.md    (modified)

  hooks:
    ~ format.sh                (modified)
    ~ lint.sh                  (modified)
    + post-compact.sh          (new - in manifest)

  commands:
    ~ git.md                   (modified)
    + improve.md               (new - in manifest)

  agents:
    ~ developer-specialist-go  (modified)
    + developer-specialist-zig (new - in manifest)

  p10k:
    (no changes)

  settings:
    ~ settings.json            (modified)

═══════════════════════════════════════════════
```

---

## Phase 4 : Synthesize (RLM Pattern)

### 4.1 : Appliquer les mises à jour

**Pour chaque composant avec changements :**

**IMPORTANT** : Les listes ci-dessous sont extraites dynamiquement depuis
le manifest distant (Phase 0 Bootstrap). Ce sont les valeurs de référence.

#### Features

```bash
BASE="https://raw.githubusercontent.com/kodflow/devcontainer-template/main"
# MANIFEST_LANGUAGES: Liste extraite du manifest distant (source of truth)
for lang in go nodejs python rust java ruby php elixir dart scala carbon cpp; do
    curl -sL "$BASE/.devcontainer/features/languages/$lang/RULES.md" \
         -o ".devcontainer/features/languages/$lang/RULES.md" 2>/dev/null
done
```

#### Hooks (scripts)

```bash
# MANIFEST_SCRIPTS: Liste extraite du manifest distant (source of truth)
for script in format imports lint security test commit-validate pre-validate post-edit post-compact; do
    curl -sL "$BASE/.devcontainer/images/.claude/scripts/$script.sh" \
         -o ".devcontainer/images/.claude/scripts/$script.sh" 2>/dev/null
    chmod +x ".devcontainer/images/.claude/scripts/$script.sh"
done
```

#### Commands

```bash
# MANIFEST_COMMANDS: Liste extraite du manifest distant (source of truth)
for cmd in git search update plan review do test init improve; do
    curl -sL "$BASE/.devcontainer/images/.claude/commands/$cmd.md" \
         -o ".devcontainer/images/.claude/commands/$cmd.md" 2>/dev/null
done
```

#### Agents

```bash
# MANIFEST_AGENTS: Liste extraite du manifest distant (source of truth)
mkdir -p ".devcontainer/images/.claude/agents"
for agent in devops-executor-bsd devops-executor-linux devops-executor-osx \
             devops-executor-qemu devops-executor-vmware devops-executor-windows \
             devops-orchestrator devops-specialist-aws devops-specialist-azure \
             devops-specialist-docker devops-specialist-finops devops-specialist-gcp \
             devops-specialist-hashicorp devops-specialist-infrastructure \
             devops-specialist-kubernetes devops-specialist-security \
             developer-executor-quality developer-executor-security \
             developer-orchestrator developer-specialist-carbon \
             developer-specialist-cpp developer-specialist-dart \
             developer-specialist-elixir developer-specialist-go \
             developer-specialist-java developer-specialist-nodejs \
             developer-specialist-php developer-specialist-python \
             developer-specialist-review developer-specialist-ruby \
             developer-specialist-rust developer-specialist-scala; do
    curl -sL "$BASE/.devcontainer/images/.claude/agents/$agent.md" \
         -o ".devcontainer/images/.claude/agents/$agent.md" 2>/dev/null
done
```

#### p10k

```bash
curl -sL "$BASE/.devcontainer/images/.p10k.zsh" \
     -o ".devcontainer/images/.p10k.zsh" 2>/dev/null
```

#### Settings

```bash
curl -sL "$BASE/.devcontainer/images/.claude/settings.json" \
     -o ".devcontainer/images/.claude/settings.json" 2>/dev/null
```

### 4.2 : Cleanup deprecated files

```yaml
cleanup_workflow:
  deprecated_files:
    - ".coderabbit.yaml"  # CodeRabbit removed (subscription ended)

  action: |
    for file in deprecated_files:
      if exists(file):
        rm file
        log "Removed deprecated: $file"
```

```bash
# Remove deprecated configuration files
[ -f ".coderabbit.yaml" ] && rm -f ".coderabbit.yaml" \
    && echo "Removed deprecated .coderabbit.yaml"
```

### 4.3 : Validation finale

```yaml
validation_workflow:
  1_verify_files:
    action: "Vérifier que tous les fichiers sont valides"
    check: "Pas de 404, syntaxe correcte"

  2_run_hooks:
    action: "Exécuter les hooks pour valider"
    tools: [Bash]

  3_update_version:
    action: "Mettre à jour .template-version"
    tools: [Write]
```

```bash
# Enregistrer la version
COMMIT=$(curl -sL "https://api.github.com/repos/kodflow/devcontainer-template/commits/main" | jq -r '.sha[:7]')
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"commit\": \"$COMMIT\", \"updated\": \"$DATE\"}" > .devcontainer/.template-version
```

### 4.4 : Rapport consolidé

**Output Final :**

```
═══════════════════════════════════════════════
  ✓ DevContainer updated successfully
═══════════════════════════════════════════════

  Template: kodflow/devcontainer-template
  Version : def5678 (2024-01-20)
  Manifest: v1.0 (source of truth)

  Updated components (from MANIFEST):
    ✓ features    (12 languages)
    ✓ hooks       (9 scripts)
    ✓ commands    (9 commands)
    ✓ agents      (32 agents)
    - p10k        (unchanged)
    ✓ settings    (1 file)

  Cleanup (deprecated from MANIFEST):
    ✓ .coderabbit.yaml removed

  Total: 63 files synchronized

  Note: Restart terminal to apply p10k changes.

═══════════════════════════════════════════════
```

---

## --check

Mode dry-run : affiche les différences sans appliquer.

```
═══════════════════════════════════════════════
  /update --check (from MANIFEST)
═══════════════════════════════════════════════

  Manifest: v1.0 (fetched from template)

  Updates available:

  features (2 changes):
    ~ go/RULES.md      → Go 1.24 (was 1.23)
    + zig/             → New (discovered in manifest)

  hooks (1 change):
    ~ lint.sh          → Added ktn-linter support

  commands (1 change):
    + improve.md       → New (discovered in manifest)

  agents (2 changes):
    ~ developer-specialist-go  → Updated
    + developer-specialist-zig → New (discovered in manifest)

  deprecated (1 file):
    - .coderabbit.yaml → Will be removed

  Run '/update' to apply all changes.
═══════════════════════════════════════════════
```

---

## --component NAME

Met à jour un seul composant.

```
/update --component hooks

═══════════════════════════════════════════════
  /update --component hooks
═══════════════════════════════════════════════

  Updating: hooks only

  ✓ format.sh      updated
  ✓ imports.sh     updated
  ✓ lint.sh        updated
  ✓ security.sh    updated
  ✓ test.sh        updated
  - pre-validate   (unchanged)
  - post-edit      (unchanged)

  Done: 5 files updated

═══════════════════════════════════════════════
```

---

## GARDE-FOUS (ABSOLUS)

| Action | Status | Raison |
|--------|--------|--------|
| Skip Phase 1 (Peek) | ❌ **INTERDIT** | Vérifier versions avant MAJ |
| Mettre à jour depuis source non-officielle | ❌ **INTERDIT** | Sécurité |
| Modifier fichiers hors .devcontainer/ | ❌ **INTERDIT** | Scope limité |
| Écraser fichiers modifiés sans backup | ⚠ WARNING | Afficher diff d'abord |

### Parallélisation légitime

| Élément | Parallèle? | Raison |
|---------|------------|--------|
| Analyse des 5 composants | ✅ Parallèle | Comparaisons indépendantes |
| Application des mises à jour | ❌ Séquentiel | Ordre peut importer |
| Validation finale | ✅ Parallèle | Checks indépendants |

---

## Fichiers concernés

**Mis à jour par /update :**
```
.devcontainer/
├── features/languages/*/RULES.md
├── images/
│   ├── .p10k.zsh
│   └── .claude/
│       ├── commands/*.md
│       ├── scripts/*.sh
│       └── settings.json
└── .template-version
```

**JAMAIS modifiés :**
```
.devcontainer/
├── devcontainer.json      # Config projet
├── docker-compose.yml     # Services locaux
├── Dockerfile             # Customisations
└── hooks/                 # Hooks lifecycle
```

---

## MANIFEST (Source of Truth)

**Cette section est parsée automatiquement par la Phase 0 Bootstrap.**

Quand vous ajoutez un nouveau composant au template, mettez à jour cette section.
Les projets downstream récupèreront automatiquement les nouvelles entrées.

```yaml
# =============================================================================
# UPDATE MANIFEST - DO NOT MODIFY FORMAT (machine-parseable)
# =============================================================================
manifest_version: "1.0"
template_repo: "kodflow/devcontainer-template"
template_branch: "main"

components:
  # Language features with RULES.md
  languages:
    - go
    - nodejs
    - python
    - rust
    - java
    - ruby
    - php
    - elixir
    - dart
    - scala
    - carbon
    - cpp

  # Hook scripts (.sh files)
  scripts:
    - format
    - imports
    - lint
    - security
    - test
    - commit-validate
    - pre-validate
    - post-edit
    - post-compact

  # Slash commands (.md files)
  commands:
    - git
    - search
    - update
    - plan
    - review
    - do
    - test
    - init
    - improve

  # Agent definitions (.md files in agents/)
  agents:
    - devops-executor-bsd
    - devops-executor-linux
    - devops-executor-osx
    - devops-executor-qemu
    - devops-executor-vmware
    - devops-executor-windows
    - devops-orchestrator
    - devops-specialist-aws
    - devops-specialist-azure
    - devops-specialist-docker
    - devops-specialist-finops
    - devops-specialist-gcp
    - devops-specialist-hashicorp
    - devops-specialist-infrastructure
    - devops-specialist-kubernetes
    - devops-specialist-security
    - developer-executor-quality
    - developer-executor-security
    - developer-orchestrator
    - developer-specialist-carbon
    - developer-specialist-cpp
    - developer-specialist-dart
    - developer-specialist-elixir
    - developer-specialist-go
    - developer-specialist-java
    - developer-specialist-nodejs
    - developer-specialist-php
    - developer-specialist-python
    - developer-specialist-review
    - developer-specialist-ruby
    - developer-specialist-rust
    - developer-specialist-scala

  # Static config files
  config_files:
    - path: ".devcontainer/images/.p10k.zsh"
      description: "Powerlevel10k configuration"
    - path: ".devcontainer/images/.claude/settings.json"
      description: "Claude settings"

# Files to remove from downstream projects (deprecated)
deprecated:
  - ".coderabbit.yaml"  # CodeRabbit subscription ended (2025-01)

# =============================================================================
# END MANIFEST
# =============================================================================
```

### Parsing le Manifest

```bash
# Récupérer le manifest distant
MANIFEST_URL="https://raw.githubusercontent.com/kodflow/devcontainer-template/main"
MANIFEST_URL+="/.devcontainer/images/.claude/commands/update.md"

# Extraire les langages
curl -sL "$MANIFEST_URL" | \
  sed -n '/^  languages:/,/^  [a-z]/p' | \
  grep '^\s*-' | sed 's/^\s*- //'

# Extraire les scripts
curl -sL "$MANIFEST_URL" | \
  sed -n '/^  scripts:/,/^  [a-z]/p' | \
  grep '^\s*-' | sed 's/^\s*- //'

# Extraire les commandes
curl -sL "$MANIFEST_URL" | \
  sed -n '/^  commands:/,/^  [a-z]/p' | \
  grep '^\s*-' | sed 's/^\s*- //'

# Extraire les fichiers deprecated
curl -sL "$MANIFEST_URL" | \
  sed -n '/^deprecated:/,/^# =/p' | \
  grep '^\s*-' | sed 's/^\s*- "\([^"]*\)".*/\1/'
```
