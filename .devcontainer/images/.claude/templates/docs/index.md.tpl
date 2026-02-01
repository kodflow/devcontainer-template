# {{PROJECT_NAME}}

Welcome to the **{{PROJECT_NAME}}** documentation.

## Quick Links

| Section | Description |
|---------|-------------|
| [Architecture](architecture/README.md) | C4 diagrams and system design |
| [ADR](adr/README.md) | Architecture Decision Records |
| [API](api/README.md) | API documentation |
| [Runbooks](runbooks/README.md) | Operational procedures |
| [Guides](guides/README.md) | Developer and user guides |

## Getting Started

1. Review the [Architecture](architecture/README.md) overview
2. Check [ADR](adr/README.md) for design decisions
3. Follow the [Guides](guides/README.md) for setup instructions

## Project Structure

```
{{PROJECT_NAME}}/
├── src/                    # Source code
├── tests/                  # Test files
├── docs/                   # Additional documentation
└── .docs/                  # MkDocs documentation (this site)
```

## Commands

| Command | Description |
|---------|-------------|
| `/docs --serve` | Start documentation server on :8080 |
| `/docs --build` | Build static documentation |
| `/c4` | Generate C4 architecture diagrams |

---

*Documentation generated with [Claude Code](https://claude.ai/claude-code) and [MkDocs Material](https://squidfunk.github.io/mkdocs-material/)*
