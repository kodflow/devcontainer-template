#!/bin/bash
# Auto-format files based on extension
# Usage: format.sh <file_path>

set -e

FILE="$1"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    exit 0
fi

EXT="${FILE##*.}"

case "$EXT" in
    # JavaScript/TypeScript
    js|jsx|ts|tsx|mjs|cjs)
        if command -v prettier &>/dev/null; then
            prettier --write "$FILE" 2>/dev/null || true
        elif command -v npx &>/dev/null; then
            npx prettier --write "$FILE" 2>/dev/null || true
        fi
        ;;

    # Python
    py)
        if command -v black &>/dev/null; then
            black --quiet "$FILE" 2>/dev/null || true
        fi
        if command -v ruff &>/dev/null; then
            ruff format "$FILE" 2>/dev/null || true
        fi
        ;;

    # Go
    go)
        if command -v gofmt &>/dev/null; then
            gofmt -w "$FILE" 2>/dev/null || true
        fi
        ;;

    # Rust
    rs)
        if command -v rustfmt &>/dev/null; then
            rustfmt "$FILE" 2>/dev/null || true
        fi
        ;;

    # JSON
    json)
        if command -v prettier &>/dev/null; then
            prettier --write "$FILE" 2>/dev/null || true
        elif command -v jq &>/dev/null; then
            TMP=$(mktemp)
            jq '.' "$FILE" > "$TMP" 2>/dev/null && mv "$TMP" "$FILE" || rm -f "$TMP"
        fi
        ;;

    # YAML
    yml|yaml)
        if command -v prettier &>/dev/null; then
            prettier --write "$FILE" 2>/dev/null || true
        fi
        ;;

    # Markdown
    md)
        if command -v prettier &>/dev/null; then
            prettier --write "$FILE" 2>/dev/null || true
        fi
        ;;

    # Terraform
    tf)
        if command -v terraform &>/dev/null; then
            terraform fmt "$FILE" 2>/dev/null || true
        fi
        ;;

    # Shell
    sh|bash)
        if command -v shfmt &>/dev/null; then
            shfmt -w "$FILE" 2>/dev/null || true
        fi
        ;;
esac

exit 0
