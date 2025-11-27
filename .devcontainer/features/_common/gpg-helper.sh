#!/bin/bash
# Common GPG helper functions for devcontainer features
# This script provides robust GPG key and repository management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================================
# GPG Key Management Functions
# ============================================================================

# Add a GPG key from a URL and save it to a keyring file
# Usage: add_gpg_key <key_url> <keyring_path>
add_gpg_key() {
    local key_url="$1"
    local keyring_path="$2"

    if [ -z "$key_url" ] || [ -z "$keyring_path" ]; then
        echo -e "${RED}Error: add_gpg_key requires URL and keyring path${NC}" >&2
        return 1
    fi

    echo -e "${YELLOW}Adding GPG key from $key_url...${NC}"

    # Create directory if it doesn't exist
    sudo mkdir -p "$(dirname "$keyring_path")"

    # Download and add key with retries
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if curl -fsSL "$key_url" | sudo gpg --dearmor -o "$keyring_path" 2>/dev/null; then
            # Verify the keyring file was created
            if [ -f "$keyring_path" ]; then
                sudo chmod 644 "$keyring_path"
                echo -e "${GREEN}✓ GPG key added successfully${NC}"
                return 0
            fi
        fi

        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo -e "${YELLOW}Retry $retry_count/$max_retries...${NC}"
            sleep 2
        fi
    done

    echo -e "${RED}Failed to add GPG key after $max_retries attempts${NC}" >&2
    return 1
}

# Add a GPG key using wget
# Usage: add_gpg_key_wget <key_url> <keyring_path>
add_gpg_key_wget() {
    local key_url="$1"
    local keyring_path="$2"

    if [ -z "$key_url" ] || [ -z "$keyring_path" ]; then
        echo -e "${RED}Error: add_gpg_key_wget requires URL and keyring path${NC}" >&2
        return 1
    fi

    echo -e "${YELLOW}Adding GPG key from $key_url...${NC}"

    # Create directory if it doesn't exist
    sudo mkdir -p "$(dirname "$keyring_path")"

    # Download and add key with retries
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if wget -qO- "$key_url" | gpg --dearmor | sudo tee "$keyring_path" > /dev/null 2>&1; then
            # Verify the keyring file was created
            if [ -f "$keyring_path" ]; then
                sudo chmod 644 "$keyring_path"
                echo -e "${GREEN}✓ GPG key added successfully${NC}"
                return 0
            fi
        fi

        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo -e "${YELLOW}Retry $retry_count/$max_retries...${NC}"
            sleep 2
        fi
    done

    echo -e "${RED}Failed to add GPG key after $max_retries attempts${NC}" >&2
    return 1
}

# ============================================================================
# Repository Management Functions
# ============================================================================

# Add an APT repository with proper architecture and signing key
# Usage: add_apt_repository <repo_line> <list_file>
add_apt_repository() {
    local repo_line="$1"
    local list_file="$2"

    if [ -z "$repo_line" ] || [ -z "$list_file" ]; then
        echo -e "${RED}Error: add_apt_repository requires repository line and list file${NC}" >&2
        return 1
    fi

    echo -e "${YELLOW}Adding repository to $list_file...${NC}"

    # Create directory if it doesn't exist
    sudo mkdir -p "$(dirname "$list_file")"

    # Add repository
    echo "$repo_line" | sudo tee "$list_file" > /dev/null

    if [ -f "$list_file" ]; then
        echo -e "${GREEN}✓ Repository added successfully${NC}"
        return 0
    else
        echo -e "${RED}Failed to add repository${NC}" >&2
        return 1
    fi
}

# ============================================================================
# APT Update with Error Handling
# ============================================================================

# Run apt-get update with proper error handling
# Usage: safe_apt_update
safe_apt_update() {
    echo -e "${YELLOW}Updating package lists...${NC}"

    # First, try a simple update
    if sudo apt-get update 2>&1 | tee /tmp/apt-update.log; then
        echo -e "${GREEN}✓ Package lists updated successfully${NC}"
        rm -f /tmp/apt-update.log
        return 0
    fi

    # If update failed, check for GPG errors
    if grep -q "GPG error" /tmp/apt-update.log || grep -q "NO_PUBKEY" /tmp/apt-update.log; then
        echo -e "${YELLOW}⚠ GPG errors detected, attempting to fix...${NC}"

        # Refresh GPG keys
        sudo apt-key update 2>/dev/null || true

        # Try update again
        if sudo apt-get update; then
            echo -e "${GREEN}✓ Package lists updated after GPG fix${NC}"
            rm -f /tmp/apt-update.log
            return 0
        fi
    fi

    echo -e "${RED}Failed to update package lists${NC}" >&2
    cat /tmp/apt-update.log >&2
    rm -f /tmp/apt-update.log
    return 1
}

# ============================================================================
# Helper Functions
# ============================================================================

# Check if a command exists
# Usage: command_exists <command>
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect system architecture
# Usage: detect_arch
detect_arch() {
    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "armhf"
            ;;
        *)
            echo "$arch"
            ;;
    esac
}
