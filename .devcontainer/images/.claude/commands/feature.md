---
name: feature
description: |
  Feature tracking with RTM (Requirements Traceability Matrix).
  CRUD operations, auto-learn from code changes, parallel audit.
allowed-tools:
  - "Read(**/*)"
  - "Write(**/*)"
  - "Edit(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "Bash(*)"
  - "Task(*)"
  - "TaskCreate(*)"
  - "TaskUpdate(*)"
  - "TaskList(*)"
  - "TaskGet(*)"
  - "AskUserQuestion(*)"
  - "mcp__grepai__*"
  - "mcp__taskmaster__*"
---

# /feature - Feature Tracking RTM (Requirements Traceability Matrix)

$ARGUMENTS

---

## Overview

Track project features with full traceability: CRUD, audit, auto-learn.

**Database:** `.claude/features.json` (git-committed, no secrets)

---

## --help

```
═══════════════════════════════════════════════════════════════
  /feature - Feature Tracking RTM
═══════════════════════════════════════════════════════════════

  DESCRIPTION
    Manage project features with full traceability.
    CRUD operations, parallel audit, auto-learn from code.

  USAGE
    /feature --add "title" --desc "description"  Create feature
    /feature --edit <id> [--title "..."] [--desc "..."] [--status ...]
    /feature --del <id>                           Delete (confirm)
    /feature --list                               List all features
    /feature --show <id>                          Detail + journal
    /feature --checkup                            Audit ALL features
    /feature --checkup <id>                       Audit one feature
    /feature --help                               This help

  STATUSES
    pending | in_progress | completed | blocked | archived

  DATABASE
    .claude/features.json (git-committed)
    Schema version: 1

  EXAMPLES
    /feature --add "JWT auth" --desc "Add JWT token auth to API"
    /feature --edit F001 --status completed
    /feature --list
    /feature --checkup

═══════════════════════════════════════════════════════════════
```

**IF `$ARGUMENTS` contains `--help`**: Display the help above and STOP.

---

## Phase 1: Init

**Always runs first. Ensure `.claude/features.json` exists.**

```yaml
init:
  check: "Read .claude/features.json"
  if_missing:
    action: |
      Write .claude/features.json with:
      {
        "version": 1,
        "features": []
      }
    message: "Created .claude/features.json"
  if_exists:
    action: "Load into working memory"
```

---

## Phase 2: CRUD Operations

### --add "title" --desc "description"

```yaml
add_feature:
  1_generate_id:
    action: "Auto-increment: find max existing ID number, +1"
    format: "F001, F002, F003, ..."

  2_create_entry:
    fields:
      id: "{generated_id}"
      title: "{from --add argument}"
      description: "{from --desc argument, or ask user}"
      status: "pending"
      tags: "[]  # Ask user for optional tags"
      created: "{ISO 8601 now}"
      updated: "{ISO 8601 now}"
      journal:
        - ts: "{ISO 8601 now}"
          action: "created"
          detail: "Initial feature definition"

  3_write:
    action: "Edit .claude/features.json, append to features array"

  4_output:
    format: |
      ═══════════════════════════════════════════════════════════════
        Feature Created
      ═══════════════════════════════════════════════════════════════
        ID     : {id}
        Title  : {title}
        Status : pending
      ═══════════════════════════════════════════════════════════════
```

### --edit \<id\> [--title "..."] [--desc "..."] [--status ...] [--tags ...]

```yaml
edit_feature:
  1_find: "Locate feature by ID in features array"
  2_update: "Update only specified fields"
  3_journal: |
    Append entry:
      { ts: now, action: "modified", detail: "Updated {changed_fields}" }
    If --status changed:
      { ts: now, action: "status_change", detail: "from → to" }
  4_compact: |
    If journal has > 20 entries:
      Summarize oldest entries into single "compacted" entry
  5_write: "Save updated features.json"
```

### --del \<id\>

```yaml
delete_feature:
  1_find: "Locate feature by ID"
  2_confirm:
    tool: AskUserQuestion
    question: "Delete feature {id}: {title}? This cannot be undone."
    options:
      - label: "Yes, delete"
        description: "Permanently remove this feature"
      - label: "Archive instead"
        description: "Set status to archived (recoverable)"
  3_execute:
    if_delete: "Remove from features array"
    if_archive: "Set status to archived, add journal entry"
  4_write: "Save updated features.json"
```

### --list

```yaml
list_features:
  action: "Read features.json, display formatted table"
  format: |
    ═══════════════════════════════════════════════════════════════
      /feature --list ({n} features)
    ═══════════════════════════════════════════════════════════════

      ID    | Title                          | Status      | Tags        | Updated
      ------+--------------------------------+-------------+-------------+------------
      F001  | JWT authentication             | completed   | auth, api   | 2026-02-27
      F002  | Branch protection CI gates     | in_progress | ci, github  | 2026-02-26
      F003  | Taskmaster integration         | pending     | tooling     | 2026-02-27

    ═══════════════════════════════════════════════════════════════
```

### --show \<id\>

```yaml
show_feature:
  action: "Display full feature detail + journal"
  format: |
    ═══════════════════════════════════════════════════════════════
      Feature {id}: {title}
    ═══════════════════════════════════════════════════════════════

      Status      : {status}
      Tags        : {tags}
      Created     : {created}
      Updated     : {updated}

      Description:
        {description}

      Journal ({n} entries):
        {ts} | {action} | {detail}
        {ts} | {action} | {detail} | files: {files}
        ...

    ═══════════════════════════════════════════════════════════════
```

---

## Phase 3: --checkup (Parallel Audit)

```yaml
checkup_workflow:
  1_load_features:
    action: "Read .claude/features.json, filter status != archived"
    output: "active_features[]"

  2_determine_scope:
    if_id_provided: "Audit only the specified feature"
    if_no_id: "Audit ALL active features"

  3_determine_parallelism:
    action: "min(len(features_to_audit), 8)"
    note: "Max 8 parallel agents"

  4_spawn_audit_agents:
    mode: "PARALLEL (single message, multiple Task calls)"
    per_feature:
      subagent_type: "Explore"
      model: "haiku"
      prompt: |
        Audit feature {id}: "{title}"
        Description: {description}
        Status: {status}
        Journal (last 5): {last_5_journal_entries}

        TASKS:
        1. Search codebase (grepai_search) for files related to this feature
        2. Verify implementation matches description
        3. Identify gaps (described but not implemented)
        4. Identify possible improvements
        5. Conformity score: PASS / PARTIAL / FAIL

        Return JSON:
        { "id": "...", "conformity": "...", "gaps": [], "improvements": [], "related_files": [] }

  5_cross_feature_analysis:
    action: "Analyze results for contradictions"
    checks:
      - "Two features modify same files conflictually"
      - "Feature depends on incomplete feature"
      - "Contradictory descriptions"

  6_generate_report:
    format: |
      ═══════════════════════════════════════════════════════════════
        /feature --checkup - Audit Report
      ═══════════════════════════════════════════════════════════════

        Features audited: {n}
        Agents used: {parallel_count}

        Results:
          ├─ F001: ✓ PASS (branch protection)
          ├─ F002: ⚠ PARTIAL (2 gaps found)
          └─ F003: ✗ FAIL (not implemented)

        Cross-feature:
          ├─ Contradiction: F002 vs F005 on auth method
          └─ Dependency: F003 blocked by F001

        Actions:
          → F002: /plan generated (.claude/plans/fix-f002-gaps.md)
          → F003: /plan generated (.claude/plans/implement-f003.md)

      ═══════════════════════════════════════════════════════════════

  7_update_journal:
    action: |
      For each audited feature:
        Add journal entry:
          { action: "checkup_pass"|"checkup_fail", detail: "Conformity: {score}" }

  8_auto_plan:
    condition: "PARTIAL or FAIL or contradiction detected"
    action: |
      For each problem:
        Generate .claude/plans/fix-{feature_id}-{slug}.md
        Add journal entry: { action: "plan_generated", detail: "..." }
```

---

## Journal Actions Reference

| Action | Trigger | Fields |
|--------|---------|--------|
| `created` | --add | detail |
| `modified` | --edit, /do auto-learn | detail, files? |
| `status_change` | --edit --status | detail (from → to) |
| `checkup_pass` | --checkup | detail |
| `checkup_fail` | --checkup | detail |
| `plan_generated` | --checkup auto-plan | detail |
| `compacted` | Journal > 20 entries | detail (N events) |

---

## Journal Compaction

```yaml
compaction:
  trigger: "journal.length > 20 for any feature"
  action: |
    Keep last 20 entries.
    Summarize removed entries into:
      { ts: oldest_ts, action: "compacted", detail: "{N} events compacted" }
    Insert compacted entry at index 0.
  result: "Journal always has <= 21 entries (1 compacted + 20 recent)"
```

---

## Schema Reference

```json
{
  "version": 1,
  "features": [
    {
      "id": "F001",
      "title": "Short title (< 80 chars)",
      "description": "Detailed description of the feature",
      "status": "pending|in_progress|completed|blocked|archived",
      "tags": ["tag1", "tag2"],
      "created": "ISO 8601",
      "updated": "ISO 8601",
      "journal": [
        {
          "ts": "ISO 8601",
          "action": "created|modified|status_change|checkup_pass|checkup_fail|plan_generated|compacted",
          "detail": "Description of what happened",
          "files": ["optional/array/of/paths.ext"]
        }
      ]
    }
  ]
}
```

---

## Guardrails

| Action | Status | Reason |
|--------|--------|--------|
| Delete without confirmation | **FORBIDDEN** | Must use AskUserQuestion |
| Journal > 20 entries | **AUTO-COMPACT** | Keeps DB manageable |
| features.json > 500 features | **WARNING** | Consider archiving |
| Modify features.json schema | **FORBIDDEN** | Version migration needed |
| Store secrets in features.json | **FORBIDDEN** | Git-committed file |

---

## Integration

| Skill | Integration |
|-------|-------------|
| `/do` | Auto-learn: update journal for modified files |
| `/git --commit` | Stage features.json, add journal entries for committed features |
| `/review` | Add checkup_fail journal entry for findings |
| `/init` | Propose --add for discovered features |
| `/warmup` | Load features.json into context |
| `/plan` | Reference features in plan context |
