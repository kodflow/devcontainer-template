# Kodflow DevContainer Template

## Stack

- Ubuntu 24.04 LTS
- Zsh + Powerlevel10k
- Docker + DevContainer

## Slash Commands

### /build - Planification

| Commande | Action |
|----------|--------|
| `/build --project <desc>` | Crée un projet avec tâches auto-générées |
| `/build --for <project> --task <desc>` | Ajoute une tâche au projet |
| `/build --for <project> --task <id>` | Met à jour une tâche |
| `/build --list` | Liste tous les projets |
| `/build --for <project> --list` | Liste les tâches du projet |

### /run - Exécution

| Commande | Action |
|----------|--------|
| `/run <project>` | Exécute toutes les tâches du projet |
| `/run --for <project> --task <id>` | Exécute une tâche spécifique |

## Taskwarrior

### UDAs (auto-détectés)

| Attribut | Valeurs | Auto-détection |
|----------|---------|----------------|
| `model` | haiku, sonnet, opus | Complexité de la tâche |
| `parallel` | yes, no | Dépendances entre tâches |
| `phase` | 1, 2, 3... | Ordre d'exécution |

### Workflow

```
/build --project "Implémenter auth OAuth"
    ↓
Analyse + Questions + Plan auto
    ↓
/build --list  (voir les projets)
/build --for auth-oauth --list  (voir les tâches)
    ↓
/run auth-oauth  (exécute tout)
```

### Tags Taskwarrior

- `+claude` : Tâches gérées par Claude
- `+BLOCKED` : En attente de dépendances
- `+ACTIVE` : En cours d'exécution
