---
name: init
description: |
  Conversational project discovery + doc generation.
  Open-ended dialogue builds rich context, then synthesizes all project docs.
  Use when: creating new project, starting work, verifying setup.
allowed-tools:
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

# /init - Conversational Project Discovery

$ARGUMENTS

---

## Overview

Conversational initialization with **progressive context building**:

1. **Detect** - Template or already personalized?
2. **Discover** - Open-ended conversation to understand the project
3. **Synthesize** - Review accumulated context with user
4. **Generate** - Produce all project docs from rich context
5. **Validate** - Environment, tools, deps, config

---

## Usage

```
/init                # Everything automatic
```

**Intelligent behavior:**
- Detects template → starts discovery conversation
- Detects personalized → skips to validation
- Detects problems → auto-fix when possible
- No flags, no unnecessary questions

---

## Phase 0: Detect (Template vs Personalized)

**Detect if the project needs personalization:**

```yaml
detect_workflow:
  check_markers:
    - file: "/workspace/CLAUDE.md"
      template_marker: "Kodflow DevContainer Template"
    - file: "/workspace/docs/vision.md"
      template_marker: "batteries-included VS Code Dev Container"

  decision:
    if_template_detected:
      action: "Run Phase 1 (Discovery Conversation)"
      message: "Template detected. Let's discover your project."
    if_personalized:
      action: "Skip to Phase 4 (Validation)"
      message: "Project already personalized. Validating..."
```

**Output Phase 0:**

```
═══════════════════════════════════════════════════════════════
  /init - Project Detection
═══════════════════════════════════════════════════════════════

  Checking: /workspace/CLAUDE.md
  Result  : Template markers found

  → Project needs personalization
  → Starting discovery conversation...

═══════════════════════════════════════════════════════════════
```

---

## Phase 1: Discovery Conversation

**RULES (ABSOLUTE):**

- Ask **ONE question at a time** as plain text output
- **NEVER** use AskUserQuestion tool
- **NEVER** offer predefined options or multiple-choice lists
- After **EACH** user response, display the updated **Project Context** block
- Adapt the next question based on accumulated context
- Minimum **4** exchanges, maximum **10**
- Questions must be open-ended and conversational

### Question Strategy

**Fixed questions (always asked first):**

```yaml
round_1:
  question: |
    Tell me about your project. What are you building
    and what problem does it solve?
  extracts: [purpose, problem]

round_2:
  question: |
    Who will use this? Describe the people or systems
    that will interact with it.
  extracts: [users]

round_3:
  question: |
    What should we call this project?
  extracts: [name]
```

**Adaptive questions (selected based on gaps in context):**

```yaml
adaptive_pool:
  tech_stack:
    trigger: "tech stack unknown"
    question: "What languages, frameworks, or tools are you planning to use?"
    extracts: [tech_stack]

  data_storage:
    trigger: "data storage relevant AND unknown"
    question: "How will your project store and manage data?"
    extracts: [database]

  deployment:
    trigger: "deployment unknown"
    question: "Where and how will this run in production?"
    extracts: [deployment]

  quality:
    trigger: "quality priorities unknown"
    question: "What matters most for quality — test coverage, performance, security, or something else?"
    extracts: [quality]

  constraints:
    trigger: "constraints unknown"
    question: "Are there any constraints I should know about — team size, timeline, compliance requirements?"
    extracts: [constraints]

  architecture:
    trigger: "complex project AND architecture unclear"
    question: "Do you have a particular architecture in mind — monolith, microservices, event-driven, or something else?"
    extracts: [architecture]

  follow_up:
    trigger: "previous answer was brief"
    question: "Can you tell me more about {topic}? I want to make sure I capture the full picture."
    extracts: [varies]
```

### Project Context Block

**Display this block after EVERY exchange, updated with new information:**

```
═════════════════════════════════════════════════════
  PROJECT CONTEXT
═════════════════════════════════════════════════════
  Name        : {name or "---"}
  Purpose     : {1-2 sentence summary or "---"}
  Problem     : {problem statement or "---"}
  Users       : {target users or "---"}
  Tech Stack  : {languages, frameworks or "---"}
  Database    : {database choices or "---"}
  Deployment  : {cloud/hosting or "---"}
  Architecture: {architecture approach or "---"}
  Quality     : {quality priorities or "---"}
  Constraints : {known constraints or "---"}
  [Discovery — exchange {N}/10]
═════════════════════════════════════════════════════
```

### Transition Criteria

Move to Phase 2 when **ALL** of these are true:

- Name is known
- Purpose/Problem is known
- Users are known
- At least one tech element is concrete
- At least 4 exchanges completed

**OR:** User signals readiness / 10 exchanges reached.

---

## Phase 2: Vision Synthesis

**Review the accumulated context with the user before generating files.**

```yaml
synthesis_workflow:
  step_1:
    action: "Display FINAL Project Context with all fields populated"
    output: |
      ═════════════════════════════════════════════════════
        FINAL PROJECT CONTEXT
      ═════════════════════════════════════════════════════
        Name        : {name}
        Purpose     : {purpose}
        Problem     : {problem}
        Users       : {users}
        Tech Stack  : {tech_stack}
        Database    : {database}
        Deployment  : {deployment}
        Architecture: {architecture}
        Quality     : {quality}
        Constraints : {constraints}
      ═════════════════════════════════════════════════════

  step_2:
    message: |
      Here is what I understand about your project.
      Review and tell me if anything needs to change.
      Say "generate" when you're ready for me to create
      your project documentation.

  step_3:
    loop: "Process any refinements, update context, repeat"
    exit: "User says 'generate' or confirms"
```

---

## Phase 3: File Generation

**Generate all files DIRECTLY from accumulated context. No templates.**

```yaml
generation_rules:
  - NO mustache/handlebars placeholders
  - NO template files referenced
  - Content is SYNTHESIZED from the full conversation context
  - Every file must contain real, specific, actionable content
  - Write vision.md FIRST, then remaining files in parallel
```

### Files to Generate

```yaml
files:
  # PRIMARY OUTPUT - written first
  - path: "/workspace/docs/vision.md"
    description: "Rich project vision synthesized from conversation"
    structure:
      - "# Vision: {name}"
      - "## Purpose — what and why"
      - "## Problem Statement — pain points addressed"
      - "## Target Users — who benefits and how"
      - "## Goals — prioritized list"
      - "## Success Criteria — measurable targets table"
      - "## Design Principles — guiding decisions"
      - "## Non-Goals — explicit exclusions"
      - "## Key Decisions — tech choices with rationale"

  # SUPPORTING FILES - written in parallel after vision.md
  - path: "/workspace/CLAUDE.md"
    description: "Project overview, tech stack, how to work"
    structure:
      - "# {name}"
      - "## Purpose — 2-3 sentences"
      - "## Tech Stack — languages, frameworks, databases"
      - "## How to Work — /init, /feature, /fix"
      - "## Key Principles — MCP-first, semantic search, specialists"
      - "## Verification — test, lint, security commands"
      - "## Documentation — links to vision, architecture, workflows"

  - path: "/workspace/AGENTS.md"
    description: "Map tech stack to available specialist agents"
    structure:
      - "# Specialist Agents"
      - "## Primary — agents matching tech stack"
      - "## Supporting — review, devops, security agents"
      - "## Usage — when to invoke each agent"

  - path: "/workspace/docs/architecture.md"
    description: "System context, components, data flow"
    structure:
      - "# Architecture: {name}"
      - "## System Context — high-level view"
      - "## Components — key modules/services"
      - "## Data Flow — how data moves"
      - "## Technology Stack — detailed breakdown"
      - "## Constraints — technical boundaries"

  - path: "/workspace/docs/workflows.md"
    description: "Development processes adapted to tech stack"
    structure:
      - "# Development Workflows"
      - "## Setup — prerequisites, installation"
      - "## Development Loop — code, test, commit"
      - "## Testing Strategy — unit, integration, e2e"
      - "## Deployment — build, release process"
      - "## CI/CD — pipeline stages"

  - path: "/workspace/README.md"
    description: "Update description section only, preserve existing structure"
    mode: "edit"
    note: "Only update the project description. Keep all other content."

  # CONDITIONAL FILES
  - path: "/workspace/.env.example"
    condition: "database OR cloud services mentioned"
    description: "Environment variable template"
    structure:
      - "# {name} Environment Variables"
      - "APP_NAME={name}"
      - "# Database, cloud, API vars as relevant"

  - path: "/workspace/Makefile"
    condition: "language with build tooling (Go, Rust, Python, Node)"
    description: "Build targets adapted to tech stack"
    structure:
      - "# {name} targets"
      - "Standard targets: build, test, lint, fmt, clean"
      - "Language-specific targets as relevant"
```

---

## Phase 4: Environment Validation

**Verify the environment (parallel via Task agents).**

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

## Phase 5: Report

```
═══════════════════════════════════════════════════════════════
  /init - Complete
═══════════════════════════════════════════════════════════════

  Project: {name}
  Purpose: {purpose summary}

  Generated:
    ✓ docs/vision.md
    ✓ CLAUDE.md
    ✓ AGENTS.md
    ✓ docs/architecture.md
    ✓ docs/workflows.md
    ✓ README.md (updated)
    {conditional files}

  Environment:
    ✓ Tools installed ({tool list})
    ✓ Dependencies ready
    ✓ grepai indexed ({N} files)

  Ready to develop!
    → /feature "description" to start

═══════════════════════════════════════════════════════════════
```

---

## Auto-fix (automatic)

When a problem is detected, auto-fix if possible:

| Problem | Auto Action |
|---------|-------------|
| `.env` missing | `cp .env.example .env` |
| deps not installed | `npm ci` / `go mod download` |
| grepai not running | `nohup grepai watch &` |
| Ollama not reachable | Display HOST instructions |

---

## GARDE-FOUS

| Action | Status |
|--------|--------|
| Skip detection | INTERDIT |
| Closed questions / AskUserQuestion | INTERDIT |
| Placeholders in generated files | INTERDIT |
| Skip vision synthesis review | INTERDIT |
| Destructive fix without asking | INTERDIT |
