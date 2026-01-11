# DevContainer Images

## Purpose

Docker base image with all development tools pre-installed.
Claude Code and MCP servers are included; languages added via features.

## Structure

```text
.devcontainer/images/
├── Dockerfile          # Base image definition
├── docker-compose.yml  # Service composition
├── mcp.json.tpl        # MCP server template
├── .p10k.zsh           # Powerlevel10k config
└── .claude/            # Claude Code configuration
    ├── commands/       # Slash commands (/git, /review, etc.)
    ├── scripts/        # Hook scripts
    ├── agents/         # Agent definitions
    ├── docs/           # Design Patterns Knowledge Base (250+ patterns)
    └── settings.json   # Claude settings
```

## Design Patterns Knowledge Base

**Location:** `.claude/docs/`

Base de connaissances exhaustive de 250+ design patterns, consultée automatiquement par les skills `/plan` et `/review`.

| Category | Patterns | Examples |
|----------|----------|----------|
| GoF (23) | creational, structural, behavioral | Factory, Observer, Strategy |
| Performance (12) | performance/ | Object Pool, Cache, Lazy Load |
| Concurrency (15) | concurrency/ | Thread Pool, Actor, Mutex |
| Enterprise (40+) | enterprise/ | PoEAA (Martin Fowler) |
| Messaging (31) | messaging/ | EIP patterns |
| DDD (14) | ddd/ | Aggregate, Repository, Entity |
| Functional (15) | functional/ | Monad, Either, Lens |
| Security (12) | security/ | OAuth, JWT, RBAC |
| Testing (15) | testing/ | Mock, Stub, Fixture |

**Usage par les agents :** Voir `.claude/docs/CLAUDE.md`

## Installed Tools

| Category | Tools |
|----------|-------|
| Cloud CLIs | AWS, GCP, Azure, 1Password |
| IaC | Terraform, Vault, Consul, Nomad, Packer, Ansible |
| Container | Docker (via feature), kubectl, Helm |
| Code Quality | ShellCheck, ktn-linter |
| Shell | Zsh + Oh My Zsh + Powerlevel10k |

## MCP Servers (Runtime)

Configured in `mcp.json.tpl`:

| Server | Package | Usage | Auth |
|--------|---------|-------|------|
| **GitHub** | `@modelcontextprotocol/server-github` | PR, Issues, Repos | `GITHUB_TOKEN` |
| **Codacy** | `@codacy/codacy-mcp` | Code quality, Security | `CODACY_TOKEN` |
| **Playwright** | `@playwright/mcp` | Browser automation, E2E tests | None |

**Playwright capabilities:** `core`, `pdf`, `testing`, `tracing` (headless mode)

## Hooks

| Hook | Trigger | Action |
|------|---------|--------|
| `commit-validate.sh` | PreToolUse (Bash) | Validate git commits |
| `pre-validate.sh` | PreToolUse (Write/Edit) | Protect sensitive files |
| `post-edit.sh` | PostToolUse (Write/Edit) | Format + Lint |
| `security.sh` | PostToolUse (Write/Edit) | Secret detection |
| `test.sh` | PostToolUse (Write/Edit) | Run related tests |

## Build

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/kodflow/devcontainer-template:latest .
```
