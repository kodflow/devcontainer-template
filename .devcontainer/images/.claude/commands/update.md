# Update - DevContainer Environment Update

$ARGUMENTS

---

## Description

Met à jour l'environnement DevContainer depuis le template officiel.

**Composants mis à jour :**

- **Features** - Language features et leurs RULES.md
- **Hooks** - Scripts Claude (format, lint, security, etc.)
- **Commands** - Commandes slash (/git, /search)
- **p10k** - Configuration Powerlevel10k
- **Settings** - Configuration Claude

**Source** : `github.com/kodflow/devcontainer-template`

---

## Arguments

| Pattern | Action |
|---------|--------|
| (none) | Mise à jour complète |
| `--check` | Vérifie les mises à jour disponibles |
| `--component <name>` | Met à jour un composant spécifique |
| `--help` | Affiche l'aide |

### Composants disponibles

| Composant | Chemin |
|-----------|--------|
| `features` | `.devcontainer/features/languages/` |
| `hooks` | `.devcontainer/images/.claude/scripts/` |
| `commands` | `.devcontainer/images/.claude/commands/` |
| `p10k` | `.devcontainer/images/.p10k.zsh` |
| `settings` | `.devcontainer/images/.claude/settings.json` |

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

Composants:
  features    Language features (RULES.md)
  hooks       Scripts Claude (format, lint...)
  commands    Commandes slash (/git, /search)
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

## Configuration

```yaml
REPO: "kodflow/devcontainer-template"
BRANCH: "main"
BASE_URL: "https://raw.githubusercontent.com/${REPO}/${BRANCH}"
```

---

## Workflow (RLM Pattern: Partition + Map)

### Phase 0 : Détection du contexte

1. Vérifier la connectivité GitHub
2. Récupérer le dernier commit du template
3. Comparer avec la version locale (si `.devcontainer/.template-version` existe)

**Output Phase 0 :**
```
═══════════════════════════════════════════════
  /update - Context Detection
═══════════════════════════════════════════════

  Local version  : abc1234 (2024-01-15)
  Remote version : def5678 (2024-01-20)

  Status: UPDATE AVAILABLE

═══════════════════════════════════════════════
```

---

### Phase 1 : Analyse des composants (Parallel)

**Lancer 5 Task agents en parallèle pour analyser chaque composant :**

```
Task({ prompt: "Compare features/languages/ local vs remote", model: "haiku" })
Task({ prompt: "Compare .claude/scripts/ local vs remote", model: "haiku" })
Task({ prompt: "Compare .claude/commands/ local vs remote", model: "haiku" })
Task({ prompt: "Compare .p10k.zsh local vs remote", model: "haiku" })
Task({ prompt: "Compare settings.json local vs remote", model: "haiku" })
```

---

### Phase 2 : Rapport des différences

**Pour chaque composant, identifier :**

- Fichiers ajoutés (nouveau dans template)
- Fichiers modifiés (diff entre local et remote)
- Fichiers supprimés (retiré du template)

```
═══════════════════════════════════════════════
  Component Analysis
═══════════════════════════════════════════════

  features:
    + languages/zig/           (new)
    ~ languages/go/RULES.md    (modified)

  hooks:
    ~ format.sh                (modified)
    ~ lint.sh                  (modified)

  commands:
    ~ git.md                   (modified)

  p10k:
    (no changes)

  settings:
    ~ settings.json            (modified)

═══════════════════════════════════════════════
```

---

### Phase 3 : Mise à jour (séquentielle)

**Pour chaque composant avec changements :**

#### Features

```bash
BASE="https://raw.githubusercontent.com/kodflow/devcontainer-template/main"
for lang in go nodejs python rust java ruby php elixir dart-flutter scala carbon cpp; do
    curl -sL "$BASE/.devcontainer/features/languages/$lang/RULES.md" \
         -o ".devcontainer/features/languages/$lang/RULES.md" 2>/dev/null
done
```

#### Hooks (scripts)

```bash
for script in format imports lint security test commit-validate bash-validate pre-validate post-edit; do
    curl -sL "$BASE/.devcontainer/images/.claude/scripts/$script.sh" \
         -o ".devcontainer/images/.claude/scripts/$script.sh" 2>/dev/null
    chmod +x ".devcontainer/images/.claude/scripts/$script.sh"
done
```

#### Commands

```bash
for cmd in git search update; do
    curl -sL "$BASE/.devcontainer/images/.claude/commands/$cmd.md" \
         -o ".devcontainer/images/.claude/commands/$cmd.md" 2>/dev/null
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

---

### Phase 4 : Validation

1. Vérifier que tous les fichiers sont valides (pas de 404)
2. Exécuter les hooks pour valider la syntaxe
3. Mettre à jour `.devcontainer/.template-version`

```bash
# Enregistrer la version
COMMIT=$(curl -sL "https://api.github.com/repos/kodflow/devcontainer-template/commits/main" | jq -r '.sha[:7]')
DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"commit\": \"$COMMIT\", \"updated\": \"$DATE\"}" > .devcontainer/.template-version
```

---

## --check

Mode dry-run : affiche les différences sans appliquer.

```
═══════════════════════════════════════════════
  /update --check
═══════════════════════════════════════════════

  Updates available:

  features (2 changes):
    ~ go/RULES.md      → Go 1.24 (was 1.23)
    + zig/             → New language support

  hooks (1 change):
    ~ lint.sh          → Added ktn-linter support

  commands (0 changes):
    (up to date)

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

## Output final

```
═══════════════════════════════════════════════
  ✓ DevContainer updated successfully
═══════════════════════════════════════════════

  Template: kodflow/devcontainer-template
  Version : def5678 (2024-01-20)

  Updated components:
    ✓ features    (2 files)
    ✓ hooks       (5 files)
    ✓ commands    (1 file)
    - p10k        (unchanged)
    ✓ settings    (1 file)

  Total: 9 files updated

  Note: Restart terminal to apply p10k changes.
═══════════════════════════════════════════════
```

---

## GARDE-FOUS

| Action | Status |
|--------|--------|
| Écraser des fichiers locaux modifiés sans backup | ⚠ WARNING (affiche diff) |
| Mettre à jour depuis une source non-officielle | ❌ INTERDIT |
| Modifier des fichiers hors .devcontainer/ | ❌ INTERDIT |

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
