# Update - Mise à jour depuis la Marketplace

Mettre à jour les commandes, scripts et binaires depuis GitHub.

---

## Action

Exécuter ce script bash :

```bash
#!/bin/bash
REPO="kodflow/devcontainer-template"
BASE="https://raw.githubusercontent.com/$REPO/main/.devcontainer/features/claude"

echo "Updating from Kodflow Marketplace..."

# Check if .claude existed before (for gitignore logic)
CLAUDE_EXISTED=false
[ -d ".claude" ] && CLAUDE_EXISTED=true

# Create directories
mkdir -p ".claude/commands" ".claude/scripts"

# Commands
for cmd in build commit secret install update feature fix; do
    curl -sL "$BASE/.claude/commands/$cmd.md" -o ".claude/commands/$cmd.md" 2>/dev/null && echo "✓ /$cmd"
done

# Scripts
for s in format imports lint post-edit pre-validate security test typecheck; do
    curl -sL "$BASE/.claude/scripts/$s.sh" -o ".claude/scripts/$s.sh" 2>/dev/null && chmod +x ".claude/scripts/$s.sh"
done
echo "✓ scripts"

# Settings
curl -sL "$BASE/.claude/settings.json" -o ".claude/settings.json" 2>/dev/null
echo "✓ settings.json"

# Status-line binary
echo ""
echo "Installing status-line..."
mkdir -p "$HOME/.local/bin"

case "$(uname -s)" in
    Linux*)  STATUS_OS="linux" ;;
    Darwin*) STATUS_OS="darwin" ;;
    MINGW*|MSYS*|CYGWIN*) STATUS_OS="windows" ;;
    *) STATUS_OS="linux" ;;
esac

case "$(uname -m)" in
    x86_64|amd64) STATUS_ARCH="amd64" ;;
    aarch64|arm64) STATUS_ARCH="arm64" ;;
    *) STATUS_ARCH="amd64" ;;
esac

STATUS_EXT=""
[ "$STATUS_OS" = "windows" ] && STATUS_EXT=".exe"

STATUS_URL="https://github.com/kodflow/status-line/releases/latest/download/status-line-${STATUS_OS}-${STATUS_ARCH}${STATUS_EXT}"
if curl -sL "$STATUS_URL" -o "$HOME/.local/bin/status-line${STATUS_EXT}" 2>/dev/null; then
    chmod +x "$HOME/.local/bin/status-line${STATUS_EXT}"
    echo "✓ status-line"
else
    echo "⚠ status-line (download failed)"
fi

# MCP config (merge with existing)
echo ""
echo "Configuring MCP..."
MCP_REMOTE=$(curl -sL "$BASE/.mcp.json" 2>/dev/null)
if [ -n "$MCP_REMOTE" ]; then
    if [ -f ".mcp.json" ]; then
        # Merge: keep existing servers, add missing ones
        echo "$MCP_REMOTE" | jq -s '.[0].mcpServers * .[1].mcpServers | {mcpServers: .}' .mcp.json - > .mcp.json.tmp 2>/dev/null && mv .mcp.json.tmp .mcp.json
        echo "✓ .mcp.json (merged)"
    else
        echo "$MCP_REMOTE" > .mcp.json
        echo "✓ .mcp.json (created)"
    fi
else
    echo "⚠ .mcp.json (download failed)"
fi

# Add .claude to .gitignore if it was newly created
if [ "$CLAUDE_EXISTED" = false ]; then
    echo ""
    echo "Configuring .gitignore..."
    if [ -f ".gitignore" ]; then
        if ! grep -q "^\.claude$" .gitignore 2>/dev/null; then
            echo "" >> .gitignore
            echo "# Claude Code (auto-added by /update)" >> .gitignore
            echo ".claude" >> .gitignore
            echo "✓ .gitignore (added .claude)"
        fi
    else
        echo "# Claude Code" > .gitignore
        echo ".claude" >> .gitignore
        echo "✓ .gitignore (created)"
    fi
fi

echo ""
echo "Done! Restart claude to reload."
```

---

## Output

```
Updating from Kodflow Marketplace...
✓ /build
✓ /commit
✓ /secret
✓ /install
✓ /update
✓ /feature
✓ /fix
✓ scripts
✓ settings.json

Installing status-line...
✓ status-line

Configuring MCP...
✓ .mcp.json (merged)

Configuring .gitignore...
✓ .gitignore (added .claude)

Done! Restart claude to reload.
```
