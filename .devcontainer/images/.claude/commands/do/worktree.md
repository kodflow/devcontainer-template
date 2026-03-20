# Phase 5.5: Worktree Dispatch (Semi-Auto, Optional)

**Triggered ONLY when plan contains a Parallelization table with `worktree: yes` steps.**

```yaml
worktree_dispatch:
  condition: "Plan has steps with worktree=yes AND no dependency conflicts"

  1_detect:
    action: "Parse plan for Parallelization table"
    if_absent: "Skip to Phase 6.0 (normal sequential loop)"

  2_display:
    action: "Show parallelizable groups to user"
    format: |
      ═══════════════════════════════════════════════
        /do — Parallel Worktree Dispatch
      ═══════════════════════════════════════════════

        Group 1 (parallel):
          Step 1: src/auth/   → developer-specialist-go (sonnet)
          Step 2: src/api/    → developer-specialist-go (haiku)

        Group 2 (sequential, depends on Group 1):
          Step 3: docs/       → developer-specialist-review (haiku)

      ═══════════════════════════════════════════════

  3_confirm:
    tool: AskUserQuestion
    question: "Create N worktrees and dispatch agents in parallel?"
    options:
      - label: "Yes, dispatch"
        description: "Create worktrees and run agents in parallel"
      - label: "Sequential only"
        description: "Skip worktrees, run all steps sequentially"

  4_dispatch:
    condition: "User approved"
    actions:
      - "For each parallel step: Agent(subagent_type=<agent>, model=<model>, isolation='worktree', prompt=<step description>)"
      - "Launch ALL parallel agents in SINGLE message"
      - "Wait for all to complete"

  5_merge:
    tool: AskUserQuestion
    question: "All worktrees complete. Merge branches into current branch?"
    actions:
      - "git merge --no-ff <worktree-branch> for each"
      - "Resolve conflicts if any"
      - "Continue to next group or Phase 7.0"
```

**Guardrails:**
- NEVER create worktrees without user confirmation
- Max parallel agents = nproc (CPU count)
- If ANY worktree fails, pause and ask user before continuing
- Worktrees are cleaned up after merge (ExitWorktree action=remove)
