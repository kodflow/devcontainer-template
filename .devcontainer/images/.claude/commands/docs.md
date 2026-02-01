---
name: docs
description: |
  Documentation Server with MkDocs Material (auto-setup).
  Detects project type and generates appropriate docs.
  Uses /warmup for context - adapts to actual content.
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
  - "mcp__grepai__grepai_search"
  - "mcp__grepai__grepai_trace_callers"
  - "mcp__grepai__grepai_trace_callees"
  - "mcp__grepai__grepai_trace_graph"
---

# /docs - Documentation Server (Adaptive)

Serve project documentation with **MkDocs Material**. Detects project type and adapts content.

$ARGUMENTS

---

## Core Principles

```yaml
principles:
  adaptive_content:
    rule: "Detect project type, generate appropriate docs"
    workflow: "/warmup → detect → adapt → generate"

  no_empty_content:
    rule: "NEVER create empty sections or placeholder pages"
    reason: "Empty pages = broken UX"

  context_aware:
    rule: "Use /warmup to understand project before generating"
    example: "Template project ≠ Application project"

  human_readable:
    rule: "Write for humans, not for templates"
    example: "Quick Start guide, not 'Overview of overview'"

  project_types:
    template: "How to use this template"
    library: "API reference + usage examples"
    application: "Architecture + guides + API"
    empty: "Getting started with this project"
```

---

## Arguments

| Argument | Action |
|----------|--------|
| (none) | Create minimal structure if missing, serve on :8080 |
| `--update` | Regenerate from codebase analysis |
| `--stop` | Stop running MkDocs server |
| `--status` | Show server status |
| `--port <n>` | Custom port (default: 8080) |
| `--help` | Show help |

---

## --help

```
═══════════════════════════════════════════════════════════════
  /docs - Documentation Server
═══════════════════════════════════════════════════════════════

  DESCRIPTION
    Serves project documentation with MkDocs Material theme.
    Creates minimal structure - NO empty placeholder pages.

  USAGE
    /docs [OPTIONS]

  OPTIONS
    (none)              Create minimal structure, serve on :8080
    --update            Regenerate from codebase analysis
    --stop              Stop running MkDocs server
    --status            Show server status
    --port <n>          Custom port (default: 8080)
    --help              Show this help

  EXAMPLES
    /docs                   # Serve docs
    /docs --update          # Regenerate content
    /docs --stop            # Stop server

  MINIMAL STRUCTURE (auto-created)
    mkdocs.yml              # Config at project root
    docs/
    ├── index.md            # Quick Start (required)
    └── guides/             # How-to guides (required)
        └── README.md

  OPTIONAL SECTIONS (created only if content exists)
    architecture/           # Only if codebase has clear structure
    adr/                    # Only if ADRs exist
    api/                    # Only if API detected (OpenAPI, etc.)

  CONTENT DETECTION
    API:  openapi.yaml | swagger.json | **/routes/** | **/api/**
    ADR:  docs/adr/0*.md | decisions/0*.md
    Arch: Complex multi-module project

═══════════════════════════════════════════════════════════════
```

**SI `$ARGUMENTS` contient `--help`** : Afficher l'aide ci-dessus et STOP.

---

## Mode Normal (Serve)

### Phase 0: Context Detection (WARMUP)

```yaml
phase_0_warmup:
  description: "Load project context BEFORE generating docs"
  mandatory: true

  actions:
    1_read_claude_md:
      tool: "Read('/workspace/CLAUDE.md')"
      extract: "Project type, structure, conventions"

    2_detect_project_type:
      checks:
        - "Glob(pattern='src/**/*.{go,py,ts,rs,java}')" → has_code
        - "Glob(pattern='{package.json,go.mod,Cargo.toml,pyproject.toml}')" → has_manifest
        - "Glob(pattern='**/openapi.{yaml,yml,json}')" → has_api
        - "Glob(pattern='.devcontainer/**')" → is_devcontainer
        - "Glob(pattern='**/*.tpl')" → has_templates

      classification:
        template:
          signals: ["is_devcontainer", "has_templates", "!has_code"]
          docs_type: "How to use this template"

        library:
          signals: ["has_manifest", "has_code", "!has_api"]
          docs_type: "API reference + usage"

        application:
          signals: ["has_manifest", "has_code", "has_api"]
          docs_type: "Full docs (arch + guides + API)"

        empty:
          signals: ["!has_manifest", "!has_code"]
          docs_type: "Getting started scaffold"

    3_analyze_if_code_exists:
      condition: "has_code == true"
      tools:
        - "mcp__grepai__grepai_search(query='main entry point')"
        - "mcp__grepai__grepai_search(query='public functions exports')"
        - "Grep(pattern='TODO|FIXME|@api|@doc')"
      extract: "Entry points, public API, doc comments"

  output:
    project_type: "template | library | application | empty"
    project_context: "{extracted from CLAUDE.md}"
    detected_features: [list of features]
```

### Phase 1: Detect Existing Structure

```yaml
phase_1_detect:
  description: "Check what exists before creating anything"

  checks:
    1_mkdocs_yml:
      tool: "Glob(pattern='mkdocs.yml')"
      if_exists: "Use existing config"
      if_missing: "Will create"

    2_docs_folder:
      tool: "Glob(pattern='docs/index.md')"
      if_exists: "Has content"
      if_missing: "Will create based on project_type"

    3_conflict_detection:
      tool: "Glob(pattern='docs/{.vuepress,docusaurus.config.*,_config.yml}')"
      if_found: "Ask user before replacing"

  output: "detection_result"
```

### Phase 2: Generate Adapted Content

```yaml
phase_2_generate:
  description: "Generate docs based on detected project type"

  condition: "docs/index.md missing OR --update flag"

  by_project_type:

    template:
      description: "DevContainer, boilerplate, starter kit"
      generate:
        - "docs/index.md"           # What is this template
        - "docs/getting-started.md" # How to use it
        - "docs/customization.md"   # How to customize (if features exist)
      content_from:
        - "CLAUDE.md hierarchy"
        - ".devcontainer/ structure"
        - "features/ available"
        - "commands/ skills"

    library:
      description: "Package, module, SDK"
      generate:
        - "docs/index.md"         # Quick start
        - "docs/api/README.md"    # Auto-generated from code
        - "docs/examples.md"      # From tests/examples/
      content_from:
        - "Docstrings (grepai_search)"
        - "Public exports"
        - "README sections"
        - "Example files"

    application:
      description: "Service, app, full project"
      generate:
        - "docs/index.md"         # Overview + quick start
        - "docs/guides/README.md" # How-to guides
        - "docs/api/README.md"    # If API detected
      content_from:
        - "Entry points (main, handlers)"
        - "Route definitions"
        - "Config options"
        - "Env variables"

    empty:
      description: "New/empty project"
      action: "AskUserQuestion"
      question: "What type of project will this be?"
      options:
        - "Web Application"
        - "CLI Tool"
        - "Library/SDK"
        - "Microservice"
      then: "Generate scaffold for chosen type"

  extraction_tools:
    docstrings: "grepai_search('docstring documentation comment')"
    exports: "grepai_search('export public module')"
    routes: "grepai_search('route endpoint handler')"
    config: "grepai_search('config env environment')"

  important: |
    - Content MUST reflect actual project
    - Use grepai to extract real info from code
    - If empty/unclear, ASK user
    - NEVER generate generic placeholder content
```

### Phase 3: Generate Nav (content-aware)

```yaml
phase_3_nav:
  description: "Build nav only from existing content"

  rules:
    - "Every nav entry MUST point to a file with real content"
    - "No placeholder pages in nav"
    - "No 'Coming Soon' entries"

  example_minimal:
    nav:
      - Home: index.md
      - Guides: guides/README.md

  example_with_api:
    nav:
      - Home: index.md
      - Guides: guides/README.md
      - API: api/README.md  # Only if API detected

  example_full:
    nav:
      - Home: index.md
      - Guides: guides/README.md
      - Architecture: architecture/README.md  # Only if complex project
      - API: api/README.md                     # Only if API detected
      - ADR: adr/index.md                      # Only if ADRs exist
```

### Phase 4: Start Server

```yaml
phase_4_serve:
  description: "Start MkDocs development server"

  pre_check:
    - "pkill -f 'mkdocs serve' 2>/dev/null || true"

  note: |
    MkDocs is PRE-INSTALLED in the Docker image.
    No pip install needed - persists across rebuilds.

  command: |
    mkdocs serve -a 0.0.0.0:{PORT}

  output: |
    ═══════════════════════════════════════════════════════════
      /docs - Server Running
    ═══════════════════════════════════════════════════════════

      URL: http://localhost:{PORT}

      Sections:
        {ONLY_EXISTING_SECTIONS}

      Commands:
        /docs --update      Regenerate from codebase
        /docs --stop        Stop server

    ═══════════════════════════════════════════════════════════
```

---

## Mode --update

### Purpose

Analyze codebase and regenerate documentation content.

```yaml
update_workflow:
  1_analyze:
    - "Read CLAUDE.md hierarchy"
    - "Detect technology stack"
    - "Find entry points, modules, patterns"

  2_detect_content:
    - "Check for API definitions"
    - "Check for existing ADRs"
    - "Assess architecture complexity"

  3_generate:
    - "Update existing pages with fresh content"
    - "Add new sections ONLY if content detected"
    - "Remove sections if content no longer exists"

  4_preserve:
    - "<!-- MANUAL --> sections"
    - "User-added pages"
    - "Custom nav entries"
```

---

## --stop

```yaml
stop:
  command: "pkill -f 'mkdocs serve'"
  output: "Server stopped. Restart: /docs"
```

---

## --status

```yaml
status:
  checks:
    - "Server running? (pgrep)"
    - "Docs structure exists?"
    - "Content files count"
  output: |
    Server: {RUNNING|STOPPED}
    Structure: {EXISTS|MISSING}
    Content: {N} pages
```

---

## GARDE-FOUS (ABSOLUS)

| Action | Status | Raison |
|--------|--------|--------|
| Créer page vide/placeholder | ❌ **INTERDIT** | UX cassée |
| Créer section sans contenu | ❌ **INTERDIT** | Navigation polluée |
| Nav vers page inexistante | ❌ **INTERDIT** | Liens cassés |
| "Coming Soon" / "TBD" | ❌ **INTERDIT** | Pas de promesses vides |
| Template avec instructions | ❌ **INTERDIT** | Doc = contenu, pas meta |
| Créer api/ sans API détectée | ❌ **INTERDIT** | Faux positif |
| Créer adr/ sans ADR existant | ❌ **INTERDIT** | Section inutile |
| Overwrite `<!-- MANUAL -->` | ❌ **INTERDIT** | Préserver éditions user |

---

## Content Templates

### index.md (Required)

```markdown
# {PROJECT_NAME}

{ONE_LINE_DESCRIPTION}

## Quick Start

\`\`\`bash
# Installation
{INSTALL_COMMAND}

# Run
{RUN_COMMAND}
\`\`\`

## What's Included

| Component | Description |
|-----------|-------------|
{ACTUAL_COMPONENTS}

## Navigation

- [Guides](guides/README.md) - How to use
{OPTIONAL_LINKS_ONLY_IF_EXIST}
```

### guides/README.md (Required)

```markdown
# Guides

## Getting Started

{ACTUAL_GETTING_STARTED_CONTENT}

## Common Tasks

{ACTUAL_TASKS_FOR_THIS_PROJECT}
```

### api/README.md (Only if API detected)

```markdown
# API Reference

{ACTUAL_API_DOCUMENTATION}

## Endpoints

{GENERATED_FROM_OPENAPI_OR_CODE}
```

### adr/index.md (Only if ADRs exist)

```markdown
# Architecture Decision Records

| ADR | Title | Status | Date |
|-----|-------|--------|------|
{ACTUAL_ADR_LIST_FROM_FILES}
```

---

## MkDocs Configuration

```yaml
# mkdocs.yml (at project root)
site_name: {PROJECT_NAME}
docs_dir: docs

theme:
  name: material
  palette:
    - scheme: slate
      primary: deep purple
      toggle:
        icon: material/brightness-4
    - scheme: default
      primary: deep purple
      toggle:
        icon: material/brightness-7
  features:
    - navigation.tabs
    - navigation.top
    - search.suggest
    - content.code.copy

plugins:
  - search
  - mermaid2

markdown_extensions:
  - pymdownx.highlight
  - pymdownx.superfences:
      custom_fences:
        - name: mermaid
          class: mermaid
          format: !!python/name:pymdownx.superfences.fence_code_format
  - admonition
  - tables
  - toc:
      permalink: true

nav:
  # ONLY entries with actual content
  - Home: index.md
  - Guides: guides/README.md
  # Add more ONLY if content exists
```

---

## Validation

```yaml
validation:
  before_serve:
    - "Every nav entry points to existing file"
    - "No file < 10 lines (likely placeholder)"
    - "No 'TODO', 'TBD', 'Coming Soon' in content"

  warnings:
    - "File > 200 lines → suggest splitting"
    - "Broken internal links"
    - "Images without alt text"
```

---

## Error Messages

```yaml
errors:
  empty_section_detected:
    message: |
      ⚠️ Empty section detected: {SECTION}

      This section has no real content.
      Either add content or remove the section.

      DO NOT create placeholder pages.

  placeholder_detected:
    message: |
      ⚠️ Placeholder content detected in {FILE}

      Found: "{PLACEHOLDER_TEXT}"

      Replace with actual content or remove the file.
```
