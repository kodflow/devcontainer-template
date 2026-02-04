# DevContainer Images

## Purpose

Docker base image with development tools. Claude Code + MCP servers included.

## Structure

```text
.devcontainer/images/
├── Dockerfile          # Base image
├── docker-compose.yml  # Services
├── mcp.json.tpl        # MCP config template
└── .claude/            # Claude Code config
    ├── commands/       # Skills (/git, /review, etc.)
    ├── scripts/        # Hook scripts
    ├── agents/         # Agent definitions
    └── docs/           # 300+ Design Patterns
```

## Container Paths

| Source | Container | Backup |
|--------|-----------|--------|
| `.claude/` | `~/.claude/` | `/etc/claude-defaults/` |
| `mcp.json.tpl` | `/etc/mcp/mcp.json.tpl` | - |

**Note:** Files restored from backup at container start via `postStart.sh`.

## Installed Tools

| Category | Tools |
|----------|-------|
| Cloud | AWS, GCP, Azure, 1Password |
| IaC | Terraform, Vault, Consul, Ansible |
| Container | kubectl, Helm |
| Quality | ShellCheck, ktn-linter, grepai |

## MCP Servers

| Server | Usage | Auth |
|--------|-------|------|
| grepai | Semantic search, call graphs | None |
| context7 | Library documentation | None |
| GitHub | PR, Issues, Repos | `GITHUB_TOKEN` |
| GitLab | MR, Issues, Pipelines | `GITLAB_TOKEN` |
| Codacy | Code quality | `CODACY_TOKEN` |
| Playwright | Browser automation | None |

**grepai tools:** `grepai_search`, `grepai_trace_callers`, `grepai_trace_callees`, `grepai_trace_graph`

## Skills

| Skill | Description |
|-------|-------------|
| `/git` | Branch + commit + PR |
| `/plan` | Planning mode |
| `/do` | Iterative execution |
| `/review` | Code review RLM |
| `/improve` | Docs enhancement |
| `/search` | Documentation research |
| `/test` | E2E with Playwright |
| `/infra` | Terraform/Terragrunt |
| `/warmup` | Context pre-loading |

## Hooks

| Hook | Action |
|------|--------|
| `commit-validate.sh` | Block AI mentions |
| `security.sh` | Secret detection |
| `pre-validate.sh` | Protect files |
| `post-edit.sh` | Format + Lint |
| `test.sh` | Run tests |

**Makefile-first:** Hooks use `make fmt/lint/test FILE=<path>` if available.

## Build

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/kodflow/devcontainer-template:latest .
```
