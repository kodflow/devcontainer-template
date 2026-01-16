#!/bin/bash
# ============================================================================
# log-shipper.sh - Sync local JSONL logs to Valkey Streams
# Usage: log-shipper.sh [branch] [--daemon]
#
# Architecture:
#   session.jsonl ──[tail -F]──> shipper ──[XADD]──> Valkey Streams
#
# Features:
#   - Fail-safe (never crashes, retries on Valkey failure)
#   - Backoff on connection errors
#   - Resume from last processed line
#   - Can run as daemon (--daemon) or one-shot
#
# Valkey Data Model:
#   claude:events                    # Stream global (XADD)
#   claude:branch:<branch>:runs      # List of run_ids (LPUSH)
#   claude:run:<run_id>:meta         # Hash metadata (HSET)
#   claude:branch:<branch>:checkpoint # Last run_id (SET)
# ============================================================================

set -uo pipefail

# === Configuration ===
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/workspace}"
LOGS_BASE="$PROJECT_DIR/.claude/logs"
VALKEY_HOST="${VALKEY_HOST:-valkey}"
VALKEY_PORT="${VALKEY_PORT:-6379}"
VALKEY_CLI="${VALKEY_CLI:-valkey-cli}"

# Retry config
MAX_RETRIES=5
RETRY_DELAY=2
BACKOFF_MULTIPLIER=2

# === Arguments ===
BRANCH_ARG="${1:-}"
DAEMON_MODE=false

for arg in "$@"; do
    case "$arg" in
        --daemon)
            DAEMON_MODE=true
            ;;
    esac
done

# === Helper: Valkey command with retry ===
vk() {
    local retries=0
    local delay=$RETRY_DELAY

    while [[ $retries -lt $MAX_RETRIES ]]; do
        if "$VALKEY_CLI" -h "$VALKEY_HOST" -p "$VALKEY_PORT" --raw "$@" 2>/dev/null; then
            return 0
        fi

        retries=$((retries + 1))
        if [[ $retries -lt $MAX_RETRIES ]]; then
            sleep "$delay"
            delay=$((delay * BACKOFF_MULTIPLIER))
        fi
    done

    return 1
}

# === Helper: Check Valkey connectivity ===
check_valkey() {
    if ! vk PING >/dev/null 2>&1; then
        echo "WARNING: Valkey not available at $VALKEY_HOST:$VALKEY_PORT" >&2
        return 1
    fi
    return 0
}

# === Helper: Ship one JSONL line to Valkey ===
ship_event() {
    local line="$1"
    local branch_safe="$2"

    # Parse event JSON
    local ts session_id tool_name hook_event run_id

    ts=$(printf '%s' "$line" | jq -r '.timestamp // ""' 2>/dev/null || echo "")
    session_id=$(printf '%s' "$line" | jq -r '.session_id // ""' 2>/dev/null || echo "")
    tool_name=$(printf '%s' "$line" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
    hook_event=$(printf '%s' "$line" | jq -r '.hook_event_name // ""' 2>/dev/null || echo "")

    # Generate run_id if not present
    run_id="${session_id:-${branch_safe}-$(date +%Y%m%d)}"

    # 1) XADD to global stream
    vk XADD "claude:events" "*" \
        ts "$ts" \
        session_id "$session_id" \
        tool_name "$tool_name" \
        hook_event "$hook_event" \
        branch "$branch_safe" \
        run_id "$run_id" \
        payload "$line" >/dev/null 2>&1 || return 1

    # 2) Track run in branch index (only once per session)
    vk LPOS "claude:branch:${branch_safe}:runs" "$run_id" >/dev/null 2>&1 || \
        vk LPUSH "claude:branch:${branch_safe}:runs" "$run_id" >/dev/null 2>&1

    # 3) Update run metadata
    vk HSET "claude:run:${run_id}:meta" \
        branch "$branch_safe" \
        last_tool "$tool_name" \
        last_event "$hook_event" \
        updated_at "$ts" >/dev/null 2>&1 || true

    # 4) Update checkpoint
    vk SET "claude:branch:${branch_safe}:checkpoint" "$run_id" >/dev/null 2>&1 || true

    # 5) Set TTL (7 days)
    vk EXPIRE "claude:run:${run_id}:meta" 604800 >/dev/null 2>&1 || true
    vk EXPIRE "claude:branch:${branch_safe}:runs" 604800 >/dev/null 2>&1 || true

    return 0
}

# === Main: Process a single branch ===
process_branch() {
    local branch_safe="$1"
    local log_dir="$LOGS_BASE/$branch_safe"
    local session_log="$log_dir/session.jsonl"
    local offset_file="$log_dir/.shipper_offset"

    if [[ ! -f "$session_log" ]]; then
        return 0
    fi

    # Get last processed line number
    local offset=0
    if [[ -f "$offset_file" ]]; then
        offset=$(cat "$offset_file" 2>/dev/null || echo "0")
    fi

    # Process new lines
    local line_num=0
    local shipped=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Skip already processed
        if [[ $line_num -le $offset ]]; then
            continue
        fi

        # Skip empty lines
        if [[ -z "$line" ]] || [[ "$line" == "{}" ]]; then
            continue
        fi

        # Ship to Valkey
        if ship_event "$line" "$branch_safe"; then
            shipped=$((shipped + 1))
            # Update offset atomically
            printf '%d' "$line_num" > "$offset_file.tmp"
            mv "$offset_file.tmp" "$offset_file"
        else
            echo "WARNING: Failed to ship event at line $line_num for branch $branch_safe" >&2
            break
        fi
    done < "$session_log"

    if [[ $shipped -gt 0 ]]; then
        echo "Shipped $shipped events for branch $branch_safe"
    fi
}

# === Main: Process all branches ===
process_all_branches() {
    if [[ ! -d "$LOGS_BASE" ]]; then
        return 0
    fi

    for branch_dir in "$LOGS_BASE"/*/; do
        if [[ -d "$branch_dir" ]]; then
            local branch_safe
            branch_safe=$(basename "$branch_dir")
            process_branch "$branch_safe"
        fi
    done
}

# === Main entry point ===
main() {
    echo "Log Shipper starting..."
    echo "  Valkey: $VALKEY_HOST:$VALKEY_PORT"
    echo "  Logs: $LOGS_BASE"
    echo "  Mode: $([ "$DAEMON_MODE" = true ] && echo "daemon" || echo "one-shot")"

    # Check jq
    if ! command -v jq &>/dev/null; then
        echo "ERROR: jq is required" >&2
        exit 1
    fi

    # Check Valkey CLI
    if ! command -v "$VALKEY_CLI" &>/dev/null; then
        echo "WARNING: $VALKEY_CLI not found, using redis-cli" >&2
        VALKEY_CLI="redis-cli"
        if ! command -v "$VALKEY_CLI" &>/dev/null; then
            echo "ERROR: Neither valkey-cli nor redis-cli found" >&2
            exit 1
        fi
    fi

    if [[ "$DAEMON_MODE" = true ]]; then
        # Daemon mode: continuous processing
        echo "Running in daemon mode (Ctrl+C to stop)"
        while true; do
            if check_valkey; then
                if [[ -n "$BRANCH_ARG" ]] && [[ "$BRANCH_ARG" != "--daemon" ]]; then
                    process_branch "$BRANCH_ARG"
                else
                    process_all_branches
                fi
            fi
            sleep 5
        done
    else
        # One-shot mode
        if ! check_valkey; then
            echo "ERROR: Valkey not available" >&2
            exit 1
        fi

        if [[ -n "$BRANCH_ARG" ]] && [[ "$BRANCH_ARG" != "--daemon" ]]; then
            process_branch "$BRANCH_ARG"
        else
            process_all_branches
        fi
    fi

    echo "Log Shipper completed"
}

# Run main
main "$@"
