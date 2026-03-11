#!/bin/bash
# ============================================================================
# on-stop-quality.sh - Batch quality checks at end of Claude's turn
# Hook: Stop (all matchers)
# Exit 0 = always (fail-open)
#
# Purpose: Run lint + typecheck + test ONCE at end of turn,
# instead of after every Write/Edit. Deduplicates files and batches
# by project root to minimize compilation overhead.
#
# Security scanning is handled by security.sh in PreToolUse (Bash)
# at git commit time — not here.
#
# Reads from /tmp/.claude-edited-files (populated by post-edit.sh)
# and session.jsonl as fallback.
#
# Performance gain: ~88% CPU reduction for multi-edit sessions.
# Example: 10 Go edits: 163s → 19s
# ============================================================================

set +e  # Fail-open: never block

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/workspace}"

# Source common utilities
# shellcheck source=common.sh
[ -f "$SCRIPT_DIR/common.sh" ] && . "$SCRIPT_DIR/common.sh"

# === Collect edited files ===
TRACKER="/tmp/.claude-edited-files"
EDITED_FILES=""

# Primary: read from tracker file (populated by post-edit.sh)
if [ -f "$TRACKER" ]; then
    EDITED_FILES=$(sort -u "$TRACKER" 2>/dev/null || true)
    # Clean up tracker for next turn
    rm -f "$TRACKER" 2>/dev/null || true
fi

# Fallback: read from session.jsonl if tracker is empty
if [ -z "$EDITED_FILES" ]; then
    BRANCH=$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
    BRANCH_SAFE=$(printf '%s' "$BRANCH" | tr '/ ' '__')
    SESSION_LOG="$PROJECT_DIR/.claude/logs/$BRANCH_SAFE/session.jsonl"

    if [ -f "$SESSION_LOG" ] && command -v jq &>/dev/null; then
        EDITED_FILES=$(jq -r '
            select(.hook_event_name == "PostToolUse") |
            select(.tool_name == "Write" or .tool_name == "Edit") |
            .tool_input.file_path // empty
        ' "$SESSION_LOG" 2>/dev/null | sort -u)
    fi
fi

# Nothing edited? Nothing to do.
[ -z "$EDITED_FILES" ] && exit 0

# === Filter: keep only code files that still exist ===
FILTERED=""
while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ ! -f "$f" ] && continue
    case "$f" in
        *.md|*.json|*.yaml|*.yml|*.toml|*.lock|*.env|*.txt) continue ;;
        /tmp/*|*/.claude/*|*/node_modules/*|*/vendor/*|*/.git/*) continue ;;
        *) FILTERED="${FILTERED}${f}"$'\n' ;;
    esac
done <<< "$EDITED_FILES"
FILTERED=$(printf '%s' "$FILTERED" | sed '/^$/d')

[ -z "$FILTERED" ] && exit 0

# === Count files for reporting ===
FILE_COUNT=$(printf '%s\n' "$FILTERED" | wc -l)
FILE_COUNT="${FILE_COUNT## }"

echo "--- Quality Check ($FILE_COUNT files) ---" >&2

# === Group files by project root ===
# This avoids running golangci-lint/cargo check N times on the same package
declare -A PROJECT_FILES  # project_root -> space-separated file list

while IFS= read -r f; do
    [ -z "$f" ] && continue
    DIR=$(dirname "$f")
    ROOT=$(find_project_root "$DIR" "$DIR" 2>/dev/null)
    ROOT="${ROOT:-$DIR}"
    PROJECT_FILES["$ROOT"]+="$f "
done <<< "$FILTERED"

ISSUES=""

# === Run quality checks per project (deduplicated) ===
for root in "${!PROJECT_FILES[@]}"; do
    FILES="${PROJECT_FILES[$root]}"

    # --- 1. Lint: per file (but same project = same compilation cache) ---
    for f in $FILES; do
        LINT_OUT=$("$SCRIPT_DIR/lint.sh" "$f" 2>&1)
        LINT_RC=$?
        if [ $LINT_RC -ne 0 ] && [ -n "$LINT_OUT" ]; then
            ISSUES="${ISSUES}Lint(${f##*/}): ${LINT_OUT:0:300}\n"
        fi
    done

    # --- 2. Typecheck: ONCE per project root (not per file) ---
    FIRST_FILE=$(echo "$FILES" | awk '{print $1}')
    if [ -n "$FIRST_FILE" ]; then
        TYPE_OUT=$("$SCRIPT_DIR/typecheck.sh" "$FIRST_FILE" 2>&1)
        TYPE_RC=$?
        if [ $TYPE_RC -ne 0 ] && [ -n "$TYPE_OUT" ]; then
            ROOT_SHORT="${root#"$PROJECT_DIR"/}"
            ROOT_SHORT="${ROOT_SHORT:-$root}"
            ISSUES="${ISSUES}Typecheck($ROOT_SHORT): ${TYPE_OUT:0:300}\n"
        fi
    fi

    # --- 3. Test: per file (only test files, runner skips non-test) ---
    for f in $FILES; do
        TEST_OUT=$("$SCRIPT_DIR/test.sh" "$f" 2>&1)
        TEST_RC=$?
        if [ $TEST_RC -ne 0 ] && [ -n "$TEST_OUT" ]; then
            ISSUES="${ISSUES}Test(${f##*/}): ${TEST_OUT:0:300}\n"
        fi
    done
done

# === Report results ===
if [ -n "$ISSUES" ]; then
    echo "Issues found:" >&2
    printf '%b' "$ISSUES" | head -30 >&2
    echo "--- End Quality Check ---" >&2

    # Output additionalContext so Claude sees issues at next prompt
    if command -v jq &>/dev/null; then
        CONTEXT="Quality issues found in $FILE_COUNT edited files:\n$ISSUES\nPlease fix these issues."
        jq -n -c \
            --arg ctx "$CONTEXT" \
            '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":$ctx}}' \
            2>/dev/null || true
    fi
else
    echo "All checks passed." >&2
    echo "--- End Quality Check ---" >&2
fi

exit 0
