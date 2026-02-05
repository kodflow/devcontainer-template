# devcontainer-template

## Purpose

Universal DevContainer shell providing cutting-edge AI agents, skills, and workflows to bootstrap any project. Reliability first: agents reason deeply, cross-reference sources, and self-correct until the output meets quality standards.

## Project Structure

```
/workspace
├── src/          # All source code (mandatory)
├── tests/        # Unit tests (Go: alongside code in src/)
├── docs/         # Documentation (vision, architecture, workflows)
└── CLAUDE.md     # This file
```

## Tech Stack

- **Languages**: Go, Python, Node.js, Rust, Elixir, Java, PHP, Ruby, Scala, Dart, C++, Carbon
- **Cloud CLIs**: AWS v2, GCP SDK, Azure CLI
- **IaC**: Terraform, Vault, Consul, Nomad, Packer, Ansible
- **Containers**: Docker, kubectl, Helm
- **AI**: Claude Code, MCP servers (GitHub, Codacy, Playwright, context7, grepai)

## How to Work

1. **New project**: `/init` → conversational discovery → doc generation
2. **New feature**: `/feature "description"` → planning mode → PR
3. **Bug fix**: `/fix "description"` → planning mode → PR
4. **Code review**: `/review` → 5 specialist executors in parallel

Branch conventions: `feat/<desc>` or `fix/<desc>`, commit prefix matches.

## Key Principles

**Reliability first**: Verify before generating. Agents consult context7 and official docs before producing non-trivial code.

**MCP-first**: Use MCP tools (`mcp__github__*`, `mcp__codacy__*`) before CLI fallbacks. Auth is pre-configured.

**Self-correction**: When linting or tests fail, agents fix and retry automatically.

**Semantic search**: Use `grepai_search` for meaning-based queries. Fall back to Grep for exact strings.

**Specialist agents**: Language conventions enforced by agents that know current stable versions.

**Deep reasoning**: For complex tasks — Peek, Decompose, Parallelize, Synthesize.

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
├── AGENTS.md                # Specialist agents for tech stack
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
| `/init` | Conversational project discovery + doc generation |
| `/feature` | Start feature branch with planning |
| `/fix` | Start fix branch with planning |
| `/review` | Code review with 5 specialist agents |
| `/plan` | Analyze codebase and design implementation approach |
| `/do` | Execute approved plans iteratively |
| `/git` | Conventional commits, branch management |
| `/improve` | Documentation QA for design patterns |

## Verification

Changes are complete when:
- Tests pass (`make test` or language equivalent)
- Linting passes (auto-run by hooks)
- No secrets in commits (checked by security hook)
- Commit follows conventional format
