<!-- updated: 2026-02-11T07:30:19Z -->
# DevContainer Images

## Purpose

Docker base image with all development tools pre-installed.
Claude Code and MCP servers are included; languages added via features.

## Structure

```text
.devcontainer/images/
├── Dockerfile          # Base image (~15 layers, consolidated)
├── .dockerignore       # Build context exclusions
├── mcp.json.tpl        # MCP server template
├── grepai.config.yaml  # GrepAI search config (12 languages)
├── .p10k.zsh           # Powerlevel10k config
├── scripts/vpn/        # VPN helper scripts
└── .claude/            # Claude Code configuration
    ├── commands/       # Slash commands (16 skills)
    ├── scripts/        # Hook scripts (15 scripts)
    ├── agents/         # Agent definitions (57 agents)
    ├── docs/           # Design Patterns Knowledge Base (250+ patterns)
    ├── templates/      # Project/docs/terraform templates
    └── settings.json   # Claude settings
```

## Container Paths (Runtime)

| Source (Build) | Container Path | Backup Location |
|----------------|----------------|-----------------|
| `.claude/` | `/home/vscode/.claude/` | `/etc/claude-defaults/` |
| `.claude/commands/` | `~/.claude/commands/` | `/etc/claude-defaults/commands/` |
| `.claude/scripts/` | `~/.claude/scripts/` | `/etc/claude-defaults/scripts/` |
| `.claude/agents/` | `~/.claude/agents/` | `/etc/claude-defaults/agents/` |
| `.claude/docs/` | `~/.claude/docs/` | `/etc/claude-defaults/docs/` |
| `mcp.json.tpl` | `/etc/mcp/mcp.json.tpl` | - |

**Note:** Files are restored from `/etc/claude-defaults/` at each container start via `postStart.sh`.

## Design Patterns Knowledge Base

**Container Location:** `~/.claude/docs/` (restored at startup)

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
| Network | ping, dig, nmap, traceroute, mtr, tcpdump, netcat, whois, iperf3, net-tools |
| VPN | OpenVPN, WireGuard, StrongSwan (IPsec), PPTP |
| Code Quality | ShellCheck, ktn-linter, grepai |
| Shell | Zsh + Oh My Zsh + Powerlevel10k |

## MCP Servers (Runtime)

Configured in `mcp.json.tpl`:

| Server | Package | Usage | Auth |
|--------|---------|-------|------|
| **grepai** | `grepai` (binary) | Semantic code search, Call graph | None (local) |
| **context7** | `@upstash/context7-mcp` | Up-to-date documentation for prompts | None (rate-limited) |
| **GitHub** | `ghcr.io/github/github-mcp-server` (Docker) | PR, Issues, Repos | `GITHUB_TOKEN` |
| **GitLab** | `@zereight/mcp-gitlab` | MR, Issues, Pipelines, Wiki | `GITLAB_TOKEN` |
| **Codacy** | `@codacy/codacy-mcp` | Code quality, Security | `CODACY_TOKEN` |
| **Playwright** | `@playwright/mcp` | Browser automation, E2E tests | None |

**grepai tools (MANDATORY - use instead of Grep):**

| Tool | Description | Use Case |
|------|-------------|----------|
| `grepai_search` | Semantic code search | Natural language queries |
| `grepai_trace_callers` | Find function callers | Impact analysis |
| `grepai_trace_callees` | Find called functions | Dependency analysis |
| `grepai_trace_graph` | Build call graph | Architecture understanding |
| `grepai_index_status` | Check index health | Debugging |

**GitLab tools (when GITLAB_TOKEN configured):**

| Tool | Description | Use Case |
|------|-------------|----------|
| `gitlab_list_projects` | List accessible projects | Project discovery |
| `gitlab_get_project` | Get project details | Project info |
| `gitlab_list_merge_requests` | List MRs | Code review |
| `gitlab_get_merge_request` | Get MR details | Review analysis |
| `gitlab_list_issues` | List project issues | Issue tracking |
| `gitlab_list_pipelines` | List CI pipelines | CI/CD status |

**GitLab env vars:** `GITLAB_TOKEN`, `GITLAB_API_URL` (default: gitlab.com)

**Context7 usage:** Add "use context7" in prompts to fetch up-to-date documentation.

**Playwright capabilities:** `core`, `pdf`, `testing`, `tracing` (headless mode)

## Skills (Slash Commands)

| Skill | Description |
|-------|-------------|
| `/init` | Project initialization check |
| `/plan` | Planning mode for implementation strategy |
| `/do` | Iterative task execution loop (RLM) |
| `/review` | AI-powered code review (RLM decomposition) |
| `/git` | Workflow Git automation (commit, push, PR, merge) |
| `/search` | Documentation research with official sources |
| `/docs` | Deep project documentation generation (multi-agent) |
| `/test` | E2E testing with Playwright MCP |
| `/lint` | Intelligent linting with ktn-linter (148 rules) |
| `/infra` | Infrastructure automation (Terraform/Terragrunt) |
| `/secret` | Secure secret management (1Password + Vault-like paths) |
| `/vpn` | Multi-protocol VPN management (OpenVPN, WireGuard, IPsec, PPTP) |
| `/warmup` | Context pre-loading and CLAUDE.md update |
| `/update` | DevContainer update from template |
| `/improve` | Continuous docs enhancement & anti-pattern detection |
| `/prompt` | Generate ideal prompt structure for /plan |

## Hooks

| Hook | Trigger | Action |
|------|---------|--------|
| `commit-validate.sh` | PreToolUse (Bash) | Block AI mentions in commits |
| `security.sh` | PreToolUse (Bash) + PostToolUse (Write/Edit) | Secret detection on commit + edit |
| `pre-validate.sh` | PreToolUse (Write/Edit) | Protect sensitive files |
| `post-edit.sh` | PostToolUse (Write/Edit) | Format + Lint + Typecheck |
| `test.sh` | PostToolUse (Write/Edit) | Run related tests |
| `session-init.sh` | SessionStart (all) | Cache git metadata as env vars |
| `post-compact.sh` | SessionStart (compact) | Restore RLM context rules |
| `on-stop.sh` | Stop (*) | Terminal bell + session summary |
| `notification.sh` | Notification (*) | Terminal bell + notification log

**Makefile-first pattern:** All scripts (format, lint, typecheck, test) check for Makefile targets first:
- `make fmt FILE=<path>` or `make format FILE=<path>`
- `make lint FILE=<path>`
- `make typecheck FILE=<path>`
- `make test FILE=<path>`

Falls back to direct tool invocation (prettier, eslint, ruff, etc.) if no Makefile target exists.

## Build

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/kodflow/devcontainer-template:latest .
```
