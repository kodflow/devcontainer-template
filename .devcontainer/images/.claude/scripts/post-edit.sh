#!/bin/bash
# ============================================================================
# post-edit.sh - Format only (fast, runs after every Write/Edit)
# Hook: PostToolUse (Write|Edit)
# Exit 0 = always (fail-open)
#
# Purpose: Auto-format edited files for immediate feedback.
# Lint, typecheck, test, and security scans are batched in on-stop-quality.sh
# (Stop hook) to avoid redundant CPU work when Claude edits multiple files.
# ============================================================================

set +e  # Fail-open: hooks should never block unexpectedly

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read file_path from stdin JSON (preferred) or fallback to argument
INPUT="$(cat 2>/dev/null || true)"
FILE=""
if [ -n "$INPUT" ] && command -v jq &>/dev/null; then
    FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || true)
fi
FILE="${FILE:-${1:-}}"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    exit 0
fi

# Skip format for documentation and config files
if [[ "$FILE" == *".claude/contexts/"* ]] || \
   [[ "$FILE" == *".claude/plans/"* ]] || \
   [[ "$FILE" == *".claude/sessions/"* ]] || \
   [[ "$FILE" == */plans/* ]] || \
   [[ "$FILE" == *.md ]] || \
   [[ "$FILE" == /tmp/* ]] || \
   [[ "$FILE" == /home/vscode/.claude/* ]]; then
    exit 0
fi

# === Format only (fast: goimports ~100ms, ruff ~50ms, prettier ~200ms) ===
FMT_OUT=$("$SCRIPT_DIR/format.sh" "$FILE" 2>&1) || true

# Track edited file for on-stop-quality.sh batch processing
TRACKER="/tmp/.claude-edited-files"
echo "$FILE" >> "$TRACKER" 2>/dev/null || true

# Output additionalContext only if formatter reported issues
if [ -n "$FMT_OUT" ] && command -v jq &>/dev/null; then
    CONTEXT="Format issues in $FILE:\n${FMT_OUT:0:300}"
    jq -n -c \
        --arg ctx "$CONTEXT" \
        '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":$ctx}}' \
        2>/dev/null || true
fi

exit 0
