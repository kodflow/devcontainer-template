# Update - Mise à jour depuis la Marketplace

Mettre à jour les commandes et scripts depuis GitHub.

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

Done! Restart claude to reload.
```
