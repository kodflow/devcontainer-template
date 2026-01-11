#!/bin/bash
# ============================================================================
# post-compact.sh - Restore critical context after context compaction
# SessionStart hook for "compact" matcher
# Exit 0 = success, outputs additionalContext to inject into Claude's context
# ============================================================================

set -euo pipefail

# Read hook input (best-effort, resilient to empty/malformed input)
INPUT="$(cat || true)"

# Parse source field (graceful if jq unavailable or input malformed)
SOURCE=""
if command -v jq >/dev/null 2>&1; then
    SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // ""' 2>/dev/null || true)"
fi

# Only act on compact events
if [[ "$SOURCE" != "compact" ]]; then
    exit 0
fi

# Output critical reminders as additionalContext
# This gets injected into Claude's context after compaction
cat << 'CONTEXT'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "## POST-COMPACTION REMINDERS\n\n**CRITICAL RULES (from CLAUDE.md):**\n\n1. **GIT WORKFLOW**: NEVER commit directly to main/master. Always use `/git --commit` which creates a branch + PR.\n\n2. **MCP-FIRST RULE**: Use MCP tools before CLI (mcp__github__*, mcp__grepai__*, mcp__codacy__*).\n\n3. **SKILL INVOCATION**: When user invokes a skill (e.g., `/git --commit`), use the Skill tool to load and follow the full workflow.\n\n4. **SAFEGUARDS**: Never delete files in .claude/ or .devcontainer/ without explicit approval.\n\n**RELOAD if needed:**\n- Read /workspace/CLAUDE.md for project rules\n- Read specific command file from .claude/commands/ if using a skill\n\n**Context was compacted. Verify current task state before continuing.**"
  }
}
CONTEXT

exit 0
