#!/bin/bash
# bash-validate.sh - PreToolUse hook pour Bash
# Basic command validation for dangerous operations
# Exit 0 = allowed, Exit 2 = blocked

set -euo pipefail

# Read input JSON from Claude
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only process Bash commands
if [[ "$TOOL" != "Bash" ]]; then
    exit 0
fi

# === DANGEROUS COMMANDS (always blocked without explicit approval) ===
DANGEROUS_PATTERNS=(
    # Force push
    "git push --force"
    "git push -f"
    # Hard reset
    "git reset --hard"
    # Clean untracked files
    "git clean -fd"
    "git clean -f"
    # Destructive filesystem operations
    "rm -rf /"
    "rm -rf /*"
    "rm -rf ~"
    "rm -rf $HOME"
    # System-level changes
    "chmod -R 777"
    "chown -R"
    # Database drops
    "DROP DATABASE"
    "DROP TABLE"
    "TRUNCATE"
)

# Check for dangerous patterns
for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$pattern"* ]]; then
        echo "═══════════════════════════════════════════════"
        echo "  ⚠️  DANGEROUS COMMAND DETECTED"
        echo "═══════════════════════════════════════════════"
        echo ""
        echo "  Pattern: $pattern"
        echo ""
        echo "  Command:"
        echo "    ${COMMAND:0:200}"
        echo ""
        echo "  This command requires explicit user approval."
        echo "  If you intended this, re-run with confirmation."
        echo ""
        echo "═══════════════════════════════════════════════"
        exit 2
    fi
done

# Command allowed
exit 0
