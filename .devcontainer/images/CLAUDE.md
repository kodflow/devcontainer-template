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
    └── settings.json   # Claude settings
```

## Installed Tools

| Category | Tools |
|----------|-------|
| Cloud CLIs | AWS, GCP, Azure, 1Password |
| IaC | Terraform, Vault, Consul, Nomad, Packer, Ansible |
| Container | Docker (via feature), kubectl, Helm |
| Code Quality | ShellCheck, ktn-linter |
| Shell | Zsh + Oh My Zsh + Powerlevel10k |

## MCP Servers (Runtime)

Configured in `mcp.json.tpl`, tokens injected at startup:

- **GitHub** - PR/Issue management
- **Codacy** - Code quality analysis

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
