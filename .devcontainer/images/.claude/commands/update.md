# Update - Mise à jour depuis la Marketplace

$ARGUMENTS

---

## Description

Mettre à jour les commandes, scripts, binaires et Taskwarrior depuis GitHub.

---

## Arguments

| Pattern | Action |
|---------|--------|
| (vide) | Met a jour depuis le repository Kodflow |
| `--help` | Affiche l'aide de la commande |

---

## --help

Quand `--help` est passe, afficher :

```
═══════════════════════════════════════════════
  /update - Mise a jour depuis la Marketplace
═══════════════════════════════════════════════

Usage: /update [options]

Options:
  (vide)          Met a jour tout depuis GitHub
  --help          Affiche cette aide

Elements mis a jour:
  - Commandes (/build, /commit, /feature, etc.)
  - Scripts (format, lint, security...)
  - Binaires (status-line, ktn-linter)
  - Configuration MCP
  - Taskwarrior

Exemples:
  /update         Telecharge les dernieres versions
═══════════════════════════════════════════════
```

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
mkdir -p ".claude/commands" ".claude/scripts" ".claude/sessions"

# Commands
for cmd in build commit secret install update feature fix; do
    curl -sL "$BASE/.claude/commands/$cmd.md" -o ".claude/commands/$cmd.md" 2>/dev/null && echo "✓ /$cmd"
done

# Scripts (including Taskwarrior hooks)
for s in format imports lint post-edit pre-validate security test typecheck task-validate task-log task-init task-subtasks; do
    curl -sL "$BASE/.claude/scripts/$s.sh" -o ".claude/scripts/$s.sh" 2>/dev/null && chmod +x ".claude/scripts/$s.sh"
done
echo "✓ scripts"

# Taskwarrior installation
echo ""
echo "Installing Taskwarrior..."
if ! command -v task &>/dev/null; then
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq taskwarrior && echo "✓ taskwarrior"
    elif command -v apk &>/dev/null; then
        sudo apk add --no-cache task && echo "✓ taskwarrior"
    elif command -v brew &>/dev/null; then
        brew install task && echo "✓ taskwarrior"
    else
        echo "⚠ taskwarrior (manual install required)"
    fi
else
    echo "✓ taskwarrior (already installed)"
fi

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

# MCP config (merge with existing + add Taskwarrior)
echo ""
echo "Configuring MCP..."
MCP_REMOTE=$(curl -sL "$BASE/.mcp.json" 2>/dev/null)

# Add Taskwarrior MCP server
TASKWARRIOR_MCP='{"taskwarrior":{"command":"npx","args":["-y","mcp-server-taskwarrior"]}}'

if [ -n "$MCP_REMOTE" ]; then
    if [ -f ".mcp.json" ]; then
        # Merge: keep existing servers, add missing ones + taskwarrior
        echo "$MCP_REMOTE" | jq -s --argjson tw "$TASKWARRIOR_MCP" '.[0].mcpServers * .[1].mcpServers * $tw | {mcpServers: .}' .mcp.json - > .mcp.json.tmp 2>/dev/null && mv .mcp.json.tmp .mcp.json
        echo "✓ .mcp.json (merged + taskwarrior)"
    else
        echo "$MCP_REMOTE" | jq --argjson tw "$TASKWARRIOR_MCP" '.mcpServers += $tw' > .mcp.json
        echo "✓ .mcp.json (created + taskwarrior)"
    fi
else
    # Fallback: create with just taskwarrior
    echo "{\"mcpServers\":$TASKWARRIOR_MCP}" > .mcp.json
    echo "✓ .mcp.json (taskwarrior only)"
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

Installing Taskwarrior...
✓ taskwarrior

✓ settings.json

Installing status-line...
✓ status-line

Configuring MCP...
✓ .mcp.json (merged + taskwarrior)

Configuring .gitignore...
✓ .gitignore (added .claude)

Done! Restart claude to reload.
```

## Taskwarrior Integration

Après mise à jour, les commandes `/feature` et `/fix` utilisent Taskwarrior pour :
- **Suivi obligatoire** : Chaque Write/Edit est bloqué sans tâche active
- **4 phases** : Planning → Implementation → Testing → PR
- **Event sourcing** : Chaque action loggée en annotation JSON
- **Récupération crash** : Reprise via `--continue`

```bash
# Voir les projets Claude
task +claude list

# Voir les événements d'un projet
task project:<name> annotations

# Exporter en JSON
task project:<name> export
```
