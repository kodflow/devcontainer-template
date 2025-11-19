#!/bin/bash
# Post-create script - runs once after container is created
# Features are already installed during image build
set -e

# Load utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}   Kodflow DevContainer Setup${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""

# Check if already initialized
if [ -f /home/vscode/.kodflow-initialized ]; then
    log_success "Kodflow already initialized"
    echo ""
    exit 0
fi

log_info "Setting up environment variables and aliases..."

# Create environment initialization script
cat > /home/vscode/.kodflow-env.sh << 'ENVEOF'
# Kodflow Environment Initialization
# This file is sourced by ~/.zshrc and ~/.bashrc

# NVM (Node.js Version Manager)
export NVM_DIR="/home/vscode/.cache/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# pyenv (Python Version Manager)
export PYENV_ROOT="/home/vscode/.cache/pyenv"
if [ -d "$PYENV_ROOT" ]; then
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)" 2>/dev/null || true
    eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
fi

# rbenv (Ruby Version Manager)
export RBENV_ROOT="/home/vscode/.cache/rbenv"
if [ -d "$RBENV_ROOT" ]; then
    export PATH="$RBENV_ROOT/bin:$PATH"
    eval "$(rbenv init -)" 2>/dev/null || true
fi

# SDKMAN (Java/JVM SDK Manager)
export SDKMAN_DIR="/home/vscode/.cache/sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

# Rust/Cargo
export CARGO_HOME="/home/vscode/.cache/cargo"
export RUSTUP_HOME="/home/vscode/.cache/rustup"
[ -f "$CARGO_HOME/env" ] && source "$CARGO_HOME/env"

# Go
export GOPATH="/home/vscode/.cache/go"
if [ -d "/usr/local/go" ]; then
    export GOROOT="/usr/local/go"
    export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"
fi

# Flutter/Dart
export FLUTTER_ROOT="/home/vscode/.cache/flutter"
export PUB_CACHE="/home/vscode/.cache/pub-cache"
if [ -d "$FLUTTER_ROOT" ]; then
    export PATH="$FLUTTER_ROOT/bin:$PUB_CACHE/bin:$PATH"
fi

# Composer (PHP)
export COMPOSER_HOME="/home/vscode/.cache/composer"
export PATH="$COMPOSER_HOME/vendor/bin:$PATH"

# Mix (Elixir)
export MIX_HOME="/home/vscode/.cache/mix"
export PATH="$MIX_HOME/escripts:$PATH"

# npm global packages
export PATH="/home/vscode/.local/share/npm-global/bin:$PATH"

# pnpm
export PNPM_HOME="/home/vscode/.cache/pnpm"
export PATH="$PNPM_HOME:$PATH"

# Local bin
export PATH="/home/vscode/.local/bin:$PATH"

# vcpkg
export VCPKG_ROOT="/home/vscode/.cache/vcpkg"
export PATH="$VCPKG_ROOT:$PATH"

# Pulumi
export PATH="/home/vscode/.cache/pulumi/bin:$PATH"

# Carbon
export CARBON_PATH="/home/vscode/.cache/carbon"
export PATH="$CARBON_PATH/bin:$PATH"

# Bazel
export BAZEL_USER_ROOT="/home/vscode/.cache/bazel"

# Aliases
alias super-claude="claude --dangerously-skip-permissions --mcp-config /workspace/.devcontainer/mcp.json"
alias k="kubectl"
alias tf="terraform"
alias g="git"

# Kubernetes auto-completion (if kubectl is installed)
if command -v kubectl &> /dev/null; then
    source <(kubectl completion zsh) 2>/dev/null || true
fi

# Helm auto-completion (if helm is installed)
if command -v helm &> /dev/null; then
    source <(helm completion zsh) 2>/dev/null || true
fi

# Terraform auto-completion (if terraform is installed)
if command -v terraform &> /dev/null; then
    complete -o nospace -C /usr/bin/terraform terraform 2>/dev/null || true
fi
ENVEOF

log_success "Environment script created at ~/.kodflow-env.sh"

# The environment is already loaded by ~/.zshrc (configured in Dockerfile)
# No need to modify shell rc files

# Mark as initialized
touch /home/vscode/.kodflow-initialized

echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN}Setup Complete${NC}"
echo -e "${CYAN}=========================================${NC}"
echo ""
log_success "Kodflow DevContainer is ready!"
echo ""
echo "💡 Useful commands:"
echo -e "   ${GREEN}super-claude${NC}  - Claude CLI with MCP config"
echo -e "   ${GREEN}k${NC}             - kubectl"
echo -e "   ${GREEN}tf${NC}            - terraform"
echo ""

exit 0
