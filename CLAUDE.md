# Kodflow DevContainer Template

## Project Structure

```text
/workspace
├── src/                    # ALL source code (mandatory)
├── tests/                  # Unit tests (except Go: alongside code)
├── docs/                   # Documentation
└── CLAUDE.md               # This file
```

**Rules:** ALL code in `/src`, tests in `/tests` (Go: tests in `/src`).

## Workflow

```
/warmup → /plan <feature> → /do → /git --commit
```

| Command | Action |
|---------|--------|
| `/warmup` | Précharge contexte projet |
| `/plan` | Mode planification |
| `/do` | Exécution itérative |
| `/git --commit` | Branch + commit + PR |
| `/improve` | Amélioration continue (auto-détecté) |
| `/review` | Code review RLM |

## Branch Conventions

| Type | Branch | Commit |
|------|--------|--------|
| Feature | `feat/<desc>` | `feat(scope): message` |
| Bugfix | `fix/<desc>` | `fix(scope): message` |

## Key Rules (Details in `.devcontainer/images/.claude/CLAUDE.md`)

| Rule | Summary |
|------|---------|
| **MCP-FIRST** | Use MCP tools before CLI (`mcp__github__*` > `gh`) |
| **GREPAI-FIRST** | Use grepai for semantic search, Grep as fallback |
| **NO AI REFS** | Never mention AI in commits/docs (hook enforced) |
| **SAFEGUARDS** | Never delete `.claude/` or `.devcontainer/` without approval |

## Code Quality

- Latest stable language versions (enforced by specialist agents)
- Security-first approach
- Full test coverage
- No deprecated APIs

## Context Hierarchy

```
/CLAUDE.md                          # This file (overview)
├── .devcontainer/CLAUDE.md         # DevContainer config
│   ├── images/CLAUDE.md            # Docker images + MCP
│   │   └── .claude/CLAUDE.md       # Core rules (detailed)
│   ├── features/CLAUDE.md          # Features overview
│   └── hooks/CLAUDE.md             # Hooks overview
└── .github/CLAUDE.md               # CI/CD workflows
```

**Principle:** Root = overview, deeper = details. Max 100 lines per file.
