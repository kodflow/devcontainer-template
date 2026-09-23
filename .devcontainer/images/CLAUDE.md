<!-- updated: 2026-04-24T10:50:00Z -->
# DevContainer Images

## Purpose

Two-tier Docker images with all development tools pre-installed.
Claude Code and MCP servers are included; languages added via features.

**Base image** (`Dockerfile.base`): Stable deps (apt, Cloud CLIs) — rebuilt weekly.
**Main image** (`Dockerfile`): Dynamic tools (Claude, rtk) — rebuilt daily.

## Structure

```text
.devcontainer/images/
├── Dockerfile.base     # Stable layer (~1.1GB, weekly rebuild)
├── Dockerfile          # Dynamic layer (~120MB, daily rebuild)
├── .dockerignore       # Build context exclusions
├── mcp.json.tpl        # MCP server template
├── rtk.config.toml     # RTK PreToolUse rewrite config
├── .p10k.zsh           # Powerlevel10k config
├── scripts/vpn/        # VPN helper scripts
├── hooks/              # Image-embedded lifecycle hooks
│   ├── shared/utils.sh # Shared utilities
│   └── lifecycle/      # onCreate, postCreate, postStart, etc.
└── .claude/            # Claude Code configuration
    ├── scripts/        # Quality scripts (7: common, format, lint, test,
    │                   # typecheck, pre-commit-checks, pre-commit-quality)
    ├── docs/           # Design Patterns Knowledge Base (170+ patterns)
    ├── templates/      # Project/docs/terraform templates
    └── settings.json   # Claude settings (permissions, env, statusLine — no hooks)
```

Skills, agents and lifecycle hooks no longer ship here — they come from the
public [kodflow marketplace](https://github.com/kodflow/claude-marketplace)
(6 plugins: `kodflow-workflow`, `kodflow-review`, `kodflow-devops`,
`kodflow-shell`, `kodflow-specialists`, `kodflow-hooks`), installed/updated at every container
start by `postStart.sh` (`step_marketplace_install`, fail-open when offline —
warning, cached plugins keep working). Same install for a workstation via
`.devcontainer/install.sh` (`install_marketplace`) and the
`.devcontainer/features/claude/install.sh` feature. Codex gets the same
skills/agents via the marketplace's `scripts/install.sh --codex`.

## Container Paths (Runtime)

| Source (Build) | Container Path | Backup Location |
|----------------|----------------|-----------------|
| `.claude/` | `~/.claude/` | `/etc/claude-defaults/` |
| `.claude/scripts/` | `~/.claude/scripts/` | `/etc/claude-defaults/scripts/` |
| `.claude/docs/` | `~/.claude/docs/` | `/etc/claude-defaults/docs/` |
| `mcp.json.tpl` | `/etc/mcp/mcp.json.tpl` | - |
| `hooks/` | `/etc/devcontainer-hooks/` | - |
| `features/` (CI-staged) | `/etc/devcontainer-template/features/` | 3-way safe-synced to `.devcontainer/features/` |
| `image-template-files.json` (CI-built) | `/etc/devcontainer-template/.template-files.json` | sha256 manifest powering the 3-way sync |

**Note:** `scripts/`, `docs/`, `templates/`, `settings.json` and `.claude.json` restored from
`/etc/claude-defaults/` at each start via `postStart.sh` (`step_restore_claude_config`), which
also removes any leftover `commands/`, `agents/`, `workflows/` from older images so nothing runs
beside its marketplace-plugin twin.
Lifecycle hooks called directly from `devcontainer.json` → `/etc/devcontainer-hooks/` (no stubs).
`.devcontainer/features/` is **3-way merged** from `/etc/devcontainer-template/features/` at every
`postStart` (step `step_sync_features`, helper `shared/sync-features.sh`). Per-file protection
(issue #334 + #367):

1. byte-identical → noop;
2. tracked + git-dirty → preserved (`[WARNING]`);
3. previous shipped sha256 (from `.template-files.json::files`) matches current dst → safe overwrite;
4. dst hash appears in `.template-files.json::previous_hashes[rel]` → fast-forward, silent overwrite (stale-but-clean);
5. otherwise → preserved with an improved `[WARNING]` pointing at `git diff` (real consumer fork).

`--delete` only removes dst files whose sha256 still matches the previous manifest entry, so
consumer-added files are never deleted.

Manifest schema v2 (CI-built by `build-features-manifest.py`, see `scripts/`): adds an optional
`previous_hashes[rel] = [sha256, …]` list capped at 8 generations. The CI workflow
(`docker-images.yml`) fetches the previous image's manifest via `docker pull + docker cp` and
passes it as `--prev-manifest` to the builder; failure is non-fatal (one-build degradation,
self-healing).

Template repo self-skip: see `step_sync_features` in `postStart.sh` — primary path matches
`origin` URL against `kodflow/devcontainer-template` (#367); legacy `.template-version`
marker-file path stays as secondary opt-in.

### Local script overrides (`*.local.sh`)

Mirror of the `devcontainer.local.json` pattern, scoped to `~/.claude/scripts/`. To customise a
hook script without forking the upstream copy, drop a `<name>.local.sh` next to it:

| Upstream | Override seam |
|----------|---------------|
| `~/.claude/scripts/pre-commit-quality.sh` | `~/.claude/scripts/pre-commit-quality.local.sh` |
| `~/.claude/scripts/pre-commit-checks.sh` | `~/.claude/scripts/pre-commit-checks.local.sh` |
| `~/.claude/scripts/test.sh` | `~/.claude/scripts/test.local.sh` |

The upstream script sources its `.local.sh` companion **after** every upstream function is
defined and immediately before the entrypoint, so `.local.sh` can redefine any function (shell
uses last-definition-wins). `/update` and `safe_glob_copy` skip every `*.local.sh` file, so the
override survives template syncs. Issue ref: kodflow/devcontainer-template#352.

Example (`~/.claude/scripts/pre-commit-quality.local.sh`):

```bash
# Force Bazel for this project; can be deleted once #350 lands.
run_test() {
    local out="$1"
    (cd "$PROJECT_ROOT" && bazel test --test_output=errors //...) >> "$out" 2>&1 || return 1
}
```

## Design Patterns Knowledge Base

**Container Location:** `~/.claude/docs/` (restored at startup)

170+ pattern files across 19 categories, consulted by `/plan` and `/review`.

| Category | Files | Examples |
|----------|-------|----------|
| GoF (25 files) | creational, structural, behavioral | Factory, Observer, Strategy |
| Architectural (9) | architectural/ | MVC, Hexagonal, CQRS |
| Cloud + Resilience (27) | cloud/, resilience/ | Circuit Breaker, Saga, Retry |
| Concurrency (8) | concurrency/ | Thread Pool, Actor, Mutex |
| DDD (8) | ddd/ | Aggregate, Repository, Entity |
| DevOps (14) | devops/ | Feature Toggles, Blue-Green |
| Enterprise (12) | enterprise/ | PoEAA (Martin Fowler) |
| Functional (5) | functional/ | Monad, Either, Lens |
| Integration + Messaging (15) | integration/, messaging/ | API Gateway, EIP |
| Performance (8) | performance/ | Cache, Lazy Load, Pool |
| Principles (7) | principles/, conventions/ | SOLID, DRY, KISS |
| Security (8) | security/ | OAuth, JWT, RBAC |
| Testing (8) | testing/ | Mock, Stub, Fixture |

**Agent usage:** See `.claude/docs/CLAUDE.md`

## Installed Tools

| Category | Tools |
|----------|-------|
| Cloud CLIs | AWS, GCP, Azure, 1Password |
| IaC | Terraform, Vault, Consul, Nomad, Packer, Ansible |
| Container | Docker (via feature), kubectl, Helm |
| Network | ping, dig, nmap, traceroute, mtr, tcpdump, netcat, whois, iperf3, net-tools |
| VPN | OpenVPN, WireGuard, StrongSwan (IPsec), PPTP |
| Code Quality | ShellCheck, CodeRabbit, Qodo, RTK |
| Shell | Zsh (default `$SHELL`) + Oh My Zsh + Powerlevel10k |

## Shell Startup Optimization (v3)

`~/.devcontainer-env.sh` uses a three-pillar architecture for fast shell startup:

| Pillar | Mechanism | Effect |
|--------|-----------|--------|
| Lazy wrappers | `nvm`, `pyenv`, `rbenv`, `sdk` load on first use | ~1.4s saved |
| Cached completions | `~/.zsh_completions/` via fpath (pre-generated by postStart) | ~750ms saved |
| Dynamic p10k segments | `~/.p10k-segments.zsh` based on installed tools | ~70ms saved |

**Phase 1** (always): PATH, env vars, fpath — no subprocesses.
**Phase 2** (terminal only): lazy wrappers, aliases, fast `complete -C` for HashiCorp/AWS.

Tool binaries (`node`, `python`, `ruby`, `java`) work immediately via Phase 1 PATH/shims.
Management commands (`nvm use`, `pyenv install`) trigger lazy-load on first call.

## MCP Servers (Runtime)

Core servers in `mcp.json.tpl` (GitHub, GitLab). Additional servers added via MCP fragments:
- Image-level fragments (`/etc/mcp/fragments/`): context7 — always merged
- Feature-level fragments (`/etc/mcp/features/`): ktn-linter (Go), Playwright (browser), rust-analyzer, etc.

| Server | Package | Type | Auth |
|--------|---------|------|------|
| **GitHub** | `ghcr.io/github/github-mcp-server` (Docker) | Core (template) | `GITHUB_TOKEN` |
| **GitLab** | `@zereight/mcp-gitlab` | Core (template) | `GITLAB_TOKEN` |
| **context7** | `@upstash/context7-mcp` | Fragment (image) | None |
| **ktn-linter** | `ktn-linter` (binary) | Fragment (Go feature) | None |
| **Playwright** | `@playwright/mcp` | Fragment (browser feature) | None |

**Removed in 2026-04:** `grepai` MCP server (semantic search via Ollama embeddings)
— high CPU/RAM cost for marginal benefit. Use `Grep`/`Read` for searches and
`mcp__context7__*` for library documentation.

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

**Playwright capabilities** (when browser feature enabled): `core`, `pdf`, `testing`, `tracing` (headless mode)

## Skills (kodflow marketplace)

Skills come from the marketplace, not from a commands/ directory in the image. Per plugin:

| Plugin | Skills |
|--------|--------|
| `kodflow-workflow` | `/challenge`, `/feature`, `/fix`, `/git`, `/plan`, `/project`, `/refine`, `/search`, `/warmup` |
| `kodflow-review` | `/adr`, `/comment`, `/debug`, `/learn`, `/lint`, `/review` |
| `kodflow-devops` | `/audit`, `/infra`, `/ktn`, `/update` |
| `kodflow-specialists` | 29 language/OS/devops agents (no skills) |
| `kodflow-hooks` | lifecycle hooks only (no skills) |

Skills that existed only in this template and are gone (superseded by the skills above, or
out of scope for a public plugin): `/init`, `/test`, `/review-doctor`, `/feature` RTM mode,
`/secret`, `/vpn`.

## Hooks (5 scripts, 15 events — kodflow-hooks plugin)

One script per event, each a fixed sequence — gate → block → transform → observe — because
hooks on the same event run in parallel and only one script can order them:

| Script | Events |
|--------|--------|
| `on-tool.sh` | PreToolUse, PostToolUse, PostToolUseFailure |
| `on-session.sh` | SessionStart, SessionEnd, PreCompact, ConfigChange |
| `on-user.sh` | UserPromptSubmit, Notification |
| `on-agent.sh` | SubagentStart, SubagentStop, TaskCreated, TaskCompleted, TeammateIdle |
| `on-stop.sh` | Stop |

Plus `lib/event.jq` (one log sanitization policy) and `lib/format.sh` (formatter table).
`on-tool.sh` carries the git guard (no `--no-verify`, no AI attribution, no `.claude/` path in
messages, staged-secret scan, `--force` → `--force-with-lease`), the rtk rewrite (fidelity guard
for cat/head/tail/sed/diff/patch, `NO_RTK=` opt-out, normal permission flow — no auto-approve),
protected paths (`.claude/protected-paths`, one glob per line), the edit tracker and the
formatter. `on-stop.sh` carries the project-linter gate and the reminder to update the CLAUDE.md
of every directory changed this session (once per directory). `settings.json` in the image no
longer has a hooks block. Log: `.claude/logs/<branch>/session.jsonl` (gitignored).

**ktn-linter integration (inside `on-tool.sh` / `on-stop.sh`):**

| Hook | Endpoint | Phase scope (default) | Env override | Purpose |
|------|----------|-----------------------|--------------|---------|
| `on-tool.sh` PreToolUse (Write/Edit) | `/hooks/pre-tool-use` | `structural,signatures` | `KTN_PRE_PHASES` | Pre-edit fast check — only naming/signature breaks block before the edit |
| `on-stop.sh` Stop | `/hooks/stop` | `structural,signatures,logic,performance,modern,style,comment,tests` | `KTN_STOP_PHASES` | Session-end report — runs on the Go packages edited this session (tracker), never on a git diff |

Called only when `http://127.0.0.1:$KTN_LINTER_PORT` answers (bash `/dev/tcp` probe; nothing is
called otherwise). A Stop `decision:block` verdict passes through verbatim; otherwise the report
joins the single Stop feedback document. See [docs/ktn-linter-integration.md](/workspace/docs/ktn-linter-integration.md).

**Per-edit lint (PostToolUse) — project-level recipe.** `on-tool.sh` deliberately does NOT curl `/hooks/post-tool-use`: Claude Code keeps only the *last* JSON emitted by a hook chain, so a script-level call would race with the native HTTP hook and silently drop `decision: "block"` payloads (issue #344). Consumers needing per-edit lint wire the HTTP hook directly in their project's `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "http",
            "url": "http://localhost:7717/hooks/post-tool-use",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

The native hook speaks the Claude Code hook payload protocol directly (decision + hookSpecificOutput) — no re-parse, no re-wrap, no payload mangling.

**Makefile-first pattern:** Scripts check `make fmt/lint/typecheck/test FILE=<path>` first, then fall back to direct tool invocation.

## Build

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/kodflow/devcontainer-template:latest .
```
