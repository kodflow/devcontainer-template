#!/bin/bash
set -euo pipefail

echo "========================================="
echo "Installing OpenVPN Client"
echo "========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Target user for config directory (devcontainer provides _REMOTE_USER)
TARGET_USER="${_REMOTE_USER:-vscode}"
TARGET_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || echo "/home/${TARGET_USER}")"

# ─────────────────────────────────────────────────────────────────────────────
# Install OpenVPN + DNS resolution
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Installing openvpn...${NC}"

apt-get update -y
apt-get install -y --no-install-recommends openvpn
rm -rf /var/lib/apt/lists/*

echo -e "${GREEN}✓ openvpn $(openvpn --version 2>&1 | head -1 | awk '{print $2}') installed${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Create config directory
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Setting up OpenVPN config directory...${NC}"

mkdir -p "${TARGET_HOME}/.config/openvpn"
chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config/openvpn" 2>/dev/null || true
chmod 700 "${TARGET_HOME}/.config/openvpn"
echo -e "${GREEN}✓ Config directory created: ${TARGET_HOME}/.config/openvpn${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Create container-friendly DNS update script
# ─────────────────────────────────────────────────────────────────────────────
# In Docker containers, the standard update-resolv-conf relies on resolvconf
# which is a transitional package for systemd-resolved on Ubuntu 24.04.
# systemd-resolved requires D-Bus, which is not available in containers.
# This script writes /etc/resolv.conf directly instead.
echo -e "${YELLOW}Creating container-friendly DNS update script...${NC}"

cat > /etc/openvpn/update-dns << 'DNS_SCRIPT'
#!/bin/bash
# Container-friendly DNS update for OpenVPN
# Writes directly to /etc/resolv.conf (no systemd-resolved/D-Bus dependency)

[ "$script_type" ] || exit 0
[ "$dev" ] || exit 0

BACKUP="/etc/resolv.conf.ovpn-backup"

case "$script_type" in
  up)
    # Backup original resolv.conf (Docker DNS)
    [ ! -f "$BACKUP" ] && cp /etc/resolv.conf "$BACKUP"

    # Parse OpenVPN DHCP options
    NMSRVRS=""
    SRCHS=""
    for optionvarname in $(printf '%s\n' ${!foreign_option_*} | sort -t _ -k 3 -g); do
        option="${!optionvarname}"
        # shellcheck disable=SC2086
        set -- $option
        if [ "$1" = "dhcp-option" ]; then
            [ "$2" = "DNS" ] && NMSRVRS="${NMSRVRS:+$NMSRVRS }$3"
            [ "$2" = "DOMAIN" ] && SRCHS="${SRCHS:+$SRCHS }$3"
        fi
    done

    # Write new resolv.conf (VPN DNS + Docker fallback)
    {
        [ -n "$SRCHS" ] && echo "search $SRCHS"
        for ns in $NMSRVRS; do echo "nameserver $ns"; done
        # Keep Docker DNS as fallback
        grep '^nameserver' "$BACKUP" 2>/dev/null || true
    } > /etc/resolv.conf
    ;;
  down)
    # Restore original resolv.conf
    [ -f "$BACKUP" ] && mv "$BACKUP" /etc/resolv.conf
    ;;
esac
DNS_SCRIPT

chmod +x /etc/openvpn/update-dns
echo -e "${GREEN}✓ /etc/openvpn/update-dns created${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Create helper scripts
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Creating helper scripts...${NC}"

# --- vpn-connect ---
cat > /usr/local/bin/vpn-connect << 'CONNECT_SCRIPT'
#!/bin/bash
set -euo pipefail

OVPN_CONFIG="${OPENVPN_CONFIG:-/home/vscode/.config/openvpn/client.ovpn}"
OVPN_AUTH="${OPENVPN_AUTH:-/tmp/vpn-auth.txt}"

if pgrep -x openvpn &>/dev/null; then
    echo "OpenVPN is already running. Use vpn-disconnect first."
    exit 1
fi

if [ ! -f "$OVPN_CONFIG" ]; then
    echo "No OpenVPN config found at: $OVPN_CONFIG"
    echo "Place your .ovpn file there or set OPENVPN_CONFIG_REF in .env"
    exit 1
fi

VPN_ARGS=(
    --config "$OVPN_CONFIG"
    --daemon ovpn-client
    --log /tmp/openvpn.log
    --script-security 2
    --up /etc/openvpn/update-dns
    --down /etc/openvpn/update-dns
)

if [ -f "$OVPN_AUTH" ] && [ -s "$OVPN_AUTH" ]; then
    VPN_ARGS+=(--auth-user-pass "$OVPN_AUTH")
fi

echo "Starting OpenVPN..."
sudo openvpn "${VPN_ARGS[@]}"

# Wait for tun0
ATTEMPT=0
while [ "$ATTEMPT" -lt 15 ]; do
    if ip link show tun0 &>/dev/null; then
        VPN_IP=$(ip -4 addr show tun0 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "unknown")
        echo "VPN connected (tun0: $VPN_IP)"
        exit 0
    fi
    sleep 1
    ((ATTEMPT++))
done

echo "VPN started but tun0 not detected after 15s (check /tmp/openvpn.log)"
exit 1
CONNECT_SCRIPT

# --- vpn-disconnect ---
cat > /usr/local/bin/vpn-disconnect << 'DISCONNECT_SCRIPT'
#!/bin/bash
set -euo pipefail

if ! pgrep -x openvpn &>/dev/null; then
    echo "OpenVPN is not running."
    exit 0
fi

echo "Stopping OpenVPN..."
sudo killall openvpn 2>/dev/null || true

# Wait for process to stop
ATTEMPT=0
while [ "$ATTEMPT" -lt 10 ]; do
    if ! pgrep -x openvpn &>/dev/null; then
        echo "VPN disconnected."
        exit 0
    fi
    sleep 1
    ((ATTEMPT++))
done

echo "Warning: OpenVPN process still running after 10s"
exit 1
DISCONNECT_SCRIPT

# --- vpn-status ---
cat > /usr/local/bin/vpn-status << 'STATUS_SCRIPT'
#!/bin/bash

if pgrep -x openvpn &>/dev/null; then
    echo "Status: CONNECTED"
    if ip link show tun0 &>/dev/null; then
        VPN_IP=$(ip -4 addr show tun0 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "unknown")
        echo "Interface: tun0 ($VPN_IP)"
    else
        echo "Interface: tun0 not found (connecting...)"
    fi
    if [ -f /tmp/openvpn.log ]; then
        echo "Last log lines:"
        tail -5 /tmp/openvpn.log
    fi
else
    echo "Status: DISCONNECTED"
fi
STATUS_SCRIPT

chmod +x /usr/local/bin/vpn-connect
chmod +x /usr/local/bin/vpn-disconnect
chmod +x /usr/local/bin/vpn-status

echo -e "${GREEN}✓ Helper scripts created: vpn-connect, vpn-disconnect, vpn-status${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Allow vscode user to run openvpn and killall without password
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Configuring sudoers for OpenVPN...${NC}"

cat > /etc/sudoers.d/openvpn << 'SUDOERS'
# Allow vscode user to manage OpenVPN without password
vscode ALL=(ALL) NOPASSWD: /usr/sbin/openvpn
vscode ALL=(ALL) NOPASSWD: /usr/bin/killall openvpn
SUDOERS

chmod 440 /etc/sudoers.d/openvpn
echo -e "${GREEN}✓ sudoers configured for passwordless OpenVPN${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}OpenVPN client installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - openvpn $(openvpn --version 2>&1 | head -1 | awk '{print $2}')"
echo "  - update-dns (container-friendly DNS for VPN routes)"
echo "  - vpn-connect (start VPN)"
echo "  - vpn-disconnect (stop VPN)"
echo "  - vpn-status (check VPN state)"
echo ""
echo "Configuration:"
echo "  Config: ${TARGET_HOME}/.config/openvpn/client.ovpn"
echo "  Logs:   /tmp/openvpn.log"
echo ""
echo "Quick start:"
echo "  # Option 1: Set op:// references in .env (auto-connect on start)"
echo "  # Option 2: Place .ovpn file in ~/.config/openvpn/client.ovpn"
echo "  vpn-connect    # Manual connect"
echo "  vpn-status     # Check connection"
echo "  vpn-disconnect # Manual disconnect"
echo ""
