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
# MCP Configuration Setup
# ============================================================================
VAULT_ID="ypahjj334ixtiyjkytu5hij2im"
MCP_TPL="/workspace/.devcontainer/hooks/shared/mcp.json.tpl"
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

# Initialize tokens
CODACY_TOKEN=""
GITHUB_TOKEN=""

# Try 1Password if OP_SERVICE_ACCOUNT_TOKEN is defined
if [ -n "$OP_SERVICE_ACCOUNT_TOKEN" ] && command -v op &> /dev/null; then
    log_info "Retrieving secrets from 1Password..."

    CODACY_TOKEN=$(get_1password_field "mcp-codacy" "$VAULT_ID")
    GITHUB_TOKEN=$(get_1password_field "mcp-github" "$VAULT_ID")
fi

# Use environment variables as fallback
if [ -z "$CODACY_TOKEN" ] && [ -n "$CODACY_API_TOKEN" ]; then
    log_info "Using Codacy token from CODACY_API_TOKEN"
    CODACY_TOKEN="$CODACY_API_TOKEN"
fi

if [ -z "$GITHUB_TOKEN" ] && [ -n "$GITHUB_API_TOKEN" ]; then
    log_info "Using GitHub token from GITHUB_API_TOKEN"
    GITHUB_TOKEN="$GITHUB_API_TOKEN"
fi

# Show warnings if tokens are missing
[ -z "$CODACY_TOKEN" ] && log_warning "Codacy token not available"
[ -z "$GITHUB_TOKEN" ] && log_warning "GitHub token not available"

# Generate mcp.json from template
if [ -f "$MCP_TPL" ]; then
    log_info "Generating .mcp.json from template..."
    sed "s|{{ with secret \"secret/mcp/codacy\" }}{{ .Data.data.token }}{{ end }}|${CODACY_TOKEN}|g" "$MCP_TPL" | \
        sed "s|{{ with secret \"secret/mcp/github\" }}{{ .Data.data.token }}{{ end }}|${GITHUB_TOKEN}|g" \
        > "$MCP_OUTPUT"
    log_success "mcp.json generated successfully"
fi

# ============================================================================
# Git Credential Cleanup (remove macOS-specific helpers)
# ============================================================================
log_info "Cleaning git credential helpers..."
git config --global --unset-all credential.https://github.com.helper 2>/dev/null || true
git config --global --unset-all credential.https://gist.github.com.helper 2>/dev/null || true
log_success "Git credential helpers cleaned"

# ============================================================================
# Claude CLI Configuration
# ============================================================================
log_info "Configuring Claude CLI..."
mkdir -p /home/vscode/.claude
cat > /home/vscode/.claude/settings.json <<'EOF'
{
  "enableAllProjectMcpServers": true,
  "alwaysThinkingEnabled": true
}
EOF
log_success "Claude CLI configured"

# ============================================================================
# Final message
# ============================================================================
echo ""
log_success "postStart: Container ready!"
