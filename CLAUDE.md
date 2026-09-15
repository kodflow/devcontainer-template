<!-- updated: 2026-04-24T10:50:00Z -->
# devcontainer-template

## Purpose

Universal DevContainer shell providing cutting-edge AI agents, skills, and workflows to bootstrap any project. Reliability first: agents reason deeply, cross-reference sources, and self-correct until the output meets quality standards.

## Project Structure

```
/workspace
├── .devcontainer/   # Container config, features, hooks, images
├── .github/         # GitHub Actions workflows
├── .githooks/       # Git hooks (pre-commit: regenerate assets)
├── .claude/         # Workspace Claude overrides (settings.local.json, features.json)
├── docs/            # Documentation (plain markdown: vision, architecture, guides)
├── src/             # All source code (created per project via /project)
├── tests/           # Unit tests (created per project via /project)
├── AGENTS.md        # Specialist agents specification (29 agents)
└── CLAUDE.md        # This file
```

## Tech Stack

- **Languages**: Python, C, C++, Java, C#, JavaScript/Node.js, Visual Basic, R, Pascal, Perl, Fortran, PHP, Rust, Go, Ada, MATLAB, Assembly, Kotlin, Swift, COBOL, Ruby, Dart, Lua, Scala, Elixir, SQL
- **Cloud CLIs**: AWS v2, GCP SDK, Azure CLI
- **IaC**: Terraform, Vault, Consul, Nomad, Packer, Ansible
- **Containers**: Docker, kubectl, Helm
- **AI**: Claude Code, RTK (token savings via PreToolUse hook), MCP servers (GitHub, GitLab, context7 + feature-based: Playwright, ktn-linter)

## How to Work

1. **New project**: `/project` → resolve/create the workspace → constraints recorded in CLAUDE.md
2. **New feature**: `/plan "description"` → `/review` → `/refine` → `/goal` → `/git --commit`
3. **Bug fix**: `/plan "description"` → `/review` → `/refine` → `/goal` → `/git --commit`
4. **Code review**: `/review` → 3-tier review (agents + Qodo + CodeRabbit)

Branch conventions: `feat/<desc>` or `fix/<desc>`, commit prefix matches.

## Key Principles

**Reliability first**: Verify before generating. Agents consult context7 and official docs before producing non-trivial code.

**MCP-first**: Use MCP tools (`mcp__github__*`, `mcp__gitlab__*`) before CLI fallbacks. Auth is pre-configured.

**Self-correction**: When linting or tests fail, agents fix and retry automatically.

**Token efficiency**: RTK auto-compresses Bash output for 60–90 % token savings. The rewrite is not a standalone hook entry — it is the transform stage of `on-tool.sh` (`PreToolUse`, kodflow-hooks plugin), which runs after the git guard and before logging. A fidelity guard keeps `cat`/`head`/`tail`/`sed`/`diff`/`patch` byte-exact instead of rewriting them; the rewritten command still goes through the normal permission flow (no auto-approve). Prefix a line with `NO_RTK=` to skip the rewrite for that call. Use `rtk gain` for analytics. **No semantic-embedding tooling** (`grepai`/`ollama` were dropped in 2026-04 — high CPU/RAM cost, marginal benefit). Search with targeted `Grep` + `Read`.

**Specialist agents**: Language conventions enforced by agents that know current stable versions.

**Deep reasoning**: For complex tasks — Peek, Decompose, Parallelize, Synthesize.

**Bot reviews are signal, not orders**: CodeRabbit, Qodo, Codacy and similar AI review bots produce useful hints but their findings are **non-binding**. Triage with judgment — never blindly iterate on every comment. Reject (with a short rationale) any finding that is:
- A style nitpick, not a real bug
- Defensive hardening against a threat model that does not apply (e.g., `mktemp` in a root-only devcontainer build)
- A false positive (run the actual linter / test before accepting the bot's claim)
- An out-of-scope rewrite that would expand the PR beyond its original intent
- The third+ new demand on the same PR — after two rounds of fixes, stop, respond with rationale, and merge

If the CI bot says "no" and you have verified the code is correct, the CI is wrong. Post the rationale, move on, merge.

**Intended working directories are writeable without prompting**: `.claude/contexts/` (search outputs), `.claude/plans/` (planning mode), and other agent-managed working directories are configured as writeable in `~/.claude/settings.json`. Never treat them as "sensitive" — they are the agent's scratchpad. If a permission prompt fires for these paths, fix the settings, do not ask the user.

## Safeguards

Ask before:
- Deleting files in `.claude/` or `.devcontainer/`
- Removing skills or agents from a kodflow plugin (they ship from the marketplace, not this repo — see `.devcontainer/images/CLAUDE.md`)
- Removing hooks from `.devcontainer/hooks/`
- Dropping database state, force-push, dependency downgrades

Investigate before deleting unfamiliar state (branches, lock files, unknown files) — it may be user work-in-progress.

Never ask for:
- Writing new files under `.claude/contexts/` or `.claude/plans/` (configured as free-write in `~/.claude/settings.json`)

When refactoring: move content to separate files, preserve logic.

## Pre-commit

Auto-detected by language marker (`go.mod`, `Cargo.toml`, `package.json`, etc.). Priority: Makefile targets, then language-specific commands.

## Hooks (15 events, 5 scripts)

Hooks ship in the `kodflow-hooks` marketplace plugin, not in the image — `settings.json` has no `hooks` block. Hooks registered on the same event run in parallel, so each event gets exactly one script and the ordering lives inside it: gate → block → transform → observe, exit at the first stage with nothing left to do.

| Script | Events |
|--------|--------|
| `on-tool.sh` | PreToolUse, PostToolUse, PostToolUseFailure — git guard, protected paths, RTK rewrite, format/lint, project-linter pre-check, logging |
| `on-session.sh` | SessionStart, SessionEnd, PreCompact, ConfigChange |
| `on-user.sh` | UserPromptSubmit, Notification |
| `on-agent.sh` | SubagentStart, SubagentStop, TaskCreated, TaskCompleted, TeammateIdle |
| `on-stop.sh` | Stop — project-linter verdict, per-directory CLAUDE.md reminder, terminal bell |

`PermissionRequest` auto-approval and `WorktreeCreate`/`WorktreeRemove` hooks were dropped (native `permissions.allow` and native worktree handling do this correctly; see the plugin's README for what else was removed and why).

## Agent Teams (experimental)

Parallel multi-agent execution for 3 high-value skills (`/review`, `/plan`, `/infra`). Each skill detects its runtime mode at invocation and branches:

| Capability (persisted) | Runtime mode | Where |
|---|---|---|
| TMUX | TEAMS_TMUX | Split-pane teammates in tmux |
| IN_PROCESS | TEAMS_INPROCESS | Shift+Down to cycle teammates |
| NONE | SUBAGENTS | Legacy Task-tool dispatch |

**Single source of truth:** `skills/_shared/team-mode.md` in the `kodflow-devops` marketplace plugin
**Primitives:** `skills/_shared/scripts/team-mode-primitives.sh` in the same plugin (`detect_runtime_mode`, `extract_task_contract`, `classify_terminal`, …)
**Capability file:** `~/.claude/.team-capability` (hint only — live probe is source of truth)
**Install:** automatic via `install.sh`; opt-out with `install.sh --no-teams`
**Runtime opt-out:** `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0 /<skill>`
**Debug:** `TEAM_MODE_DEBUG=1` → stderr decision logs
**Kill switch:** `echo NONE > ~/.claude/.team-capability`

Every team task embeds a `<!-- task-contract v1 ... -->` JSON block (contract_version, access_mode, owned_paths, acceptance_criteria, …). `TaskCreated` is logged by `on-agent.sh`, not adjudicated — the old `task-created.sh` contract registry was dropped (it needed a capability file and primitives library nothing shipped, so it never ran).

## Documentation Hierarchy

```
CLAUDE.md                    # This overview
├── AGENTS.md                # Specialist agents (29 agents)
├── docs/vision.md           # Objectives, success criteria
├── docs/architecture.md     # System design, components
├── docs/workflows.md        # Detailed workflows
├── docs/ktn-linter-integration.md  # ktn-linter hook contract
├── .github/CLAUDE.md        # GitHub Actions, dependabot
├── .devcontainer/CLAUDE.md  # Container config details
│   ├── features/CLAUDE.md   # Language & tool features
│   ├── hooks/CLAUDE.md      # Host-side hooks (initialize.sh only)
│   └── images/CLAUDE.md     # Two-tier images (base + dynamic)
└── kodflow marketplace      # Skills, agents, hooks (6 plugins, installed by postStart)
```

Principle: More detail deeper in tree. Each file ≤ 1000 lines.

## Commands

All skills below ship as marketplace plugins (`kodflow-workflow`, `kodflow-review`, `kodflow-devops`), installed by `postStart.sh` — not repository files.

| Command | Purpose |
|---------|---------|
| `/project` | Resolve/create the workspace; record decisions as numbered constraints in CLAUDE.md |
| `/plan` | Analyze codebase and design implementation approach |
| `/challenge` | Adversarial debate of a plan (architecture/scepticism/ops lenses + specialists) before it's built |
| `/refine` | Goal contract generator (10-lens analysis) |
| `/review` | Code review (3-tier: agents + Qodo + CodeRabbit) |
| `/git` | Conventional commits, branch management |
| `/search` | Documentation research with official sources |
| `/feature` | Open/track a feature (note store or GitLab/GitHub issue), branch, append-only trail |
| `/fix` | Same as `/feature` for defects; refuses to open one with no repro |
| `/lint` | Multi-language intelligent linting |
| `/comment` | Audit and fix code comments (WHY not WHAT, docstrings) |
| `/ktn` | Autonomous ktn-linter MCP lifecycle (binary, mcp.json, hooks, daemon, phases) |
| `/infra` | Infrastructure automation (Terraform/Terragrunt) |
| `/audit` | Health check of this Claude Code install: skills, agents, hooks, scripts, MCP servers, KB freshness |
| `/warmup` | Context pre-loading and CLAUDE.md update |
| `/update` | DevContainer update from template; also refreshes the marketplace plugins |
| `/learn` | Extract reusable patterns from the current session into `~/.claude/docs/learned/` |
| `/debug` | Systematic root-cause-first debugging (reproduce → isolate → prove → fix) |
| `/adr` | Architecture Decision Records (docs/adr/NNNN-*.md + index), wired into `/plan` and `/git` |

### Canonical workflow (Skills Architecture v1.6)

```
/search → /plan → /refine → /goal <slug>
```

`/plan --goal` chains automatically into `/refine` once the plan is
written. `/refine` writes a contract at `.claude/goals/<slug>.md` and
prints a textual `Suggested next step: /goal <slug>` — there is no
auto-chain. **`/goal` is a harness builtin** (not a repository
command file): the user types `/goal <slug>` (a documented model
convention — the agent reads `.claude/goals/<slug>.md`) or pastes the
explicit directive condition `/refine` emits. The builtin loops on the
condition; there is no runtime state file.

## Collaboration Rules

**Response style**
- Terse. No trailing summary ("I did X, Y, Z"). The diff and output are enough.
- Lead with action or decision, not with preamble.
- French or English to match the user's language.

**Tool discipline**
- Dedicated tools over Bash equivalents: Read (not cat), Edit (not sed), Glob (not find), Grep (not grep).
- Read the full file before modifying it. No guessing.
- Parallelize independent tool calls in a single message when possible.

**Git discipline**
- Branch prefix matches commit prefix: `feat/*` → `feat:`, `fix/*` → `fix:`.
- Never `--no-verify`, never `git push --force` without explicit user approval.
- Always create NEW commits after hook failure, never `--amend`.

**Memory discipline**
- Propose feedback/user/project memories when the user corrects you, confirms an unusual choice, or shares a deadline/constraint.
- At session end with significant corrections, suggest running `/learn`.

**Destructive actions** — see the canonical [Safeguards](#safeguards) section above.

## Verification

Changes are complete when:
- Tests pass (`make test` or language equivalent)
- Linting passes (auto-run by hooks)
- No secrets in commits (checked by security hook)
- Commit follows conventional format
