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
Claude Code + MCP servers (github, gitlab, context7 + feature fragments)
        |
kodflow marketplace plugins (skills, agents, hooks — installed by postStart)
        |
Specialist agents (29 — kodflow-specialists plugin)
```

## Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| DevContainer config | `.devcontainer/devcontainer.json` | VS Code entry point |
| Docker Compose | `.devcontainer/docker-compose.yml` | Service definition, volumes |
| Base image (stable) | `.devcontainer/images/Dockerfile.base` | System deps, Cloud CLIs (weekly) |
| Main image (dynamic) | `.devcontainer/images/Dockerfile` | Claude, tools (daily) |
| Lifecycle hooks | `/etc/devcontainer-hooks/lifecycle/` | Startup automation (image-embedded) |
| Language features | `.devcontainer/features/languages/` | Per-language installers |
| Specialist agents | `kodflow-specialists` (marketplace plugin) | 29 AI agent definitions |
| Skills (slash commands) | `kodflow-workflow` / `kodflow-review` / `kodflow-devops` (marketplace plugins) | Workflow entry points |
| Hooks | `kodflow-hooks` (marketplace plugin) | 15 events, 5 scripts — no `hooks` block in image `settings.json` |
| MCP template | `.devcontainer/images/mcp.json.tpl` | Server configuration |

## Data Flow

1. **Container creation** — VS Code reads `devcontainer.json`, builds and runs service
2. **onCreate** — Provisions caches, injects CLAUDE.md, sets safe directories
3. **postCreate** — Wires language managers (NVM, pyenv, rustup), creates aliases
4. **postStart** — Registers the kodflow marketplace and installs/updates its 6 plugins (fail-open if offline), restores Claude, injects secrets into `mcp.json`, validates setup
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
- **AI**: Claude Code, MCP servers, RTK token-savings hook (PreToolUse rewrite)

## External Dependencies

| Service | Tool | Purpose |
|---------|------|---------|
| GitHub | `ghcr.io/github/github-mcp-server` | PR automation, code search |
| GitLab | `@zereight/mcp-gitlab` | MR automation, pipelines |
| context7 | `@upstash/context7-mcp` | Official library documentation (image fragment) |
| Playwright | `@playwright/mcp` | Browser automation, E2E testing (browser feature) |
| ktn-linter | Local MCP | Code linting — MCP server + hook provider (Go feature fragment) |

### ktn-linter Integration Model

ktn-linter has a dual role: **MCP server** (linting tools) and **hook provider** (PreToolUse/Stop; no PostToolUse call).

- **Template responsibility**: installs binary, registers MCP fragment (`requires_binary` gate)
- **ktn-linter responsibility**: HTTP server with lint logic, ScanReport formatting, severity ordering
- **Integration**: calls are embedded in the `kodflow-hooks` marketplace plugin's `on-tool.sh` (PreToolUse) and `on-stop.sh` (Stop) — no wrapper scripts in the template; graceful degradation if ktn-linter isn't running

See [ktn-linter-integration.md](ktn-linter-integration.md) for the full contract.

## Volumes

```yaml
volumes:
  package-cache:    # npm, pip, cargo caches
  npm-global:       # Global npm packages
  claude-data:      # Claude CLI state
  op-config:        # 1Password config
```

See `.devcontainer/docker-compose.yml` for full configuration.
