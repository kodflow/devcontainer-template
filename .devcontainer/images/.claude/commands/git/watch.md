# Watch Workflow (--watch)

**Active CI, review & code quality loop -- resolves ALL issues so `--merge` is a clean final action.**

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

  # ─── Phase 4.0: Pipeline Fix Loop (Circuit Breaker) ────────
  phase_4_pipeline_fix:
    description: "Detect pipeline failures and fix them automatically"
    circuit_breaker:
      closed:
        description: "Normal operation"
        flow: "monitor → detect issue → fix → push → wait → refresh"
        max_fix_iterations: 3
        re_pin_after_push: "After each fix push, refresh PR/MR info and update pin_commit"

      half_open:
        description: "Stall detected — no status change for >10min"
        detection:
          method: "Compare current check/review statuses with previous poll"
          trigger: "No status field changed across 10+ consecutive minutes"
          note: "NOT a hard timeout — watch continues but investigates the stall"
        actions:
          - investigate_codacy: "Check if coverage upload missing"
          - investigate_pipeline: "Check if runner available"
          - investigate_coderabbit: "If >5min no review, post @coderabbitai review"
          - report: "Display investigation results to user"

      open:
        description: "Unresolvable issue detected"
        action: "Escalate to user with detailed explanation, exit watch"

    fix_actions:
      pipeline_failure:
        steps:
          - "Analyze job logs"
          - "Identify failure type: lint | type | test | build | dependency"
          - "Apply auto-fix: lint→format, type→fix types, test→update assertions"
          - "Commit with conventional message: fix(ci): resolve {{job}} failure"
          - "Re-pin commit SHA after push"

      branch_behind:
        steps:
          - "Rebase from main/default branch"
          - "Resolve simple conflicts automatically"
          - "Escalate complex conflicts to user"

      merge_conflicts:
        steps:
          - "Attempt auto-resolve for non-overlapping changes"
          - "Escalate overlapping/semantic conflicts to user"

  # ─── Phase 4.5: Review Triage with Legitimacy Filter ────────
  #
  # THIS IS THE CORE OF --watch: fetch all review findings,
  # judge each one for legitimacy, fix legitimate issues,
  # reject illegitimate ones WITH justification, and reply
  # to each bot explaining the decision.
  #
  # --watch does ALL the review work so --merge has nothing to do.
  # ─────────────────────────────────────────────────────────────
  phase_4_5_review_triage:
    description: "Triage, judge, fix or reject ALL review findings"
    platform: "GitHub (CodeRabbit + Qodo), both (Codacy)"
    max_iterations: 3

    # ── Step 1: Parallel Fetch (platform-conditional) ───────
    fetch:
      github_calls:
        - tool: "mcp__github__pull_request_read"
          params: { method: "get_review_comments" }
          captures: "inline_comments (CodeRabbit + Qodo + Human threads)"
        - tool: "mcp__github__pull_request_read"
          params: { method: "get_comments" }
          captures: "issue_comments (CodeRabbit summary)"
      gitlab_calls:
        - tool: "mcp__gitlab__list_merge_request_notes"
          captures: "mr_notes (human + bot comments)"
        - tool: "mcp__gitlab__list_merge_request_discussions"
          captures: "mr_discussions (unresolved threads)"
      both_platforms:
        - tool: "mcp__codacy__codacy_list_pull_request_issues"
          params: { status: "new" }
          captures: "codacy_issues"

    # ── Step 2: Classify by Source ──────────────────────────
    classify:
      coderabbit:
        detect: "author.login == 'coderabbitai[bot]'"
        relevant: "unresolved AND NOT outdated"
      qodo:
        detect: "author.login IN ['qodo-merge-pro[bot]', 'qodo-code-review[bot]'] AND P0/P1"
        relevant: "P0 or P1 only (P2 ignored)"
      codacy:
        detect: "From mcp__codacy__codacy_list_pull_request_issues"
        relevant: "status='new' AND severity in [Critical, High, Medium]"
      human:
        detect: "is_bot=false"
        action: "NEVER auto-handle — flag to user only"

    # ── Step 3: Legitimacy Filter (CRITICAL) ────────────────
    #
    # Before fixing ANY finding, judge whether it is LEGITIMATE
    # or ILLEGITIMATE. This prevents regressions from blindly
    # applying bot suggestions.
    #
    # ILLEGITIMATE findings (REJECT with justification):
    #   - Downgrade language/tool version (e.g., "use Go 1.21" when project uses 1.26)
    #   - Remove a feature or capability the project intentionally provides
    #   - Change architecture in a way that contradicts CLAUDE.md or project conventions
    #   - Suggest patterns incompatible with the project's stack
    #   - Style preferences that contradict existing codebase conventions
    #   - False positives (rule doesn't apply to this context)
    #
    # LEGITIMATE findings (FIX):
    #   - Real bugs (null pointer, off-by-one, race condition)
    #   - Security vulnerabilities (injection, XSS, hardcoded secrets)
    #   - Unused imports/variables
    #   - Missing error handling
    #   - Performance issues with clear fix
    #   - Documentation/typo fixes
    #   - Actual code quality improvements that align with project conventions
    #
    legitimacy_filter:
      for_each_finding:
        1_read_context: "Read the affected file + surrounding code"
        2_check_project_rules: "Consult CLAUDE.md, language RULES.md, and conventions"
        3_judge: |
          Classify as:
            LEGITIMATE   → real issue, should be fixed
            ILLEGITIMATE → contradicts project, would cause regression
            UNCLEAR      → needs more context → ask user via AskUserQuestion before acting
        4_record_decision: "Store verdict + justification for each finding"

    # ── Step 4: Fix Legitimate Findings ─────────────────────
    fix_loop:
      flow: |
        WHILE relevant_count > 0 AND iteration < max_iterations:
          1. Separate findings into LEGITIMATE vs ILLEGITIMATE
          2. Fix all LEGITIMATE findings (code changes)
          3. Commit: "fix(review): address {source} findings"
          4. Push to branch
          5. Respond to bots (see interaction below)
          6. Wait for re-reviews (max 120s)
          7. Re-fetch and re-classify
          8. Check: relevant_count == 0?

    # ── Step 5: Respond to Bots (MANDATORY) ─────────────────
    #
    # Every finding gets a response. No silent dismissals.
    #
    bot_interaction:
      coderabbit:
        legitimate_fixed:
          action: |
            1. "@coderabbitai pause" (before batch fix)
            2. Apply fixes + commit + push
            3. "@coderabbitai resume"
            4. "@coderabbitai resolve" on fixed threads
            5. "@coderabbitai review" (trigger re-review)

        illegitimate_rejected:
          action: |
            Post a reply on EACH rejected thread via mcp__github__add_reply_to_pull_request_comment:
              "Thank you for the suggestion. We're not applying this change because:
               [REASON — e.g., project uses Go 1.26+ per CLAUDE.md, downgrading would break features].
               This is intentional and consistent with the project conventions."
            Then: "@coderabbitai resolve" to dismiss the thread.

      qodo:
        legitimate_fixed:
          action: "Fix + push (Qodo auto-re-reviews on push)"
        illegitimate_rejected:
          action: |
            Post a reply on the Qodo comment thread:
              "P{level} finding acknowledged but rejected:
               [REASON — e.g., this pattern is intentional for performance].
               Not a regression — consistent with project design."

      codacy:
        legitimate_fixed:
          action: "Fix code + push (Codacy auto-re-analyzes)"
        false_positive:
          action: |
            Ask user via AskUserQuestion:
              Option 1: "Fix the code anyway"
              Option 2: "Add inline suppression (// nolint, # noqa, etc.)"
              Option 3: "Add path exclusion to .codacy.yaml"
              Option 4: "Ignore this finding"
        illegitimate_rejected:
          action: "Ignore (Codacy doesn't have thread resolution)"

      human:
        action: "NEVER auto-handle. Display to user and wait."

    # ── Step 6: Escalation ──────────────────────────────────
    escalation:
      condition: "iteration >= max_iterations AND relevant_count > 0"
      action: |
        Present remaining findings to user:
          Option 1: "Continue fixing (raise iteration limit)"
          Option 2: "Force proceed (override remaining findings)"
          Option 3: "Abort watch"

  # ─── Phase 5.0: Exit Conditions ─────────────────────────────
  phase_5_exit:
    all_green:
      condition: "Pipeline passed + All reviews satisfied + Prerequisites met"
      action: "Display final dashboard"
      message: "All prerequisites green — ready for /git --merge"
      display_format: |
        ═══════════════════════════════════════════════════════════════
          ✓ All prerequisites green — PR #{{number}} ready to merge
        ═══════════════════════════════════════════════════════════════
          PIPELINE      : ✓ All {{job_count}} jobs passed
          REVIEWS       : ✓ All satisfied ({{fixed}} fixed, {{rejected}} rejected with justification)
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
