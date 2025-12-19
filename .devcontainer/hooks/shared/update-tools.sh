#!/bin/bash
# =============================================================================
# Kodflow Tools Updater
# =============================================================================
# Downloads latest versions of frequently updated tools
# Called by postCreate.sh to ensure latest versions on each rebuild
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}→${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error()   { echo -e "${RED}✗${NC} $1"; }

# Ensure directories exist
mkdir -p "$HOME/.local/bin"

# =============================================================================
# Detect architecture
# =============================================================================
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)             echo "amd64" ;;
    esac
}

ARCH=$(detect_arch)
OS="linux"

echo ""
echo "═══════════════════════════════════════════════"
echo "  Updating tools to latest versions..."
echo "═══════════════════════════════════════════════"
echo ""

# =============================================================================
# status-line (Claude Code status bar)
# https://github.com/kodflow/status-line
# =============================================================================
log_info "Updating status-line..."
STATUS_URL="https://github.com/kodflow/status-line/releases/latest/download/status-line-${OS}-${ARCH}"
if curl -fsSL "$STATUS_URL" -o "$HOME/.local/bin/status-line" 2>/dev/null; then
    chmod +x "$HOME/.local/bin/status-line"
    VERSION=$("$HOME/.local/bin/status-line" --version 2>/dev/null || echo "installed")
    log_success "status-line ($VERSION)"
else
    log_warning "status-line download failed (optional)"
fi

# =============================================================================
# ktn-linter (Go linter)
# https://github.com/kodflow/ktn-linter
# Only install if Go is available
# =============================================================================
if command -v go &>/dev/null; then
    log_info "Updating ktn-linter..."

    # Determine install location
    KTN_BIN="${GOPATH:-$HOME/go}/bin"
    mkdir -p "$KTN_BIN"

    KTN_URL="https://github.com/kodflow/ktn-linter/releases/latest/download/ktn-linter-${OS}-${ARCH}"
    if curl -fsSL "$KTN_URL" -o "$KTN_BIN/ktn-linter" 2>/dev/null; then
        chmod +x "$KTN_BIN/ktn-linter"
        VERSION=$("$KTN_BIN/ktn-linter" --version 2>/dev/null || echo "installed")
        log_success "ktn-linter ($VERSION)"
    else
        log_warning "ktn-linter download failed (optional)"
    fi
fi

# =============================================================================
# Add more tools here as needed
# =============================================================================
# Example:
# if command -v some_tool &>/dev/null; then
#     log_info "Updating some_tool..."
#     # download and install
# fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  Tools update complete"
echo "═══════════════════════════════════════════════"
echo ""
