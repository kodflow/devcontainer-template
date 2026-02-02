# Kodflow DevContainer Template

A DevContainer template with Claude Code integration for AI-assisted development.

## Quick Start

```bash
# Clone and open in VS Code
git clone https://github.com/kodflow/devcontainer-template
code devcontainer-template

# Reopen in container (Ctrl+Shift+P)
Dev Containers: Reopen in Container

# Start working
/warmup    # Load project context
/docs      # View this documentation
```

## What's Included

| Component | Description |
|-----------|-------------|
| **Commands** | `/docs`, `/review`, `/git`, `/plan`, `/lint`, `/test` |
| **Agents** | Specialist agents for Go, Python, Node.js, Rust, etc. |
| **Hooks** | Auto-format, lint, security checks on file changes |
| **MCP Servers** | GitHub, Codacy, grepai, Playwright integrations |

## Key Principles

1. **MCP-First** - Use MCP tools before CLI fallback
2. **grepai-First** - Semantic search before regex
3. **RLM Decomposition** - Break complex tasks into sub-agents
4. **Hooks** - Automated quality gates

## Navigation

- [Guides](guides/README.md) - Workflows and commands
