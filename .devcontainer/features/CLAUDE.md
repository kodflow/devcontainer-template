# DevContainer Features

## Purpose

Modular features for languages, tools, and architectures.

## Structure

```text
features/
├── languages/      # Language-specific (26 languages)
├── architectures/  # Architecture patterns (14 patterns)
├── claude/         # Claude Code standalone integration
└── kubernetes/     # Local K8s via kind
```

## Key Components

- Each language has `install.sh` + `devcontainer-feature.json`
- Conventions enforced by specialist agents (e.g., `developer-specialist-go`)
- install.sh runs on devcontainer build

## Adding a Language

1. Create `languages/<name>/`
2. Add `devcontainer-feature.json` for metadata
3. Add `install.sh` for installation
