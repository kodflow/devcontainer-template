#!/bin/bash
# Don't exit on error - we want to use our retry logic
set +e

# Load utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils.sh"

echo "========================================="
echo "Installing Node.js Development Environment"
echo "========================================="

# Environment variables
export NVM_DIR="${NVM_DIR:-/home/vscode/.cache/nvm}"
export NODE_VERSION="${NODE_VERSION:-lts/*}"
export PNPM_HOME="${PNPM_HOME:-/home/vscode/.cache/pnpm}"
export YARN_CACHE_FOLDER="${YARN_CACHE_FOLDER:-/home/vscode/.cache/yarn}"
export npm_config_cache="${npm_config_cache:-/home/vscode/.cache/npm}"

# Install dependencies with retry
log_info "Installing dependencies..."
apt_get_retry update
apt_get_retry install -y curl git build-essential libssl-dev || {
    log_error "Failed to install dependencies"
    exit 1
}

# Install NVM (Node Version Manager)
log_info "Installing NVM..."
mkdir_safe "$NVM_DIR"
# Use v0.40.1 (latest stable version) instead of "latest" which doesn't exist
download_and_pipe "https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh" bash || {
    log_error "Failed to install NVM"
    exit 1
}

# Load NVM
export NVM_DIR="$NVM_DIR"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js (latest LTS by default)
log_info "Installing Node.js ${NODE_VERSION}..."
retry 3 5 nvm install "$NODE_VERSION" || {
    log_error "Failed to install Node.js"
    exit 1
}
nvm use "$NODE_VERSION"
nvm alias default "$NODE_VERSION"

# Get installed Node and npm versions
NODE_INSTALLED=$(node --version)
NPM_INSTALLED=$(npm --version)

log_success "Node.js ${NODE_INSTALLED} installed"
log_success "npm ${NPM_INSTALLED} installed"

# Install Yarn (latest stable)
log_info "Installing Yarn..."
retry 3 5 npm install --no-audit --no-fund -g yarn || {
    log_warning "Failed to install Yarn, but continuing..."
}
if command_exists yarn; then
    YARN_VERSION=$(yarn --version)
    log_success "Yarn ${YARN_VERSION} installed"
fi

# Install pnpm (latest)
log_info "Installing pnpm..."
download_and_pipe "https://get.pnpm.io/install.sh" sh - || {
    log_warning "Failed to install pnpm, but continuing..."
}
export PATH="$PNPM_HOME:$PATH"
if command_exists pnpm; then
    PNPM_VERSION=$(pnpm --version)
    log_success "pnpm ${PNPM_VERSION} installed"
fi

# Install global npm packages
log_info "Installing global packages..."

# Define packages to install
declare -a PACKAGES=(
    "typescript"
    "ts-node"
    "eslint"
    "prettier"
    "vite"
    "npm-check-updates"
    "nodemon"
    "pm2"
)

# Install each package with retry
for package in "${PACKAGES[@]}"; do
    log_info "Installing ${package}..."
    if retry 3 5 npm install --no-audit --no-fund -g "$package"; then
        log_success "${package} installed"
    else
        log_warning "Failed to install ${package}, but continuing..."
    fi
done

# Display installed versions
if command_exists tsc; then
    TS_VERSION=$(tsc --version)
    log_success "TypeScript ${TS_VERSION}"
fi
if command_exists eslint; then
    ESLINT_VERSION=$(eslint --version)
    log_success "${ESLINT_VERSION}"
fi
if command_exists prettier; then
    PRETTIER_VERSION=$(prettier --version)
    log_success "Prettier ${PRETTIER_VERSION}"
fi
if command_exists vite; then
    VITE_VERSION=$(vite --version)
    log_success "Vite ${VITE_VERSION}"
fi
if command_exists nodemon; then
    NODEMON_VERSION=$(nodemon --version)
    log_success "nodemon ${NODEMON_VERSION}"
fi
if command_exists pm2; then
    PM2_VERSION=$(pm2 --version)
    log_success "PM2 ${PM2_VERSION}"
fi

# Create cache directories
mkdir_safe "$npm_config_cache"
mkdir_safe "$YARN_CACHE_FOLDER"
mkdir_safe "$PNPM_HOME"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Node.js environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
log_success "Installation complete!"
echo ""
echo "Installed components:"
echo "  - NVM (Node Version Manager)"
echo "  - Node.js ${NODE_INSTALLED}"
echo "  - npm ${NPM_INSTALLED}"
if command_exists yarn; then
    echo "  - Yarn ${YARN_VERSION:-$(yarn --version 2>/dev/null)}"
fi
if command_exists pnpm; then
    echo "  - pnpm ${PNPM_VERSION:-$(pnpm --version 2>/dev/null)}"
fi
if command_exists tsc; then
    echo "  - TypeScript"
fi
if command_exists ts-node; then
    echo "  - ts-node"
fi
if command_exists eslint; then
    echo "  - ESLint"
fi
if command_exists prettier; then
    echo "  - Prettier"
fi
if command_exists vite; then
    echo "  - Vite"
fi
if command_exists ncu; then
    echo "  - npm-check-updates"
fi
if command_exists nodemon; then
    echo "  - nodemon"
fi
if command_exists pm2; then
    echo "  - PM2"
fi
echo ""
echo "Cache directories:"
echo "  - NVM: $NVM_DIR"
echo "  - npm: $npm_config_cache"
echo "  - Yarn: $YARN_CACHE_FOLDER"
echo "  - pnpm: $PNPM_HOME"
echo ""

# Exit successfully
exit 0
