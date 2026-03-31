#!/bin/bash
# ============================================================================
# worktree-remove.sh - Handle worktree removal
# Hook: WorktreeRemove (no matcher, always fires)
# Exit 0 = always (fail-open)
#
# Purpose: Clean up logs and resources when a worktree is removed.
# ============================================================================

set +e

INPUT="$(cat 2>/dev/null || true)"
WORKTREE_PATH=""
if command -v jq &>/dev/null && [ -n "$INPUT" ]; then
    WORKTREE_PATH=$(printf '%s' "$INPUT" | jq -r '.worktree_path // ""' 2>/dev/null || echo "")
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/workspace}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Log the removal
LOG_DIR="$PROJECT_DIR/.claude/logs"
mkdir -p "$LOG_DIR" 2>/dev/null || true

if command -v jq &>/dev/null && [ -n "$WORKTREE_PATH" ]; then
    jq -n -c \
        --arg ts "$TIMESTAMP" \
        --arg path "$WORKTREE_PATH" \
        '{timestamp:$ts,path:$path,event:"WorktreeRemove"}' \
        >> "$LOG_DIR/worktrees.jsonl" 2>/dev/null || true
fi

# Actually remove the worktree directory (with safety checks)
# Worktrees can be in ~/.claude/worktrees/ (custom hook) or .claude/worktrees/ (built-in)
WORKTREE_BASE="$HOME/.claude/worktrees"
BUILTIN_BASE="$PROJECT_DIR/.claude/worktrees"
if [ -n "$WORKTREE_PATH" ] && \
   { [[ "$WORKTREE_PATH" == "$WORKTREE_BASE/"* ]] || \
     [[ "$WORKTREE_PATH" == "$BUILTIN_BASE/"* ]] || \
     [[ "$WORKTREE_PATH" == "/tmp/claude-worktrees/"* ]]; } && \
   [ -d "$WORKTREE_PATH" ]; then
    # Prune git worktree reference first
    git -C "$PROJECT_DIR" worktree remove "$WORKTREE_PATH" --force 2>/dev/null || \
        rm -rf "$WORKTREE_PATH" 2>/dev/null || true
    git -C "$PROJECT_DIR" worktree prune 2>/dev/null || true
fi

exit 0
