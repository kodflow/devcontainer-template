# OpenVPN Client Feature

## Purpose

Optional OpenVPN client for VPN connectivity from within the DevContainer.
Entirely opt-in: without configuration, nothing happens.

## Components

| Component | Description |
|-----------|-------------|
| openvpn | OpenVPN client daemon |
| resolvconf | DNS resolution for VPN routes |
| vpn-connect | Start VPN connection |
| vpn-disconnect | Stop VPN connection |
| vpn-status | Check VPN state |

## Quick Start

```bash
# Manual connection (config must exist)
vpn-connect
vpn-status
vpn-disconnect
```

## Configuration

### Option 1: 1Password references (recommended)

Set in `.devcontainer/.env` (git-ignored):

```bash
# Format: op://VAULT/PROFILE
# Each profile = 2 items with same title in the vault:
#   "HOME" (DOCUMENT) → .ovpn file
#   "HOME" (LOGIN)    → username + password
OPENVPN_CONFIG_REF=op://VPN/HOME
```

Multiple profiles supported — add more items in the vault:

```
VPN vault:
├── "HOME"       (DOCUMENT) + "HOME"       (LOGIN)
├── "OFFICE"     (DOCUMENT) + "OFFICE"     (LOGIN)
└── "DATACENTER" (DOCUMENT) + "DATACENTER" (LOGIN)
```

Auto-connects on container start via `postStart.sh`.

### Option 2: File on disk

Place `.ovpn` file at `~/.config/openvpn/client.ovpn` (volume mount or manual copy).

### Priority order

1. `op://` reference in `.env` (resolved at runtime)
2. File on disk at `$OPENVPN_CONFIG`
3. Nothing found: skip silently

## Requirements

- `docker-compose.yml` must have `cap_add: [NET_ADMIN]` and `/dev/net/tun` device
- Feature must be enabled in `devcontainer.json`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `RTNETLINK: Operation not permitted` | Missing `NET_ADMIN` capability in docker-compose.yml |
| `Cannot open TUN/TAP dev` | Missing `/dev/net/tun` device in docker-compose.yml |
| `auth-user-pass` error | Check `OPENVPN_AUTH_USER_REF` / `OPENVPN_AUTH_PASS_REF` |
| DNS not resolving | Check `resolvconf` is installed: `resolvconf --version` |
| Logs | `cat /tmp/openvpn.log` |
