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
for a different aspect (languages, commands, hooks, agents, architecture, etc.).
Results are scored and consolidated into real, useful documentation with Mermaid
diagrams, concrete examples, and progressive architecture zoom.

$ARGUMENTS

---

## Core Principles

```yaml
principles:
  deep_analysis:
    rule: "Launch N agents in parallel, each analyzing independently"
    iterations: "One pass per major category (9 parallel agents = 9 iterations)"
    output: "Consolidated results with importance scoring"

  no_superficial_content:
    rule: "NEVER list without explaining"
    bad: "Available commands: /git, /review, /plan"
    good: "### /git - Full workflow with phases, arguments, examples"

  product_pitch_first:
    rule: "index.md MUST answer 'What problem does this solve?' before anything technical"
    structure: "Problem → Solution → Key features → Quick start → What's inside → Support"
    reason: "Readers decide in 30 seconds if the project is relevant to them"
    entry_point: "Landing page provides: About, Access, Usage, Resources, Support"

  progressive_zoom:
    rule: "Architecture docs follow Google Maps analogy: macro → micro"
    levels:
      - "Level 1: System context — big blocks, external dependencies"
      - "Level 2: Components — modules, services, their roles"
      - "Level 3: Internal — implementation details, algorithms, data structures"
    reason: "Reader picks the zoom level they need"

  diagrams_mandatory:
    rule: "Every architecture or flow page MUST include at least one Mermaid diagram"
    types: ["flowchart", "sequence", "C4 context", "ER diagram", "state machine"]
    reason: "Visual comprehension is 60,000x faster than text"

  link_dont_copy:
    rule: "Reference source files via links, not inline copies"
    bad: "```yaml\n# Copy of docker-compose.yml\nservices:\n  app: ...\n```"
    good: "See [`docker-compose.yml`](../docker-compose.yml) for full service definition."
    reason: "Copied content desynchronizes immediately"

  project_specific:
    rule: "Every analysis is unique to THIS project"
    reason: "Questions asked for template != questions for app using template"

  scoring_mechanism:
    rule: "Identify what's IMPORTANT to surface"
    criteria:
      - "Complexity (1-10): How complex is this component?"
      - "Usage frequency (1-10): How often will users need this?"
      - "Uniqueness (1-10): How specific to this project?"
      - "Documentation gap (1-10): How underdocumented currently?"
      - "Diagram bonus (+3): complexity >= 7 AND no diagram exists yet"
    thresholds:
      primary: "Score >= 24 → full page + mandatory diagram"
      standard: "Score 16-23 → own page, diagram recommended"
      reference: "Score < 16 → aggregated in reference section"

  adaptive_structure:
    template_project: "How to use, languages, commands, agents, hooks"
    library_project: "API reference, usage examples, integration guides, internal architecture"
    application_project: "Architecture, API, deployment, data flow, cluster, configuration"
```

---

## Arguments

| Argument | Action |
|----------|--------|
| (none) | Freshness check → incremental or full analysis → serve on :8080 |
| `--update` | Force full re-analysis, ignore freshness (regenerate everything) |
| `--stop` | Stop running MkDocs server |
| `--status` | Show freshness report, stale pages, server status |
| `--port <n>` | Custom port (default: 8080) |
| `--quick` | Skip analysis entirely, serve existing docs as-is |
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
    (languages, commands, hooks, architecture, etc.). Results
    are scored and consolidated into rich documentation with
    Mermaid diagrams and progressive architecture zoom.

  USAGE
    /docs [OPTIONS]

  OPTIONS
    (none)              Freshness check + incremental/full + serve
    --update            Force full regeneration (ignore freshness)
    --stop              Stop running MkDocs server
    --status            Freshness report + stale pages + server status
    --port <n>          Custom port (default: 8080)
    --quick             Serve existing docs as-is, skip analysis
    --help              Show this help

  ANALYSIS AGENTS (launched in parallel)
    1. languages-analyzer     install.sh → tools, versions, why
    2. commands-analyzer      commands/*.md → workflows, args
    3. agents-analyzer        agents/*.md → capabilities
    4. hooks-analyzer         lifecycle/*.sh → automation
    5. mcp-analyzer           mcp.json → integrations
    6. patterns-analyzer      .claude/docs/ → patterns KB
    7. structure-analyzer     codebase → directory map
    8. config-analyzer        env, settings → configuration
    9. architecture-analyzer  code → components, flows, protocols

  SCORING (what to document)
    Complexity:     1-10 (how complex?)
    Usage:          1-10 (how often needed?)
    Uniqueness:     1-10 (how project-specific?)
    Gap:            1-10 (how underdocumented?)
    Diagram bonus:  +3 (complexity >= 7, no diagram yet)
    Total >= 24     → Primary (full page + mandatory diagram)
    Total 16-23     → Standard (own page, diagram recommended)
    Total < 16      → Reference (aggregated)

  EXAMPLES
    /docs                   # Freshness check → update stale pages → serve
    /docs --update          # Force full regeneration from scratch
    /docs --status          # Show what's stale without regenerating
    /docs --quick           # Serve existing docs immediately
    /docs --stop            # Stop server

═══════════════════════════════════════════════════════════════
```

**SI `$ARGUMENTS` contient `--help`** : Afficher l'aide ci-dessus et STOP.

---

## Template Variables

All `{VARIABLE}` placeholders used in output templates and generated files:

```yaml
variables:
  # Derived from project analysis (Phase 0-1)
  PROJECT_NAME: "From CLAUDE.md title, package.json name, go.mod module, or git repo name"
  PROJECT_TYPE: "template | library | application | empty (detected in Phase 0)"
  GENERATED_DESCRIPTION: "2-3 sentence summary synthesized from agent analysis results"

  # Derived from scoring (Phase 2)
  SECTIONS_WITH_SCORES: "Formatted list: section name + score, sorted descending"

  # Derived from agent results (Phase 1)
  N: "Number of analysis agents that completed successfully"
  D: "Total count of Mermaid diagrams generated across all pages"

  # Derived from git (Phase 0)
  GIT_REMOTE_URL: "From git remote get-url origin (for repo_url in mkdocs.yml)"
  REPO_NAME: "Auto-detected from remote URL host (GitHub/GitLab/Bitbucket)"

  # Freshness (Phase 0.5)
  LAST_COMMIT_SHA: "Git SHA from generation marker in docs/index.md"
  MARKER_DATE: "ISO8601 date from generation marker"
  MARKER_COMMIT: "Short SHA from generation marker"
  DAYS_AGO: "Days since last generation"
  COMMITS_SINCE: "Number of commits between marker SHA and HEAD"
  CHANGED_COUNT: "Number of files changed since marker commit"
  STALE_COUNT: "Number of doc pages affected by changed files"
  STALE_LIST: "Formatted list of stale page paths"
  BROKEN_COUNT: "Number of broken internal links in docs/"
  BROKEN_LIST: "Formatted list of broken links with source page"
  OUTDATED_COUNT: "Number of dependency version mismatches"
  OUTDATED_LIST: "Formatted list: dep name, docs version vs actual version"
  TOTAL_PAGES: "Total number of pages in docs/"

  # User-configurable
  PORT: "MkDocs serve port (default: 8080, override with --port)"

  # Runtime
  RUNNING: "pgrep -f 'mkdocs serve' returns 0"
  STOPPED: "pgrep -f 'mkdocs serve' returns non-zero"
  TIMESTAMP: "date -Iseconds of last analysis run"
  PERCENTAGE: "(pages_with_content / total_nav_entries) * 100"
```

---

## Architecture Overview

```
/docs Execution Flow
────────────────────────────────────────────────────────────────

Phase 0: Project Detection
├─ Detect project type (template/library/app/empty)
└─ Choose analysis strategy + agent list

Phase 0.5: Freshness Check
├─ Read generation marker from docs/index.md
├─ git diff <last_sha>..HEAD → changed files
├─ Map changed files → stale doc pages
├─ Check broken links + outdated deps
└─ Decision: INCREMENTAL (stale pages only) or FULL

Phase 1: Parallel Analysis (9 agents in ONE message)
├─ Task(languages-analyzer)     ──┐
├─ Task(commands-analyzer)      ──┤
├─ Task(agents-analyzer)        ──┤
├─ Task(hooks-analyzer)         ──┤ ALL PARALLEL
├─ Task(mcp-analyzer)           ──┤ (single message)
├─ Task(patterns-analyzer)      ──┤
├─ Task(structure-analyzer)     ──┤
├─ Task(config-analyzer)        ──┤
└─ Task(architecture-analyzer)  ──┘

Phase 2: Consolidation + Scoring
├─ Collect all agent results
├─ Build dependency DAG, topological sort
├─ Apply scoring formula (with diagram bonus)
├─ Identify high-priority sections
└─ Build documentation tree

Phase 3: Content Generation (dependency order)
├─ Generate index.md (product pitch first)
├─ For each scored section:
│   ├─ If score >= 24: Primary — full page + mandatory diagram
│   ├─ If score 16-23: Standard — own page, diagram recommended
│   └─ If score < 16: Reference — aggregated in reference section
├─ Generate architecture pages (C4 progressive zoom)
└─ Generate nav structure

Phase 4: Verification (DocAgent-inspired)
├─ Verify: completeness, accuracy, quality, no placeholders
├─ Feedback loop: fix issues and re-verify (max 2 iterations)
└─ Proceed with warnings if max iterations reached

Phase 5: Serve
├─ Final checks
└─ Start MkDocs on specified port
```

---

## Phase 0: Project Detection

```yaml
phase_0_detect:
  description: "Identify project type and handle existing docs/"
  mandatory: true

  existing_docs_handling:
    check: "ls docs/ 2>/dev/null"
    decision:
      if_mkdocs_generated:
        signal: "docs/ contains mkdocs-generated content (index.md with '<!-- generated by /docs -->')"
        action: "Overwrite — regenerate all content"
        message: "Previous /docs output detected. Regenerating..."
      if_user_content:
        signal: "docs/ contains files without generation marker (from /init or manual)"
        action: "Preserve user files in docs/_preserved/, generate around them"
        message: "Existing documentation found. Preserving user content in docs/_preserved/."
      if_empty_or_missing:
        action: "Create docs/ fresh"

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

## Phase 0.5: Freshness Check

```yaml
phase_05_freshness:
  description: "Detect stale docs and decide incremental vs full regeneration"
  skip_if: "--update flag (force full) OR no docs/ exists (first run)"

  generation_marker:
    location: "First line of docs/index.md"
    format: "<!-- /docs-generated: {JSON} -->"
    fields:
      date: "ISO8601 timestamp of last generation"
      commit: "Git SHA at time of generation"
      pages: "Number of pages generated"
      agents: "Number of agents used"
    example: '<!-- /docs-generated: {"date":"2026-02-06T14:30:00Z","commit":"abc1234","pages":12,"agents":9} -->'

  freshness_checks:
    1_code_drift:
      command: "git diff --name-only {marker.commit}..HEAD"
      output: "List of files changed since last generation"
      mapping: |
        For each changed file, find doc pages that reference it:
        - Grep docs/*.md for the filename
        - Mark matching pages as STALE

    2_broken_links:
      action: |
        For each relative link in docs/*.md:
          Check if target file exists on disk
        For each code path mentioned in docs:
          Check if the path still exists
      output: "List of broken internal links"

    3_outdated_deps:
      action: |
        Compare versions mentioned in docs vs actual:
        - package.json dependencies vs docs mentions
        - go.mod versions vs docs mentions
        - Cargo.toml versions vs docs mentions
        - install.sh versions vs docs mentions
      output: "List of version mismatches"

    4_dead_external_links:
      action: |
        For each external URL in docs/*.md:
          curl -s -o /dev/null -w "%{http_code}" <url>
          → 404 = DEAD, 301 = MOVED, 200 = OK
      output: "List of dead/moved external links"
      note: "Only check if < 50 external links (avoid rate limiting)"

  decision:
    if_no_marker:
      action: "FULL generation (first run)"
    if_zero_stale:
      action: "SKIP analysis, serve existing docs"
      message: "Docs are up to date (last generated {date}, {commits} commits, 0 stale)."
    if_stale_pages:
      action: "INCREMENTAL — only re-analyze and regenerate stale pages"
      optimization: |
        Only launch agents whose scope covers the changed files:
        - src/ changed → architecture-analyzer
        - commands/ changed → commands-analyzer
        - hooks/ changed → hooks-analyzer
        - package.json changed → config-analyzer + dependencies
        - etc.
    if_update_flag:
      action: "FULL generation regardless of freshness"

  output_template: |
    ═══════════════════════════════════════════════════════════════
      /docs - Freshness Check
    ═══════════════════════════════════════════════════════════════

      Last generated : {MARKER_DATE} ({DAYS_AGO} days ago)
      Last commit    : {MARKER_COMMIT} → HEAD ({COMMITS_SINCE} commits)

      Code drift:
        Changed files  : {CHANGED_COUNT}
        Stale pages    : {STALE_COUNT} / {TOTAL_PAGES}
        {STALE_LIST}

      Broken links   : {BROKEN_COUNT}
        {BROKEN_LIST}

      Outdated deps  : {OUTDATED_COUNT}
        {OUTDATED_LIST}

      Decision: {INCREMENTAL|FULL|UP_TO_DATE}
        → {ACTION_DESCRIPTION}

    ═══════════════════════════════════════════════════════════════
```

---

## Phase 1: Parallel Analysis Agents

**CRITICAL:** Launch ALL agents in a SINGLE message with multiple Task calls.
**INCREMENTAL MODE:** Only launch agents whose scope covers stale pages.

### Agent 1: Languages Analyzer

```yaml
languages_analyzer:
  trigger: "PROJECT_TYPE in [template, library, application]"
  subagent_type: "Explore"
  model: "opus"

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
  model: "opus"

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
  model: "opus"

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
  model: "opus"

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
  model: "opus"

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
  model: "opus"

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
  model: "opus"

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
  model: "opus"

  prompt: |
    Analyze all configuration:

    1. Find .env, .env.example files
    2. Parse devcontainer.json settings
    3. Extract docker-compose.yml services and volumes
    4. Identify required vs optional config
    5. Document environment variables
    6. List exposed ports and their purpose
    7. Identify secrets/tokens needed and their source

    Return:
    - Required configuration (must-have)
    - Optional configuration (nice-to-have)
    - Secrets/tokens needed with source (env var, 1Password, etc.)
    - Default values
    - Network configuration (ports, services, volumes)
```

### Agent 9: Architecture Analyzer (NEW)

```yaml
architecture_analyzer:
  trigger: "PROJECT_TYPE in [library, application] OR src/ exists"
  subagent_type: "Explore"
  model: "opus"
  reason: "Deep reasoning for architecture analysis"

  c4_best_practices:
    - "Levels 1-2 provide most value; Levels 3-4 need more maintenance for smaller audiences"
    - "Focus on elements difficult to discover from code alone: coordination, business rules, non-obvious dependencies"
    - "Link to READMEs, ADRs, and repository docs — don't duplicate generated content (OpenAPI, AsyncAPI)"
    - "Keep diagrams lightweight — add numbered relationships for flow instead of separate dynamic diagrams"
    - "Match diagrams to how the organization actually understands the system, not just technical boundaries"
    - "Consider landscape diagrams as entry point for small-to-medium architectures"

  prompt: |
    Deep architecture analysis of the project. Produce a MULTI-LEVEL
    progressive zoom analysis following C4 Model best practices.

    ## C4 Guidelines
    - Levels 1-2 provide the most value; only go deeper for complex components
    - Focus on what's hard to discover from code alone: coordination patterns,
      business rules, non-obvious data dependencies
    - Link to source files (READMEs, ADRs, OpenAPI specs) — never duplicate
      content already generated by specialized tools
    - Keep diagrams lightweight; add numbered relationships for flow clarity
    - Match diagram boundaries to how the team understands the system

    ## Level 1: System Context (C4 Context)
    - What are the major blocks/services?
    - What external systems does this project depend on?
    - What is the boundary of the system?
    - Generate a Mermaid C4 context diagram
    - Consider a landscape diagram for small-to-medium projects

    ## Level 2: Containers (C4 Container)
    For EACH major block identified in Level 1:
    - What deployable units (apps, services, databases) compose it?
    - What is each unit's responsibility?
    - How do they communicate? (protocols, formats)
    - Generate a Mermaid container diagram with numbered flows
    - Include deployment details directly (pragmatic over separate diagrams)

    ## Level 3: Components (C4 Component — only for complex blocks)
    For key components (most complex or most used):
    - Internal modules and their responsibilities
    - Key design patterns used (reference .claude/docs/ if available)
    - Error handling strategy
    - Performance considerations

    ## Data Flow Analysis
    - Trace the main data flows through the system
    - Identify ALL communication protocols:
      HTTP/HTTPS, gRPC, WebSocket, AMQP, MQTT, etc.
    - Identify ALL data formats:
      JSON, YAML, Protobuf, XML, MessagePack, etc.
    - For each API endpoint found (OpenAPI, routes, handlers):
      Document request/response formats with field descriptions
    - Generate a Mermaid sequence diagram for the primary flow

    ## Cluster & Scalability (if applicable)
    Detect signals: docker-compose replicas, K8s manifests, load balancer
    config, consensus code (Raft, Paxos), replication settings.
    If found:
    - Describe the scaling strategy (horizontal/vertical)
    - Recommended minimum node configuration
    - Data replication approach
    - Fault tolerance mechanisms
    - Network best practices (TLS between services, segmentation)

    ## Secondary Features Detection
    Search for non-obvious features embedded in the code:
    - Consensus mechanisms (Raft, Paxos, PBFT)
    - Caching layers (Redis, in-memory, CDN)
    - Event sourcing / CQRS patterns
    - Rate limiting, circuit breakers
    - Observability (metrics, tracing, logging)
    For each detected: explain what it does, why it exists, how it works.

    ## Output Format
    Return structured JSON with:
    - levels: [level1, level2, level3] each with components and diagrams
    - data_flows: [{name, source, destination, protocol, format}]
    - apis: [{path, method, request_format, response_format, description}]
    - cluster: {strategy, min_nodes, replication, fault_tolerance} or null
    - secondary_features: [{name, purpose, mechanism, files}]
    - diagrams: [{type, title, mermaid_code}]

    Scoring:
    - Complexity (1-10)
    - Usage (1-10)
    - Uniqueness (1-10)
    - Gap (1-10)
```

---

## Phase 2: Consolidation and Scoring

```yaml
phase_2_consolidation:
  description: "Merge agent results and apply enhanced scoring"

  scoring_formula:
    base: "complexity + usage + uniqueness + gap"
    diagram_bonus: "+3 if complexity >= 7 AND no diagram exists yet"
    total_max: 43
    thresholds:
      primary: ">= 24 (full page + mandatory Mermaid diagram)"
      standard: "16-23 (own page, diagram recommended)"
      reference: "< 16 (aggregated in reference section)"

  diagram_requirement:
    rule: |
      IF score >= 24 AND component is architectural:
        MUST include at least one Mermaid diagram
      IF score >= 24 AND component has data flow:
        MUST include sequence or flowchart diagram
      IF cluster/scaling detected:
        MUST include deployment diagram

  # DocAgent-inspired: dependencies-first ordering ensures components are
  # documented only after their dependencies have been processed.
  dependency_ordering:
    rule: "Topological sort of component dependencies before content generation"
    reason: "A module's docs can reference its dependency's docs via links"
    implementation:
      - "Build dependency DAG from agent results (imports, calls, data flow)"
      - "Topological sort → processing order for Phase 3"
      - "Earlier components provide context for later ones"

  consolidation_steps:
    1_collect:
      action: "Gather all agent JSON results"

    2_deduplicate:
      action: "Merge overlapping information (structure + architecture)"

    3_score:
      action: "Calculate total score per component with diagram bonus"

    4_prioritize:
      action: "Sort by score descending, then by dependency order"

    5_identify_diagrams:
      action: "For each primary section, determine required diagram types"

    6_structure:
      action: "Build documentation tree adapted to PROJECT_TYPE"

  output_structure:
    common:
      - "index.md (always — product pitch format)"
      - "architecture/ (if application/library, primary: score >= 24)"
    template:
      - "getting-started/ (primary: score >= 24)"
      - "languages/ (primary: score >= 24)"
      - "commands/ (primary: score >= 24)"
      - "agents/ (standard: score >= 16)"
      - "automation/ (hooks + mcp, standard: score >= 16)"
      - "patterns/ (if KB exists, standard: score >= 16)"
      - "reference/ (aggregated: score < 16)"
    application:
      - "architecture/ (always for app)"
      - "api/ (if endpoints detected)"
      - "deployment/ (if cluster/docker detected)"
      - "guides/ (standard: score >= 16)"
      - "reference/ (aggregated: score < 16)"
    library:
      - "architecture/ (if complex internal structure)"
      - "api/ (always for library)"
      - "examples/ (standard: score >= 16)"
      - "guides/ (standard: score >= 16)"
      - "reference/ (aggregated: score < 16)"
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
      - "Every page must have real content from agent analysis"
      - "Every code block must be functional"
      - "Every table must have data"
      - "Every architecture page must have at least one Mermaid diagram"
      - "Every flow description must have a sequence or flowchart diagram"

    link_not_copy:
      - "Reference source files via relative links"
      - "NEVER copy entire config files inline"
      - "Quote only the relevant excerpt (max 15 lines) with link to full file"

    editorial_rules:
      - "No generic filler: 'This module handles X' → explain HOW it handles X"
      - "Every section must contain information extractable ONLY from this project"
      - "Prefer 'The auth module exposes /login and /logout, uses JWT stored in Redis'"
      - "Over 'The auth module manages authentication'"

  #---------------------------------------------------------------------------
  # DOCUMENTATION PHILOSOPHY (Divio System)
  #---------------------------------------------------------------------------
  # Every page falls into one of four categories (never mix them):
  #   Tutorial    → learning-oriented, practical steps for beginners
  #   How-to      → task-oriented, steps for working developers
  #   Reference   → factual, structured lookup during active work
  #   Explanation → theoretical, conceptual understanding
  # Maintaining clear boundaries prevents "gravitational pull" toward
  # merging types, which degrades both author and reader experience.
  #---------------------------------------------------------------------------

  #---------------------------------------------------------------------------
  # UNIVERSAL TEMPLATES (applied to all project types)
  #---------------------------------------------------------------------------
  universal_templates:

    index_md:
      description: "Product pitch landing page — readers decide in 30 seconds"
      # Inspired by: product documentation best practices (entry point pattern)
      # Provides: About, Access, Usage, Resources, Support
      generation_marker:
        first_line: '<!-- /docs-generated: {"date":"{TIMESTAMP}","commit":"{LAST_COMMIT_SHA}","pages":{TOTAL_PAGES},"agents":{N}} -->'
        rule: "ALWAYS insert as first line of index.md — enables freshness detection"
      structure:
        - "<!-- /docs-generated: {JSON_MARKER} -->"
        - "# {PROJECT_NAME}"
        - ""
        - "## What is this?"
        - "{2-3 sentences: what problem it solves, for whom}"
        - "{One sentence: who the target users are}"
        - ""
        - "## Key Features"
        - "{Bullet list of 5-8 major capabilities with one-line explanations}"
        - "{Each feature answers 'what does this DO for me?'}"
        - ""
        - "## How it works"
        - "{Mermaid flowchart: high-level system overview}"
        - "{2-3 sentences explaining the diagram}"
        - ""
        - "## Quick Start"
        - "{3-5 numbered steps to get running, with code blocks}"
        - "{Each step has expected output or verification}"
        - ""
        - "## What's Inside"
        - "{Table: component → description → doc type (Tutorial/Guide/Reference) → link}"
        - ""
        - "## Support"
        - "{Links: issues, discussions, contributing guide}"
      anti_patterns:
        - "Starting with technical details before the pitch"
        - "Listing features without explaining their benefit"
        - "Quick start that requires more than 5 steps"
        - "Missing verification step after quick start"

    architecture_overview_md:
      description: "Level 1 zoom — system context, big picture"
      structure:
        - "# Architecture Overview"
        - ""
        - "## System Context"
        - "{Mermaid C4 context diagram: system + external dependencies}"
        - "{Paragraph explaining the diagram and key interactions}"
        - ""
        - "## Major Components"
        - "{Table: component → responsibility → technology → link}"
        - ""
        - "## Technology Stack"
        - "{Table: category → tool → version → purpose}"

    architecture_components_md:
      description: "Level 2 zoom — inside each major block"
      structure:
        - "# Components"
        - ""
        - "For EACH major component:"
        - "## {Component Name}"
        - "{Mermaid component diagram showing internal modules}"
        - "{Paragraph explaining the component's role}"
        - "### Modules"
        - "{Table: module → responsibility → key files}"
        - "### Dependencies"
        - "{List of internal and external dependencies}"

    architecture_flow_md:
      description: "Data flows and communication patterns"
      structure:
        - "# Data Flow"
        - ""
        - "## Primary Flow"
        - "{Mermaid sequence diagram: main user journey}"
        - "{Step-by-step explanation of the flow}"
        - ""
        - "## Communication Protocols"
        - "{Table: source → destination → protocol → format → purpose}"
        - ""
        - "## API Endpoints"
        - "{For each endpoint: method, path, request/response format, description}"
        - "{Link to OpenAPI spec if exists}"

    architecture_deployment_md:
      description: "Cluster, scaling, network — only if detected"
      condition: "cluster/scaling signals detected by architecture-analyzer"
      structure:
        - "# Deployment & Scaling"
        - ""
        - "## Deployment Architecture"
        - "{Mermaid deployment diagram: nodes, services, networks}"
        - ""
        - "## Scaling Strategy"
        - "{Horizontal/vertical, min nodes, replication}"
        - ""
        - "## Network Configuration"
        - "{Table: service → port → protocol → access (internal/external)}"
        - ""
        - "## Best Practices"
        - "{Concrete recommendations: TLS, segmentation, load balancing}"
        - ""
        - "## Recommended Configuration"
        - "{Table: scenario → nodes → RAM → storage → notes}"

  #---------------------------------------------------------------------------
  # PROJECT-TYPE SPECIFIC STRUCTURES
  #---------------------------------------------------------------------------
  generation_by_project_type:

    template:
      structure:
        index.md: "Product pitch: what this template provides, key features, quick start"
        getting-started/:
          README.md: "Installation methods (template, one-liner, manual)"
          workflow.md: "Feature development workflow with diagram"
          configuration.md: "Environment setup, tokens, MCP config"
        architecture/:
          README.md: "System context: DevContainer + Claude + MCP ecosystem"
          components.md: "Features, hooks, agents, commands — how they connect"
          flow.md: "Container lifecycle flow with sequence diagram"
        languages/:
          README.md: "Overview of all languages with comparison table"
          "{lang}.md": "One page per language: tools, linters, versions, why"
        commands/:
          README.md: "All commands overview with when-to-use decision tree"
          "{cmd}.md": "Full command doc: phases, args, examples, diagrams"
        agents/:
          README.md: "Agent ecosystem: orchestrators → specialists → executors"
          language-specialists.md: "All language agents with capabilities"
          devops-specialists.md: "All DevOps agents with domains"
          executors.md: "All executor agents with analysis types"
        automation/:
          README.md: "Automation overview: hooks + MCP + pre-commit"
          hooks.md: "All lifecycle hooks with execution order diagram"
          mcp-servers.md: "All MCP integrations with tools and auth"
        patterns/:
          README.md: "Design patterns KB: categories, counts, usage"
          by-category.md: "Patterns organized by category with links"
        reference/:
          conventions.md: "Coding conventions, commit format, branch naming"
          troubleshooting.md: "Common issues and solutions"

    library:
      structure:
        index.md: "Product pitch: what this library does, install, basic example"
        architecture/:
          README.md: "System context: library boundary and dependencies"
          components.md: "Internal module breakdown with diagram"
          flow.md: "Data flow through the library with sequence diagram"
        api/:
          README.md: "API overview: main types, functions, interfaces"
          "{module}.md": "Per-module: exported API, parameters, return types, examples"
        examples/:
          README.md: "Example index with difficulty levels"
          "{example}.md": "Each example: problem, solution, code, explanation"
        guides/:
          installation.md: "Installation and setup"
          usage.md: "Usage patterns and best practices"
          migration.md: "Version migration guide (if applicable)"

    application:
      structure:
        index.md: "Product pitch: what this app does, who it's for, quick start"
        architecture/:
          README.md: "Level 1: system context with C4 diagram"
          components.md: "Level 2: component breakdown with internal diagrams"
          flow.md: "Data flows with sequence diagrams per major flow"
          deployment.md: "Level 3: cluster, scaling, network (if applicable)"
          decisions.md: "Key architectural decisions with rationale"
        api/:
          README.md: "API overview: base URL, auth, rate limiting"
          endpoints.md: "All endpoints: method, path, request/response formats"
          protocols.md: "Communication protocols: HTTP, gRPC, WebSocket, etc."
        deployment/:
          README.md: "Deployment guide: prerequisites, steps"
          configuration.md: "All config options: env vars, files, secrets"
          cluster.md: "Cluster setup: nodes, replication, fault tolerance"
          network.md: "Network: ports, TLS, segmentation, load balancing"
        guides/:
          README.md: "User guides index"
          getting-started.md: "First steps after deployment"
          operations.md: "Day-to-day operations and maintenance"
```

---

## Phase 4: Verification (DocAgent-inspired)

```yaml
phase_4_verify:
  description: "Iterative quality verification before serving"
  inspiration: "DocAgent multi-agent pattern: Writer → Verifier feedback loop"
  max_iterations: 2

  verifier_checks:
    completeness:
      - "Every primary section (score >= 24) has a full page"
      - "Every standard section (score >= 16) has an own page"
      - "No section references information not present in agent results"
    accuracy:
      - "Mermaid diagrams match actual component names from code"
      - "File paths in links point to real files"
      - "Version numbers match what install scripts actually install"
    quality:
      - "No generic filler ('This module handles X' without explaining HOW)"
      - "Every table has >= 2 rows of real data"
      - "Every code block is syntactically valid"
    no_placeholders:
      - "No 'Coming Soon', 'TBD', 'TODO', 'WIP' in any page"
      - "No '{VARIABLE}' patterns remaining in generated content"
      - "No empty sections or stub pages"

  feedback_loop:
    on_failure:
      action: "Fix the specific issue and re-verify (up to max_iterations)"
      strategy: "Targeted fix — only regenerate the failing section, not all docs"
    on_success:
      action: "Proceed to Phase 5 (Serve)"
    on_max_iterations:
      action: "Proceed with warnings listed in serve output"
```

---

## Phase 5: Validation + Serve

```yaml
phase_5_validate_and_serve:
  description: "Final validation then start MkDocs server"

  validation:
    mandatory_checks:
      - "Every nav entry points to existing file"
      - "No file < 20 lines (likely placeholder)"
      - "No 'TODO', 'TBD', 'Coming Soon' in content"
      - "All code blocks have language tag"
      - "All internal links resolve"
      - "Every architecture page has at least one Mermaid diagram"
      - "index.md has generation marker as first line (<!-- /docs-generated: ... -->)"
      - "index.md starts with product pitch after marker (not technical details)"
      - "No full config files copied inline (use links)"

    warnings:
      - "File > 300 lines → suggest splitting"
      - "Architecture page without sequence diagram"
      - "API page without request/response examples"
      - "Deployment page without recommended config table"

  serve:
    pre_check:
      - "pkill -f 'mkdocs serve' 2>/dev/null || true"

    command: "mkdocs serve -a 0.0.0.0:{PORT}"

    output_template: |
      ═══════════════════════════════════════════════════════════════
        /docs - Server Running (Deep Analysis Complete)
      ═══════════════════════════════════════════════════════════════

        Project Type: {PROJECT_TYPE}
        Analysis:     {N} agents completed
        Diagrams:     {D} Mermaid diagrams generated

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
    - "Generation marker? (head -1 docs/index.md)"
    - "Git diff since marker commit"
    - "Content files count"
    - "Mermaid diagrams count"
    - "Broken internal links"
    - "Outdated dependency versions"

  output_template: |
    ═══════════════════════════════════════════════════════════════
      /docs - Status Report
    ═══════════════════════════════════════════════════════════════

      Server      : {RUNNING|STOPPED}
      Structure   : {EXISTS|MISSING}

      Freshness:
        Generated   : {TIMESTAMP} ({DAYS_AGO} days ago)
        Commit      : {MARKER_COMMIT} → HEAD ({COMMITS_SINCE} commits)
        Stale pages : {STALE_COUNT} / {TOTAL_PAGES}
        Broken links: {BROKEN_COUNT}
        Outdated    : {OUTDATED_COUNT} deps

      Content:
        Pages       : {TOTAL_PAGES} files
        Diagrams    : {D} Mermaid blocks
        Coverage    : {PERCENTAGE}%

      {IF_STALE: "Run /docs to update stale pages (incremental)"}
      {IF_FRESH: "Docs are up to date."}

    ═══════════════════════════════════════════════════════════════
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
| Creer page vide/placeholder | **INTERDIT** | UX cassee |
| Lancer agents sequentiellement | **INTERDIT** | Performance degradee |
| Skip scoring | **INTERDIT** | Perte de priorisation |
| Generer sans analyse | **INTERDIT** | Contenu superficiel |
| "Coming Soon" / "TBD" | **INTERDIT** | Promesses vides |
| Creer section score < 16 standalone | **INTERDIT** | Pollution navigation |
| Ignorer PROJECT_TYPE | **INTERDIT** | Structure inadaptee |
| Page architecture sans diagramme | **INTERDIT** | Comprehension degradee |
| Copier fichier config entier inline | **INTERDIT** | Desynchronisation |
| Phrase generique sans info specifique | **INTERDIT** | Contenu creux |
| index.md qui commence par du technique | **INTERDIT** | Pitch produit d'abord |
| Skip architecture-analyzer pour app | **INTERDIT** | Architecture est critique |
| Skip freshness check (Phase 0.5) | **INTERDIT** | Regeneration inutile |
| Generer sans marker dans index.md | **INTERDIT** | Freshness impossible ensuite |
| Full regen si incremental suffit | **EVITER** | Gaspillage de tokens/temps |

---

## MkDocs Configuration

```yaml
# mkdocs.yml (generated at project root)
site_name: "{PROJECT_NAME}"
site_description: "{GENERATED_DESCRIPTION}"
docs_dir: docs
repo_url: "{GIT_REMOTE_URL}"       # auto-detected from git remote
repo_name: "{REPO_NAME}"           # auto-detected (GitHub/GitLab/Bitbucket)
edit_uri: "blob/main/docs/"        # read-only link (use "edit/main/docs/" for edit link)
use_directory_urls: true

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
  # GENERATED by nav_algorithm below — never hand-edited
  # ---
  # nav_algorithm:
  #   1. Start with index.md (always first)
  #   2. For each section in output_structure[PROJECT_TYPE]:
  #      - Skip if no component scored >= section threshold
  #      - Add section header (directory name, title-cased)
  #      - Add README.md as section landing page
  #      - Add child pages sorted by score descending
  #   3. Always end with reference/ section (aggregates score < 16)
  #   4. Validate: every nav entry points to an existing file
  #   5. Warn if total nav depth > 3 levels (flatten if possible)
  #
  # Example output for template project:
  #   - Home: index.md
  #   - Getting Started:
  #     - Overview: getting-started/README.md
  #     - Workflow: getting-started/workflow.md
  #     - Configuration: getting-started/configuration.md
  #   - Architecture:
  #     - Overview: architecture/README.md
  #     - Components: architecture/components.md
  #   - Reference:
  #     - Conventions: reference/conventions.md
```

---

## Error Messages

```yaml
errors:
  analysis_failed:
    message: |
      Analysis agent failed: {AGENT_NAME}

      Error: {ERROR_MESSAGE}

      Continuing with partial results...

  empty_section_detected:
    message: |
      Empty section detected: {SECTION}

      Score: {SCORE}/43

      This section has no real content.
      Moving to reference section.

  missing_diagram:
    message: |
      Architecture page without diagram: {PAGE}

      Score: {SCORE}/43 (includes +3 diagram bonus)

      Generating Mermaid diagram from agent analysis data.
      The diagram uses real component names from the codebase.
```

---

## Sources and References

This skill's design draws from the following methodologies and research:

| Source | Contribution | Reference |
|--------|-------------|-----------|
| **C4 Model** (Simon Brown) | Progressive architecture zoom (Context → Container → Component), diagram practices | [Practical C4 Modeling Tips](https://revision.app/blog/practical-c4-modeling-tips) |
| **DocAgent** (arXiv 2504.08725) | Multi-agent coordination: Reader → Searcher → Writer → Verifier, dependency-first ordering, iterative feedback loops | [DocAgent: Multi-Agent Collaboration](https://arxiv.org/html/2504.08725v1) |
| **Divio Documentation System** | Four documentation types (Tutorial, How-to, Reference, Explanation), boundary maintenance | [Divio Documentation Structure](https://docs.divio.com/documentation-system/structure/) |
| **MkDocs** | Configuration options: repo_url, edit_uri, nav structure, validation, plugins | [MkDocs Configuration Guide](https://www.mkdocs.org/user-guide/configuration/) |
| **MkDocs Material** | Theme: dark/light palette, navigation features, code copy, search, Mermaid diagrams | [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/) |
| **Product Documentation Tips** | Entry point pattern (About/Access/Usage/Resources/Support), chunking, navigation depth | [10 Tips for Product Documentation](https://developerhub.io/blog/10-tips-for-structuring-your-product-documentation/) |
| **Mermaid** | Diagram types: flowchart, sequence, C4 context, ER, state machine, deployment | [Mermaid Documentation](https://mermaid.js.org/) |
