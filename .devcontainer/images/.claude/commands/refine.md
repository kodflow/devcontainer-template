---
name: refine
description: |
  Skills Architecture v1.3 — proof-bearing goal contract generator.
  Reads .claude/contexts/<slug>.md + .claude/plans/<slug>.md, dispatches
  4-10 review lenses through the router (with static fallback per fix #17),
  synthesizes a /goal directive (≤4096 chars) plus a full contract at
  .claude/goals/<slug>.md.
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

# /refine — Goal Contract Generator (PR3 — Skills Architecture v1.3)

## Phase 1: Detect mode (LIGHT / FULL via AUTO)

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

## Phase 2: Dispatch lenses

Read `~/.claude/commands/refine/dispatch.md`. For each of the 10 lenses,
call `route-agent.sh --skill /refine --phase lens-N-<name>`. On exit
code 20-31, fall back to the static lens map in
`refine-static-fallback.sh` (fix #17 — critical lenses must run
regardless of router state).

## Phase 3: Synthesize

Read `~/.claude/commands/refine/synthesis.md`. Collect → dedup → rank
→ budget → render → compact. Budget enforces ≤4096 chars on the
runtime directive; LIGHT mode targets ≤2000.

## Phase 4: Emit

Read `~/.claude/commands/refine/render.md`. Writes two artefacts:

- `.claude/goals/<slug>.md` — full contract (proof triplets, lenses,
  rationale).
- runtime directive — single compact `/goal "..."` line printed to the
  agent + appended to the goal-state file via `goal-state.sh update`.

## Skill chain

After emit, the user can:

```bash
Skill(skill="do", args="--goal-turn <slug>")
```

to launch the iterative loop against this contract. PR1's
goal-state.sh already accepts this slug.

## Arguments

| Pattern | Action |
|---------|--------|
| `<slug>` | Refine `.claude/plans/<slug>.md` + `.claude/contexts/<slug>.md` |
| `--light` | Force LIGHT mode (≤2000 char directive) |
| `--full` | Force FULL mode (all 10 lenses) |
| `--auto` | Default — pick LIGHT/FULL from plan frontmatter |
| `--help` | Display help |
