---
name: docs
description: |
  Documentation Server with MkDocs Material (auto-setup).
  Serves /docs folder, creates structure if missing.
  Use --update to generate C4 architecture diagrams.
allowed-tools:
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "Write(docs/**)"
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

# /docs - Documentation Server (RLM Architecture)

Serve project documentation with **MkDocs Material**. Auto-setup structure, generate C4 architecture with `--update`.

$ARGUMENTS

---

## Core Principle: Just Works

```yaml
just_works:
  rule: "Run /docs - everything is automatic"

  modes:
    serve: "/docs → creates structure if missing, serves on :8080"
    update: "/docs --update → analyzes codebase, generates C4 diagrams"

  pattern: "Same as /warmup"
```

---

## Arguments

| Argument | Action |
|----------|--------|
| (none) | Create structure if missing, serve on :8080 |
| `--update` | Analyze codebase and generate/update C4 architecture |
| `--stop` | Stop running MkDocs server |
| `--status` | Show server status and documentation structure |
| `--port <n>` | Custom port (default: 8080) |
| `--help` | Show help |

---

## --help

```
═══════════════════════════════════════════════════════════════
  /docs - Documentation Server (RLM Architecture)
═══════════════════════════════════════════════════════════════

  DESCRIPTION
    Serves project documentation with MkDocs Material theme.
    Creates /docs folder structure automatically if missing.
    Use --update to generate C4 architecture diagrams.

  USAGE
    /docs [OPTIONS]

  OPTIONS
    (none)              Create structure if missing, serve on :8080
    --update            Generate/update C4 architecture diagrams
    --stop              Stop running MkDocs server
    --status            Show server and structure status
    --port <n>          Custom port (default: 8080)
    --help              Show this help

  EXAMPLES
    /docs                   # Just works - serve docs
    /docs --update          # Generate C4 architecture
    /docs --stop            # Stop server
    /docs --status          # Check status

  STRUCTURE (auto-created)
    docs/
    ├── mkdocs.yml          # MkDocs configuration
    ├── index.md            # Homepage
    ├── architecture/       # C4 diagrams (via --update)
    │   ├── README.md
    │   ├── c4-context.md
    │   ├── c4-container.md
    │   └── c4-component.md
    ├── adr/                # Architecture Decision Records
    ├── api/                # API documentation
    ├── runbooks/           # Operational guides
    └── guides/             # User/developer guides

  ERROR HANDLING
    - MkDocs not installed → auto-install
    - Port in use → kill existing or suggest --port
    - Templates missing → copy from defaults
    - Existing doc system → ask before replacing

  PATTERN
    /docs           ≈ /warmup           (serve/load)
    /docs --update  ≈ /warmup --update  (generate/update)

═══════════════════════════════════════════════════════════════
```

**SI `$ARGUMENTS` contient `--help`** : Afficher l'aide ci-dessus et STOP.

---

## Mode Normal (Serve)

### Phase 1: Detect & Create Structure

```yaml
phase_1_structure:
  description: "Check /docs folder, create if missing"

  check:
    tool: "Glob(pattern='docs/mkdocs.yml')"
    result: "exists | missing"

  if_missing:
    actions:
      1_create_dirs:
        command: |
          mkdir -p docs/architecture
          mkdir -p docs/adr
          mkdir -p docs/api
          mkdir -p docs/runbooks
          mkdir -p docs/guides

      2_detect_project:
        sources:
          - "package.json → name, description"
          - "go.mod → module name"
          - "Cargo.toml → package.name"
          - "pyproject.toml → project.name"
          - "fallback → directory name"
        output: "PROJECT_NAME, PROJECT_DESCRIPTION"

      3_create_mkdocs_yml:
        template: "~/.claude/templates/docs/mkdocs.yml.tpl"
        fallback: "/etc/claude-defaults/templates/docs/mkdocs.yml.tpl"
        variables:
          PROJECT_NAME: "{detected}"
          PROJECT_DESCRIPTION: "{detected}"

      4_create_index_md:
        template: "~/.claude/templates/docs/index.md.tpl"

      5_create_section_readmes:
        files:
          - "docs/architecture/README.md"
          - "docs/adr/README.md"
          - "docs/api/README.md"
          - "docs/runbooks/README.md"
          - "docs/guides/README.md"

      6_update_gitignore:
        check: "grep -q 'docs/site' .gitignore"
        action: "echo 'docs/site/' >> .gitignore"

  output_if_created: |
    ═══════════════════════════════════════════════════════════
      /docs - Structure Created
    ═══════════════════════════════════════════════════════════

      Created /docs folder:
        docs/
        ├── mkdocs.yml
        ├── index.md
        ├── architecture/
        ├── adr/
        ├── api/
        ├── runbooks/
        └── guides/

      Next: Run /docs --update to generate C4 architecture

    ═══════════════════════════════════════════════════════════
```

### Phase 2: Start Server

```yaml
phase_2_serve:
  description: "Start MkDocs development server"

  pre_check:
    - "pkill -f 'mkdocs serve' 2>/dev/null || true"
    - "Verify mkdocs installed"

  command: |
    cd docs && mkdocs serve -a 0.0.0.0:{PORT} &

  default_port: 8080

  output: |
    ═══════════════════════════════════════════════════════════
      /docs - Server Running
    ═══════════════════════════════════════════════════════════

      URL: http://localhost:{PORT}

      Features:
        ✓ Live reload enabled
        ✓ Mermaid diagrams supported
        ✓ Material theme active

      Sections:
        /                   Homepage
        /architecture/      C4 diagrams
        /adr/               Architecture decisions
        /api/               API documentation
        /runbooks/          Operational guides
        /guides/            User guides

      Commands:
        /docs --update      Generate C4 architecture
        /docs --stop        Stop server
        /docs --status      Check status

    ═══════════════════════════════════════════════════════════
```

---

## Mode --update (C4 Architecture Generation)

### Phase U0: Peek (Quick Scan)

```yaml
phase_u0_peek:
  description: "Quick scan before analysis"

  checks:
    1_structure_exists:
      tool: "Glob(pattern='docs/mkdocs.yml')"
      if_missing: "Will create structure first"

    2_architecture_exists:
      tool: "Glob(pattern='docs/architecture/*.md')"
      if_exists: "Will update existing (preserve <!-- MANUAL -->)"
      if_missing: "Will generate fresh"

    3_conflict_detection:
      tool: "Glob(pattern='docs/{.vuepress,docusaurus.config.*,_config.yml}')"
      if_found: |
        WARNING: Existing documentation system detected
        Ask user: "Replace with MkDocs?" or "Abort"

    4_check_metadata:
      tool: "Read(file_path='docs/.docs-metadata.json')"
      extract: "last_update, detected_stack"
      if_missing: "First generation"

  output: |
    ═══════════════════════════════════════════════════════════
      /docs --update - Peek Analysis
    ═══════════════════════════════════════════════════════════

      Existing Structure: {EXISTS|MISSING}
      Architecture Files: {COUNT} files
      Last Update: {DATE or "Never"}

      Conflicts: {NONE|DETECTED}

      Strategy: {FRESH|UPDATE}

    ═══════════════════════════════════════════════════════════
```

### Phase U1: Load Project Context

```yaml
phase_u1_context:
  description: "Read CLAUDE.md hierarchy for project understanding"

  actions:
    1_find_claude_md:
      tool: "Glob(pattern='**/CLAUDE.md')"

    2_read_hierarchy:
      files:
        - "/workspace/CLAUDE.md"
        - ".devcontainer/CLAUDE.md"
        - "src/CLAUDE.md (if exists)"

    3_extract_context:
      - "Project structure"
      - "Language conventions"
      - "Detected frameworks"

  output: "project_context"
```

### Phase U2: Detect Technology Stack

```yaml
phase_u2_detect:
  description: "Identify actual frameworks from manifest files"

  manifest_detection:
    nodejs:
      file: "package.json"
      read: "dependencies, devDependencies"

    go:
      file: "go.mod"
      read: "require block"

    rust:
      file: "Cargo.toml"
      read: "[dependencies]"

    python:
      file: "pyproject.toml | requirements.txt"
      read: "dependencies"

    java:
      file: "pom.xml | build.gradle*"
      read: "dependencies"

    # ... other languages from devcontainer features

  output:
    detected_stack:
      languages: []
      frameworks: []
```

### Phase U3: Delegate to Specialist Agents

```yaml
phase_u3_delegate:
  description: "Launch specialist agents for extraction"

  agent_mapping:
    go: "developer-specialist-go"
    nodejs: "developer-specialist-nodejs"
    python: "developer-specialist-python"
    rust: "developer-specialist-rust"
    java: "developer-specialist-java"
    scala: "developer-specialist-scala"
    php: "developer-specialist-php"
    ruby: "developer-specialist-ruby"
    elixir: "developer-specialist-elixir"
    dart: "developer-specialist-dart"
    cpp: "developer-specialist-cpp"
    carbon: "developer-specialist-carbon"

  parallel_extraction:
    tool: "Task"
    model: "haiku"

    prompt_template: |
      Analyze {language} codebase using {framework}.

      PROJECT CONTEXT:
      {project_context}

      EXTRACT (using grepai semantic search):

      1. ENTRY POINTS
         Query: "application entry points main functions HTTP handlers"

      2. MODULES
         Query: "modules packages their responsibilities"
         Use: grepai_trace_graph(depth=3)

      3. EXTERNAL SYSTEMS
         Query: "external service connections database clients"

      4. COMPONENTS
         Query: "service classes controllers repositories"

      5. RELATIONSHIPS
         Use: grepai_trace_callers, grepai_trace_callees

      OUTPUT JSON:
      {
        "entry_points": [...],
        "modules": [...],
        "external_systems": [...],
        "components": [...],
        "relationships": [...]
      }

  output: "extracted_entities"
```

### Phase U4: Cross-Reference with .claude/docs/

```yaml
phase_u4_validate:
  description: "Validate against local architecture knowledge"

  knowledge_sources:
    - ".claude/docs/architectural/"
    - ".claude/docs/enterprise/"
    - ".claude/docs/integration/"
    - ".claude/docs/ddd/"

  validation:
    - "Check components map to known patterns"
    - "Validate relationships follow integration patterns"
    - "Detect anti-patterns"

  output: "validated_entities"
```

### Phase U5: Generate C4 Diagrams

```yaml
phase_u5_generate:
  description: "Generate Mermaid C4 diagrams"

  files:
    context:
      path: "docs/architecture/c4-context.md"
      content: |
        # C4 Context Diagram

        System context showing users and external systems.

        ```mermaid
        C4Context
            title System Context - {PROJECT_NAME}

            {PERSONS}
            System(main, "{PROJECT_NAME}", "{DESCRIPTION}")
            {EXTERNAL_SYSTEMS}
            {RELATIONSHIPS}
        ```

        ## Description
        {CONTEXT_DESCRIPTION}

    container:
      path: "docs/architecture/c4-container.md"
      content: |
        # C4 Container Diagram

        Technical building blocks of the system.

        ```mermaid
        C4Container
            title Container Diagram - {PROJECT_NAME}

            {PERSONS}
            System_Boundary(boundary, "{PROJECT_NAME}") {
                {CONTAINERS}
            }
            {EXTERNAL_SYSTEMS}
            {RELATIONSHIPS}
        ```

        ## Containers
        {CONTAINER_DESCRIPTIONS}

    component:
      path: "docs/architecture/c4-component.md"
      content: |
        # C4 Component Diagram

        Internal structure of containers.

        ```mermaid
        C4Component
            title Component Diagram - {CONTAINER_NAME}

            Container_Boundary(container, "{CONTAINER_NAME}") {
                {COMPONENTS}
            }
            {RELATIONSHIPS}
        ```

        ## Components
        {COMPONENT_DESCRIPTIONS}

    readme:
      path: "docs/architecture/README.md"
      content: |
        # Architecture Overview

        Generated: {DATE}
        Stack: {LANGUAGES} / {FRAMEWORKS}

        ## Diagrams

        - [Context](c4-context.md) - System + external actors
        - [Container](c4-container.md) - Technical building blocks
        - [Component](c4-component.md) - Internal structure

        ## Detected Stack

        | Type | Technology |
        |------|------------|
        {STACK_TABLE}
```

### Phase U6: Write and Report

```yaml
phase_u6_write:
  description: "Write files and report"

  incremental_mode:
    preserve: "<!-- MANUAL --> sections"
    note: "Git handles versioning - no backup needed"

  output: |
    ═══════════════════════════════════════════════════════════
      /docs --update - Architecture Generated
    ═══════════════════════════════════════════════════════════

      Project: {PROJECT_NAME}

      Detected Stack:
        Languages:  {LANGUAGES}
        Frameworks: {FRAMEWORKS}

      Specialist Agents:
        {AGENTS_USED}

      Entities Extracted:
        Persons:          {persons_count}
        External Systems: {external_count}
        Containers:       {containers_count}
        Components:       {components_count}
        Relationships:    {relationships_count}

      Generated Files:
        ✓ docs/architecture/README.md
        ✓ docs/architecture/c4-context.md
        ✓ docs/architecture/c4-container.md
        ✓ docs/architecture/c4-component.md

      Pattern Validation:
        ✓ Cross-referenced with .claude/docs/
        {PATTERNS_FOUND}

      View: http://localhost:8080/architecture/
            (if server running)

    ═══════════════════════════════════════════════════════════
```

---

## --stop

```yaml
stop_workflow:
  command: "pkill -f 'mkdocs serve'"

  output: |
    ═══════════════════════════════════════════════════════════
      /docs - Server Stopped
    ═══════════════════════════════════════════════════════════

      MkDocs server stopped.
      Restart: /docs

    ═══════════════════════════════════════════════════════════
```

---

## --status

```yaml
status_workflow:
  checks:
    server: "pgrep -f 'mkdocs serve'"
    structure: "ls docs/"
    files: "find docs -name '*.md' | wc -l"

  output: |
    ═══════════════════════════════════════════════════════════
      /docs - Status
    ═══════════════════════════════════════════════════════════

      Server: {RUNNING|STOPPED}
      {URL if running}

      Structure:
        docs/
        ├── mkdocs.yml        {EXISTS|MISSING}
        ├── index.md          {EXISTS|MISSING}
        ├── architecture/     {FILE_COUNT} files
        ├── adr/              {FILE_COUNT} files
        ├── api/              {FILE_COUNT} files
        ├── runbooks/         {FILE_COUNT} files
        └── guides/           {FILE_COUNT} files

      Total: {TOTAL} markdown files

      Last --update: {DATE or "Never"}

    ═══════════════════════════════════════════════════════════
```

---

## Mermaid C4 Syntax Reference

```yaml
context:
  - "Person(id, 'Name', 'Description')"
  - "System(id, 'Name', 'Description')"
  - "System_Ext(id, 'Name', 'Description')"
  - "Rel(from, to, 'Label')"

container:
  - "Container(id, 'Name', 'Tech', 'Description')"
  - "ContainerDb(id, 'Name', 'Tech', 'Description')"
  - "ContainerQueue(id, 'Name', 'Tech', 'Description')"
  - "System_Boundary(id, 'Name') { ... }"

component:
  - "Component(id, 'Name', 'Tech', 'Description')"
  - "Container_Boundary(id, 'Name') { ... }"
```

---

## Error Handling

```yaml
error_handling:
  mkdocs_not_installed:
    detect: "command -v mkdocs"
    action: |
      echo "MkDocs not installed. Installing..."
      pip install mkdocs-material mkdocs-mermaid2-plugin
    fallback: "Abort with instructions"

  port_in_use:
    detect: "lsof -i :{PORT} 2>/dev/null"
    action: |
      echo "Port {PORT} in use. Killing existing mkdocs..."
      pkill -f 'mkdocs serve' || true
    fallback: "Suggest --port <other>"

  templates_missing:
    detect: "ls ~/.claude/templates/docs/ 2>/dev/null"
    action: |
      mkdir -p ~/.claude/templates/docs
      cp -r /etc/claude-defaults/templates/docs/* ~/.claude/templates/docs/
    fallback: "Use inline defaults"

  docs_folder_conflict:
    detect: "ls docs/.vuepress docs/docusaurus.config.* 2>/dev/null"
    action: "Ask user before overwriting"
    output: |
      ⚠️ Existing documentation system detected:
        {DETECTED_SYSTEM}

      Options:
        1. Replace with MkDocs (backup existing)
        2. Abort and keep existing
```

---

## Metadata Tracking

```yaml
metadata:
  file: "docs/.docs-metadata.json"

  structure:
    last_update: "ISO8601 timestamp"
    detected_stack:
      languages: []
      frameworks: []
    entities:
      persons: 0
      external_systems: 0
      containers: 0
      components: 0
      relationships: 0
    agents_used: []

  update_action: |
    Write metadata after each --update:
    {
      "last_update": "{ISO8601}",
      "detected_stack": {...},
      "entities": {...}
    }

  gitignore: "docs/.docs-metadata.json should NOT be gitignored (track history)"
```

---

## GARDE-FOUS (ABSOLUS)

| Action | Status | Raison |
|--------|--------|--------|
| Skip Phase U0 (Peek) | ❌ **INTERDIT** | Détection conflits obligatoire |
| Skip context loading in --update | ❌ **INTERDIT** | RLM context-first |
| Use hardcoded framework patterns | ❌ **INTERDIT** | Détection dynamique uniquement |
| Overwrite `<!-- MANUAL -->` sections | ❌ **INTERDIT** | Préserver éditions utilisateur |
| Delete user content in docs/ | ❌ **INTERDIT** | Seule mise à jour autorisée |
| Write outside docs/ | ❌ **INTERDIT** | Scope limité |
| Ignorer conflit doc system | ❌ **INTERDIT** | Demander confirmation |
| Générer sans validation grepai | ⚠ **WARNING** | Qualité réduite |
| Ignorer .gitignore dans scan | ❌ **INTERDIT** | Respect exclusions |

**Note:** Pas de backup nécessaire - git versionne tout. Utiliser `git diff` et `git checkout` si besoin.

---

## Validation Thresholds

```yaml
validation:
  architecture_files:
    ideal: "50-100 lines"
    warning: "101-200 lines"
    critical: "> 200 lines"
    action_if_critical: "Split into sub-components"

  mermaid_diagrams:
    max_entities: 20
    warning: "> 15 entities (readability)"
    action: "Suggest splitting into multiple diagrams"

  relationships:
    orphan_check: "Warn if component has 0 relationships"
    circular_check: "Detect circular dependencies"
```

---

## Design Patterns Applied

| Pattern | Category | Usage |
|---------|----------|-------|
| Lazy Loading | Performance | Créer structure on-demand |
| Template Method | Behavioral | Templates + variables |
| Observer | Behavioral | Hot-reload MkDocs |
| Facade | Structural | /docs unifie serve + update |

**Références :**
- `.claude/docs/performance/lazy-load.md`
- `.claude/docs/behavioral/template-method.md`
- `.claude/docs/structural/facade.md`

---

## Intégration Workflow

```
/warmup                     # Précharger contexte
    ↓
/docs                       # Lancer serveur docs
    ↓
/docs --update              # Générer architecture C4
    ↓
(edit docs/guides/*.md)     # Ajouter guides manuels
    ↓
/git --commit               # Commiter la doc
```

**Intégration avec autres skills :**

| Avant /docs | Après /docs |
|-------------|-------------|
| /warmup | /review (avec context) |
| /init | /git --commit |

---

## Template Location

```yaml
templates:
  user: "~/.claude/templates/docs/"
  system: "/etc/claude-defaults/templates/docs/"

  files:
    - "mkdocs.yml.tpl"
    - "index.md.tpl"
    - "architecture/README.md.tpl"
    - "adr/README.md.tpl"
    - "api/README.md.tpl"
    - "guides/README.md.tpl"
```
