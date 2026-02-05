# Architecture Overview

## System Context

```
Developer IDE (VS Code Dev Containers)
        ↓
.devcontainer/docker-compose.yml → devcontainer service
        ↓
Base image (.devcontainer/images/Dockerfile)
        ↓
Lifecycle hooks + features → Tools (Claude CLI, cloud CLIs)
        ↓
MCP servers (github, codacy, taskwarrior) via /workspace/mcp.json
```

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| DevContainer config | `.devcontainer/devcontainer.json` | Main entry point for VS Code |
| Docker Compose | `.devcontainer/docker-compose.yml` | Service definition, volumes |
| Base image | `.devcontainer/images/Dockerfile` | Ubuntu + core tooling |
| Lifecycle hooks | `.devcontainer/hooks/lifecycle/` | Startup automation |
| Language features | `.devcontainer/features/languages/` | Per-language installers |
| MCP template | `.devcontainer/images/mcp.json.tpl` | Server configuration |

## Data Flow

1. **Container creation** - VS Code reads `devcontainer.json`, builds/runs service
2. **onCreate** - Provisions caches, injects CLAUDE.md, sets safe directories
3. **postCreate** - Wires language managers (NVM, pyenv), creates aliases
4. **postStart** - Restores Claude, injects secrets into `mcp.json`, validates setup

## Technology Stack

- **Base**: `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`
- **Cloud CLIs**: AWS v2, GCP SDK, Azure CLI
- **IaC**: Terraform, Vault, Consul, Nomad, Packer
- **Container**: kubectl, Helm, Docker Compose
- **Languages**: Managed via devcontainer features (NVM, pyenv, rustup, etc.)

## External Dependencies

| Service | Tool | Purpose |
|---------|------|---------|
| GitHub | `@modelcontextprotocol/server-github` | PR automation |
| Codacy | `@codacy/codacy-mcp` | Security/lint analysis |
| Taskwarrior | `mcp-server-taskwarrior` | Task tracking |

## Volumes

```yaml
volumes:
  package-cache:    # npm, pip, cargo caches
  npm-global:       # Global npm packages
  claude-data:      # Claude CLI state
  op-config:        # 1Password config
```

See `.devcontainer/docker-compose.yml` for full configuration.
