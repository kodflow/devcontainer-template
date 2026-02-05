# Architecture: devcontainer-template

## System Context

```
Developer IDE (VS Code / Codespaces)
        |
.devcontainer/devcontainer.json
        |
docker-compose.yml → devcontainer service
        |
Base image (Ubuntu 24.04 + core tooling)
        |
Lifecycle hooks + language features
        |
Claude Code + MCP servers (github, codacy, context7, grepai, playwright)
        |
Specialist agents (13 language + 5 executor + 8 devops)
```

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| DevContainer config | `.devcontainer/devcontainer.json` | VS Code entry point |
| Docker Compose | `.devcontainer/docker-compose.yml` | Service definition, volumes |
| Base image | `.devcontainer/images/Dockerfile` | Ubuntu + core tooling |
| Lifecycle hooks | `.devcontainer/hooks/lifecycle/` | Startup automation |
| Language features | `.devcontainer/features/languages/` | Per-language installers |
| Specialist agents | `.devcontainer/images/.claude/agents/` | AI agent definitions |
| Slash commands | `.claude/commands/` | Workflow entry points |
| MCP template | `.devcontainer/images/mcp.json.tpl` | Server configuration |

## Data Flow

1. **Container creation** — VS Code reads `devcontainer.json`, builds and runs service
2. **onCreate** — Provisions caches, injects CLAUDE.md, sets safe directories
3. **postCreate** — Wires language managers (NVM, pyenv, rustup), creates aliases
4. **postStart** — Restores Claude, injects secrets into `mcp.json`, validates setup
5. **Development** — User invokes slash commands → orchestrators → specialists → output

## Agent Architecture

```
User intent (slash command)
        |
   Orchestrator (developer/devops)
        |
   RLM Decomposition: Peek → Decompose → Parallelize → Synthesize
        |
   Specialist agents (language/infra/security)
        |
   Executor agents (correctness/security/design/quality/shell)
        |
   Validated output (code, review, plan)
```

## Technology Stack

- **Base**: `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`
- **Cloud CLIs**: AWS v2, GCP SDK, Azure CLI
- **IaC**: Terraform, Vault, Consul, Nomad, Packer, Ansible
- **Containers**: kubectl, Helm, Docker Compose
- **Languages**: Managed via devcontainer features (NVM, pyenv, rustup, etc.)
- **AI**: Claude Code, MCP servers, grepai semantic search

## External Dependencies

| Service | Tool | Purpose |
|---------|------|---------|
| GitHub | `@modelcontextprotocol/server-github` | PR automation, code search |
| Codacy | `@codacy/codacy-mcp` | Security and lint analysis |
| context7 | `@upstash/context7-mcp` | Official library documentation |
| Playwright | `@playwright/mcp` | Browser automation, E2E testing |
| grepai | Local MCP | Semantic code search, call graphs |

## Volumes

```yaml
volumes:
  package-cache:    # npm, pip, cargo caches
  npm-global:       # Global npm packages
  claude-data:      # Claude CLI state
  op-config:        # 1Password config
```

See `.devcontainer/docker-compose.yml` for full configuration.
