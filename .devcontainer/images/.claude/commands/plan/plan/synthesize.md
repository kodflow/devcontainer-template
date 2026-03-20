# Phase 5.0: Synthesize (RLM Pattern)

**Generate the structured plan:**

```yaml
synthesize_workflow:
  plan_audience:
    rule: "Plan must be executable by a skilled developer with ZERO domain knowledge"
    implications:
      - "Chemins de fichiers EXACTS (pas 'the auth module')"
      - "Code samples COMPLETS (pas 'implement the logic')"
      - "Commandes CLI EXACTES avec outputs attendus"

  step_granularity:
    rule: "Each step = 1 TDD cycle (2-5 min)"
    format: |
      ### Step N: <Titre>
      **Files:** `src/file.ts` (create), `tests/file.test.ts` (create)
      **Test first:** Write failing test for {behavior}
      **Implement:** Minimal code to pass
      **Verify:** Run tests, confirm green
      **Commit:** `feat(scope): description`

  1_collect:
    action: "Collect agent results"

  2_consolidate:
    action: "Merge into coherent plan"

  3_generate:
    format: "Structured plan document"

  4_persist_to_disk:
    action: "Write plan to .claude/plans/{slug}.md"
    slug_rule: "Same as /search: lowercase, hyphens, max 40 chars from description"
    collision: "If file exists, append timestamp suffix (-YYYYMMDD-HHMM)"
    purpose: "Survives context compaction; /do can detect from disk"
    note: "This is IN ADDITION to ExitPlanMode (which shows plan to user)"

  5_persist_context:
    action: "Write context file to .claude/contexts/{slug}.md"
    trigger: "Always after plan generation"
    purpose: "Captures discoveries, relevant files, and implementation notes for /do recovery"
    content:
      header: |
        # Context: {description}
        Generated: {ISO8601}
        Plan: .claude/plans/{slug}.md
      sections:
        discoveries: "Key findings from codebase analysis (patterns, conventions, gotchas)"
        relevant_files: "Files examined during planning with brief role description"
        implementation_notes: "Technical decisions, trade-offs, constraints discovered"
        dependencies: "External libs, APIs, or services involved"
    link_in_plan:
      action: "Add 'Context: .claude/contexts/{slug}.md' line in plan header"
      format: |
        # Implementation Plan: {description}
        Context: .claude/contexts/{slug}.md
```

**Plan Output Format:**

```markdown
# Implementation Plan: <description>
Context: .claude/contexts/<slug>.md

## Overview
<2-3 sentences summarizing the approach>

## Design Patterns Applied

| Pattern | Category | Justification | Reference |
|---------|----------|---------------|-----------|
| Repository | DDD | Data access abstraction | ~/.claude/docs/ddd/README.md |
| Factory | Creational | Token creation | ~/.claude/docs/creational/README.md |

## Prerequisites
- [ ] <Required dependency or setup>
- [ ] <Other prerequisite>

## Implementation Steps

### Step 1: <Title>
**Files:** `src/file1.ts`, `src/file2.ts`
**Actions:**
1. <Specific action>
2. <Specific action>

**Code pattern:**
```<lang>
// Example of what will be implemented
```

### Step 2: <Title>
...

## Parallelization (optional — for multi-step plans)

When steps are independent (no shared files, no dependency), tag them for parallel execution:

| Step | Files | Agent | Model | Worktree | Depends On |
|------|-------|-------|-------|----------|------------|
| 1 | src/auth/ | developer-specialist-go | sonnet | yes | - |
| 2 | src/api/ | developer-specialist-go | haiku | yes | - |
| 3 | docs/ | developer-specialist-review | haiku | no | 1, 2 |

`/do` will use this table to create worktrees and dispatch agents in parallel (semi-auto: user confirms before creating worktrees).

**Rules:**
- Only tag `worktree: yes` if step touches DIFFERENT files than other parallel steps
- Assign the most specific agent for the task
- Model follows agent default (from registry.json)
- Steps with `depends_on` run sequentially AFTER dependencies complete

## Testing Strategy
- [ ] Unit tests for `component`
- [ ] Integration test for `flow`

## Rollback Plan
How to rollback if issues

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Risk description | Solution |
```

---

## Phase 5.5: Complexity Check

**Triggered automatically after Synthesize. NOT a blocker -- just a question.**

```yaml
complexity_check:
  trigger: "files_to_modify + files_to_create > 15"

  action:
    tool: AskUserQuestion
    questions:
      - question: "This plan touches {n} files. Beyond ~15 files in a single session, quality may degrade. How do you want to proceed?"
        header: "Scope"
        options:
          - label: "Execute as-is"
            description: "Proceed with the full plan in one session"
          - label: "Split into phases"
            description: "Claude will propose logical segments to execute separately"

  on_execute_as_is:
    action: "Continue to Phase 6.0 normally"

  on_split:
    action: |
      Rewrite the plan into numbered phases (Phase A, B, C...)
      Each phase: <= 15 files, independently testable
      User approves each phase via /do
```

**If <= 15 files:** Skip this phase silently, proceed to Phase 6.0.

---

## Phase 6.0: Validation Request

**MANDATORY: Wait for user approval**

```
═══════════════════════════════════════════════════════════════
  Plan ready for review
═══════════════════════════════════════════════════════════════

  Summary:
    • 4 implementation steps
    • 6 files to modify
    • 2 new files to create
    • 8 tests to add

  Design Patterns:
    • Repository (DDD)
    • Factory (Creational)

  Estimated complexity: MEDIUM

  Actions:
    → Review the plan above
    → Run /do to execute (auto-detects plan)
    → Or modify the plan manually

═══════════════════════════════════════════════════════════════
```

---

## Integration with Other Skills

| Before /plan | After /plan |
|-------------|-------------|
| `/search <topic>` | `/do` |
| Generates `.claude/contexts/{slug}.md` | Executes the plan (auto-detected from conversation or `.claude/plans/`) |

**Full workflow:**

```
/search "JWT authentication best practices"
    ↓
.claude/contexts/jwt-auth-best-practices.md generated
    ↓
/plan "Add JWT auth to API" --context
    ↓
Plan created, displayed, AND persisted to .claude/plans/add-jwt-auth-api.md
    ↓
User: "OK, go ahead"
    ↓
/do                          # Detects plan from conversation OR .claude/plans/
    ↓
Implementation executed
```

**Note**: `/do` automatically detects the approved plan from conversation context
or from `.claude/plans/*.md` on disk (conversation takes priority).
Plans persist across context compaction.
