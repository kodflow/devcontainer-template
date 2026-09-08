#!/usr/bin/env bash
# rtk-hook-version: 3
# RTK PreToolUse hook — rewrites Bash commands to their rtk equivalent.
#
# Why this script and not rtk-hook-claude.sh: that wrapper called
# `rtk hook claude`, a subcommand removed from rtk by 0.28.2. It exited 127 on
# EVERY Bash call and fail-open'd, so rtk compression was silently dead while
# the log filled with rc=127. `rtk rewrite` is rtk's own documented hook API
# ("single source of truth for hooks") and is what this script uses.
#
# ABSOLUTE: never exit non-zero and never write to stderr on a normal path.
# A PreToolUse hook that fails blocks every Bash call in the session, and rtk
# is best-effort token compression — never worth blocking the agent on.
#
# stdin  : PreToolUse JSON payload
# stdout : a hookSpecificOutput object when a rewrite applies; nothing otherwise
# log    : $HOME/.claude/logs/<branch>/rtk-hook.log  (diagnostics only, never stderr)

set +e

_branch() { git symbolic-ref --short HEAD 2>/dev/null || printf 'default'; }
LOG_DIR="${HOME}/.claude/logs/$(_branch)"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="${LOG_DIR}/rtk-hook.log"
_log() { printf '[rtk-hook] %s\n' "$*" >>"$LOG" 2>/dev/null; }

command -v jq  >/dev/null 2>&1 || { _log "jq absent; pass-through";  exit 0; }
command -v rtk >/dev/null 2>&1 || { _log "rtk absent; pass-through"; exit 0; }

# `rtk rewrite` landed in 0.23.0. Warn once, then stay quiet — a hook that logs
# on every invocation turns the log into noise nobody reads.
VER=$(rtk --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -n "$VER" ]; then
  MAJ=${VER%%.*}; REST=${VER#*.}; MIN=${REST%%.*}
  if [ "$MAJ" -eq 0 ] && [ "$MIN" -lt 23 ]; then
    MARKER="${XDG_CACHE_HOME:-$HOME/.cache}/rtk/.version-warning-shown"
    if [ ! -f "$MARKER" ]; then
      mkdir -p "$(dirname "$MARKER")" 2>/dev/null
      _log "rtk $VER too old (need >= 0.23.0); pass-through. Upgrade: cargo install rtk"
      : >"$MARKER" 2>/dev/null
    fi
    exit 0
  fi
fi

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# Opt-out escape hatch. A command whose exact byte-for-byte output matters
# (a checksum, a diff being applied, a heredoc being written) prefixes itself
# with NO_RTK= and is passed through untouched.
case "$CMD" in NO_RTK=*) exit 0 ;; esac

# Fidelity guard, enforced here and not only in rtk's own exclude_commands.
# rtk 0.28.2 honours the exclusion for `head file` and `head -n 40 file` but
# NOT for `head -40 file` — the short-form path skips the check and rewrites to
# `rtk read --max-lines`, which strips comments. Any command whose exact bytes
# matter is filtered here, before rtk is consulted at all.
# Strip leading VAR=value assignments and env/command wrappers before reading
# the command name. `OUT=x head -40 f` and `env FOO=1 cat f` both name a fidelity
# read, and both slipped past a naive "first word" test.
_rest=${CMD#"${CMD%%[![:space:]]*}"}
while :; do
  _w=${_rest%%[[:space:]]*}
  case "$_w" in
    [A-Za-z_]*=*|env|command|builtin|nohup|time|exec)
      _next=${_rest#*[[:space:]]}
      [ "$_next" = "$_rest" ] && break
      _rest=${_next#"${_next%%[![:space:]]*}"} ;;
    *) break ;;
  esac
done
FIRST=${_rest%%[[:space:]]*}
FIRST=${FIRST##*/}
case "$FIRST" in
  cat|head|tail|sed|awk|diff|patch|sha256sum|sha1sum|md5sum|base64|xxd|od|strings|cmp)
    exit 0 ;;
esac

# `rtk find` rejects compound predicates outright:
#   "rtk find does not support compound predicates or actions (e.g. -not, -exec)"
# It fails loudly rather than losing data, so this is a cost guard, not a safety
# one: rewriting such a command guarantees a failed call and a retry. Same for
# grep/git invocations that pipe into something expecting native formatting.
case "$FIRST" in
  find)
    case " $CMD " in
      *" -not "*|*" -exec "*|*" -execdir "*|*" -o "*|*" -delete "*|*" -prune "*|*" -printf "*|*" -print0 "*)
        exit 0 ;;
    esac ;;
esac

REWRITTEN=$(rtk rewrite "$CMD" 2>/dev/null) || exit 0
[ -z "$REWRITTEN" ] && exit 0
[ "$CMD" = "$REWRITTEN" ] && exit 0

UPDATED=$(printf '%s' "$INPUT" | jq -c --arg cmd "$REWRITTEN" '.tool_input | .command = $cmd' 2>/dev/null)
[ -z "$UPDATED" ] && { _log "jq failed building updatedInput; pass-through"; exit 0; }

jq -n --argjson updated "$UPDATED" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: "rtk auto-rewrite",
    updatedInput: $updated
  }
}' 2>/dev/null || exit 0
exit 0
