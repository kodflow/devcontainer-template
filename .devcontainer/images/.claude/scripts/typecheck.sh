#!/bin/bash
# Type check files based on extension
# Usage: typecheck.sh <file_path>

set -e

FILE="$1"
if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    exit 0
fi

EXT="${FILE##*.}"
DIR=$(dirname "$FILE")

# Find project root (look for common config files)
find_project_root() {
    local current="$1"
    while [ "$current" != "/" ]; do
        if [ -f "$current/package.json" ] || \
           [ -f "$current/pyproject.toml" ] || \
           [ -f "$current/go.mod" ] || \
           [ -f "$current/Cargo.toml" ] || \
           [ -f "$current/pom.xml" ] || \
           [ -f "$current/build.sbt" ] || \
           [ -f "$current/mix.exs" ] || \
           [ -f "$current/pubspec.yaml" ]; then
            echo "$current"
            return
        fi
        current=$(dirname "$current")
    done
    echo "$DIR"
}

PROJECT_ROOT=$(find_project_root "$DIR")

case "$EXT" in
    # TypeScript - strict type checking
    ts|tsx)
        if command -v tsc &>/dev/null; then
            (cd "$PROJECT_ROOT" && tsc --noEmit 2>/dev/null) || true
        elif command -v npx &>/dev/null && [ -f "$PROJECT_ROOT/package.json" ]; then
            (cd "$PROJECT_ROOT" && npx tsc --noEmit 2>/dev/null) || true
        fi
        ;;

    # Python - mypy strict mode
    py)
        if command -v mypy &>/dev/null; then
            mypy --strict "$FILE" 2>/dev/null || true
        elif command -v pyright &>/dev/null; then
            pyright "$FILE" 2>/dev/null || true
        fi
        ;;

    # Go - go vet and staticcheck
    go)
        if command -v staticcheck &>/dev/null; then
            staticcheck "$FILE" 2>/dev/null || true
        fi
        if command -v go &>/dev/null; then
            go vet "$FILE" 2>/dev/null || true
        fi
        ;;

    # Rust - cargo check (faster than build)
    rs)
        [[ -f "$HOME/.cache/cargo/env" ]] && source "$HOME/.cache/cargo/env"
        if command -v cargo &>/dev/null && [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
            (cd "$PROJECT_ROOT" && cargo check 2>/dev/null) || true
        fi
        ;;

    # Java - compile check
    java)
        if command -v javac &>/dev/null; then
            javac -Xlint:all "$FILE" -d /tmp 2>/dev/null || true
        fi
        ;;

    # PHP - phpstan max level
    php)
        if command -v phpstan &>/dev/null; then
            phpstan analyse -l max "$FILE" 2>/dev/null || true
        elif command -v psalm &>/dev/null; then
            psalm "$FILE" 2>/dev/null || true
        fi
        ;;

    # Ruby - steep or sorbet
    rb)
        if command -v steep &>/dev/null && [ -f "$PROJECT_ROOT/Steepfile" ]; then
            (cd "$PROJECT_ROOT" && steep check 2>/dev/null) || true
        elif command -v srb &>/dev/null; then
            srb tc "$FILE" 2>/dev/null || true
        fi
        ;;

    # Scala - scalac check
    scala)
        if command -v scalac &>/dev/null; then
            scalac -Werror "$FILE" -d /tmp 2>/dev/null || true
        fi
        ;;

    # Elixir - dialyzer
    ex|exs)
        if command -v mix &>/dev/null && [ -f "$PROJECT_ROOT/mix.exs" ]; then
            (cd "$PROJECT_ROOT" && mix dialyzer 2>/dev/null) || true
        fi
        ;;

    # Dart - dart analyze with strict mode
    dart)
        if command -v dart &>/dev/null; then
            dart analyze --fatal-infos "$FILE" 2>/dev/null || true
        fi
        ;;

    # C++ - clang type checking
    cpp|cc|cxx|hpp)
        if command -v clang++ &>/dev/null; then
            clang++ -std=c++23 -fsyntax-only -Werror "$FILE" 2>/dev/null || true
        elif command -v g++ &>/dev/null; then
            g++ -std=c++23 -fsyntax-only -Werror "$FILE" 2>/dev/null || true
        fi
        ;;

    # C
    c|h)
        if command -v clang &>/dev/null; then
            clang -std=c23 -fsyntax-only -Werror "$FILE" 2>/dev/null || true
        elif command -v gcc &>/dev/null; then
            gcc -std=c23 -fsyntax-only -Werror "$FILE" 2>/dev/null || true
        fi
        ;;
esac

exit 0
