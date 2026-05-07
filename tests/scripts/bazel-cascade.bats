#!/usr/bin/env bats
# Tests for the Makefile → Bazel → go-test cascade in pre-commit-quality.sh
# (issue #350) and the Bazel detection helpers shared via common.sh.
#
# Discipline: NO test invokes the real make/go/bazel/bazelisk binaries.
# Every command dispatch is verified through PATH stubs that log to $TEST_LOG.

setup() {
    load '../helpers/setup'
    common_setup

    SCRIPTS_DIR="${BATS_TEST_DIRNAME}/../../.devcontainer/images/.claude/scripts"
    QUALITY_SCRIPT="$SCRIPTS_DIR/pre-commit-quality.sh"

    BIN="$TEST_TMPDIR/bin"
    mkdir -p "$BIN"
    export PATH="$BIN:$PATH"

    TEST_LOG="$TEST_TMPDIR/calls.log"
    : > "$TEST_LOG"
    export TEST_LOG

    REPO="$TEST_TMPDIR/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q -b main
    git -C "$REPO" config user.email "t@t.com"
    git -C "$REPO" config user.name "T"
    cat > "$REPO/go.mod" <<'EOF'
module example.com/test
go 1.21
EOF
    cat > "$REPO/main.go" <<'EOF'
package main
func main() {}
EOF
    git -C "$REPO" add . && git -C "$REPO" commit -q -m init
    git -C "$REPO" checkout -q -b feature
    echo "// edit" >> "$REPO/main.go"
    git -C "$REPO" add main.go
}

teardown() {
    common_teardown
}

# Stub a binary on PATH that logs every invocation and exits 0.
stub_cmd() {
    local name="$1"
    cat > "$BIN/$name" <<EOF
#!/usr/bin/env bash
echo "$name \$*" >> "\$TEST_LOG"
exit 0
EOF
    chmod +x "$BIN/$name"
}

run_quality() {
    bash -c "cd '$REPO' && CLAUDE_PROJECT_DIR='$REPO' bash '$QUALITY_SCRIPT' main 2>&1"
}

# ---------- helper unit tests ----------

@test "has_bazel_workspace detects MODULE.bazel" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    : > "$TEST_TMPDIR/MODULE.bazel"
    run has_bazel_workspace "$TEST_TMPDIR"
    [ "$status" -eq 0 ]
}

@test "has_bazel_workspace detects WORKSPACE" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    : > "$TEST_TMPDIR/WORKSPACE"
    run has_bazel_workspace "$TEST_TMPDIR"
    [ "$status" -eq 0 ]
}

@test "has_bazel_workspace detects WORKSPACE.bazel" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    : > "$TEST_TMPDIR/WORKSPACE.bazel"
    run has_bazel_workspace "$TEST_TMPDIR"
    [ "$status" -eq 0 ]
}

@test "has_bazel_workspace returns 1 when no marker" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    run has_bazel_workspace "$TEST_TMPDIR"
    [ "$status" -eq 1 ]
}

@test "bazel_bin prefers bazelisk over bazel" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    stub_cmd bazel
    stub_cmd bazelisk
    run bazel_bin
    [ "$status" -eq 0 ]
    [ "$output" = "bazelisk" ]
}

@test "bazel_bin falls back to bazel when bazelisk absent" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    stub_cmd bazel
    run bazel_bin
    [ "$status" -eq 0 ]
    [ "$output" = "bazel" ]
}

@test "bazel_bin returns 1 when neither present" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    # Disable PATH lookups via a clean env so neither binary is found.
    # Capture failure with `|| rc=$?` to bypass bats' set -e propagation.
    local rc=0
    PATH= bazel_bin >/dev/null 2>&1 || rc=$?
    [ "$rc" -ne 0 ]
}

@test "has_makefile_target rejects commented target" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    cat > "$TEST_TMPDIR/Makefile" <<'EOF'
# test:
EOF
    run has_makefile_target "test" "$TEST_TMPDIR"
    [ "$status" -eq 1 ]
}

@test "has_makefile_target rejects suffixed target name" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    cat > "$TEST_TMPDIR/Makefile" <<'EOF'
integration-test:
	@echo no
EOF
    run has_makefile_target "test" "$TEST_TMPDIR"
    [ "$status" -eq 1 ]
}

@test "has_makefile_target accepts target with deps" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    cat > "$TEST_TMPDIR/Makefile" <<'EOF'
test: deps
	@echo running
EOF
    run has_makefile_target "test" "$TEST_TMPDIR"
    [ "$status" -eq 0 ]
}

@test "has_makefile_target rejects variable assignment" {
    # shellcheck source=/dev/null
    source "$SCRIPTS_DIR/common.sh"
    cat > "$TEST_TMPDIR/Makefile" <<'EOF'
test:=foo
EOF
    run has_makefile_target "test" "$TEST_TMPDIR"
    [ "$status" -eq 1 ]
}

# ---------- quality-gate cascade integration ----------

@test "pre-commit-quality picks Makefile when test target exists" {
    cat > "$REPO/Makefile" <<'EOF'
test:
	@echo make test
EOF
    git -C "$REPO" add Makefile
    stub_cmd make
    stub_cmd go      # must NOT be invoked
    stub_cmd bazel   # must NOT be invoked

    run run_quality

    grep -q "^make test$" "$TEST_LOG"
    ! grep -q "^bazel " "$TEST_LOG"
    ! grep -q "^go test" "$TEST_LOG"
}

@test "pre-commit-quality picks Bazel when MODULE.bazel and no Makefile target" {
    : > "$REPO/MODULE.bazel"
    git -C "$REPO" add MODULE.bazel
    stub_cmd bazelisk
    stub_cmd bazel
    stub_cmd go      # must NOT be invoked

    run run_quality

    grep -q "^bazelisk test --test_output=errors " "$TEST_LOG"
    ! grep -q "^go test" "$TEST_LOG"
}

@test "pre-commit-quality maps changed package to //pkg/... label" {
    : > "$REPO/MODULE.bazel"
    mkdir -p "$REPO/pkg/foo"
    cat > "$REPO/pkg/foo/foo.go" <<'EOF'
package foo
EOF
    git -C "$REPO" add . && git -C "$REPO" commit -q -m base
    git -C "$REPO" checkout -q -B feature
    echo "// edit" >> "$REPO/pkg/foo/foo.go"
    git -C "$REPO" add pkg/foo/foo.go

    stub_cmd bazelisk

    run run_quality

    grep -q "//pkg/foo/\.\.\." "$TEST_LOG"
}

@test "pre-commit-quality falls back to go test -race -timeout 180s without -count=1" {
    # Neither Makefile target nor MODULE.bazel.
    stub_cmd go
    stub_cmd bazel  # present but no MODULE.bazel → not invoked

    run run_quality

    grep -qE "^go test -race -timeout 180s " "$TEST_LOG"
    ! grep -q -- "-count=1" "$TEST_LOG"
}

@test "pre-commit-quality prefers Makefile even when MODULE.bazel also present" {
    cat > "$REPO/Makefile" <<'EOF'
test:
	@echo make test
EOF
    : > "$REPO/MODULE.bazel"
    git -C "$REPO" add Makefile MODULE.bazel
    stub_cmd make
    stub_cmd bazelisk  # must NOT be invoked

    run run_quality

    grep -q "^make test$" "$TEST_LOG"
    ! grep -q "^bazelisk " "$TEST_LOG"
}
