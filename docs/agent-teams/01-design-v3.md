# Implementation Plan V3 (final hardened): Agent Teams built-in to devcontainer-template

Context: /workspace/.claude/contexts/agent-teams-refactor.md (sections 1-7)
Supersedes: V2 `/home/vscode/.claude/plans/agent-teams-refactor-v2.md`
Supersedes: V1 `/home/vscode/.claude/plans/sprightly-tumbling-rabin.md`
Research verified: code.claude.com via context7 on 2026-04-09

---

## Changelog V3 → V3.1 (polish)

1. **Delimiter tolerance**: `extract_task_contract` now accepts `<!-- task-contract v<N>` with flexible whitespace and any version number. Parser becomes forward-compatible with future contract versions.
2. **`contract_version` field**: required in every contract block. Currently `1`. Future-proofs against v2 migration.
3. **`idempotency_key` field**: optional. When present, `task-created.sh` deduplicates on repeated TaskCreated invocations (edge case: retry after transient failure).
4. **`TEAM_MODE_DEBUG=1` env var**: when set, `team-mode-primitives.sh` logs every runtime decision (capability read, live probe, terminal class, registry transitions) to stderr. Off by default.
5. **`date` portability**: GNU vs BSD vs busybox `date` abstracted behind `epoch_now`, `epoch_from_iso`, `epoch_24h_ago` helpers in `team-mode-primitives.sh`. Tested in `test-version-compare.sh`.
6. **Collision strictness documented**: owned_paths collision is exact-match only, NOT hierarchical. `src/auth/` and `src/auth/jwt.go` do not collide. Documented as intentional and advisory.

---

## Changelog V2 → V3

1. **`access_mode` field added to task-contract v1**: resolves the `/review` contradiction. `owned_paths` is REQUIRED only when `access_mode: write`; read-only tasks are allowed to declare zero ownership.
2. **Task registry lifecycle**: local `task-registry.jsonl` now carries `status` (`active | completed | failed | abandoned`), `access_mode`, `created_at`, `completed_at`. Collisions are computed only against `status=active` AND `access_mode=write` entries. `task-completed.sh` transitions state.
3. **JSON embedded contract format replacing pseudo-YAML**: parsed via `jq`, not `awk`. No more string-level parsing of YAML-ish content.
4. **C-minimal is now deterministic**: new helper script `.devcontainer/scripts/list-team-agents.sh` extracts the exact agent list by grepping migrated skills. C-minimal operates on that output, not a human estimate.
5. **Terminal classification relaxed**: `known-compatible | known-incompatible | unknown` with `unknown → conservative downgrade`. Heuristic, not normative.
6. **"Byte-for-byte fallback" removed**: replaced with "functional + schema equivalence + same severity semantics + no new user-visible sections in fallback mode".
7. **`super-claude` wrapper specified**: new sub-section A6.1 with explicit behavior per capability + bypass flag.
8. **Token ceiling scoped to B1**: 2.5x is a pilot budget for `/review`. Each subsequent skill sets its own ceiling in its migration PR.
9. **Contract unit test tier added**: new F3-unit layer under F3 that covers parse/mapping/probe primitives in isolation. F3 end-to-end is kept on top.

---

## Vocabulary (normative, unchanged from V2)

### Capability (persisted in `~/.claude/.team-capability`)

| Value | Meaning |
|---|---|
| `TMUX` | tmux present + known-compatible terminal + env flag + Claude ≥ 2.1.32 |
| `IN_PROCESS` | env flag + Claude ≥ 2.1.32, but tmux absent OR terminal known-incompatible OR unknown |
| `NONE` | env flag disabled OR Claude < 2.1.32 OR forced off |

### Runtime mode (live, overrides capability)

| Value | Trigger |
|---|---|
| `TEAMS_TMUX` | Live probe PASS: tmux usable AND known-compatible terminal |
| `TEAMS_INPROCESS` | Live probe PASS: teams usable but tmux or terminal disqualifies split-pane |
| `SUBAGENTS` | Live probe FAIL on any team prerequisite — legacy `Task`-tool dispatching |

### Terminal classification (heuristic, maintained by tests)

| Class | Detection signals | Action |
|---|---|---|
| `known-compatible` | `$TMUX` set AND not inside vscode/WT/Ghostty-incompat; `$TERM_PROGRAM` ∈ {`iTerm.app`, `WezTerm`, `ghostty`} | allow split-pane |
| `known-incompatible` | `$TERM_PROGRAM == vscode`; `$WT_SESSION` set; `$VSCODE_PID` set | downgrade to IN_PROCESS |
| `unknown` | none of the above matched | downgrade to IN_PROCESS (conservative) |

Rationale: these lists are heuristics updated by the regression tests in F3, not platform invariants.

### Compatibility matrix

| Claude ver | env flag | tmux | Terminal | Capability | Runtime mode |
|:-:|:-:|:-:|:-:|:-:|:-:|
| < 2.1.32 | — | — | — | NONE | SUBAGENTS |
| ≥ 2.1.32 | off | — | — | NONE | SUBAGENTS |
| ≥ 2.1.32 | on | no | — | IN_PROCESS | TEAMS_INPROCESS |
| ≥ 2.1.32 | on | yes | known-compatible | TMUX | TEAMS_TMUX |
| ≥ 2.1.32 | on | yes | known-incompatible | TMUX | TEAMS_INPROCESS |
| ≥ 2.1.32 | on | yes | unknown | TMUX | TEAMS_INPROCESS |

---

## Task payload contract v1 (JSON embedded)

Every task created for a teammate MUST embed the following block inside `task_description`:

```
<!-- task-contract v1
{
  "contract_version": 1,
  "scope": "src/auth/",
  "access_mode": "write",
  "owned_paths": ["src/auth/jwt.go", "src/auth/jwt_test.go"],
  "forbidden_paths": ["src/auth/session.go"],
  "acceptance_criteria": ["all tests pass", "no clippy warnings"],
  "output_format": "diff",
  "assignee": "reviewer-security",
  "depends_on": [],
  "idempotency_key": "review-jwt-2026-04-09-a1b2c3"
}
-->

<free-form instructions for the teammate follow here>
```

### Field rules

| Field | Type | Required | Constraint |
|---|---|---|---|
| `contract_version` | integer | ✓ | Currently `1`. Parsers reject unknown versions. |
| `scope` | string | ✓ | Non-empty |
| `access_mode` | enum | ✓ | `"read-only"` or `"write"` |
| `owned_paths` | array\<string\> | ✓ if `write`, else optional | When `write`, ≥ 1 entry. **Collision is exact-path match only** — `src/auth/` and `src/auth/jwt.go` do not collide. Advisory. |
| `forbidden_paths` | array\<string\> | Optional | Advisory only |
| `acceptance_criteria` | array\<string\> | ✓ | ≥ 1 entry |
| `output_format` | string | ✓ | Skill-defined enum (`diff`, `report`, `patch`, `summary`, …) |
| `assignee` | string | ✓ | Must match a teammate name known to the lead |
| `depends_on` | array\<string\> | Optional | Task IDs this depends on |
| `idempotency_key` | string | Optional | When present, duplicate TaskCreated events with the same key are deduplicated by `task-created.sh`. Prevents double-recording on transient failures. |

### Parsing (`team-mode-primitives.sh` canonical, V3.1)

Delimiter-tolerant, version-aware. Single implementation sourced by hooks AND unit tests:

```bash
extract_task_contract() {
    local description="$1"
    # Tolerant opening marker: accepts any whitespace + any version number
    # Tolerant closing marker: any line containing "-->"
    printf '%s' "$description" | awk '
        /<!--[[:space:]]*task-contract[[:space:]]+v[0-9]+/ { p=1; next }
        p && /-->/                                        { p=0; exit }
        p                                                 { print }
    ' | jq -c . 2>/dev/null
}

validate_contract_version() {
    local contract_json="$1"
    [ "$(printf '%s' "$contract_json" | jq -r '.contract_version // 0')" = "1" ]
}
```

Failure semantics:
- `jq` fails OR contract absent → WARNING + advisory allow
- `contract_version != 1` → WARNING + advisory allow (forward-compat)
- `jq` succeeds + version valid → strict validation + collision check

### `/review` contract compliance

With `access_mode: "read-only"`, `/review` legitimately declares `owned_paths: []` and satisfies the contract. No self-contradiction. The collision check skips `read-only` entries entirely.

---

## Registry lifecycle (local, hook-owned)

**File:** `~/.claude/logs/<team-name>/task-registry.jsonl`

Written by `task-created.sh`, updated by `task-completed.sh`, read by `task-created.sh` (for collisions) and `teammate-idle.sh` (for pending check).

### Entry schema

```json
{
  "id": "task-001",
  "team": "my-project",
  "assignee": "reviewer-security",
  "subject": "Review JWT handling",
  "contract": true,
  "access_mode": "write",
  "owned_paths": ["src/auth/jwt.go"],
  "status": "active",
  "created_at": "2026-04-09T14:30:00Z",
  "completed_at": null
}
```

### State transitions

```
(none) ──[task-created.sh]──▶ active
active ──[task-completed.sh, exit 0]──▶ completed
active ──[task-completed.sh with {"continue": false}]──▶ abandoned
active ──[teammate-idle.sh on failure]──▶ failed (advisory, does not block)
```

### Collision rule

A new task is rejected only when:
1. Its `access_mode == "write"`, AND
2. There exists a registry entry with `status == "active"` AND `access_mode == "write"` AND overlapping `owned_paths`, AND
3. That entry's `assignee` is different from the new task's `assignee` (self-overlap is allowed — same teammate refining a task).

All other cases produce a warning or pass silently.

### Garbage collection

`task-registry.jsonl` is append-only. On every `task-created.sh` invocation, entries older than 24 hours AND `status != "active"` are pruned to a `.archive.jsonl` sibling. Keeps the active set small.

---

## Phase A — Infrastructure + contracts (blast radius: HIGH, PR count: 1)

### Step A1: tmux in Dockerfile.base

**File:** `.devcontainer/images/Dockerfile.base` (edit, +1 line)

Append `tmux` to the existing `apt-get install` package list.

### Step A2: `install_tmux()` in install.sh

**File:** `.devcontainer/install.sh` (edit, +80 lines)

Non-blocking multi-distro installer. Unchanged from V2.

### Step A3: `detect_agent_teams_support()` + terminal probe

**File:** `.devcontainer/install.sh` (edit, +80 lines — 20 more than V2 for the terminal probe)

```bash
classify_terminal() {
    # Priority: known-incompatible > known-compatible > unknown
    [ -n "${VSCODE_PID:-}" ] && { echo "known-incompatible"; return; }
    [ "${TERM_PROGRAM:-}" = "vscode" ] && { echo "known-incompatible"; return; }
    [ -n "${WT_SESSION:-}" ] && { echo "known-incompatible"; return; }

    # Inside a tmux session is always compatible (obviously)
    [ -n "${TMUX:-}" ] && { echo "known-compatible"; return; }

    case "${TERM_PROGRAM:-}" in
        iTerm.app|WezTerm|ghostty|kitty) echo "known-compatible"; return ;;
    esac

    echo "unknown"
}

detect_agent_teams_support() {
    local min="2.1.32"
    local current
    current=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

    if [ "${NO_TEAMS:-false}" = "true" ]; then
        printf '%s\n' "NONE" > "$HOME_DIR/.claude/.team-capability"
        echo "→ Agent Teams capability: NONE (--no-teams flag)"
        return
    fi

    local cap="NONE"
    if [ -n "$current" ] && printf '%s\n%s\n' "$min" "$current" | sort -VC 2>/dev/null; then
        local term_class
        term_class=$(classify_terminal)
        if command -v tmux &>/dev/null && [ "$term_class" = "known-compatible" ]; then
            cap="TMUX"
        else
            cap="IN_PROCESS"
        fi
    fi

    mkdir -p "$HOME_DIR/.claude"
    printf '%s\n' "$cap" > "$HOME_DIR/.claude/.team-capability"

    if [ "$cap" = "NONE" ] && [ -f "$HOME_DIR/.claude/settings.json" ] && command -v jq &>/dev/null; then
        jq 'del(.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS)' \
            "$HOME_DIR/.claude/settings.json" > "$HOME_DIR/.claude/settings.json.tmp" \
            && mv "$HOME_DIR/.claude/settings.json.tmp" "$HOME_DIR/.claude/settings.json"
    fi

    echo "→ Agent Teams capability: $cap (claude=${current:-none}, min=$min, term=$(classify_terminal))"
}
```

### Step A4: Fix stale counts + `--no-teams` flag

**File:** `.devcontainer/install.sh` (edit, ~20 lines). Unchanged from V2.

### Step A5: `shared/team-mode.md` canonical protocol (NEW, ~260 lines)

**File:** `.devcontainer/images/.claude/commands/shared/team-mode.md`

**Sections (V3):**

1. Vocabulary (Capability vs Runtime vs Terminal classification)
2. Compatibility matrix (6 rows)
3. Runtime detection canonical block (with terminal classification)
4. **Task payload contract v1 (JSON embedded)** — full field rules + parser snippet
5. Registry lifecycle diagram
6. TEAMS execution contract
7. SUBAGENTS execution contract (fallback)
8. Contracts & invariants (capability file = cache, registry = local, stdin only)
9. Name convention per skill
10. Per-skill success criteria template
11. Guardrails (ABSOLUTE)
12. Known-incompatible terminals list (heuristic, updated by tests)
13. Bypass & debug flags (`NO_TEAMS`, `SUPER_CLAUDE_NO_TMUX`, `CLAUDE_CODE_TASK_LIST_ID`, `TEAM_MODE_DEBUG`)

### Debug mode

When `TEAM_MODE_DEBUG=1`, `team-mode-primitives.sh` emits stderr logs at each decision point:
```
[team-mode] capability-read: TMUX
[team-mode] live-probe: claude=2.1.97 env=1 tmux=yes term=known-compatible
[team-mode] runtime-mode: TEAMS_TMUX
[team-mode] contract-parse: valid v1 access_mode=write paths=2
[team-mode] registry-transition: task-001 active→completed
```
Helper: `team_mode_debug_log() { [ "${TEAM_MODE_DEBUG:-0}" = "1" ] && echo "[team-mode] $*" >&2; }`. Off by default, zero cost.

### Step A6: Wire into install.sh main flow

**File:** `.devcontainer/install.sh` (edit, ~6 lines)

Call order: `install_claude_cli → install_tmux → (existing downloads) → detect_agent_teams_support → install_super_claude → verify_installation`.

### Step A6.1: `super-claude` wrapper spec (NEW sub-section)

**File:** `.devcontainer/install.sh` — the `install_super_claude` function (edit, ~30 lines)

**Explicit behavior per capability:**

```bash
super-claude() {
    local mcp_config="$HOME/.claude/mcp.json"
    local cap
    cap=$(cat "$HOME/.claude/.team-capability" 2>/dev/null || echo NONE)

    export CLAUDE_CONFIG_DIR="$HOME/.claude"

    # Bypass: user sets SUPER_CLAUDE_NO_TMUX=1 → never wrap
    if [ "${SUPER_CLAUDE_NO_TMUX:-0}" = "1" ]; then
        _run_claude "$@"
        return
    fi

    # Already inside tmux → never nest (known footgun)
    if [ -n "${TMUX:-}" ]; then
        _run_claude "$@"
        return
    fi

    # Capability NONE or IN_PROCESS → no wrap needed
    if [ "$cap" != "TMUX" ]; then
        _run_claude "$@"
        return
    fi

    # Capability TMUX + not already in tmux → wrap
    if command -v tmux &>/dev/null; then
        tmux new -A -s claude "env CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR _run_claude $*"
    else
        _run_claude "$@"
    fi
}

_run_claude() {
    local mcp_config="$HOME/.claude/mcp.json"
    if [ -f "$mcp_config" ] && command -v jq &>/dev/null && jq empty "$mcp_config" 2>/dev/null; then
        claude --dangerously-skip-permissions --mcp-config "$mcp_config" "$@"
    else
        claude --dangerously-skip-permissions "$@"
    fi
}
```

**Rules:**

| Situation | Behavior |
|---|---|
| `SUPER_CLAUDE_NO_TMUX=1` | Never wrap (explicit bypass) |
| Already inside `$TMUX` | Never wrap (nested tmux = footgun) |
| Capability `NONE` | Never wrap |
| Capability `IN_PROCESS` | Never wrap |
| Capability `TMUX` + no `$TMUX` + tmux binary present | Wrap with `tmux new -A -s claude` |
| Capability `TMUX` + tmux binary missing (impossible in theory) | Never wrap, warn |

### Step A7: NEW — `list-team-agents.sh` helper (NEW, ~40 lines)

**File:** `.devcontainer/scripts/list-team-agents.sh`

Deterministic extraction of agents referenced by migrated skills. Output: JSON array on stdout.

```bash
#!/bin/bash
# Extract agent names referenced by skills in commands/ that declare
# a team-mode migration. Used by C-minimal to know exactly which agents
# need metadata updates. Pure function, no side effects.
set -euo pipefail

COMMANDS_DIR="${1:-.devcontainer/images/.claude/commands}"

# Find skill files that reference the shared team-mode doc
migrated_skills=$(grep -rlE '@.*shared/team-mode\.md' "$COMMANDS_DIR" 2>/dev/null || true)

# Extract agent names from patterns like:
#   "using developer-executor-correctness"
#   "subagent_type: developer-specialist-go"
#   "spawn teammate developer-..."
echo "$migrated_skills" | while IFS= read -r file; do
    [ -z "$file" ] && continue
    grep -oE '(developer|devops|docs|os)-(orchestrator|executor|specialist|analyzer|commentator)-[a-z-]+' "$file" 2>/dev/null || true
done | sort -u | jq -R -s -c 'split("\n") | map(select(length > 0))'
```

Example output:
```json
["developer-executor-correctness","developer-executor-design","developer-executor-quality","developer-executor-security","developer-executor-shell","developer-specialist-review"]
```

Run at the beginning of Phase C-minimal to produce the EXACT scope. Re-runnable.

### Phase A exit criteria

- [ ] `docker run --rm <image> tmux -V` prints `tmux 3.x`
- [ ] `bash install.sh --no-teams` → `.team-capability == NONE`
- [ ] `classify_terminal` returns the expected class on all 5 test env configs
- [ ] `shared/team-mode.md` exists, passes F3-unit schema validation
- [ ] `super-claude` never nests tmux
- [ ] `list-team-agents.sh` returns `[]` at this phase (no skill migrated yet — expected)
- [ ] No existing skill modified
- [ ] F3-unit (below) passes all 20+ primitive tests

---

## Phase B1 — PILOT: `/review` (blast radius: MEDIUM, PR count: 1)

### Migration

**Files edited:**
- `.devcontainer/images/.claude/commands/review.md`
- `.devcontainer/images/.claude/commands/review/dispatch.md`
- `.devcontainer/images/.claude/commands/review/tiers.md`

**Insertion template** (same as V2 but with corrected contract):

```markdown
## Execution Mode Detection

@.devcontainer/images/.claude/commands/shared/team-mode.md

Run the canonical runtime detection block from section 3 of the shared doc.
Computed runtime mode branches into `## TEAMS execution` or `## SUBAGENTS execution (fallback)`.

## TEAMS execution

Create 5 tasks via TaskCreate, one per review axis. Each task_description
MUST embed a task-contract v1 block:

TASK 1 (correctness):
<!-- task-contract v1
{"scope":"<PR root>","access_mode":"read-only","owned_paths":[],"forbidden_paths":[],"acceptance_criteria":["report all correctness findings"],"output_format":"report","assignee":"reviewer-correctness","depends_on":[]}
-->

Review the PR for correctness. Focus on: ...

TASK 2 (security): ... assignee: reviewer-security ...
TASK 3 (design):   ... assignee: reviewer-design   ...
TASK 4 (quality):  ... assignee: reviewer-quality  ...
TASK 5 (shell):    ... assignee: reviewer-shell    ...

Then spawn 5 teammates:
- spawn teammate using developer-executor-correctness, name reviewer-correctness
- spawn teammate using developer-executor-security, name reviewer-security
- spawn teammate using developer-executor-design, name reviewer-design
- spawn teammate using developer-executor-quality, name reviewer-quality
- spawn teammate using developer-executor-shell, name reviewer-shell

Wait for all 5 teammates to stop (TeammateIdle), then synthesize via the
existing review/synthesis.md procedure. Clean up the team at the end.

## SUBAGENTS execution (fallback)

<existing dispatch logic, unchanged — renamed only>
```

**All 5 tasks have `access_mode: "read-only"` with `owned_paths: []`**. Contract satisfied. Collision check skips all 5.

### Per-skill success criteria (B1, hardened V3)

- **Functional equivalence**: same review findings (set comparison, not ordered) across modes on 3 real PRs
- **Schema equivalence**: synthesis report has the same sections, same severity levels, same fields per finding
- **Semantic equivalence**: a "critical" in legacy mode remains a "critical" in TEAMS mode
- **No new user-visible sections in fallback**: `/review` in SUBAGENTS mode does NOT print any team-related output to the user
- **Performance floor**: ≥ 1.5x faster wall-clock on a 30+ file PR in TEAMS_TMUX
- **Pilot token ceiling**: ≤ 2.5x legacy cost for `/review` specifically (this ceiling does NOT apply to other skills; each sets its own)
- **Stability**: 5 consecutive runs without manual intervention
- **Hook cleanliness**: 0 false-positive TaskCreated rejections across 10 runs
- **Fallback**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=0 /review` produces functionally equivalent output

### B1 exit criteria

All 9 criteria above verified on real data. Regression test in F3 scenario 9.

---

## Phase D — Hooks (advisory, stdin-only, lifecycle-aware; PR count: 1)

### Step D1: `task-created.sh` v3 (NEW, ~130 lines)

```bash
#!/bin/bash
# Hook: TaskCreated — advisory validation of task-contract v1
# V3: JSON-embedded contract + lifecycle-aware registry
set +e

CAP=$(cat "$HOME/.claude/.team-capability" 2>/dev/null)
[ "$CAP" = "NONE" ] && exit 0

INPUT="$(cat 2>/dev/null || true)"
command -v jq >/dev/null 2>&1 || exit 0

SUBJECT=$(printf '%s' "$INPUT"       | jq -r '.task_subject // ""')
DESCRIPTION=$(printf '%s' "$INPUT"   | jq -r '.task_description // ""')
TEAM=$(printf '%s' "$INPUT"          | jq -r '.team_name // "default"')
TASK_ID=$(printf '%s' "$INPUT"       | jq -r '.task_id // ""')
TEAMMATE=$(printf '%s' "$INPUT"      | jq -r '.teammate_name // ""')

# Minimum sanity
[ -z "$SUBJECT" ] && { echo "Task rejected: subject is empty" >&2; exit 2; }

REGISTRY="$HOME/.claude/logs/$TEAM/task-registry.jsonl"
ARCHIVE="$HOME/.claude/logs/$TEAM/task-registry.archive.jsonl"
mkdir -p "$(dirname "$REGISTRY")"

# Garbage collect: move non-active entries older than 24h to archive
if [ -f "$REGISTRY" ]; then
    CUTOFF=$(date -u -d '24 hours ago' +%s 2>/dev/null || date -u -v-24H +%s)
    TMP=$(mktemp)
    while IFS= read -r line; do
        AGE=$(printf '%s' "$line" | jq -r '.created_at // "1970-01-01T00:00:00Z"' | { read d; date -u -d "$d" +%s 2>/dev/null || echo 0; })
        STATUS=$(printf '%s' "$line" | jq -r '.status // "unknown"')
        if [ "$STATUS" = "active" ] || [ "$AGE" -gt "$CUTOFF" ]; then
            printf '%s\n' "$line" >> "$TMP"
        else
            printf '%s\n' "$line" >> "$ARCHIVE"
        fi
    done < "$REGISTRY"
    mv "$TMP" "$REGISTRY"
fi

# Extract task-contract v1 JSON block
CONTRACT_JSON=$(printf '%s' "$DESCRIPTION" \
    | awk '/^<!-- task-contract v1$/{p=1; next} /^-->$/{p=0} p' \
    | jq -c . 2>/dev/null || true)

if [ -z "$CONTRACT_JSON" ]; then
    # Advisory: no contract, log and allow
    echo "Task advisory: no task-contract v1 block (recommended for team tasks)" >&2
    jq -nc \
        --arg id "$TASK_ID" \
        --arg team "$TEAM" \
        --arg assignee "$TEAMMATE" \
        --arg subj "$SUBJECT" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{id:$id, team:$team, assignee:$assignee, subject:$subj, contract:false, access_mode:null, owned_paths:[], status:"active", created_at:$ts, completed_at:null}' \
        >> "$REGISTRY"
    exit 0
fi

# Parse contract fields
ACCESS_MODE=$(printf '%s' "$CONTRACT_JSON"  | jq -r '.access_mode // "write"')
OWNED_PATHS=$(printf '%s' "$CONTRACT_JSON"  | jq -c '.owned_paths // []')
CONTRACT_ASSIGNEE=$(printf '%s' "$CONTRACT_JSON" | jq -r '.assignee // ""')
[ -z "$TEAMMATE" ] && TEAMMATE="$CONTRACT_ASSIGNEE"

# Required-field validation
if [ "$ACCESS_MODE" = "write" ]; then
    OWNED_COUNT=$(printf '%s' "$OWNED_PATHS" | jq 'length')
    if [ "$OWNED_COUNT" -eq 0 ]; then
        echo "Task rejected: access_mode=write requires at least one owned_paths entry" >&2
        exit 2
    fi
fi

# Collision check: only against active + write entries from other assignees
if [ "$ACCESS_MODE" = "write" ] && [ -f "$REGISTRY" ]; then
    CONFLICT=$(jq -rc \
        --argjson new_paths "$OWNED_PATHS" \
        --arg new_assignee "$TEAMMATE" \
        'select(.status == "active" and .access_mode == "write" and .assignee != $new_assignee)
         | . as $row
         | ($new_paths | map(. as $np | $row.owned_paths | index($np)) | map(select(. != null)) | length)
         | select(. > 0)' \
        "$REGISTRY" | head -1)
    if [ -n "$CONFLICT" ]; then
        echo "Task rejected: owned_paths collision with an active write task owned by a different teammate" >&2
        exit 2
    fi
fi

# Record as active
jq -nc \
    --arg id "$TASK_ID" \
    --arg team "$TEAM" \
    --arg assignee "$TEAMMATE" \
    --arg subj "$SUBJECT" \
    --arg mode "$ACCESS_MODE" \
    --argjson paths "$OWNED_PATHS" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{id:$id, team:$team, assignee:$assignee, subject:$subj, contract:true, access_mode:$mode, owned_paths:$paths, status:"active", created_at:$ts, completed_at:null}' \
    >> "$REGISTRY"

exit 0
```

### Step D2: `task-completed.sh` v3 (edit, ~40 lines added)

Add lifecycle transition. If task_id is found in registry with status=active, rewrite the line with status=completed + completed_at.

```bash
# After existing logging:
REGISTRY="$HOME/.claude/logs/$TEAM/task-registry.jsonl"
if [ -f "$REGISTRY" ] && [ -n "$TASK_ID" ]; then
    TMP=$(mktemp)
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq -c \
        --arg id "$TASK_ID" \
        --arg now "$NOW" \
        'if .id == $id and .status == "active" then .status = "completed" | .completed_at = $now else . end' \
        "$REGISTRY" > "$TMP" && mv "$TMP" "$REGISTRY"
fi
```

### Step D3: `teammate-idle.sh` v3 (edit, ~25 lines added)

Count active tasks owned by the idling teammate. If > 0, exit 2 with feedback.

```bash
CAP=$(cat "$HOME/.claude/.team-capability" 2>/dev/null)
[ "$CAP" = "NONE" ] && exit 0

REGISTRY="$HOME/.claude/logs/$TEAM/task-registry.jsonl"
if [ -f "$REGISTRY" ] && [ -n "$TEAMMATE" ]; then
    PENDING=$(jq -rc \
        --arg a "$TEAMMATE" \
        'select(.status == "active" and .assignee == $a) | .id' \
        "$REGISTRY" | wc -l)
    if [ "$PENDING" -gt 0 ]; then
        echo "You still have $PENDING active task(s) — continue working" >&2
        exit 2
    fi
fi
exit 0
```

### Step D4: Wire TaskCreated in settings.json

Unchanged from V2.

### Phase D exit criteria

- [ ] F3-unit parse tests: valid JSON, empty block, malformed JSON, missing `access_mode` — all handled correctly
- [ ] F3 scenario: TaskCreated with write collision → exit 2
- [ ] F3 scenario: TaskCreated with read-only + `owned_paths: []` → exit 0 (no contradiction)
- [ ] F3 scenario: TaskCreated with write + same assignee overlap → exit 0 (self-overlap allowed)
- [ ] F3 scenario: TaskCompleted transitions registry entry to `completed`
- [ ] F3 scenario: TeammateIdle with pending tasks → exit 2
- [ ] F3 scenario: Garbage collection runs on old entries

---

## Phase C-minimal — Agent metadata (deterministic, PR count: 1)

### Step C-minimal-1: Generate the exact scope

**Command (run once at the start of the PR):**

```bash
bash .devcontainer/scripts/list-team-agents.sh > /tmp/c-minimal-scope.json
```

After B1 merge, this will output something like:
```json
["developer-executor-correctness","developer-executor-design","developer-executor-quality","developer-executor-security","developer-executor-shell","developer-specialist-review"]
```

Commit `/tmp/c-minimal-scope.json` as `.devcontainer/scripts/c-minimal-scope.json` (or regenerate deterministically in CI). C-minimal PR touches EXACTLY those agents.

### Step C-minimal-2: Apply metadata + tool declarations

For each agent in the scope file:
1. Add `teamRole: lead|teammate|both` to frontmatter.
2. Ensure `tools:` list includes `SendMessage`, `TaskCreate`, `TaskUpdate`, `TaskList`, `TaskGet`.
3. No body changes.

### Step C-extended (deferred)

After `/review` pilot validates AND B2..B7 are underway, a separate PR adds `teamRole: teammate` + the "When spawned as a TEAMMATE" appendix to all remaining agents. Purely declarative. Blast radius: LOW.

### Phase C-minimal exit criteria

- [ ] Scope file generated from the script, not from a human list
- [ ] Every agent in scope has `teamRole` in frontmatter
- [ ] Every teammate agent lists the 5 coordination tools
- [ ] F3-unit frontmatter validator passes for all scoped agents
- [ ] No agent outside the scope is touched

---

## Phase B2-B7 — Sequential migration (PR count: 6)

Each PR follows the B1 template with per-skill success criteria. Token ceiling is NOT 2.5x globally — each PR sets its own based on the nature of parallelism and records it in the PR description for audit:

| Skill | Parallelism | Indicative ceiling | Rationale |
|---|---|---|---|
| `/plan` | 4 explorers, read-only | ≤ 2x | Exploration is cheaper than review |
| `/docs` | 8 analyzers, mostly read-only | ≤ 3x | High breadth, acceptable in one-shot runs |
| `/do` | N specialists, write-heavy | ≤ 2.5x | Depends on plan parallelization table |
| `/infra` | Clouds in parallel | ≤ 2x | Cloud ops are IO-bound |
| `/test` | e2e/unit/integration | ≤ 2x | Test suites parallelize well |
| `/improve` | 4 axes | ≤ 2.5x | Similar to /review |

These are **indicative starting points**, tuned in each PR against real data.

---

## Phase F — Docs + audit + tests (PR count: 1)

### Step F1-F4: unchanged from V2 (CLAUDE.md updates, /audit extension, README)

### Step F3-unit: Contract unit tests (NEW tier below F3 end-to-end)

**File:** `.devcontainer/tests/unit/` (new directory, ~8 scripts)

Shell unit tests (plain `bash` assertion style, no bats dependency) that cover primitives in isolation. Each file is standalone and exits 0/1.

```
.devcontainer/tests/unit/
├── run-all.sh                          # harness that runs everything
├── test-parse-contract.sh              # 10+ cases: valid, empty, malformed, missing field, …
├── test-capability-mapping.sh          # 6 cases: every row of the matrix
├── test-terminal-classify.sh           # 10+ cases: known-compat/incompat/unknown + edge
├── test-registry-lifecycle.sh          # created → completed, created → failed, collision, self-overlap
├── test-registry-gc.sh                 # 24h+ entries move to archive
├── test-super-claude-wrap.sh           # all 6 situations in the wrapper spec table
├── test-list-team-agents.sh            # fixture skills → expected agent set
└── test-version-compare.sh             # sort -V edge cases including prerelease suffixes
```

Example (`test-parse-contract.sh`, abbreviated):
```bash
#!/bin/bash
set -e
source .devcontainer/scripts/team-mode-primitives.sh  # where extract_task_contract lives

# Case 1: valid JSON block
INPUT=$(cat <<'EOF'
<!-- task-contract v1
{"scope":"src/","access_mode":"write","owned_paths":["a.go"],"acceptance_criteria":["x"],"output_format":"diff","assignee":"t1","depends_on":[]}
-->
free text
EOF
)
OUT=$(extract_task_contract "$INPUT")
[ "$(echo "$OUT" | jq -r .access_mode)" = "write" ] || { echo FAIL case 1; exit 1; }

# Case 2: malformed JSON
INPUT=$(cat <<'EOF'
<!-- task-contract v1
{"scope":"src/","access_mode":"write"
-->
EOF
)
OUT=$(extract_task_contract "$INPUT")
[ -z "$OUT" ] || { echo FAIL case 2; exit 1; }

# Case 3: no block
OUT=$(extract_task_contract "just some task description")
[ -z "$OUT" ] || { echo FAIL case 3; exit 1; }

echo "parse-contract: all cases passed"
```

The primitive library `team-mode-primitives.sh` lives in `.devcontainer/scripts/` and is sourced by BOTH hooks AND unit tests. This is the single implementation of `extract_task_contract`, `classify_terminal`, `map_capability_runtime`, etc.

### Step F3-e2e: End-to-end scenarios (unchanged + scenario 10 added)

Scenarios 1-9 from V2, plus:
10. **Contract format migration**: parse a V2-style pseudo-YAML block → assert it fails cleanly with advisory warning (forward-compat for users who copy-paste old docs).

### Phase F exit criteria

- [ ] `bash .devcontainer/tests/unit/run-all.sh` → 0 failures across all primitive tests
- [ ] `bash .devcontainer/tests/test-agent-teams.sh` → 10 scenarios all pass
- [ ] `/audit` shows non-zero Agent Teams score
- [ ] README has an Agent Teams section with opt-out note

---

## Merge order (V3, unchanged from V2)

```
A → B1(/review) → D → C-minimal → B2 → B3 → B4 → B5 → B6 → B7 → F → C-extended
```

PR count: 12. Each independently revertible.

---

## File change summary (V3)

| Phase | Edit | Create | Total | PR |
|---|---|---|---|---|
| A | 3 (install.sh, Dockerfile.base, settings.json optional) | 3 (team-mode.md, list-team-agents.sh, team-mode-primitives.sh) | 6 | 1 |
| B1 | 3 | 0 | 3 | 1 |
| D | 3 | 1 (task-created.sh) | 4 | 1 |
| C-minimal | ~6-10 (deterministic) | 0 | ~8 | 1 |
| B2-B7 | ~12 | 0 | 12 | 6 |
| F | 7 | 10 (unit tests + e2e + docs) | 17 | 1 |
| C-extended | ~60 | 0 | 60 | 1 |
| **TOTAL** | **~94** | **14** | **~108** | **12** |

Slightly smaller than V2 because C-minimal scope went from "~22" to "~6-10 deterministic".

---

## Risks & Mitigations (V3 additions only)

| Risk (new in V3) | Mitigation |
|---|---|
| `classify_terminal` misclassifies a future terminal | Heuristic documented as maintained by tests; unknown → downgrade; F3-unit covers all known cases |
| JSON contract extractor misses edge cases (multiline strings, unicode, trailing commas) | F3-unit test `test-parse-contract.sh` covers 10+ cases; `jq` handles standard JSON correctly; non-standard inputs → advisory fallback |
| Registry GC corrupts active entries | GC only moves entries with `status != active` AND age > 24h; active entries are preserved unconditionally; tested in `test-registry-gc.sh` |
| `super-claude` wrapping breaks interactive features | Bypass via `SUPER_CLAUDE_NO_TMUX=1`; nested tmux explicitly refused; tested in `test-super-claude-wrap.sh` |
| `list-team-agents.sh` misses an agent due to naming pattern drift | Pattern is generous (`(developer\|devops\|docs\|os)-...`); if a new prefix appears, update regex; run after every B-step to verify scope |
| Per-skill token ceiling drift | Each B2-B7 PR records its actual ceiling; `/audit` flags any skill without a recorded ceiling |
| Users paste old V2-style pseudo-YAML contract blocks | Scenario F3-e2e #10 confirms graceful advisory fallback; docs explicitly show JSON format |

---

## What "frozen-ready" means in V3

All 4 structural defects from the V2 review are resolved:

1. ✅ **Contract contradiction on `/review`**: `access_mode: read-only` + `owned_paths: []` is now a first-class, documented case.
2. ✅ **Lifecycle in local registry**: `status` field + `task-completed.sh` transitions + GC.
3. ✅ **Fragile contract format**: JSON embedded, parsed via `jq`, not awk/sed.
4. ✅ **Deterministic C-minimal**: `list-team-agents.sh` extracts the scope, no human estimation.

Plus 5 polish fixes:

5. ✅ Terminal classification relaxed to `known-compatible | known-incompatible | unknown`.
6. ✅ "Byte-for-byte fallback" replaced with "functional + schema + semantic equivalence".
7. ✅ `super-claude` wrapper fully specified with bypass flag.
8. ✅ Token ceiling is a B1 pilot budget; each subsequent skill sets its own.
9. ✅ Contract unit test tier (`F3-unit`) below the end-to-end tests, covering primitives.

The plan is now executable without further hardening. Phase A can start.

---

## What's still NOT in scope (deferred)

- Cross-session teammate persistence (platform limitation)
- Nested teams (platform limitation)
- Per-teammate permission modes at spawn time (platform limitation)
- Lead promotion / leadership transfer (platform limitation)
- Auto token-burn throttling (nice-to-have, deferred)
- Rich team dashboard UI (nice-to-have, deferred)
- C-extended broad metadata pass (scheduled last)
