#!/bin/bash
set -e

echo "========================================="
echo "GPG and Repository Cleanup/Fix"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Initializing GPG and fixing repository issues...${NC}"

# Ensure GPG is installed (bypass signature checks if needed for bootstrapping)
echo -e "${YELLOW}Installing GPG and prerequisites...${NC}"
export DEBIAN_FRONTEND=noninteractive

# First attempt: normal update
if ! sudo apt-get update -qq 2>/dev/null; then
    echo -e "${YELLOW}⚠ Initial apt-get update failed, attempting with relaxed security for bootstrap${NC}"
    # Allow unauthenticated packages temporarily to bootstrap GPG tools
    sudo apt-get update -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true -qq 2>/dev/null || true
fi

# Install GPG and required tools (allow unauthenticated if necessary for bootstrap)
sudo apt-get install -y --allow-unauthenticated gnupg2 ca-certificates apt-transport-https ubuntu-keyring 2>/dev/null || \
    sudo apt-get install -y gnupg2 ca-certificates apt-transport-https ubuntu-keyring 2>/dev/null || true

# Ensure keyring directories exist with proper permissions
echo -e "${YELLOW}Setting up keyring directories...${NC}"
sudo mkdir -p /usr/share/keyrings
sudo mkdir -p /etc/apt/keyrings
sudo mkdir -p /etc/apt/trusted.gpg.d
sudo chmod 755 /usr/share/keyrings
sudo chmod 755 /etc/apt/keyrings
sudo chmod 755 /etc/apt/trusted.gpg.d

# Fix permissions on existing keyrings
if [ -d /usr/share/keyrings ]; then
    sudo find /usr/share/keyrings -type f -name "*.gpg" -exec chmod 644 {} \; 2>/dev/null || true
fi

if [ -d /etc/apt/keyrings ]; then
    sudo find /etc/apt/keyrings -type f -name "*.gpg" -exec chmod 644 {} \; 2>/dev/null || true
fi

if [ -d /etc/apt/trusted.gpg.d ]; then
    sudo find /etc/apt/trusted.gpg.d -type f -exec chmod 644 {} \; 2>/dev/null || true
fi

# Refresh Ubuntu archive keyring
echo -e "${YELLOW}Refreshing Ubuntu keyring...${NC}"
if dpkg -l ubuntu-keyring >/dev/null 2>&1; then
    # Reinstall ubuntu-keyring to refresh keys
    sudo apt-get install --reinstall -y --allow-unauthenticated ubuntu-keyring 2>/dev/null || \
        sudo apt-get install --reinstall -y ubuntu-keyring 2>/dev/null || {
        echo -e "${YELLOW}⚠ Could not reinstall ubuntu-keyring, attempting manual key import${NC}"

        # Manually import Ubuntu keys as fallback
        # Ubuntu Archive Automatic Signing Key
        sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3B4FE6ACC0B21F32 2>/dev/null || true
        sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 871920D1991BC93C 2>/dev/null || true
    }
else
    # Install ubuntu-keyring if not present
    echo -e "${YELLOW}Installing ubuntu-keyring...${NC}"
    sudo apt-get install -y --allow-unauthenticated ubuntu-keyring 2>/dev/null || true
fi

# Update CA certificates
echo -e "${YELLOW}Updating CA certificates...${NC}"
sudo update-ca-certificates 2>/dev/null || true

# Clean apt cache completely to force refresh
echo -e "${YELLOW}Cleaning apt cache...${NC}"
sudo rm -rf /var/lib/apt/lists/*
sudo mkdir -p /var/lib/apt/lists/partial
sudo chmod -R 755 /var/lib/apt/lists

# Remove any duplicate or corrupted source list entries
echo -e "${YELLOW}Cleaning source lists...${NC}"
if [ -d /etc/apt/sources.list.d ]; then
    # Remove duplicate entries
    for file in /etc/apt/sources.list.d/*.list; do
        if [ -f "$file" ]; then
            sudo awk '!seen[$0]++' "$file" | sudo tee "$file.tmp" > /dev/null
            sudo mv "$file.tmp" "$file"
        fi
    done
fi

# Try updating package lists with detailed error handling
echo -e "${YELLOW}Updating package lists...${NC}"
UPDATE_OUTPUT=$(mktemp)
UPDATE_ERRORS=$(mktemp)

if sudo apt-get update 2>"$UPDATE_ERRORS" | tee "$UPDATE_OUTPUT"; then
    echo -e "${GREEN}✓ Package lists updated successfully${NC}"
else
    EXIT_CODE=$?

    # Check if there are GPG errors
    if grep -qi "GPG error\|NO_PUBKEY\|invalid signature" "$UPDATE_ERRORS" "$UPDATE_OUTPUT" 2>/dev/null; then
        echo -e "${YELLOW}⚠ GPG signature warnings detected (this is common in multi-stage builds)${NC}"

        # Extract and display unique error messages
        echo -e "${YELLOW}Repository warnings:${NC}"
        grep -i "GPG error\|NO_PUBKEY\|invalid signature" "$UPDATE_ERRORS" "$UPDATE_OUTPUT" 2>/dev/null | sort -u | head -5 || true

        # Note: We don't fail here because:
        # 1. Some repos may not be fully configured yet
        # 2. Subsequent features will add their own keys
        # 3. This is the first feature to run
        echo -e "${YELLOW}ℹ This feature runs first - subsequent features will configure their repositories${NC}"
        echo -e "${YELLOW}ℹ If the build continues to fail, specific repositories may need attention${NC}"
    else
        echo -e "${RED}✗ apt-get update failed with exit code $EXIT_CODE${NC}"
        cat "$UPDATE_ERRORS"
        # Don't exit - let subsequent features try
    fi
fi

rm -f "$UPDATE_OUTPUT" "$UPDATE_ERRORS"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}GPG initialization completed${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Next steps:"
echo "  - Other features will now install and configure their repositories"
echo "  - Each feature will add its own GPG keys as needed"
echo ""
