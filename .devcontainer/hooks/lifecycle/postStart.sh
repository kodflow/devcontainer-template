#!/bin/bash
# shellcheck disable=SC1090,SC1091
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
# Restore Claude commands/scripts from image defaults
# ============================================================================
# Volume mounts overwrite image content, so we restore from /etc/claude-defaults/
CLAUDE_DEFAULTS="/etc/claude-defaults"

if [ -d "$CLAUDE_DEFAULTS" ]; then
    log_info "Restoring Claude configuration from image defaults..."

    # Ensure base directory exists
    mkdir -p "$HOME/.claude"

    # CLEAN commands, scripts, agents and docs to avoid legacy pollution
    # Only these directories are managed by the image - sessions/plans are user data
    rm -rf "$HOME/.claude/commands" "$HOME/.claude/scripts" "$HOME/.claude/agents" "$HOME/.claude/docs"

    # Restore commands (fresh copy from image)
    if [ -d "$CLAUDE_DEFAULTS/commands" ]; then
        mkdir -p "$HOME/.claude/commands"
        cp -r "$CLAUDE_DEFAULTS/commands/"* "$HOME/.claude/commands/" 2>/dev/null || true
    fi

    # Restore scripts (fresh copy from image)
    if [ -d "$CLAUDE_DEFAULTS/scripts" ]; then
        mkdir -p "$HOME/.claude/scripts"
        cp -r "$CLAUDE_DEFAULTS/scripts/"* "$HOME/.claude/scripts/" 2>/dev/null || true
        chmod -R 755 "$HOME/.claude/scripts/"
    fi

    # Restore agents (fresh copy from image)
    if [ -d "$CLAUDE_DEFAULTS/agents" ]; then
        mkdir -p "$HOME/.claude/agents"
        cp -r "$CLAUDE_DEFAULTS/agents/"* "$HOME/.claude/agents/" 2>/dev/null || true
        chmod -R 755 "$HOME/.claude/agents/"
    fi

    # Restore docs (Design Patterns Knowledge Base - fresh copy from image)
    if [ -d "$CLAUDE_DEFAULTS/docs" ]; then
        mkdir -p "$HOME/.claude/docs"
        cp -r "$CLAUDE_DEFAULTS/docs/"* "$HOME/.claude/docs/" 2>/dev/null || true
    fi

    # Restore settings.json only if it does not exist (user customizations preserved)
    if [ -f "$CLAUDE_DEFAULTS/settings.json" ] && [ ! -f "$HOME/.claude/settings.json" ]; then
        cp "$CLAUDE_DEFAULTS/settings.json" "$HOME/.claude/settings.json"
    fi

    log_success "Claude configuration restored (clean)"
fi

# ============================================================================
# Ensure Claude directories exist (volume mount point)
# ============================================================================
mkdir -p "$HOME/.claude/sessions" "$HOME/.claude/plans"
log_success "Claude directories initialized"

# Reload .env file to get updated tokens
ENV_FILE="/workspace/.devcontainer/.env"
if [ -f "$ENV_FILE" ]; then
    log_info "Reloading environment from .env..."
    set -a
    source "$ENV_FILE"
    set +a
fi

# ============================================================================
# Ollama + grepai Initialization (for semantic code search MCP)
# ============================================================================
# Ollama runs as a sidecar container (see docker-compose.yml)
# Accessible via OLLAMA_HOST env var (default: ollama:11434)
# Model is pulled on first start and persisted in ollama-data volume
GREPAI_BIN="/usr/local/bin/grepai"
OLLAMA_ENDPOINT="${OLLAMA_HOST:-ollama:11434}"

init_semantic_search() {
    local grepai_config="/workspace/.grepai/config.yaml"

    # Wait for Ollama sidecar to be ready (max 30s)
    log_info "Waiting for Ollama sidecar at $OLLAMA_ENDPOINT..."
    local retries=15
    while [ $retries -gt 0 ]; do
        if curl -sf "http://${OLLAMA_ENDPOINT}/api/tags" >/dev/null 2>&1; then
            log_success "Ollama sidecar is ready"
            break
        fi
        retries=$((retries - 1))
        sleep 2
    done

    if [ $retries -eq 0 ]; then
        log_warning "Ollama sidecar not responding, grepai may not work"
        return 0
    fi

    # Pull embedding model if not present (non-blocking check)
    if ! curl -sf "http://${OLLAMA_ENDPOINT}/api/tags" 2>/dev/null | grep -q "nomic-embed-text"; then
        log_info "Pulling nomic-embed-text model (background)..."
        curl -sf "http://${OLLAMA_ENDPOINT}/api/pull" -d '{"name":"nomic-embed-text"}' >/dev/null 2>&1 &
    fi

    # Initialize grepai for the workspace
    if [ -x "$GREPAI_BIN" ]; then
        if [ ! -d "/workspace/.grepai" ]; then
            log_info "Initializing grepai for semantic code search..."
            if (cd /workspace && "$GREPAI_BIN" init --provider ollama --backend gob --yes 2>/dev/null); then
                log_success "grepai initialized"
            else
                log_warning "grepai init failed"
                return 0
            fi
        fi

        # Fix Ollama endpoint in grepai config (localhost -> sidecar)
        if [ -f "$grepai_config" ]; then
            if grep -q "localhost:11434" "$grepai_config"; then
                log_info "Updating grepai config to use Ollama sidecar..."
                sed -i "s|localhost:11434|${OLLAMA_ENDPOINT}|g" "$grepai_config"
                log_success "grepai config updated (endpoint: $OLLAMA_ENDPOINT)"
            fi
        fi

        # Start grepai watch daemon for real-time indexing (if not already running)
        if ! pgrep -f "grepai watch" >/dev/null 2>&1; then
            log_info "Starting grepai watch daemon for real-time indexing..."
            (cd /workspace && nohup "$GREPAI_BIN" watch >/dev/null 2>&1 &)
            sleep 2
            if pgrep -f "grepai watch" >/dev/null 2>&1; then
                log_success "grepai watch daemon started"
            else
                log_warning "grepai watch daemon failed to start"
            fi
        else
            log_info "grepai watch daemon already running"
        fi
    fi
}

# Run in background to not block container startup
init_semantic_search &

# ============================================================================
# MCP Configuration Setup (inject secrets into template)
# ============================================================================
# 1Password vault ID (can be overridden via OP_VAULT_ID env var)
VAULT_ID="${OP_VAULT_ID:-ypahjj334ixtiyjkytu5hij2im}"
MCP_TPL="/etc/mcp/mcp.json.tpl"
MCP_OUTPUT="/workspace/mcp.json"

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
CODERABBIT_TOKEN="${CODERABBIT_API_KEY:-}"

# ============================================================================
# 1Password CLI Config Directory Permissions Fix
# ============================================================================
# Docker named volumes create directories with root ownership.
# 1Password CLI requires: ownership by current user + permissions 700.
# See: https://github.com/kodflow/devcontainer-template/issues/86
OP_CONFIG_DIRS=("$HOME/.config/op" "$HOME/.op")

for OP_DIR in "${OP_CONFIG_DIRS[@]}"; do
    if [ -d "$OP_DIR" ]; then
        # Fix ownership if not current user
        if [ "$(stat -c '%U' "$OP_DIR" 2>/dev/null)" != "$(whoami)" ]; then
            log_info "Fixing ownership of $OP_DIR..."
            sudo chown -R "$(whoami):$(whoami)" "$OP_DIR"
        fi
        # Ensure correct permissions (700 = owner only)
        chmod 700 "$OP_DIR"
    fi
done
log_success "1Password config directories configured"

# ============================================================================
# npm Cache Permissions Fix
# ============================================================================
# Docker named volumes create directories with root ownership.
# npm requires write access to its cache for npx/MCP servers to work.
# See: https://github.com/kodflow/devcontainer-template/issues/88
NPM_CACHE_DIR="$HOME/.cache/npm"

if [ -d "$NPM_CACHE_DIR" ]; then
    # Fix ownership if not current user
    if [ "$(stat -c '%U' "$NPM_CACHE_DIR" 2>/dev/null)" != "$(whoami)" ]; then
        log_info "Fixing ownership of npm cache..."
        sudo chown -R "$(whoami):$(whoami)" "$NPM_CACHE_DIR"
    fi
fi
log_success "npm cache configured"

# Try 1Password if OP_SERVICE_ACCOUNT_TOKEN is defined
if [ -n "$OP_SERVICE_ACCOUNT_TOKEN" ] && command -v op &> /dev/null; then
    log_info "Retrieving secrets from 1Password..."

    OP_CODACY=$(get_1password_field "mcp-codacy" "$VAULT_ID")
    OP_GITHUB=$(get_1password_field "mcp-github" "$VAULT_ID")
    OP_CODERABBIT=$(get_1password_field "coderabbit" "$VAULT_ID")

    [ -n "$OP_CODACY" ] && CODACY_TOKEN="$OP_CODACY"
    [ -n "$OP_GITHUB" ] && GITHUB_TOKEN="$OP_GITHUB"
    [ -n "$OP_CODERABBIT" ] && CODERABBIT_TOKEN="$OP_CODERABBIT"
fi

# Show status of tokens (INFO for optional, WARNING for essential)
[ -z "$CODACY_TOKEN" ] && log_info "Codacy token not configured (optional)"
[ -z "$GITHUB_TOKEN" ] && log_warning "GitHub token not available"
[ -z "$CODERABBIT_TOKEN" ] && log_info "CodeRabbit token not configured (optional)"

# Helper: escape special chars for sed replacement
# Handles: & \ | / and strips newlines/CR (covers all token formats)
# LC_ALL=C ensures deterministic behavior across locales
escape_for_sed() {
    LC_ALL=C printf '%s' "$1" | tr -d '\n\r' | sed -e 's/[&/|\\]/\\&/g'
}

# Security: refuse to write secrets through symlinks or unsafe directories
MCP_DIR=$(dirname -- "$MCP_OUTPUT")
if [ ! -d "$MCP_DIR" ] || [ -L "$MCP_DIR" ]; then
    log_error "Refusing to write mcp.json: unsafe parent directory ($MCP_DIR)"
    # Skip all MCP generation but continue with rest of postStart
elif [ -e "$MCP_OUTPUT" ] && { [ -L "$MCP_OUTPUT" ] || [ ! -f "$MCP_OUTPUT" ]; }; then
    log_error "Refusing to write mcp.json: not a regular file ($MCP_OUTPUT)"
    # Skip all MCP generation but continue with rest of postStart
else

# Migrate legacy .mcp.json to mcp.json (renamed in v2)
if [ -f "/workspace/.mcp.json" ] && [ ! -e "$MCP_OUTPUT" ]; then
    log_info "Migrating legacy .mcp.json to mcp.json..."

    if ! command -v jq >/dev/null 2>&1; then
        log_warning "jq not found; migrating without JSON validation"
        if cp "/workspace/.mcp.json" "$MCP_OUTPUT"; then
            chown "$(id -u):$(id -g)" "$MCP_OUTPUT" 2>/dev/null || true
            chmod 600 "$MCP_OUTPUT"
            rm -f "/workspace/.mcp.json" || log_warning "Could not remove legacy .mcp.json (permissions?)"
            log_success "Migration complete: .mcp.json → mcp.json"
        else
            log_error "Migration failed: unable to copy legacy file"
        fi
    else
        MCP_MIG_TMP=$(mktemp "${MCP_OUTPUT}.migrate.XXXXXX") || {
            log_error "Migration failed: unable to create temp file"
            MCP_MIG_TMP=""
        }
        if [ -n "$MCP_MIG_TMP" ] && cp "/workspace/.mcp.json" "$MCP_MIG_TMP"; then
            # Validate JSON before completing migration
            if jq empty "$MCP_MIG_TMP" 2>/dev/null; then
                mv "$MCP_MIG_TMP" "$MCP_OUTPUT"
                chown "$(id -u):$(id -g)" "$MCP_OUTPUT" 2>/dev/null || true
                chmod 600 "$MCP_OUTPUT"
                rm -f "/workspace/.mcp.json" || log_warning "Could not remove legacy .mcp.json (permissions?)"
                log_success "Migration complete: .mcp.json → mcp.json"
            else
                log_error "Legacy .mcp.json is invalid JSON; keeping legacy file"
                rm -f "$MCP_MIG_TMP"
            fi
        elif [ -n "$MCP_MIG_TMP" ]; then
            log_error "Migration failed"
            rm -f "$MCP_MIG_TMP"
        fi
    fi
fi

# Generate mcp.json from template (baked in Docker image)
# ALWAYS regenerate from template to ensure latest MCP config is applied
if [ -f "$MCP_TPL" ]; then
    if [ -z "$CODACY_TOKEN" ] && [ -z "$GITHUB_TOKEN" ]; then
        # No tokens available - create minimal config for optional MCPs (grepai, playwright, etc.)
        log_warning "No tokens available, creating minimal mcp.json"
        printf '%s\n' '{"mcpServers":{}}' > "$MCP_OUTPUT"
        chown "$(id -u):$(id -g)" "$MCP_OUTPUT" 2>/dev/null || true
        chmod 600 "$MCP_OUTPUT"
        log_info "Created minimal mcp.json (optional MCPs will be added below)"
    else
        # Generate mcp.json from template (uses subshell to avoid global trap clobbering)
        generate_mcp_from_template() {
            local escaped_codacy escaped_github mcp_tmp
            escaped_codacy=$(escape_for_sed "${CODACY_TOKEN}")
            escaped_github=$(escape_for_sed "${GITHUB_TOKEN}")

            mcp_tmp=$(mktemp "${MCP_OUTPUT}.tmp.XXXXXX") || {
                log_error "Failed to create temp file for mcp.json generation"
                return 0
            }

            # Cleanup on function exit (does not affect other traps)
            trap 'rm -f "$mcp_tmp" 2>/dev/null || true' RETURN

            if ! sed -e "s|{{CODACY_TOKEN}}|${escaped_codacy}|g" \
                    -e "s|{{GITHUB_TOKEN}}|${escaped_github}|g" \
                    "$MCP_TPL" > "$mcp_tmp"; then
                log_error "Failed to render mcp.json template"
                return 0
            fi

            if jq empty "$mcp_tmp" 2>/dev/null; then
                mv "$mcp_tmp" "$MCP_OUTPUT"
                chown "$(id -u):$(id -g)" "$MCP_OUTPUT" 2>/dev/null || true
                chmod 600 "$MCP_OUTPUT"
                log_success "mcp.json generated successfully"
            else
                log_error "Generated mcp.json is invalid JSON, keeping original"
            fi
        }
        log_info "Regenerating mcp.json from template (forced)..."
        generate_mcp_from_template
    fi

    # =========================================================================
    # Add optional MCPs based on installed features
    # =========================================================================
    # Helper function to add a conditional MCP server (uses atomic temp file)
    add_optional_mcp() {
        local name="$1"
        local binary="$2"
        local output="$3"

        # Nothing to do if there is no base config to modify
        [ -f "$output" ] || return 0

        # jq is required for JSON manipulation
        if ! command -v jq >/dev/null 2>&1; then
            log_warning "Skipping $name MCP injection (jq not found)"
            return 0
        fi

        if [ -x "$binary" ]; then
            log_info "Adding $name MCP (binary found at $binary)"
            local tmp_file
            tmp_file=$(mktemp "${output}.tmp.XXXXXX") || {
                log_warning "Failed to add $name MCP (unable to create temp file)"
                return 0
            }
            if jq --arg name "$name" --arg bin "$binary" \
               '.mcpServers = (.mcpServers // {}) | .mcpServers[$name] = {"command": $bin, "args": [], "env": {}}' \
               "$output" > "$tmp_file" && jq empty "$tmp_file" 2>/dev/null; then
                mv "$tmp_file" "$output"
                # Ensure correct ownership and secure permissions
                chown "$(id -u):$(id -g)" "$output" 2>/dev/null || true
                chmod 600 "$output" 2>/dev/null || true
            else
                log_warning "Failed to add $name MCP, keeping original"
                rm -f "$tmp_file"
            fi
        else
            log_info "Skipping $name MCP (binary not found)"
        fi
    }

    # Rust: rust-analyzer-mcp (only if Rust feature is installed)
    add_optional_mcp "rust-analyzer" "$HOME/.cache/cargo/bin/rust-analyzer-mcp" "$MCP_OUTPUT"

    # Future conditional MCPs can be added here:
    # add_optional_mcp "gopls" "$HOME/.cache/go/bin/gopls-mcp" "$MCP_OUTPUT"
    # add_optional_mcp "pyright" "$HOME/.cache/pyenv/shims/pyright-mcp" "$MCP_OUTPUT"
else
    log_warning "MCP template not found at $MCP_TPL"
fi

fi  # End of symlink security check

# ============================================================================
# Git Credential Cleanup (remove macOS-specific helpers)
# ============================================================================
log_info "Cleaning git credential helpers..."
git config --global --unset-all credential.https://github.com.helper 2>/dev/null || true
git config --global --unset-all credential.https://gist.github.com.helper 2>/dev/null || true
log_success "Git credential helpers cleaned"

# ============================================================================
# Export dynamic environment variables (appended to ~/.devcontainer-env.sh)
# ============================================================================
# Note: ~/.devcontainer-env.sh is created by postCreate.sh with static content
# We only append dynamic variables here (secrets from 1Password)
DC_ENV="$HOME/.devcontainer-env.sh"

# Export CodeRabbit API key if available (append to existing file)
if [ -n "$CODERABBIT_TOKEN" ]; then
    # Remove any existing CODERABBIT_API_KEY line to avoid duplicates
    if [ -f "$DC_ENV" ]; then
        sed -i '/^export CODERABBIT_API_KEY=/d' "$DC_ENV"
    fi
    echo "export CODERABBIT_API_KEY=\"$CODERABBIT_TOKEN\"" >> "$DC_ENV"
    log_success "CODERABBIT_API_KEY exported to $DC_ENV"
fi

# ============================================================================
# Auto-run /init for project initialization check
# ============================================================================
# Runs at every container start to verify project is properly initialized
# (compares CLAUDE.md and README.md footprints with template)
# Skipped in CI environment

INIT_LOG="$HOME/.devcontainer-init.log"

if command -v claude &> /dev/null && [ -z "${CI:-}" ]; then
    log_info "Running project initialization check..."
    # Run /init in background to not block container startup
    # Logs persisted to $HOME for debugging (survives container restarts)
    nohup bash -c "sleep 2 && claude \"/init\" || echo \"[\$(date -Iseconds)] Init check failed with exit code \$?\" >> \"$INIT_LOG\"" >> "$INIT_LOG" 2>&1 &
    log_success "Init check scheduled (logs: ~/.devcontainer-init.log)"
elif [ -n "${CI:-}" ]; then
    log_info "CI environment detected, skipping init"
fi

# ============================================================================
# Final message
# ============================================================================
echo ""
log_success "postStart: Container ready!"
