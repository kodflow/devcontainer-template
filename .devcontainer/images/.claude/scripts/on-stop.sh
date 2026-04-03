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

# Read hook input
INPUT="$(cat 2>/dev/null || true)"

# Extract session_id from hook JSON input (unique per Claude session/worktree)
# Sanitize to [A-Za-z0-9_-] to prevent path traversal in /tmp file paths
SESSION_ID="default"
if [ -n "$INPUT" ] && command -v jq &>/dev/null; then
    RAW_SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "default"' 2>/dev/null || echo "default")
    SESSION_ID=$(printf '%s' "$RAW_SID" | tr -cd 'A-Za-z0-9_-')
    [ -z "$SESSION_ID" ] && SESSION_ID="default"
fi

# === Circuit-breaker: force stop after 3 consecutive attempts ===
# Prevents infinite loop when ktn-linter (or any hook) keeps blocking stop.
# Counter resets: on successful stop, on new user prompt, or after 5 min stale.
# Session-scoped: each session/worktree has its own counter file.
STOP_COUNTER_FILE="/tmp/.claude-stop-counter-${SESSION_ID}"
STOP_COUNT=0
MAX_STOP_ATTEMPTS=3
STALE_SECONDS=300  # 5 minutes

# Atomic read-increment-write with flock to prevent race conditions.
# If lock cannot be acquired within 1s, skip increment (fail-open).
{
    if flock -w 1 9; then
        if [ -f "$STOP_COUNTER_FILE" ]; then
            FILE_AGE=$(( $(date +%s) - $(stat -c %Y "$STOP_COUNTER_FILE" 2>/dev/null || echo "0") ))
            if [ "$FILE_AGE" -gt "$STALE_SECONDS" ]; then
                rm -f "$STOP_COUNTER_FILE"
            else
                STOP_COUNT=$(cat "$STOP_COUNTER_FILE" 2>/dev/null || echo "0")
            fi
        fi
        STOP_COUNT=$((STOP_COUNT + 1))
        printf '%d' "$STOP_COUNT" > "$STOP_COUNTER_FILE" 2>/dev/null || true
    fi
} 9>"${STOP_COUNTER_FILE}.lock"

# If we've tried too many times, force clean exit (skip all hooks)
if [ "$STOP_COUNT" -ge "$MAX_STOP_ATTEMPTS" ]; then
    echo -e "\033[1;31m⚠️  CIRCUIT-BREAKER: stop hook looped ${STOP_COUNT}/${MAX_STOP_ATTEMPTS} — forcing exit to break infinite loop\033[0m" >&2
    rm -f "$STOP_COUNTER_FILE" "${STOP_COUNTER_FILE}.lock"
    exit 0
fi

# Tell the AI where we are in the circuit-breaker sequence
# so it can decide to wait instead of retrying immediately
if [ "$STOP_COUNT" -gt 1 ]; then
    echo -e "\033[1;33m⚠️  Stop attempt ${STOP_COUNT}/${MAX_STOP_ATTEMPTS} — circuit-breaker will force exit at attempt ${MAX_STOP_ATTEMPTS}\033[0m" >&2
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
        # Forward as additionalContext only — NEVER forward permissionDecision
        # on stop hook (stop must never be blocked by linter state)
        if printf '%s' "$KTN_RESP" | jq -e '.hookSpecificOutput' &>/dev/null; then
            printf '%s' "$KTN_RESP" | jq -c '
                if .hookSpecificOutput.permissionDecision then
                    .hookSpecificOutput |= del(.permissionDecision, .permissionDecisionReason)
                    | if .hookSpecificOutput.additionalContext then . else empty end
                else .
                end
            ' 2>/dev/null || true
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

# NOTE: Do NOT reset the circuit-breaker counter here.
# The script always reaches exit 0 (even when ktn-linter blocks via JSON output),
# so resetting here would prevent the counter from ever accumulating.
# Counter is reset by: user-prompt-submit.sh (new prompt), circuit-breaker trigger
# (line 54), or stale timeout (5 min).

exit 0
