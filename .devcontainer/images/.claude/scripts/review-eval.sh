#!/usr/bin/env bash
# ============================================================================
# review-eval.sh - REGRESSION / EVAL HARNESS for the /review trust anchor
# ----------------------------------------------------------------------------
# The verifier (review-verify-manifest.sh) is the keystone anti-theater gate and
# the canary (review-canary.sh) is its detection self-test. Neither one could,
# until now, detect its OWN rot: a refactor that silently stops failing INVALID
# manifests, or a canary that stops detecting seeded defects, would ship green.
#
# This harness closes that gap. In a throwaway git repo it manufactures a KNOWN
# change, asks the verifier for the authoritative facts (--print-facts), then
# builds a LABELED set of synthetic manifests — one per failure mode the gate is
# supposed to catch — and asserts the verifier's EXACT exit code for each:
#
#   case                         expected verifier exit
#   ---------------------------- ----------------------
#   correct                      0   (valid + approve-eligible)
#   paste-diff symbols           1   (anti-paste -> INVALID)
#   relabel code->docs           1   (file-class -> INVALID)
#   omit changed symbol          1   (symbol-coverage -> INVALID)
#   canary detected=false        2   (structurally valid, NOT approve-eligible)
#   code micro_pass="N/A"        1   (pass-completeness -> INVALID)
#   docs-only PR (.md only)      0   (legit -> must NOT false-FAIL)
#
# It ALSO runs review-canary.sh for real and asserts the emitted artifact has
# detected==true (the engine is not a no-op).
#
# A per-case PASS/FAIL table is printed. ANY deviation from the expectation
# above makes this script exit nonzero (so CI catches /review gate regressions).
# The temp repo is always cleaned up.
#
# Tools used (container baseline): git jq python3 (via verifier) + coreutils.
# Self-contained: discovers the verifier + canary as siblings of this script.
#
# EXIT: 0 all cases met expectation | 1 at least one deviated | 3 env/setup error
# ============================================================================

set -euo pipefail

PROG="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFIER="$SCRIPT_DIR/review-verify-manifest.sh"
CANARY="$SCRIPT_DIR/review-canary.sh"

die() { printf '%s: error: %s\n' "$PROG" "$*" >&2; exit 3; }

[ -f "$VERIFIER" ] || die "verifier not found: $VERIFIER"
[ -f "$CANARY" ]   || die "canary not found: $CANARY"
for t in git jq python3 mktemp; do
  command -v "$t" >/dev/null 2>&1 || die "required tool not found: $t"
done

# ---------------------------------------------------------------------------
# Scratch workspace + throwaway git repo (always cleaned up).
# ---------------------------------------------------------------------------
WORK="$(mktemp -d "${TMPDIR:-/tmp}/review-eval.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

REPO="$WORK/repo"
DET="$WORK/det"          # empty det dir: manifests declare no tiers
mkdir -p "$REPO" "$DET" "$WORK/logs"

EMPTY_HOOKS="$WORK/nohooks"   # neutralise any global core.hooksPath / commit-msg
mkdir -p "$EMPTY_HOOKS"

git -C "$REPO" init -q
git -C "$REPO" config user.email "eval@example.com"
git -C "$REPO" config user.name  "review eval"
git -C "$REPO" config commit.gpgsign false
git -C "$REPO" config core.hooksPath "$EMPTY_HOOKS"

mkdir -p "$REPO/docs"

# --- C0 (base): a code file with a real function + a docs file ---
cat > "$REPO/app.py" <<'EOF'
import sys


def process_data(x):
    total = 0
    value = total + 1
    return value
EOF
cat > "$REPO/docs/guide.md" <<'EOF'
# Guide

old content
EOF
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "base: app + guide"
C0="$(git -C "$REPO" rev-parse HEAD)"

# --- C1 (code change): touch process_data signature + body ONLY ---
cat > "$REPO/app.py" <<'EOF'
import sys


def process_data(x, y=0):
    total = y
    value = total + 1
    return value
EOF
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "feat: extend process_data"
C1="$(git -C "$REPO" rev-parse HEAD)"

# --- C2 (docs-only change): touch ONLY the markdown file ---
cat > "$REPO/docs/guide.md" <<'EOF'
# Guide

new content line
EOF
git -C "$REPO" add -A
git -C "$REPO" commit -q -m "docs: update guide"
C2="$(git -C "$REPO" rev-parse HEAD)"

# ---------------------------------------------------------------------------
# Authoritative facts from the verifier itself (--print-facts) for each range.
# The model would copy these verbatim; here the harness does the same.
# ---------------------------------------------------------------------------
FACTS_A="$("$VERIFIER" --repo "$REPO" --base "$C0" --head "$C1" --print-facts)"
DA="$(jq -r '.diff_hash'   <<<"$FACTS_A")"
HA="$(jq -r '.hunks_total' <<<"$FACTS_A")"
FACTS_B="$("$VERIFIER" --repo "$REPO" --base "$C1" --head "$C2" --print-facts)"
DB="$(jq -r '.diff_hash'   <<<"$FACTS_B")"
HB="$(jq -r '.hunks_total' <<<"$FACTS_B")"

[ -n "$DA" ] && [ "$HA" != "0" ] || die "range A produced no hunks (setup broken)"
[ -n "$DB" ] && [ "$HB" != "0" ] || die "range B produced no hunks (setup broken)"

# ---------------------------------------------------------------------------
# Run the REAL canary on the code change -> a genuine detected==true artifact.
# This doubles as the engine-is-not-a-no-op assertion (canary-detected case).
# ---------------------------------------------------------------------------
ART_A="$("$CANARY" --repo "$REPO" --base "$C0" --head "$C1" --out-dir "$WORK/canaryA" | tail -1)"
[ -f "$ART_A" ] || die "canary (range A) produced no artifact"
CANARY_DETECTED="$(jq -r '.detected' "$ART_A")"

# Real canary on the docs-only change (it seeds the .md fallback + still detects),
# so the legitimate docs-only manifest can be approve-eligible.
ART_B="$("$CANARY" --repo "$REPO" --base "$C1" --head "$C2" --out-dir "$WORK/canaryB" | tail -1)"
[ -f "$ART_B" ] || die "canary (range B) produced no artifact"

# A hand-built artifact whose detector reported FAILURE (engine mis-calibrated):
# structurally fine manifest, but APPROVE must be blocked (verifier exit 2).
ART_FALSE="$WORK/canary-false.json"
jq -n '{seeded:true, detected:false, defect:"forced-false canary",
        file:"app.py", ts:"eval", scratch:""}' > "$ART_FALSE"

# ---------------------------------------------------------------------------
# Synthetic manifests (one per labeled case). jq -n builds valid JSON; each
# differs from "correct" in exactly ONE injected fault so the asserted exit
# code pins the specific check that must fire.
# ---------------------------------------------------------------------------
M_CORRECT="$WORK/m_correct.json"
M_PASTE="$WORK/m_paste.json"
M_RELABEL="$WORK/m_relabel.json"
M_OMIT="$WORK/m_omit.json"
M_CANARY_FALSE="$WORK/m_canary_false.json"
M_MICRO_NA="$WORK/m_micro_na.json"
M_DOCS="$WORK/m_docs.json"

# correct: app.py code file, symbol covered, canary detected==true
jq -n --arg dh "$DA" --argjson ht "$HA" --arg art "$ART_A" '{
  diff_hash:$dh, hunks_total:$ht,
  files:[{path:"app.py", file_class:"code", hunks:$ht,
          symbols_inspected:["process_data"], macro_pass:true, micro_pass:true}],
  tiers:[], uninspected:[], canary_artifact:$art
}' > "$M_CORRECT"

# paste-the-diff: a symbols_inspected token carrying a raw '@@' diff hunk header
jq -n --arg dh "$DA" --argjson ht "$HA" --arg art "$ART_A" '{
  diff_hash:$dh, hunks_total:$ht,
  files:[{path:"app.py", file_class:"code", hunks:$ht,
          symbols_inspected:["process_data","@@ -1,3 +1,4 @@ def process_data"],
          macro_pass:true, micro_pass:true}],
  tiers:[], uninspected:[], canary_artifact:$art
}' > "$M_PASTE"

# relabel: a real code file declared as docs (file-class mismatch)
jq -n --arg dh "$DA" --argjson ht "$HA" --arg art "$ART_A" '{
  diff_hash:$dh, hunks_total:$ht,
  files:[{path:"app.py", file_class:"docs", hunks:$ht,
          symbols_inspected:["process_data"], macro_pass:true, micro_pass:true}],
  tiers:[], uninspected:[], canary_artifact:$art
}' > "$M_RELABEL"

# omit changed symbol: empty symbols_inspected for a code file with a changed def
jq -n --arg dh "$DA" --argjson ht "$HA" --arg art "$ART_A" '{
  diff_hash:$dh, hunks_total:$ht,
  files:[{path:"app.py", file_class:"code", hunks:$ht,
          symbols_inspected:[], macro_pass:true, micro_pass:true}],
  tiers:[], uninspected:[], canary_artifact:$art
}' > "$M_OMIT"

# canary detected=false: structurally sound, but the canary artifact failed
jq -n --arg dh "$DA" --argjson ht "$HA" --arg art "$ART_FALSE" '{
  diff_hash:$dh, hunks_total:$ht,
  files:[{path:"app.py", file_class:"code", hunks:$ht,
          symbols_inspected:["process_data"], macro_pass:true, micro_pass:true}],
  tiers:[], uninspected:[], canary_artifact:$art
}' > "$M_CANARY_FALSE"

# code file dodging micro via micro_pass="N/A" (only generated/vendored/... may)
jq -n --arg dh "$DA" --argjson ht "$HA" --arg art "$ART_A" '{
  diff_hash:$dh, hunks_total:$ht,
  files:[{path:"app.py", file_class:"code", hunks:$ht,
          symbols_inspected:["process_data"], macro_pass:true, micro_pass:"N/A"}],
  tiers:[], uninspected:[], canary_artifact:$art
}' > "$M_MICRO_NA"

# docs-only PR: only a markdown file changed (range B). Must NOT false-FAIL.
jq -n --arg dh "$DB" --argjson ht "$HB" --arg art "$ART_B" '{
  diff_hash:$dh, hunks_total:$ht,
  files:[{path:"docs/guide.md", file_class:"docs", hunks:$ht,
          symbols_inspected:[], macro_pass:true, micro_pass:true}],
  tiers:[], uninspected:[], canary_artifact:$art
}' > "$M_DOCS"

# ---------------------------------------------------------------------------
# WORKTREE untracked-file coverage (regression for the untracked-coverage check
# added with the worktree fix). Dirty the worktree: a tracked edit (gives hunks)
# + an UNTRACKED, non-ignored file. A manifest omitting the untracked file MUST
# FAIL (exit 1, untracked-coverage); one including it MUST PASS.
# ---------------------------------------------------------------------------
M_WT_MISS="$WORK/m_wt_miss.json"
M_WT_OK="$WORK/m_wt_ok.json"
printf '\n# worktree tweak\nextra = 1\n' >> "$REPO/app.py"
printf 'package newpkg\n\nfunc BrandNew() int { return 1 }\n' > "$REPO/newfile.go"
FACTS_W="$("$VERIFIER" --repo "$REPO" --base "$C2" --head WORKTREE --print-facts)"
DW="$(jq -r '.diff_hash'   <<<"$FACTS_W")"
HW="$(jq -r '.hunks_total' <<<"$FACTS_W")"
ART_W="$("$CANARY" --repo "$REPO" --base "$C2" --head WORKTREE --out-dir "$WORK/canaryW" | tail -1)"
[ -f "$ART_W" ] || die "canary (WORKTREE) produced no artifact"

# omits newfile.go -> untracked-coverage must fire (exit 1)
jq -n --arg dh "$DW" --argjson ht "$HW" --arg art "$ART_W" '{
  diff_hash:$dh, hunks_total:$ht,
  files:[{path:"app.py", file_class:"code", hunks:$ht,
          symbols_inspected:["process_data"], macro_pass:true, micro_pass:true}],
  tiers:[], uninspected:[], canary_artifact:$art
}' > "$M_WT_MISS"

# includes newfile.go (untracked, 0 tracked hunks) -> accepted (exit 0)
jq -n --arg dh "$DW" --argjson ht "$HW" --arg art "$ART_W" '{
  diff_hash:$dh, hunks_total:$ht,
  files:[{path:"app.py", file_class:"code", hunks:$ht,
          symbols_inspected:["process_data"], macro_pass:true, micro_pass:true},
         {path:"newfile.go", file_class:"code", hunks:0,
          symbols_inspected:["BrandNew"], macro_pass:true, micro_pass:true}],
  tiers:[], uninspected:[], canary_artifact:$art
}' > "$M_WT_OK"

# ---------------------------------------------------------------------------
# Run + record. Each case: run verifier (range A unless docs), capture rc,
# compare against the expected code. set +e around the call: a nonzero exit is
# the SIGNAL we measure, not a harness failure.
# ---------------------------------------------------------------------------
NAMES=() EXPECTS=() ACTUALS=() RESULTS=()
FAILED=0

run_case() {
  # $1 label  $2 expected-rc  $3 manifest  $4 base  $5 head
  local label="$1" exp="$2" mani="$3" base="$4" head="$5" rc log
  log="$WORK/logs/$(printf '%s' "$label" | tr -c 'A-Za-z0-9' '_').log"
  set +e
  "$VERIFIER" --repo "$REPO" --base "$base" --head "$head" \
              --manifest "$mani" --det "$DET" >"$log" 2>&1
  rc=$?
  set -e
  NAMES+=("$label"); EXPECTS+=("$exp"); ACTUALS+=("$rc")
  if [ "$rc" = "$exp" ]; then
    RESULTS+=("PASS")
  else
    RESULTS+=("FAIL")
    FAILED=1
    printf '\n--- verifier output for FAILING case "%s" (exp=%s got=%s) ---\n' \
           "$label" "$exp" "$rc"
    cat "$log"
    printf -- '--- end ---\n'
  fi
}

# Non-verifier assertion: the real canary actually detected its seeded defect.
record_bool() {
  # $1 label  $2 expected  $3 actual
  NAMES+=("$1"); EXPECTS+=("$2"); ACTUALS+=("$3")
  if [ "$2" = "$3" ]; then RESULTS+=("PASS"); else RESULTS+=("FAIL"); FAILED=1; fi
}

record_bool "canary-detected" "true" "$CANARY_DETECTED"

run_case "correct"            0 "$M_CORRECT"      "$C0" "$C1"
run_case "paste-diff-symbol"  1 "$M_PASTE"        "$C0" "$C1"
run_case "relabel-code-docs"  1 "$M_RELABEL"      "$C0" "$C1"
run_case "omit-symbol"        1 "$M_OMIT"         "$C0" "$C1"
run_case "canary-false"       2 "$M_CANARY_FALSE" "$C0" "$C1"
run_case "code-micro-N/A"     1 "$M_MICRO_NA"     "$C0" "$C1"
run_case "docs-only-no-fail"  0 "$M_DOCS"         "$C1" "$C2"
run_case "worktree-untracked-miss" 1 "$M_WT_MISS" "$C2" WORKTREE
run_case "worktree-untracked-ok"   0 "$M_WT_OK"   "$C2" WORKTREE

# ---------------------------------------------------------------------------
# Per-case PASS/FAIL table.
# ---------------------------------------------------------------------------
printf '\n== review /review gate eval ==\n'
printf '%-20s %-8s %-8s %s\n' "CASE" "EXPECT" "ACTUAL" "RESULT"
printf '%-20s %-8s %-8s %s\n' "--------------------" "------" "------" "------"
i=0
while [ "$i" -lt "${#NAMES[@]}" ]; do
  printf '%-20s %-8s %-8s %s\n' \
    "${NAMES[$i]}" "${EXPECTS[$i]}" "${ACTUALS[$i]}" "${RESULTS[$i]}"
  i=$((i + 1))
done

printf '\n'
if [ "$FAILED" -eq 0 ]; then
  printf 'EVAL: PASS (%d/%d cases met expectation)\n' "${#NAMES[@]}" "${#NAMES[@]}"
  exit 0
else
  printf 'EVAL: FAIL (at least one case deviated -> /review gate regressed)\n'
  exit 1
fi
