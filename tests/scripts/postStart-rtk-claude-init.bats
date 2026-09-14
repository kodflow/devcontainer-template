#!/usr/bin/env bats
# Tests for step_rtk_claude_init in postStart.sh.
#
# Since the lifecycle hooks moved to the kodflow-hooks plugin, the PreToolUse
# rewrite is the plugin's job. This step therefore runs `rtk init -g --no-patch`
# (RTK.md + the @RTK.md import only) and REMOVES any rtk hook a previous image
# or a manual `rtk init -g` left in settings.json — two rewriters on the same
# event would run in parallel and rewrite the same command twice.
#
# Acceptance: idempotent (re-runs preserve user content byte-for-byte),
# leaves the file structure intact when rtk is missing.

setup() {
    load '../helpers/setup'
    common_setup

    SCRIPT="${BATS_TEST_DIRNAME}/../../.devcontainer/images/hooks/lifecycle/postStart.sh"

    # Sandbox HOME so writes don't touch the developer's real ~/.claude.
    export TEST_HOME="$TEST_TMPDIR/home"
    mkdir -p "$TEST_HOME/.claude"
}

teardown() {
    common_teardown
}

extract_step_fn() {
    awk '/^step_rtk_claude_init\(\) \{/,/^\}/' "$SCRIPT"
}

run_step() {
    bash -c "
        set -uo pipefail
        export HOME='$TEST_HOME'
        log_info()    { printf '[INFO] %s\n' \"\$*\"; }
        log_warning() { printf '[WARN] %s\n' \"\$*\"; }
        $(extract_step_fn)
        step_rtk_claude_init
    "
}

# === Happy path: fresh ~/.claude/ → RTK.md + import, and no rtk hook ===

@test "step_rtk_claude_init: fresh sandbox produces RTK.md + @RTK.md import, and no rtk hook in settings.json" {
    if ! command -v rtk >/dev/null 2>&1; then
        skip "rtk binary required"
    fi
    run run_step
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.claude/RTK.md" ]
    [ -f "$TEST_HOME/.claude/CLAUDE.md" ]
    grep -q '^@RTK.md' "$TEST_HOME/.claude/CLAUDE.md"
    # The rewrite belongs to kodflow-hooks; settings.json must not carry a
    # second one.
    if [ -f "$TEST_HOME/.claude/settings.json" ]; then
        ! grep -qE '"command": *"[^"]*rtk[^"]*"' "$TEST_HOME/.claude/settings.json"
    fi
}

# === A stale rtk hook left by an older image is removed, other hooks kept ===

@test "step_rtk_claude_init: removes a pre-existing rtk hook entry and keeps the others" {
    if ! command -v rtk >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        skip "rtk and jq required"
    fi
    cat > "$TEST_HOME/.claude/settings.json" <<'EOF'
{
  "permissions": {"allow": ["Bash(ls:*)"]},
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "rtk hook claude"}]},
      {"matcher": "Write", "hooks": [{"type": "command", "command": "/opt/other-hook.sh"}]}
    ]
  }
}
EOF
    run run_step
    [ "$status" -eq 0 ]
    ! grep -q 'rtk hook claude' "$TEST_HOME/.claude/settings.json"
    grep -q '/opt/other-hook.sh' "$TEST_HOME/.claude/settings.json"
    jq -e '.permissions.allow == ["Bash(ls:*)"]' "$TEST_HOME/.claude/settings.json" >/dev/null
}

# === Idempotency: re-running leaves the file byte-identical ===

@test "step_rtk_claude_init: idempotent across re-runs (CLAUDE.md byte-identical)" {
    if ! command -v rtk >/dev/null 2>&1; then
        skip "rtk binary required"
    fi
    run_step >/dev/null 2>&1
    md5_first=$(md5sum "$TEST_HOME/.claude/CLAUDE.md" | cut -d' ' -f1)
    run_step >/dev/null 2>&1
    md5_second=$(md5sum "$TEST_HOME/.claude/CLAUDE.md" | cut -d' ' -f1)
    [ "$md5_first" = "$md5_second" ]
}

# === User content preservation: arbitrary user text survives byte-for-byte ===

@test "step_rtk_claude_init: arbitrary user content preserved byte-for-byte" {
    if ! command -v rtk >/dev/null 2>&1; then
        skip "rtk binary required"
    fi
    cat > "$TEST_HOME/.claude/CLAUDE.md" <<'EOF'
# My custom rules
- never use sudo
- prefer pnpm over npm

@OTHER.md

## Section that should survive
custom content here
EOF
    expected_top=$(head -8 "$TEST_HOME/.claude/CLAUDE.md")

    run run_step
    [ "$status" -eq 0 ]

    actual_top=$(head -8 "$TEST_HOME/.claude/CLAUDE.md")
    [ "$expected_top" = "$actual_top" ]

    # @RTK.md import must be present (somewhere) without disturbing the
    # original 8 lines of user content.
    grep -qE '^@RTK\.md' "$TEST_HOME/.claude/CLAUDE.md"
}

# === Pre-existing @RTK.md import: not duplicated ===

@test "step_rtk_claude_init: pre-existing @RTK.md import is not duplicated" {
    if ! command -v rtk >/dev/null 2>&1; then
        skip "rtk binary required"
    fi
    cat > "$TEST_HOME/.claude/CLAUDE.md" <<'EOF'
# Existing rules
@RTK.md

# more rules
EOF
    run run_step
    [ "$status" -eq 0 ]
    # Exactly one occurrence of `@RTK.md` at start of line.
    local count
    count=$(grep -cE '^@RTK\.md' "$TEST_HOME/.claude/CLAUDE.md")
    [ "$count" -eq 1 ]
}

# === No-rtk: skip cleanly ===

@test "step_rtk_claude_init: no rtk on PATH → return 0 with skip warning" {
    bash -c "
        set -uo pipefail
        export HOME='$TEST_HOME'
        export PATH='/usr/bin:/bin'
        log_info()    { printf '[INFO] %s\n' \"\$*\"; }
        log_warning() { printf '[WARN] %s\n' \"\$*\"; }
        $(extract_step_fn)
        step_rtk_claude_init
    " 2>&1 | tee "$TEST_TMPDIR/out"

    # Strict: bash -c must exit 0 (the function returns 0 when rtk is missing).
    # The previous `|| true` masked any non-zero return and made the assertion
    # vacuous — drop it.
    [ "${PIPESTATUS[0]:-0}" -eq 0 ]
    grep -q "skipping" "$TEST_TMPDIR/out" || grep -q "rtk not on PATH" "$TEST_TMPDIR/out"
}

# === The step never patches settings.json through rtk ===

@test "step_rtk_claude_init: never calls rtk init with --auto-patch" {
    run extract_step_fn
    [ "$status" -eq 0 ]
    [[ "$output" != *"--auto-patch"* ]]
    [[ "$output" == *"--no-patch"* ]]
}
