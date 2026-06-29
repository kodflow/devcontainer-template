#!/bin/bash
# ============================================================================
# review-scanners/install.sh — deterministic scanners for /review v2 (#392)
# ----------------------------------------------------------------------------
# Fail-soft by design: each scanner is independent and OPTIONAL. /review
# degrades cleanly when a tool is absent (marks the tier `absent`, caps
# confidence, never silent-passes). So one tool failing to install must NOT
# abort the others or the build — we record a per-tool ok|absent summary and
# always exit 0. NOTE: not `set -e`; failures are handled explicitly.
# ============================================================================
set -uo pipefail

FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../languages/shared/feature-utils.sh
source "${FEATURE_DIR}/feature-utils.sh" 2>/dev/null || \
source "${FEATURE_DIR}/../languages/shared/feature-utils.sh" 2>/dev/null || {
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
    log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
    log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
    log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
    log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
    ok() { echo -e "${GREEN}✓${NC} $*"; }
    warn() { echo -e "${YELLOW}⚠${NC} $*"; }
    detect_arch() { case "$(uname -m)" in x86_64) ARCH_UNAME=x86_64; ARCH_DEB=amd64;; aarch64|arm64) ARCH_UNAME=aarch64; ARCH_DEB=arm64;; esac; export ARCH_UNAME ARCH_DEB; }
    get_github_latest_version() { curl -fsS "https://api.github.com/repos/$1/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"v\?\([^"]*\)".*/\1/p' | head -n1; }
    get_github_latest_version_or_empty() { get_github_latest_version "$1" 2>/dev/null || echo ""; }
    apt_update_once() { sudo apt-get update; }
    install_binary_from_url() { local t; t=$(mktemp); if curl -fsSL --retry 3 "$1" -o "$t" 2>/dev/null; then sudo install -m "${3:-0755}" "$t" "$2"; rm -f "$t"; else rm -f "$t"; return 1; fi; }
    print_banner() { echo "== $* =="; }
}

ENABLE_SAST="${ENABLESAST:-true}"
ENABLE_SCA="${ENABLESCA:-true}"
ENABLE_LINTERS="${ENABLELINTERS:-true}"
ENABLE_ASTGREP="${ENABLEASTGREP:-true}"

detect_arch
print_banner "Review Deterministic Scanners" 2>/dev/null || echo "== Review scanners =="

INSTALLED=()
ABSENT=()
record() { if command -v "$1" >/dev/null 2>&1; then INSTALLED+=("$1"); ok "$1"; else ABSENT+=("$1"); warn "$1 not installed (review tier will report 'absent')"; fi; }

# --- Python-based scanners: isolated venv to dodge PEP-668 (externally managed) ---
VENV="/opt/review-scanners-venv"
PYTOOLS=()
[ "$ENABLE_SAST" = "true" ] && PYTOOLS+=("semgrep" "detect-secrets")
[ "$ENABLE_LINTERS" = "true" ] && PYTOOLS+=("checkov" "yamllint")
if [ "${#PYTOOLS[@]}" -gt 0 ]; then
    log_info "Creating scanner venv at $VENV..."
    if sudo python3 -m venv "$VENV" 2>/dev/null && sudo "$VENV/bin/pip" install --quiet --upgrade pip 2>/dev/null; then
        # Install each independently so one failure does not drop the rest.
        for pkg in "${PYTOOLS[@]}"; do
            if sudo "$VENV/bin/pip" install --quiet "$pkg" 2>/dev/null; then
                # detect-secrets ships the `detect-secrets` console script.
                bin="$pkg"
                [ -x "$VENV/bin/$bin" ] && sudo ln -sf "$VENV/bin/$bin" "/usr/local/bin/$bin"
            else
                log_warning "pip install $pkg failed"
            fi
        done
    else
        log_warning "Could not create scanner venv; skipping python scanners"
    fi
fi

# --- GitHub-release binaries (fail-soft each) ---
ghbin() {  # ghbin <repo> <asset-template-with-{ver}{arch}> <dest-binary-name> [arch=deb|uname]
    local repo="$1" tmpl="$2" name="$3" archkind="${4:-deb}"
    local ver arch url
    ver="$(get_github_latest_version_or_empty "$repo")"
    [ -z "$ver" ] && { log_warning "$name: could not resolve latest version (rate-limit?)"; return 1; }
    [ "$archkind" = "uname" ] && arch="$ARCH_UNAME" || arch="$ARCH_DEB"
    url="${tmpl//\{ver\}/$ver}"; url="${url//\{arch\}/$arch}"
    install_binary_from_url "$url" "/usr/local/bin/$name" 0755 2>/dev/null \
        || { log_warning "$name: download failed ($url)"; return 1; }
}

if [ "$ENABLE_SAST" = "true" ]; then
    # gitleaks release asset: gitleaks_<ver>_linux_<x64|arm64>.tar.gz (tarball)
    GLV="$(get_github_latest_version_or_empty gitleaks/gitleaks)"
    if [ -n "$GLV" ]; then
        gl_arch="x64"; [ "$ARCH_DEB" = "arm64" ] && gl_arch="arm64"
        tmp="$(mktemp -d)"
        if curl -fsSL --retry 3 "https://github.com/gitleaks/gitleaks/releases/download/v${GLV}/gitleaks_${GLV}_linux_${gl_arch}.tar.gz" -o "$tmp/gl.tgz" 2>/dev/null \
           && tar -xzf "$tmp/gl.tgz" -C "$tmp" gitleaks 2>/dev/null; then
            sudo install -m0755 "$tmp/gitleaks" /usr/local/bin/gitleaks
        fi
        rm -rf "$tmp"
    fi
    # trufflehog: official install script (writes to /usr/local/bin)
    curl -fsSL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh 2>/dev/null \
        | sudo sh -s -- -b /usr/local/bin 2>/dev/null || log_warning "trufflehog install script failed"
fi

if [ "$ENABLE_SCA" = "true" ]; then
    # osv-scanner release binary: osv-scanner_linux_<amd64|arm64>
    ghbin google/osv-scanner \
        "https://github.com/google/osv-scanner/releases/download/v{ver}/osv-scanner_linux_{arch}" \
        osv-scanner deb || true
    # trivy: official install script
    curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh 2>/dev/null \
        | sudo sh -s -- -b /usr/local/bin 2>/dev/null || log_warning "trivy install script failed"
fi

if [ "$ENABLE_LINTERS" = "true" ]; then
    # hadolint release binary: hadolint-Linux-<x86_64|arm64>
    HV="$(get_github_latest_version_or_empty hadolint/hadolint)"
    if [ -n "$HV" ]; then
        ha_arch="x86_64"; [ "$ARCH_DEB" = "arm64" ] && ha_arch="arm64"
        install_binary_from_url "https://github.com/hadolint/hadolint/releases/download/v${HV}/hadolint-Linux-${ha_arch}" /usr/local/bin/hadolint 0755 2>/dev/null \
            || log_warning "hadolint download failed"
    fi
    # actionlint: official downloader script
    tmp="$(mktemp -d)"
    if curl -fsSL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash 2>/dev/null | bash -s -- latest "$tmp" >/dev/null 2>&1 \
       && [ -x "$tmp/actionlint" ]; then
        sudo install -m0755 "$tmp/actionlint" /usr/local/bin/actionlint
    else
        log_warning "actionlint install failed"
    fi
    rm -rf "$tmp"
fi

if [ "$ENABLE_ASTGREP" = "true" ]; then
    # ast-grep: prefer cargo, then npm, then GH release. Binary MUST be 'ast-grep'
    # — never rely on 'sg' (/usr/bin/sg is newgrp; documented footgun in /review).
    if command -v cargo >/dev/null 2>&1 && cargo install ast-grep --locked 2>/dev/null; then
        :
    elif command -v npm >/dev/null 2>&1 && sudo npm install -g @ast-grep/cli 2>/dev/null; then
        :
    else
        AGV="$(get_github_latest_version_or_empty ast-grep/ast-grep)"
        if [ -n "$AGV" ]; then
            ag_arch="x86_64-unknown-linux-gnu"; [ "$ARCH_DEB" = "arm64" ] && ag_arch="aarch64-unknown-linux-gnu"
            tmp="$(mktemp -d)"
            if curl -fsSL --retry 3 "https://github.com/ast-grep/ast-grep/releases/download/${AGV}/app-${ag_arch}.zip" -o "$tmp/ag.zip" 2>/dev/null \
               && unzip -o "$tmp/ag.zip" -d "$tmp" >/dev/null 2>&1 && [ -x "$tmp/ast-grep" ]; then
                sudo install -m0755 "$tmp/ast-grep" /usr/local/bin/ast-grep
            else
                log_warning "ast-grep download failed"
            fi
            rm -rf "$tmp"
        fi
    fi
fi

# --- Summary (drives the /review-doctor scanner matrix expectation) ---
log_info "Scanner install summary:"
for t in semgrep detect-secrets gitleaks trufflehog osv-scanner trivy hadolint actionlint yamllint checkov ast-grep; do
    record "$t"
done
echo ""
log_success "review-scanners: ${#INSTALLED[@]} installed, ${#ABSENT[@]} absent (absent tiers degrade cleanly in /review)"
# Always succeed — absence is a supported state, not a build failure.
exit 0
