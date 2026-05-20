# refine/render.md — Skills Architecture v1.3 (PR3)

## Full contract template (`.claude/goals/<slug>.md`)

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

## Runtime directive template (compact)

```
/goal "Implement <plan title>: <top blockers compressed>. Acceptance:
<≤3 bullet criteria>. Rollback: <one line>. Scope guard:
<owned_paths>."
```

Hard cap: 4096 chars. LIGHT target: 2000 chars.

## Post-render side effects

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
