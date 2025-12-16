# Build - Project & Task Planner

$ARGUMENTS

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
| `--list` | Liste projets |
| `--for <project> --list` | Liste tâches |

---

## Init Wizard

### Questions

1. **Langage** → Voir `.devcontainer/features/languages/`
2. **Architecture** → Voir `.devcontainer/features/architectures/`
3. **Plateformes** (multiSelect) → Linux, macOS, Windows, iOS, Android, Web, Embedded
4. **CPU** (multiSelect) → amd64, arm64, arm, riscv64, wasm32

### Defaults par langage

| Langage | Architecture default | Plateformes default |
|---------|---------------------|---------------------|
| Go, Java, Node.js, Rust, Python, Scala, Elixir | **Sliceable Monolith** | Linux, macOS |
| PHP, Ruby | **MVC** | Linux |
| Dart/Flutter | **MVVM** | iOS, Android |
| C++ | **Clean** | Linux, macOS |

### Documentation

- **Langages** : `.devcontainer/features/languages/<lang>/RULES.md`
- **Architectures** : `.devcontainer/features/architectures/<arch>.md`

### Actions

1. Créer structure selon architecture choisie
2. Créer `/src/PROJECT.md` avec config
3. Créer fichiers de base (go.mod, package.json, etc.)
4. Chaîner → `/build --context`

---

## --context

1. **Update versions** depuis sources officielles (JAMAIS downgrade)
2. **Générer CLAUDE.md** dans chaque dossier (entonnoir)

### Sources versions

| Langage | URL |
|---------|-----|
| Go | https://go.dev/VERSION?m=text |
| Python | https://endoflife.date/api/python.json |
| Node.js | https://nodejs.org/dist/index.json |
| Rust | https://static.rust-lang.org/dist/channel-rust-stable.toml |

### Règles CLAUDE.md

- Profondeur 1 : ~30 lignes
- Profondeur 2 : ~50 lignes
- Profondeur 3+ : ~60 lignes
- Jamais commit (gitignored)

---

## --project / --task

### Taskwarrior UDAs

```bash
task config uda.model.type string
task config uda.model.values opus,sonnet,haiku
task config uda.parallel.type string
task config uda.parallel.values yes,no
task config uda.phase.type numeric
```

### Auto-détection

| Complexité | model |
|------------|-------|
| Simple (format, lint) | haiku |
| Standard (CRUD, tests) | sonnet |
| Complexe (archi, sécu) | opus |

| Dépendance | parallel |
|------------|----------|
| Fichiers différents | yes |
| Même fichier/séquentiel | no |

---

## Output

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
