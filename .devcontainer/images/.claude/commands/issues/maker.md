---
name: issues:maker
description: Dependency-driven development loop. When your goal is blocked on an upstream dependency you don't control, file precise upstream issues for the gaps, monitor them in real time, advance the unblocked work, and auto-resume the blocked work the moment an issue is resolved or a new version ships. Use when migrating onto / co-evolving with a fast-moving dependency (SDK, library, service, platform) whose missing features gate your progress.
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Monitor", "TaskStop", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "mcp__github__issue_write", "mcp__github__issue_read", "mcp__github__list_issues", "mcp__github__search_issues", "mcp__github__add_issue_comment", "mcp__github__list_tags", "mcp__github__list_releases", "mcp__github__get_file_contents", "mcp__github__create_pull_request", "WebFetch"]
model: sonnet
---

# /issues:maker — Dependency-driven development loop

> Make real-time progress on a goal that is partly blocked by a dependency you
> don't own. Instead of stalling, you **file precise upstream issues for what's
> missing, monitor them live, ship the unblocked parts, and auto-resume the
> blocked parts when upstream lands them.** One armed monitor + a clean
> blocked/unblocked split = forward motion every turn.

This skill generalizes the "monitor + file issues + block/resume" pattern: it is
not tied to any one dependency. Point it at any upstream repo and goal.

---

## Arguments

| Pattern | Action |
|---------|--------|
| _(none)_ | Full loop on the active goal/plan: assess → file gaps → arm monitor → advance unblocked → resume on events |
| `--repo <owner/repo>` | Upstream dependency repo to file/track issues against (else inferred from the plan / `go.mod` / manifest) |
| `--plan <path>` | Plan file holding the goal + blocking map (default: the session's active plan) |
| `--check` | Read-only: print the blocker/issue/version status table. No issues filed, no monitor armed |
| `--file` | Only the gap-assessment + issue-filing phase (dedup against existing issues), then stop |
| `--watch` | Only (re)arm the monitor on the currently-open blocking issues |
| `--resume` | Run the post-event path now: re-check issue/version state, bump the dep, continue blocked work |
| `--help` | Print this file's summary and STOP |

**IF the argument contains `--help`**: print this file's summary and STOP.

---

## Core principle

> Blocked ≠ idle. Every turn, separate the goal into **unblocked** (do it now)
> and **blocked-on-upstream** (file it, monitor it, wait). Never hand-roll a
> feature that belongs upstream just to avoid waiting — and never sit idle when
> unblocked work remains.

---

## Phase 0 — Load context

1. Resolve the **goal** (the active `/goal`, or the `## Goal`/objective in `--plan`).
2. Resolve the **upstream repo** (`--repo`, else from the plan, else from the
   dependency manifest: `go.mod`/`package.json`/`Cargo.toml`/`pyproject.toml`).
3. Read the plan's **blocking map** — which work items depend on which upstream
   capability. If none exists, derive it now (see Phase 1).

> The plan file is the source of truth and the resume anchor. Keep it updated
> (status line + blocking map + filed-issue table) so any future turn — or a
> fresh session after rebuild — can resume from it.

## Phase 1 — Assess (split blocked vs unblocked)

For each work item in the goal, classify:

- **Unblocked** — the upstream capability exists and is *consumable* (see the
  consumability check below). → schedule for this turn.
- **Blocked** — needs an upstream capability that is missing, broken, or merged
  but not yet released. → candidate for an issue.

**Consumability check (do not trust "merged" — verify a usable release):**
clean-room install the dependency at the target version from a throwaway dir and
build a trivial consumer. Merged-to-main ≠ consumable (no tag, nested-module
quirks, relative `replace` directives, placeholder requires all bite here).
Example (Go):

```bash
cd "$(mktemp -d)" && go mod init probe && \
  go get <module>/<pkg>@<version> && go build ./...
```

## Phase 2 — File issues for the gaps (your judgment gate)

For each blocked item, **judge** whether the missing capability belongs
upstream (reusable, generic, not your business logic) or in your own project.
Only file upstream for the former.

Before filing, **dedup**: `search_issues` / `list_issues` on the upstream repo;
update or comment on an existing issue instead of creating a duplicate.

Write issues that are **detailed AND project-agnostic** — justify the feature
for *any* consumer, not just your project (your repo is at most one cited
example). Each issue should carry: problem (with file:line evidence if known),
who needs it generally, proposed API/surface, semantics & platform notes,
and binary acceptance criteria. File via `mcp__github__issue_write`.

Keep an **umbrella/tracking issue** linking the set when there are several.

## Phase 3 — Arm the monitor (real-time wait)

Arm ONE persistent `Monitor` that polls the open blocking issues (and/or the
release feed) and emits exactly when a blocker clears. Poll remote APIs at
≥15-min intervals; emit only on a state transition you'd act on.

```bash
# Template: emit when a tracked issue flips to closed (per-issue, once).
prev=""
while true; do
  st=$(curl -fsS --max-time 20 "https://api.github.com/repos/<owner>/<repo>/issues/<N>" \
        2>/dev/null | jq -r '.state // "unknown"')
  [ "$st" = "closed" ] && [ "$prev" != "closed" ] && \
    echo "<repo>#<N> CLOSED -> <what it unblocks> | resume <plan-path>"
  prev="$st"
  sleep 900
done
```

Rules:
- **One monitor for the current blocker set.** When the set changes (a new gap,
  or one resolved), `TaskStop` the old monitor and arm a fresh one.
- `persistent: true` (it must outlive the turn).
- Also watch the **version/tag feed** when "merged but unreleased" is the blocker
  (`git ls-remote --tags` or `list_tags`) — closing an issue and shipping a
  consumable version are two different events; watch whichever gates you.

## Phase 4 — Advance the unblocked work

Do the Phase-1 unblocked items now, smallest verifiable slice first. Keep every
project gate green per slice (build, tests, lint). Update the plan's status +
task list as slices land. This is what makes the loop *progress*, not just wait.

## Phase 5 — Resume on event (the loop closes)

When the monitor emits (or on `--resume`):
1. Re-verify with the **consumability check** (closed issue ≠ released).
2. Bump the dependency to the new version; re-run the gates.
3. Move the now-unblocked item from "blocked" to "in progress"; do it.
4. Re-arm the monitor on the *remaining* open blockers (Phase 3).
5. If nothing is blocked and the goal's unblocked work is done → the loop is
   complete; report and stop the monitor.

---

## Idempotency & guardrails

- **Re-running is safe.** Phase 2 dedups against existing issues; Phase 3 stops
  the stale monitor before arming a new one; Phase 4 only does undone slices.
- **Never duplicate an upstream issue** — comment/update instead.
- **Never hand-roll upstream's job** locally to dodge the wait (unless the user
  explicitly authorizes a temporary `replace`/vendored shim, kept out of
  committed manifests).
- **Never file business-logic gaps upstream** — only generic, reusable
  capabilities pass the Phase-2 judgment gate.
- **Don't commit/push unless asked**; work on a feature branch.
- **One armed monitor at a time** for the current goal's blocker set; poll
  remote APIs at ≥15-min intervals to respect rate limits.
- Keep the **plan file** authoritative (status, blocking map, issue table) so a
  post-rebuild session resumes cleanly.

## Boundaries

| `/issues:maker` owns | It does NOT |
|---|---|
| Splitting goal into blocked/unblocked | Implement upstream's features for it |
| Filing + dedup + tracking upstream issues | Merge/close upstream issues |
| Arming the live monitor + resume-on-event | Replace your own well-scoped work with vendoring |
| Driving unblocked slices to green | Commit/push without the user asking |
