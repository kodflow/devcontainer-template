#!/bin/bash
# Sort and organize imports based on extension
# Usage: imports.sh <file_path>

set -e

FILE="$1"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    exit 0
fi

EXT="${FILE##*.}"

case "$EXT" in
    # JavaScript/TypeScript
    js|jsx|ts|tsx|mjs|cjs)
        # eslint-plugin-import or prettier-plugin-organize-imports
        if command -v eslint &>/dev/null; then
            eslint --fix --rule 'import/order: error' "$FILE" 2>/dev/null || true
        elif command -v npx &>/dev/null; then
            npx eslint --fix --rule 'import/order: error' "$FILE" 2>/dev/null || true
        fi
        ;;

    # Python
    py)
        if command -v isort &>/dev/null; then
            isort --quiet "$FILE" 2>/dev/null || true
        elif command -v ruff &>/dev/null; then
            ruff check --select I --fix "$FILE" 2>/dev/null || true
        fi
        ;;

    # Go
    go)
        if command -v goimports &>/dev/null; then
            goimports -w "$FILE" 2>/dev/null || true
        elif command -v gofmt &>/dev/null; then
            # gofmt doesn't sort imports but at least formats
            gofmt -w "$FILE" 2>/dev/null || true
        fi
        ;;

    # Rust
    rs)
        # rustfmt handles imports automatically
        if command -v rustfmt &>/dev/null; then
            rustfmt "$FILE" 2>/dev/null || true
        fi
        ;;

    # Java
    java)
        if command -v google-java-format &>/dev/null; then
            google-java-format --replace "$FILE" 2>/dev/null || true
        fi
        ;;
esac

exit 0
