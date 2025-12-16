#!/bin/bash
# Lint files based on extension
# Usage: lint.sh <file_path>

set -e

FILE="$1"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    exit 0
fi

EXT="${FILE##*.}"
DIR=$(dirname "$FILE")

case "$EXT" in
    # JavaScript/TypeScript
    js|jsx|ts|tsx|mjs|cjs)
        if command -v eslint &>/dev/null; then
            eslint --fix "$FILE" 2>/dev/null || true
        elif command -v npx &>/dev/null && [ -f "package.json" ]; then
            npx eslint --fix "$FILE" 2>/dev/null || true
        fi
        ;;

    # Python
    py)
        if command -v ruff &>/dev/null; then
            ruff check --fix "$FILE" 2>/dev/null || true
        elif command -v pylint &>/dev/null; then
            pylint --errors-only "$FILE" 2>/dev/null || true
        fi
        if command -v mypy &>/dev/null; then
            mypy --ignore-missing-imports "$FILE" 2>/dev/null || true
        fi
        ;;

    # Go
    go)
        if command -v golangci-lint &>/dev/null; then
            golangci-lint run "$FILE" 2>/dev/null || true
        elif command -v go &>/dev/null; then
            go vet "$FILE" 2>/dev/null || true
        fi
        ;;

    # Rust
    rs)
        if command -v cargo &>/dev/null; then
            # Run clippy on the whole project (can't target single file easily)
            (cd "$DIR" && cargo clippy --fix --allow-dirty 2>/dev/null) || true
        fi
        ;;

    # Shell
    sh|bash)
        if command -v shellcheck &>/dev/null; then
            shellcheck "$FILE" 2>/dev/null || true
        fi
        ;;

    # Dockerfile
    Dockerfile*)
        if command -v hadolint &>/dev/null; then
            hadolint "$FILE" 2>/dev/null || true
        fi
        ;;

    # YAML (for k8s, docker-compose, etc.)
    yml|yaml)
        if command -v yamllint &>/dev/null; then
            yamllint -d relaxed "$FILE" 2>/dev/null || true
        fi
        ;;

    # Terraform
    tf)
        if command -v terraform &>/dev/null; then
            terraform validate 2>/dev/null || true
        fi
        if command -v tflint &>/dev/null; then
            tflint "$FILE" 2>/dev/null || true
        fi
        ;;
esac

exit 0
