# Kodflow DevContainer Template

## Project Structure (MANDATORY)

```text
/workspace
+-- src/                    # ALL source code (mandatory)
|   +-- components/
|   +-- services/
|   +-- ...
+-- tests/                  # Unit tests (optional, not for Go)
+-- docs/                   # Documentation
+-- CLAUDE.md
```

**Rules:**
- ALL code MUST be in `/src` regardless of language
- Tests in `/tests` (except Go: tests alongside code in `/src`)
- Never put code at project root

## Language Rules

**STRICT**: Follow rules in `.devcontainer/features/languages/<lang>/RULES.md`

Each RULES.md contains:
1. **Line 1**: Required version (NEVER downgrade)
2. Code style and conventions
3. Project structure requirements
4. Testing standards

## Workflow (MANDATORY)

### 1. Context Generation
```
/build --context
```
Generates CLAUDE.md in all subdirectories + fetches latest language versions.

### 2. Feature Development
```
/feature <description>
```
Creates `feat/<description>` branch, **mandatory planning mode**, CI check, PR creation (no auto-merge).

### 3. Bug Fixes
```
/fix <description>
```
Creates `fix/<description>` branch, **mandatory planning mode**, CI check, PR creation (no auto-merge).

**Flow:**
```
/build --context → /feature "..." ou /fix "..."
```

## Branch Conventions

| Type | Branch | Commit prefix |
|------|--------|---------------|
| Feature | `feat/<desc>` | `feat(scope): message` |
| Bugfix | `fix/<desc>` | `fix(scope): message` |

## Code Quality

- Latest stable version ONLY (see RULES.md)
- No deprecated APIs
- No legacy patterns
- Security-first approach
- Full test coverage

## MCP-FIRST RULE (MANDATORY)

**ALWAYS use MCP tools BEFORE falling back to CLI binaries.**

```yaml
mcp_priority:
  rule: "MCP tools are the PRIMARY interface"
  fallback: "CLI only when MCP unavailable or fails"

  workflow:
    1_check_mcp: "Verify MCP server is available in mcp.json"
    2_use_mcp: "Call mcp__<server>__<action> tool"
    3_on_failure: "Log error, inform user, then try CLI fallback"
    4_never_ask: "NEVER ask user for tokens if MCP is configured"

  examples:
    github:
      priority: "mcp__github__list_pull_requests"
      fallback: "gh pr list"
    codacy:
      priority: "mcp__codacy__codacy_cli_analyze"
      fallback: "codacy-cli analyze"
    playwright:
      priority: "mcp__playwright__browser_navigate"
      fallback: "npx playwright test"
```

**Why MCP-first:**

- MCP servers have pre-configured authentication (tokens in mcp.json)
- CLI tools require separate auth (`gh auth login`, etc.)
- MCP provides structured responses (JSON vs text parsing)
- Single source of truth for credentials

## Reasoning Patterns (RLM)

Before complex tasks, apply these patterns from [Recursive Language Models](https://arxiv.org/abs/2512.24601):

1. **Peek** - Read aperçu (Glob, Read partial) before full analysis
2. **Semantic Search** - Use grepai MCP for intelligent code search (replaces Grep)
3. **Decompose** - Divide into sub-tasks (Task agents)
4. **Parallelize** - Execute independents in parallel (single message, multiple tools)
5. **Synthesize** - Combine results into coherent answer

**Application:**
```
Complex request → Peek/grepai → Decompose → Parallel Task agents → Synthesize
```

## GREPAI-FIRST RULE (MANDATORY)

**ALWAYS use grepai MCP for code search BEFORE falling back to Grep tool.**

```yaml
grepai_priority:
  rule: "grepai is the PRIMARY search interface"
  fallback: "Grep tool only when grepai unavailable"

  workflow:
    1_init: "Ensure grepai is initialized (grepai init)"
    2_search: "Call mcp__grepai__grepai_search for semantic search"
    3_trace: "Use mcp__grepai__grepai_trace_* for call graph analysis"
    4_fallback: "Grep tool only if MCP fails"

  tools:
    grepai_search:
      description: "Semantic code search with natural language"
      priority: "ALWAYS use first"
      example: "mcp__grepai__grepai_search(query='error handling')"

    grepai_trace_callers:
      description: "Find all callers of a function"
      use_case: "Before modifying a function"

    grepai_trace_callees:
      description: "Find all functions called by a symbol"
      use_case: "Understanding dependencies"

    grepai_trace_graph:
      description: "Build call graph around a symbol"
      use_case: "Impact analysis"

    grepai_index_status:
      description: "Check index health and stats"
      use_case: "Debugging search issues"

  examples:
    semantic_search:
      priority: "mcp__grepai__grepai_search"
      fallback: "Grep tool"
    call_analysis:
      priority: "mcp__grepai__grepai_trace_callers"
      fallback: "Grep for function name"
```

**Why grepai-first:**

- Semantic understanding (natural language queries)
- Call graph analysis (callers/callees)
- Context-aware results (file paths, line numbers)
- Faster than regex for complex patterns
- Local processing (no cloud dependency)

## SAFEGUARDS (ABSOLUTE - NO BYPASS)

**NEVER without EXPLICIT user approval:**
- Delete files in `.claude/` directory
- Delete files in `.devcontainer/` directory
- Modify `.claude/commands/*.md` destructively (removing features/logic)
- Remove hooks from `.devcontainer/hooks/`

**When simplifying/refactoring:**
- Move content to separate files, NEVER delete logic
- Ask before removing any feature, even if it seems redundant

## Hooks (Auto-applied)

| Hook | Action |
|------|--------|
| `pre-validate.sh` | Protect sensitive files |
| `post-edit.sh` | Format + Imports + Lint |
| `security.sh` | Secret detection |
| `test.sh` | Run related tests |

## Project-Specific Commands

### /improve - Documentation QA

Commande spécifique à ce projet pour auditer la base de connaissances Design Patterns.

```
/improve --help            # Afficher l'aide
/improve                   # Audit complet
/improve --check           # Dry-run (sans modification)
/improve --fix             # Corriger automatiquement
/improve --missing         # Patterns manquants
/improve --category <name> # Auditer une catégorie
```

Cible : `/workspace/.devcontainer/images/.claude/docs/`

## Context Hierarchy (Funnel Documentation)

```
/CLAUDE.md                      # Project overview (this file)
├── .claude/commands/           # Project-specific commands
│   └── improve.md              # /improve - docs QA
├── .devcontainer/CLAUDE.md     # DevContainer config
│   ├── features/CLAUDE.md      # Features overview
│   │   └── kubernetes/CLAUDE.md # K8s details
│   └── images/CLAUDE.md        # Docker images
└── src/CLAUDE.md               # Source code context
```

**Principle:** More details deeper in tree, <60 lines each, ALL committed.
