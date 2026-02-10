---
name: ovpn
description: |
  OpenVPN client management with 1Password multi-profile support.
  List/connect/disconnect VPN profiles from vault "VPN".
  Use when: managing VPN connections, listing available profiles.
allowed-tools:
  - "Bash(op:*)"
  - "Bash(sudo:*)"
  - "Bash(pgrep:*)"
  - "Bash(ip:*)"
  - "Bash(tail:*)"
  - "Bash(wc:*)"
  - "Bash(jq:*)"
  - "Read(**/*)"
  - "Edit(**/.env)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "AskUserQuestion(*)"
---

# /ovpn - OpenVPN Client Management (1Password Multi-Profile)

$ARGUMENTS

---

## Overview

Interactive VPN management via **1Password CLI** (`op`) with multi-profile support:

- **Peek** - Verify prerequisites (openvpn, op CLI, vault access, current state)
- **Execute** - List profiles, connect, disconnect, or show status
- **Synthesize** - Display formatted result

**Backend**: 1Password vault "VPN" (configurable via `OPENVPN_VAULT`)
**Convention**: Each profile = 2 items with same title in the vault:
  - `PROFILE` (DOCUMENT) = `.ovpn` config file
  - `PROFILE` (LOGIN) = username + password

---

## Arguments

| Pattern | Action |
|---------|--------|
| `--list` | List available VPN profiles from 1Password vault |
| `--connect <profile>` | Connect to a named VPN profile |
| `--connect` (no arg) | Connect using default profile from `OPENVPN_CONFIG_REF` in `.env` |
| `--disconnect` | Stop VPN and clean up credentials |
| `--status` | Show connection state, tun0 IP, and recent logs |
| `--help` | Show usage |

### Examples

```bash
# List available VPN profiles
/ovpn --list

# Connect to a specific profile
/ovpn --connect HOME

# Connect using default from .env
/ovpn --connect

# Check VPN status
/ovpn --status

# Disconnect
/ovpn --disconnect
```

---

## --help

```
═══════════════════════════════════════════════════════════════
  /ovpn - OpenVPN Client Management (1Password)
═══════════════════════════════════════════════════════════════

Usage: /ovpn <action> [options]

Actions:
  --list                  List VPN profiles in vault
  --connect [profile]     Connect to VPN (default: from .env)
  --disconnect            Stop VPN and clean up
  --status                Show connection state

Options:
  --help                  Show this help

1Password Convention (vault "VPN"):
  Each profile = 2 items with same title:
    "HOME" (DOCUMENT) → .ovpn config file
    "HOME" (LOGIN)    → username + password

  Configure default: OPENVPN_CONFIG_REF=op://VPN/HOME
  in .devcontainer/.env

Examples:
  /ovpn --list
  /ovpn --connect HOME
  /ovpn --connect
  /ovpn --status
  /ovpn --disconnect

═══════════════════════════════════════════════════════════════
```

---

## Phase 1: Peek (MANDATORY)

**Verify prerequisites BEFORE any action:**

```yaml
peek_workflow:
  1_check_openvpn:
    action: "Verify openvpn is installed"
    command: "command -v openvpn"
    on_failure: |
      ABORT with message:
      "OpenVPN not installed. Enable the openvpn feature in devcontainer.json:
       \"./features/openvpn\": {}"

  2_check_op:
    action: "Verify op CLI is available"
    command: "command -v op"
    on_failure: |
      ABORT with message:
      "op CLI not found. Install 1Password CLI or run inside DevContainer."

  3_check_token:
    action: "Verify OP_SERVICE_ACCOUNT_TOKEN"
    command: "test -n \"$OP_SERVICE_ACCOUNT_TOKEN\""
    on_failure: |
      ABORT with message:
      "OP_SERVICE_ACCOUNT_TOKEN not set. Configure in .devcontainer/.env"

  4_check_vault:
    action: "Verify access to VPN vault"
    command: "op vault get \"${OPENVPN_VAULT:-VPN}\" --format json 2>/dev/null | jq -r '.id'"
    store: "VAULT_NAME"
    on_failure: |
      ABORT with message:
      "Cannot access vault '${OPENVPN_VAULT:-VPN}'. Check 1Password configuration."

  5_check_state:
    action: "Check if VPN is already connected"
    command: "pgrep -x openvpn"
    store: "VPN_RUNNING (boolean)"
    note: "Informational - does not abort"
```

**Output Phase 1:**

```
═══════════════════════════════════════════════════════════════
  /ovpn - Connection Check
═══════════════════════════════════════════════════════════════

  OpenVPN CLI  : /usr/sbin/openvpn ✓
  1Password CLI: op v2.32.0 ✓
  Service Token: OP_SERVICE_ACCOUNT_TOKEN ✓ (set)
  Vault Access : VPN ✓
  VPN State    : DISCONNECTED

═══════════════════════════════════════════════════════════════
```

---

## Action: --list

**List available VPN profiles from 1Password vault:**

```yaml
list_workflow:
  1_list_documents:
    action: "List DOCUMENT items in VPN vault"
    command: |
      vault="${OPENVPN_VAULT:-VPN}"
      op item list --vault "$vault" --categories DOCUMENT --format json \
        | jq -r '.[].title'
    store: "PROFILES"

  2_display:
    action: "Display available profiles"
    format: "Table with profile name and availability"
```

**Output --list:**

```
═══════════════════════════════════════════════════════════════
  /ovpn --list
═══════════════════════════════════════════════════════════════

  Vault: VPN

  | Profile    | Config (.ovpn) | Credentials |
  |------------|----------------|-------------|
  | HOME       | ✓ DOCUMENT     | ✓ LOGIN     |
  | OFFICE     | ✓ DOCUMENT     | ✓ LOGIN     |
  | DATACENTER | ✓ DOCUMENT     | ✗ missing   |

  Total: 3 profiles

  Default: HOME (from OPENVPN_CONFIG_REF)

═══════════════════════════════════════════════════════════════
```

---

## Action: --connect

**Connect to a VPN profile:**

```yaml
connect_workflow:
  1_check_not_connected:
    action: "Block if already connected"
    command: "pgrep -x openvpn"
    on_match: |
      ABORT with message:
      "VPN already connected. Use /ovpn --disconnect first."

  2_resolve_profile:
    action: "Determine profile name"
    logic: |
      if argument provided:
        profile = argument
      else:
        # Read from .env
        ref="${OPENVPN_CONFIG_REF:-}"
        if [ -z "$ref" ]; then
          ABORT "No profile specified and OPENVPN_CONFIG_REF not set.
                 Use: /ovpn --connect <profile>
                 Or set OPENVPN_CONFIG_REF=op://VPN/PROFILE in .devcontainer/.env"
        fi
        ref="${ref#op://}"
        profile=$(echo "$ref" | cut -d'/' -f2)

  3_resolve_uuids:
    action: "Resolve DOCUMENT and LOGIN UUIDs (avoids same-title ambiguity)"
    command: |
      vault="${OPENVPN_VAULT:-VPN}"
      doc_uuid=$(op item list --vault "$vault" --categories DOCUMENT --format json \
        | jq -r --arg t "$profile" '.[] | select(.title==$t) | .id')
      login_uuid=$(op item list --vault "$vault" --categories LOGIN --format json \
        | jq -r --arg t "$profile" '.[] | select(.title==$t) | .id')

  4_download_config:
    action: "Download .ovpn config by UUID"
    command: |
      mkdir -p ~/.config/openvpn
      op document get "$doc_uuid" --vault "$vault" > ~/.config/openvpn/client.ovpn
      chmod 600 ~/.config/openvpn/client.ovpn
    on_failure: |
      ABORT "Failed to download .ovpn config for profile '$profile'"

  5_resolve_credentials:
    action: "Get username/password from LOGIN item"
    command: |
      vpn_user=$(op read "op://$vault/$login_uuid/username")
      vpn_pass=$(op read "op://$vault/$login_uuid/password")
      printf '%s\n%s\n' "$vpn_user" "$vpn_pass" > /tmp/vpn-auth.txt
      chmod 600 /tmp/vpn-auth.txt
    note: "NEVER log passwords"
    on_failure: "Continue without auth (some configs don't need credentials)"

  6_connect:
    action: "Start OpenVPN with auto-reconnect"
    command: |
      sudo openvpn \
        --config ~/.config/openvpn/client.ovpn \
        --daemon ovpn-client \
        --log /tmp/openvpn.log \
        --script-security 2 \
        --up /etc/openvpn/update-dns \
        --down /etc/openvpn/update-dns \
        --keepalive 10 60 \
        --connect-retry 5 \
        --connect-retry-max 0 \
        --persist-tun \
        --persist-key \
        --resolv-retry infinite \
        --auth-user-pass /tmp/vpn-auth.txt
    note: |
      Uses sudo openvpn directly (not vpn-connect helper)
      Auto-reconnect flags ensure persistent connection:
        --keepalive 10 60       (ping every 10s, restart after 60s silence)
        --connect-retry 5       (retry every 5s)
        --connect-retry-max 0   (retry forever)
        --persist-tun           (keep tun device across reconnects)
        --persist-key           (keep key across reconnects)
        --resolv-retry infinite (retry DNS forever)

  7_verify:
    action: "Wait for tun0 interface"
    command: |
      attempt=0
      while [ $attempt -lt 15 ]; do
        if ip link show tun0 &>/dev/null; then
          vpn_ip=$(ip -4 addr show tun0 | grep -oP 'inet \K[\d.]+')
          echo "CONNECTED: $vpn_ip"
          break
        fi
        sleep 1
        ((attempt++))
      done
    timeout: "15 seconds"
```

**Output --connect (success):**

```
═══════════════════════════════════════════════════════════════
  /ovpn --connect HOME
═══════════════════════════════════════════════════════════════

  Profile  : HOME
  Vault    : VPN
  Config   : ✓ Downloaded (.ovpn)
  Creds    : ✓ Resolved (username + password)
  Status   : CONNECTED
  Interface: tun0 (10.8.0.2)

═══════════════════════════════════════════════════════════════
```

---

## Action: --disconnect

**Stop VPN and clean up:**

```yaml
disconnect_workflow:
  1_check_running:
    action: "Verify VPN is running"
    command: "pgrep -x openvpn"
    on_failure: |
      INFO "VPN is not running. Nothing to disconnect."
      return

  2_stop:
    action: "Kill openvpn process"
    command: "sudo killall openvpn 2>/dev/null || true"

  3_cleanup:
    action: "Remove credentials file"
    command: "rm -f /tmp/vpn-auth.txt"
    note: "Ephemeral credentials cleaned up"

  4_verify:
    action: "Confirm disconnection"
    command: "! pgrep -x openvpn && ! ip link show tun0 2>/dev/null"
```

**Output --disconnect:**

```
═══════════════════════════════════════════════════════════════
  /ovpn --disconnect
═══════════════════════════════════════════════════════════════

  Action : Stopped openvpn daemon
  Cleanup: /tmp/vpn-auth.txt removed
  Status : DISCONNECTED

═══════════════════════════════════════════════════════════════
```

---

## Action: --status

**Check current VPN state:**

```yaml
status_workflow:
  1_check_process:
    action: "Check openvpn process"
    command: "pgrep -x openvpn"
    store: "PID or empty"

  2_check_interface:
    action: "Check tun0 interface"
    command: "ip addr show tun0 2>/dev/null"
    store: "IP address or empty"

  3_check_logs:
    action: "Show recent log lines"
    command: "tail -5 /tmp/openvpn.log 2>/dev/null"
    store: "Recent logs"
```

**Output --status (connected):**

```
═══════════════════════════════════════════════════════════════
  /ovpn --status
═══════════════════════════════════════════════════════════════

  Process  : openvpn (PID: 1234) ✓
  Interface: tun0 (10.8.0.2) ✓
  Uptime   : Running

  Recent logs:
    [timestamp] Initialization Sequence Completed
    [timestamp] TUN/TAP device tun0 opened

═══════════════════════════════════════════════════════════════
```

**Output --status (disconnected):**

```
═══════════════════════════════════════════════════════════════
  /ovpn --status
═══════════════════════════════════════════════════════════════

  Process  : not running ✗
  Interface: tun0 not found ✗
  Status   : DISCONNECTED

  Hint: Use /ovpn --connect to start VPN

═══════════════════════════════════════════════════════════════
```

---

## SAFEGUARDS (ABSOLUTE)

| Action | Status | Reason |
|--------|--------|--------|
| Connect if already connected | BLOCKED | Must `--disconnect` first |
| Log passwords or credentials | FORBIDDEN | Security |
| Commit `.ovpn` files | BLOCKED | Protected by `.gitignore` |
| Store credentials outside `/tmp` | FORBIDDEN | Ephemeral only |
| Skip Phase 1 (Peek) | FORBIDDEN | Must verify prerequisites |
| Connect without confirming profile | FORBIDDEN | Must resolve and display profile name |
| Run without `OP_SERVICE_ACCOUNT_TOKEN` | BLOCKED | Auth required for 1Password |
