<!-- updated: 2026-02-25T01:00:00Z -->
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
├── instructions/       # AI instructions
│   └── codacy.instructions.md
└── CLAUDE.md           # This file
```

## Workflows

| Workflow | Trigger | Description |
|----------|---------|-------------|
| docker-images.yml | push/PR | Build devcontainer images |
| release.yml | push to main | Create release with claude-assets.tar.gz |

## Instructions

| File | Description |
|------|-------------|
| codacy.instructions.md | Codacy code quality AI instructions |

## Conventions

- Workflows use reusable actions where possible
- Secrets stored in GitHub repository settings
- Branch protection on main
