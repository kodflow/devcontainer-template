---
name: refine
description: |
  Skills Architecture v1.4 — proof-bearing goal contract generator with
  three entry modes. FULL mode reads .claude/contexts/<slug>.md +
  .claude/plans/<slug>.md, dispatches 4-10 review lenses, synthesizes a
  /goal directive (≤4096 chars) plus a full contract at
  .claude/goals/<slug>.md. BARE mode skips lens dispatch and structures
  a free-form description into a budgeted /goal. FROM-CONTRACT mode
  re-compacts an existing goal contract (useful after manual edits).
allowed-tools:
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "Task(*)"
  - "Agent(*)"
  - "TaskCreate(*)"
  - "TaskUpdate(*)"
  - "Skill(skill=do)"
  - "Write(.claude/goals/*.md)"
  - "mcp__context7__*"
---

$ARGUMENTS

@.devcontainer/images/.claude/commands/shared/team-mode.md

# /refine — Goal Contract Generator (v1.4 — Skills Architecture)

## Modes

| Mode | Trigger | What runs |
|---|---|---|
| **FULL** (default) | `<slug>` | Phase 1 + 2 + 3 + 4 — full lens analysis |
| **BARE** | `--bare "<description>"` | Phase 3 + 4 only — skip lens dispatch |
| **FROM-CONTRACT** | `--from-contract <slug>` | Phase 3 (re-compact) + 4 only |

BARE is for cases where there's no plan + context to analyse yet (a
trivial fix, an exploratory `/goal` you want to start fast). FROM-CONTRACT
is for cases where you edited `.claude/goals/<slug>.md` by hand and want
the 4096-char budget re-enforced on the directive without re-running
the 10 lenses.

## Phase 1: Detect mode (LIGHT / FULL via AUTO) — FULL mode only

Read `~/.claude/commands/refine/auto.md`. AUTO is the default; pass
`--light` or `--full` to override. Plan frontmatter MUST declare:

| Field | Type | Notes |
|---|---|---|
| `risk` | string | `low` / `medium` / `high` / `critical` |
| `loc_estimate_max` | number | numeric upper bound on LOC change |
| `touches_public_api` | bool | true → FULL |
| `touches_security_surface` | bool | true → FULL (fix #14) |
| `touches_dev_infra` | bool | true → FULL (fix #15) |

Any missing or non-numeric field defaults to FULL. The decision tree
is deterministic — see `auto.md` for the exact boundaries.

BARE mode skips this phase entirely and uses LIGHT budget (≤2000 char)
by default — pass `--full-budget` to force the 4096 budget instead.

## Phase 2: Dispatch lenses — FULL mode only

Read `~/.claude/commands/refine/dispatch.md`. For each of the 10 lenses,
call `route-agent.sh --skill /refine --phase lens-N-<name>`. On exit
code 20-31, fall back to the static lens map in
`refine-static-fallback.sh` (fix #17 — critical lenses must run
regardless of router state).

BARE and FROM-CONTRACT modes skip this phase entirely. The trade-off is
that the resulting `/goal` has no proof triplets — that's the explicit
deal of the bare path.

## Phase 3: Synthesize (all modes)

Read `~/.claude/commands/refine/synthesis.md`.

- **FULL**: collect lens findings → dedup → rank → budget → render → compact.
- **BARE**: apply WHAT/WHY/WHERE/HOW/DONE template to the description →
  budget → compact (no collect/dedup/rank — there's nothing to rank).
- **FROM-CONTRACT**: read `.claude/goals/<slug>.md`, extract the
  directive section → budget → compact.

Budget enforces ≤4096 chars on the runtime directive; LIGHT mode (and
BARE default) target ≤2000.

## Phase 4: Emit (all modes)

Read `~/.claude/commands/refine/render.md`. Writes:

- **FULL**: `.claude/goals/<slug>.md` (proof triplets) + runtime directive.
- **BARE**: `.claude/goals/<slug>.md` skeleton (template-filled) +
  runtime directive. `<slug>` is derived from `--slug` flag, else
  auto-generated from the description's first 5 words.
- **FROM-CONTRACT**: runtime directive only — the contract file is
  the input, never overwritten.

Runtime directive is always appended to the goal-state file via
`goal-state.sh update` (PR1).

## Skill chain

After emit, the user can:

```bash
Skill(skill="do", args="--goal-turn <slug>")
```

to launch the iterative loop against this contract. The goal-state CRUD
helper accepts this slug regardless of which mode produced it.

## Arguments

| Pattern | Action |
|---------|--------|
| `<slug>` | **FULL** mode: refine `.claude/plans/<slug>.md` + `.claude/contexts/<slug>.md` |
| `--bare "<description>"` | **BARE** mode: structure + compact a free-form description, no lens analysis |
| `--from-contract <slug>` | **FROM-CONTRACT** mode: re-compact existing `.claude/goals/<slug>.md` |
| `--slug <name>` | Override auto-generated slug in BARE mode |
| `--light` | Force LIGHT mode (≤2000 char directive) — FULL mode only |
| `--full` | Force FULL mode (all 10 lenses) — overrides AUTO |
| `--full-budget` | Use 4096 budget in BARE mode (default is LIGHT 2000) |
| `--auto` | Default for FULL mode — pick LIGHT/FULL from plan frontmatter |
| `--help` | Display help |

## Workflow patterns (v1.4)

```
quick    : /refine --bare "fix race in worker.go pool init"      →  /goal
medium   : /plan ... --auto → /refine                            →  /goal
full     : /search → /plan → /refine                             →  /goal
edited   : (manually edit .claude/goals/<slug>.md) → /refine --from-contract <slug>
```

The `--bare` mode is the answer to "I want a perfect /goal directive
without going through /search and /plan first". It uses the SAME
synthesis + budget logic as FULL mode (single source of truth for the
4096-char rule), it just skips the analysis phase that needs the
plan + context inputs.
