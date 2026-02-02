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

**Language conventions are enforced by specialist agents** (e.g., `developer-specialist-go`,
`developer-specialist-python`). Each agent knows the latest stable version and best practices.

Key principles:
1. Use **latest stable version** of each language
2. Follow language-specific code style (enforced by linters)
3. ALL code in `/src`, tests in `/tests` (except Go: tests alongside code)
4. Security-first approach with full test coverage

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

- Latest stable version ONLY (specialist agents know current versions)
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

**ALWAYS try grepai FIRST. Use Grep as FALLBACK only.**

```yaml
search_strategy:
  primary:
    tool: mcp__grepai__grepai_search
    for: "Semantic search, meaning-based queries"

  trace:
    tools: [mcp__grepai__grepai_trace_callers, mcp__grepai__grepai_trace_callees, mcp__grepai__grepai_trace_graph]
    for: "Impact analysis, call graphs"

  fallback:
    tool: Grep
    conditions:
      - "grepai returns 0 results AND query is valid"
      - "Exact regex/literal match needed (ERROR_CODE_42)"
      - "grepai MCP unavailable (connection error)"

  cross_reference:
    rule: "Validate with 2+ sources when possible"

grepai_workflow:
  step_1_semantic:
    tool: mcp__grepai__grepai_search
    example: grepai_search(query="authentication error handling")

  step_2_evaluate:
    if: "results.count == 0 OR exact_match_needed"
    then: "Proceed to Grep fallback"

  step_3_fallback:
    tool: Grep
    use_for:
      - "Exact string (ERROR_CODE_42)"
      - "Regex pattern (func.*Handler)"
      - "grepai MCP failed"

  step_4_cross_reference:
    action: "Compare & validate from multiple sources"
```

**Decision matrix:**

| Search Task | Tool | Reason |
|-------------|------|--------|
| "Find authentication code" | `grepai_search` | Semantic |
| "Who calls handleLogin?" | `mcp__grepai__grepai_trace_callers` | Call graph |
| Exact string `"ERROR_CODE_42"` | `Grep` (fallback) | Literal match |
| Regex `func.*Handler` | `Grep` (fallback) | Pattern match |
| grepai returns 0 results | `Grep` (fallback) | Degraded mode |

**Initialization (automatic via initialize.sh + postStart.sh):**

Ollama runs on HOST machine for GPU acceleration (Metal on Mac, CUDA on Linux).
Installed automatically via `initialize.sh` during DevContainer build.

```bash
# Detection:
# 1. OLLAMA_HOST env var (override)
# 2. host.docker.internal:11434 (host Ollama with GPU)
```

**GPU Acceleration (10x faster):**

Ollama is automatically installed on your host machine during DevContainer build:

```bash
# Manual setup (if needed):
# macOS (Metal GPU)
brew install ollama
ollama serve
ollama pull qwen3-embedding:0.6b

# Linux (NVIDIA GPU)
curl -fsSL https://ollama.ai/install.sh | sh
ollama serve
ollama pull qwen3-embedding:0.6b

# Then restart DevContainer - host Ollama auto-detected
```

**Performance:**

| Configuration | Speed | Hardware |
|---------------|-------|----------|
| Host Ollama (Mac) | ~10ms/embed | Metal GPU |
| Host Ollama (Linux) | ~5ms/embed | NVIDIA GPU |

## SAFEGUARDS (ABSOLUTE - NO BYPASS)

**NEVER without EXPLICIT user approval:**
- Delete files in `.claude/` directory
- Delete files in `.devcontainer/` directory
- Modify `.claude/commands/*.md` destructively (removing features/logic)
- Remove hooks from `.devcontainer/hooks/`

**When simplifying/refactoring:**
- Move content to separate files, NEVER delete logic
- Ask before removing any feature, even if it seems redundant

## AI Reference Policy (ABSOLUTE - NO BYPASS)

**NEVER mention AI/LLM in generated content:**

| Content Type | Forbidden References |
|--------------|---------------------|
| Commit messages | `Co-Authored-By: Claude/AI/GPT`, `Generated by AI` |
| Code comments | `// AI-generated`, `# Claude suggestion` |
| Documentation | `Created with AI`, `LLM-assisted` |
| PR/MR descriptions | `🤖`, `AI-powered`, `Claude Code` |
| Issue descriptions | Any AI/LLM attribution |

**Enforced by:**
- `commit-validate.sh` hook (blocks commits with AI references)
- Pre-commit checks (automatic)

**Rationale:** Professional discretion about tooling used.

## Pre-commit Language Detection

**Auto-detect languages and run checks for ALL detected stacks:**

```yaml
detection:
  go.mod: Go → golangci-lint, go build, go test -race
  Cargo.toml: Rust → cargo clippy, cargo build, cargo test
  package.json: Node.js → npm run lint/build/test
  pyproject.toml: Python → ruff, mypy, pytest
  Gemfile: Ruby → rubocop, rspec
  pom.xml: Java → mvn checkstyle, compile, test
  build.gradle: Gradle → ./gradlew check, build, test
  mix.exs: Elixir → mix credo, compile, test
  composer.json: PHP → phpstan, phpunit
  pubspec.yaml: Dart → dart analyze, test
  build.sbt: Scala → sbt compile, test

priority:
  1: Makefile targets (make lint, make test) if available
  2: Language-specific commands

script: ".claude/scripts/pre-commit-checks.sh"
```

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

**Principle:** More details deeper in tree, <100 lines each (WARNING), <150 (CRITICAL), ALL committed.
