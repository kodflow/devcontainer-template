---
name: docs
description: |
  Documentation Server with Deep Analysis (RLM Multi-Agent).
  Launches N parallel agents to analyze every aspect of the project.
  Scoring mechanism identifies what's important to document.
  Adapts structure based on project type (template vs application).
allowed-tools:
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "Write(docs/**)"
  - "Write(mkdocs.yml)"
  - "Task(*)"
  - "Bash(mkdocs:*)"
  - "Bash(cd:*)"
  - "Bash(mkdir:*)"
  - "Bash(kill:*)"
  - "Bash(pgrep:*)"
  - "Bash(pkill:*)"
  - "Bash(curl:*)"
  - "Bash(sleep:*)"
  - "mcp__grepai__grepai_search"
  - "mcp__grepai__grepai_trace_callers"
  - "mcp__grepai__grepai_trace_callees"
  - "mcp__grepai__grepai_trace_graph"
  - "AskUserQuestion"
---

# /docs - Documentation Server (Deep Analysis)

Generate and serve **comprehensive** project documentation using MkDocs Material.

**Key Difference:** This skill launches **N parallel analysis agents**, each specialized
for a different aspect (languages, commands, hooks, agents, etc.). Results are scored
and consolidated into real, useful documentation.

$ARGUMENTS

---

## Core Principles

```yaml
principles:
  deep_analysis:
    rule: "Launch N agents in parallel, each analyzing independently"
    iterations: "One pass per major category (C iterations)"
    output: "Consolidated results with importance scoring"

  no_superficial_content:
    rule: "NEVER list without explaining"
    bad: "Available commands: /git, /review, /plan"
    good: "### /git - Full workflow with phases, arguments, examples"

  project_specific:
    rule: "Every analysis is unique to THIS project"
    reason: "Questions asked for template ≠ questions for app using template"

  scoring_mechanism:
    rule: "Identify what's IMPORTANT to surface"
    criteria:
      - "Complexity score (1-10): How complex is this component?"
      - "Usage frequency (1-10): How often will users need this?"
      - "Uniqueness (1-10): How specific to this project?"
      - "Documentation gap (1-10): How underdocumented currently?"
    threshold: "Score >= 24 → Include in main docs"

  adaptive_structure:
    template_project: "How to use, languages, commands, agents, hooks"
    library_project: "API reference, usage examples, integration guides"
    application_project: "Architecture, API, deployment, configuration"
```

---

## Arguments

| Argument | Action |
|----------|--------|
| (none) | Deep analysis + generate + serve on :8080 |
| `--update` | Re-analyze and regenerate all documentation |
| `--stop` | Stop running MkDocs server |
| `--status` | Show server status and docs coverage |
| `--port <n>` | Custom port (default: 8080) |
| `--quick` | Skip deep analysis, use cached results |
| `--help` | Show help |

---

## --help

```
═══════════════════════════════════════════════════════════════
  /docs - Documentation Server (Deep Analysis)
═══════════════════════════════════════════════════════════════

  DESCRIPTION
    Generates comprehensive documentation using multi-agent
    parallel analysis. Each agent specializes in one aspect
    (languages, commands, hooks, etc.). Results are scored
    and consolidated into useful documentation.

  USAGE
    /docs [OPTIONS]

  OPTIONS
    (none)              Deep analysis + generate + serve
    --update            Re-analyze and regenerate all
    --stop              Stop running MkDocs server
    --status            Show coverage and server status
    --port <n>          Custom port (default: 8080)
    --quick             Use cached analysis, skip re-scan
    --help              Show this help

  ANALYSIS AGENTS (launched in parallel)
    1. languages-analyzer   Parses install.sh → tools, versions, why
    2. commands-analyzer    Parses commands/*.md → workflows, args
    3. agents-analyzer      Parses agents/*.md → capabilities
    4. hooks-analyzer       Parses lifecycle/*.sh → automation
    5. mcp-analyzer         Parses mcp.json → integrations
    6. patterns-analyzer    Indexes .claude/docs/ → patterns KB
    7. structure-analyzer   Maps codebase → architecture
    8. config-analyzer      Reads env, settings → configuration

  SCORING (what to document)
    Complexity:     1-10 (how complex?)
    Usage:          1-10 (how often needed?)
    Uniqueness:     1-10 (how project-specific?)
    Gap:            1-10 (how underdocumented?)
    Total >= 24     → Primary documentation
    Total 16-23     → Secondary documentation
    Total < 16      → Reference only

  EXAMPLES
    /docs                   # Full analysis + serve
    /docs --update          # Regenerate all docs
    /docs --quick           # Use cache, skip analysis
    /docs --stop            # Stop server

═══════════════════════════════════════════════════════════════
```

**SI `$ARGUMENTS` contient `--help`** : Afficher l'aide ci-dessus et STOP.

---

## Architecture Overview

```
/docs Execution Flow
────────────────────────────────────────────────────────────────

Phase 0: Project Detection
├─ Detect project type (template/library/app/empty)
└─ Choose analysis strategy

Phase 1: Parallel Analysis (N agents in ONE message)
├─ Task(languages-analyzer)  ──┐
├─ Task(commands-analyzer)   ──┤
├─ Task(agents-analyzer)     ──┤ ALL PARALLEL
├─ Task(hooks-analyzer)      ──┤ (single message)
├─ Task(mcp-analyzer)        ──┤
├─ Task(patterns-analyzer)   ──┤
├─ Task(structure-analyzer)  ──┤
└─ Task(config-analyzer)     ──┘

Phase 2: Consolidation
├─ Collect all agent results
├─ Apply scoring formula
├─ Identify high-priority sections
└─ Build documentation structure

Phase 3: Generation
├─ For each scored section:
│   ├─ If score >= 24: Full documentation page
│   ├─ If score 16-23: Summary in parent page
│   └─ If score < 16: Reference link only
└─ Generate nav structure

Phase 4: Serve
└─ Start MkDocs on specified port
```

---

## Phase 0: Project Detection

```yaml
phase_0_detect:
  description: "Identify project type to choose analysis strategy"
  mandatory: true

  detection_signals:
    template_project:
      patterns:
        - ".devcontainer/features/**/install.sh"
        - ".devcontainer/images/.claude/"
        - ".claude/commands/*.md"
      anti_patterns:
        - "src/**/*.{go,py,ts,rs,java,rb,php}"
      result: "PROJECT_TYPE=template"

    library_project:
      patterns:
        - "{package.json,go.mod,Cargo.toml,pyproject.toml}"
        - "src/**/*.{go,py,ts,rs}"
        - "{lib,pkg,src}/**/*"
      anti_patterns:
        - "**/openapi.{yaml,yml,json}"
        - "**/routes/**"
      result: "PROJECT_TYPE=library"

    application_project:
      patterns:
        - "src/**/*.{go,py,ts,rs}"
        - "**/openapi.{yaml,yml,json}"
        - "{cmd,app,server,api}/**/*"
      result: "PROJECT_TYPE=application"

    empty_project:
      patterns:
        - "Only CLAUDE.md and basic files"
      result: "PROJECT_TYPE=empty"

  output:
    project_type: "template | library | application | empty"
    analysis_agents: "[list of agents to launch based on type]"
```

---

## Phase 1: Parallel Analysis Agents

**CRITICAL:** Launch ALL agents in a SINGLE message with multiple Task calls.

### Agent 1: Languages Analyzer

```yaml
languages_analyzer:
  trigger: "PROJECT_TYPE in [template, library, application]"
  subagent_type: "Explore"
  model: "haiku"

  prompt: |
    Analyze ALL language features in .devcontainer/features/languages/.

    For EACH language directory found:
    1. Read devcontainer-feature.json (version, options)
    2. Read install.sh (extract ALL tools installed with versions)
    3. Read RULES.md if exists (conventions)

    Extract for each language:
    - Version strategy (latest/LTS/configurable)
    - Package manager
    - Linters with versions
    - Formatters
    - Test tools
    - Security tools
    - Desktop/WASM support
    - Why these specific tools were chosen

    Return structured summary with scoring:
    - Complexity (1-10): How complex is this language setup?
    - Usage (1-10): How often will devs use this?
    - Uniqueness (1-10): How specific to this template?
    - Gap (1-10): How underdocumented is this?
```

### Agent 2: Commands Analyzer

```yaml
commands_analyzer:
  trigger: "Always"
  subagent_type: "Explore"
  model: "haiku"

  prompt: |
    Analyze ALL Claude commands/skills in:
    - .claude/commands/
    - .devcontainer/images/.claude/commands/

    For EACH .md file found:
    1. Extract command name from YAML frontmatter
    2. Extract description
    3. Parse arguments table
    4. Identify workflow phases (from headers/content)
    5. Extract when to use
    6. Find example usages

    Return for each command:
    - Name (/git, /review, etc.)
    - Description (one-liner)
    - Arguments with descriptions
    - Workflow phases in order
    - When to use this command
    - Example usage snippets

    Include scoring for the commands system overall.
```

### Agent 3: Agents Analyzer

```yaml
agents_analyzer:
  trigger: "PROJECT_TYPE == template OR .claude/agents/ exists"
  subagent_type: "Explore"
  model: "haiku"

  prompt: |
    Analyze ALL specialist agents in .devcontainer/images/.claude/agents/.

    For EACH .md file:
    1. Extract agent name from filename
    2. Read content for specialization
    3. Identify model used (opus/sonnet/haiku from frontmatter)
    4. List tools available (from allowed-tools)
    5. When is this agent invoked

    Categorize agents:
    - Language specialists (developer-specialist-*)
    - DevOps specialists (devops-specialist-*)
    - Executors (developer-executor-*, devops-executor-*)
    - Orchestrators (developer-orchestrator, devops-orchestrator)

    Return structured inventory with counts per category.
```

### Agent 4: Hooks Analyzer

```yaml
hooks_analyzer:
  trigger: "PROJECT_TYPE == template OR .devcontainer/hooks/ exists"
  subagent_type: "Explore"
  model: "haiku"

  prompt: |
    Analyze ALL hooks in .devcontainer/hooks/.

    For EACH .sh file in lifecycle/:
    1. Read file content completely
    2. Extract trigger (which devcontainer.json field)
    3. List key operations (from comments and code analysis)
    4. Identify files created/modified

    Also analyze shared/utils.sh:
    - List all utility functions
    - What each function does

    Return execution order and dependencies between hooks.
```

### Agent 5: MCP Analyzer

```yaml
mcp_analyzer:
  trigger: "mcp.json exists"
  subagent_type: "Explore"
  model: "haiku"

  prompt: |
    Analyze MCP server configuration:
    - /workspace/mcp.json (active config)
    - .devcontainer/features/claude/.mcp.json (template)
    - .devcontainer/images/mcp.json.tpl (source template)

    For EACH server configured:
    1. Server name
    2. Command to run
    3. Authentication method (env var names)
    4. List ALL tools provided by this server
    5. When to use (from CLAUDE.md rules)

    Document the MCP-FIRST and GREPAI-FIRST rules.
```

### Agent 6: Patterns Analyzer

```yaml
patterns_analyzer:
  trigger: ".claude/docs/ OR .devcontainer/images/.claude/docs/ exists"
  subagent_type: "Explore"
  model: "haiku"

  prompt: |
    Analyze design patterns knowledge base in .devcontainer/images/.claude/docs/.

    1. Read main README.md for structure
    2. Count patterns per category (from directory listing)
    3. List all categories with their purpose
    4. Identify template files for pattern documentation
    5. Find the most important/commonly used patterns

    Return inventory:
    - Total pattern count
    - Categories with counts
    - Template structure
    - How patterns are used by /plan and /review
```

### Agent 7: Structure Analyzer

```yaml
structure_analyzer:
  trigger: "Always"
  subagent_type: "Explore"
  model: "haiku"

  prompt: |
    Map the complete project structure:

    1. Directory tree (depth 3 max)
    2. Purpose of each major directory
    3. CLAUDE.md hierarchy (funnel documentation)
    4. Technology stack detected
    5. Entry points and main files
    6. Build/config files present

    For template projects, focus on:
    - features/ structure
    - images/ structure
    - hooks/ structure

    For application projects, focus on:
    - src/ structure
    - API definitions
    - Configuration files
```

### Agent 8: Config Analyzer

```yaml
config_analyzer:
  trigger: "Always"
  subagent_type: "Explore"
  model: "haiku"

  prompt: |
    Analyze all configuration:

    1. Find .env, .env.example files
    2. Parse devcontainer.json settings
    3. Extract docker-compose.yml services
    4. Identify required vs optional config
    5. Document environment variables

    Return:
    - Required configuration (must-have)
    - Optional configuration (nice-to-have)
    - Secrets/tokens needed
    - Default values
```

---

## Phase 2: Consolidation and Scoring

```yaml
phase_2_consolidation:
  description: "Merge agent results and apply scoring"

  scoring_formula:
    total: "complexity + usage + uniqueness + gap"
    thresholds:
      primary: ">= 24 (full documentation page)"
      secondary: "16-23 (summary section)"
      reference: "< 16 (link only)"

  consolidation_steps:
    1_collect:
      action: "Gather all agent JSON results"

    2_deduplicate:
      action: "Merge overlapping information"

    3_score:
      action: "Calculate total score per component"

    4_prioritize:
      action: "Sort by score descending"

    5_structure:
      action: "Build documentation tree"

  output_structure_template:
    docs_root:
      - "index.md (always)"
      - "getting-started/ (score >= 24)"
      - "languages/ (if template, score >= 24)"
      - "commands/ (score >= 24)"
      - "agents/ (if template, score >= 20)"
      - "automation/ (hooks + mcp, score >= 20)"
      - "patterns/ (if KB exists, score >= 16)"
      - "reference/ (aggregated low-score items)"
```

---

## Phase 3: Content Generation

```yaml
phase_3_generate:
  description: "Generate documentation from consolidated results"

  rules:
    no_placeholders:
      - "NEVER write 'Coming Soon'"
      - "NEVER write 'TBD' or 'TODO'"
      - "NEVER create empty sections"

    content_requirements:
      - "Every page must have real content"
      - "Every code block must be functional"
      - "Every table must have data"

    extraction_priority:
      - "Use agent-extracted data directly"
      - "Quote from source files when appropriate"
      - "Link to source files for details"

  generation_by_project_type:

    template:
      structure:
        index.md: "What is this template, Quick Start, What's Included"
        getting-started/:
          README.md: "Installation, First Steps"
          workflow.md: "Feature development workflow"
        languages/:
          README.md: "Overview of all 12 languages"
          "{lang}.md": "One page per language with tools table"
        commands/:
          README.md: "Overview of all commands"
          "{cmd}.md": "One page per command with full details"
        agents/:
          README.md: "Agent architecture overview"
          language-specialists.md: "All 12 language agents"
          devops-specialists.md: "All 8+ devops agents"
          executors.md: "All executor agents"
        automation/:
          README.md: "Automation overview"
          hooks.md: "All lifecycle hooks detailed"
          mcp-servers.md: "All MCP integrations"
        patterns/:
          README.md: "Design patterns KB overview"
          by-category.md: "Patterns organized by category"
        reference/:
          conventions.md: "Coding conventions"
          troubleshooting.md: "Common issues"

    library:
      structure:
        index.md: "What is this library, Quick Start"
        api/:
          README.md: "API overview"
          "{module}.md": "Per-module documentation"
        examples/:
          README.md: "Example index"
          "{example}.md": "Each example explained"
        guides/:
          installation.md: "Installation guide"
          usage.md: "Usage patterns"

    application:
      structure:
        index.md: "What is this app, Quick Start"
        architecture/:
          README.md: "Architecture overview"
          components.md: "Component breakdown"
        api/:
          README.md: "API reference"
          endpoints.md: "Endpoint documentation"
        deployment/:
          README.md: "Deployment guide"
          configuration.md: "Configuration reference"
        guides/:
          README.md: "User guides"
```

---

## Phase 4: Serve

```yaml
phase_4_serve:
  description: "Start MkDocs server"

  pre_check:
    - "pkill -f 'mkdocs serve' 2>/dev/null || true"

  command: "mkdocs serve -a 0.0.0.0:{PORT}"

  output_template: |
    ═══════════════════════════════════════════════════════════════
      /docs - Server Running (Deep Analysis Complete)
    ═══════════════════════════════════════════════════════════════

      Project Type: {PROJECT_TYPE}
      Analysis:     {N} agents completed

      URL: http://localhost:{PORT}

      Generated Sections (by score):
      {SECTIONS_WITH_SCORES}

      Commands:
        /docs --update      Re-analyze and regenerate
        /docs --stop        Stop server
        /docs --status      Show coverage stats

    ═══════════════════════════════════════════════════════════════
```

---

## Mode --stop

```yaml
stop:
  command: "pkill -f 'mkdocs serve'"
  output: "Server stopped. Restart: /docs"
```

---

## Mode --status

```yaml
status:
  checks:
    - "Server running? (pgrep -f 'mkdocs serve')"
    - "Docs structure exists? (ls docs/)"
    - "Content files count"
    - "Last analysis timestamp"

  output_template: |
    Server:     {RUNNING|STOPPED}
    Structure:  {EXISTS|MISSING}
    Pages:      {N} files
    Coverage:   {PERCENTAGE}%
    Last scan:  {TIMESTAMP}
```

---

## Mode --quick

```yaml
quick:
  description: "Skip deep analysis, use existing docs"

  workflow:
    1_check_cache: "Verify docs/ exists with content"
    2_skip_analysis: "Don't launch analysis agents"
    3_serve_directly: "Start MkDocs immediately"

  use_case: "Fast iteration when docs already generated"
```

---

## GARDE-FOUS (ABSOLUS)

| Action | Status | Raison |
|--------|--------|--------|
| Créer page vide/placeholder | ❌ **INTERDIT** | UX cassée |
| Lancer agents séquentiellement | ❌ **INTERDIT** | Performance dégradée |
| Skip scoring | ❌ **INTERDIT** | Perte de priorisation |
| Générer sans analyse | ❌ **INTERDIT** | Contenu superficiel |
| "Coming Soon" / "TBD" | ❌ **INTERDIT** | Promesses vides |
| Créer section score < 16 standalone | ❌ **INTERDIT** | Pollution navigation |
| Ignorer PROJECT_TYPE | ❌ **INTERDIT** | Structure inadaptée |

---

## MkDocs Configuration

```yaml
# mkdocs.yml (generated at project root)
site_name: "{PROJECT_NAME}"
docs_dir: docs
site_description: "{GENERATED_DESCRIPTION}"

theme:
  name: material
  palette:
    - scheme: slate
      primary: deep purple
      accent: purple
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
    - scheme: default
      primary: deep purple
      accent: purple
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.expand
    - navigation.top
    - search.suggest
    - search.highlight
    - content.code.copy
    - content.tabs.link

plugins:
  - search

markdown_extensions:
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.inlinehilite
  - pymdownx.snippets
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - admonition
  - pymdownx.details
  - pymdownx.tabbed:
      alternate_style: true
  - tables
  - toc:
      permalink: true

nav:
  # GENERATED FROM PHASE 3
  # Only sections with score >= threshold
```

---

## Validation

```yaml
validation:
  before_serve:
    - "Every nav entry points to existing file"
    - "No file < 20 lines (likely placeholder)"
    - "No 'TODO', 'TBD', 'Coming Soon' in content"
    - "All code blocks have language tag"
    - "All internal links resolve"

  warnings:
    - "File > 300 lines → suggest splitting"
    - "Missing code examples"
    - "Missing tables in reference pages"
```

---

## Error Messages

```yaml
errors:
  analysis_failed:
    message: |
      ⚠️ Analysis agent failed: {AGENT_NAME}

      Error: {ERROR_MESSAGE}

      Continuing with partial results...

  empty_section_detected:
    message: |
      ⚠️ Empty section detected: {SECTION}

      Score: {SCORE}/40

      This section has no real content.
      Moving to reference section.
```
