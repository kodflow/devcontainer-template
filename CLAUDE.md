# Kodflow DevContainer Template

## Stack

- Ubuntu 24.04 LTS
- Zsh + Powerlevel10k
- Docker + DevContainer

## Slash Commands

### /build - Planification

| Commande | Action |
|----------|--------|
| `/build --context` | Génère CLAUDE.md dans tous les dossiers |
| `/build --project <desc>` | Crée projet + tâches auto |
| `/build --for <project> --task <desc>` | Ajoute une tâche |
| `/build --for <project> --task <id>` | Met à jour une tâche |
| `/build --list` | Liste les projets |
| `/build --for <project> --list` | Liste les tâches |

### /run - Exécution

| Commande | Action |
|----------|--------|
| `/run <project>` | Exécute tout le projet |
| `/run --for <project> --task <id>` | Exécute une tâche |

## Hooks

### Scripts disponibles (`.claude/scripts/`)

| Script | Fonction | Langages |
|--------|----------|----------|
| `format.sh` | Auto-format | JS/TS, Python, Go, Rust, JSON, YAML, Terraform |
| `lint.sh` | Linting + fix | JS/TS, Python, Go, Rust, Shell, Dockerfile |
| `imports.sh` | Tri imports | JS/TS, Python, Go, Rust, Java |
| `typecheck.sh` | Type check | TypeScript, Python, Go, Rust |
| `security.sh` | Détection secrets | Tous |
| `test.sh` | Tests auto | JS/TS, Python, Go, Rust |
| `pre-validate.sh` | Protection fichiers | Tous |
| `post-edit.sh` | Format + Imports + Lint | Tous |

### Configuration active

```
PreToolUse (Write|Edit):
  → pre-validate.sh (protection fichiers sensibles)

PostToolUse (Write|Edit):
  → post-edit.sh (format + imports + lint)
  → security.sh (détection secrets)
  → test.sh (si fichier test)
```

## Contexte (CLAUDE.md)

### Principe : Entonnoir

```
/CLAUDE.md              → Vue d'ensemble (commité)
/src/CLAUDE.md          → Détails src (ignoré)
/src/components/        → Plus de détails (ignoré)
```

### Règles

- < 60 lignes par fichier
- Concis et universel
- Divulgation progressive
- Sous-dossiers JAMAIS commités

## Taskwarrior

### UDAs

| Attribut | Valeurs |
|----------|---------|
| `model` | haiku, sonnet, opus |
| `parallel` | yes, no |
| `phase` | 1, 2, 3... |

### Workflow

```
/build --context              → Génère le contexte
/build --project "Auth OAuth" → Planifie les tâches
/run auth-oauth               → Exécute
```
