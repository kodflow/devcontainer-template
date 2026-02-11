<!-- updated: 2026-02-11T21:58:22Z -->
# DevContainer Configuration

## Purpose

Development container setup for consistent dev environments across languages.

## Structure

```text
.devcontainer/
├── devcontainer.json    # Main config
├── docker-compose.yml   # Multi-service setup
├── Dockerfile           # Extends images/ base
├── install.sh           # Standalone Claude installer
├── claude-assets.tar.gz # Pre-built Claude assets
├── scripts/             # Build utilities
├── features/            # Language & tool features
├── hooks/               # Lifecycle scripts
└── images/              # Docker base image
```

## Key Files

- `devcontainer.json`: VS Code devcontainer config
- `docker-compose.yml`: Services (app, MCP servers)
- `.env`: Environment variables (git-ignored)

## Usage

Features are enabled in `devcontainer.json` under `features`.
Language conventions are enforced by specialist agents (e.g., `developer-specialist-go`).
