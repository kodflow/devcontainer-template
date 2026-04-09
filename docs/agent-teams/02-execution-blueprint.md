# Execution Blueprint: Agent Teams Refactor — Phases B1 → C-extended (single pass)

**Design reference:** `/home/vscode/.claude/plans/agent-teams-refactor-v3.md`
**Status:** Phase A ✅ complete (see context). This plan covers every remaining phase in concrete, ready-to-execute form.

---

## Context (why)

Phase A landed the infrastructure (tmux in Dockerfile.base, `install.sh` with `install_tmux` + `detect_agent_teams_support` + `--no-teams` flag, `shared/team-mode.md` canonical protocol, `team-mode-primitives.sh` library, `list-team-agents.sh` helper, super-claude capability-aware wrapper). Zero skill was modified. 19/19 Phase A exit criteria validated, 14 primitive tests pass, live runtime probe confirms correct degradation on the current VS Code container (`TEAMS_INPROCESS`).

The user now wants a **single execution blueprint** covering every remaining phase (B1 pilot `/review`, D hooks, C-minimal agents, B2-B7 skill migrations, F documentation+tests, C-extended metadata sweep) so `/do` can chew through all of it in one pass.

Goals of this plan:
- Concrete file paths with line numbers and anchor strings
- Exact templates to paste (not "add a block describing X")
- Deterministic dependencies between phases
- Parallelization hints so `/do` can dispatch efficiently
- Per-phase exit criteria + rollback

---

## Prerequisites (inherited from Phase A)

- [x] `.team-capability` file semantics defined
- [x] `team-mode-primitives.sh` available at `~/.claude/scripts/team-mode-primitives.sh`
- [x] `shared/team-mode.md` canonical protocol doc exists
- [x] `list-team-agents.sh` helper exists (returns `[]` pre-B1, as expected)
- [x] Claude Code 2.1.97 on the dev container
- [x] `jq`, `awk` available (Dockerfile.base)

---

# PHASE B1 — `/review` pilot

**Goal:** `/review` becomes the reference implementation. Lead = existing review dispatcher. 5 teammates (correctness, security, design, quality, shell) running in parallel when Runtime mode ∈ {TEAMS_TMUX, TEAMS_INPROCESS}. Full SUBAGENTS fallback for env-disabled or old Claude.

**Blast radius:** MEDIUM. Read-only review ⇒ zero file conflicts.
**Depends on:** Phase A.

## B1.1 — Insert runtime detection block in `review.md`

**File:** `/workspace/.devcontainer/images/.claude/commands/review.md` (249 lines)

**Anchor:** after the `## Quick Reference` section that ends around line 166. Before the guardrails table.

**Paste this block:**

```markdown
## Execution Mode Detection (Agent Teams)

@.devcontainer/images/.claude/commands/shared/team-mode.md

Before dispatching reviewers, determine the runtime mode via the canonical block from section 3 of `shared/team-mode.md`:

```bash
source "$HOME/.claude/scripts/team-mode-primitives.sh"
MODE=$(detect_runtime_mode)
```

Branch on `$MODE`:
- `TEAMS_TMUX` or `TEAMS_INPROCESS` → run `## TEAMS execution` (this file, below)
- `SUBAGENTS` → run `## SUBAGENTS execution (fallback)` (same content as legacy dispatch, unchanged)

The SUBAGENTS path must be functionally, schema-, and semantically equivalent to the legacy behavior. No new user-visible sections when running in fallback.
```

## B1.2 — Add `## TEAMS execution` section to `review/dispatch.md`

**File:** `/workspace/.devcontainer/images/.claude/commands/review/dispatch.md` (353 lines)

**Anchor:** Right before the first `Task(` call in the agent dispatch section (find with `grep -n "Task(" review/dispatch.md`).

**Paste the TEAMS section:**

```markdown
## TEAMS execution (Agent Teams mode)

Use this path when `$MODE ∈ {TEAMS_TMUX, TEAMS_INPROCESS}`.

### Step 1: Create 5 tasks via TaskCreate

Each task_description MUST embed a `task-contract v1` JSON block. Read-only review means `access_mode: "read-only"` and `owned_paths: []` (legitimate, collision check skips read-only).

Task 1 (correctness):
```
subject: Review PR #<N> for correctness
description:
<!-- task-contract v1
{"contract_version":1,"scope":"PR #<N>","access_mode":"read-only","owned_paths":[],"acceptance_criteria":["list all correctness findings with file:line and severity","apply Correctness Oracle Framework","return JSON array of findings"],"output_format":"report","assignee":"reviewer-correctness","depends_on":[]}
-->

Review the PR for correctness: invariants, state machines, concurrency, off-by-one, error surfacing. Use `mcp__grepai__grepai_trace_callers/callees` for impact. Return findings JSON.
```

Task 2 (security):
```
subject: Review PR #<N> for security
description:
<!-- task-contract v1
{"contract_version":1,"scope":"PR #<N>","access_mode":"read-only","owned_paths":[],"acceptance_criteria":["list all security findings","OWASP Top 10 + CWE references","taint analysis source→sink"],"output_format":"report","assignee":"reviewer-security","depends_on":[]}
-->

Review for security: OWASP, injection, secrets, crypto, supply chain.
```

Task 3 (design):
```
subject: Review PR #<N> for design
description:
<!-- task-contract v1
{"contract_version":1,"scope":"PR #<N>","access_mode":"read-only","owned_paths":[],"acceptance_criteria":["antipatterns","DDD/SOLID violations","architecture drift"],"output_format":"report","assignee":"reviewer-design","depends_on":[]}
-->

Review for design: patterns, DDD, SOLID, layering.
```

Task 4 (quality):
```
subject: Review PR #<N> for quality
description:
<!-- task-contract v1
{"contract_version":1,"scope":"PR #<N>","access_mode":"read-only","owned_paths":[],"acceptance_criteria":["complexity","smells","style violations","maintainability"],"output_format":"report","assignee":"reviewer-quality","depends_on":[]}
-->

Review for quality: complexity, smells, maintainability, style.
```

Task 5 (shell):
```
subject: Review PR #<N> for shell/CI safety
description:
<!-- task-contract v1
{"contract_version":1,"scope":"PR #<N>","access_mode":"read-only","owned_paths":[],"acceptance_criteria":["shell pitfalls","Dockerfile issues","CI/CD configuration risks"],"output_format":"report","assignee":"reviewer-shell","depends_on":[]}
-->

Review shell/Dockerfile/CI for dangerous patterns and missing safeguards.
```

### Step 2: Spawn 5 teammates

Natural language to Claude Code:

```
Create an agent team for review and spawn 5 teammates:
- use developer-executor-correctness, name it reviewer-correctness, claim the correctness task
- use developer-executor-security, name it reviewer-security, claim the security task
- use developer-executor-design, name it reviewer-design, claim the design task
- use developer-executor-quality, name it reviewer-quality, claim the quality task
- use developer-executor-shell, name it reviewer-shell, claim the shell task
Do NOT start implementing findings yourself — wait for all 5 teammates to finish.
```

### Step 3: Wait + synthesize + cleanup

- Wait for all 5 TeammateIdle events (lead stays passive during review).
- Collect teammate reports.
- Run `review/synthesis.md` Phase 12-13 exactly as in legacy mode — same report schema, same severity semantics.
- Call team cleanup at the end.

---

## SUBAGENTS execution (fallback)

<Rename the existing Phase 4 dispatch section from this line onward — no logic change. The existing Task() dispatches remain exactly as they are. Leave everything untouched except the section header.>
```

## B1.3 — Preserve existing dispatch as `SUBAGENTS` section

**File:** same `review/dispatch.md`

**Action:** rename the existing `## Phase 4: Parallel Dispatch` (or whatever it's called — find with `grep -n "^## " review/dispatch.md`) to `## SUBAGENTS execution (fallback)`. Leave all content untouched.

## B1.4 — Add success criteria section to `review.md`

**File:** `review.md`, append at the end:

```markdown
## Success criteria (TEAMS vs SUBAGENTS)

- **Functional equivalence**: same set of findings across modes on 3 real PRs (set comparison, not ordered)
- **Schema equivalence**: synthesis report has identical sections, severity levels, finding fields
- **Semantic equivalence**: a "critical" in legacy mode is still "critical" in TEAMS mode
- **Fallback invariant**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0 /review` runs the SUBAGENTS path unchanged
- **Performance floor** (TEAMS_TMUX): ≥ 1.5x faster wall-clock on a 30+ file PR
- **Pilot token ceiling**: ≤ 2.5x legacy cost (this ceiling is B1-specific, NOT universal)
- **Stability**: 5 consecutive runs without manual intervention
- **Hook cleanliness**: 0 false-positive TaskCreated rejections across 10 runs
```

## B1 exit criteria

- [ ] `review.md` contains `## Execution Mode Detection` block with `@shared/team-mode.md` reference
- [ ] `dispatch.md` contains `## TEAMS execution` + `## SUBAGENTS execution (fallback)` sections
- [ ] `list-team-agents.sh` now returns the 6 agents (5 executors + developer-specialist-review)
- [ ] Manual test: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0 /review` runs unchanged
- [ ] Manual test: normal `/review` dispatches 5 teammates in parallel
- [ ] `grep -c "task-contract v1" review/dispatch.md` ≥ 5

---

# PHASE D — Hooks (advisory, stdin-only, lifecycle-aware)

**Depends on:** Phase A. **Blast radius:** MEDIUM (hooks can interrupt work if misfired).

## D.1 — Create `task-created.sh`

**File:** `/workspace/.devcontainer/images/.claude/scripts/task-created.sh` (NEW, ~140 lines)

Full script as specified in V3 section "Phase D → Step D1", with these V3.1 additions:
- Sources `team-mode-primitives.sh` for `extract_task_contract`, `validate_contract_version`, `epoch_now`, `epoch_24h_ago`, `epoch_from_iso`, `team_mode_debug_log`
- Reads idempotency_key from contract; if present in registry, exits 0 silently (dedup)
- GC pass: moves non-active entries older than 24h to `task-registry.archive.jsonl`
- Collision check: only against `status=active AND access_mode=write AND assignee != new` entries
- Early return if `.team-capability == NONE`
- `chmod +x` after creation

**Exact skeleton** (paste and complete):

```bash
#!/bin/bash
# Hook: TaskCreated — advisory validation of task-contract v1
set +e

# Gate on capability
CAP=$(cat "$HOME/.claude/.team-capability" 2>/dev/null || echo NONE)
[ "$CAP" = "NONE" ] && exit 0

# Source primitives
PRIMITIVES="$HOME/.claude/scripts/team-mode-primitives.sh"
[ -f "$PRIMITIVES" ] || exit 0
# shellcheck disable=SC1090
source "$PRIMITIVES"

INPUT="$(cat 2>/dev/null || true)"
command -v jq >/dev/null 2>&1 || exit 0

SUBJECT=$(printf '%s' "$INPUT"     | jq -r '.task_subject // ""')
DESCRIPTION=$(printf '%s' "$INPUT" | jq -r '.task_description // ""')
TEAM=$(printf '%s' "$INPUT"        | jq -r '.team_name // "default"')
TASK_ID=$(printf '%s' "$INPUT"     | jq -r '.task_id // ""')
TEAMMATE=$(printf '%s' "$INPUT"    | jq -r '.teammate_name // ""')

team_mode_debug_log "task-created: id=$TASK_ID team=$TEAM assignee=$TEAMMATE"

# Minimum sanity
[ -z "$SUBJECT" ] && { echo "Task rejected: subject is empty" >&2; exit 2; }

REGISTRY_DIR="$HOME/.claude/logs/$TEAM"
REGISTRY="$REGISTRY_DIR/task-registry.jsonl"
ARCHIVE="$REGISTRY_DIR/task-registry.archive.jsonl"
mkdir -p "$REGISTRY_DIR"

# GC: move non-active entries older than 24h to archive
if [ -f "$REGISTRY" ]; then
    CUTOFF=$(epoch_24h_ago)
    TMP=$(mktemp)
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        AGE_ISO=$(printf '%s' "$line" | jq -r '.created_at // "1970-01-01T00:00:00Z"')
        AGE=$(epoch_from_iso "$AGE_ISO")
        STATUS=$(printf '%s' "$line" | jq -r '.status // "unknown"')
        if [ "$STATUS" = "active" ] || [ "$AGE" -gt "$CUTOFF" ]; then
            printf '%s\n' "$line" >> "$TMP"
        else
            printf '%s\n' "$line" >> "$ARCHIVE"
        fi
    done < "$REGISTRY"
    mv "$TMP" "$REGISTRY"
fi

# Extract contract
CONTRACT_JSON=$(extract_task_contract "$DESCRIPTION")

# Idempotency dedup
if [ -n "$CONTRACT_JSON" ] && [ -f "$REGISTRY" ]; then
    IDEM=$(printf '%s' "$CONTRACT_JSON" | jq -r '.idempotency_key // ""')
    if [ -n "$IDEM" ] && grep -q "\"idempotency_key\":\"$IDEM\"" "$REGISTRY" 2>/dev/null; then
        team_mode_debug_log "task-created: dedup by idempotency_key=$IDEM"
        exit 0
    fi
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Missing contract → advisory
if [ -z "$CONTRACT_JSON" ]; then
    echo "Task advisory: no task-contract v1 block (recommended for team tasks)" >&2
    jq -nc \
        --arg id "$TASK_ID" --arg team "$TEAM" --arg assignee "$TEAMMATE" \
        --arg subj "$SUBJECT" --arg now "$NOW" \
        '{id:$id, team:$team, assignee:$assignee, subject:$subj, contract:false, access_mode:null, owned_paths:[], status:"active", created_at:$now, completed_at:null, idempotency_key:null}' \
        >> "$REGISTRY"
    exit 0
fi

# Version check
if ! validate_contract_version "$CONTRACT_JSON"; then
    VER=$(printf '%s' "$CONTRACT_JSON" | jq -r '.contract_version // "unknown"')
    echo "Task advisory: contract_version=$VER not supported (expected 1), advisory mode" >&2
    jq -nc \
        --arg id "$TASK_ID" --arg team "$TEAM" --arg assignee "$TEAMMATE" \
        --arg subj "$SUBJECT" --arg now "$NOW" \
        '{id:$id, team:$team, assignee:$assignee, subject:$subj, contract:false, access_mode:null, owned_paths:[], status:"active", created_at:$now, completed_at:null, idempotency_key:null}' \
        >> "$REGISTRY"
    exit 0
fi

# Parse fields
ACCESS_MODE=$(printf '%s' "$CONTRACT_JSON" | jq -r '.access_mode // "write"')
OWNED=$(printf '%s' "$CONTRACT_JSON" | jq -c '.owned_paths // []')
IDEM=$(printf '%s' "$CONTRACT_JSON" | jq -r '.idempotency_key // ""')
CONTRACT_ASSIGNEE=$(printf '%s' "$CONTRACT_JSON" | jq -r '.assignee // ""')
[ -z "$TEAMMATE" ] && TEAMMATE="$CONTRACT_ASSIGNEE"

# Required-field validation
if [ "$ACCESS_MODE" = "write" ]; then
    OWNED_COUNT=$(printf '%s' "$OWNED" | jq 'length')
    if [ "$OWNED_COUNT" -eq 0 ]; then
        echo "Task rejected: access_mode=write requires at least one owned_paths entry" >&2
        exit 2
    fi
fi

# Collision check: active + write + different assignee + overlapping exact paths
if [ "$ACCESS_MODE" = "write" ] && [ -f "$REGISTRY" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        OTHER_STATUS=$(printf '%s' "$line" | jq -r '.status // ""')
        OTHER_MODE=$(printf '%s' "$line"   | jq -r '.access_mode // ""')
        OTHER_ASSIGNEE=$(printf '%s' "$line" | jq -r '.assignee // ""')
        [ "$OTHER_STATUS" = "active" ] || continue
        [ "$OTHER_MODE" = "write" ]    || continue
        [ "$OTHER_ASSIGNEE" != "$TEAMMATE" ] || continue
        OTHER_PATHS=$(printf '%s' "$line" | jq -c '.owned_paths // []')
        OVERLAP=$(jq -nc --argjson a "$OWNED" --argjson b "$OTHER_PATHS" \
            '$a | map(. as $p | $b | index($p)) | map(select(. != null)) | length')
        if [ "$OVERLAP" -gt 0 ]; then
            echo "Task rejected: owned_paths collision with active write task '$OTHER_ASSIGNEE'" >&2
            exit 2
        fi
    done < "$REGISTRY"
fi

# Record as active
jq -nc \
    --arg id "$TASK_ID" --arg team "$TEAM" --arg assignee "$TEAMMATE" \
    --arg subj "$SUBJECT" --arg mode "$ACCESS_MODE" \
    --arg idem "$IDEM" --argjson paths "$OWNED" --arg now "$NOW" \
    '{id:$id, team:$team, assignee:$assignee, subject:$subj, contract:true, access_mode:$mode, owned_paths:$paths, status:"active", created_at:$now, completed_at:null, idempotency_key:(if $idem == "" then null else $idem end)}' \
    >> "$REGISTRY"

team_mode_debug_log "task-created: recorded $TASK_ID status=active mode=$ACCESS_MODE"
exit 0
```

## D.2 — Patch `task-completed.sh` with lifecycle transition

**File:** `/workspace/.devcontainer/images/.claude/scripts/task-completed.sh` (existing, 47 lines)

**Action:** append before the final `exit 0` a block that transitions the matching registry entry from `active` to `completed`:

```bash
# V3.1: registry lifecycle transition
CAP=$(cat "$HOME/.claude/.team-capability" 2>/dev/null || echo NONE)
if [ "$CAP" != "NONE" ]; then
    REGISTRY="$HOME/.claude/logs/$TEAM_NAME/task-registry.jsonl"
    if [ -f "$REGISTRY" ] && [ -n "$TASK_ID" ]; then
        TMP=$(mktemp)
        NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        jq -c \
            --arg id "$TASK_ID" \
            --arg now "$NOW" \
            'if .id == $id and .status == "active" then .status = "completed" | .completed_at = $now else . end' \
            "$REGISTRY" > "$TMP" && mv "$TMP" "$REGISTRY"
    fi
fi
```

(The existing script already extracts `TEAM_NAME` and `TASK_ID`; reuse those variables. If variable names differ, adapt.)

## D.3 — Patch `teammate-idle.sh` with pending-task check

**File:** `/workspace/.devcontainer/images/.claude/scripts/teammate-idle.sh` (existing, 41 lines)

**Action:** insert right before the existing `exit 0`:

```bash
# V3.1: reject idle if active tasks still pending for this teammate
CAP=$(cat "$HOME/.claude/.team-capability" 2>/dev/null || echo NONE)
if [ "$CAP" != "NONE" ] && [ -n "$TEAMMATE" ]; then
    REGISTRY="$HOME/.claude/logs/${TEAM_NAME:-default}/task-registry.jsonl"
    if [ -f "$REGISTRY" ]; then
        PENDING=$(jq -rc --arg a "$TEAMMATE" \
            'select(.status == "active" and .assignee == $a) | .id' \
            "$REGISTRY" 2>/dev/null | wc -l)
        if [ "$PENDING" -gt 0 ]; then
            echo "You still have $PENDING active task(s) — continue working" >&2
            exit 2
        fi
    fi
fi
```

## D.4 — Wire TaskCreated in settings.json

**File:** `/workspace/.devcontainer/images/.claude/settings.json`

**Anchor:** right after the `TaskCompleted` block in the `"hooks"` object (around line 345). Add:

```json
"TaskCreated": [
  {
    "matcher": "",
    "hooks": [
      {
        "type": "command",
        "command": "/home/vscode/.claude/scripts/task-created.sh",
        "timeout": 5,
        "async": false
      }
    ]
  }
],
```

Note: `async: false` (not `true` like TaskCompleted) because TaskCreated must be able to exit 2 and actually block task creation.

## D exit criteria

- [ ] `task-created.sh` is executable and sources primitives
- [ ] `bash -n task-created.sh` passes; `shellcheck` passes
- [ ] `settings.json` validates via `jq empty`
- [ ] Manual test: empty `task_subject` stdin → exit 2
- [ ] Manual test: valid contract, no collision → exit 0, registry line added
- [ ] Manual test: collision → exit 2
- [ ] Manual test: TaskCompleted transitions `active` → `completed`
- [ ] Manual test: TeammateIdle with pending tasks → exit 2

---

# PHASE C-minimal — Deterministic agent metadata (post-B1)

**Depends on:** Phase A + B1 (needs `list-team-agents.sh` to return the actual post-B1 scope). **Blast radius:** LOW (purely declarative frontmatter).

## C.1 — Extract scope from migrated skills

```bash
bash .devcontainer/scripts/list-team-agents.sh > /tmp/c-minimal-scope.json
cat /tmp/c-minimal-scope.json
```

**Expected after B1 only:**
```json
["developer-executor-correctness","developer-executor-design","developer-executor-quality","developer-executor-security","developer-executor-shell","developer-specialist-review"]
```

Since this plan executes B1 through B7 in one pass, by the time C-minimal runs the scope will include ALL teammates from ALL 7 migrated skills. Expected final C-minimal scope (~24-28 agents):

```
developer-orchestrator           (lead)
developer-specialist-review      (lead for /review)
developer-commentator            (lead for /comment if migrated — NOT in B1-B7)
devops-orchestrator              (lead for /infra)
docs-analyzer-architecture       (lead for /docs)

developer-executor-correctness   (/review + /improve)
developer-executor-security      (/review + /improve)
developer-executor-design        (/review + /improve)
developer-executor-quality       (/review + /improve)
developer-executor-shell         (/review + /improve)

docs-analyzer-agents             (/docs)
docs-analyzer-commands           (/docs)
docs-analyzer-config             (/docs)
docs-analyzer-hooks              (/docs)
docs-analyzer-languages          (/docs)
docs-analyzer-mcp                (/docs)
docs-analyzer-patterns           (/docs)
docs-analyzer-structure          (/docs)

devops-specialist-aws            (/infra)
devops-specialist-gcp            (/infra)
devops-specialist-azure          (/infra)
devops-specialist-hashicorp      (/infra)

developer-specialist-<lang>      (/do — picked dynamically from plan, multiple)
```

`/do` MUST re-run `list-team-agents.sh` to get the exact list after B1-B7, not use the above prediction.

## C.2 — Apply metadata per agent

For each agent path returned by the extractor, add these frontmatter keys (idempotent):

```yaml
teamRole: lead       # for *-orchestrator, developer-specialist-review, docs-analyzer-architecture
# OR
teamRole: teammate   # for all executors, specialists, analyzers
teamSafe: true
```

And ensure the `tools:` list includes (adding missing entries only):
```yaml
tools:
  - <existing tools preserved>
  - SendMessage
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskGet
```

**Script to apply in one shot:**

```bash
# Read scope
SCOPE=$(bash .devcontainer/scripts/list-team-agents.sh)
echo "$SCOPE" | jq -r '.[]' | while read -r agent; do
    f=".devcontainer/images/.claude/agents/${agent}.md"
    [ -f "$f" ] || { echo "skip missing: $agent"; continue; }
    # Determine role
    case "$agent" in
        *-orchestrator|developer-specialist-review|docs-analyzer-architecture) ROLE=lead ;;
        *) ROLE=teammate ;;
    esac
    # Edit file (use yq or sed on frontmatter)
    echo "processing $agent → $ROLE"
    # Use Edit tool to insert teamRole/teamSafe after 'name:' line
done
```

Note: actual Edit tool invocations are done one-per-file by `/do` loop. The script above is illustrative; the real execution uses the harness Edit tool, not bash awk.

## C.3 — No body changes

The "When spawned as a TEAMMATE" documentation block is explicitly deferred to Phase C-extended. C-minimal is metadata only.

## C-minimal exit criteria

- [ ] Scope extracted deterministically via `list-team-agents.sh`
- [ ] Every agent in scope has `teamRole` and `teamSafe: true` in frontmatter
- [ ] Every agent in scope lists the 5 coordination tools
- [ ] No agent OUTSIDE the scope is touched
- [ ] `registry.json` regenerated if present (or left alone if auto-managed)

---

# PHASE B2 → B7 — Remaining skill migrations

Each follows the B1 template. Per skill: brief spec + teammate lineup + per-skill success criteria. The general pattern is identical:
1. Insert `## Execution Mode Detection` block referencing `@shared/team-mode.md`
2. Add `## TEAMS execution` section with TaskCreate batch + spawn instructions
3. Rename existing dispatch → `## SUBAGENTS execution (fallback)`
4. Append success criteria section

## B2 — `/plan`

**Files:** `commands/plan.md` (204 lines), `commands/plan/explore.md`, `commands/plan/synthesize.md`
**Lead:** `developer-orchestrator` (`teamRole: lead`)
**Teammates (4):** spawned to parallelize Phase 3.0 exploration
- `explorer-backend` → subagent type TBD, prompt "explore backend domain"
- `explorer-frontend` → subagent type TBD, prompt "explore frontend domain"
- `explorer-test` → subagent type TBD, prompt "explore existing tests + conventions"
- `explorer-patterns` → subagent type TBD, prompt "consult ~/.claude/docs/ for applicable patterns"

Since generic explorer agents don't exist as dedicated subagents yet, fall back to reusing `developer-specialist-review` with task-specific prompts, OR create 4 new light agents in `.devcontainer/images/.claude/agents/` named `explorer-*.md` with `teamRole: teammate`.

**Decision:** reuse existing `developer-specialist-review` with differentiated prompts — avoids creating 4 new agents and keeps C-minimal scope smaller.

**Task contracts:** `access_mode: "read-only"`, `owned_paths: []`.

**Success criteria (unique to /plan):**
- Functional: same plan structure (Context, Steps, Parallelization table, Risks)
- Token ceiling: ≤ 2x legacy (exploration is cheap)
- Performance floor: ≥ 1.5x on a 10-objective task

## B3 — `/docs`

**Files:** `commands/docs.md` (408 lines), `commands/docs/analyze.md`, `commands/docs/generate.md`, `commands/docs/scan.md`, `commands/docs/scoring.md`
**Lead:** `docs-analyzer-architecture` (`teamRole: both`)
**Teammates (8):** the existing `docs-analyzer-*` agents map 1:1 to Phase 4 analysis axes
- `docs-agents` using docs-analyzer-agents
- `docs-commands` using docs-analyzer-commands
- `docs-config` using docs-analyzer-config
- `docs-hooks` using docs-analyzer-hooks
- `docs-languages` using docs-analyzer-languages
- `docs-mcp` using docs-analyzer-mcp
- `docs-patterns` using docs-analyzer-patterns
- `docs-structure` using docs-analyzer-structure

8 teammates exceeds the soft cap of 3 and approaches the hard cap of 5 set in `shared/team-mode.md` section 6. **Decision:** split into 2 waves of 4 teammates each, or keep 8 with an explicit override comment in the skill.

**Recommended:** 2 waves of 4 — wave 1 dispatches (agents, commands, hooks, config), wave 2 dispatches (mcp, patterns, structure, languages). Lead waits between waves and feeds wave-1 output into wave-2 prompts. Token cost stays bounded.

**Task contracts:** `access_mode: "read-only"`, `owned_paths: []`, each analyzer scopes its own area.

**Success criteria:**
- Functional: same 8 analysis axes covered
- Token ceiling: ≤ 3x legacy (breadth justifies it)

## B4 — `/do`

**Files:** `commands/do.md` (210 lines), `commands/do/decompose.md`, `commands/do/loop.md`, `commands/do/worktree.md`, `commands/do/synthesis.md`
**Lead:** `developer-orchestrator`
**Teammates:** dynamic — picked from the approved plan's Parallelization table. Each worktree-tagged step becomes a teammate with `access_mode: "write"` and the file paths from the plan.

This is the most complex migration because the teammate count is plan-dependent. The TEAMS branch reads the plan's Parallelization table, computes the teammate set, and spawns up to 5 teammates (hard cap).

**Task contracts:** `access_mode: "write"`, `owned_paths` from the plan table per step.

**Success criteria:**
- Functional: same plan steps executed, same commits produced
- Token ceiling: ≤ 2.5x legacy
- Collision: 0 write collisions (enforced by task-created.sh)

## B5 — `/infra`

**Files:** `commands/infra.md` (134 lines)
**Lead:** `devops-orchestrator`
**Teammates (up to 4):** cloud specialists spawned only for clouds present in the repo (detected via `.tf` file scan)
- `cloud-aws` using devops-specialist-aws
- `cloud-gcp` using devops-specialist-gcp
- `cloud-azure` using devops-specialist-azure
- `cloud-hashicorp` using devops-specialist-hashicorp

**Task contracts:** usually `access_mode: "read-only"` for plan/validate, `"write"` for apply operations.

**Success criteria:**
- Functional: same Terraform plan output
- Token ceiling: ≤ 2x

## B6 — `/test`

**Files:** `commands/test.md` (200 lines), `commands/test/workflow.md`, `commands/test/playwright.md`
**Lead:** `developer-orchestrator`
**Teammates (3):**
- `test-unit` → developer-specialist-<lang>, read tests + execute
- `test-integration` → same, integration suite
- `test-e2e` → developer-specialist-review (or dedicated Playwright agent if exists)

**Task contracts:** `read-only` for analysis, `write` for generating missing tests.

**Success criteria:**
- Functional: same suite coverage reported
- Token ceiling: ≤ 2x

## B7 — `/improve`

**Files:** `commands/improve.md` (287 lines)
**Lead:** `developer-orchestrator`
**Teammates (4):** reuse executors
- `improve-design` using developer-executor-design
- `improve-quality` using developer-executor-quality
- `improve-security` using developer-executor-security
- `improve-shell` using developer-executor-shell

**Task contracts:** `access_mode: "write"`, `owned_paths` based on analysis scope passed by lead.

**Success criteria:**
- Functional: same improvement categories covered
- Token ceiling: ≤ 2.5x

## B2-B7 exit criteria (global)

- [ ] Each skill has `## Execution Mode Detection` + `## TEAMS execution` + `## SUBAGENTS execution (fallback)` sections
- [ ] Each skill has its own success criteria block
- [ ] `list-team-agents.sh` returns the union of all teammates across B1-B7
- [ ] Every skill's SUBAGENTS fallback is functionally equivalent to legacy (manual test per skill)
- [ ] No skill spawns > 5 teammates in a single wave

---

# PHASE F — Docs + audit + tests

**Depends on:** A, B1-B7, C-minimal, D. **Blast radius:** LOW.

## F.1 — Update CLAUDE.md files

### F.1.a — `/workspace/CLAUDE.md` (174 lines)

**Anchor:** in the `## Hooks (17 event types)` table, add a row for `TaskCreated`:
```markdown
| TaskCreated | Task payload contract validation + file conflict advisory |
```

**Append** a new section `## Agent Teams`:
```markdown
## Agent Teams

Parallel multi-agent execution for high-value skills. Gated by capability:
| Capability | Runtime | Where |
|---|---|---|
| TMUX | TEAMS_TMUX | Split-pane teammates |
| IN_PROCESS | TEAMS_INPROCESS | Shift+Down to cycle |
| NONE | SUBAGENTS | Legacy Task-tool dispatch |

Protocol: `@.devcontainer/images/.claude/commands/shared/team-mode.md`
Install: automatic via `install.sh`. Opt-out: `install.sh --no-teams`.
Runtime override: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0`.
Debug: `TEAM_MODE_DEBUG=1`.
```

### F.1.b — `/workspace/.devcontainer/images/.claude/CLAUDE.md` (111 lines)

Add a new section after `## 5.0 SKILLS`:

```markdown
## 5.1 AGENT TEAMS

Single source of truth: `commands/shared/team-mode.md`.

### Capability vs Runtime mode
| Capability (persisted) | Runtime mode (live probe) |
|---|---|
| TMUX | TEAMS_TMUX or TEAMS_INPROCESS |
| IN_PROCESS | TEAMS_INPROCESS or SUBAGENTS |
| NONE | SUBAGENTS |

### Migrated skills
`/review`, `/plan`, `/docs`, `/do`, `/infra`, `/test`, `/improve`

### NOT migrated
`/git`, `/secret`, `/vpn`, `/update`, `/init`, `/warmup`, `/prompt`, `/search`, `/feature` (sequential or conflict-prone)

### Contract
Every team task embeds a `<!-- task-contract v1 ... -->` JSON block. See section 4 of `shared/team-mode.md`.
```

### F.1.c — `/workspace/.devcontainer/CLAUDE.md` (39 lines)

Short addition to the `## Key Files` list:
```markdown
- `install.sh`: installs tmux + detects Agent Teams capability. `--no-teams` to opt out.
```

## F.2 — Extend `/audit` with Agent Teams dimension

**File:** `.devcontainer/images/.claude/commands/audit.md` (108 lines)

**Anchor:** add a 7th dimension after the existing 6 in the Dimensions section.

```markdown
### Dimension 7: Agent Teams (0-100)

Scoring:
- +25 if `.team-capability` exists and ≠ NONE
- +25 if `list-team-agents.sh` returns ≥ 5 agents (indicates ≥ 1 skill migrated)
- +20 if `shared/team-mode.md` exists and has ≥ 14 sections
- +15 if `task-created.sh` exists and is executable
- +10 if tmux is installed
- +5 if Claude Code version ≥ 2.1.32

Output row: `Agent Teams   [████████░░] 80/100   — IN_PROCESS, 6/7 skills migrated`

Data sources:
- `$HOME/.claude/.team-capability`
- `bash .devcontainer/scripts/list-team-agents.sh | jq length`
- `test -f .devcontainer/images/.claude/commands/shared/team-mode.md`
- `command -v tmux`
- `claude --version`
```

## F.3 — Regression tests

### F.3.a — Unit tests tier

**Directory (NEW):** `.devcontainer/tests/unit/`

**Files to create (9 scripts):**

```
.devcontainer/tests/unit/
├── run-all.sh                      # harness, runs each test-*.sh, tallies pass/fail, exits 0 on success
├── test-parse-contract.sh          # 10 cases: valid/empty/malformed/unknown version/extra whitespace/v2/single-line/double-block
├── test-capability-mapping.sh      # 6 rows of the compatibility matrix
├── test-terminal-classify.sh       # 10 cases: all known-compat/incompat/unknown
├── test-registry-lifecycle.sh      # created → completed / abandoned; self-overlap allowed
├── test-registry-gc.sh             # 24h+ entries move to archive
├── test-super-claude-wrap.sh       # 6 situations from the wrapper spec table
├── test-list-team-agents.sh        # fixture skill dir → expected JSON array
└── test-version-compare.sh         # 2.1.32 vs 2.1.97, 2.1.31, 2.1.32-beta, 2.2.0, empty
```

Each test is a plain bash script with `set -e`, sources `team-mode-primitives.sh`, runs assertions via simple `[ ... ] || { echo FAIL; exit 1; }`. No bats dependency.

### F.3.b — End-to-end harness

**File (NEW):** `.devcontainer/tests/test-agent-teams.sh`

10 scenarios from V3:
1. Nominal (tmux + env + claude ≥ 2.1.32) → TMUX
2. No tmux → IN_PROCESS
3. `--no-teams` → NONE + env stripped
4. Old Claude mock → NONE
5. VSCODE_PID set → downgrade TMUX → TEAMS_INPROCESS
6. TaskCreated collision → exit 2
7. TaskCreated missing contract → exit 0 + warning
8. Tools allowlist canary: spawn teammate with `tools: Read, Grep` only, try SendMessage (documents current behavior)
9. `/review` golden diff: run in both modes, compare synthesis
10. Pseudo-YAML legacy contract → advisory fallback (forward compat)

## F.4 — README + architecture docs

### F.4.a — `/workspace/README.md` (if exists)

Add a new section "Agent Teams" with 3 bullet points + link to `shared/team-mode.md`.

### F.4.b — `docs/architecture.md` (if exists)

Add Agent Teams to the component diagram: Lead + Teammates + Task registry + Hooks.

### F.4.c — `docs/workflows.md` (if exists)

Add a flowchart: capability detection → runtime mode → TEAMS vs SUBAGENTS branch.

## F exit criteria

- [ ] All 3 CLAUDE.md files updated
- [ ] `/audit` shows Agent Teams dimension with non-zero score
- [ ] `bash .devcontainer/tests/unit/run-all.sh` → 0 failures
- [ ] `bash .devcontainer/tests/test-agent-teams.sh` → 10 scenarios pass (or documented skips for scenarios requiring real PRs)
- [ ] README mentions feature + opt-out flag

---

# PHASE C-extended — Declarative metadata sweep (deferred last)

**Depends on:** all previous phases landed and stable. **Blast radius:** LOW (purely declarative).

## C-extended.1 — Scope

All agents NOT already in C-minimal. Expected count: 82 − (~24 in C-minimal) = **~58 agents**.

Extraction:
```bash
ALL=$(ls .devcontainer/images/.claude/agents/*.md | xargs -n1 basename | sed 's/\.md$//')
MINIMAL=$(bash .devcontainer/scripts/list-team-agents.sh | jq -r '.[]')
comm -23 <(echo "$ALL" | sort) <(echo "$MINIMAL" | sort)
```

## C-extended.2 — Apply

For each of the ~58 remaining agents:
1. Add `teamRole: teammate` + `teamSafe: true` to frontmatter (idempotent, skip if present)
2. Append the "When spawned as a TEAMMATE" documentation block (from V3 Step C4 template) at the end of the file:

```markdown
---

## When spawned as a TEAMMATE

You are an independent Claude Code instance. You do NOT see the lead's conversation history.

- Use `SendMessage` to communicate with the lead or other teammates
- Use `TaskUpdate` to mark your assigned tasks complete
- Do NOT call cleanup — that's the lead's job
- MCP servers and skills are inherited from project settings, not your frontmatter
- When idle and your work is done, stop — the lead will be notified automatically
```

## C-extended.3 — Update `registry.json` if present

If `.devcontainer/images/.claude/agents/registry.json` is human-managed, add `teamRole` field alongside existing metadata. If auto-managed, leave it alone.

## C-extended exit criteria

- [ ] `jq '[.[] | select(.teamRole)] | length' registry.json` == 82 (or comparable count via filesystem scan)
- [ ] No runtime regression (pure frontmatter + doc addition)
- [ ] Every teammate agent has the documentation block

---

# Parallelization table (for `/do` worktree dispatch)

`/do` can parallelize phases that touch disjoint file sets. After A (done), the optimal order is:

| Step | Files | Lead agent | Worktree | Depends on | Can parallel with |
|---|---|---|---|---|---|
| B1 | review.md + review/dispatch.md (x2 sections) | developer-specialist-review | yes | — | D |
| D | task-created.sh (NEW) + task-completed.sh + teammate-idle.sh + settings.json | developer-executor-shell | yes | — | B1 |
| C-minimal | ~24 agent frontmatter edits | developer-commentator | yes | B1 (for scope) | B2 (different file sets) |
| B2 /plan | plan.md + plan/explore.md + plan/synthesize.md | developer-orchestrator | yes | A | B3, B5, B6 |
| B3 /docs | docs.md + docs/analyze.md | developer-orchestrator | yes | A | B2, B5, B6 |
| B4 /do | do.md + do/loop.md + do/decompose.md | developer-orchestrator | yes | A | (none — touches harness behavior) |
| B5 /infra | infra.md | devops-orchestrator | yes | A | B2, B3, B6 |
| B6 /test | test.md + test/workflow.md | developer-orchestrator | yes | A | B2, B3, B5 |
| B7 /improve | improve.md | developer-orchestrator | yes | B1 (uses same executors) | F |
| F docs | 3 CLAUDE.md + audit.md + tests/unit/ (9 files) + tests/test-agent-teams.sh + README + docs/*.md | developer-orchestrator | yes | B1-B7, D, C-minimal | C-extended |
| C-extended | ~58 agent files | developer-commentator | yes | F | (none — final step) |

**Recommended merge order** (sequential where dependencies force it, parallel otherwise):

```
(B1 ∥ D)                           # 2 PRs in parallel
    ↓
(C-minimal)                         # 1 PR, uses post-B1 scope
    ↓
(B2 ∥ B3 ∥ B5 ∥ B6 ∥ B4)            # 5 PRs in parallel (B4 touches do harness, flag as risky)
    ↓
(B7)                                # depends on C-minimal having run on executors
    ↓
(F)                                 # docs + tests catching up
    ↓
(C-extended)                        # final declarative sweep
```

Total: 11 PRs. With parallel dispatch: 5 waves. Each PR independently revertible.

---

# Testing strategy (full plan)

## Per-phase live verification (during `/do`)

- **B1**: `bash -n` on edited files, manual invocation of `/review` in both modes on this very repo
- **D**: fire `task-created.sh` with 5 stdin payloads (valid, missing, malformed, collision, idempotency), assert exit codes
- **C-minimal**: `bash .devcontainer/scripts/list-team-agents.sh | jq length` before and after, assert count ≥ 6
- **B2-B7**: same as B1 per skill, plus compare SUBAGENTS output to legacy on a fixture task
- **F**: `bash .devcontainer/tests/unit/run-all.sh` (all 9 unit tests), `bash .devcontainer/tests/test-agent-teams.sh` (10 e2e)
- **C-extended**: frontmatter validation only, no runtime test

## Continuous checks during `/do` loop

- After every file edit: `bash -n <file>` if shell, `jq empty <file>` if JSON, `awk` smoke for markdown frontmatter
- After every phase: re-run `list-team-agents.sh` to verify scope grows as expected

---

# Rollback strategy

Each phase = 1 PR, revertible independently.

| Phase | Rollback cost |
|---|---|
| B1 | Revert 3 files, no state |
| D | Revert scripts + settings.json, delete `~/.claude/logs/*/task-registry.jsonl` |
| C-minimal | Revert ~24 frontmatter edits, zero runtime impact |
| B2-B7 | Revert per-skill (one PR each) |
| F | Revert docs, delete tests/unit/, delete tests/test-agent-teams.sh |
| C-extended | Revert ~58 frontmatter + doc blocks |

**Global kill switch:** `echo NONE > ~/.claude/.team-capability` forces all migrated skills to SUBAGENTS path on next invocation. No other action required.

**User opt-out:** re-run `bash install.sh --no-teams` — strips env var, rewrites capability, no revert needed.

---

# Risks & Mitigations (execution-specific)

| Risk | Mitigation |
|---|---|
| `/do` dispatches too many parallel worktrees and context explodes | Parallelization table caps at 5 concurrent; phases beyond 5 are sequential |
| B4 (/do self-modifying) breaks the harness mid-run | Manual step: B4 runs LAST in its wave, isolated worktree, explicit manual review before merge |
| C-minimal scope mis-predicted because B1-B7 reference an agent I didn't anticipate | `list-team-agents.sh` is the source of truth — re-run after every B-step |
| Hooks misfire and block legitimate work | All hooks gated on `.team-capability != NONE`; instant kill switch available |
| `/review` golden diff doesn't match because of prompt-level changes | Success criteria explicitly say "functional + schema + semantic equivalence", not byte-for-byte |
| Tools allowlist changes in future Claude Code | F3 scenario 8 is the canary; explicit tool declarations in C-minimal are belt-and-braces |
| Contract format drift (v1 → v2) | `contract_version` field + `validate_contract_version`; advisory fallback on unknown |
| Registry grows unboundedly | GC in `task-created.sh` on every invocation; archive sibling; never writes to Claude internals |

---

# What `/do` must do on the next pass

1. Read this plan file
2. Create a TaskCreate batch for the 11 phases (1 task per phase, with depends_on from the parallelization table)
3. For each phase in order (respecting the dependency graph):
   a. Read the phase section
   b. Apply the exact edits described (file paths + templates are concrete)
   c. Run the phase exit criteria checks
   d. If any fails, stop and report; do NOT proceed to the next phase
4. At the end: run full regression tests (F3 unit + e2e)
5. Produce a summary with file change counts, test pass/fail, and `/audit` Agent Teams dimension score

The plan is explicitly designed so `/do` does not need to re-read `agent-teams-refactor-v3.md` during execution — all design decisions are frozen, only implementation details remain.

---

# Frozen invariants (carried from V3.1)

- Two taxonomies: Capability (persisted) vs Runtime mode (live)
- Capability file is a HINT; live probe is SOURCE OF TRUTH
- Stdin hook payloads do NOT contain file paths (verified against context7)
- `~/.claude/tasks/` and `~/.claude/teams/` are READ-ONLY best-effort (never enforcement)
- `task-contract v1` is JSON embedded in HTML comment, parsed via jq
- Hooks are ADVISORY by default, strict only on explicit contract violations
- Terminal classification: known-compatible | known-incompatible | unknown (heuristic, test-maintained)
- `/review` is the pilot; all other skills follow its template
- Token cost ceilings are per-skill, not global
- C-minimal scope is DETERMINISTIC via `list-team-agents.sh`
- `super-claude` never nests tmux; bypass via `SUPER_CLAUDE_NO_TMUX=1`
- `TEAM_MODE_DEBUG=1` enables stderr decision logs
