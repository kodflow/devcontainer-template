<!-- updated: 2026-02-12T08:40:00Z -->
# Lifecycle Hooks

## Purpose

DevContainer lifecycle scripts executed at specific container events.

## Scripts

| Script | Event | Description |
|--------|-------|-------------|
| `initialize.sh` | onCreateCommand | Initial setup (Ollama install on host) |
| `onCreate.sh` | onCreate | Container creation |
| `postCreate.sh` | postCreate | After container ready (runs once) |
| `postAttach.sh` | postAttach | After VS Code attaches |
| `postStart.sh` | postStart | After each start (MCP, grepai, VPN) |
| `updateContent.sh` | updateContent | Content updates |

## Execution Order

1. initialize.sh (earliest)
2. onCreate.sh
3. postCreate.sh
4. postStart.sh
5. postAttach.sh (latest)

## postStart.sh Key Subsystems

**grepai semantic search** (`init_semantic_search`, background):
- Multi-factor `.health-stamp` detects model/version/config changes
- Automatically purges and rebuilds index when any factor changes
- Watchdog daemon restarts `grepai watch` if it crashes (60s interval)

**VPN auto-connect** (`init_vpn`, background):
- Multi-protocol support (OpenVPN, WireGuard, IPsec, PPTP)
- Config from 1Password vault

## Conventions

- All scripts must be executable (`chmod +x`)
- Use `set -u` (not `set -euo pipefail`) to prevent undefined variable use without killing the script on errors
- Source `../shared/utils.sh` for common functions
- Use `run_step "name" function` pattern to isolate each operation in a subshell
- Each step tracks PASS/FAIL independently; script always exits 0
- Call `print_step_summary "label"` at the end to display results
