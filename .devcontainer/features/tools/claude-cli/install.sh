#!/bin/bash
# Don't exit on error - we want to use our retry logic
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Retry function
retry() {
    local max_attempts=$1
    local delay=$2
    shift 2
    local attempt=1
    local exit_code=0

    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            if [ $attempt -gt 1 ]; then
                log_success "Command succeeded on attempt $attempt"
            fi
            return 0
        fi

        exit_code=$?

        if [ $attempt -lt $max_attempts ]; then
            log_warning "Command failed (exit code: $exit_code), retrying in ${delay}s... (attempt $attempt/$max_attempts)"
            sleep "$delay"
        else
            log_error "Command failed after $max_attempts attempts"
        fi

        ((attempt++))
    done

    return $exit_code
}

# apt-get with retry and lock handling
apt_get_retry() {
    local max_attempts=5
    local attempt=1
    local delay=10

    while [ $attempt -le $max_attempts ]; do
        # Wait for apt locks to be released
        local lock_wait=0
        while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
              sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
              sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
            if [ $lock_wait -eq 0 ]; then
                log_warning "Waiting for apt locks to be released..."
            fi
            sleep 2
            lock_wait=$((lock_wait + 2))

            if [ $lock_wait -ge 60 ]; then
                log_warning "Forcing apt lock release after 60s wait"
                sudo rm -f /var/lib/dpkg/lock-frontend
                sudo rm -f /var/lib/apt/lists/lock
                sudo rm -f /var/cache/apt/archives/lock
                sudo dpkg --configure -a || true
                break
            fi
        done

        # Try apt-get command
        if sudo apt-get "$@"; then
            if [ $attempt -gt 1 ]; then
                log_success "apt-get succeeded on attempt $attempt"
            fi
            return 0
        fi

        exit_code=$?

        if [ $attempt -lt $max_attempts ]; then
            log_warning "apt-get failed, running update and retrying in ${delay}s... (attempt $attempt/$max_attempts)"
            sudo apt-get update --fix-missing || true
            sudo dpkg --configure -a || true
            sleep "$delay"
        else
            log_error "apt-get failed after $max_attempts attempts"
        fi

        ((attempt++))
    done

    return $exit_code
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Safe directory creation
mkdir_safe() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || sudo mkdir -p "$dir"

        if [ "$(whoami)" = "vscode" ]; then
            sudo chown -R vscode:vscode "$dir" 2>/dev/null || true
        fi
    fi
}

echo "========================================="
echo "Installing Claude CLI"
echo "========================================="

# Environment variables
export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-/home/vscode/.claude}"

# Install dependencies
log_info "Installing dependencies..."
apt_get_retry update
apt_get_retry install -y curl git || {
    log_warning "Failed to install dependencies, but continuing..."
}

# Install Claude CLI via npm (if not already installed)
log_info "Installing Claude CLI..."

# Check if npm is available, if not try to load NVM
if ! command_exists npm; then
    log_info "npm not found in PATH, attempting to load Node.js..."

    # First, check if npm is available via /usr/local/bin (symlink created by nodejs feature)
    if [ -L "/usr/local/bin/npm" ] || [ -f "/usr/local/bin/npm" ]; then
        export PATH="/usr/local/bin:$PATH"
        if command_exists npm; then
            log_success "Node.js loaded via /usr/local/bin symlinks"
        fi
    fi

    # If still not found, try loading NVM directly
    if ! command_exists npm; then
        export NVM_DIR="${NVM_DIR:-/home/vscode/.cache/nvm}"
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            log_info "Loading NVM from $NVM_DIR..."
            \. "$NVM_DIR/nvm.sh"
            nvm use default >/dev/null 2>&1 || true

            if command_exists npm; then
                log_success "Node.js loaded from NVM"
            fi
        fi
    fi

    # Final check
    if ! command_exists npm; then
        log_error "npm is not installed. Please install Node.js first."
        log_info "Add the Node.js feature BEFORE claude-cli in devcontainer.json:"
        log_info '  "./features/languages/nodejs": { ... },'
        log_info '  "./features/tools/claude-cli": {},'
        exit 1
    fi
fi

# Verify Node.js and npm versions
NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
NPM_VERSION=$(npm --version 2>/dev/null || echo "unknown")
log_info "Using Node.js $NODE_VERSION, npm $NPM_VERSION"

# Install Claude CLI globally with retry
if retry 3 5 npm install --no-audit --no-fund -g @anthropic-ai/claude-code; then
    log_success "Claude CLI installed via npm"
else
    log_error "Failed to install Claude CLI"
    exit 1
fi

# Create global symlink for claude
log_info "Creating global symlink for claude..."

# Get the global npm bin directory (npm bin -g was removed in npm 9+)
NPM_GLOBAL_BIN="$(npm prefix -g)/bin"
log_info "npm global bin directory: $NPM_GLOBAL_BIN"

# Search for claude binary in multiple locations
CLAUDE_PATH=""
if [ -f "$NPM_GLOBAL_BIN/claude" ]; then
    CLAUDE_PATH="$NPM_GLOBAL_BIN/claude"
elif command -v claude &>/dev/null; then
    CLAUDE_PATH="$(command -v claude)"
else
    # Search in common npm global locations
    log_info "Searching for claude binary..."
    for search_path in \
        "/usr/local/bin/claude" \
        "/usr/bin/claude" \
        "$HOME/.npm-global/bin/claude" \
        "$HOME/.local/bin/claude" \
        "/home/vscode/.cache/nvm/versions/node/*/bin/claude"; do
        # Use glob expansion for paths with wildcards
        for found_path in $search_path; do
            if [ -f "$found_path" ] && [ -x "$found_path" ]; then
                CLAUDE_PATH="$found_path"
                break 2
            fi
        done
    done
fi

if [ -n "$CLAUDE_PATH" ] && [ -f "$CLAUDE_PATH" ]; then
    if [ "$CLAUDE_PATH" != "/usr/local/bin/claude" ]; then
        sudo ln -sf "$CLAUDE_PATH" /usr/local/bin/claude
        log_success "Global symlink created: /usr/local/bin/claude -> $CLAUDE_PATH"
    else
        log_success "Claude already available at /usr/local/bin/claude"
    fi
else
    log_error "Could not find claude binary anywhere"
    exit 1
fi

# Verify installation
if command_exists claude; then
    CLAUDE_VERSION=$(claude --version 2>&1 || echo "Claude CLI latest")
    log_success "Claude CLI is available in PATH"
    log_success "Version: ${CLAUDE_VERSION}"
else
    log_error "Claude CLI was installed but is not available in PATH"
    log_info "This might be resolved after restarting the shell or container"
fi

# Create config directories
mkdir_safe "$CLAUDE_CONFIG_DIR"
mkdir_safe /home/vscode/.config/@anthropic
mkdir_safe /home/vscode/.cache/@anthropic
mkdir_safe /home/vscode/.local/share/@anthropic

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Claude CLI installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
log_success "Installation complete!"
echo ""
echo "Installed components:"
echo "  - Claude CLI"
echo ""
echo "Configuration directories:"
echo "  - Config: $CLAUDE_CONFIG_DIR"
echo "  - Anthropic config: /home/vscode/.config/@anthropic"
echo "  - Anthropic cache: /home/vscode/.cache/@anthropic"
echo "  - Anthropic data: /home/vscode/.local/share/@anthropic"
echo ""
echo "Quick start:"
echo "  1. Login: claude login"
echo "  2. Start a session: claude chat"
echo ""
echo "For more information: claude --help"
echo ""

# Exit successfully
exit 0
