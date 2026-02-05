# Development Workflows

## Quick Reference

| Task | Command |
|------|---------|
| Generate context | `/build --context` |
| New feature | `/feature <description>` |
| Bug fix | `/fix <description>` |
| Code review | `/review` |
| Run tests | `make test` or language-specific |

## Feature Development

```
/build --context → /feature "add user auth" → implement → /review → PR
```

1. Generate CLAUDE.md files with `/build --context`
2. Create feature branch with `/feature "description"`
3. Implement changes (planning mode activated)
4. Run `/review` for code quality check
5. PR created automatically (no auto-merge)

## Bug Fixes

```
/build --context → /fix "login timeout" → implement → /review → PR
```

Same flow as features, uses `fix/` branch prefix.

## Branch Conventions

| Type | Branch | Commit |
|------|--------|--------|
| Feature | `feat/<desc>` | `feat(scope): message` |
| Bug fix | `fix/<desc>` | `fix(scope): message` |

## Pre-commit Checks

Auto-detected by language:

| Marker | Language | Checks |
|--------|----------|--------|
| `go.mod` | Go | golangci-lint, build, test -race |
| `Cargo.toml` | Rust | clippy, build, test |
| `package.json` | Node | lint, build, test |
| `pyproject.toml` | Python | ruff, mypy, pytest |

Priority: Makefile targets → Language-specific commands

## MCP Integration

Prefer MCP tools over CLI:
- `mcp__github__*` before `gh` CLI
- `mcp__codacy__*` before `codacy-cli`

MCP servers have pre-configured auth via `mcp.json`.

## Search Strategy

1. **Semantic search**: `grepai_search` for meaning-based queries
2. **Call graphs**: `grepai_trace_callers/callees` for impact analysis
3. **Fallback to Grep**: Exact strings, regex patterns, or when grepai unavailable

## Hooks

| Hook | Action |
|------|--------|
| `pre-validate.sh` | Protect sensitive files |
| `post-edit.sh` | Format + lint |
| `security.sh` | Secret detection |
| `test.sh` | Run related tests |
