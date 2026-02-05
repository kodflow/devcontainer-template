# devcontainer-template

Coquille DevContainer universelle fournissant un ecosysteme IA complet — 35 agents specialistes, 11 commandes slash, workflows auto-correctifs — pour bootstrapper et developper n'importe quel projet avec une qualite maximale. Fiabilite d'abord : les agents raisonnent en profondeur, recoupent les sources officielles, et s'auto-corrigent jusqu'a ce que le resultat respecte les standards.

## Installation Rapide

### One-Liner (Machine Hôte ou Projet Existant)

Installez Claude Code avec **TOUS les assets** (35 agents, 11 commands, 11 scripts, 155+ patterns) en une seule commande :

```bash
curl -fsSL https://raw.githubusercontent.com/kodflow/devcontainer-template/main/.devcontainer/install.sh | bash
```

**Ce qui est installé :**
- ✅ Claude CLI (si pas déjà installé)
- ✅ 35 agents spécialisés (Go, Python, Rust, Node.js, etc.)
- ✅ 11 commandes slash (`/git`, `/review`, `/plan`, `/do`, etc.)
- ✅ 11 scripts de hooks (security, lint, format, test)
- ✅ 155+ design patterns (GoF, Cloud, DDD, Enterprise)
- ✅ Outils additionnels (grepai, status-line)

**Total :** 239 fichiers (~3.2MB) en 1-2 minutes

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

```json
"features": {
  "ghcr.io/devcontainers/features/go:1": {},
  "ghcr.io/devcontainers/features/python:1": {},
  "ghcr.io/devcontainers/features/rust:1": {}
}
```

Voir : https://containers.dev/features

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
| **github** | Intégration GitHub |
| **codacy** | Analyse de code |
| **taskwarrior** | Gestion de tâches |

### Configuration des tokens

**Option 1 : Variables d'environnement**

```bash
export GITHUB_API_TOKEN="ghp_xxx"
export CODACY_API_TOKEN="xxx"
```

**Option 2 : 1Password**

Configurez `OP_SERVICE_ACCOUNT_TOKEN` et les items correspondants dans votre vault.

### Fichiers MCP

| Fichier | Description |
|---------|-------------|
| `mcp.json` | Config MCP projet (ignoré par git) |
| `.devcontainer/images/mcp.json.tpl` | Template MCP |

## Structure

```
.devcontainer/
├── devcontainer.json          # Configuration DevContainer
├── docker-compose.yml         # Services Docker
├── Dockerfile                 # Extends l'image de base
├── hooks/
│   ├── lifecycle/
│   │   ├── initialize.sh      # Avant création (hôte)
│   │   ├── onCreate.sh        # Création container
│   │   ├── postCreate.sh      # Config initiale
│   │   ├── postStart.sh       # Chaque démarrage (MCP)
│   │   └── postAttach.sh      # Attachement IDE
│   └── shared/
│       ├── mcp.json.tpl       # Template MCP
│       └── utils.sh           # Fonctions utilitaires
└── images/
    └── Dockerfile             # Image de base GHCR
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

- `{projet}-local-bin` : Binaires locaux
- `vscode-extensions` : Extensions VS Code
- `zsh-history` : Historique shell

## License

MIT
