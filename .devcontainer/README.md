# DevContainer Configuration

Ce repository est configuré avec un environnement de développement complet basé sur Docker, incluant des builds multi-architecture automatisés.

## Quick Start

### Utilisation de l'image pré-construite

Par défaut, le `docker-compose.yml` utilise l'image publiée sur GitHub Container Registry:

```bash
# L'image sera automatiquement téléchargée au démarrage
docker-compose up -d
```

### Build local (optionnel)

Si tu préfères builder localement:

1. Édite `.devcontainer/docker-compose.yml`
2. Commente la ligne `image:`
3. Décommente la section `build:`

```yaml
# image: ghcr.io/kodflow/devcontainer:latest

build:
  context: .
  dockerfile: Dockerfile
  args:
    BUILDKIT_INLINE_CACHE: 1
```

## Configuration 1Password

### Setup initial

1. Copie le template:
   ```bash
   cp .devcontainer/.env.example .devcontainer/.env
   ```

2. Récupère ton service account token depuis [1Password Developer Tools](https://my.1password.com/developer-tools/infrastructure-secrets/)

3. Ajoute-le dans `.devcontainer/.env`:
   ```bash
   OP_SERVICE_ACCOUNT_TOKEN="ops_votre_token_ici"
   ```

Le fichier `.env` est git-ignoré et ne sera jamais commité.

## Alias et outils

### Super Claude

L'alias `super-claude` est automatiquement configuré dans le container:

```bash
super-claude
```

Équivalent à:
```bash
claude --dangerously-skip-permissions --mcp /home/vscode/.devcontainer/mcp.json
```

### Outils inclus

- **Languages**: Node.js 22, Go, Python, Ruby, Rust, Java
- **CLI Tools**: AWS CLI, GitHub CLI, 1Password CLI
- **HashiCorp**: Terraform, Vault, Consul, Nomad
- **Build Tools**: Bazelisk, golangci-lint
- **Shell**: Zsh avec Oh My Zsh et Powerlevel10k

## GitHub Actions - Build Multi-Architecture

### Déclenchement automatique

Le workflow build les images Docker quand:
- Tu push sur `main` avec des modifications dans `.devcontainer/`
- Tu modifies le workflow lui-même
- Tu déclenches manuellement via `workflow_dispatch`

### Images publiées

Les images sont disponibles sur GitHub Container Registry:

```bash
docker pull ghcr.io/kodflow/devcontainer:latest
docker pull ghcr.io/kodflow/devcontainer:main
docker pull ghcr.io/kodflow/devcontainer:main-<commit-sha>
```

### Architectures supportées

- **linux/amd64** - Intel/AMD processors
- **linux/arm64** - Apple Silicon (M1/M2/M3)

## Volumes persistants

Les données suivantes survivent aux rebuilds:

- `~/.zsh_history_dir` - Historique du shell
- `~/.cache` - Cache des package managers
- `~/.config` - Configurations
- `~/.local/bin` - Binaires locaux
- `~/.claude` - Configuration Claude CLI
- `~/.config/@anthropic` - Config Anthropic
- `~/.cache/@anthropic` - Cache Anthropic
- `~/.local/share/@anthropic` - Données Anthropic
- `~/.config/op` - Configuration 1Password
- `~/.op` - Cache 1Password

## Utilisation comme template

Ce repository peut servir de base pour d'autres projets:

1. **Utilise ce repo comme template** sur GitHub
2. **Les builds s'activeront automatiquement** quand tu modifieras `.devcontainer/`
3. **Les images seront publiées** sur ton propre GHCR

Le workflow est conçu pour ne builder que si nécessaire grâce aux filtres `paths`.

## Sécurité

### Actions GitHub

Toutes les actions GitHub sont pinées à leur commit SHA complet:

- ✅ Protection contre les supply chain attacks
- ✅ Immutabilité garantie
- ✅ Conformité Codacy/Semgrep

### 1Password

- Les tokens ne sont jamais commités (`.env` dans `.gitignore`)
- Permissions strictes sur `~/.config/op` (700)
- Service account tokens uniquement (pas de personal tokens)

## Troubleshooting

### L'image ne se télécharge pas

```bash
# Authentifie-toi sur GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Puis pull manuellement
docker pull ghcr.io/kodflow/devcontainer:latest
```

### Rebuild complet

```bash
# Arrête et supprime tout
docker-compose down -v

# Rebuild from scratch
docker-compose build --no-cache
docker-compose up -d
```

### Vérifier les logs du workflow

```bash
# Via gh CLI
gh run list --limit 5
gh run view <run-id> --log

# Ou sur GitHub
# https://github.com/kodflow/.repository/actions
```

## Structure du repository

```
.
├── .devcontainer/
│   ├── .env.example          # Template pour variables d'environnement
│   ├── Dockerfile            # Image Docker multi-stage
│   ├── docker-compose.yml    # Configuration des services
│   ├── devcontainer.json     # Config VS Code DevContainer
│   ├── mcp.json.tpl          # Template MCP pour Claude
│   ├── p10k.sh               # Config Powerlevel10k
│   └── README.md             # Cette documentation
├── .github/
│   └── workflows/
│       └── docker-build.yml  # Workflow de build multi-arch
└── .gitignore                # Fichiers ignorés par git
```

## Contribuer

1. Fork le repository
2. Crée une branche feature
3. Commit tes changements
4. Push et ouvre une PR

Les builds se déclencheront automatiquement sur ta PR.
