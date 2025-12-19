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
