---
name: plan
description: |
  Enter Claude Code planning mode with RLM decomposition.
  Analyzes codebase, designs approach, creates step-by-step plan.
  Use when: starting a new feature, refactoring, or complex task.
allowed-tools:
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "mcp__grepai__*"
  - "mcp__context7__*"
  - "Task(*)"
  - "WebFetch(*)"
  - "WebSearch(*)"
  - "mcp__github__*"
  - "mcp__playwright__*"
  - "Write(.claude/plans/*.md)"
  - "Write(.claude/contexts/*.md)"
---

# /plan - Claude Code Planning Mode (RLM Architecture)

$ARGUMENTS

## GREPAI-FIRST (MANDATORY)

Use `grepai_search` for ALL semantic/meaning-based queries BEFORE Grep.
Use `grepai_trace_callers`/`grepai_trace_callees` for impact analysis.
Fallback to Grep ONLY for exact string matches or regex patterns.

---

## Overview

Planning mode with **RLM** patterns:

- **Peek** - Quick codebase scan
- **Decompose** - Split into subtasks
- **Parallelize** - Multi-domain exploration
- **Synthesize** - Structured plan

**Principle**: Plan -> Validate -> Implement (never the reverse)

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<description>` | Plans the implementation of the feature/fix |
| `--context` | Auto-detect most recent `.claude/contexts/*.md` |
| `--context=<name>` | Load specific `.claude/contexts/{name}.md` |
| `--help` | Show help |

---

## --help

```
═══════════════════════════════════════════════════════════════
  /plan - Claude Code Planning Mode (RLM)
═══════════════════════════════════════════════════════════════

Usage: /plan <description> [options]

Options:
  <description>     What to implement
  --context         Load most recent .claude/contexts/*.md
  --context=<name>  Load specific .claude/contexts/{name}.md
  --help            Show this help

RLM Patterns:
  1. Peek       - Quick codebase scan
  2. Decompose  - Split into subtasks
  3. Parallelize - Parallel exploration
  4. Synthesize - Structured plan

Workflow:
  /search <topic> → /plan <feature> → (approve) → /do

Examples:
  /plan "Add user authentication with JWT"
  /plan "Refactor database layer" --context
  /plan "Fix memory leak in worker process"

═══════════════════════════════════════════════════════════════
```

---

## Phase Reference

| Phase | Module | Description |
|-------|--------|-------------|
| 1.0-3.0 | Read ~/.claude/commands/plan/explore.md | Peek + Decompose + Parallelize |
| 4.0 | Read ~/.claude/commands/plan/patterns.md | Pattern consultation + DTO convention |
| 5.0-6.0 | Read ~/.claude/commands/plan/synthesize.md | Plan generation + complexity check + validation |

---

## Execution Flow

```
Phase 1.0: Peek (RLM Pattern)
  → Recover context from .claude/contexts/
  → Scan project structure
  → Identify relevant patterns

Phase 2.0: Decompose (RLM Pattern)
  → Extract objectives from description
  → Categorize by domain
  → Order by dependency

Phase 3.0: Parallelize (RLM Pattern)
  → Launch 4 parallel exploration agents
  → backend, frontend, test, patterns

Phase 4.0: Pattern Consultation
  → Consult ~/.claude/docs/ for applicable patterns
  → DTO convention reminder (if Go)

Phase 5.0: Synthesize (RLM Pattern)
  → Generate structured plan document
  → Persist to .claude/plans/{slug}.md
  → Persist context to .claude/contexts/{slug}.md
  → Add worktree parallelization table (if applicable)

Phase 5.5: Complexity Check
  → If > 15 files, ask user to split

Phase 6.0: Validation Request
  → Wait for user approval before /do
```

---

## Guardrails (ABSOLUTE)

| Action | Status |
|--------|--------|
| Skip Phase 1 (Peek) | **FORBIDDEN** |
| Sequential exploration | **FORBIDDEN** |
| Skip Pattern Consultation | **FORBIDDEN** |
| Implement without approved plan | **FORBIDDEN** |
| Plan without concrete steps | **FORBIDDEN** |
| Plan without rollback strategy | **WARNING** |
