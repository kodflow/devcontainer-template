#!/bin/bash
# Don't exit on error - we want to use our retry logic
set +e

# Load utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils.sh"

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

# Check if npm is available
if ! command_exists npm; then
    log_error "npm is not installed. Please install Node.js first."
    log_info "Add the Node.js feature to devcontainer.json: ./features/languages/nodejs"
    exit 1
fi

# Install Claude CLI globally with retry
if retry 3 5 npm install --no-audit --no-fund -g @anthropic-ai/claude-code-cli; then
    log_success "Claude CLI installed"
else
    log_error "Failed to install Claude CLI"
    exit 1
fi

if command_exists claude; then
    CLAUDE_VERSION=$(claude --version 2>&1 || echo "Claude CLI latest")
    log_success "Version: ${CLAUDE_VERSION}"
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
