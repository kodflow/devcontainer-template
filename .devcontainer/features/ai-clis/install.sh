#!/bin/bash
# ============================================================================
# ai-clis/install.sh — extra agentic coding CLIs (challenge-setup-2026 Q4)
# ----------------------------------------------------------------------------
# Opt-in companions to Claude Code: Codex (Apache-2.0), opencode (MIT),
# Crush (MIT). Fail-soft per tool: each is independent and optional, so one
# failing install must not abort the others or the build. NO API KEYS are ever
# baked — every CLI is inert until the user injects their own key at runtime
# (1Password `op run`/`op inject`, per the /secret convention). Always exit 0.
# NOTE: not `set -e`.
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
    print_banner() { echo "== $* =="; }
}

ENABLE_CODEX="${ENABLECODEX:-true}"
ENABLE_OPENCODE="${ENABLEOPENCODE:-true}"
ENABLE_CRUSH="${ENABLECRUSH:-true}"

detect_arch
print_banner "AI Coding CLIs" 2>/dev/null || echo "== AI Coding CLIs =="

# --- Codex (openai/codex) — native Rust binary, musl static, Apache-2.0 -------
if [ "$ENABLE_CODEX" = "true" ]; then
    CXV="$(get_github_latest_version_or_empty openai/codex)"
    # openai/codex tags releases as `rust-v<semver>`. get_github_latest_version
    # only strips a leading bare `v`, so CXV still carries the `rust-v` prefix.
    # Normalize it off here and re-add a single `rust-v` when building the URL,
    # otherwise the path double-prefixes to `rust-vrust-v…` and 404s.
    CXV="${CXV#rust-v}"; CXV="${CXV#v}"
    if [ -n "$CXV" ]; then
        cx_triple="x86_64-unknown-linux-musl"; [ "$ARCH_DEB" = "arm64" ] && cx_triple="aarch64-unknown-linux-musl"
        tmp="$(mktemp -d)"
        # Release asset: codex-<triple>.tar.gz containing the `codex` binary.
        if curl -fsSL --retry 3 "https://github.com/openai/codex/releases/download/rust-v${CXV}/codex-${cx_triple}.tar.gz" -o "$tmp/codex.tgz" 2>/dev/null \
           && tar -xzf "$tmp/codex.tgz" -C "$tmp" 2>/dev/null; then
            cxbin="$(find "$tmp" -maxdepth 2 -type f -name 'codex*' -perm -u+x | head -n1)"
            [ -n "$cxbin" ] && sudo install -m0755 "$cxbin" /usr/local/bin/codex
        fi
        rm -rf "$tmp"
    fi
    # Fallback: npm package @openai/codex if the binary path changed.
    if ! command -v codex >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        sudo npm install -g @openai/codex 2>/dev/null || log_warning "codex npm fallback failed"
    fi
fi

# --- opencode (opencode-ai) — official install script, MIT --------------------
if [ "$ENABLE_OPENCODE" = "true" ]; then
    if command -v npm >/dev/null 2>&1 && sudo npm install -g opencode-ai 2>/dev/null; then
        :
    else
        log_warning "opencode npm install failed; skipping remote installer fallback"
    fi
fi

# --- Crush (charmbracelet/crush) — Go binary, MIT -----------------------------
if [ "$ENABLE_CRUSH" = "true" ]; then
    if command -v go >/dev/null 2>&1 && go install github.com/charmbracelet/crush@latest 2>/dev/null; then
        # go install drops it in $GOPATH/bin or $GOBIN; symlink onto PATH.
        gobin="$(go env GOBIN 2>/dev/null)"; [ -z "$gobin" ] && gobin="$(go env GOPATH 2>/dev/null)/bin"
        [ -x "$gobin/crush" ] && sudo ln -sf "$gobin/crush" /usr/local/bin/crush
    else
        CRV="$(get_github_latest_version_or_empty charmbracelet/crush)"
        if [ -n "$CRV" ]; then
            tmp="$(mktemp -d)"
            if curl -fsSL --retry 3 "https://github.com/charmbracelet/crush/releases/download/v${CRV}/crush_${CRV}_Linux_${ARCH_DEB}.tar.gz" -o "$tmp/crush.tgz" 2>/dev/null \
               && tar -xzf "$tmp/crush.tgz" -C "$tmp" 2>/dev/null; then
                crbin="$(find "$tmp" -maxdepth 2 -type f -name crush -perm -u+x | head -n1)"
                [ -n "$crbin" ] && sudo install -m0755 "$crbin" /usr/local/bin/crush
            fi
            rm -rf "$tmp"
        fi
    fi
fi

# --- Summary ------------------------------------------------------------------
INSTALLED=(); ABSENT=()
for t in codex opencode crush; do
    if command -v "$t" >/dev/null 2>&1; then INSTALLED+=("$t"); ok "$t"; else ABSENT+=("$t"); warn "$t not installed"; fi
done
echo ""
log_warning "Reminder: these CLIs are INERT without your own API key. Inject at runtime"
log_warning "via 1Password (op run / op inject) — never bake keys into the image."
log_success "ai-clis: ${#INSTALLED[@]} installed, ${#ABSENT[@]} absent"
exit 0
