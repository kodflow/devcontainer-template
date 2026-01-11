---
name: review
description: |
  AI-powered code review using RLM (Recursive Language Model) decomposition.
  Analyzes code changes for security, quality, and best practices.
  Use when: running /review, analyzing PR changes, pre-commit checks,
  or when user asks for code review feedback.
allowed-tools:
  - "Bash(git diff:*)"
  - "Bash(git status:*)"
  - "Bash(git log:*)"
  - "Bash(git remote:*)"
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "mcp__github__*"
  - "mcp__codacy__*"
  - "mcp__playwright__*"
---

# Review - AI Code Review (RLM Architecture)

## Overview

Intelligent code review using **Recursive Language Model** decomposition:

- **Peek** before full analysis (Glob, partial Read)
- **Decompose** into parallel sub-tasks
- **Synthesize** condensed results

## Usage

```
/review                    # Review current changes (git diff)
/review --pr [number]      # Review specific PR
/review --staged           # Review staged changes only
/review --file <path>      # Review specific file
/review --security         # Security-focused review only
/review --quality          # Quality-focused review only
```

## RLM Workflow

```yaml
review_workflow:
  1_peek:
    action: "Quick scan of changes"
    tools: [Glob, "git diff --stat"]
    output: "file_list, change_summary"

  2_decompose:
    action: "Categorize files by type"
    categories:
      - security: "*.go, *.py, *.js, *.ts (auth, crypto, input)"
      - quality: "All code files (complexity, style)"
      - tests: "*_test.*, *.test.*, *.spec.*"
      - config: "*.yaml, *.json, *.toml, Dockerfile"

  3_parallel_dispatch:
    action: "Launch sub-agents via Task tool"
    agents:
      - security-scanner (context: fork)
      - quality-checker (context: fork)
    mode: "parallel"

  4_synthesize:
    action: "Combine results"
    format: "Prioritized markdown report"
```

## Output Format

```markdown
# Code Review: <scope>

## Summary
<1-2 sentences overall assessment>

## Critical Issues
> Must fix before merge

### [CRITICAL] `file:line` - Title
**Problem:** Description
**Fix:** Suggestion
**Reference:** URL

## Major Issues
> Strongly recommended

## Minor Issues
> Nice to have (max 5 shown)

## Pattern Analysis
> Design patterns assessment

### Patterns Identified
| Pattern | Location | Status |
|---------|----------|--------|
| Singleton | `src/db.ts` | ✓ Correct |
| Factory | `src/handlers/` | ⚠ Missing reset |

### Pattern Suggestions
| Problem | Suggested Pattern | Reference |
|---------|-------------------|-----------|
| Repeated DB connections | Object Pool | .claude/docs/performance/README.md |
| Complex object creation | Builder | .claude/docs/creational/README.md |

## Commendations
> What's done well

## Metrics
| Metric | Value |
|--------|-------|
| Files | N |
| Critical | N |
| Major | N |
```

## MCP Integration

**Priority MCP tools:**

| Action | MCP Tool |
|--------|----------|
| PR files | `mcp__github__get_pull_request_files` |
| PR diff | `mcp__codacy__codacy_get_pull_request_git_diff` |
| Issues | `mcp__codacy__codacy_list_pull_request_issues` |
| Security | `mcp__codacy__codacy_search_repository_srm_items` |

**Fallback CLI:**

- `git diff`, `gh pr view --json files`

## Agents Architecture

This skill uses specialized agents via the Task tool:

```
/review
    │
    ├─→ code-reviewer (orchestrator)
    │       │
    │       ├─→ security-scanner (parallel, context: fork)
    │       │     Tools: Codacy SRM, bandit, semgrep, trivy, gitleaks
    │       │     Focus: OWASP Top 10, secrets, injection, crypto
    │       │
    │       └─→ quality-checker (parallel, context: fork)
    │             Tools: Codacy issues, eslint, pylint, shellcheck
    │             Focus: Complexity, duplication, style, dead code
    │
    └─→ Synthesized Report
```

**Agent dispatch example:**

```yaml
Task:
  subagent_type: Explore
  prompt: |
    Load the security-scanner agent from ~/.claude/agents/security-scanner.md
    Analyze: {file_list}
    Diff: {diff_content}
    Return JSON only.
```

## Pattern Consultation (OBLIGATOIRE)

Lors de chaque review, consulter `.claude/docs/` pour :

```yaml
pattern_analysis:
  1_identify:
    action: "Grep pour patterns connus dans le code"
    patterns:
      - "class.*Factory" → Factory pattern
      - "getInstance" → Singleton pattern
      - "subscribe.*notify" → Observer pattern
      - "execute.*undo" → Command pattern

  2_validate:
    action: "Comparer avec docs/"
    check:
      - "Pattern correctement implémenté?"
      - "Manque-t-il des éléments?"
      - "Anti-patterns présents?"

  3_suggest:
    action: "Identifier améliorations possibles"
    consult:
      - ".claude/docs/README.md" (tableau de décision)
      - Category README pour détails
```

**Quand suggérer un pattern :**

| Code Smell | Pattern Suggéré | Référence |
|------------|-----------------|-----------|
| new() répétés | Factory/Builder | creational/README.md |
| If/else sur types | Strategy/State | behavioral/README.md |
| Callbacks imbriqués | Promise/Async | concurrency/README.md |
| Données dupliquées | Flyweight/Cache | performance/README.md |
| Couplage fort | Mediator/Observer | behavioral/README.md |

---

## Guard-rails

| Action | Status |
|--------|--------|
| Auto-approve/merge | FORBIDDEN |
| Skip security issues | FORBIDDEN |
| Modify code directly | FORBIDDEN |
| Post without user review | FORBIDDEN |
| Skip pattern analysis | FORBIDDEN |
