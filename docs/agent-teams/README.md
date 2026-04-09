# Agent Teams Refactor — Design & Execution Records

Canonical archive of the planning + execution of the Agent Teams integration into the devcontainer-template.

## Files

| File | Role | Size |
|---|---|---|
| [`01-design-v3.md`](./01-design-v3.md) | Final hardened design plan (V3 + V3.1 polish) with vocabulary, compatibility matrix, task contract v1 JSON spec, registry lifecycle, per-phase exit criteria, risk mitigations | ~850 lines |
| [`02-execution-blueprint.md`](./02-execution-blueprint.md) | Execution runbook used by `/do` — concrete file paths, anchors, and edit templates for Phases B1 → C-extended | ~990 lines |
| [`03-research-context.md`](./03-research-context.md) | Upstream research log: findings from `context7` / `code.claude.com` docs (hook stdin payload schemas, task storage paths, tools allowlist caveat, teammateMode auto semantics), current state audit | ~160 lines |

## Context

Design iterated across three versions (V1 → V2 → V3.1), each hardened after a structural review. V1 mixed capability and runtime-mode taxonomies; V2 introduced the task payload contract but left the parser fragile; V3 locked in the JSON-embedded contract, the advisory-only hooks, and the deterministic C-minimal scope. V3.1 added delimiter tolerance, `contract_version`, `idempotency_key`, `TEAM_MODE_DEBUG`, portable `date` helpers, and explicit documentation of exact-path collision semantics.

## How to read these

If you're onboarding to the Agent Teams refactor, read in order: `03` (what we learned) → `01` (what we decided) → `02` (how we implemented it).

The design file is the source of truth for **decisions**. The execution blueprint is the source of truth for **edits**. The research context captures **evidence** (links to official docs, stdin payload examples, version constraints).

## Runtime protocol (shortcut)

The canonical runtime protocol lives at `.devcontainer/images/.claude/commands/shared/team-mode.md`. Skills reference it via `@`-include. Primitives library: `.devcontainer/images/.claude/scripts/team-mode-primitives.sh`. Helper scripts: `.devcontainer/scripts/list-team-agents.sh`, `.devcontainer/tests/unit/run-all.sh`.

## Invariants (for future contributors)

- Capability file is a HINT; `detect_runtime_mode` live probe is the source of truth
- Hook stdin does NOT carry file paths — all metadata travels inside `task_description` as a `<!-- task-contract v1 {...} -->` JSON block
- `~/.claude/tasks/` and `~/.claude/teams/` are READ-ONLY best-effort, never enforcement targets
- Hooks are ADVISORY by default — strict rejection only on explicit contract violations
- Kill switch: `echo NONE > ~/.claude/.team-capability`
