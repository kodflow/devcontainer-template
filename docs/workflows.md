# Development Workflows

## Quick Reference

| Task | Command |
|------|---------|
| Initialize project | `/project` |
| New feature | `/plan "feature description"` |
| Bug fix | `/plan "fix description"` |
| Code review | `/review` |
| Plan implementation | `/plan` |
| Execute plan | `/refine` → `/goal <slug>` |
| Commit changes | `/git --commit` |
| Run tests | `make test` or language-specific |

## Project Initialization

```
/project → detect template → discovery conversation → generate docs → validate environment
```

Run once after creating a project from this template. Produces vision, architecture, workflows, and agent configuration; decisions are recorded as numbered constraints in CLAUDE.md.

## Feature Development

```
/plan "add user auth" → implement → /review → PR
```

1. Creates `feat/<desc>` branch
2. Enters planning mode — analyzes codebase, designs approach
3. Implement changes (agents consult context7 for latest best practices)
4. `/review` runs 5 executor agents in parallel (correctness, security, design, quality, shell)
5. PR created via MCP GitHub integration

## Bug Fixes

```
/plan "fix: login timeout" → implement → /review → PR
```

Same flow as features, uses `fix/` branch prefix and `fix(scope):` commits.

## Code Review Pipeline

`/review` is a 3-tier review: T1 agents, T2 Qodo (skipped when absent), T3
CodeRabbit (auth-probed). T1 dispatches five cross-cutting executors in
parallel, alongside the language specialists selected by file type:

| Executor | Focus |
|----------|-------|
| Correctness | Invariants, state machines, off-by-one, concurrency |
| Security | Taint analysis, OWASP Top 10, secrets, injection |
| Design | Patterns, SOLID, DDD, antipatterns |
| Quality | Complexity, code smells, maintainability |
| Shell | Shell scripts, Dockerfiles, CI/CD safety |

## Self-Correction Loop

When agents detect issues:
1. Generate code → run linting/tests
2. If failure → analyze error → fix → retry
3. Repeat until quality criteria are met
4. If stuck after 3 attempts → escalate to user

## Branch Conventions

| Type | Branch | Commit |
|------|--------|--------|
| Feature | `feat/<desc>` | `feat(scope): message` |
| Bug fix | `fix/<desc>` | `fix(scope): message` |

## Pre-commit Checks

Auto-detected by language marker:

| Marker | Language | Checks |
|--------|----------|--------|
| `go.mod` | Go | golangci-lint, build, test -race |
| `Cargo.toml` | Rust | clippy, build, test |
| `package.json` | Node | lint, build, test |
| `pyproject.toml` | Python | ruff, mypy, pytest |

Priority: Makefile targets → Language-specific commands

## Search Strategy

1. **Exact strings / regex**: Grep (primary)
2. **File discovery**: Glob
3. **Read-then-understand**: Read full files; agents reason from context
4. **Official docs**: context7 (`mcp__context7__*`) for library documentation
5. **Token efficiency**: RTK rewrite (transform stage of `on-tool.sh`, `kodflow-hooks` plugin) auto-compresses Bash output

## Hooks

Hooks ship in the `kodflow-hooks` marketplace plugin (15 events, 5 scripts), not in the image — `settings.json` has no `hooks` block. Hooks on the same event run in parallel, so each event gets exactly one script and the ordering lives inside it: gate → block → transform → observe.

| Script | Events | Action |
|--------|--------|--------|
| `on-tool.sh` | PreToolUse, PostToolUse, PostToolUseFailure | Git guard, protected paths, RTK rewrite, format/lint, project-linter pre-check, logging |
| `on-session.sh` | SessionStart, SessionEnd, PreCompact, ConfigChange | Session lifecycle |
| `on-user.sh` | UserPromptSubmit, Notification | Prompt/notification handling |
| `on-agent.sh` | SubagentStart, SubagentStop, TaskCreated, TaskCompleted, TeammateIdle | Agent/task lifecycle logging |
| `on-stop.sh` | Stop | Project-linter verdict, per-directory CLAUDE.md reminder |
