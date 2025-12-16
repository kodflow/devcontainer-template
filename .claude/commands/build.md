# Build - Project & Task Planner

$ARGUMENTS

---

## Parsing des arguments

| Pattern | Action |
|---------|--------|
| `--project <desc>` | Crée un nouveau projet |
| `--for <project> --task <desc>` | Crée une tâche dans le projet |
| `--for <project> --task <id>` | Met à jour une tâche existante |
| `--list` | Liste tous les projets |
| `--for <project> --list` | Liste les tâches du projet |

---

## Actions

### `--project <description>` : Créer un projet

1. **Analyse la description** pour comprendre le scope
2. **Pose des questions** si infos manquantes (`AskUserQuestion`)
3. **Explore le codebase** si pertinent
4. **Recherche web** pour best practices si nécessaire
5. **Crée le projet** et génère automatiquement les tâches :

```bash
# Créer les tâches avec métadonnées
task add "<tache>" project:<nom_projet> +claude \
  model:<haiku|sonnet|opus> \
  parallel:<yes|no> \
  phase:<N> \
  [depends:<IDs>]

# Ajouter les détails
task <ID> annotate "Action: <détails>"
task <ID> annotate "Fichiers: <paths>"
task <ID> annotate "Critères: <done_when>"
```

### `--for <project> --task <description>` : Créer une tâche

1. **Analyse la description**
2. **Détermine automatiquement** :
   - `model` : haiku (simple), sonnet (standard), opus (complexe)
   - `parallel` : yes si indépendant, no si séquentiel
   - `phase` : selon les dépendances
   - `depends` : IDs des tâches prérequises

```bash
task add "<description>" project:<project> +claude \
  model:<auto> parallel:<auto> phase:<auto> [depends:<auto>]
```

### `--for <project> --task <id>` : Mettre à jour

```bash
task <id> modify <champs_modifies>
task <id> annotate "<nouvelle_info>"
```

### `--list` : Lister les projets

```bash
task projects
```

### `--for <project> --list` : Lister les tâches

```bash
task project:<project> +claude list
task project:<project> +claude +BLOCKED blocked
task project:<project> summary
```

---

## Auto-détection du modèle

| Critères | Modèle |
|----------|--------|
| Formatting, linting, renommage simple | `haiku` |
| CRUD, refactoring, tests unitaires | `sonnet` |
| Architecture, debugging complexe, sécurité | `opus` |

## Auto-détection parallélisation

| Critères | Parallel |
|----------|----------|
| Fichiers différents, pas de dépendance | `yes` |
| Même fichier, dépendance logique | `no` |

## Auto-détection phase

- Phase 1 : Tâches sans prérequis
- Phase N : Tâches dépendant de tâches phase N-1
- Même phase si parallélisables ensemble

---

## Initialisation UDA (auto si première utilisation)

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

## Output

### Création projet
```
## Projet créé : <nom>

| # | Phase | Tâche | Modèle | // | Dépend |
|---|-------|-------|--------|----|--------|
| 1 | 1 | ... | haiku | yes | - |
| 2 | 1 | ... | sonnet | yes | - |
| 3 | 2 | ... | opus | no | 1,2 |

Exécuter : `/run <nom>`
```

### Création tâche
```
## Tâche ajoutée : #<ID>

- Projet : <nom>
- Modèle : <model>
- Phase : <N>
- Parallel : <yes|no>
- Dépend de : <IDs>
```

### Liste projets
```
## Projets

| Projet | Tâches | Complétées | % |
|--------|--------|------------|---|
```

### Liste tâches
```
## Tâches : <projet>

### Prêtes
| ID | Phase | Tâche | Modèle | // |

### Bloquées
| ID | Tâche | Bloquée par |

### Complétées
| ID | Tâche |
```
