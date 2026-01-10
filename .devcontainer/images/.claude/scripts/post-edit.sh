#!/bin/bash
# Combined post-edit hook: format + imports + lint
# Usage: post-edit.sh <file_path>

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$1"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    exit 0
fi

# Skip format/lint for documentation and config files
if [[ "$FILE" == *".claude/plans/"* ]] || \
   [[ "$FILE" == *".claude/sessions/"* ]] || \
   [[ "$FILE" == */plans/* ]] || \
   [[ "$FILE" == *.md ]] || \
   [[ "$FILE" == /tmp/* ]] || \
   [[ "$FILE" == /home/vscode/.claude/* ]]; then
    exit 0
fi

# === Format/Lint pipeline ===

# 1. Format
"$SCRIPT_DIR/format.sh" "$FILE"

# 2. Sort imports
"$SCRIPT_DIR/imports.sh" "$FILE"

# 3. Lint (with auto-fix)
"$SCRIPT_DIR/lint.sh" "$FILE"

exit 0
