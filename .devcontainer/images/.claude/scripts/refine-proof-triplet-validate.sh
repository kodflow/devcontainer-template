#!/usr/bin/env bash
# refine-proof-triplet-validate.sh — skills-cleanup C5 (GI8)
#
# Validates the command lines of a /goal CONTRACT (proof-triplet form) against
# the safe grammar declared in the global contract:
#   - ! grep -RIn '<pat>' <path>          (absence)
#   - grep -Rq '<pat>' <path>             (presence, exit-based)
#   - test "$(<pipeline>)" -<op> <N>      (count; | only inside $())
#   - test [!] -f|-e|-x|-d <path>
#   - bats <file>
#   - make <target>
#   - cd <dir> && <one of the above>
# DENY anywhere: ;  top-level |  >  >>  `backticks`  eval rm mv curl wget sudo chmod chown
#
# Reads lines from stdin. Exit 0 if every command line is safe, 25 otherwise.
# Header (`/goal … CONTRACT:`), blank lines, the STOP block, and lines annotated
# `(manual smoke)` / `[gate …]` are skipped (not machine-gated).
set -uo pipefail
EXIT_BAD=25

validate_line() {
  local raw="$1" cmd body
  cmd="$raw"
  cmd="$(printf '%s' "$cmd" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"          # trim
  cmd="$(printf '%s' "$cmd" | sed -E 's/^[0-9]+\)[[:space:]]*//')"                      # drop "N) "
  cmd="$(printf '%s' "$cmd" | sed -E 's/[[:space:]]*\(manual[^)]*\)[[:space:]]*$//')"   # drop (manual …)
  cmd="$(printf '%s' "$cmd" | sed -E 's/[[:space:]]*\[gate[^]]*\][[:space:]]*$//')"     # drop [gate …]
  cmd="$(printf '%s' "$cmd" | sed -E 's/[[:space:]]+$//')"

  # Non-command lines that legitimately appear in a CONTRACT block → skip.
  [ -z "$cmd" ] && return 0
  case "$cmd" in
    /goal*|CONTRACT:*|STOP:*|Suggested\ next\ step:*) return 0 ;;
  esac

  # DENY dangerous metacharacters anywhere.
  case "$cmd" in
    *';'*|*'`'*|*'>'*) return 1 ;;
  esac
  # Normalize shell delimiters to spaces so a forbidden binary is caught even when
  # nested inside a command substitution, e.g. test "$(rm -rf x)" -eq 0 (Qodo #2).
  local scan
  scan="$(printf '%s' "$cmd" | tr '()|;&{}<>' '         ')"
  case " $scan " in
    *' eval '*|*' rm '*|*' mv '*|*' curl '*|*' wget '*|*' sudo '*|*' chmod '*|*' chown '*) return 1 ;;
  esac
  case "$scan" in
    rm\ *|mv\ *|curl\ *|wget\ *|sudo\ *|chmod\ *|chown\ *|eval\ *) return 1 ;;
  esac

  # Strip one optional `cd <dir> && ` prefix (the only allowed compound).
  body="$cmd"
  if [[ "$cmd" =~ ^cd\ [^\&\;|]+\ \&\&\ (.+)$ ]]; then
    body="${BASH_REMATCH[1]}"
  fi

  # No further command chaining: a single command only (the lone `cd … &&` above
  # is the only permitted compound). Rejects `make test && echo x`, etc.
  [[ "$body" == *'&&'* ]] && return 1

  # A top-level pipe is forbidden; `|` is allowed only inside a test "$(...)" form.
  if [[ "$body" == *'|'* ]] && [[ ! "$body" =~ ^test\ \"\$\(.*\)\" ]]; then
    return 1
  fi

  # Whitelist of allowed command heads.
  [[ "$body" == "! grep "* ]]                                   && return 0
  [[ "$body" =~ ^grep\ -[A-Za-z]*q[A-Za-z]*\  ]]                && return 0
  [[ "$body" =~ ^test\ \"\$\(.*\)\"\ -(eq|ge|le|ne)\ [0-9]+$ ]] && return 0
  [[ "$body" =~ ^test\ (!\ )?-[fexd]\ .+ ]]                     && return 0
  [[ "$body" == "bats "* ]]                                     && return 0
  [[ "$body" == "make "* ]]                                     && return 0
  return 1
}

bad=0
while IFS= read -r line || [ -n "$line" ]; do
  if ! validate_line "$line"; then
    echo "invalid CONTRACT line: $line" >&2
    bad=1
  fi
done

[ "$bad" -eq 0 ] || exit "$EXIT_BAD"
exit 0
