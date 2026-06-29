#!/usr/bin/env bash
# ============================================================================
# review-verify-manifest.sh - NON-LLM external verifier for /review (Phase 8)
# ----------------------------------------------------------------------------
# The keystone anti-theater gate. A model cannot APPROVE its own review: this
# script recomputes the coverage facts from git + the captured deterministic
# tier outputs, and INVALIDATES the run (nonzero exit) on any mismatch. The
# model defines neither the denominator of its coverage nor its own tier numbers.
#
# CONTRACT (from /review spec, Phase 8 + Anti-Theater Guardrails):
#   review-verify-manifest.sh --repo <dir> --base <sha> --head <sha> \
#                             --manifest <file.json> --det <det_dir>
#
# Tools used (only these are assumed present): git jq python3 sha256sum awk
# wc  (coreutils). NO ast-grep, NO semgrep, NO sed.
#
# CHECKS (each prints expected-vs-actual on mismatch):
#   1. diff-integrity   recompute diff_hash = git -C repo diff "BASE...HEAD"
#                       | sha256sum, and hunks_total = count of '^@@' hunk
#                       headers; both MUST equal the manifest values.
#   2. symbol-coverage  extract changed symbols from diff hunk-header context
#                       ('@@ .. @@ <ctx>') + added/removed signature lines;
#                       manifest.files[].symbols_inspected (union) MUST be a
#                       SUPERSET of that set (under-enumeration FAILS).
#                       Set logic done in python3, language-agnostic / tolerant.
#   3. tier-authenticity each manifest.tiers[] entry with status ran|failed MUST
#                       map to a real captured .out file in DET, and its recorded
#                       exit/findings MUST match what is parsed from that .out
#                       (cross-checked against DET/_table.tsv). Fabricated tier
#                       numbers FAIL.
#   4. pass-completeness no file with file_class in {code,config,iac} may have
#                       macro_pass=false, or a missing/false micro_pass.
#   5. approve-eligible manifest.uninspected MUST be [] and manifest.canary MUST
#                       be "passed" for an APPROVE-eligible run. When only this
#                       check fails (structure 1-4 sound) the script prints a
#                       distinct 'NOT APPROVE-ELIGIBLE' note but STILL exits
#                       nonzero so the model cannot emit APPROVE.
#
# EXIT CODES:
#   0  VERIFIER: PASS  (all checks pass; run is valid AND approve-eligible)
#   1  VERIFIER: FAIL  (one of checks 1-4 failed -> run is INVALID)
#   2  VERIFIER: FAIL (approve-eligibility) (checks 1-4 sound but canary failed
#                      or uninspected non-empty -> valid run, NOT approve-eligible)
#   3  usage / argument / environment error
#
# Final machine line is always one of:
#   VERIFIER: PASS
#   VERIFIER: FAIL (<check>)
# ============================================================================

set -euo pipefail

PROG="$(basename "$0")"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
pass()  { printf '[PASS] %s\n' "$*"; }
fail()  { printf '[FAIL] %s\n' "$*"; }
info()  { printf '[ ..]  %s\n' "$*"; }
die()   { printf '%s: error: %s\n' "$PROG" "$*" >&2; exit 3; }

usage() {
  cat <<EOF
$PROG - non-LLM coverage-manifest verifier for /review (anti-theater gate)

USAGE:
  $PROG --repo <dir> --base <sha> --head <sha> --manifest <file.json> --det <det_dir>
  $PROG --repo <dir> --base <sha> --head <sha> --print-facts

ARGUMENTS:
  --repo <dir>          git repository the review ran against
  --base <sha>          base ref/sha of the reviewed range
  --head <sha>          head ref/sha of the reviewed range, OR the sentinel
                        WORKTREE to review the uncommitted working tree vs BASE
  --manifest <file>     coverage manifest JSON emitted by the review run
  --det <det_dir>       directory of captured deterministic tier .out files
                        (and the DET/_table.tsv produced by the tier runner)
  --print-facts         print canonical {diff_hash, hunks_total} as JSON and
                        exit 0 (manifest/det not required); the model copies
                        these verbatim instead of recomputing (avoids RTK drift)
  -h, --help            show this help and exit

EXIT: 0 PASS | 1 INVALID run | 2 not approve-eligible | 3 usage/env error
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
REPO="" BASE="" HEAD="" MANIFEST="" DET="" PRINT_FACTS=0

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)        REPO="${2:-}";     shift 2 || die "--repo needs a value" ;;
    --base)        BASE="${2:-}";     shift 2 || die "--base needs a value" ;;
    --head)        HEAD="${2:-}";     shift 2 || die "--head needs a value" ;;
    --manifest)    MANIFEST="${2:-}"; shift 2 || die "--manifest needs a value" ;;
    --det)         DET="${2:-}";      shift 2 || die "--det needs a value" ;;
    # --print-facts: compute the canonical diff_hash + hunks_total from git and
    # print them as JSON, then exit. The model copies these into the manifest
    # INSTEAD of computing them itself — closing the RTK-rewrite divergence
    # (the model's `git diff` is rewritten by the RTK PreToolUse hook, this
    # script's internal `git diff` is not). Only --repo/--base/--head needed.
    --print-facts) PRINT_FACTS=1;     shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             usage >&2; die "unknown argument: $1" ;;
  esac
done

[ -n "$REPO" ]     || { usage >&2; die "--repo is required"; }
[ -n "$BASE" ]     || { usage >&2; die "--base is required"; }
[ -n "$HEAD" ]     || { usage >&2; die "--head is required"; }
if [ "$PRINT_FACTS" -eq 0 ]; then
  [ -n "$MANIFEST" ] || { usage >&2; die "--manifest is required"; }
  [ -n "$DET" ]      || { usage >&2; die "--det is required"; }
fi

# ---------------------------------------------------------------------------
# Environment validation
# ---------------------------------------------------------------------------
for t in git jq python3 sha256sum awk wc; do
  command -v "$t" >/dev/null 2>&1 || die "required tool not found: $t"
done

[ -d "$REPO" ]      || die "repo dir does not exist: $REPO"
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $REPO"
if [ "$PRINT_FACTS" -eq 0 ]; then
  [ -f "$MANIFEST" ]  || die "manifest file not found: $MANIFEST"
  jq -e . "$MANIFEST" >/dev/null 2>&1 || die "manifest is not valid JSON: $MANIFEST"
  [ -d "$DET" ]       || die "det dir does not exist: $DET"
fi

if ! git -C "$REPO" rev-parse --verify --quiet "${BASE}^{commit}" >/dev/null; then
  die "base ref not resolvable in repo: $BASE"
fi
# HEAD may be the sentinel WORKTREE / WORKING-TREE — meaning "review the
# uncommitted working tree against BASE" (the common local `/review` on a dirty
# tree). In that mode there is no HEAD commit to resolve.
case "$HEAD" in
  WORKTREE|WORKING-TREE) HEAD_IS_WORKTREE=1 ;;
  *)
    HEAD_IS_WORKTREE=0
    if ! git -C "$REPO" rev-parse --verify --quiet "${HEAD}^{commit}" >/dev/null; then
      die "head ref not resolvable in repo: $HEAD"
    fi ;;
esac

# ---------------------------------------------------------------------------
# Canonical diff — the ONE deterministic byte stream both this verifier and
# the manifest's diff_hash must agree on. Pinned flags (no color, no external
# differ, fixed -U3 context, default prefixes) remove git-config / TTY drift.
# WORKTREE mode diffs BASE against the working tree (tracked changes; untracked
# files are out of scope and must be committed/added to be reviewed).
# ---------------------------------------------------------------------------
canonical_diff() {
  if [ "$HEAD_IS_WORKTREE" -eq 1 ]; then
    git -C "$REPO" -c core.pager=cat diff --no-color --no-ext-diff -U3 "${BASE}" --
  else
    git -C "$REPO" -c core.pager=cat diff --no-color --no-ext-diff -U3 "${BASE}...${HEAD}"
  fi
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/review-verify.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

DIFF_FILE="$WORK/diff.patch"
canonical_diff > "$DIFF_FILE"

# --print-facts: emit the authoritative diff_hash + hunks_total and exit 0.
# The model MUST copy these verbatim into the manifest rather than recompute
# them (its own `git diff` runs through the RTK rewrite and would diverge).
if [ "$PRINT_FACTS" -eq 1 ]; then
  pf_hash="$(sha256sum < "$DIFF_FILE" | awk '{print tolower($1)}')"
  pf_hunks="$(awk '/^@@/ {n++} END {print n+0}' "$DIFF_FILE")"
  jq -n --arg h "$pf_hash" --argjson n "$pf_hunks" --arg head "$HEAD" \
        '{diff_hash:$h, hunks_total:$n, head:$head}'
  exit 0
fi

printf '== review-verify-manifest ==\n'
printf 'repo=%s base=%s head=%s\n' "$REPO" "$BASE" "$HEAD"
printf 'manifest=%s det=%s\n\n' "$MANIFEST" "$DET"

# Accumulators. set -e safe: we never `exit` from a check, only flag.
STRUCT_FAILS=()           # names of failed structural checks (1-4)
ELIG_OK=1                 # 1 = approve-eligible, 0 = not
ELIG_REASON=""

# ===========================================================================
# CHECK 1 - diff-integrity (recompute diff_hash + hunks_total)
# ===========================================================================
check_diff_integrity() {
  local ok=1

  # --- diff_hash ---
  local actual_hash mani_hash
  actual_hash="$(sha256sum < "$DIFF_FILE" | awk '{print tolower($1)}')"
  mani_hash="$(jq -r '.diff_hash // ""' "$MANIFEST" \
    | awk '{ if (match($0,/[0-9a-fA-F]{64}/)) print tolower(substr($0,RSTART,64)) }')"

  if [ -z "$mani_hash" ]; then
    fail "diff-integrity: manifest.diff_hash missing or not a sha256"
    ok=0
  elif [ "$mani_hash" != "$actual_hash" ]; then
    fail "diff-integrity: diff_hash mismatch"
    printf '       expected (git): %s\n' "$actual_hash"
    printf '       actual (manifest): %s\n' "$mani_hash"
    ok=0
  else
    pass "diff-integrity: diff_hash matches ($actual_hash)"
  fi

  # --- hunks_total (count of hunk headers '^@@') ---
  local actual_hunks mani_hunks
  actual_hunks="$(awk '/^@@/ {n++} END {print n+0}' "$DIFF_FILE")"
  mani_hunks="$(jq -r 'if has("hunks_total") then (.hunks_total|tostring) else "" end' "$MANIFEST")"

  if [ -z "$mani_hunks" ] || [ "$mani_hunks" = "null" ]; then
    fail "diff-integrity: manifest.hunks_total missing"
    ok=0
  elif ! printf '%s' "$mani_hunks" | awk '/^[0-9]+$/{exit 0} {exit 1}'; then
    fail "diff-integrity: manifest.hunks_total is not an integer ($mani_hunks)"
    ok=0
  elif [ "$mani_hunks" != "$actual_hunks" ]; then
    fail "diff-integrity: hunks_total mismatch"
    printf '       expected (git): %s\n' "$actual_hunks"
    printf '       actual (manifest): %s\n' "$mani_hunks"
    ok=0
  else
    pass "diff-integrity: hunks_total matches ($actual_hunks)"
  fi

  [ "$ok" -eq 1 ] || STRUCT_FAILS+=("diff-integrity")
}

# ===========================================================================
# CHECK 2 - symbol-coverage (manifest symbols ⊇ git-extracted symbols)
# Language-agnostic, best-effort, tolerant. Set logic in python3.
# ===========================================================================
check_symbol_coverage() {
  if python3 - "$DIFF_FILE" "$MANIFEST" <<'PY'
import sys, json, re

diff_path, manifest_path = sys.argv[1], sys.argv[2]

# Multi-language keyword / primitive stoplist: these are NOT symbols, so they
# must never enter the REQUIRED set (otherwise the generic "name before (" or
# control-statement hunk contexts would force false failures).
KEYWORDS = {
    "if","for","while","switch","return","else","elif","do","case","default",
    "func","def","function","fn","sub","class","struct","interface","trait",
    "enum","impl","type","typedef","namespace","module","package","protocol",
    "record","object","public","private","protected","static","final","async",
    "await","virtual","override","abstract","sealed","partial","readonly",
    "internal","friend","inline","extern","register","volatile","constexpr",
    "noexcept","template","typename","decltype","auto","using","import","from",
    "export","where","with","try","catch","except","finally","throw","throws",
    "raise","match","when","select","go","defer","chan","range","in","is","as",
    "and","or","not","lambda","pub","mut","ref","new","delete","goto","break",
    "continue","yield","assert","sizeof","typeof","operator","unsafe","extends",
    "implements","void","const","let","var","val","true","false","nil","null",
    "none","self","this","super","base","int","uint","float","double","char",
    "bool","byte","rune","short","long","signed","unsigned","string","str",
    "error","any","dynamic","object","print","println","echo",
}

DEF_PATTERNS = [
    r'\bfunc\s+(?:\([^)]*\)\s*)?([A-Za-z_]\w*)',                          # Go
    r'\bdef\s+([A-Za-z_]\w*)',                                            # Python/Ruby
    r'\bfunction\s+\*?\s*([A-Za-z_]\w*)',                                 # JS/PHP
    r'\bfn\s+([A-Za-z_]\w*)',                                             # Rust
    r'\bsub\s+([A-Za-z_]\w*)',                                            # Perl
    r'\b(?:class|struct|interface|trait|impl|enum|type|namespace|'
    r'module|protocol|record|object)\s+([A-Za-z_]\w*)',                   # many
]

def names_from_text(text, signatures_only=False):
    """Best-effort symbol-name extraction. Returns a set of identifiers.
    signatures_only=True -> only return names from an explicit definition
    keyword (used for added/removed diff lines, keeps the REQUIRED set tight)."""
    found = set()
    matched_def = False
    for p in DEF_PATTERNS:
        for m in re.finditer(p, text):
            found.add(m.group(1)); matched_def = True
    if signatures_only:
        if not matched_def:
            return set()
    elif not matched_def:
        # hunk-context fallback: identifier immediately before '(' (the
        # enclosing function for C/C++/Java/C#/... where git emits a signature)
        m = re.search(r'([A-Za-z_]\w*)\s*\(', text)
        if m:
            found.add(m.group(1))
    return {n for n in found if len(n) > 1 and n.lower() not in KEYWORDS}

# --- git-extracted (REQUIRED) symbol set ---
required = set()
hunk_re = re.compile(r'^@@[^@]*@@(.*)$')
try:
    with open(diff_path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith('@@'):
                m = hunk_re.match(line.rstrip('\n'))
                if m:
                    required |= names_from_text(m.group(1), signatures_only=False)
            elif line.startswith('+') and not line.startswith('+++'):
                required |= names_from_text(line[1:], signatures_only=True)
            elif line.startswith('-') and not line.startswith('---'):
                required |= names_from_text(line[1:], signatures_only=True)
except OSError as e:
    print("symbol-coverage: cannot read diff: %s" % e); sys.exit(2)

# --- manifest token set (union of all symbols_inspected, tokenised) ---
ident_re = re.compile(r'[A-Za-z_]\w*')
manifest_tokens = set()
sym_count = 0
try:
    with open(manifest_path, encoding="utf-8", errors="replace") as fh:
        man = json.load(fh)
except (OSError, ValueError) as e:
    print("symbol-coverage: cannot read manifest: %s" % e); sys.exit(2)

for f in (man.get("files") or []):
    for s in (f.get("symbols_inspected") or []):
        sym_count += 1
        manifest_tokens.update(ident_re.findall(str(s)))

missing = sorted(n for n in required if n not in manifest_tokens)

if missing:
    print("symbol-coverage: manifest under-enumerates changed symbols")
    print("  git-extracted symbols: %d, manifest symbols: %d"
          % (len(required), sym_count))
    print("  MISSING from symbols_inspected (union): %s"
          % ", ".join(missing[:40]) + (" ..." if len(missing) > 40 else ""))
    sys.exit(1)

print("symbol-coverage: %d git-extracted symbol(s) all covered by %d "
      "manifest symbol(s)" % (len(required), sym_count))
sys.exit(0)
PY
  then
    pass "symbol-coverage: symbols_inspected ⊇ git-extracted symbol set"
  else
    fail "symbol-coverage: under-enumeration detected (see above)"
    STRUCT_FAILS+=("symbol-coverage")
  fi
}

# ===========================================================================
# CHECK 3 - tier-authenticity (.out exists; exit/findings match capture)
# Mirrors the tier runner: file = "${tool//[^a-zA-Z0-9]/_}.out",
# findings column = line count of that .out (wc -l). Both cross-checked
# against DET/_table.tsv (tool\tstatus\texit\tfindings).
# ===========================================================================
check_tier_authenticity() {
  local c3_fail=0 tiers
  tiers="$(jq -r '.tiers[]? | [(.tool//""),(.status//""),(.exit|tostring),(.findings|tostring)] | @tsv' "$MANIFEST")"

  if [ -z "$tiers" ]; then
    pass "tier-authenticity: no tiers declared (nothing to verify)"
    return 0
  fi

  local tool status exit_f findings_f
  while IFS=$'\t' read -r tool status exit_f findings_f; do
    [ -n "$tool" ] || continue
    case "$status" in
      absent|na|"" )  # no .out is expected for absent/na tiers
        info "tier-authenticity: $tool status=$status (no .out expected)"
        continue ;;
    esac

    # Resolve the captured .out file (sanitised whole string and first token)
    local san_full san_first first out cand
    san_full="${tool//[^a-zA-Z0-9]/_}"
    first="${tool%% *}"
    san_first="${first//[^a-zA-Z0-9]/_}"
    out=""
    for cand in "$DET/$san_full.out" "$DET/$san_first.out"; do
      if [ -f "$cand" ]; then out="$cand"; break; fi
    done

    if [ -z "$out" ]; then
      fail "tier-authenticity: $tool status=$status but no captured .out in DET"
      printf '       looked for: %s.out , %s.out\n' "$san_full" "$san_first"
      c3_fail=1
      continue
    fi

    # Recompute findings = line count of the .out (same as the runner's wc -l)
    local actual_lines
    actual_lines="$(wc -l < "$out")"; actual_lines="${actual_lines// /}"

    if [ -n "$findings_f" ] && [ "$findings_f" != "null" ] && [ "$findings_f" != "$actual_lines" ]; then
      fail "tier-authenticity: $tool findings mismatch"
      printf '       expected (%s line count): %s\n' "$(basename "$out")" "$actual_lines"
      printf '       actual (manifest): %s\n' "$findings_f"
      c3_fail=1
    fi

    # Cross-check exit + findings against the runner's DET/_table.tsv row
    if [ -f "$DET/_table.tsv" ]; then
      local row tbl_exit tbl_find
      row="$(awk -F'\t' -v t="$tool" -v t2="$first" '$1==t || $1==t2 {print; exit}' "$DET/_table.tsv")"
      if [ -n "$row" ]; then
        tbl_exit="$(printf '%s' "$row" | awk -F'\t' '{print $3}')"
        tbl_find="$(printf '%s' "$row" | awk -F'\t' '{print $4}')"
        if [ -n "$exit_f" ] && [ "$exit_f" != "null" ] && [ -n "$tbl_exit" ] && [ "$exit_f" != "$tbl_exit" ]; then
          fail "tier-authenticity: $tool exit mismatch"
          printf '       expected (_table.tsv): %s\n' "$tbl_exit"
          printf '       actual (manifest): %s\n' "$exit_f"
          c3_fail=1
        fi
        if [ -n "$tbl_find" ] && [ "$tbl_find" != "$actual_lines" ]; then
          fail "tier-authenticity: $tool captured table/.out inconsistent (tampering)"
          printf '       _table.tsv findings: %s , .out line count: %s\n' "$tbl_find" "$actual_lines"
          c3_fail=1
        fi
      fi
    fi

    [ "$c3_fail" -eq 1 ] || info "tier-authenticity: $tool ok (exit=$exit_f findings=$actual_lines)"
  done <<< "$tiers"

  if [ "$c3_fail" -eq 0 ]; then
    pass "tier-authenticity: all ran/failed tiers map to real captured output"
  else
    STRUCT_FAILS+=("tier-authenticity")
  fi
}

# ===========================================================================
# CHECK 4 - pass-completeness (code/config/iac need macro+micro)
# ===========================================================================
check_pass_completeness() {
  local offenders
  offenders="$(jq -r '
    .files[]?
    | select(.file_class=="code" or .file_class=="config" or .file_class=="iac")
    | select((.macro_pass != true) or (has("micro_pass")|not) or (.micro_pass == false))
    | "\(.path)\tfile_class=\(.file_class)\tmacro_pass=\(.macro_pass)\tmicro_pass=\(if has("micro_pass") then .micro_pass else "MISSING" end)"
  ' "$MANIFEST")"

  if [ -n "$offenders" ]; then
    fail "pass-completeness: code/config/iac file(s) with failed/missing passes:"
    while IFS= read -r line; do printf '       %s\n' "$line"; done <<< "$offenders"
    STRUCT_FAILS+=("pass-completeness")
  else
    pass "pass-completeness: all code/config/iac files have macro+micro passes"
  fi
}

# ===========================================================================
# CHECK 5 - approve-eligibility (uninspected==[] AND canary=="passed")
# Soft gate: does NOT mark the run INVALID, but DOES force nonzero exit so the
# model cannot APPROVE.
# ===========================================================================
check_approve_eligibility() {
  local uninspected_len canary reasons=()
  uninspected_len="$(jq -r '(.uninspected // []) | length' "$MANIFEST")"
  canary="$(jq -r '.canary // ""' "$MANIFEST")"

  if [ "$uninspected_len" != "0" ]; then
    reasons+=("uninspected is non-empty ($uninspected_len item(s))")
  fi
  if [ "$canary" != "passed" ]; then
    reasons+=("canary != passed (got: '${canary:-<missing>}')")
  fi

  if [ "${#reasons[@]}" -eq 0 ]; then
    pass "approve-eligibility: uninspected==[] and canary==passed"
  else
    ELIG_OK=0
    local r joined=""
    for r in "${reasons[@]}"; do joined+="${joined:+; }$r"; done
    ELIG_REASON="$joined"
    fail "approve-eligibility: NOT approve-eligible -> $joined"
  fi
}

# ---------------------------------------------------------------------------
# Run all checks (structural first, eligibility last)
# ---------------------------------------------------------------------------
check_diff_integrity
check_symbol_coverage
check_tier_authenticity
check_pass_completeness
check_approve_eligibility

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
printf '\n'
if [ "${#STRUCT_FAILS[@]}" -gt 0 ]; then
  printf 'INVALID RUN: structural check(s) failed: %s\n' "${STRUCT_FAILS[*]}"
  printf 'VERIFIER: FAIL (%s)\n' "${STRUCT_FAILS[0]}"
  exit 1
elif [ "$ELIG_OK" -eq 0 ]; then
  printf 'NOT APPROVE-ELIGIBLE: %s\n' "$ELIG_REASON"
  printf '  (run is structurally valid, but the model MUST NOT emit APPROVE — verdict INCONCLUSIVE)\n'
  printf 'VERIFIER: FAIL (approve-eligibility)\n'
  exit 2
else
  printf 'VERIFIER: PASS\n'
  exit 0
fi
