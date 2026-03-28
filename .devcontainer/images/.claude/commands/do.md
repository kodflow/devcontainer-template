---
name: do
description: |
  Iterative task execution loop with RLM decomposition.
  Transforms a task into a persistent loop with automatic iteration.
  The agent keeps going, fixing its own mistakes, until success criteria are met.
  Also executes approved plans from /plan (auto-detected).
allowed-tools:
  - "Read(**/*)"
  - "Glob(**/*)"
  - "mcp__grepai__*"
  - "mcp__context7__*"
  - "Grep(**/*)"
  - "Write(**/*)"
  - "Edit(**/*)"
  - "Bash(*)"
  - "Task(*)"
  - "TaskCreate(*)"
  - "TaskUpdate(*)"
  - "TaskList(*)"
  - "TaskGet(*)"
  - "AskUserQuestion(*)"
---

# /do - Iterative Task Loop (RLM Architecture)

$ARGUMENTS

## GREPAI-FIRST (MANDATORY)

Use `grepai_search` for ALL semantic/meaning-based queries BEFORE Grep.
Use `grepai_trace_callers`/`grepai_trace_callees` for impact analysis.
Fallback to Grep ONLY for exact string matches or regex patterns.

## CONTEXT7 (RECOMMENDED)

Use `mcp__context7__resolve-library-id` + `mcp__context7__query-docs` to:
- Verify library API usage before writing implementation code
- Check framework conventions when working on unfamiliar codebases
- Resolve ambiguous patterns by consulting up-to-date documentation

---

## Overview

Iterative loop using **Recursive Language Model** decomposition:

- **Peek** - Quick scan before execution
- **Decompose** - Split the task into sub-objectives
- **Parallelize** - Parallel validations (test, lint, build)
- **Synthesize** - Consolidated report

**Principle**: Iterate until success rather than aiming for perfection.

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<task>` | Launch the interactive workflow |
| _(empty)_ | Execute the approved plan (if exists) |
| `--plan <path>` | Execute a specific plan file |
| `--help` | Display help |

---

## --help

```
═══════════════════════════════════════════════════════════════
  /do - Iterative Task Loop (RLM)
═══════════════════════════════════════════════════════════════

  DESCRIPTION
    Transforms a task into a persistent loop of iterations.
    The agent continues until the success criteria are met
    or the iteration limit is reached.

    If an approved plan exists (via /plan), it executes it
    automatically without asking interactive questions.

  USAGE
    /do <task>              Launch the interactive workflow
    /do                     Execute the approved plan (if exists)
    /do --plan <path>       Execute a specific plan file
    /do --help              Display this help

  RLM PATTERNS
    1. Plan    - Approved plan detection (skip questions if yes)
    2. Secret   - 1Password secret discovery
    3. Questions - Interactive configuration (if no plan)
    4. Peek     - Codebase scan + git conflict check
    5. Decompose - Split into measurable sub-objectives
    6. Loop     - Simultaneous validations (test/lint/build)
    7. Synthesize - Consolidated report per iteration

  EXAMPLES
    /do "Migrate Jest tests to Vitest"
    /do "Add tests to cover src/utils at 80%"
    /do                     # Execute the plan from /plan

  GUARDRAILS
    - Max 50 iterations (default: 10)
    - MEASURABLE success criteria only
    - Mandatory diff review before merge
    - Git conflict check before modifications

═══════════════════════════════════════════════════════════════
```

**IF `$ARGUMENTS` contains `--help`**: Display the help above and STOP.

---

## Phase Reference

| Phase | Module | Description |
|-------|--------|-------------|
| 1.0-2.0 | Read ~/.claude/commands/do/plan-detect.md | Plan detection + secret discovery |
| 3.0-4.0 | Read ~/.claude/commands/do/questions.md | Interactive questions (if no plan) + Peek |
| 5.0 | Read ~/.claude/commands/do/decompose.md | Task decomposition into sub-objectives |
| 5.5 | Read ~/.claude/commands/do/worktree.md | Worktree dispatch (optional, parallel) |
| 6.0 | Read ~/.claude/commands/do/loop.md | Main execution loop + guardrails |
| 7.0 | Read ~/.claude/commands/do/synthesis.md | Final report + skill integration |

---

## Execution Flow

```
Phase 1.0: Plan Detection
  → Plan found? → PLAN_EXECUTION mode (skip questions)
  → No plan?   → ITERATIVE mode

Phase 2.0: Secret Discovery (1Password, non-blocking)

Phase 3.0: Interactive Questions (IF NO PLAN)
  → Task type, iterations, criteria, scope

Phase 4.0: Peek (RLM Pattern)
  → Git check, structure scan, pattern detection, stack detection

Phase 5.0: Decompose (RLM Pattern)
  → Split task into ordered sub-objectives

Phase 5.5: Worktree Dispatch (optional)
  → Only if plan has worktree=yes steps

Phase 6.0: Main Loop
  → Peek → Apply → Parallelize (test/lint/build) → Synthesize → Decision

Phase 7.0: Final Synthesis
  → Success or Failure report
```

---

## Quick Guardrails

| Action | Status |
|--------|--------|
| Skip plan detection | **FORBIDDEN** |
| Skip questions without plan | **FORBIDDEN** |
| Skip peek | **FORBIDDEN** |
| Ignore max_iterations | **FORBIDDEN** |
| Subjective criteria | **FORBIDDEN** |
| Modify .claude/ or .devcontainer/ | **FORBIDDEN** |
| More than 50 iterations | **FORBIDDEN** |
