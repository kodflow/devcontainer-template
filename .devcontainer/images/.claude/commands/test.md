---
name: test
description: |
  E2E and frontend testing with Playwright MCP and RLM decomposition.
  Automates browser interactions, visual testing, and debugging.
  Use when: running E2E tests, debugging frontend, generating test code.
allowed-tools:
  - "mcp__playwright__*"
  - "Bash(npm:*)"
  - "Bash(npx:*)"
  - "Read(**/*)"
  - "Write(**/*)"
  - "Glob(**/*)"
  - "mcp__grepai__*"
  - "mcp__context7__*"
  - "Grep(**/*)"
  - "Task(*)"
---

# /test - E2E & Frontend Testing (RLM Architecture)

$ARGUMENTS

## GREPAI-FIRST (MANDATORY)

Use `grepai_search` for ALL semantic/meaning-based queries BEFORE Grep.
Use `grepai_trace_callers`/`grepai_trace_callees` for impact analysis.
Fallback to Grep ONLY for exact string matches or regex patterns.

## CONTEXT7 (RECOMMENDED)

Use `mcp__context7__resolve-library-id` + `mcp__context7__query-docs` to:
- Verify Playwright API usage and available selectors
- Check test framework APIs (Jest, Vitest, pytest, Go testing)
- Validate assertion library patterns

---

## Overview

E2E tests and frontend debugging with **RLM** patterns:

- **Peek** - Analyze the page before interaction
- **Decompose** - Split the test into steps
- **Parallelize** - Simultaneous assertions and captures
- **Synthesize** - Consolidated test report

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<url>` | Open the URL and explore the page |
| `--run` | Run the project's Playwright tests |
| `--debug <url>` | Interactive debug mode |
| `--trace` | Enable tracing for the session |
| `--screenshot <url>` | Screenshot the page |
| `--pdf <url>` | Generate a PDF of the page |
| `--codegen <url>` | Generate test code |
| `--help` | Show help |

---

## --help

```
═══════════════════════════════════════════════════════════════
  /test - E2E & Frontend Testing (RLM)
═══════════════════════════════════════════════════════════════

Usage: /test <url|action> [options]

Actions:
  <url>               Open and explore the page
  --run               Run project tests
  --debug <url>       Interactive debug mode
  --trace             Enable tracing
  --screenshot <url>  Screenshot
  --pdf <url>         Generate a PDF
  --codegen <url>     Generate test code

RLM Patterns:
  1. Peek       - Analyze the page (snapshot)
  2. Decompose  - Split into test steps
  3. Parallelize - Simultaneous assertions
  4. Synthesize - Consolidated report

MCP Tools:
  browser_navigate    Open a URL
  browser_click       Click element
  browser_type        Type text
  browser_snapshot    Capture state
  browser_expect      Assertions

Examples:
  /test https://example.com
  /test --screenshot https://myapp.com/login
  /test --run
  /test --codegen https://myapp.com

═══════════════════════════════════════════════════════════════
```

---

## Module Reference

| Action | Module |
|--------|--------|
| MCP tools & guardrails | Read ~/.claude/commands/test/playwright.md |
| RLM phases & test workflows | Read ~/.claude/commands/test/workflow.md |

---

## Routing

1. **Any URL action**: Start with Phase 1.0 Peek from `workflow.md`
2. **--run / --trace / --codegen**: Execute specific workflow from `workflow.md`
3. **MCP tool reference**: Refer to `playwright.md` for tool details
4. **Guardrails**: Refer to `playwright.md` for safety rules
