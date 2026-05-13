#!/bin/bash
# ============================================================================
# git-guard.sh - Combined git commit/push guard (PreToolUse Bash)
# Merges commit-validate.sh + security.sh into a single script.
#
# Only activates on git commit/push commands. All other Bash commands
# pass through instantly (no JSON parsing overhead).
#
# Functions:
#   1. Block AI/Claude mentions in commit messages
#   2. Auto-correct --force → --force-with-lease
#   3. Scan staged files for secrets before commit
#
# Exit 0 = allow, Exit 2 = block
# ============================================================================

set +e  # Fail-open

# === Read hook input ===
INPUT="$(cat 2>/dev/null || true)"
if [ -z "$INPUT" ] || ! command -v jq &>/dev/null; then
    exit 0
fi

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Only handle Bash tool
if [ "$TOOL" != "Bash" ]; then
    exit 0
fi

# Normalize RTK-prefixed commands
NORMALIZED_CMD="$COMMAND"
if [[ "$NORMALIZED_CMD" =~ ^rtk[[:space:]]+proxy[[:space:]]+ ]]; then
    NORMALIZED_CMD="${NORMALIZED_CMD#rtk proxy }"
elif [[ "$NORMALIZED_CMD" =~ ^rtk[[:space:]]+ ]]; then
    NORMALIZED_CMD="${NORMALIZED_CMD#rtk }"
fi

# === FAST EXIT: not a git commit/push? Skip entirely ===
if [[ ! "$NORMALIZED_CMD" =~ ^git[[:space:]]+(commit|push) ]]; then
    exit 0
fi

# ============================================================
# From here: git commit or git push only
# ============================================================

# === 0. Reject --no-verify ===
#
# `--no-verify` bypasses every local git hook — pre-commit, commit-msg,
# pre-push — which makes the layer-2 .githooks/commit-msg guard pointless if
# Claude can route around it. We refuse it outright. The only valid escape
# hatch is a deliberate human terminal action outside Claude's Bash tool.
#
# `-n` after `git commit` is git's documented alias for `--no-verify`
# (see `man git-commit`). For `git push`, `-n` means `--dry-run` and is
# harmless, so we only treat the bare `-n` as a bypass when preceded by
# `commit`.
if [[ "$NORMALIZED_CMD" =~ --no-verify ]] \
   || [[ "$NORMALIZED_CMD" =~ ^git[[:space:]]+commit([[:space:]].*)?[[:space:]]-n([[:space:]]|$) ]]; then
    echo "═══════════════════════════════════════════════" >&2
    echo "  ❌ COMMAND BLOCKED — --no-verify is forbidden" >&2
    echo "═══════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  Bypassing local git hooks defeats the AI-attribution and" >&2
    echo "  secret-scan guards (defence-in-depth, issue #358)." >&2
    echo "  If a hook is wrong, fix the hook — don't skip it." >&2
    echo "" >&2
    echo "═══════════════════════════════════════════════" >&2
    exit 2
fi

# === 1. Auto-correct --force → --force-with-lease (push) ===
if [[ "$NORMALIZED_CMD" =~ ^git[[:space:]]+push ]] && \
   [[ "$NORMALIZED_CMD" =~ --force ]] && \
   [[ ! "$NORMALIZED_CMD" =~ --force-with-lease ]]; then
    # Replace standalone --force with --force-with-lease (preserves quoting)
    CORRECTED="${COMMAND/--force/--force-with-lease}"
    echo "⚠️  Auto-corrected: --force → --force-with-lease" >&2
    jq -n --arg cmd "$CORRECTED" \
        --arg reason "Auto-corrected: --force → --force-with-lease" \
        '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":$reason,"updatedInput":{"command":$cmd}}}'
    exit 0
fi

# === 2. Block AI mentions in commit messages ===
#
# Build a HAYSTACK string that covers every shape `git commit` accepts. The
# previous parser only saw -m "..." with double quotes; everything else (single
# quotes, -F file, -F -, --amend reusing prior message, editor mode, multiple
# -m flags, rebase/cherry-pick reusing tainted history) silently passed.
# See issue #358 D2 for the leak catalogue.
#
# Catches:
#   - git commit -m "..." | -m '...' | -m bare | -m "X" -m "Y"
#   - git commit --message=... (= or space)
#   - git commit -F file  (reads file content)
#   - git commit -F -  (reads stdin — best-effort, scanned later if available)
#   - git commit --amend (no -m) → looks up HEAD's message via git log -1
#   - git commit (editor mode) → looks up COMMIT_EDITMSG when present
#   - git rebase --continue / git cherry-pick (replay tainted commits)
#   - Heredoc bodies (cat <<EOF ...)
if [[ "$NORMALIZED_CMD" =~ ^git[[:space:]]+(commit|rebase|cherry-pick) ]]; then
    HAYSTACK=""

    # All -m / --message values, repeated. Tolerates both quote styles and
    # bare-word forms. `re-quote` extraction is delegated to a sed pass that
    # turns each occurrence into one line we can grep.
    HAYSTACK="$HAYSTACK"$'\n'"$(printf '%s' "$COMMAND" | sed -nE '
        s/.*--message=([^[:space:]].*)/\1/p
        s/.*--message[[:space:]]+([^[:space:]].*)/\1/p
        s/.*-m[[:space:]]+"([^"]+)".*/\1/p
        s/.*-m[[:space:]]+'\''([^'\'']+)'\''.*/\1/p
        s/.*-m[[:space:]]+([^[:space:]"'\''][^[:space:]]*).*/\1/p
    ' 2>/dev/null)"

    # -F file (skip "-F -" which means stdin — we cannot read it from here)
    if [[ "$NORMALIZED_CMD" =~ -F[[:space:]]+([^[:space:]]+) ]]; then
        F_ARG="${BASH_REMATCH[1]}"
        if [ "$F_ARG" != "-" ] && [ -r "$F_ARG" ]; then
            HAYSTACK="$HAYSTACK"$'\n'"$(cat -- "$F_ARG" 2>/dev/null || true)"
        fi
    fi

    # Heredoc bodies (cat <<EOF ... EOF wrapped inside the command string)
    if [[ "$COMMAND" =~ \<\<[\'\"]?[A-Z_]+ ]]; then
        HAYSTACK="$HAYSTACK"$'\n'"$(printf '%s' "$COMMAND" | sed -n '/<<.*EOF/,/EOF/p' | grep -v "EOF" | grep -v "cat <<" 2>/dev/null || true)"
    fi

    # --amend without -m reuses HEAD's commit message — fetch it
    # (also covers rebase/cherry-pick that reuse upstream messages)
    if [[ "$NORMALIZED_CMD" =~ --amend ]] && [[ ! "$NORMALIZED_CMD" =~ -m[[:space:]]|--message ]]; then
        HAYSTACK="$HAYSTACK"$'\n'"$(git log -1 --pretty=%B 2>/dev/null || true)"
    fi
    if [[ "$NORMALIZED_CMD" =~ ^git[[:space:]]+(rebase|cherry-pick) ]]; then
        # rebase --continue / cherry-pick: scan ALL commits being applied since
        # they replay tainted messages from upstream history without going
        # through `-m`. Best-effort: scan the last 20 commits.
        HAYSTACK="$HAYSTACK"$'\n'"$(git log -20 --pretty=%B 2>/dev/null || true)"
    fi

    # Editor mode (no -m, no -F, no --amend): the message is going to be typed
    # in COMMIT_EDITMSG, which doesn't exist yet at PreToolUse time. We cannot
    # block it here — the `.githooks/commit-msg` hook (layer 2, defence-in-depth)
    # catches that path at git's `commit-msg` event. Documented in #358 D3.

    if [ -n "$HAYSTACK" ]; then
        HAYSTACK_LOWER=$(printf '%s' "$HAYSTACK" | tr '[:upper:]' '[:lower:]')

        FORBIDDEN_PATTERNS=(
            "co-authored-by:.*(claude|anthropic|openai|gpt|copilot|gemini|llm|ai)"
            "generated[[:space:]]+(by|with)[[:space:]]+(claude|ai|gpt|anthropic|copilot)"
            "ai[-.]assisted"
            "🤖"
            "claude[-[:space:]]code"
        )

        for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
            if echo "$HAYSTACK_LOWER" | grep -qiE "$pattern"; then
                echo "═══════════════════════════════════════════════" >&2
                echo "  ❌ COMMIT BLOCKED - AI reference detected" >&2
                echo "═══════════════════════════════════════════════" >&2
                echo "" >&2
                echo "  Forbidden pattern: $pattern" >&2
                echo "  Remove AI references from the commit message." >&2
                echo "  Defence-in-depth: layer 2 (.githooks/commit-msg) will" >&2
                echo "  also block this on the git side if you bypass me." >&2
                echo "" >&2
                echo "═══════════════════════════════════════════════" >&2
                exit 2
            fi
        done
    fi
fi

if [[ "$NORMALIZED_CMD" =~ ^git[[:space:]]+commit ]]; then

    # === 3. Scan staged files for secrets (reads staged blobs, not working tree) ===
    ISSUES_FOUND=0

    # Inline lightweight secret scan (avoid calling security.sh subprocess)
    # Use process substitution to avoid subshell (preserves ISSUES_FOUND)
    while IFS= read -r -d '' f; do
        [ -z "$f" ] && continue

        # Skip hook/tooling scripts (contain regex patterns that match themselves)
        # Skip agents (contain security detection patterns), templates (.tpl),
        # lifecycle hooks (contain token variable references), and test fixtures
        case "$f" in
            */.claude/scripts/*|*/.claude/agents/*|*/.claude/commands/*) continue ;;
            */.githooks/*|*.bats|*.tpl) continue ;;
            */hooks/lifecycle/*) continue ;;
        esac

        # Read staged blob content (not working tree)
        STAGED_CONTENT=$(git show ":$f" 2>/dev/null) || continue

        # Skip binary files (check staged content)
        if printf '%s' "$STAGED_CONTENT" | file -- - 2>/dev/null | grep -q "binary"; then
            continue
        fi

        # Pattern-based secret detection on staged content
        if printf '%s' "$STAGED_CONTENT" | grep -iEq \
            'password\s*=\s*["\047][^"\047]+|api[_-]?key\s*=\s*["\047][^"\047]+|secret[_-]?key\s*=\s*["\047][^"\047]+|aws[_-]?access[_-]?key|BEGIN RSA PRIVATE KEY|BEGIN OPENSSH PRIVATE KEY|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9_]+|sk-[a-zA-Z0-9]{48}|AKIA[0-9A-Z]{16}'; then
            echo "⚠️  Potential secret in: $f" >&2
            ISSUES_FOUND=1
        fi

        # detect-secrets (if available, more thorough)
        if [ $ISSUES_FOUND -eq 0 ] && command -v detect-secrets &>/dev/null; then
            if printf '%s' "$STAGED_CONTENT" | detect-secrets scan 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); exit(0 if any(d.get("results",{}).values()) else 1)'; then
                echo "⚠️  detect-secrets found issue in: $f" >&2
                ISSUES_FOUND=1
            fi
        fi
    done < <(git diff --cached --name-only -z 2>/dev/null)

    if [ $ISSUES_FOUND -eq 1 ]; then
        echo "═══════════════════════════════════════════════" >&2
        echo "  ⚠️  COMMIT BLOCKED - Secrets detected" >&2
        echo "═══════════════════════════════════════════════" >&2
        echo "  Remove secrets before committing." >&2
        echo "═══════════════════════════════════════════════" >&2
        exit 2
    fi
fi

exit 0
