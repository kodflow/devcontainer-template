# Configuration

## Variables d'environnement

Le fichier `.devcontainer/.env` configure le container. Il est créé automatiquement au premier lancement depuis `.devcontainer/.env.tpl`.

### Obligatoires

| Variable | Valeur | Exemple |
|----------|--------|---------|
| `GIT_USER` | Nom pour les commits | `Jean Dupont` |
| `GIT_EMAIL` | Email pour les commits | `jean@example.com` |

Ces valeurs sont lues par `postCreate.sh` pour configurer `git config`.

### Tokens MCP (optionnels)

| Variable | Service | Comment l'obtenir |
|----------|---------|-------------------|
| `GITHUB_TOKEN` | GitHub MCP (PRs, issues) | [Settings → Developer settings → Fine-grained tokens](https://github.com/settings/tokens?type=beta) |
| `GITLAB_TOKEN` | GitLab MCP (MRs, pipelines) | [Preferences → Access Tokens](https://gitlab.com/-/user_settings/personal_access_tokens) |
| `CODACY_TOKEN` | Codacy (analyse qualité) | [Settings → API tokens](https://app.codacy.com/account/api-tokens) |

Sans token, le serveur MCP correspondant ne démarre pas. Les commandes (`/review`, `/git`) utilisent alors les CLI (`gh`, `glab`) en fallback.

### Secrets et VPN (optionnels)

| Variable | Usage |
|----------|-------|
| `OP_SERVICE_ACCOUNT_TOKEN` | Auth 1Password CLI pour `/secret` |
| `VPN_CONFIG_REF` | Référence 1Password au profil VPN (ex: `op://VPN/MonVPN/config`) |
| `OLLAMA_HOST` | Endpoint Ollama (défaut: `host.docker.internal:11434`) |

### Exemple complet

```env
# .devcontainer/.env
GIT_USER=Jean Dupont
GIT_EMAIL=jean@example.com

# Tokens MCP
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
GITLAB_TOKEN=glpat-xxxxxxxxxxxxxxxxxxxx
CODACY_TOKEN=xxxxxxxxxxxxx

# Secrets
OP_SERVICE_ACCOUNT_TOKEN=ops_xxxxxxxxxxxx

# VPN (auto-connect au démarrage)
VPN_CONFIG_REF=op://VPN/Bureau/config
```

## Volumes persistants

8 volumes Docker conservent les données entre les rebuilds du container :

| Volume | Chemin | Ce qui persiste |
|--------|--------|-----------------|
| `package-cache` | `~/.cache` | npm, pip, cargo, maven, gradle, go-build |
| `npm-global` | `~/.local/share/npm-global` | Packages npm globaux |
| `claude-config` | `~/.claude` | Sessions Claude, settings, historique |
| `op-config` | `~/.config/op` | Config 1Password |
| `op-cache` | `~/.op` | Cache 1Password |
| `zsh-history` | `~/.zsh_history_dir` | Historique shell |
| `gnupg` | `~/.gnupg` | Clés GPG (depuis le host) |
| `docker-socket` | `/var/run/docker.sock` | Accès Docker-from-Docker |

!!! warning "Le home n'est pas un volume"
    Seuls ces sous-répertoires persistent. Le reste de `~` est recréé à chaque rebuild depuis l'image. Les fichiers Claude sont restaurés depuis `/etc/claude-defaults/` par `postStart.sh`.

## Activer des features optionnelles

Dans `devcontainer.json`, décommenter les features selon vos besoins :

```jsonc
"features": {
    // Toujours activé (requis pour MCP)
    "ghcr.io/devcontainers/features/node:1": {},

    // Décommenter pour Kubernetes local
    // "ghcr.io/kodflow/devcontainer-template/kubernetes:latest": {
    //     "kindVersion": "0.31.0",
    //     "kubectlVersion": "1.35.0"
    // },

    // Décommenter pour Docker-in-Docker
    // "ghcr.io/devcontainers/features/docker-outside-of-docker:1": {
    //     "moby": false,
    //     "installDockerBuildx": true
    // }
}
```
