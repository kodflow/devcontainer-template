#!/usr/bin/env bash
# Shared setup for all bats tests

# Path to scripts under test
SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../.devcontainer/images/.claude/scripts"

# Call from each test file's setup()
common_setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export TEST_TMPDIR
}

# Call from each test file's teardown()
common_teardown() {
    [ -d "${TEST_TMPDIR:-}" ] && rm -rf "$TEST_TMPDIR"
}

# Source common.sh for tests that need it
load_common() {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
}

# Create a temporary .env file scoped to TEST_TMPDIR and export ENV_FILE
# pointing at it. Used by postCreate-* bats to isolate workspace state.
# Usage: set_env_file 'GIT_USER="kodflow"' 'GIT_EMAIL="x@y.com"'
set_env_file() {
    ENV_FILE="$TEST_TMPDIR/test.env"
    : > "$ENV_FILE"
    local line
    for line in "$@"; do
        printf '%s\n' "$line" >> "$ENV_FILE"
    done
    export ENV_FILE
}

# Source a single function definition from a shell file without executing
# the rest of the file. Useful when the file has top-level state mutations
# (init_steps, set -u, …) that bats setup() cannot tolerate.
# Usage: source_function_from "$path_to_sh" "function_name"
source_function_from() {
    local file="$1" func="$2"
    eval "$(awk -v f="$func" '
        $0 ~ "^"f"\\(\\) \\{" {p=1}
        p {print}
        p && /^\}$/ {exit}
    ' "$file")"
}
