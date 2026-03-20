# Watch Workflow (--watch)

**Active CI & review monitoring loop -- makes everything green so `--merge` is a clean final action.**

**Flow:** `/git --commit` --> `/git --watch` --> `/git --merge`

```yaml
action_watch:
  trigger: "--watch"
  refresh_interval: 60s
  stop: "Ctrl+C (user interrupt)"

  # ─── Phase 1.0: Resolve PR/MR ───────────────────────────────
  phase_1_resolve:
    description: "Auto-detect PR/MR from current branch"
    steps:
      - detect_platform: "git remote get-url origin → github.com | gitlab.*"
      - resolve_target: "Auto-detect from current branch"
      - get_info:
          github: "mcp__github__pull_request_read(method: get)"
          gitlab: "mcp__gitlab__get_merge_request"
      - pin_commit: "Store HEAD commit SHA for tracking (re-pinned after each fix push)"
      - validate: "PR/MR must exist and be open"
      - fail_if: "No PR/MR found → error with guidance"

  # ─── Phase 2.0: Collect All Prerequisites ────────────────────
  phase_2_collect:
    description: "Gather status of all merge prerequisites"
    parallel:
      pipeline:
        description: "Get check runs / pipeline jobs (job-level, not overall)"
        github: "mcp__github__pull_request_read(method: get_status)"
        gitlab: "mcp__gitlab__list_pipelines + mcp__gitlab__list_pipeline_jobs"
        parse: "Extract individual job statuses, durations, conclusions"

      reviews:
        description: "Fetch bot review statuses"
        note: "CodeRabbit and Qodo are GitHub-only. On GitLab, only Codacy is available."
        sources:
          coderabbit:
            platform: "GitHub only"
            detect: "author.login == 'coderabbitai[bot]'"
            check: "APPROVED | CHANGES_REQUESTED | PENDING"
          qodo:
            platform: "GitHub only"
            detect: "author.login IN ['qodo-merge-pro[bot]', 'qodo-code-review[bot]']"
            check: "P0/P1 findings present?"
          codacy:
            platform: "GitHub and GitLab"
            detect: "Status check from Codacy or mcp__codacy__ API"
            check: "passing | pending | failing"

      prerequisites:
        description: "Merge readiness checks"
        github: "mergeable_state, required_reviews_count, branch_up_to_date"
        gitlab: "detailed_merge_status, approvals_left, has_conflicts"

      human_reviews:
        description: "Human reviewer status"
        action: "Flag but NEVER auto-handle"
        display: "Show status, never attempt to resolve"

  # ─── Phase 3.0: Dashboard Display ───────────────────────────
  phase_3_dashboard:
    description: "Render status dashboard after each collection"
    format: |
      ═══════════════════════════════════════════════════════════════
        /git --watch - PR #{{number}} ({{branch}})     [{{green}}/{{total}} green]
      ═══════════════════════════════════════════════════════════════

        PIPELINE      | {{job_count}} jobs | [{{progress_bar}}] {{passed}}/{{total_jobs}}
          ├─ lint     : ✓ passed (45s)
          ├─ build    : ✓ passed (1m 23s)
          ├─ test     : ⟳ running (2m 15s)
          └─ deploy   : ○ queued

        REVIEWS       | {{source_count}} sources
          ├─ CodeRabbit    : ✓ approved
          ├─ Qodo          : ⚠ 1 P1 finding → fixing...
          └─ Codacy        : ⟳ analyzing (3m)

        PREREQUISITES | {{rule_count}} rules
          ├─ Required reviews (1/1) : ✓
          └─ Branch up-to-date      : ✓

        STATUS: {{green}}/{{total}} green — {{current_action}}
        Next refresh: {{countdown}}s
      ═══════════════════════════════════════════════════════════════
    symbols:
      passed: "✓"
      failed: "✗"
      running: "⟳"
      queued: "○"
      warning: "⚠"
      fixing: "→ fixing..."

  # ─── Phase 4.0: Fix Loop (Circuit Breaker Pattern) ──────────
  phase_4_fix_loop:
    description: "Detect issues and fix them automatically"
    circuit_breaker:
      closed:
        description: "Normal operation"
        flow: "monitor → detect issue → fix → push → wait for re-review → refresh"
        max_fix_iterations: 3  # Total across all issues (matches --merge Phase 3.5.4)
        re_pin_after_push: "After each fix push, refresh PR/MR info and update pin_commit to new HEAD SHA"

      half_open:
        description: "Stall detected — no status change for >10min"
        detection:
          method: "Compare current check/review statuses with previous poll"
          trigger: "No status field changed across 10+ consecutive minutes"
          note: "This is NOT a hard timeout — watch continues but investigates the stall"
          distinction: "The 10min HARD timeout in guardrails applies to --merge CI polling only, not --watch"
        actions:
          - investigate_codacy: "Check if coverage upload missing, check status.codacy.com"
          - investigate_pipeline: "Check if runner available, check GitHub Actions status page"
          - investigate_coderabbit: "If >5min no review, post @coderabbitai review (GitHub only)"
          - report: "Display investigation results to user"

      open:
        description: "Unresolvable issue detected"
        action: "Escalate to user with detailed explanation, exit watch"

    fix_actions:
      coderabbit_changes_requested:
        platform: "GitHub only"
        steps:
          - "Analyze each finding"
          - "Fix if legitimate code issue"
          - "Reply with justification if finding is rejected"
          - "Post @coderabbitai resolve on addressed threads"
          - "Post @coderabbitai review to trigger re-review"
          - "Re-pin commit SHA after push"

      qodo_p0_p1:
        platform: "GitHub only"
        steps:
          - "Analyze P0/P1 findings"
          - "Fix code issues"
          - "Commit with conventional message: fix(scope): address Qodo P1 finding"
          - "Push (auto triggers re-review)"
          - "Re-pin commit SHA after push"

      codacy_failure:
        steps:
          - "Analyze quality issues via mcp__codacy__codacy_list_pull_request_issues"
          - "Fix code issues"
          - "If exclusion needed: ask user before modifying .codacy.yaml"

      pipeline_failure:
        steps:
          - "Analyze job logs"
          - "Identify failure type: lint | type | test | build"
          - "Apply auto-fix: lint→format, type→fix types, test→update assertions"
          - "Commit with conventional message: fix(ci): resolve {{job}} failure"

      branch_behind:
        steps:
          - "Rebase from main/default branch"
          - "Resolve simple conflicts automatically"
          - "Escalate complex conflicts to user"

      merge_conflicts:
        steps:
          - "Attempt auto-resolve for non-overlapping changes"
          - "Escalate overlapping/semantic conflicts to user"

      human_reviews:
        action: "NEVER touch — flag status to user only"

  # ─── Phase 5.0: Exit Conditions ─────────────────────────────
  phase_5_exit:
    all_green:
      action: "Display final dashboard"
      message: "All prerequisites green — ready for /git --merge"
      display_format: |
        ═══════════════════════════════════════════════════════════════
          ✓ All prerequisites green — PR #{{number}} ready to merge
        ═══════════════════════════════════════════════════════════════
          PIPELINE      : ✓ All {{job_count}} jobs passed
          REVIEWS       : ✓ All approved
          PREREQUISITES : ✓ All met
          Duration      : {{elapsed}}

          Next step: /git --merge
        ═══════════════════════════════════════════════════════════════

    user_interrupt:
      action: "Display current state, exit cleanly"
      message: "Watch interrupted — current state displayed above"

    unresolvable:
      action: "Escalate with detailed explanation"
      message: "Cannot auto-resolve: {{reason}} — manual intervention needed"
```
