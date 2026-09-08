---
name: fix
description: >-
  Open a defect and keep its trail. Records the bug where the project tracks
  work — a note store when one is grafted onto the session, otherwise a GitLab or
  GitHub issue — then cuts a branch named after the issue so forges and external
  trackers link the two. Refuses to open a bug with no reproduction: observed
  versus expected, and the steps that show it. Re-running on the same defect
  appends what was learned as a comment, so the original symptom and the
  investigation that followed stay readable side by side.
when_to_use: >-
  Use when existing behaviour is wrong — a crash, a wrong result, a regression, a
  flaky test. For something the project does not do yet, use /feature. To
  actually find the cause once the bug is opened, use /debug.
argument-hint: "<what is broken> [--no-branch] [--local] [--status]"
model: opus
allowed-tools:
  - "Bash(git:*)"
  - "Bash(gh:*)"
  - "Bash(glab:*)"
  - "Bash(curl:*)"
  - "Bash(jq:*)"
  - "Bash(bash:*)"
  - "Bash(python3:*)"
  - "Bash(date:*)"
  - "Bash(mkdir:*)"
  - "Bash(ls:*)"
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "Write(.claude/issues/*.md)"
  - "Edit(.claude/issues/*.md)"
  - "mcp__github__*"
  - "mcp__gitlab__*"
  - "AskUserQuestion"
  - "Skill(*)"
---

# /fix — open a defect, keep the trail

$ARGUMENTS

Same machinery as `/feature`, one hard difference: **a bug report without a
reproduction is not a bug report.** Everything below enforces that.

Read `../_shared/tracker.md` before acting — destination, ledger, comments and
branches are defined there and shared with `/feature`.

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<description>` | Open (or extend) the defect and cut its branch |
| `--no-branch` | Record it, do not touch git |
| `--local` | Force a local draft; do not contact any forge |
| `--status` | Show what is tracked, change nothing |
| `--help` | Print the help block and stop |

## --help

```
════════════════════════════════════════════════════════════════
  /fix — open a defect, keep the trail
════════════════════════════════════════════════════════════════

Usage: /fix <what is broken> [options]

  --no-branch   record only, no git
  --local       local draft, never contact a forge
  --status      show what is tracked, change nothing
  --help        this help

A defect needs: observed · expected · steps · scope.
Missing steps is a blocker, not a formality — an unreproducible
bug wastes whoever picks it up next, and that is often you.

Chain:  /fix → /debug → /challenge → /goal → /git
════════════════════════════════════════════════════════════════
```

**If `$ARGUMENTS` contains `--help`:** print it and STOP.

---

## Phases

### 0 — Locate

```bash
bash ~/.claude/skills/_shared/scripts/detect-tracker.sh
```

Destination per `../_shared/tracker.md` §1; existing-subject check per §3.
**Search the forge for an open issue with a similar symptom before creating** —
duplicate bug reports are worse than duplicate features, because two people then
investigate the same thing without knowing.

Found → phase 4. Not found → phase 1.

### 1 — Make the defect reproducible

Required before anything is published:

| | |
|---|---|
| **Observed** | what actually happens, quoted — the error, the wrong value, the trace |
| **Expected** | what should happen instead, and what says so (spec, test, docs, prior behaviour) |
| **Steps** | the shortest sequence that shows it |
| **Scope** | version/commit, environment, how often it reproduces |

Fill what you can from the repository yourself — `git log`, the failing test, the
error string — rather than asking for what you can read.

**Steps are the blocker.** If you cannot state how to see the failure, ask once
with `AskUserQuestion`, then:

- Still nothing → open it anyway, titled as a **report**, with a
  `## Not yet reproduced` section naming exactly what is missing. Do **not**
  fabricate steps, and do not silently drop the field.
- Intermittent → say so with the observed rate. "Fails about 1 run in 5 under
  `-race`" is a reproduction. "Sometimes fails" is not.

**Do not diagnose here.** The cause belongs to `/debug`, which will not accept a
fix without proving one. A guess written into the issue body reads as fact to
everyone who comes after.

### 2 — Show it before publishing

```
⏸  Open a defect on <destination>
   Title  : <title>
   Labels : <labels or "none">
   Reproduced: yes | no — <what is missing>
   Body   : <N> lines

   <the body>

   [1] open it   [2] show me the exact payload   [3] cancel
```

Nothing is created before an explicit yes.

### 3 — Create

Per `../_shared/tracker.md` §1, then the ledger at `.claude/issues/<slug>.md`
with `kind: fix` and a first `### <date> — reported` section.

### 4 — Extend (re-run)

The defect is already tracked. Append what this run learned:

- a narrower reproduction
- a ruled-out hypothesis — **worth recording**; it stops the next person
  re-walking it
- the root cause, once `/debug` has actually proven one
- a related failure that turns out to be the same defect

Comment, and a dated ledger section. Nothing new → say so and stop.

When a root cause is confirmed, say plainly in the comment what was believed
before and what replaced it. A trail that quietly drops a wrong hypothesis
teaches nobody.

### 5 — Branch

Per `../_shared/tracker.md` §4: `fix/<iid>-<slug>`. Refuse over a dirty tree —
especially here, where the uncommitted work may be the very thing that broke it.

### 6 — Hand off

```
/fix → /debug         reproduce, isolate, prove the cause
     → /challenge     debate the fix, lock it into a /goal prompt
     → /goal          execute
     → /git --commit  land it
```

`/debug` enforces no-fix-without-root-cause. Send it there rather than patching
the symptom from here.

---

## Guardrails

Everything in `../_shared/tracker.md` §5, plus:

| Action | Status |
|--------|--------|
| Invent reproduction steps | **FORBIDDEN** — mark `Not yet reproduced` |
| Write a diagnosis as fact before `/debug` proved it | **FORBIDDEN** |
| Start fixing | **FORBIDDEN** — this skill opens work |
| Drop a ruled-out hypothesis from the trail | **FORBIDDEN** — it has value |
| Open a duplicate without searching | **FORBIDDEN** |
| Branch over a dirty tree | **FORBIDDEN** |
