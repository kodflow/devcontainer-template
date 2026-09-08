# /challenge — Phases 1-2: the panel and the rounds

## Phase 1 — who is actually on the panel

The panel is **never three generic reviewers**. It is three lenses *plus every
installed specialist whose domain the plan touches*, and the specialists are the
half that catches the errors a generalist cannot see.

### 1.1 What does the plan touch?

Read the plan and the files it names. Do not guess from the prose alone — open
what it points at.

```bash
ls ~/.claude/agents/*.md | xargs -n1 basename | sed 's/\.md$//'
```

Route on evidence using the shared table in `../_shared/specialists.md` — one
specialist per matched domain. That file is the single source of truth for the
routing, so `/challenge`, `/feature` and `/fix` never disagree about who reviews
what.

**Every match is dispatched.** A plan touching Go and Kubernetes gets both, and
the panel is six reviewers, not three. Skipping a matched specialist because the
panel "feels big enough" is exactly how a plan ships with a defect the installed
specialist would have named on sight.

**No match at all** — a pure prose, process or documentation plan — is the only
case where the panel is the three lenses alone. Say so explicitly; do not let it
pass as normal.

### 1.2 The full panel

| Reviewer | Lens | Model | Availability |
|----------|------|-------|--------------|
| **architect** | Is the shape right? Boundaries, coupling, what this makes hard later. | opus | always |
| **sceptic** | What is assumed and unproven? Where does this fail? | opus | always |
| **operator** | What happens at 3am? Rollback, migration, blast radius, observability. | sonnet | always |
| **`<specialist>`** | Is this correct *in this technology*? Idiom, footgun, version reality. | its own | one per matched domain |
| **codex** | An outside-the-family read of the same plan. | — | only when the CLI answers and not `--no-codex` |

The three lenses are chosen to *conflict*: the architect wants the boundary, the
operator wants the smallest deployable change, the sceptic wants evidence for
both. Specialists conflict with all three, because a language's actual
constraints do not care what shape anyone wanted.

### 1.3 Every specialist must cite what it checked

`../_shared/specialists.md` defines what a specialist owes back: `consulted`
(the documentation actually checked, per claim that needed it) and `unverified`
(what it could not confirm). Put that requirement in every specialist brief.

**A technology objection with an empty `consulted` list is a memory claim.**
Route it to *needs the user* or send it back for verification — do not accept it
as evidence. That is the whole reason for dispatching a specialist rather than
reasoning about the technology yourself: not that it knows more, but that it
goes and checks.

### 1.4 Codex

Invoked as a subprocess with the plan on stdin and its verdict read from stdout,
briefed the same as the others. A non-zero exit, a timeout or empty output means
Codex did not review — say so and continue. Never fabricate its verdict, and
never let its absence quietly shrink the panel.

### 1.5 Announce the panel

Every run, before the first round:

```
Plan touches: Go · Kubernetes · GitHub Actions
Panel (6): architect (opus) · sceptic (opus) · operator (sonnet)
         + developer-specialist-go · devops-specialist-kubernetes
         + tooling-specialist-github-actions
         codex: absent (CLI not installed)
```

If a domain matched but its specialist is not installed, say that too — it is a
gap in the panel, and the user should know the plan went unreviewed from that
angle rather than assume it passed.

## Phase 2 — the rounds

`N = --concurrency` (default 3, hard max 6). Each round is four steps.

### 2.1 Argue — all reviewers, one message, in parallel

Each reviewer gets the **plan text inline**, not a path. A reviewer that has to
go fetch the plan spends its turns fetching instead of judging.

The brief, per reviewer:

```
Here is a plan. Argue against it from the <lens> lens.

<the full plan>

Constraints this project has already accepted:
<the MUST/MUST NOT constraints from the ledger, verbatim>

Return objections only. For each: what breaks, how you know, and what would
have to change. An objection with no concrete failure behind it is noise —
leave it out. If the plan is sound from your lens, say so and stop; do not
manufacture an objection to look useful.
```

Structured return per objection: `severity` (blocking / material / minor),
`claim`, `evidence` (file:line, or the plan line it contradicts), `remedy`.

### 2.2 Triage — you, not a reviewer

Judge each objection against the plan and the codebase:

| Verdict | Meaning | Effect |
|---------|---------|--------|
| **accepted** | It is right; the plan changes | rewrite in 2.4 |
| **rejected** | Provably wrong — cite what proves it | recorded, never silently dropped |
| **needs the user** | Cannot be settled from the code or the plan | phase 2.3 |

A reviewer contradicting another is normal and often the most useful signal.
Do not average them: pick, and say why.

**Rejected objections are recorded in the output.** A reviewer that was wrong
about something specific is information for the next round.

### 2.3 Ask — the moment a difficulty appears

Any objection landing in *needs the user* stops the round and becomes a question
**immediately**. Not batched to the end, not resolved by assumption.

`AskUserQuestion`, one question per genuine difficulty, and each question:

- offers exactly **3 options**
- marks **one as recommended** — put it first and append `(Recommended)` to its
  label. **This is mandatory.** A question with no recommendation pushes the
  decision back without the analysis that earned it.
- the free-text answer is always available (the tool adds it), so a fourth path
  is never blocked

Each option's description says what it costs, not just what it is. "Simpler, but
you cannot add per-tenant limits later without a migration" is useful; "simpler
approach" is not.

Cap: **4 questions per round.** Beyond that the plan is too unformed to debate —
say so and send it back to `/plan`.

Answers become **constraints for every later round**. A reviewer that re-opens a
settled question is answered with the decision, not re-argued.

### 2.4 Rewrite — the plan changes, not its defence

Apply every accepted objection and every answer to the plan text itself. The
rewritten plan is what round N+1 argues with.

**Do not defend the plan.** If an objection is accepted, the plan was wrong; say
what changed. Arguing back is how three rounds produce zero improvement.

### Stopping

Stop at the first of:

- a round produces **no accepted objection** — converged, and the remaining
  rounds are not spent
- `N` rounds are done
- the user answers a question in a way that invalidates the plan's premise —
  stop and say the plan needs redoing, do not patch around it

Report the round count and why it stopped. A run that converged in one round is
a better result than one that used all three, not a lazier one.

## Recording

Per round, keep: objections raised, verdict on each, questions asked and
answered, what changed in the plan. This becomes the *What changed* / *What you
decided* / *What is still open* sections of the handover, and — when the plan
belongs to a `/feature` or `/fix` subject — the comment posted on its issue.

## Guardrails

| Action | Status |
|--------|--------|
| Name a reviewer that did not run | **FORBIDDEN** |
| Fabricate a Codex verdict when the CLI is absent | **FORBIDDEN** |
| Manufacture an objection to fill a round | **FORBIDDEN** |
| Batch a difficulty to the end instead of asking when it appears | **FORBIDDEN** |
| Ask without marking one option recommended | **FORBIDDEN** |
| Ask more than 4 questions in a round | **FORBIDDEN** — send it back to `/plan` |
| Drop a rejected objection from the record | **FORBIDDEN** |
| Defend the plan instead of rewriting it | **FORBIDDEN** |
| Re-argue a question the user already answered | **FORBIDDEN** |
| Run past `--concurrency` | **FORBIDDEN** |
