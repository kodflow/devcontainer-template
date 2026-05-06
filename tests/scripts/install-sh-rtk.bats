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
# We extract the function via sed to avoid running the full install entrypoint.
run_install_rtk() {
    local arch="$1" extra="${2:-}"
    bash -c "
        set -euo pipefail
        export HOME_DIR='$HOME_DIR'
        export ARCH='$arch'
        export OS='linux'
        # Strip /usr/local/bin from PATH so 'command -v rtk' on the test host
        # (where rtk is pre-installed) returns false and the install path runs.
        # Keeps /usr/bin and /bin so curl/grep/sed/tar still resolve.
        export PATH='/usr/bin:/bin'
        $extra
        ok() { echo \"\$@\"; }; info() { echo \"\$@\"; }; warn() { echo \"\$@\"; }; log() { echo \"\$@\"; }
        sed -n '651,744p' '$SCRIPT' > /tmp/rtk-only-\$\$.sh
        echo 'tool_count=0' >> /tmp/rtk-only-\$\$.sh
        echo 'download_tools' >> /tmp/rtk-only-\$\$.sh
        bash /tmp/rtk-only-\$\$.sh
        rc=\$?
        rm -f /tmp/rtk-only-\$\$.sh
        exit \$rc
    "
}

# === amd64 + arm64: simulated download failure must propagate exit-non-zero ===

@test "amd64: simulated curl failure exits non-zero (build hard-fail)" {
    if ! command -v curl >/dev/null 2>&1; then
        skip "curl not available"
    fi
    run run_install_rtk amd64 "RTK_INSTALL_TEST_FAIL=1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"download/extract failed"* ]]
}

@test "arm64: simulated curl failure exits non-zero (build hard-fail)" {
    if ! command -v curl >/dev/null 2>&1; then
        skip "curl not available"
    fi
    run run_install_rtk arm64 "RTK_INSTALL_TEST_FAIL=1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"download/extract failed"* ]]
}

# === Unsupported arch (devcontainer expects amd64/arm64): hard-fail too ===

@test "unsupported arch (riscv64): hard-fail with explicit message" {
    run run_install_rtk riscv64 ""
    [ "$status" -ne 0 ]
    [[ "$output" == *"unsupported architecture"* ]]
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
    run sed -n '651,744p' "${BATS_TEST_DIRNAME}/../../.devcontainer/install.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"(optional"* ]]
}
