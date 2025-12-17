# Build - Project & Task Planner

$ARGUMENTS

---

## Ressources distantes

Toutes les ressources sont accessibles depuis GitHub si non présentes localement :

```
REPO="kodflow/devcontainer-template"
BASE="https://raw.githubusercontent.com/$REPO/main/.devcontainer/features"
```

| Ressource | Local | Distant |
|-----------|-------|---------|
| Langages | `.devcontainer/features/languages/` | `$BASE/languages/` |
| Architectures | `.devcontainer/features/architectures/` | `$BASE/architectures/` |
| RULES.md | `languages/<lang>/RULES.md` | `$BASE/languages/<lang>/RULES.md` |

**Priorité** : Local > Distant (fallback automatique)

---

## Prérequis (auto-check)

Avant toute action, vérifier et configurer automatiquement :

```bash
# 1. Vérifier taskwarrior
if ! command -v task &>/dev/null; then
    echo "⚠ Taskwarrior non installé. Exécuter /update d'abord."
    exit 1
fi

# 2. Configurer UDAs si absents
if ! task _get rc.uda.model.type &>/dev/null 2>&1; then
    echo "Configuring taskwarrior UDAs..."
    task config uda.model.type string
    task config uda.model.values opus,sonnet,haiku
    task config uda.model.default sonnet
    task config uda.parallel.type string
    task config uda.parallel.values yes,no
    task config uda.parallel.default no
    task config uda.phase.type numeric
    task config uda.phase.default 1
    echo "✓ UDAs configured"
fi

# 3. Vérifier MCP taskwarrior
if [ -f ".mcp.json" ]; then
    if ! grep -q "taskwarrior" .mcp.json 2>/dev/null; then
        echo "⚠ MCP taskwarrior manquant. Exécuter /update."
    fi
fi
```

---

## Détection

- **SI `/src` n'existe PAS** → Assistant d'initialisation
- **SI `/src` existe** → Parser les arguments

---

## Arguments

| Pattern | Action |
|---------|--------|
| (vide + pas de /src) | Init wizard |
| `--context` | Génère CLAUDE.md + update versions |
| `--project <desc>` | Crée projet Taskwarrior |
| `--for <project> --task <desc>` | Ajoute tâche |
| `--for <project> --task <id>` | Met à jour tâche |
| `--list` | Liste projets |
| `--for <project> --list` | Liste tâches |

---

## Init Wizard

### Langages disponibles

Récupérer la liste depuis GitHub si non présent localement :

```bash
# Liste des langages disponibles
curl -sL "https://api.github.com/repos/kodflow/devcontainer-template/contents/.devcontainer/features/languages" | \
  jq -r '.[].name' 2>/dev/null || echo "go node python rust"
```

### Questions

1. **Langage** → Liste dynamique (local ou distant)
2. **Architecture** → sliceable-monolith, mvc, mvvm, clean, hexagonal
3. **Plateformes** (multiSelect) → Linux, macOS, Windows, iOS, Android, Web, Embedded
4. **CPU** (multiSelect) → amd64, arm64, arm, riscv64, wasm32

### Defaults par langage

| Langage | Architecture default | Plateformes default |
|---------|---------------------|---------------------|
| Go, Java, Node.js, Rust, Python, Scala, Elixir | **Sliceable Monolith** | Linux, macOS |
| PHP, Ruby | **MVC** | Linux |
| Dart/Flutter | **MVVM** | iOS, Android |
| C++ | **Clean** | Linux, macOS |

### Récupération RULES.md

```bash
LANG="go"  # exemple
LOCAL=".devcontainer/features/languages/$LANG/RULES.md"
REMOTE="https://raw.githubusercontent.com/kodflow/devcontainer-template/main/.devcontainer/features/languages/$LANG/RULES.md"

if [ -f "$LOCAL" ]; then
    cat "$LOCAL"
else
    curl -sL "$REMOTE"
fi
```

### Actions après wizard

1. Créer structure selon architecture (voir fichier `.md` correspondant)
2. Créer `/src/PROJECT.md` avec config
3. Créer fichiers de base (go.mod, package.json, etc.)
4. Chaîner → `/build --context`

---

## --context

1. **Update versions** depuis sources officielles (JAMAIS downgrade)
2. **Générer CLAUDE.md** dans chaque dossier (entonnoir)

### Règles CLAUDE.md

- Profondeur 1 : ~30 lignes
- Profondeur 2 : ~50 lignes
- Profondeur 3+ : ~60 lignes
- Jamais commit (gitignored)

---

## --project : Créer un projet

1. Analyse la description pour comprendre le scope
2. Pose des questions si infos manquantes (`AskUserQuestion`)
3. Explore le codebase si pertinent
4. Recherche web pour best practices si nécessaire
5. Crée le projet et génère automatiquement les tâches :

```bash
task add "<tache>" project:<nom_projet> +claude \
  model:<haiku|sonnet|opus> \
  parallel:<yes|no> \
  phase:<N> \
  [depends:<IDs>]

task <ID> annotate "Action: <détails>"
task <ID> annotate "Fichiers: <paths>"
task <ID> annotate "Critères: <done_when>"
```

---

## --for <project> --task : Créer une tâche

1. Analyse la description
2. Détermine automatiquement :
   - `model` : selon complexité
   - `parallel` : selon dépendances
   - `phase` : selon ordre logique
   - `depends` : IDs des tâches prérequises

```bash
task add "<description>" project:<project> +claude \
  model:<auto> parallel:<auto> phase:<auto> [depends:<auto>]
```

---

## Auto-détection du modèle

| Critères | Modèle | Exemples |
|----------|--------|----------|
| Tâche simple, mécanique | `haiku` | Formatting, linting, renommage, typos |
| Tâche standard, logique claire | `sonnet` | CRUD, refactoring, tests unitaires, features simples |
| Tâche complexe, réflexion | `opus` | Architecture, debugging complexe, sécurité, design patterns |

---

## Auto-détection parallélisation

| Critères | Parallel | Exemples |
|----------|----------|----------|
| Fichiers différents, indépendant | `yes` | Créer 3 composants distincts |
| Même fichier, dépendance logique | `no` | Créer interface puis implémentation |
| Ordre requis | `no` | Setup DB avant migrations |

---

## Auto-détection phase

- **Phase 1** : Tâches sans prérequis (setup, config)
- **Phase 2** : Tâches dépendant de phase 1
- **Phase N** : Tâches dépendant de phase N-1
- **Même phase** si parallélisables ensemble

Exemple :
```
Phase 1: [Setup DB] [Setup Auth]        ← parallel: yes
Phase 2: [Create User Model]            ← depends: DB
Phase 3: [Create User API] [User Tests] ← parallel: yes, depends: Model
```

---

## Taskwarrior UDAs (auto-config)

```bash
task config uda.model.type string
task config uda.model.values opus,sonnet,haiku
task config uda.model.default sonnet
task config uda.parallel.type string
task config uda.parallel.values yes,no
task config uda.parallel.default no
task config uda.phase.type numeric
task config uda.phase.default 1
```

---

## --list / --for <project> --list

```bash
task projects                              # Liste projets
task project:<project> +claude list        # Tâches du projet
task project:<project> +claude +BLOCKED    # Tâches bloquées
task project:<project> summary             # Résumé
```

---

## Outputs

### Init projet
```
## Projet initialisé

| Setting | Value |
|---------|-------|
| Langage | Go |
| Architecture | Sliceable Monolith |
| Plateformes | linux, macos |
| CPU | amd64, arm64 |

→ /build --context
```

### Création projet
```
## Projet créé : auth-system

| # | Phase | Tâche | Modèle | // | Dépend |
|---|-------|-------|--------|----|--------|
| 1 | 1 | Setup database schema | sonnet | yes | - |
| 2 | 1 | Setup JWT config | haiku | yes | - |
| 3 | 2 | Create User model | sonnet | no | 1 |
| 4 | 2 | Create Auth service | opus | no | 1,2 |
| 5 | 3 | Create login endpoint | sonnet | yes | 3,4 |
| 6 | 3 | Create register endpoint | sonnet | yes | 3,4 |
| 7 | 4 | Write unit tests | sonnet | yes | 5,6 |

Exécuter : `/run auth-system`
```

### Création tâche
```
## Tâche ajoutée : #8

- Projet : auth-system
- Tâche : Add password reset
- Modèle : sonnet
- Phase : 3
- Parallel : yes
- Dépend de : 4
```

### Liste projets
```
## Projets

| Projet | Tâches | Complétées | % |
|--------|--------|------------|---|
| auth-system | 7 | 3 | 43% |
| billing | 12 | 12 | 100% |
```

### Liste tâches
```
## Tâches : auth-system

### Prêtes (Phase 3)
| ID | Tâche | Modèle | // |
|----|-------|--------|----|
| 5 | Create login endpoint | sonnet | yes |
| 6 | Create register endpoint | sonnet | yes |

### Bloquées
| ID | Tâche | Bloquée par |
|----|-------|-------------|
| 7 | Write unit tests | 5, 6 |

### Complétées
| ID | Tâche |
|----|-------|
| 1 | Setup database schema |
| 2 | Setup JWT config |
| 3 | Create User model |
```
