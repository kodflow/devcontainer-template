#!/usr/bin/env bash
# =============================================================================
# Shared Feature Utility Library
# =============================================================================
# Common functions for all DevContainer feature install.sh scripts.
# Source this file at the top of each install.sh with inline fallback:
#
#   FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   # shellcheck source=../shared/feature-utils.sh
#   source "${FEATURE_DIR}/../shared/feature-utils.sh" 2>/dev/null || {
#       RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
#       ok() { echo -e "${GREEN}✓${NC} $*"; }
#       warn() { echo -e "${YELLOW}⚠${NC} $*"; }
#       err() { echo -e "${RED}✗${NC} $*" >&2; }
#   }
# =============================================================================

# Guard against double-sourcing
[[ -n "${_FEATURE_UTILS_LOADED:-}" ]] && return 0
readonly _FEATURE_UTILS_LOADED=1

# =============================================================================
# Colors
# =============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# =============================================================================
# Logging
# =============================================================================
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Short aliases (used by most features)
ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*" >&2; }

# =============================================================================
# Architecture Detection
# =============================================================================
# Sets: ARCH_UNAME (x86_64/aarch64), ARCH_DEB (amd64/arm64)
detect_arch() {
    ARCH_UNAME=$(uname -m)
    case "$ARCH_UNAME" in
        x86_64)           ARCH_DEB="amd64" ;;
        aarch64|arm64)    ARCH_UNAME="aarch64"; ARCH_DEB="arm64" ;;
        armv7l)           ARCH_DEB="armhf" ;;
        *)                err "Unsupported architecture: $ARCH_UNAME"; return 1 ;;
    esac
    export ARCH_UNAME ARCH_DEB
}

# =============================================================================
# GitHub Latest Version
# =============================================================================
# Usage: get_github_latest_version "owner/repo" "fallback_version"
# Returns version WITHOUT 'v' prefix
get_github_latest_version() {
    local repo="$1"
    local fallback="$2"
    local version
    version=$(curl -s --connect-timeout 5 --max-time 10 \
        "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
        | sed -n 's/.*"tag_name": *"v\?\([^"]*\)".*/\1/p' | head -n 1)
    echo "${version:-$fallback}"
}

# =============================================================================
# Tool Check
# =============================================================================
tool_installed() {
    command -v "$1" &>/dev/null
}

# =============================================================================
# Banners
# =============================================================================
print_banner() {
    echo "========================================="
    echo "Installing $1"
    echo "========================================="
}

print_success_banner() {
    echo ""
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}$1 installed successfully!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
}
