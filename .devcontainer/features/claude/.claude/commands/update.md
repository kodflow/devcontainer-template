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

# Commands
for cmd in build run commit secret install update; do
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

echo ""
echo "Done! Restart claude to reload."
```

---

## Output

```
Updating from Kodflow Marketplace...
✓ /build
✓ /run
✓ /commit
✓ /secret
✓ /install
✓ /update
✓ scripts
✓ settings.json

Installing status-line...
✓ status-line

Done! Restart claude to reload.
```
