#!/bin/bash
# ============================================================================
# Kodflow Claude Marketplace - One-liner Install
# ============================================================================
# curl -sL https://raw.githubusercontent.com/kodflow/devcontainer-template/main/.devcontainer/features/claude/install.sh | bash
# ============================================================================

set -e

REPO="kodflow/devcontainer-template"
BRANCH="main"
BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}/.devcontainer/features/claude"
TARGET="${KODFLOW_TARGET:-$(pwd)}"

echo "═══════════════════════════════════════════"
echo "  Kodflow Claude Marketplace"
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
for cmd in build run commit secret install update; do
    curl -sL "$BASE/.claude/commands/$cmd.md" -o "$TARGET/.claude/commands/$cmd.md" 2>/dev/null && echo "  ✓ /$cmd"
done

# ─────────────────────────────────────────────────────────────────────────────
# 4. Télécharger les scripts
# ─────────────────────────────────────────────────────────────────────────────
echo "→ Downloading scripts..."
for script in format imports lint post-edit pre-validate security test typecheck; do
    curl -sL "$BASE/.claude/scripts/$script.sh" -o "$TARGET/.claude/scripts/$script.sh" 2>/dev/null && \
    chmod +x "$TARGET/.claude/scripts/$script.sh"
done
echo "  ✓ hooks (format, lint, security...)"

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
    curl -sL "$BASE/CLAUDE.md" -o "$TARGET/CLAUDE.md" 2>/dev/null
    echo "  ✓ CLAUDE.md"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 7. Installer statusline (binaire)
# ─────────────────────────────────────────────────────────────────────────────
echo "→ Installing statusline..."
mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/kodflow-status" << 'EOF'
#!/bin/bash
# Git: branch + changes
if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    B=$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD)
    C=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    [ "$C" -gt 0 ] && echo "$B*$C" || echo "$B"
fi
EOF

chmod +x "$HOME/.local/bin/kodflow-status"
echo "  ✓ kodflow-status"

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
echo "    /build   - Planifier un projet"
echo "    /run     - Exécuter des tâches"
echo "    /commit  - Workflow git"
echo "    /update  - Mettre à jour depuis GitHub"
echo ""
echo "  → Relance 'claude' pour charger les commandes"
echo "═══════════════════════════════════════════"
