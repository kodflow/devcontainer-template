#!/bin/bash
# ============================================================================
# Claude Code Marketplace - One-liner Install
# ============================================================================
# curl -sL https://raw.githubusercontent.com/kodflow/devcontainer-template/main/.devcontainer/features/claude/install.sh | bash
# ============================================================================

set -e

REPO="kodflow/devcontainer-template"
BRANCH="main"
BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}/.devcontainer/images"

# DC_TARGET: Override installation directory (defaults to current working directory)
# Usage: DC_TARGET=/path/to/project ./install.sh
TARGET="${DC_TARGET:-$(pwd)}"

echo "═══════════════════════════════════════════"
echo "  Claude Code Marketplace"
echo "═══════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 1. Install Claude CLI (si pas déjà installé)
# ─────────────────────────────────────────────────────────────────────────────
if ! command -v claude &>/dev/null; then
    echo "→ Installing Claude CLI..."
    npm install -g @anthropic-ai/claude-code 2>/dev/null || \
    curl -fsSL https://claude.ai/install.sh | sh 2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. Créer les dossiers
# ─────────────────────────────────────────────────────────────────────────────
echo "→ Setting up $TARGET/.claude/..."
mkdir -p "$TARGET/.claude/commands"
mkdir -p "$TARGET/.claude/scripts"

# ─────────────────────────────────────────────────────────────────────────────
# 3. Télécharger les commandes
# ─────────────────────────────────────────────────────────────────────────────
echo "→ Downloading commands..."
for cmd in git search prompt; do
    curl -sL "$BASE/.claude/commands/$cmd.md" -o "$TARGET/.claude/commands/$cmd.md" 2>/dev/null && echo "  ✓ /$cmd"
done

# ─────────────────────────────────────────────────────────────────────────────
# 4. Télécharger les scripts (hooks)
# ─────────────────────────────────────────────────────────────────────────────
echo "→ Downloading scripts..."
download_failed=0
for script in format imports lint post-edit pre-validate security test bash-validate commit-validate post-compact on-stop notification session-init; do
    script_tmp="$(mktemp)"
    if curl -fsL --retry 2 "$BASE/.claude/scripts/$script.sh" -o "$script_tmp" 2>/dev/null; then
        install -m 0755 "$script_tmp" "$TARGET/.claude/scripts/$script.sh"
    else
        echo "  ⚠ Failed to download: $script.sh" >&2
        download_failed=1
    fi
    rm -f "$script_tmp"
done
[ "$download_failed" -eq 0 ] && echo "  ✓ hooks (format, lint, security...)" || echo "  ⚠ Some hooks failed to download"

# ─────────────────────────────────────────────────────────────────────────────
# 5. Télécharger settings.json
# ─────────────────────────────────────────────────────────────────────────────
echo "→ Downloading settings..."
curl -sL "$BASE/.claude/settings.json" -o "$TARGET/.claude/settings.json" 2>/dev/null
echo "  ✓ settings.json"

# ─────────────────────────────────────────────────────────────────────────────
# 6. Télécharger CLAUDE.md (si pas existant)
# ─────────────────────────────────────────────────────────────────────────────
if [ ! -f "$TARGET/CLAUDE.md" ]; then
    curl -sL "https://raw.githubusercontent.com/${REPO}/${BRANCH}/CLAUDE.md" -o "$TARGET/CLAUDE.md" 2>/dev/null
    echo "  ✓ CLAUDE.md"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 7. Installer grepai (semantic code search MCP)
# ─────────────────────────────────────────────────────────────────────────────
echo "→ Installing grepai..."
mkdir -p "$HOME/.local/bin"

# Détecter OS
case "$(uname -s)" in
    Linux*)  GREPAI_OS="linux" ;;
    Darwin*) GREPAI_OS="darwin" ;;
    MINGW*|MSYS*|CYGWIN*) GREPAI_OS="windows" ;;
    *)       GREPAI_OS="linux" ;;
esac

# Détecter architecture
case "$(uname -m)" in
    x86_64|amd64) GREPAI_ARCH="amd64" ;;
    aarch64|arm64) GREPAI_ARCH="arm64" ;;
    *)            GREPAI_ARCH="amd64" ;;
esac

# Extension pour Windows
GREPAI_EXT=""
[ "$GREPAI_OS" = "windows" ] && GREPAI_EXT=".exe"

# Télécharger depuis les releases officielles (avec sécurité download)
GREPAI_URL="https://github.com/yoanbernabeu/grepai/releases/latest/download/grepai_${GREPAI_OS}_${GREPAI_ARCH}${GREPAI_EXT}"
grepai_tmp="$(mktemp)"
if curl -fsL --retry 3 --retry-delay 1 --proto '=https' --tlsv1.2 "$GREPAI_URL" -o "$grepai_tmp" 2>/dev/null; then
    install -m 0755 "$grepai_tmp" "$HOME/.local/bin/grepai${GREPAI_EXT}"
    echo "  ✓ grepai (${GREPAI_OS}/${GREPAI_ARCH})"
else
    # Fallback: try go install with binary discovery
    if command -v go &>/dev/null; then
        if go install github.com/yoanbernabeu/grepai/cmd/grepai@latest 2>/dev/null; then
            # Ensure binary is in expected location
            GREPAI_BIN_PATH="$(go env GOBIN 2>/dev/null || true)"
            [ -z "${GREPAI_BIN_PATH}" ] && GREPAI_BIN_PATH="$(go env GOPATH 2>/dev/null)/bin"
            if [ -x "${GREPAI_BIN_PATH}/grepai${GREPAI_EXT}" ]; then
                cp -f "${GREPAI_BIN_PATH}/grepai${GREPAI_EXT}" "$HOME/.local/bin/grepai${GREPAI_EXT}"
                chmod +x "$HOME/.local/bin/grepai${GREPAI_EXT}"
            fi
            echo "  ✓ grepai (go install)"
        else
            echo "  ⚠ grepai install failed (optional)"
        fi
    else
        echo "  ⚠ grepai download failed (optional)"
    fi
fi
rm -f "$grepai_tmp"

# ─────────────────────────────────────────────────────────────────────────────
# 8. Installer status-line (binaire officiel)
# ─────────────────────────────────────────────────────────────────────────────
echo "→ Installing status-line..."
mkdir -p "$HOME/.local/bin"

# Détecter OS
case "$(uname -s)" in
    Linux*)  STATUS_OS="linux" ;;
    Darwin*) STATUS_OS="darwin" ;;
    MINGW*|MSYS*|CYGWIN*) STATUS_OS="windows" ;;
    *)       STATUS_OS="linux" ;;
esac

# Détecter architecture
case "$(uname -m)" in
    x86_64|amd64) STATUS_ARCH="amd64" ;;
    aarch64|arm64) STATUS_ARCH="arm64" ;;
    *)            STATUS_ARCH="amd64" ;;
esac

# Extension pour Windows
STATUS_EXT=""
[ "$STATUS_OS" = "windows" ] && STATUS_EXT=".exe"

# Télécharger depuis les releases officielles (avec sécurité download)
STATUS_URL="https://github.com/kodflow/status-line/releases/latest/download/status-line-${STATUS_OS}-${STATUS_ARCH}${STATUS_EXT}"
status_tmp="$(mktemp)"
if curl -fsL --retry 3 --retry-delay 1 --proto '=https' --tlsv1.2 "$STATUS_URL" -o "$status_tmp" 2>/dev/null; then
    install -m 0755 "$status_tmp" "$HOME/.local/bin/status-line${STATUS_EXT}"
    echo "  ✓ status-line (${STATUS_OS}/${STATUS_ARCH})"
else
    echo "  ⚠ status-line download failed (optional)"
fi
rm -f "$status_tmp"

# Ajouter au PATH si nécessaire
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    # shellcheck disable=SC2016 # $HOME doit être résolu à l'exécution du shell, pas maintenant
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc" 2>/dev/null || true
    # shellcheck disable=SC2016 # $HOME doit être résolu à l'exécution du shell, pas maintenant
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc" 2>/dev/null || true
fi

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo "  ✓ Installation complete!"
echo ""
echo "  Commandes disponibles:"
echo "    /git     - Workflow git (commit, branch, PR)"
echo "    /search  - Recherche documentation"
echo "    /prompt  - Write better /plan descriptions"
echo ""
echo "  Native Claude 2.x features:"
echo "    EnterPlanMode - Planification intégrée"
echo "    TaskCreate    - Suivi des tâches avec progression"
echo "    Task agents   - Parallélisation"
echo ""
echo "  → Relance 'claude' pour charger les commandes"
echo "═══════════════════════════════════════════"
