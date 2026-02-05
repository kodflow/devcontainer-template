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
    iterations: "One pass per major category (C iterations)"
    output: "Consolidated results with importance scoring"

  no_superficial_content:
    rule: "NEVER list without explaining"
    bad: "Available commands: /git, /review, /plan"
    good: "### /git - Full workflow with phases, arguments, examples"

  product_pitch_first:
    rule: "index.md MUST answer 'What problem does this solve?' before anything technical"
    structure: "Problem → Solution → Key features → Quick start"
    reason: "Readers decide in 30 seconds if the project is relevant to them"

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
      - "Diagram bonus (+3): Complex component without any diagram"
    threshold: "Score >= 24 → Include in main docs"

  adaptive_structure:
    template_project: "How to use, languages, commands, agents, hooks"
    library_project: "API reference, usage examples, integration guides, internal architecture"
    application_project: "Architecture, API, deployment, data flow, cluster, configuration"
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
    (languages, commands, hooks, architecture, etc.). Results
    are scored and consolidated into rich documentation with
    Mermaid diagrams and progressive architecture zoom.

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
    Diagram bonus:  +3 (complex component, no diagram yet)
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
└─ Choose analysis strategy + agent list

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
├─ Apply scoring formula (with diagram bonus)
├─ Identify high-priority sections
└─ Build documentation tree

Phase 3: Content Generation
├─ Generate index.md (product pitch first)
├─ For each scored section:
│   ├─ If score >= 24: Full page + Mermaid diagram
│   ├─ If score 16-23: Summary in parent page
│   └─ If score < 16: Reference link only
├─ Generate architecture pages (progressive zoom)
└─ Generate nav structure

Phase 4: Validation + Serve
├─ Check: no placeholders, no empty pages, diagrams present
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
  model: "sonnet"
  reason: "Architecture analysis requires deeper reasoning than haiku"

  prompt: |
    Deep architecture analysis of the project. Produce a MULTI-LEVEL
    progressive zoom analysis (Google Maps analogy: macro → micro).

    ## Level 1: System Context (macro view)
    - What are the major blocks/services?
    - What external systems does this project depend on?
    - What is the boundary of the system?
    - Generate a Mermaid C4 context diagram description

    ## Level 2: Components (zoom in)
    For EACH major block identified in Level 1:
    - What modules/packages compose it?
    - What is each module's responsibility?
    - How do modules communicate internally?
    - Generate a Mermaid component diagram description

    ## Level 3: Technical Details (deep zoom)
    For key components (most complex or most used):
    - Internal data structures and algorithms
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
      primary: ">= 24 (full documentation page with diagram)"
      secondary: "16-23 (summary section in parent page)"
      reference: "< 16 (link only)"

  diagram_requirement:
    rule: |
      IF score >= 24 AND component is architectural:
        MUST include at least one Mermaid diagram
      IF score >= 24 AND component has data flow:
        MUST include sequence or flowchart diagram
      IF cluster/scaling detected:
        MUST include deployment diagram

  consolidation_steps:
    1_collect:
      action: "Gather all agent JSON results"

    2_deduplicate:
      action: "Merge overlapping information (structure + architecture)"

    3_score:
      action: "Calculate total score per component with diagram bonus"

    4_prioritize:
      action: "Sort by score descending"

    5_identify_diagrams:
      action: "For each primary section, determine required diagram types"

    6_structure:
      action: "Build documentation tree adapted to PROJECT_TYPE"

  output_structure:
    common:
      - "index.md (always — product pitch format)"
      - "architecture/ (if application/library, score >= 24)"
    template:
      - "getting-started/ (score >= 24)"
      - "languages/ (score >= 24)"
      - "commands/ (score >= 24)"
      - "agents/ (score >= 20)"
      - "automation/ (hooks + mcp, score >= 20)"
      - "patterns/ (if KB exists, score >= 16)"
      - "reference/ (aggregated low-score items)"
    application:
      - "architecture/ (always for app)"
      - "api/ (if endpoints detected)"
      - "deployment/ (if cluster/docker detected)"
      - "guides/ (score >= 20)"
      - "reference/ (aggregated low-score items)"
    library:
      - "architecture/ (if complex internal structure)"
      - "api/ (always for library)"
      - "examples/ (score >= 20)"
      - "guides/ (score >= 20)"
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
  # UNIVERSAL TEMPLATES (applied to all project types)
  #---------------------------------------------------------------------------
  universal_templates:

    index_md:
      description: "Product pitch page — answers 'Why should I care?' in 30 seconds"
      structure:
        - "# {PROJECT_NAME}"
        - ""
        - "## What is this?"
        - "{2-3 sentences: what problem it solves, for whom}"
        - ""
        - "## Key Features"
        - "{Bullet list of 5-8 major capabilities with one-line explanations}"
        - ""
        - "## How it works"
        - "{Mermaid flowchart: high-level system overview}"
        - ""
        - "## Quick Start"
        - "{3-5 steps to get running, with code blocks}"
        - ""
        - "## What's Inside"
        - "{Table: component → description → link to detailed page}"

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

## Phase 4: Validation + Serve

```yaml
phase_4_validate_and_serve:
  description: "Validate quality then start MkDocs server"

  validation:
    mandatory_checks:
      - "Every nav entry points to existing file"
      - "No file < 20 lines (likely placeholder)"
      - "No 'TODO', 'TBD', 'Coming Soon' in content"
      - "All code blocks have language tag"
      - "All internal links resolve"
      - "Every architecture page has at least one Mermaid diagram"
      - "index.md starts with product pitch (not technical details)"
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
    - "Content files count"
    - "Mermaid diagrams count"
    - "Last analysis timestamp"

  output_template: |
    Server:     {RUNNING|STOPPED}
    Structure:  {EXISTS|MISSING}
    Pages:      {N} files
    Diagrams:   {D} Mermaid blocks
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

      Adding placeholder Mermaid diagram from agent analysis.
      Review and refine the generated diagram.
```
