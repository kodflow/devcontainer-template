#!/usr/bin/env bats
# Tests for install.sh rtk install path.
# Layer 2 of plan 2026-05-06-rtk-mandatory-install-and-claude-memory.
#
# RTK install is MANDATORY in this Linux devcontainer template. Any failure
# of the install path must propagate non-zero to the install.sh entrypoint
# so the build / setup is rejected immediately.

setup() {
    load '../helpers/setup'
    common_setup

    SCRIPT="${BATS_TEST_DIRNAME}/../../.devcontainer/install.sh"
    export HOME_DIR="$TEST_TMPDIR/sandbox-home"
    mkdir -p "$HOME_DIR/.local/bin"
}

teardown() {
    common_teardown
}

# Helper: run only the rtk-install slice of download_tools() with controlled env.
# We extract the function via sed and write a runner script to a temp file —
# this avoids the complex quoting / line-numbering issues that can surface
# when bats wraps `bash -c "..."` invocations on different runners.
run_install_rtk() {
    local arch="$1" extra="${2:-}"
    local runner="$TEST_TMPDIR/rtk-runner-$$.sh"
    {
        echo "#!/bin/bash"
        echo "export HOME_DIR='$HOME_DIR'"
        echo "export ARCH='$arch'"
        echo "export OS=linux"
        # /usr/local/bin stripped → 'command -v rtk' fails → install path runs.
        echo "export PATH=/usr/bin:/bin"
        if [ -n "$extra" ]; then
            echo "export $extra"
        fi
        # Stub log helpers used by install.sh.
        echo 'ok()   { echo "$@"; }'
        echo 'info() { echo "$@"; }'
        echo 'warn() { echo "$@"; }'
        echo 'log()  { echo "$@"; }'
        # Slice the download_tools function and call it.
        sed -n '651,744p' "$SCRIPT"
        echo "tool_count=0"
        echo "download_tools"
    } > "$runner"
    chmod +x "$runner"
    # Merge stderr into stdout: install.sh writes user-facing failures to
    # >&2 by design, but bats `run` only captures stdout.
    bash "$runner" 2>&1
    local rc=$?
    rm -f "$runner"
    return $rc
}

# === amd64 + arm64: simulated download failure must propagate exit-non-zero ===

@test "amd64: simulated curl failure exits non-zero (build hard-fail)" {
    if ! command -v curl >/dev/null 2>&1; then
        skip "curl not available"
    fi
    run run_install_rtk amd64 "RTK_INSTALL_TEST_FAIL=1"
    [ "$status" -ne 0 ]
    if [[ "$output" != *"download/extract failed"* ]] && \
       [[ "$output" != *"required"* ]]; then
        echo "DEBUG output: $output" >&2
        false
    fi
}

@test "arm64: simulated curl failure exits non-zero (build hard-fail)" {
    if ! command -v curl >/dev/null 2>&1; then
        skip "curl not available"
    fi
    run run_install_rtk arm64 "RTK_INSTALL_TEST_FAIL=1"
    [ "$status" -ne 0 ]
    if [[ "$output" != *"download/extract failed"* ]] && \
       [[ "$output" != *"required"* ]]; then
        echo "DEBUG output: $output" >&2
        false
    fi
}

# === Unsupported arch (devcontainer expects amd64/arm64): hard-fail too ===

@test "unsupported arch (riscv64): hard-fail with explicit message" {
    run run_install_rtk riscv64 ""
    [ "$status" -ne 0 ]
    if [[ "$output" != *"unsupported architecture"* ]] && \
       [[ "$output" != *"unsupported"* ]]; then
        echo "DEBUG output: $output" >&2
        false
    fi
}

# === Code-path invariants (lock the contract against future regressions) ===

@test "code path: download failure calls return 1 with 'required' message" {
    grep -E 'rtk: download/extract failed.*required' "${BATS_TEST_DIRNAME}/../../.devcontainer/install.sh"
}

@test "code path: tag-resolution failure calls return 1 with 'required' message" {
    grep -E 'rtk: failed to resolve latest version.*required' "${BATS_TEST_DIRNAME}/../../.devcontainer/install.sh"
}

@test "code path: RTK_INSTALL_TEST_FAIL hook is wired" {
    grep -F 'RTK_INSTALL_TEST_FAIL' "${BATS_TEST_DIRNAME}/../../.devcontainer/install.sh"
}

@test "code path: no '(optional)' fallbacks remain in the rtk install block" {
    # The previous fail-open behavior is gone. Any '(optional)' marker in the
    # rtk slice would be a regression toward the old silent-degradation path.
    # Narrow the slice to JUST the rtk-install block (656..712); status-line
    # at 713+ is intentionally still advisory and lives outside this contract.
    run sed -n '656,712p' "${BATS_TEST_DIRNAME}/../../.devcontainer/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"(optional"* ]]
}
