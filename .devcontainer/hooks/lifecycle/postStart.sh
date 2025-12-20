#!/bin/bash
# ============================================================================
# postStart.sh - Runs EVERY TIME the container starts
# ============================================================================
# This script runs after postCreateCommand and before postAttachCommand.
# Runs each time the container is successfully started.
# Use it for: MCP setup, services startup, recurring initialization.
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/utils.sh"

log_info "postStart: Container starting..."

# ============================================================================
# Restore baked-in files from /opt/kodflow/ (volumes overwrite image content)
# ============================================================================
KODFLOW_BACKUP="/opt/kodflow"

# Restore Claude commands, scripts, and settings
if [ -d "$KODFLOW_BACKUP/.claude" ]; then
    log_info "Restoring Claude configuration from image..."

    # Restore commands (always overwrite with latest from image)
    if [ -d "$KODFLOW_BACKUP/.claude/commands" ]; then
        mkdir -p "$HOME/.claude/commands"
        cp -r "$KODFLOW_BACKUP/.claude/commands/"* "$HOME/.claude/commands/" 2>/dev/null || true
        log_success "Claude commands restored"
    fi

    # Restore scripts (always overwrite with latest from image)
    if [ -d "$KODFLOW_BACKUP/.claude/scripts" ]; then
        mkdir -p "$HOME/.claude/scripts"
        cp -r "$KODFLOW_BACKUP/.claude/scripts/"* "$HOME/.claude/scripts/" 2>/dev/null || true
        chmod -R 755 "$HOME/.claude/scripts/"
        log_success "Claude scripts restored"
    fi

    # Restore settings.json only if user hasn't customized it significantly
    # (keep user's credentials and session data, merge with image settings)
    if [ -f "$KODFLOW_BACKUP/.claude/settings.json" ]; then
        if [ ! -f "$HOME/.claude/settings.json" ] || \
           [ "$(jq -r 'keys | length' "$HOME/.claude/settings.json" 2>/dev/null)" -lt 5 ]; then
            cp "$KODFLOW_BACKUP/.claude/settings.json" "$HOME/.claude/settings.json"
            log_success "Claude settings.json restored"
        else
            log_info "Claude settings.json exists with customizations, skipping"
        fi
    fi

    mkdir -p "$HOME/.claude/sessions"
fi

# ============================================================================
# Download latest binaries from GitHub (bypass Docker cache issues)
# ============================================================================
download_latest_binary() {
    local full_repo="$1"  # Format: owner/repo (e.g., kodflow/status-line)
    local binary="$2"
    local target="$HOME/.local/bin/$binary"

    # Detect architecture
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
    esac

    # Get latest version from GitHub API
    local latest_version
    latest_version=$(curl -fsSL "https://api.github.com/repos/$full_repo/releases/latest" 2>/dev/null | jq -r '.tag_name // empty')

    if [ -z "$latest_version" ]; then
        log_warning "Failed to get latest version for $binary"
        return 1
    fi

    # Check current version (if binary exists)
    local current_version=""
    if [ -x "$target" ]; then
        # Try --version first, fallback to parsing help output
        current_version=$("$target" --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ -z "$current_version" ]; then
            current_version=$("$target" 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        fi
    fi

    # Download if version differs or binary missing
    if [ "$current_version" != "$latest_version" ]; then
        log_info "Updating $binary: ${current_version:-none} -> $latest_version"
        local url="https://github.com/$full_repo/releases/latest/download/$binary-linux-$arch"

        if curl -fsSL "$url" -o "$target.tmp" 2>/dev/null; then
            mv "$target.tmp" "$target"
            chmod +x "$target"
            log_success "$binary updated to $latest_version"
        else
            rm -f "$target.tmp"
            log_warning "Failed to download $binary"
            return 1
        fi
    else
        log_info "$binary already at $latest_version"
    fi
}

mkdir -p "$HOME/.local/bin"
log_info "Checking for latest binaries..."
download_latest_binary "kodflow/status-line" "status-line"
download_latest_binary "kodflow/ktn-linter" "ktn-linter"

# Restore NVM symlinks (node, npm, npx, claude)
NVM_DIR="${NVM_DIR:-$HOME/.cache/nvm}"
if [ -d "$NVM_DIR/versions/node" ]; then
    NODE_VERSION=$(ls "$NVM_DIR/versions/node" 2>/dev/null | head -1)
    if [ -n "$NODE_VERSION" ]; then
        log_info "Restoring Node.js symlinks for $NODE_VERSION..."
        mkdir -p "$HOME/.local/bin"
        NODE_BIN="$NVM_DIR/versions/node/$NODE_VERSION/bin"

        for cmd in node npm npx claude; do
            if [ -f "$NODE_BIN/$cmd" ]; then
                ln -sf "$NODE_BIN/$cmd" "$HOME/.local/bin/$cmd"
            fi
        done
        log_success "Node.js symlinks restored"
    fi
fi

# ============================================================================
# 1Password CLI Setup
# ============================================================================
# Fix op config directory permissions (created by Docker as root)
OP_CONFIG_DIR="/home/vscode/.config/op"
if [ -d "$OP_CONFIG_DIR" ]; then
    if [ "$(stat -c '%U' "$OP_CONFIG_DIR" 2>/dev/null)" != "vscode" ]; then
        log_info "Fixing 1Password config directory permissions..."
        sudo chown -R vscode:vscode "$OP_CONFIG_DIR" 2>/dev/null || true
    fi
    chmod 700 "$OP_CONFIG_DIR" 2>/dev/null || true
fi

# Reload .env file to get updated tokens
ENV_FILE="/workspace/.devcontainer/.env"
if [ -f "$ENV_FILE" ]; then
    log_info "Reloading environment from .env..."
    set -a
    source "$ENV_FILE"
    set +a
fi

# ============================================================================
# MCP Configuration Setup (inject secrets into template)
# ============================================================================
VAULT_ID="ypahjj334ixtiyjkytu5hij2im"
MCP_TPL="/etc/mcp/mcp.json.tpl"
MCP_OUTPUT="/workspace/.mcp.json"

# Helper function to get 1Password field (tries multiple field names)
# Usage: get_1password_field <item_name> <vault_id>
get_1password_field() {
    local item="$1"
    local vault="$2"
    local fields=("credential" "password" "identifiant" "mot de passe")

    for field in "${fields[@]}"; do
        local value
        value=$(op item get "$item" --vault "$vault" --fields "$field" --reveal 2>/dev/null || echo "")
        if [ -n "$value" ]; then
            echo "$value"
            return 0
        fi
    done
    echo ""
}

# Initialize tokens from environment variables (fallback)
CODACY_TOKEN="${CODACY_API_TOKEN:-}"
GITHUB_TOKEN="${GITHUB_API_TOKEN:-}"

# Try 1Password if OP_SERVICE_ACCOUNT_TOKEN is defined
if [ -n "$OP_SERVICE_ACCOUNT_TOKEN" ] && command -v op &> /dev/null; then
    log_info "Retrieving secrets from 1Password..."

    OP_CODACY=$(get_1password_field "mcp-codacy" "$VAULT_ID")
    OP_GITHUB=$(get_1password_field "mcp-github" "$VAULT_ID")

    [ -n "$OP_CODACY" ] && CODACY_TOKEN="$OP_CODACY"
    [ -n "$OP_GITHUB" ] && GITHUB_TOKEN="$OP_GITHUB"
fi

# Show warnings if tokens are missing
[ -z "$CODACY_TOKEN" ] && log_warning "Codacy token not available"
[ -z "$GITHUB_TOKEN" ] && log_warning "GitHub token not available"

# Generate mcp.json from template (baked in Docker image)
if [ -f "$MCP_TPL" ]; then
    log_info "Generating .mcp.json from template..."
    sed -e "s|{{CODACY_TOKEN}}|${CODACY_TOKEN}|g" \
        -e "s|{{GITHUB_TOKEN}}|${GITHUB_TOKEN}|g" \
        "$MCP_TPL" > "$MCP_OUTPUT"
    log_success "mcp.json generated successfully"
else
    log_warning "MCP template not found at $MCP_TPL"
fi

# ============================================================================
# Git Credential Cleanup (remove macOS-specific helpers)
# ============================================================================
log_info "Cleaning git credential helpers..."
git config --global --unset-all credential.https://github.com.helper 2>/dev/null || true
git config --global --unset-all credential.https://gist.github.com.helper 2>/dev/null || true
log_success "Git credential helpers cleaned"

# ============================================================================
# Final message
# ============================================================================
echo ""
log_success "postStart: Container ready!"
