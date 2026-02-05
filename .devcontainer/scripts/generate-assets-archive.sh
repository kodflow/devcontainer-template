#!/bin/bash
# ============================================================================
# generate-assets-archive.sh - Creates tar.gz of Claude Code assets
# ============================================================================
# Run before commit to bundle all assets into a single downloadable archive.
# This reduces GitHub API calls from 20+ to 1 during installation.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_DIR="$REPO_ROOT/.devcontainer/images/.claude"
OUTPUT_FILE="$REPO_ROOT/.devcontainer/claude-assets.tar.gz"

# Check if source directory exists
if [ ! -d "$CLAUDE_DIR" ]; then
    echo "Error: Claude assets directory not found: $CLAUDE_DIR"
    exit 1
fi

echo "→ Generating Claude Code assets archive..."

# Create tar.gz with relative paths
# Contents: agents/, commands/, scripts/, docs/, settings.json
cd "$CLAUDE_DIR"

tar -czf "$OUTPUT_FILE" \
    --exclude='*.pyc' \
    --exclude='__pycache__' \
    --exclude='.DS_Store' \
    agents/ \
    commands/ \
    scripts/ \
    docs/ \
    settings.json \
    2>/dev/null || {
        echo "Error: Failed to create archive"
        exit 1
    }

# Show archive info
ARCHIVE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
FILE_COUNT=$(tar -tzf "$OUTPUT_FILE" | wc -l)

echo "  ✓ Archive created: $OUTPUT_FILE"
echo "  ✓ Size: $ARCHIVE_SIZE"
echo "  ✓ Files: $FILE_COUNT"

# Add to git staging if in a git repo
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$REPO_ROOT" add "$OUTPUT_FILE"
    echo "  ✓ Added to git staging"
fi

echo "→ Done"
