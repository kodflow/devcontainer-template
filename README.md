# devcontainer-template

Coquille DevContainer universelle fournissant un ecosysteme IA complet — 29 agents specialistes et ~19 commandes slash fournis par le marketplace kodflow (6 plugins), workflows auto-correctifs — pour bootstrapper et developper n'importe quel projet avec une qualite maximale. Fiabilite d'abord : les agents raisonnent en profondeur, recoupent les sources officielles, et s'auto-corrigent jusqu'a ce que le resultat respecte les standards.

## Installation Rapide

### One-Liner (Machine Hôte ou Projet Existant)

Installez Claude Code avec les assets embarqués (scripts qualité, 155+ patterns) **et** enregistre le marketplace kodflow (agents, commandes slash, hooks) en une seule commande :

```bash
curl -fsSL https://raw.githubusercontent.com/kodflow/devcontainer-template/main/.devcontainer/install.sh | bash
```

**Ce qui est installé :**
- ✅ Claude CLI (si pas déjà installé)
- ✅ Marketplace kodflow enregistré + 6 plugins installés : `kodflow-workflow`, `kodflow-review`, `kodflow-devops`, `kodflow-shell` (`super-claude` sur le PATH, sélecteur de sessions), `kodflow-specialists` (29 agents), `kodflow-hooks` (5 scripts, 15 événements)
- ✅ 7 scripts qualité embarqués dans l'image (`format.sh`, `lint.sh`, `test.sh`, `typecheck.sh`, `pre-commit-*.sh`)
- ✅ 155+ design patterns (GoF, Cloud, DDD, Enterprise)
- ✅ Outils additionnels (rtk, status-line)

Fail-open si le marketplace est injoignable : avertissement, les plugins déjà en cache continuent de fonctionner.

**Installation minimale (sans documentation) :**

```bash
curl -fsSL https://raw.githubusercontent.com/kodflow/devcontainer-template/main/.devcontainer/install.sh | bash -s -- --minimal
```

**Installation avec target personnalisé :**

```bash
DC_TARGET=/path/to/project curl -fsSL https://raw.githubusercontent.com/kodflow/devcontainer-template/main/.devcontainer/install.sh | bash
```

**Emplacements d'installation :**
- **Machine hôte :** `~/.claude/`
- **DevContainer :** `/workspace/.devcontainer/images/.claude/`

**Mise à jour ultérieure :**

```bash
# Dans Claude Code
/update

# Ou manuellement (dans DevContainer)
bash .devcontainer/install.sh
```

---

## Outils inclus

### Base
- **Ubuntu 24.04 LTS**
- **Zsh + Oh My Zsh + Powerlevel10k**
- **Git, jq, yq, curl, build-essential**

### Cloud & DevOps
| Outil | Description |
|-------|-------------|
| **AWS CLI v2** | Amazon Web Services |
| **gcloud** | Google Cloud SDK |
| **az** | Azure CLI |
| **terraform** | Infrastructure as Code |
| **vault, consul, nomad, packer** | HashiCorp Suite |
| **kubectl, helm** | Kubernetes |
| **ansible** | Configuration Management |

### Development
| Outil | Description |
|-------|-------------|
| **gh** | GitHub CLI |
| **claude** | Claude Code CLI |
| **op** | 1Password CLI |
| **bazel** | Build System |
| **task** | Taskwarrior |
| **status-line** | Claude Code status bar |

### Langages
Les langages sont ajoutés via **DevContainer Features** selon vos besoins :

```jsonc
// Dans devcontainer.json, décommenter les langages souhaités :
"features": {
  "ghcr.io/kodflow/devcontainer-features/go:1": {},
  "ghcr.io/kodflow/devcontainer-features/python:1": {},
  "ghcr.io/kodflow/devcontainer-features/rust:1": {}
}
```

25 langages disponibles sur `ghcr.io/kodflow/devcontainer-features/`

## Installation

### Nouveau projet

```bash
gh repo create mon-projet --template kodflow/devcontainer-template --public
cd mon-projet
code .
```

### Projet existant

Copiez le dossier `.devcontainer/` dans votre projet.

## Configuration MCP

Le template inclut des serveurs MCP pré-configurés pour Claude Code.

### Serveurs MCP inclus

| Serveur | Description |
|---------|-------------|
| **github** | Intégration GitHub (PR, Issues) |
| **gitlab** | Intégration GitLab (MR, Pipelines) |
| **context7** | Documentation à jour (fragment image) |
| **ktn-linter** | Linting de code (fragment image) |
| **playwright** | Tests E2E, navigateur (feature browser) |

### Configuration des tokens

**Option 1 : Variables d'environnement**

```bash
export GITHUB_API_TOKEN="ghp_xxx"
```

**Option 2 : 1Password**

Configurez `OP_SERVICE_ACCOUNT_TOKEN` et les items correspondants dans votre vault.

### Fichiers MCP

| Fichier | Description |
|---------|-------------|
| `mcp.json` | Config MCP projet (ignoré par git) |
| `.devcontainer/images/mcp.json.tpl` | Template MCP |

### ktn-linter & Claude Code Hooks

`ktn-linter` tourne comme serveur MCP **et** comme backend HTTP interrogé par le plugin `kodflow-hooks` (les hooks ne sont plus déclarés par le template). `on-tool.sh` et `on-stop.sh` sondent `127.0.0.1:$KTN_LINTER_PORT` (`/dev/tcp`, défaut 7717) et n'appellent l'API que si le port répond — dégradation gracieuse sinon.

| Hook | Événement | Endpoint | Rôle |
|------|-----------|----------|------|
| `on-tool.sh` | PreToolUse (Write/Edit) | `/hooks/pre-tool-use` | Pré-check, phases `KTN_PRE_PHASES` (défaut `structural,signatures`) |
| `on-stop.sh` | Stop | `/hooks/stop` | Verdict sur les packages Go modifiés dans la session, phases `KTN_STOP_PHASES` (défaut `structural,signatures,logic,performance,modern,style,comment,tests`) ; un `decision:block` est transmis tel quel |

**Vérification rapide :**

```bash
which ktn-linter && curl -sf "http://localhost:${KTN_LINTER_PORT:-7717}/health" && echo "OK"
```

Voir [docs/ktn-linter-integration.md](docs/ktn-linter-integration.md) pour le contrat complet.

## Structure

```
.devcontainer/
├── devcontainer.json          # Configuration DevContainer
├── docker-compose.yml         # Services Docker
├── Dockerfile                 # Extends l'image de base
├── hooks/
│   └── lifecycle/
│       └── initialize.sh      # Avant création (hôte : Ollama, .env)
└── images/
    ├── Dockerfile.base        # Layer stable (apt, Cloud CLIs) — hebdo
    ├── Dockerfile             # Layer dynamique (Claude, outils) — quotidien
    ├── mcp.json.tpl           # Template MCP (+ fragments par feature)
    └── hooks/lifecycle/       # Hooks embarqués dans l'image
```

## Commandes

### Rebuild container

```bash
# VS Code
Cmd+Shift+P > "Dev Containers: Rebuild Container"
```

### Claude avec MCP

```bash
# Alias configuré automatiquement
super-claude
```

### Nettoyer

```bash
docker compose -f .devcontainer/docker-compose.yml down -v
```

## Volumes persistants

- `zsh-history` : Historique shell
- `package-cache` : Caches packages (npm, pip, cargo, etc.)
- `claude-config` : Configuration Claude (credentials, sessions)
- `cloud-config` : Config cloud (AWS, GCP, Azure, 1Password)

## License

MIT
