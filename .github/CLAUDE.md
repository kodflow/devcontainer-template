# GitHub Configuration

## Purpose
GitHub-specific configurations: workflows, templates, and instructions.

## Structure
```
.github/
├── workflows/       # GitHub Actions
│   └── docker-images.yml
└── instructions/    # Copilot/AI instructions
```

## Workflows
| Workflow | Trigger | Description |
|----------|---------|-------------|
| docker-images.yml | push/PR | Build devcontainer images |

## Conventions
- Workflows use reusable actions where possible
- Secrets stored in GitHub repository settings
- Branch protection on main
