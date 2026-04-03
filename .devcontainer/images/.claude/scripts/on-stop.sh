#!/bin/bash
# ============================================================================
# on-stop.sh - Session stop notification and summary
# Hook: Stop (all matchers)
# Exit 0 = always (fail-open)
#
# Purpose: Container-friendly notification when Claude stops.
# - Terminal bell (works in all terminals)
# - Brief session summary from log.sh JSONL data
# ============================================================================

set +e  # Fail-open: never block

# Read hook input for stop_hook_active guard
INPUT="$(cat 2>/dev/null || true)"
if [ -n "$INPUT" ] && command -v jq &>/dev/null; then
    STOP_ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
    if [ "$STOP_ACTIVE" = "true" ]; then
        exit 0  # Prevent infinite loop
    fi
fi

# Terminal bell - works in containers, unlike notify-send
printf '\a'

# === ktn-linter: session-level validation ===
# Scans all packages touched during the session. Never blocks stop.
KTN_PORT="${KTN_LINTER_PORT:-7717}"
if command -v curl &>/dev/null; then
    KTN_PAYLOAD="${INPUT:-{\}}"
    if command -v jq &>/dev/null; then
        KTN_PAYLOAD=$(printf '%s' "${INPUT:-{\}}" | jq -c --arg sid "${CLAUDE_SESSION_ID:-default}" '. + {"session_id": $sid}' 2>/dev/null || echo "${INPUT:-{\}}")
    fi
    KTN_RESP=$(curl -sf --max-time 28 \
        -H "Content-Type: application/json" \
        -d "$KTN_PAYLOAD" \
        "http://localhost:${KTN_PORT}/hooks/stop" 2>/dev/null) || true
    if [ -n "$KTN_RESP" ] && [ "$KTN_RESP" != "{}" ] && [ "$KTN_RESP" != "null" ] && command -v jq &>/dev/null; then
        KTN_SUMMARY=$(printf '%s' "$KTN_RESP" | jq -r '.summary // .message // empty' 2>/dev/null || true)
        if [ -n "$KTN_SUMMARY" ]; then
            echo "--- ktn-linter Session Report ---" >&2
            echo "$KTN_SUMMARY" >&2
            echo "--- End Report ---" >&2
        fi
        if printf '%s' "$KTN_RESP" | jq -e '.hookSpecificOutput' &>/dev/null; then
            printf '%s' "$KTN_RESP"
        fi
    fi
fi

# Extract last_assistant_message for summary
LAST_MSG_LEN=0
if [ -n "$INPUT" ] && command -v jq &>/dev/null; then
    LAST_MSG_LEN=$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // "" | length' 2>/dev/null || echo "0")
fi

# Generate brief session summary from log data
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/workspace}"
BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
BRANCH_SAFE=$(printf '%s' "$BRANCH" | tr '/ ' '__')
SESSION_LOG="$PROJECT_DIR/.claude/logs/$BRANCH_SAFE/session.jsonl"

if [ -f "$SESSION_LOG" ] && command -v jq &>/dev/null; then
    TOTAL=$(wc -l < "$SESSION_LOG" 2>/dev/null || echo "0")
    TOOLS=$(jq -r '.tool_name // empty' "$SESSION_LOG" 2>/dev/null | sort | uniq -c | sort -rn | head -5 || true)
    ERRORS=$(jq -r 'select(.tool_response.return_code != null and .tool_response.return_code != 0) | .tool_name' "$SESSION_LOG" 2>/dev/null | wc -l || echo "0")

    echo "--- Session Summary ---" >&2
    echo "Branch: $BRANCH" >&2
    echo "Total events: $TOTAL" >&2
    echo "Errors: $ERRORS" >&2
    if [ "$LAST_MSG_LEN" -gt 0 ] 2>/dev/null; then
        echo "Last message length: $LAST_MSG_LEN chars" >&2
    fi
    if [ -n "$TOOLS" ]; then
        echo "Top tools:" >&2
        echo "$TOOLS" | head -5 | sed 's/^/  /' >&2
    fi
    echo "--- End Summary ---" >&2
fi

exit 0
