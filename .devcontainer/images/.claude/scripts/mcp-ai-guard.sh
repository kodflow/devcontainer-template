#!/bin/bash
# ============================================================================
# mcp-ai-guard.sh - Block AI references in MCP PR/MR/comment creation
# PreToolUse hook for GitHub and GitLab MCP tools.
#
# Intercepts PR/MR creation, updates, and comments to prevent AI co-author
# references from leaking into public repositories.
#
# Matches same forbidden patterns as git-guard.sh for consistency.
#
# Exit 0 = allow, Exit 2 = block
# ============================================================================

set +e  # Fail-open: any unexpected error allows the tool to proceed

# === Read hook input ===
INPUT="$(cat 2>/dev/null || true)"
if [ -z "$INPUT" ] || ! command -v jq &>/dev/null; then
    exit 0
fi

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

# === Extract text fields based on tool ===
TEXT_TO_CHECK=""

case "$TOOL" in
    mcp__github__create_pull_request|mcp__github__update_pull_request)
        TITLE=$(printf '%s' "$INPUT" | jq -r '.tool_input.title // ""' 2>/dev/null || echo "")
        BODY=$(printf '%s' "$INPUT" | jq -r '.tool_input.body // ""' 2>/dev/null || echo "")
        TEXT_TO_CHECK="$TITLE $BODY"
        ;;
    mcp__github__add_issue_comment)
        BODY=$(printf '%s' "$INPUT" | jq -r '.tool_input.body // ""' 2>/dev/null || echo "")
        TEXT_TO_CHECK="$BODY"
        ;;
    mcp__gitlab__create_merge_request)
        TITLE=$(printf '%s' "$INPUT" | jq -r '.tool_input.title // ""' 2>/dev/null || echo "")
        DESC=$(printf '%s' "$INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null || echo "")
        TEXT_TO_CHECK="$TITLE $DESC"
        ;;
    mcp__gitlab__create_merge_request_note)
        BODY=$(printf '%s' "$INPUT" | jq -r '.tool_input.body // ""' 2>/dev/null || echo "")
        TEXT_TO_CHECK="$BODY"
        ;;
    *)
        # Unknown tool — allow (fail-open)
        exit 0
        ;;
esac

# Nothing to check
if [ -z "$TEXT_TO_CHECK" ]; then
    exit 0
fi

# === Check for forbidden AI patterns ===
TEXT_LOWER=$(echo "$TEXT_TO_CHECK" | tr '[:upper:]' '[:lower:]')

FORBIDDEN_PATTERNS=(
    "co-authored-by.*claude"
    "co-authored-by.*anthropic"
    "co-authored-by.*openai"
    "co-authored-by.*gpt"
    "co-authored-by.*ai"
    "co-authored-by.*copilot"
    "co-authored-by.*gemini"
    "co-authored-by.*llm"
    "generated.*with.*claude"
    "generated.*by.*claude"
    "generated.*with.*ai"
    "generated.*by.*ai"
    "generated.*with.*gpt"
    "generated.*by.*gpt"
    "ai.assisted"
    "ai-assisted"
    "🤖"
    "claude code"
    "claude-code"
    "anthropic"
    "openai"
    "chatgpt"
    "copilot"
)

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if echo "$TEXT_LOWER" | grep -qiE "$pattern"; then
        echo "═══════════════════════════════════════════════" >&2
        echo "  ❌ MCP BLOCKED - AI reference detected" >&2
        echo "═══════════════════════════════════════════════" >&2
        echo "" >&2
        echo "  Tool: $TOOL" >&2
        echo "  Forbidden pattern: $pattern" >&2
        echo "  Remove AI references from the text fields." >&2
        echo "" >&2
        echo "═══════════════════════════════════════════════" >&2
        exit 2
    fi
done

exit 0
