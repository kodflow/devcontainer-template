#!/bin/bash
# Common NVM helper functions for devcontainer features
# This script provides NVM loading functionality for features that depend on Node.js

# ============================================================================
# NVM Environment Setup
# ============================================================================

# Load NVM into the current shell environment
# Usage: load_nvm
load_nvm() {
    export NVM_DIR="${NVM_DIR:-/home/vscode/.cache/nvm}"

    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # Source NVM script
        \. "$NVM_DIR/nvm.sh"

        # Use default Node version
        nvm use default >/dev/null 2>&1 || true

        return 0
    else
        echo "Warning: NVM not found at $NVM_DIR" >&2
        return 1
    fi
}

# Ensure Node.js and npm are available in PATH
# This will either load NVM or use system-wide symlinks
# Usage: ensure_nodejs
ensure_nodejs() {
    # First check if node is already available (via symlinks or other means)
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        return 0
    fi

    # Try to load NVM
    if load_nvm; then
        # Verify node and npm are now available
        if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}
