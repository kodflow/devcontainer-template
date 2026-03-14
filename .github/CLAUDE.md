<!-- updated: 2026-03-10T12:30:00Z -->
# GitHub Configuration

## Purpose

GitHub-specific configurations: workflows, templates, and instructions.

## Structure

```
.github/
├── workflows/          # GitHub Actions
│   ├── docker-images.yml
│   ├── release.yml
│   └── CLAUDE.md
├── instructions/       # AI coding instructions
├── dependabot.yml      # Dependency updates
└── CLAUDE.md           # This file
```

## Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| docker-images.yml | push/PR | Build devcontainer images |
| release.yml | push to main | Create release with claude-assets.tar.gz |

## Dependency Management

| File | Description |
|------|-------------|
| dependabot.yml | Automated dependency update configuration |

## Conventions

- Workflows use reusable actions where possible
- Secrets stored in GitHub repository settings
- Branch protection on main
