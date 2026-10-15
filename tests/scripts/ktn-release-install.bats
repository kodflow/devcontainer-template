#!/usr/bin/env bats
# Behavioural tests for the ktn-linter release installers (kodflow/ktn-linter#771):
#   - install_ktn_release in the Go feature's install.sh (build time)
#   - install_ktn_linter in sync-toolchains.sh (onCreate, writes the volume)
#
# Both are run for real against a fake release served over file:// — the
# archive with and without ktn-hook, checksums.txt right, wrong and missing.

setup() {
    load '../helpers/setup'
    common_setup
    INSTALL_SH="${BATS_TEST_DIRNAME}/../../.devcontainer/features/languages/go/install.sh"
    SYNC_SH="${BATS_TEST_DIRNAME}/../../.devcontainer/images/hooks/lifecycle/sync-toolchains.sh"

    ASSET="ktn-linter_linux_amd64.tar.gz"
    REL="$TEST_TMPDIR/releases"
    DEST="$TEST_TMPDIR/bin"
    mkdir -p "$REL" "$DEST"

    # install.sh's logging helpers come from feature-utils.sh at runtime.
    ok()   { echo "OK: $*"; }
    warn() { echo "WARN: $*"; }
    err()  { echo "ERR: $*"; }
    source_function_from "$INSTALL_SH" install_ktn_release

    # install_ktn_linter is nested in sync_go (4-space indent).
    eval "$(awk '/^    install_ktn_linter\(\) \{/{p=1} p{print} p && /^    \}$/{exit}' "$SYNC_SH")"
    declare -F install_ktn_linter >/dev/null
}

teardown() {
    common_teardown
}

# make_release <dir> <with_hook:yes|no> <checksum:good|bad|none>
make_release() {
    local dir=$1 with_hook=$2 sum=$3 src="$TEST_TMPDIR/src-$RANDOM"
    mkdir -p "$dir" "$src"
    printf '#!/bin/sh\necho linter\n' > "$src/ktn-linter"
    printf '#!/bin/sh\necho hook\n' > "$src/ktn-hook"
    chmod 0555 "$src/ktn-linter" "$src/ktn-hook"
    if [ "$with_hook" = yes ]; then
        tar -czf "$dir/$ASSET" -C "$src" ktn-linter ktn-hook
    else
        tar -czf "$dir/$ASSET" -C "$src" ktn-linter
    fi
    case "$sum" in
        good) (cd "$dir" && sha256sum "$ASSET") > "$dir/checksums.txt" ;;
        bad)  printf '%064d  %s\n' 0 "$ASSET" > "$dir/checksums.txt" ;;
        none) printf '%064d  %s\n' 0 "other.tar.gz" > "$dir/checksums.txt" ;;
    esac
}

# --- install.sh: install_ktn_release ---

@test "install_ktn_release: installs ktn-linter AND ktn-hook side by side, mode 0755" {
    make_release "$REL/v1" yes good
    run install_ktn_release "file://$REL/v1" amd64 "$DEST"
    [ "$status" -eq 0 ]
    [ "$(stat -c %a "$DEST/ktn-linter")" = 755 ]
    [ "$(stat -c %a "$DEST/ktn-hook")" = 755 ]
    [ "$("$DEST/ktn-hook")" = hook ]
    [[ "$output" == *"with ktn-hook"* ]]
    [ ! -e "$DEST/ktn-linter.download" ]
}

@test "install_ktn_release: archive without ktn-hook warns but succeeds" {
    make_release "$REL/v1" no good
    run install_ktn_release "file://$REL/v1" amd64 "$DEST"
    [ "$status" -eq 0 ]
    [ -x "$DEST/ktn-linter" ]
    [ ! -e "$DEST/ktn-hook" ]
    [[ "$output" == *"WARN: ktn-hook absent"* ]]
}

@test "install_ktn_release: wrong sha256 installs nothing" {
    make_release "$REL/v1" yes bad
    run install_ktn_release "file://$REL/v1" amd64 "$DEST"
    [ "$status" -ne 0 ]
    [[ "$output" == *"sha256 mismatch"* ]]
    [ ! -e "$DEST/ktn-linter" ]
    [ ! -e "$DEST/ktn-hook" ]
}

@test "install_ktn_release: no checksums entry for the archive installs nothing" {
    make_release "$REL/v1" yes none
    run install_ktn_release "file://$REL/v1" amd64 "$DEST"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no entry in checksums.txt"* ]]
    [ ! -e "$DEST/ktn-linter" ]
}

@test "install_ktn_release: missing checksums.txt installs nothing" {
    make_release "$REL/v1" yes good
    rm "$REL/v1/checksums.txt"
    run install_ktn_release "file://$REL/v1" amd64 "$DEST"
    [ "$status" -ne 0 ]
    [[ "$output" == *"checksums.txt download failed"* ]]
    [ ! -e "$DEST/ktn-linter" ]
}

@test "install_ktn_release: a bad download keeps the previous binaries" {
    make_release "$REL/v1" yes bad
    printf 'old\n' > "$DEST/ktn-linter"
    run install_ktn_release "file://$REL/v1" amd64 "$DEST"
    [ "$status" -ne 0 ]
    [ "$(cat "$DEST/ktn-linter")" = old ]
}

# --- sync-toolchains.sh: install_ktn_linter ---

@test "install_ktn_linter: pinned version fetches both files from that tag" {
    make_release "$REL/download/v1.46.0" yes good
    GO_ARCH=amd64 GOPATH="$TEST_TMPDIR/gopath" KTN_RELEASES_URL="file://$REL"
    mkdir -p "$GOPATH/bin"
    run install_ktn_linter 1.46.0
    [ "$status" -eq 0 ]
    [ "$(stat -c %a "$GOPATH/bin/ktn-linter")" = 755 ]
    [ "$(stat -c %a "$GOPATH/bin/ktn-hook")" = 755 ]
}

@test "install_ktn_linter: no version falls back to latest/download" {
    make_release "$REL/latest/download" yes good
    GO_ARCH=amd64 GOPATH="$TEST_TMPDIR/gopath" KTN_RELEASES_URL="file://$REL"
    mkdir -p "$GOPATH/bin"
    run install_ktn_linter
    [ "$status" -eq 0 ]
    [ -x "$GOPATH/bin/ktn-hook" ]
}

@test "install_ktn_linter: archive without ktn-hook warns but succeeds" {
    make_release "$REL/download/v1.45.0" no good
    GO_ARCH=amd64 GOPATH="$TEST_TMPDIR/gopath" KTN_RELEASES_URL="file://$REL"
    mkdir -p "$GOPATH/bin"
    run install_ktn_linter 1.45.0
    [ "$status" -eq 0 ]
    [ -x "$GOPATH/bin/ktn-linter" ]
    [ ! -e "$GOPATH/bin/ktn-hook" ]
    [[ "$output" == *"ktn-hook: absent"* ]]
}

@test "install_ktn_linter: wrong sha256 installs nothing" {
    make_release "$REL/download/v1.46.0" yes bad
    GO_ARCH=amd64 GOPATH="$TEST_TMPDIR/gopath" KTN_RELEASES_URL="file://$REL"
    mkdir -p "$GOPATH/bin"
    run install_ktn_linter 1.46.0
    [ "$status" -ne 0 ]
    [[ "$output" == *"sha256 check failed"* ]]
    [ ! -e "$GOPATH/bin/ktn-linter" ]
    [ ! -e "$GOPATH/bin/ktn-hook" ]
}

# --- structure ---

@test "ktn-hook is optional, never critical, in install.sh" {
    ! grep -E 'CRITICAL_TOOLS=\([^)]*ktn-hook' "$INSTALL_SH"
    grep -E 'OPTIONAL_TOOLS=\([^)]*"ktn-hook"' "$INSTALL_SH"
}

@test "install.sh downloads archive and checksums.txt from one resolved tag" {
    grep -qF 'releases/tag/' "$INSTALL_SH"
    grep -qF 'install_ktn_release "$KTN_BASE" "$GO_ARCH" "$GOPATH/bin"' "$INSTALL_SH"
    ! grep -qF 'spawn_tool "ktn-linter"' "$INSTALL_SH"
}

@test "sync_go reinstalls when ktn-hook is missing beside an up-to-date ktn-linter" {
    grep -qF 'elif [ ! -x "${GOPATH}/bin/ktn-hook" ]; then' "$SYNC_SH"
    grep -qF 'install_ktn_linter "$upstream"' "$SYNC_SH"
}
