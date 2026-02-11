# DevContainer Hooks

## Purpose

Lifecycle scripts for devcontainer events.

## Structure

```text
hooks/
├── lifecycle/          # DevContainer lifecycle hooks
│   ├── initialize.sh   # Initial setup
│   ├── onCreate.sh     # On container creation
│   ├── postAttach.sh   # After attaching to container
│   ├── postCreate.sh   # After container is ready
│   ├── postStart.sh    # After each container start
│   └── updateContent.sh # Content updates
└── shared/             # Shared utilities
    └── utils.sh        # Common functions
```

## Lifecycle Events

| Event | Script | Description |
|-------|--------|-------------|
| onCreate | onCreate.sh | Initial container creation |
| postCreate | postCreate.sh | After container ready |
| postAttach | postAttach.sh | After VS Code attaches |
| postStart | postStart.sh | After each start |

## Conventions

- Scripts must be executable (chmod +x)
- Use `set -u` (not `set -euo pipefail`) — prevents undefined vars without killing script on errors
- Use `run_step` pattern from `shared/utils.sh` to isolate each operation
- Each step runs in a subshell; failures are logged but never block container startup
- Call `print_step_summary` at end for PASS/FAIL report
