---
name: init
description: |
  Project initialization with RLM decomposition.
  Auto-detects if personalization needed, then validates environment.
  Use when: creating new project, starting work, verifying setup.
allowed-tools:
  - AskUserQuestion
  - Write
  - Edit
  - "Bash(git:*)"
  - "Bash(docker:*)"
  - "Bash(terraform:*)"
  - "Bash(kubectl:*)"
  - "Bash(node:*)"
  - "Bash(python:*)"
  - "Bash(go:*)"
  - "Bash(grepai:*)"
  - "Bash(curl:*)"
  - "Bash(pgrep:*)"
  - "Bash(nohup:*)"
  - "Bash(mkdir:*)"
  - "Bash(wc:*)"
  - "Read(**/*)"
  - "Glob(**/*)"
  - "mcp__grepai__*"
  - "Grep(**/*)"
  - "Task(*)"
  - "mcp__github__*"
  - "mcp__codacy__*"
---

# /init - Project Initialization (RLM)

$ARGUMENTS

---

## Overview

Initialisation complète avec patterns **RLM** :

1. **Detect** - Projet personnalisé ou template?
2. **Personalize** - Wizard si template détecté
3. **Validate** - Environment, tools, deps, config
4. **Report** - Consolidated status

---

## Usage

```
/init                # Everything automatic
```

**Comportement intelligent :**
- Détecte si template → lance wizard
- Détecte si personnalisé → valide seulement
- Détecte problèmes → auto-fix quand possible
- Pas de flags, pas de questions inutiles

---

## Phase 0 : Detect (Template vs Personalized)

**Détecter si le projet nécessite personnalisation :**

```yaml
detect_workflow:
  check_markers:
    - file: "/workspace/CLAUDE.md"
      template_marker: "Kodflow DevContainer Template"
    - file: "/workspace/docs/vision.md"
      template_marker: "batteries-included VS Code Dev Container"

  decision:
    if_template_detected:
      action: "Run Phase 1 (Personalization Wizard)"
      message: "Template detected. Let's personalize your project."
    if_personalized:
      action: "Skip to Phase 2 (Validation)"
      message: "Project already personalized. Validating..."
```

**Output Phase 0 :**

```
═══════════════════════════════════════════════════════════════
  /init - Project Detection
═══════════════════════════════════════════════════════════════

  Checking: /workspace/CLAUDE.md
  Result  : Template markers found

  → Project needs personalization
  → Starting wizard...

═══════════════════════════════════════════════════════════════
```

---

## Phase 1 : Personalization Wizard

**Si template détecté, poser les questions de personnalisation.**

### Block 1: Project Identity

```yaml
ask_identity:
  tool: AskUserQuestion
  questions:
    - question: "What is your project name?"
      header: "Name"
      options:
        - label: "my-api"
          description: "REST/GraphQL API service"
        - label: "my-cli"
          description: "Command-line tool"
        - label: "my-lib"
          description: "Reusable library/package"
      multiSelect: false

    - question: "What type of project?"
      header: "Type"
      options:
        - label: "API/Backend"
          description: "REST or GraphQL service"
        - label: "CLI Tool"
          description: "Command-line utility"
        - label: "Library"
          description: "Reusable module"
        - label: "Fullstack"
          description: "Frontend + Backend"
      multiSelect: false
```

### Block 2: Tech Stack

```yaml
ask_stack:
  tool: AskUserQuestion
  questions:
    - question: "Which primary language(s)?"
      header: "Language"
      options:
        - label: "Go"
          description: "Backend, CLI, microservices"
        - label: "TypeScript/Node"
          description: "Backend, frontend, fullstack"
        - label: "Python"
          description: "ML, scripting, backend"
        - label: "Rust"
          description: "Systems, performance"
      multiSelect: true

    - question: "Which database(s)?"
      header: "Database"
      options:
        - label: "PostgreSQL"
          description: "Relational, ACID"
        - label: "MongoDB"
          description: "Document store"
        - label: "Redis"
          description: "Cache, pub/sub"
        - label: "None"
          description: "No database"
      multiSelect: true
```

### Block 3: Infrastructure

```yaml
ask_infra:
  tool: AskUserQuestion
  questions:
    - question: "Which cloud provider(s)?"
      header: "Cloud"
      options:
        - label: "AWS"
          description: "Amazon Web Services"
        - label: "GCP"
          description: "Google Cloud"
        - label: "Azure"
          description: "Microsoft Azure"
        - label: "Self-hosted"
          description: "On-premise"
      multiSelect: true

    - question: "Container strategy?"
      header: "Containers"
      options:
        - label: "Kubernetes"
          description: "K8s orchestration"
        - label: "Docker Compose"
          description: "Simple deployment"
        - label: "Serverless"
          description: "Lambda, Cloud Functions"
        - label: "None"
          description: "Traditional"
      multiSelect: false
```

### Block 4: Quality Goals

```yaml
ask_quality:
  tool: AskUserQuestion
  questions:
    - question: "Quality priorities?"
      header: "Quality"
      options:
        - label: "High test coverage (>80%)"
          description: "Comprehensive testing"
        - label: "Performance (<100ms)"
          description: "Low latency"
        - label: "Security-first"
          description: "Compliance, auditing"
        - label: "Rapid iteration"
          description: "Move fast"
      multiSelect: true
```

### File Generation

**Après les questions, générer les fichiers en PARALLÈLE :**

```yaml
generate_files:
  - path: "/workspace/CLAUDE.md"
    content: |
      # {project_name}

      ## Purpose
      {project_type} built with {languages}.

      ## How to Work
      1. `/init` - Verify setup (already done!)
      2. `/feature <desc>` - New feature
      3. `/fix <desc>` - Bug fix

      ## Key Principles
      - MCP-first for integrations
      - Semantic search with grepai
      - Specialist agents for {primary_language}

      ## Verification
      - Tests: `{test_command}`
      - Lint: auto via hooks

  - path: "/workspace/docs/vision.md"
    content: |
      # Vision: {project_name}

      ## Purpose
      {project_description}

      ## Goals
      {quality_goals}

      ## Success Criteria
      | Criterion | Target |
      |-----------|--------|
      | Test Coverage | {coverage} |
      | Availability | {sla} |

  - path: "/workspace/.env.example"
    condition: "databases.length > 0 OR cloud.length > 0"
    content: |
      # {project_name} Environment
      APP_NAME={project_name}
      {database_vars}
      {cloud_vars}

  - path: "/workspace/Makefile"
    condition: "language in [Go, Rust, Python]"
    content: |
      # {project_name} Makefile
      {language_targets}
```

---

## Phase 2 : Environment Validation

**Vérifier l'environnement (parallèle via Task agents).**

```yaml
parallel_checks:
  agents:
    - name: "tools-checker"
      checks: [git, node, go, terraform, docker, grepai]
      output: "{tool, required, installed, status}"

    - name: "deps-checker"
      checks: [npm ci, go mod, terraform init]
      output: "{manager, status, issues}"

    - name: "config-checker"
      checks: [.env, CLAUDE.md, mcp.json]
      output: "{file, status, issue}"

    - name: "grepai-checker"
      checks: [Ollama, daemon, index]
      output: "{component, status, details}"
```

---

## Phase 3 : Report

```
═══════════════════════════════════════════════════════════════
  /init - Complete
═══════════════════════════════════════════════════════════════

  Project: {project_name}
  Type   : {project_type}
  Stack  : {languages}

  Personalization:
    ✓ CLAUDE.md updated
    ✓ docs/vision.md updated
    ✓ .env.example created
    ✓ Makefile created

  Environment:
    ✓ Tools installed (git, go, docker)
    ✓ Dependencies ready
    ✓ grepai indexed (296 files)

  Ready to develop!
    → /feature "description" to start

═══════════════════════════════════════════════════════════════
```

---

## Auto-fix (automatique)

Quand un problème est détecté, fix automatique si possible :

| Problème | Action auto |
|----------|-------------|
| `.env` manquant | `cp .env.example .env` |
| deps pas installées | `npm ci` / `go mod download` |
| grepai pas lancé | `nohup grepai watch &` |
| Ollama pas accessible | Instructions HOST affichées |

---

## GARDE-FOUS

| Action | Status |
|--------|--------|
| Skip detection | ❌ INTERDIT |
| Placeholders dans output | ❌ INTERDIT |
| Fix destructif sans demander | ❌ INTERDIT |
