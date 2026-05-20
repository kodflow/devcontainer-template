# refine/render.md — Skills Architecture v1.4 (PR3 + v1.4 modes)

## FULL contract template (`.claude/goals/<slug>.md`)

```markdown
---
slug: <slug>
plan: .claude/plans/<slug>.md
context: .claude/contexts/<slug>.md
mode: LIGHT|FULL
generated_at: <ISO8601>
---

# Goal Contract: <plan title>

## Acceptance criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

## Proof triplets per lens

### lens-1-correctness (critical)
- **Claim:** ...
- **Evidence:** `src/path:line`, `tests/path:line`
- **Remediation:** ...

[... one section per lens that produced findings ...]

## Rollback strategy
<from lens-4-rollback>

## Out of scope
<from lens-9-scope>
```

## BARE contract template (`.claude/goals/<slug>.md`)

```markdown
---
slug: <slug>
plan: null
context: null
mode: BARE
generated_at: <ISO8601>
---

# Goal Contract: <derived from WHAT slot>

## What
<WHAT slot>

## Why
<WHY slot, or "unspecified">

## Where
<WHERE slot — file/module list, or "unspecified">

## How (constraints)
<HOW slot — bullet list, or "no explicit constraints">

## Acceptance criteria
- [ ] <DONE slot decomposed into checkboxes>

## Out of scope
- proof triplets (BARE mode skips lens analysis)
- rollback strategy (no plan to roll back)
```

The BARE contract is intentionally lean — no proof triplets, no
rollback. The user is told this explicitly via the "Out of scope"
section so they don't expect lens-level guarantees.

## Runtime directive templates (compact)

### FULL mode

```
/goal "Implement <plan title>: <top blockers compressed>. Acceptance:
<≤3 bullet criteria>. Rollback: <one line>. Scope guard:
<owned_paths>."
```

### BARE mode

```
/goal "<WHAT>. <WHY in one clause>. Touches: <WHERE>.
Constraints: <HOW one-liner>. Done when: <DONE one-liner>."
```

### FROM-CONTRACT mode

Re-derives the FULL directive shape from the existing contract on disk.
No new shape; same compact output.

Hard cap: 4096 chars (FULL, FROM-CONTRACT, BARE `--full-budget`).
LIGHT target: 2000 chars (FULL `--light`, BARE default).

## Post-render side effects

### FULL & BARE

```bash
# 1. Write contract
Write(file_path=".claude/goals/<slug>.md", content=<rendered>)

# 2. Append directive to goal state (PR1)
bash ~/.claude/scripts/goal-state.sh update "<slug>" \
  --decision met --decision-reason "refined" \
  --append-objective "directive-emitted"

# 3. Echo directive to the agent's transcript so /do --goal-turn picks it up
echo "$DIRECTIVE"
```

### FROM-CONTRACT

```bash
# 1. NO contract write — input file is the source of truth, never overwritten.

# 2. Append directive to goal state
bash ~/.claude/scripts/goal-state.sh update "<slug>" \
  --decision met --decision-reason "recompacted" \
  --append-objective "directive-re-emitted"

# 3. Echo directive
echo "$DIRECTIVE"
```

## Slug derivation (BARE mode)

When the user invokes `/refine --bare "<description>"` without
`--slug <name>`, derive the slug deterministically:

```bash
derive_slug() {
  local desc="$1"
  echo "$desc" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]' '-' \
    | awk -F- '{ for (i=1;i<=NF && i<=5 && length(out)<40;i++) out=out (out?"-":"") $i; print out }' \
    | sed 's/^-//;s/-$//'
}
# "Fix race in worker.go pool init" → "fix-race-in-worker-go"
```

Collision handling: if `.claude/goals/<slug>.md` exists, append a short
ISO date suffix (`-2026-05-20`) and try again. Refuse to overwrite an
existing BARE contract without explicit `--force`.
