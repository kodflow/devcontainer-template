---
name: review-doctor
description: |
  Autonomous health-and-heal for the /review v2 (evidence-bound) stack.
  Dispatches 5 specialist agents in parallel, each verifying + fixing ONE
  concern: the non-LLM verifier script, the review modules, the deterministic
  scanner matrix, agent routing, and the canary self-test. Idempotent: does
  nothing when the stack is healthy; prints an ASCII dashboard either way.
  Use when: a fresh container starts, /review returns INCONCLUSIVE unexpectedly,
  the verifier errors, or you want a one-command sanity check before relying on
  /review to gate a merge.
model: opus
allowed-tools:
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "Bash(bash:*)"
  - "Bash(git:*)"
  - "Bash(jq:*)"
  - "Bash(command:*)"
  - "Bash(which:*)"
  - "Bash(chmod:*)"
  - "Bash(test:*)"
  - "Bash([:*)"
  - "Bash(echo:*)"
  - "Bash(cat:*)"
  - "Bash(ls:*)"
  - "Bash(mktemp:*)"
  - "Bash(rm:*)"
  - "Bash(sha256sum:*)"
  - "Bash(awk:*)"
  - "Bash(wc:*)"
  - "Bash(sed:*)"
  - "Bash(grep:*)"
  - "Bash(rg:*)"
  - "Bash(shellcheck:*)"
  - "Edit(**/*)"
  - "Agent(*)"
---

# /review-doctor - Health-and-Heal for the /review v2 stack

$ARGUMENTS

Mirrors `/ktn`: verify each load-bearing piece of the evidence-bound `/review`
pipeline, heal only what is broken, and print a dashboard. The pipeline is only
as trustworthy as its keystone — a silently-broken verifier turns every review
into a fake pass. This skill exists so "is /review actually working?" is a
one-command answer.

## Parse Arguments

- **No args**: full health check + auto-heal of anything broken.
- **`--check`**: report only, never modify (dry run).
- **`--concern <name>`**: run a single concern (`verifier|modules|scanners|routing|canary`).

## Resolution paths

| Asset | Source (repo) | Runtime |
|-------|---------------|---------|
| Verifier | `.devcontainer/images/.claude/scripts/review-verify-manifest.sh` | `~/.claude/scripts/review-verify-manifest.sh` |
| Canary | `.devcontainer/images/.claude/scripts/review-canary.sh` | `~/.claude/scripts/review-canary.sh` |
| Command | `.devcontainer/images/.claude/commands/review.md` | `~/.claude/commands/review.md` |
| Modules | `…/commands/review/{dimensions,deterministic,graph,manifest}.md` | `~/.claude/commands/review/*.md` |
| Router | `…/.claude/scripts/route-agent.sh` + `agents/routing-table.jsonl` | `~/.claude/scripts/…` |

Resolve each asset with this precedence (used by every concern below):

```bash
resolve_asset() {  # $1 = relative leaf, e.g. scripts/review-canary.sh
  for root in \
    "$PROJECT_DIR/.devcontainer/images/.claude" \
    "$HOME/.claude"; do
    [ -f "$root/$1" ] && { printf '%s\n' "$root/$1"; return 0; }
  done
  return 1
}
```

Prefer the workspace source in the template repo; fall back to the runtime copy
in consumer repos (same precedence rule as the pre-commit hook).

## Execution — dispatch 5 concern agents in PARALLEL

Send all five in one message (independent, no shared writes). Each returns a
`{concern, status: ok|healed|broken, detail}` record.

### Concern 1 — Verifier (keystone)
- `command -v bash git jq python3 sha256sum awk wc` — all required tools present.
- **Verifier file exists and is executable.** Resolve via `resolve_asset
  scripts/review-verify-manifest.sh`; `[ -x "$V" ]` — heal a missing exec bit
  with `chmod +x "$V"` (status `healed`). A missing FILE is `broken` (cannot
  self-heal a keystone that isn't there).
- `bash -n "$V"` clean; `shellcheck -S warning "$V"` clean if shellcheck present.
- **Self-test (must PASS):** in a scratch `git init` repo run `--print-facts`
  against a real one-line change and assert it emits a 64-hex `diff_hash` and an
  integer `hunks_total`; then build a minimal manifest *copying those facts
  verbatim* (never recomputed) and assert a full run exits `0` /
  `VERIFIER: PASS`. A nonzero/garbled positive result ⇒ `broken` (do not
  auto-edit the script; report the failing check — a broken keystone needs
  human eyes). The matching **negative** proof lives in Concern 5 (the gate
  must also FAIL a tampered manifest, else PASS is meaningless).

### Concern 2 — Modules
- All four `review/{dimensions,deterministic,graph,manifest}.md` exist and are
  non-empty.
- Cross-consistency with `review.md`: every module `review.md` references in its
  phase map exists; the verifier's 5 checks named in `review.md` match
  `manifest.md`'s contract. Report drift; heal only trivial path typos.

### Concern 3 — Scanner matrix (deterministic tiers)
- Probe each deterministic tool the `deterministic.md` matrix expects:
  `semgrep gitleaks trufflehog detect-secrets osv-scanner trivy ast-grep
  golangci-lint staticcheck govulncheck ruff mypy eslint shellcheck actionlint
  hadolint checkov` (extend from `deterministic.md`).
- Emit a `ran|absent` table. **Absent is not failure** — `/review` degrades
  cleanly (caps confidence, never silent-pass). Do NOT install here; point at the
  scanners feature (#392) and report coverage %.
- Footgun guard: assert `ast-grep` resolves to ast-grep and NOT `/usr/bin/sg`
  (which is `newgrp`). Flag loudly if `sg` shadows it.

### Concern 4 — Routing
- `route-agent.sh` present + executable; `routing-table.jsonl` readable + valid
  JSONL (each line parses).
- Every language specialist referenced by `review.md` / `dimensions.md` resolves
  to an existing `agents/<name>.md` with valid frontmatter (reuse the
  `route-agent.sh --dry-run` path). Report any dangling reference.

### Concern 5 — Canary self-test (REAL, two-sided — proves the gate bites)

A canary that only ever reports "passed" proves nothing. This concern runs a
**positive** case (the defect detector fires) AND a **negative/tamper** case
(the verifier rejects a known-bad manifest). Both must hold, or the concern is
`broken` — a one-sided green is treated as a silent failure.

First, **existence + executability** of both load-bearing scripts (heal a bare
exec bit, report a missing file as `broken`):

```bash
V="$(resolve_asset scripts/review-verify-manifest.sh)" || { echo broken; exit; }
C="$(resolve_asset scripts/review-canary.sh)"          || { echo broken; exit; }
for s in "$V" "$C"; do
  [ -f "$s" ] || { echo "broken: missing $s"; exit; }
  [ -x "$s" ] || { [ -n "$CHECK_ONLY" ] && echo "broken: not +x $s" || chmod +x "$s"; }
done
```

**(1) Positive — `review-canary.sh` must DETECT its seeded defect.** Run the
real script (it seeds a known defect into a scratch copy of a changed code file,
runs a micro detection, and writes `.claude/review-canary-<ts>.json`). READ the
artifact and require `detected == true` — never a bare "passed" string (C6):

```bash
ART="$(bash "$C" --emit-artifact-path 2>/dev/null \
       | tail -n1)"                                  # script prints its path …
[ -f "$ART" ] || ART="$(ls -t "$PROJECT_DIR"/.claude/review-canary-*.json \
       2>/dev/null | head -n1)"                      # … or pick the newest
pos_ok=0
if [ -f "$ART" ] && jq -e '.seeded==true and .detected==true' "$ART" >/dev/null 2>&1; then
  pos_ok=1
fi
# pos_ok==0  => the detector did NOT catch a defect it planted => gate is blind.
```

**(2) Negative/Tamper — the verifier must FAIL a known-bad manifest.** Build a
scratch repo with one real in-body code change, take the authoritative facts
from `--print-facts` (so checks 1/diff-integrity can never be the reason for the
failure), then run the verifier on a CLEAN manifest and a TAMPERED one and
require the verdict to FLIP. The tamper plants exactly the two bypasses the
SHARED CONTRACT kills: a **relabeled `file_class`** (C2: `auth.go` → `docs`) and
**pasted-diff symbols** (C1: the whole multi-line diff shoved into one
`symbols_inspected` token). Everything else is identical:

```bash
S="$(mktemp -d "${TMPDIR:-/tmp}/rd-canary.XXXXXX")"
W="$(mktemp -d "${TMPDIR:-/tmp}/rd-work.XXXXXX")"
trap 'rm -rf "$S" "$W"' RETURN
git -C "$S" init -q
printf 'package auth\nfunc Login(u string) bool {\n\treturn u != ""\n}\n' > "$S/auth.go"
git -C "$S" -c user.email=d@d -c user.name=d add -A
git -C "$S" -c user.email=d@d -c user.name=d commit -qm base
BASE="$(git -C "$S" rev-parse HEAD)"
printf 'package auth\nfunc Login(u string) bool {\n\treturn len(u) > 3\n}\n' > "$S/auth.go"  # in-body edit

FACTS="$(bash "$V" --repo "$S" --base "$BASE" --head WORKTREE --print-facts)" || { echo broken; exit; }
DH="$(jq -r '.diff_hash'   <<<"$FACTS")"
HN="$(jq -rc '.hunks_total' <<<"$FACTS")"
BLOB="$(git -C "$S" -c core.pager=cat diff --no-color "$BASE" -- )"   # the WHOLE diff, one string
mkdir -p "$W/det"; : > "$W/det/_table.tsv"

# CLEAN: correct class + tight, per-file enclosing symbol -> must PASS.
jq -n --arg dh "$DH" --argjson hn "$HN" '{
  diff_hash:$dh, hunks_total:$hn, uninspected:[], canary:"passed",
  canary_artifact:"", tiers:[],
  files:[{path:"auth.go", file_class:"code", hunks:$hn, macro_pass:true,
          micro_pass:true, symbols_inspected:["Login"]}]
}' > "$W/clean.json"

# TAMPERED: file_class relabel (C2) + pasted-diff symbols (C1) -> must FAIL.
jq -n --arg dh "$DH" --argjson hn "$HN" --arg blob "$BLOB" '{
  diff_hash:$dh, hunks_total:$hn, uninspected:[], canary:"passed",
  canary_artifact:"", tiers:[],
  files:[{path:"auth.go", file_class:"docs", hunks:$hn, macro_pass:true,
          micro_pass:true, symbols_inspected:[$blob]}]
}' > "$W/tampered.json"

bash "$V" --repo "$S" --base "$BASE" --head WORKTREE --manifest "$W/clean.json"    --det "$W/det" >/dev/null 2>&1; rc_clean=$?
bash "$V" --repo "$S" --base "$BASE" --head WORKTREE --manifest "$W/tampered.json" --det "$W/det" >/dev/null 2>&1; rc_tamper=$?
```

Interpret the two exit codes (the verifier exits `0` PASS, `1` INVALID, `2`
not-approve-eligible, `3` usage/env):

| `rc_clean` | `rc_tamper` | Verdict | Meaning |
|-----------:|------------:|---------|---------|
| `0` | `1` (or `2`) | **gate bites** | clean accepted, tamper rejected — correct |
| `0` | `0` | **broken** | tamper SLIPPED THROUGH — anti-paste/relabel checks absent |
| `0` | `3` | **broken** | tamper only died on a parse/env error, not the planted defect — inconclusive bite |
| `1`/`2` | any | **broken** | clean manifest rejected — verifier over-strict or schema drift (needs human eyes) |
| `3` | any | **inconclusive** | environment problem (shallow clone, tool missing) — surface, never claim healthy |

The concern is `ok` ONLY when **(1) `pos_ok==1` AND (2) the row is "gate
bites"**. Anything else is `broken`/`inconclusive` with the exact failing row as
`detail`. Do NOT auto-patch the verifier or canary script — a non-biting gate is
reported for human eyes, never silently healed.

## Synthesize — ASCII dashboard (computed, not authored)

**The dashboard is RENDERED from the five concern records — never hand-typed.**
Each concern agent returns a `{concern, status, detail}` record where `status ∈
{ok, healed, broken, degraded, inconclusive}` is the literal output of its checks
above (e.g. Canary's `status` is `ok` only on `pos_ok==1` AND the "gate bites"
row). Map status → glyph, then print one row per record in fixed order. If any
record is missing, render `❓ unknown` for that row and force the verdict to
`INCONCLUSIVE` — never substitute a green glyph for an absent result.

```
glyph() { case "$1" in ok) echo "✅ ok";; healed) echo "🔧 healed";;
  degraded) echo "⚠  degraded";; broken) echo "❌ broken";;
  inconclusive) echo "❓ inconclusive";; *) echo "❓ unknown";; esac; }
```

Example output (illustrative — the glyphs above are filled from real records):

```
╔══════════════════════════════════════════════════════════╗
║  /review-doctor — evidence-bound review stack             ║
╠══════════════════════════════════════════════════════════╣
║  Verifier (keystone) ......... ✅ ok  (PASS self-test)   ║
║  Modules ..................... ✅ ok  (4/4 present)       ║
║  Scanner matrix ............. ⚠  6/18 ran (see #392)     ║
║  Routing .................... ✅ ok  (all specialists)   ║
║  Canary self-test ........... ✅ ok  (pos+tamper bite)   ║
╠══════════════════════════════════════════════════════════╣
║  Verdict: HEALTHY (scanners partial — degrades cleanly)  ║
╚══════════════════════════════════════════════════════════╝
```

Legend: ✅ ok · 🔧 healed · ❌ broken · ⚠ degraded-but-safe · ❓ inconclusive/unknown.

**Verdict rule (mechanical):** `HEALTHY` iff every concern is `ok`/`healed`
(scanner `degraded` allowed — degrades cleanly). Any `broken` ⇒ `UNHEALTHY`. Any
`inconclusive`/missing record ⇒ `INCONCLUSIVE`. The verdict is derived from the
records, so it cannot be greener than the worst real check.

## Idempotence & guardrails

- Healthy stack ⇒ no writes to tracked files, dashboard only. The self-tests
  operate exclusively in `mktemp -d` scratch dirs (`$S`, `$W`) and clean up via
  `trap … RETURN/EXIT`; the canary's own `.claude/review-canary-<ts>.json`
  artifact is the only durable side effect and is read-then-left (timestamped,
  non-clobbering). Re-running the doctor yields the same verdict.
- Heal only the safe, unambiguous concerns (executable bit, path typos). NEVER
  auto-rewrite the verifier or canary logic — a broken keystone or a non-biting
  gate is reported for human eyes, not patched blind.
- `--check` ⇒ never write (export `CHECK_ONLY=1`; the exec-bit heal degrades to a
  `broken` report instead of `chmod`).
- Exit nonzero if any concern is `broken` (keystone, routing, or a non-biting
  canary gate) or `inconclusive` — `absent` scanners are `⚠`, not failure. A
  green dashboard with a slipped tamper is the exact failure mode this skill
  exists to catch, so the canary concern gates the exit code too.

## Notes

- Companion to issue #392 (install the scanners this skill probes) and #393
  (this skill). Precedent: `/ktn`. The verifier self-test mirrors the functional
  test in this repo's review-verify-manifest commit.
- The canary concern is **two-sided by design**: a positive run that detects its
  own seeded defect (`review-canary.sh` → `detected==true`, C6) AND a negative
  run that watches the verifier reject a tampered manifest planting the C1
  (pasted-diff symbols) and C2 (relabeled `file_class`) bypasses. Facts come from
  `--print-facts` so diff-integrity can never masquerade as the rejection
  reason; the verdict requires the clean→PASS / tamper→FAIL flip, proving the
  gate actually bites rather than merely echoing "passed".
- Shallow clone / unresolvable BASE in a real consumer repo surfaces as
  `inconclusive` (verifier exit 3), never a false-green or a crash (C13).
