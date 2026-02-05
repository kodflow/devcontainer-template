# Kodflow DevContainer Template

## Why This Exists

A batteries-included Dev Container for consistent, secure development environments. Ships Claude CLI, cloud CLIs, and language tooling so projects bootstrap in seconds with repeatable workflows.

## Project Structure

```
/workspace
├── src/          # All source code (mandatory)
├── tests/        # Unit tests (Go: alongside code in src/)
├── docs/         # Documentation (vision, architecture, workflows)
└── CLAUDE.md     # This file
```

## How to Work

1. **Generate context**: `/build --context` creates CLAUDE.md in subdirectories
2. **New feature**: `/feature "description"` → planning mode → PR
3. **Bug fix**: `/fix "description"` → planning mode → PR

Branch conventions: `feat/<desc>` or `fix/<desc>`, commit prefix matches.

## Key Principles

**MCP-first**: Use MCP tools (`mcp__github__*`, `mcp__codacy__*`) before CLI fallbacks. MCP has pre-configured auth.

**Semantic search**: Use `grepai_search` for meaning-based queries. Fall back to Grep for exact strings or regex.

**Specialist agents**: Language conventions enforced by agents (`developer-specialist-go`, etc.). They know current stable versions.

**Reasoning patterns**: For complex tasks, apply: Peek → Decompose → Parallelize → Synthesize.

## Safeguards

Ask before:
- Deleting files in `.claude/` or `.devcontainer/`
- Removing features from `.claude/commands/*.md`
- Removing hooks from `.devcontainer/hooks/`

When refactoring: move content to separate files, preserve logic.

## Pre-commit

Auto-detected by language marker (`go.mod`, `Cargo.toml`, `package.json`, etc.). Priority: Makefile targets, then language-specific commands.

## Hooks

| Hook | Purpose |
|------|---------|
| pre-validate | Protect sensitive files |
| post-edit | Format + lint |
| security | Secret detection |
| test | Run related tests |

## Documentation Hierarchy

```
CLAUDE.md                    # This overview
├── docs/vision.md           # Objectives, success criteria
├── docs/architecture.md     # System design, components
├── docs/workflows.md        # Detailed workflows
├── .devcontainer/CLAUDE.md  # Container config details
└── .claude/commands/        # Slash commands
```

Principle: More detail deeper in tree. Each file < 100 lines.

## Commands

| Command | Purpose |
|---------|---------|
| `/init` | **Setup** - Personalize + validate environment |
| `/feature` | Start feature branch with planning |
| `/fix` | Start fix branch with planning |
| `/review` | Code review with specialist agents |
| `/improve` | Documentation QA for design patterns |

## New Project Setup

After creating a project from this template:
1. Run `/init` (auto-detects template, asks questions, validates)
2. Start with `/feature <description>`

## Verification

Changes are complete when:
- Tests pass (`make test` or language equivalent)
- Linting passes (auto-run by hooks)
- No secrets in commits (checked by security hook)
- Commit follows conventional format
