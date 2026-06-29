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
| Command | `.devcontainer/images/.claude/commands/review.md` | `~/.claude/commands/review.md` |
| Modules | `…/commands/review/{dimensions,deterministic,graph,manifest}.md` | `~/.claude/commands/review/*.md` |
| Router | `…/.claude/scripts/route-agent.sh` + `agents/routing-table.jsonl` | `~/.claude/scripts/…` |

Prefer the workspace source in the template repo; fall back to the runtime copy
in consumer repos (same precedence rule as the pre-commit hook).

## Execution — dispatch 5 concern agents in PARALLEL

Send all five in one message (independent, no shared writes). Each returns a
`{concern, status: ok|healed|broken, detail}` record.

### Concern 1 — Verifier (keystone)
- `command -v bash git jq python3 sha256sum awk wc` — all required tools present.
- Verifier file exists and is executable (`chmod +x` to heal).
- `bash -n` clean; `shellcheck -S warning` clean if shellcheck present.
- **Self-test:** in a scratch `git init` repo (or against `HEAD~1..HEAD` of this
  repo), run `--print-facts` and assert it emits `{diff_hash, hunks_total}`; then
  build a minimal manifest copying those facts and assert a full run prints
  `VERIFIER: PASS` exit 0. A nonzero/garbled result ⇒ `broken` (do not auto-edit
  the script; report the failing check — a broken keystone needs human eyes).

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

### Concern 5 — Canary self-test
- Seed a known defect into a scratch copy (e.g. an obvious nil-deref / injection)
  and assert the Phase 0.8 canary description in `review.md` would flag it — i.e.
  the canary wiring exists and `canary: passed|failed` is honored by the verifier
  (check 5 / approve-eligibility). Report `ok` when the canary contract is intact.

## Synthesize — ASCII dashboard

```
╔══════════════════════════════════════════════════════════╗
║  /review-doctor — evidence-bound review stack             ║
╠══════════════════════════════════════════════════════════╣
║  Verifier (keystone) ......... ✅ ok  (PASS self-test)   ║
║  Modules ..................... ✅ ok  (4/4 present)       ║
║  Scanner matrix ............. ⚠  6/18 ran (see #392)     ║
║  Routing .................... ✅ ok  (all specialists)   ║
║  Canary self-test ........... ✅ ok                      ║
╠══════════════════════════════════════════════════════════╣
║  Verdict: HEALTHY (scanners partial — degrades cleanly)  ║
╚══════════════════════════════════════════════════════════╝
```

Legend: ✅ ok · 🔧 healed · ❌ broken · ⚠ degraded-but-safe.

## Idempotence & guardrails

- Healthy stack ⇒ no writes, dashboard only.
- Heal only the safe, unambiguous concerns (executable bit, path typos). NEVER
  auto-rewrite the verifier logic — a broken keystone is reported, not patched
  blind.
- `--check` ⇒ never write.
- Exit nonzero only if a concern is `broken` (the keystone or routing) — `absent`
  scanners are `⚠`, not failure.

## Notes

- Companion to issue #392 (install the scanners this skill probes) and #393
  (this skill). Precedent: `/ktn`. The verifier self-test mirrors the functional
  test in this repo's review-verify-manifest commit.
