#!/bin/bash
# Combined post-edit hook: format + imports + lint + WIP check
# Usage: post-edit.sh <file_path>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$1"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    exit 0
fi

# === WIP Task Check ===
# Vérifie qu'une task est en WIP si on est en BYPASS mode
STATE_FILE="${CLAUDE_STATE_FILE:-/workspace/.claude/state.json}"

if [[ -f "$STATE_FILE" ]]; then
    MODE=$(jq -r '.mode // "plan"' "$STATE_FILE" 2>/dev/null || echo "plan")
    CURRENT_TASK=$(jq -r '.currentTask // ""' "$STATE_FILE" 2>/dev/null || echo "")

    if [[ "$MODE" == "bypass" && -z "$CURRENT_TASK" ]]; then
        echo "⚠️  POST-EDIT WARNING: Edit effectué sans task WIP active"
        echo "   Fichier: $FILE"
        echo "   Mode: bypass"
        echo ""
        echo "   Rappel: En BYPASS MODE, démarrez une task avant d'éditer:"
        echo "   /home/vscode/.claude/scripts/task-start.sh <uuid>"
        echo ""
        # Log pour audit
        logger -t "claude-wip-check" "Edit without WIP task: $FILE" 2>/dev/null || true
    fi
fi

# 1. Format
"$SCRIPT_DIR/format.sh" "$FILE"

# 2. Sort imports
"$SCRIPT_DIR/imports.sh" "$FILE"

# 3. Lint (with auto-fix)
"$SCRIPT_DIR/lint.sh" "$FILE"

exit 0
