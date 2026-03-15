#!/bin/bash
# pre-validate.sh - Validate modifications to protected files
# Usage: pre-validate.sh <file_path>
# Exit 0 = allow, Exit 2 = block

set -uo pipefail
# Note: Removed -e (errexit) to fail-open on unexpected errors

# Read file_path from stdin JSON (preferred) or fallback to argument
INPUT="$(cat 2>/dev/null || true)"
FILE=""
if [ -n "$INPUT" ] && command -v jq &>/dev/null; then
    FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || true)
fi
FILE="${FILE:-${1:-}}"

if [ -z "$FILE" ]; then
    exit 0
fi

# Configuration file paths
PROTECTED_PATHS_FILE="/workspace/.claude/protected-paths.yml"
PROTECTED_PATHS_DEFAULT="$HOME/.claude/protected-paths.yml"

# Use yq if available, otherwise fall back to hardcoded patterns
USE_YQ=false
if command -v yq &>/dev/null; then
    if [[ -f "$PROTECTED_PATHS_FILE" ]]; then
        USE_YQ=true
        CONFIG_FILE="$PROTECTED_PATHS_FILE"
    elif [[ -f "$PROTECTED_PATHS_DEFAULT" ]]; then
        USE_YQ=true
        CONFIG_FILE="$PROTECTED_PATHS_DEFAULT"
    fi
fi

# Default protected patterns (fallback) - only truly dangerous paths
PROTECTED_PATTERNS=(
    "node_modules/"
    ".git/"
    "vendor/"
    "dist/"
    "build/"
    ".env"
    "*.lock"
    "package-lock.json"
    "yarn.lock"
    "pnpm-lock.yaml"
    "Cargo.lock"
    "poetry.lock"
    "go.sum"
)

# Exceptions (always allowed)
EXCEPTIONS=(
    "*.md"
    "README*"
    "CHANGELOG*"
    ".claude/contexts/"
    ".claude/plans/"
    ".claude/sessions/"
)

# Function to check if the file matches an exception
is_exception() {
    local file="$1"
    for pattern in "${EXCEPTIONS[@]}"; do
        # Use bash pattern matching
        if [[ "$file" == *"$pattern"* ]] || [[ "$file" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Check exceptions first
if is_exception "$FILE"; then
    exit 0
fi

# === Verification with yq if available ===
if [[ "$USE_YQ" == "true" ]]; then
    # Read protected patterns from the YAML file
    # mikefarah/yq syntax (no -r flag needed, raw output is default)
    YAML_PATTERNS=$(yq '.protected[]' "$CONFIG_FILE" 2>/dev/null || echo "")

    for pattern in $YAML_PATTERNS; do
        [[ -z "$pattern" ]] && continue

        # Check if the file matches the pattern
        if [[ "$FILE" == *"$pattern"* ]] || [[ "$FILE" == $pattern ]]; then
            REASON="Protected file: $FILE (pattern: $pattern)"
            echo "🚫 $REASON" >&2
            if command -v jq &>/dev/null; then
                jq -n --arg reason "$REASON" \
                    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$reason}}'
                exit 0
            fi
            exit 2
        fi
    done
else
    # Fallback: use hardcoded patterns
    for pattern in "${PROTECTED_PATTERNS[@]}"; do
        if [[ "$FILE" == *"$pattern"* ]]; then
            REASON="Protected file: $FILE (pattern: $pattern)"
            echo "🚫 $REASON" >&2
            if command -v jq &>/dev/null; then
                jq -n --arg reason "$REASON" \
                    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$reason}}'
                exit 0
            fi
            exit 2
        fi
    done
fi


exit 0
