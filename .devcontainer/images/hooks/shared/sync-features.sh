#!/bin/bash
# shellcheck disable=SC1090,SC1091
# ============================================================================
# sync-features.sh - 3-way safe sync for .devcontainer/features/
# ============================================================================
# Sourced by postStart.sh (step_sync_features) and by /update apply.md
# to mirror the template's features/ tree into a consumer repo without
# clobbering consumer-modified files.
#
# Phase 1 (this file): per-file git-dirty + byte-identical guard.
# Phase 2 (manifest):  hash manifest 3-way merge — see _sync_via_manifest stub.
#
# See plan: .claude/plans/2026-04-28-fix-poststart-features-sync-overwrite.md
# Tracking issue: kodflow/devcontainer-template#334
# ============================================================================

# Counter exported so callers can report skips after the loop.
export FEATURES_SYNC_SKIPPED=0

# Phase 2 hook — replaced when the shipped-content hash manifest lands.
# Contract: succeed (return 0) only when the manifest can prove the dst
# file is untouched since the last image build, then perform the copy.
# Phase 1 always returns 1 so callers fall through to the safe default.
_sync_via_manifest() {
    return 1
}

# 3-way file copy with consumer-edit protection.
# Args: $1 = src absolute path, $2 = dst absolute path, $3 = workspace root
# Return codes (caller drives counters; never fatal):
#   0 = wrote (new file or safe overwrite)
#   1 = noop (byte-identical, no I/O)
#   2 = preserved (consumer-modified, skipped on purpose)
_sync_file_safely() {
    local src="$1"
    local dst="$2"
    local ws="$3"
    local rel="${dst#"${ws}"/.devcontainer/features/}"

    # Case 1: dst missing → copy (new file from upstream).
    if [ ! -e "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -a "$src" "$dst"
        return 0
    fi

    # Case 2: byte-identical → noop.
    if cmp -s "$src" "$dst"; then
        return 1
    fi

    # Case 3: tracked + dirty in consumer git → preserve consumer WIP.
    # Without git, we cannot tell WIP from a committed divergence; the
    # manifest path (Phase 2) closes that gap. Until then, fall through.
    if [ -d "$ws/.git" ] && command -v git >/dev/null 2>&1; then
        if git -C "$ws" ls-files --error-unmatch -- ".devcontainer/features/${rel}" >/dev/null 2>&1; then
            if ! git -C "$ws" diff --quiet --exit-code -- ".devcontainer/features/${rel}" >/dev/null 2>&1; then
                log_warning "Skipping features/${rel}: consumer has uncommitted changes (commit or run /update first)"
                return 2
            fi
        fi
    fi

    # Case 4: manifest-aware copy (Phase 2). Phase 1 stub returns 1 → fall through.
    if _sync_via_manifest "$src" "$dst" "$rel"; then
        return 0
    fi

    # Case 5: fallback — overwrite. Phase 1 keeps current behaviour for
    # committed consumer edits (the manifest in Phase 2 narrows this gap).
    cp -a "$src" "$dst"
    return 0
}

# Per-file walk over the embedded features tree. Replaces the previous
# `rsync -a --delete --checksum` call. `--delete` is intentionally dropped
# in Phase 1 (no manifest yet → cannot tell consumer-added from upstream-
# removed files). Phase 2 restores deletion via the hash manifest.
sync_features_tree() {
    local src="$1"
    local dst="$2"
    local ws="$3"

    if [ ! -d "$src" ]; then
        log_warning "sync_features_tree: source dir missing ($src)"
        return 1
    fi
    mkdir -p "$dst"

    FEATURES_SYNC_SKIPPED=0
    local copied=0 noop=0
    local rc
    while IFS= read -r -d '' src_file; do
        local rel="${src_file#"$src"/}"
        local dst_file="$dst/$rel"
        _sync_file_safely "$src_file" "$dst_file" "$ws"
        rc=$?
        case "$rc" in
            0) copied=$((copied + 1)) ;;
            1) noop=$((noop + 1)) ;;
            2) FEATURES_SYNC_SKIPPED=$((FEATURES_SYNC_SKIPPED + 1)) ;;
        esac
    done < <(find "$src" -type f -print0)

    log_success ".devcontainer/features/ synced ($copied copied, $noop unchanged, $FEATURES_SYNC_SKIPPED preserved)"
    if [ "$FEATURES_SYNC_SKIPPED" -gt 0 ]; then
        log_info "Tip: \`git status -- .devcontainer/features/\` shows preserved consumer edits"
    fi
    return 0
}
