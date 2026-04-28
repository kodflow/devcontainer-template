#!/usr/bin/env bats
# Tests for images/hooks/shared/sync-features.sh — the 3-way safe sync helper
# that fixes issue #334 (silent overwrite of consumer-modified feature files).

setup() {
    load '../helpers/setup'
    common_setup

    HELPER="${BATS_TEST_DIRNAME}/../../.devcontainer/images/hooks/shared/sync-features.sh"
    UTILS="${BATS_TEST_DIRNAME}/../../.devcontainer/images/hooks/shared/utils.sh"
    BUILDER="${BATS_TEST_DIRNAME}/../../.devcontainer/scripts/build-features-manifest.py"

    SRC="$TEST_TMPDIR/src"
    WS="$TEST_TMPDIR/ws"
    DST="$WS/.devcontainer/features"
    MAN="$TEST_TMPDIR/manifest.json"
    mkdir -p "$SRC" "$DST" "$WS/.devcontainer"

    git -C "$WS" init -q
    git -C "$WS" config user.email "test@test"
    git -C "$WS" config user.name "test"

    # shellcheck source=/dev/null
    source "$UTILS"
    export FEATURES_MANIFEST="$MAN"
    # shellcheck source=/dev/null
    source "$HELPER"
}

teardown() { common_teardown; }

# Build a manifest from the current SRC tree and commit DST as the
# baseline "previously-shipped" state.
seed_baseline() {
    cp -r "$SRC"/* "$DST/" 2>/dev/null || true
    python3 "$BUILDER" "$SRC" "test" "2026-04-28T00:00:00Z" > "$MAN"
    git -C "$WS" add . && git -C "$WS" commit -qm "baseline" 2>/dev/null || true
}

# --- T1: happy path ---
@test "T1 happy path: clean consumer, no upstream change → noop" {
    echo "alpha" > "$SRC/alpha.md"
    seed_baseline

    run sync_features_tree "$SRC" "$DST" "$WS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 copied, 1 unchanged, 0 removed, 0 preserved"* ]]
}

# --- T2: reproducer of issue #334 (uncommitted edit) ---
@test "T2 issue #334 reproducer: tracked + git-dirty file → preserved" {
    echo "alpha-v1" > "$SRC/alpha.md"
    seed_baseline

    # Consumer makes an uncommitted edit
    echo "consumer-edit" >> "$DST/alpha.md"
    # Upstream pushes a different version
    echo "alpha-v2" > "$SRC/alpha.md"

    run sync_features_tree "$SRC" "$DST" "$WS"
    [ "$status" -eq 0 ]
    grep -q "consumer-edit" "$DST/alpha.md"
    [[ "$output" == *"1 preserved"* ]]
    [[ "$output" == *"uncommitted changes"* ]]
}

# --- T3: committed consumer edit (manifest catches) ---
@test "T3 committed consumer edit + upstream change → manifest preserves" {
    echo "alpha-v1" > "$SRC/alpha.md"
    seed_baseline

    # Consumer commits an edit
    echo "consumer-committed" > "$DST/alpha.md"
    git -C "$WS" add . && git -C "$WS" commit -qm "consumer edit"

    # Upstream pushes a different version
    echo "alpha-v2" > "$SRC/alpha.md"

    run sync_features_tree "$SRC" "$DST" "$WS"
    [ "$status" -eq 0 ]
    grep -q "consumer-committed" "$DST/alpha.md"
    [[ "$output" == *"1 preserved"* ]]
    [[ "$output" == *"sha256 differs"* ]]
}

# --- T4: consumer-added file is left alone ---
@test "T4 consumer-added file → preserved (not in manifest, not deleted)" {
    echo "alpha-v1" > "$SRC/alpha.md"
    seed_baseline

    echo "consumer-only" > "$DST/extra.md"
    git -C "$WS" add . && git -C "$WS" commit -qm "extra"

    run sync_features_tree "$SRC" "$DST" "$WS"
    [ -f "$DST/extra.md" ]
    grep -q "consumer-only" "$DST/extra.md"
}

# --- T5: upstream-removed file (consumer untouched) → safe delete ---
@test "T5 upstream removes pristine file → deleted via manifest" {
    echo "alpha" > "$SRC/alpha.md"
    echo "beta" > "$SRC/beta.md"
    seed_baseline

    rm "$SRC/beta.md"

    run sync_features_tree "$SRC" "$DST" "$WS"
    [ "$status" -eq 0 ]
    [ ! -e "$DST/beta.md" ]
    [[ "$output" == *"1 removed"* ]]
}

# --- T6: upstream-removed file (consumer modified) → keep + warn ---
@test "T6 upstream removes consumer-modified file → kept" {
    echo "alpha" > "$SRC/alpha.md"
    echo "beta" > "$SRC/beta.md"
    seed_baseline

    rm "$SRC/beta.md"
    echo "consumer-modified" > "$DST/beta.md"

    run sync_features_tree "$SRC" "$DST" "$WS"
    [ "$status" -eq 0 ]
    [ -e "$DST/beta.md" ]
    grep -q "consumer-modified" "$DST/beta.md"
    [[ "$output" == *"Keeping features/beta.md"* ]]
}

# --- T7: new upstream file colliding with consumer-added path ---
@test "T7 new upstream path collides with consumer file → preserved" {
    echo "alpha" > "$SRC/alpha.md"
    seed_baseline

    # Consumer creates a file at a path NOT in the manifest
    echo "consumer-x" > "$DST/x.md"
    # Upstream now ships a file at the same path (not regenerating manifest →
    # the helper sees a path absent from FEATURES_MANIFEST)
    echo "upstream-x" > "$SRC/x.md"

    run sync_features_tree "$SRC" "$DST" "$WS"
    grep -q "consumer-x" "$DST/x.md"
    [[ "$output" == *"new upstream path collides"* ]]
}

# --- T8: missing manifest → falls back to Phase 1 (git-dirty) ---
@test "T8 manifest absent → falls back to Phase 1 (overwrites committed edit)" {
    echo "alpha-v1" > "$SRC/alpha.md"
    seed_baseline
    echo "consumer-committed" > "$DST/alpha.md"
    git -C "$WS" add . && git -C "$WS" commit -qm "edit"
    echo "alpha-v2" > "$SRC/alpha.md"

    export FEATURES_MANIFEST="/no/such/manifest.json"

    run sync_features_tree "$SRC" "$DST" "$WS"
    [ "$status" -eq 0 ]
    grep -q "alpha-v2" "$DST/alpha.md"
}

# --- T9: missing manifest + dirty tracked file → still preserved ---
@test "T9 manifest absent but git-dirty → Phase 1 preserves" {
    echo "alpha-v1" > "$SRC/alpha.md"
    seed_baseline
    echo "consumer-edit" >> "$DST/alpha.md"   # uncommitted
    echo "alpha-v2" > "$SRC/alpha.md"

    export FEATURES_MANIFEST="/no/such/manifest.json"

    run sync_features_tree "$SRC" "$DST" "$WS"
    [ "$status" -eq 0 ]
    grep -q "consumer-edit" "$DST/alpha.md"
    [[ "$output" == *"1 preserved"* ]]
}

# --- T10: byte-identical file → noop, no copy or skip ---
@test "T10 byte-identical src/dst → noop counter" {
    echo "alpha" > "$SRC/alpha.md"
    seed_baseline

    run sync_features_tree "$SRC" "$DST" "$WS"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 copied"* ]]
    [[ "$output" == *"1 unchanged"* ]]
    [[ "$output" == *"0 preserved"* ]]
}
