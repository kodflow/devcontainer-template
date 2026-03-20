---
name: lint
description: |
  Intelligent linting with ktn-linter using RLM decomposition.
  Sequences 148 rules optimally across 8 phases.
  Fixes ALL issues automatically in intelligent order.
  Detects DTOs on-the-fly and applies dto:"direction,context,security" convention.
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
---

# /lint - Intelligent Linting (RLM Architecture)

$ARGUMENTS

## GREPAI-FIRST (MANDATORY)

Use `grepai_search` for ALL semantic/meaning-based queries BEFORE Grep.
Use `grepai_trace_callers`/`grepai_trace_callees` for impact analysis.
Fallback to Grep ONLY for exact string matches or regex patterns.

## CONTEXT7 (RECOMMENDED)

Use `mcp__context7__resolve-library-id` + `mcp__context7__query-docs` to:
- Verify linter rule documentation when fixing complex violations
- Check framework-specific lint configurations

---

## AUTOMATIC WORKFLOW

This skill fixes **ALL** ktn-linter issues without exception.
No arguments. No flags. Just complete execution.

---

## Quick Reference

| Phase | Category | Rules | Mode |
|-------|----------|-------|------|
| 1 | STRUCTURAL | 7 | Lead (sequential) |
| 2 | SIGNATURES | 7 | Lead (sequential) |
| 3 | LOGIC | 17 | Lead (sequential) |
| 4 | PERFORMANCE | 11 | Teammate "perf" |
| 5 | MODERN | 20 | Teammate "modern" |
| 6 | STYLE | 13 | Teammate "polish" |
| 7 | DOCS | 8 | Teammate "polish" |
| 8 | TESTS | 8 | Teammate "tester" |

---

## Module Reference

| Action | Module |
|--------|--------|
| All 148 rules by phase | Read ~/.claude/commands/lint/rules.md |
| Execution workflow & agent teams | Read ~/.claude/commands/lint/execution.md |
| DTO convention & detection | Read ~/.claude/commands/lint/dto.md |

---

## Routing

1. **Run ktn-linter**: Refer to `execution.md` Step 1
2. **Parse & classify**: Refer to `rules.md` for phase mapping
3. **DTO detection**: Refer to `dto.md` when KTN-STRUCT-ONEFILE or KTN-STRUCT-CTOR
4. **Execute fixes**: Refer to `execution.md` for Agent Teams or sequential mode
5. **Re-run until convergence**: Refer to `execution.md` final verification
