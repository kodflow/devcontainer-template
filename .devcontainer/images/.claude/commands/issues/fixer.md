---
name: issues:fixer
description: |
  Continuous issue-triage loop. Every 60s, never stops: pulls the repo's open
  issues, triages each (legitimate -> fix in a workflow + PR; false-positive ->
  reply & close; unclear -> ask for info & wait; duplicate -> link & close),
  then re-arms itself for the next minute. A self-rescheduling watchdog that
  keeps the issue tracker triaged and moving without supervision.
allowed-tools:
  - "Bash(git:*)"
  - "Bash(gh:*)"
  - "mcp__github__*"
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "Write(**/*)"
  - "Edit(**/*)"
  - "Task(*)"
  - "TaskCreate(*)"
  - "TaskUpdate(*)"
  - "TaskList(*)"
  - "ScheduleWakeup(*)"
  - "Workflow(*)"
---

# /issues:fixer — continuous issue triage & fix loop

A never-ending, minute-by-minute loop that keeps the repository's issue tracker
triaged and moving. Each **tick** pulls the open issues, decides what each one
is, acts, and re-schedules itself 60 seconds out. **It does not stop on its
own** — only an explicit user cancellation ends it.

This command is deliberately *thin and conservative*: it reads, classifies, and
either dispatches a fix, asks a question, or closes a non-issue. It never
auto-merges, never touches another repo, and never closes anything it is unsure
about.

## Cadence & lifetime (non-negotiable)

- **Every 60 seconds.** At the **end of every tick** — success, no-op, or
  partial — re-arm with:
  `ScheduleWakeup(delaySeconds: 60, prompt: "/issues:fixer", reason: "issue-triage tick")`.
  60s is the runtime floor; it keeps each tick short so the loop never drifts
  into a long-running job.
- **Never stops.** Always re-arm, even when nothing changed. Omitting the
  re-arm is the *only* way the loop dies, so only do that if the user explicitly
  asks to stop.
- **One tick = one pass.** Do exactly one triage pass, re-arm, end the turn.
  Never `sleep`-spin or busy-wait inside a tick.
- **Do NOT use a recurring cron** (`* * * * *`) for this. Recurring cron jobs
  auto-expire after 7 days; the self-`ScheduleWakeup` loop has no such cap and
  is the correct "never stops" mechanism.

## Scope & tools

- Operate **only** on the current repository's own issues. Resolve `owner/repo`
  from `git remote get-url origin`. Never act on another repo's tracker.
- Prefer the GitHub MCP tools (`mcp__github__*`); fall back to `gh` only when MCP
  is unavailable.

## Each tick

### 1. Pull
List open issues, e.g.
`gh issue list --state open --json number,title,body,labels,author,comments,updatedAt,assignees`.

### 2. Filter to triage targets
Skip an issue when it is already settled or waiting:
- carries `triaged-accepted` (a fix PR is open/linked) -> **skip**;
- carries `triaged-wontfix` or is closed -> **skip**;
- carries `needs-info` -> **skip _unless_** the author has commented since the
  label was applied (then re-triage with the new information);
- has a **human** maintainer label or assignee -> **skip** (never override a
  human triage decision).

Process at most **5 issues per tick** so a backlog burst can't make a tick long;
`log()` how many were deferred to the next tick.

### 3. Classify
Put each remaining issue into **exactly one** bucket:

| Bucket | Signal | Action |
|---|---|---|
| **Legitimate & actionable** | A real bug or in-scope feature with enough detail to act on (repro, expected-vs-actual, or a clear ask) | Label `triaged-accepted`; dispatch the **fix workflow** (step 4). |
| **False-positive / invalid** | Not a real defect — misuse, works-as-designed, out-of-scope, or unreproducible by design | Comment **why**, citing the file/function/behaviour; close; label `triaged-wontfix`. |
| **Needs info** | Plausible but underspecified — no repro, ambiguous ask, missing version/logs | Comment with **specific** questions; label `needs-info`; leave open; move on. |
| **Duplicate** | Same root cause as an existing issue | Comment linking the canonical issue; close as duplicate. |

### 4. Fix workflow (for `triaged-accepted`)
Run a `Workflow` that:
1. **reproduces / locates** the cause (parallel readers over the relevant code),
2. **implements** the fix on a `fix/issue-<N>-<slug>` branch (or `feat/…` for a
   feature),
3. **opens a PR** with `Closes #<N>`, a summary of the change, and how it was
   verified. **Never auto-merge** — CI and human review gate the merge.
4. **comments** on the issue linking the PR.

Match the project's own conventions (branch prefixes, commit format, test
commands) — read `CLAUDE.md`/`AGENTS.md`/`Makefile` first.

### 5. Re-arm (always)
`ScheduleWakeup(60, "/issues:fixer", "issue-triage tick")`.

## Triage discipline

- **Conservative on close.** Only close clear false-positives and duplicates.
  When genuinely unsure -> `needs-info`, never close.
- **Cite evidence.** Every false-positive reply names the file / function /
  documented behaviour that makes it a non-issue, so the author can challenge a
  wrong call.
- **Respect humans.** Never relabel, reassign, or close an issue a maintainer
  has already touched.
- **One reply per state change.** Don't re-ask the same question every tick — the
  `needs-info` label is the "already asked, waiting" marker.
- **Idempotent.** Re-running a tick must not double-post a comment, double-apply
  a label, or open a second PR for the same issue.

## Labels

`triaged-accepted`, `needs-info`, `triaged-wontfix` (plus GitHub's native
duplicate/closed state). Create a label on first use if it does not exist.

## Per-tick summary

End each tick with one terse line so the unattended loop stays auditable:

```
tick: <N> open · <A> accepted · <F> closed(false-positive) · <I> needs-info · <D> duplicate · <K> deferred
```

## Stopping

The loop only ends when the user explicitly says to stop (e.g. "stop
/issues:fixer"). On that, do a final pass if asked, then **do not re-arm**.
