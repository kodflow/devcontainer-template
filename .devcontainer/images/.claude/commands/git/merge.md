# Merge Workflow (--merge)

Full merge action with CI validation, review triage, auto-fix, and cleanup.

---

## MCP-ONLY Policy (STRICT - Issue #142)

**NEVER use CLI for pipeline status. Always use MCP tools:**

```yaml
mcp_only_policy:
  MANDATORY:
    github:
      pipeline_status: "mcp__github__pull_request_read"
      check_runs: "mcp__github__list_check_runs (via pull_request_read)"
    gitlab:
      pipeline_status: "mcp__gitlab__list_pipelines"
      pipeline_jobs: "mcp__gitlab__list_pipeline_jobs"

  FORBIDDEN:
    - "gh pr checks"
    - "gh run view"
    - "glab ci status"
    - "glab ci view"
    - "curl api.github.com"
    - "curl gitlab.com/api"

  rationale: |
    CLI commands return stale/cached data and require parsing
    MCP provides structured JSON with real-time status
```

---

## Phase 1.0: Peek + Commit-Pinned Tracking

**CRITICAL: Track pipeline for SPECIFIC commit SHA**

```yaml
peek_workflow:
  0_get_pushed_commit:
    action: "Get SHA of just-pushed commit"
    command: "git rev-parse HEAD"
    store: "pushed_commit_sha"
    critical: true

  1_pr_mr_info:
    action: "Retrieve PR/MR info"
    tools:
      github: mcp__github__pull_request_read
      gitlab: mcp__gitlab__get_merge_request
    verify: "head_sha == pushed_commit_sha"
    output: "pr_mr_number, head_sha, status, checks"

  2_find_pipeline:
    action: "Find pipeline triggered by THIS commit"
    github: |
      # Verify: check_run.head_sha == pushed_commit_sha
      mcp__github__pull_request_read(method="get")
    gitlab: |
      # Filter: pipeline.sha == pushed_commit_sha
      mcp__gitlab__list_pipelines(sha=pushed_commit_sha)

  3_validate_pipeline:
    action: "Abort if pipeline not found within 60s"
    timeout: 60s
    on_timeout: "ERROR: No pipeline triggered for commit {sha}"

  4_conflicts:
    action: "Check for conflicts"
    command: "git fetch && git merge-base..."
```

**Output Phase 1:**

```
═══════════════════════════════════════════════════════════════
  /git --merge - Pipeline Tracking
═══════════════════════════════════════════════════════════════

  Commit: abc1234 (verified)
  PR: #42

  Pipeline found:
    ├─ ID: 12345
    ├─ SHA: abc1234 ✓ (matches pushed commit)
    ├─ Triggered: 15s ago
    └─ Status: running

═══════════════════════════════════════════════════════════════
```

---

## Phase 2.0: Job-Level Status Parsing (CRITICAL)

**Parse EACH job individually, not overall status:**

```yaml
status_parsing:
  github:
    statuses:
      success: ["success", "neutral"]
      pending: ["queued", "in_progress", "waiting", "pending"]
      failure: ["failure", "action_required", "timed_out"]
      cancelled: ["cancelled", "stale"]
      skipped: ["skipped"]

    aggregation_rule: |
      # CRITICAL: A single failed job = PIPELINE FAILED
      pipeline_success = ALL jobs in [success, skipped, neutral]
      pipeline_failure = ANY job in [failure, cancelled, timed_out]
      pipeline_pending = ANY job in [pending, queued, in_progress]

      # DO NOT report success if any job failed!

  gitlab:
    statuses:
      success: ["success", "manual"]
      pending: ["created", "waiting_for_resource", "preparing", "pending", "running"]
      failure: ["failed"]
      cancelled: ["canceled"]
      skipped: ["skipped"]

job_by_job_output:
  format: |
    ═══════════════════════════════════════════════════════════════
      CI Status - Commit {sha}
    ═══════════════════════════════════════════════════════════════

      Pipeline: #{id} (triggered {time_ago})
      Branch:   {branch}
      Commit:   {sha} ✓ (verified)

      Jobs:
        ├─ lint      : ✓ passed (45s)
        ├─ build     : ✓ passed (1m 23s)
        ├─ test      : ✗ FAILED (2m 15s)    <-- FAILED
        └─ deploy    : ⊘ skipped

      Overall: ✗ FAILED (1 job failed)

    ═══════════════════════════════════════════════════════════════
```

---

## Phase 3.0: CI Monitoring with Exponential Backoff and Hard Timeout

**ABSOLUTE LIMIT: 10 minutes / 30 polls**

```yaml
ci_monitoring:
  description: "Intelligent CI status tracking with adaptive polling"

  #---------------------------------------------------------------------------
  # CONFIGURATION
  #---------------------------------------------------------------------------
  config:
    initial_interval: 10s          # Initial interval
    max_interval: 120s             # Capped at 2 minutes
    backoff_multiplier: 1.5        # 10s → 15s → 22s → 33s → 50s → 75s → 112s → 120s
    jitter_percent: 20             # +/- 20% random (prevents thundering herd)
    timeout: 600s                  # 10 minutes HARD timeout total
    max_poll_attempts: 30          # Safety limit

  #---------------------------------------------------------------------------
  # POLLING STRATEGY (MCP-ONLY - NO CLI FALLBACK)
  #---------------------------------------------------------------------------
  polling_strategy:
    github:
      tool: mcp__github__pull_request_read
      params:
        pull_number: "{pr_number}"
      response_fields: ["state", "statuses[]", "check_runs[]"]
      # NO FALLBACK - CLI FORBIDDEN

    gitlab:
      tool: mcp__gitlab__list_pipelines
      params:
        project_id: "{project_id}"
        ref: "{branch}"
        per_page: 1
      response_fields: ["status", "id", "web_url"]
      # NO FALLBACK - CLI FORBIDDEN

  #---------------------------------------------------------------------------
  # EXPONENTIAL BACKOFF ALGORITHM
  #---------------------------------------------------------------------------
  backoff_algorithm:
    pseudocode: |
      interval = initial_interval
      elapsed = 0
      attempt = 0

      WHILE elapsed < timeout AND attempt < max_poll_attempts:
        status = poll_ci_status()  # MCP ONLY

        IF status == SUCCESS:
          RETURN {status: "passed", duration: elapsed}
        IF status in [FAILURE, ERROR, CANCELED]:
          RETURN {status: "failed", duration: elapsed, details: get_failure_details()}
        IF status in [PENDING, RUNNING]:
          # Apply jitter
          jitter = interval * (random(-jitter_percent, +jitter_percent) / 100)
          sleep(interval + jitter)
          elapsed += interval + jitter

          # Exponential backoff
          interval = min(interval * backoff_multiplier, max_interval)
          attempt++

      RETURN {status: "timeout", duration: elapsed}

  #---------------------------------------------------------------------------
  # ON TIMEOUT
  #---------------------------------------------------------------------------
  on_timeout:
    action: "ABORT immediately"
    output: |
      ═══════════════════════════════════════════════════════════════
        ⛔ Pipeline Timeout
      ═══════════════════════════════════════════════════════════════

        Waited: 10 minutes
        Polls:  30 attempts
        Status: Still pending

        This usually means:
        - Pipeline is stuck
        - Pipeline was cancelled externally
        - Wrong pipeline being monitored

        Actions:
        1. Check pipeline manually: {pipeline_url}
        2. Re-run: /git --merge
        3. Force: /git --merge --skip-ci (if CI is broken)

      ═══════════════════════════════════════════════════════════════

  #---------------------------------------------------------------------------
  # PARALLEL TASKS (during polling)
  #---------------------------------------------------------------------------
  parallel_tasks:
    - task: "Check conflicts"
      action: "git fetch && git merge-base --is-ancestor origin/main HEAD"
      on_conflict: "Automatic rebase if --auto-rebase"

    - task: "Sync with main"
      action: "Rebase if behind (max 10 commits)"
      on_behind: "git rebase origin/main"
```

**Output Phase 2.5:**

```
═══════════════════════════════════════════════════════════════
  /git --merge - CI Monitoring (Phase 2.5)
═══════════════════════════════════════════════════════════════

  PR/MR    : #42 (feat/add-auth)
  Platform : GitHub
  Timeout  : 10 minutes (HARD LIMIT)

  Polling CI status (MCP-ONLY)...
    [10:30:15] Poll #1: pending (10s elapsed, next in 10s)
    [10:30:27] Poll #2: running (22s elapsed, next in 15s)
    [10:30:45] Poll #3: running (40s elapsed, next in 22s)
    [10:31:12] Poll #4: running (67s elapsed, next in 33s)
    [10:31:50] ✓ CI PASSED (95s)

  Job-level verification:
    ├─ lint: ✓ passed (45s)
    ├─ build: ✓ passed (1m 23s)
    └─ test: ✓ passed (2m 45s)

  Proceeding to Phase 3.5...

═══════════════════════════════════════════════════════════════
```

---

## Phase 3.5: Review Comments Triage (CodeRabbit, Qodo, Codacy)

**After CI passes, triage and resolve review bot findings before merging.**

```yaml
review_triage:
  description: "Fetch, classify, fix, and interact with review bots until satisfied"

  #---------------------------------------------------------------------------
  # CONFIGURATION
  #---------------------------------------------------------------------------
  config:
    max_iterations: 3                    # Review-fix-recheck loop limit
    wait_for_re_review: 120s             # Max wait for bot re-review after push
    sources: [coderabbit, qodo, codacy, human]
    platform: "github"                   # Phase 3.5 is GitHub-only (CodeRabbit/Qodo are GitHub bots)
    skip_conditions:
      - "No review comments exist on the PR/MR"
      - "--skip-review flag was passed"
      - "Platform is GitLab (CodeRabbit/Qodo not available on GitLab)"

  #---------------------------------------------------------------------------
  # Phase 3.5.1: Parallel Fetch (GitHub-only)
  #---------------------------------------------------------------------------
  # NOTE: CodeRabbit and Qodo are GitHub-specific bots.
  # On GitLab, Phase 3.5 is skipped entirely (only Codacy runs on both,
  # but its findings are surfaced via CI checks, not review comments).
  #
  # Fetch ALL review feedback in ONE parallel call:
  #
  # 1. mcp__github__pull_request_read(method="get_review_comments")
  #    → CodeRabbit + Qodo + Human inline comments
  #
  # 2. mcp__github__pull_request_read(method="get_comments")
  #    → Issue-level comments (CodeRabbit summary)
  #
  # 3. mcp__codacy__codacy_list_pull_request_issues(status="new")
  #    → Codacy-specific findings
  #
  # All three calls are independent → execute in parallel.
  #---------------------------------------------------------------------------
  phase_3_5_1_fetch:
    action: "Fetch all review feedback in parallel"
    parallel_calls:
      - tool: "mcp__github__pull_request_read"
        params: { method: "get_review_comments" }
        captures: "inline_comments"
      - tool: "mcp__github__pull_request_read"
        params: { method: "get_comments" }
        captures: "issue_comments"
      - tool: "mcp__codacy__codacy_list_pull_request_issues"
        params: { status: "new" }
        captures: "codacy_issues"

  #---------------------------------------------------------------------------
  # Phase 3.5.2: Classification
  #---------------------------------------------------------------------------
  # Classify each comment by source and relevance.
  #---------------------------------------------------------------------------
  phase_3_5_2_classify:
    action: "Classify comments by source and filter by relevance"

    source_detection:
      coderabbit:
        rule: "author.login == 'coderabbitai[bot]'"
      qodo:
        rule: |
          author.login IN ['qodo-merge-pro[bot]', 'qodo-code-review[bot]', 'github-actions[bot]']
          AND content matches Qodo format with P0/P1/P2
        alt_logins: ["qodo-merge-pro[bot]", "qodo-code-review[bot]", "github-actions[bot]"]
      codacy:
        rule: "From mcp__codacy__codacy_list_pull_request_issues API"
      human:
        rule: "is_bot=false"

    relevance_filter:
      coderabbit:
        relevant: "unresolved AND NOT outdated"
        irrelevant: "resolved OR outdated"
      qodo:
        relevant: "P0 (BLOCKER) or P1 (MAJOR)"
        irrelevant: "P2 (MINOR)"
      codacy:
        relevant: "status='new' AND severity in [Critical, High, Medium]"
        irrelevant: "status='fixed' OR severity in [Low, Info]"
      human:
        relevant: "ALL unresolved (HIGHEST priority)"
        irrelevant: "resolved only"

  #---------------------------------------------------------------------------
  # Phase 3.5.3: Prioritization
  #---------------------------------------------------------------------------
  phase_3_5_3_prioritize:
    action: "Sort findings by priority"
    priority_order:
      1: "Human unresolved comments"
      2: "CodeRabbit unresolved findings (blocks merge via request_changes)"
      3: "Qodo P0 blockers"
      4: "Codacy Critical/High issues"
      5: "Qodo P1 majors"
      6: "Codacy Medium issues"
      7: "CodeRabbit non-blocking suggestions (lowest)"
    skip_condition: "If 0 relevant findings → output 'No review issues' → proceed to Phase 5.5"

  #---------------------------------------------------------------------------
  # Phase 3.5.4: Fix Loop
  #---------------------------------------------------------------------------
  phase_3_5_4_fix_loop:
    action: "Iterative fix loop until all relevant findings resolved"
    max_iterations: 3

    loop: |
      WHILE relevant_count > 0 AND iteration < max_iterations:
        1. Generate fix plan from prioritized findings
        2. Apply fixes (code changes)
        3. Commit: "fix(review): address {source} findings"
        4. Push to branch
        5. Interact with bots:
           - CodeRabbit: post "@coderabbitai resolve" then "@coderabbitai review"
           - Qodo: no action (auto-re-reviews on push)
           - Codacy: no action (auto-re-analyzes on push)
           - Human: no action (never auto-dismiss)
        6. Wait for re-reviews (MCP-only polling with wait_for_re_review 120s cap)
        7. Re-fetch and re-classify (repeat Phase 3.5.1 + 3.5.2)
        8. Check satisfaction: relevant_count == 0?

    coderabbit_interaction:
      resolve: "mcp__github__add_issue_comment(body='@coderabbitai resolve')"
      re_review: "mcp__github__add_issue_comment(body='@coderabbitai review')"
      pause: "mcp__github__add_issue_comment(body='@coderabbitai pause')"
      resume: "mcp__github__add_issue_comment(body='@coderabbitai resume')"
      sequence: |
        During batch fixes:
          1. "@coderabbitai pause" (before fixing multiple files)
          2. Apply all fixes + commit + push
          3. "@coderabbitai resume"
          4. "@coderabbitai resolve" (dismiss fixed findings)
          5. "@coderabbitai review" (trigger fresh re-review)

    codacy_false_positive_handling:
      description: "When Codacy finding is a false positive that cannot be fixed"
      action: |
        1. Identify if issue is a false positive (wrong rule for this context)
        2. Ask user via AskUserQuestion:
           Option 1: "Fix the code"
           Option 2: "Add inline suppression (// nolint:rule, # noqa, etc.)"
           Option 3: "Add path exclusion to .codacy.yaml"
           Option 4: "Ignore this finding"
        3. If .codacy.yaml exclusion chosen:
           Edit .codacy.yaml with new exclude_paths entry
           or engines.{tool}.exclude_paths

    escalation:
      condition: "iteration >= max_iterations AND relevant_count > 0"
      action: |
        Present remaining findings to user via AskUserQuestion:
          Option 1: "Continue fixing (raise iteration limit)"
          Option 2: "Merge anyway (override review findings)"
          Option 3: "Abort merge"

    #---------------------------------------------------------------------------
    # UNBLOCK: Reply to dismiss non-actionable findings
    #---------------------------------------------------------------------------
    # After all fixes are applied, if CodeRabbit still has CHANGES_REQUESTED
    # due to dismissed suggestions (not bugs), post a structured reply on
    # EACH unresolved thread explaining the decision. CodeRabbit will then
    # re-evaluate and either resolve the thread or approve.
    #---------------------------------------------------------------------------
    unblock_stale_reviews:
      trigger: "All actionable findings fixed but CHANGES_REQUESTED persists"
      action: |
        FOR each unresolved review thread:
          IF finding was intentionally not fixed (design decision):
            Post reply on the thread via mcp__github__add_issue_comment:
              - Acknowledge the suggestion
              - Explain why it was not applied (with justification)
              - Reference the design decision or consistency argument
          THEN:
            Post "@coderabbitai resolve" to dismiss resolved threads
            Post "@coderabbitai review" to trigger fresh evaluation
      rule: |
        NEVER ignore findings silently. Each dismissed finding MUST have
        a justified reply on the thread. This unblocks CodeRabbit's
        CHANGES_REQUESTED state for merge.
```

**Output Phase 3.5 (Triage Summary):**

```text
═══════════════════════════════════════════════════════════════
  /git --merge - Review Triage (Phase 3.5)
═══════════════════════════════════════════════════════════════

  Sources:
    ├─ CodeRabbit: 3 findings (2 relevant)
    ├─ Qodo: 1 P0, 2 P2 (1 relevant)
    ├─ Codacy: 4 new issues (3 relevant)
    └─ Human: 0 comments

  Total relevant: 6 findings
  Action: Entering fix loop...

═══════════════════════════════════════════════════════════════
```

**Output Phase 3.5 (Satisfaction Report):**

```text
═══════════════════════════════════════════════════════════════
  /git --merge - Reviews Satisfied (Phase 3.5)
═══════════════════════════════════════════════════════════════

  Iterations: 2/3
  Fixed: 5 findings
  Dismissed: 1 (Codacy false positive)
  Remaining: 0

  Commits added:
    └─ fix(review): address coderabbit + codacy findings

  Proceeding to Phase 5.5...

═══════════════════════════════════════════════════════════════
```

**Output Phase 3.5 (No Findings):**

```text
═══════════════════════════════════════════════════════════════
  /git --merge - Review Triage (Phase 3.5)
═══════════════════════════════════════════════════════════════

  Sources:
    ├─ CodeRabbit: 0 findings
    ├─ Qodo: 0 findings
    ├─ Codacy: 0 issues
    └─ Human: 0 comments

  No review issues found.
  Proceeding to Phase 5.5...

═══════════════════════════════════════════════════════════════
```

---

## Phase 4.0: Error Log Extraction (on failure)

**When pipeline fails, extract actionable information:**

```yaml
error_extraction:
  step_1_identify:
    action: "Get list of failed jobs"
    output: "[job_name, job_id, failure_reason]"

  step_2_parse_error:
    patterns:
      lint_error:
        - "eslint.*error"
        - "golangci-lint"
        - "clippy::"
        - "ruff.*error"
      build_error:
        - "cannot find module"
        - "compilation failed"
        - "cargo build.*error"
        - "tsc.*error"
      test_error:
        - "FAIL.*test"
        - "AssertionError"
        - "--- FAIL:"
        - "pytest.*FAILED"
      security_error:
        - "CRITICAL.*vulnerability"
        - "CVE-"
        - "HIGH.*severity"

  step_3_generate_debug_plan:
    output: |
      ═══════════════════════════════════════════════════════════════
        Pipeline Failed - Debug Plan
      ═══════════════════════════════════════════════════════════════

        Failed Job: {job_name}
        Error Type: {error_type}
        Exit Code:  {exit_code}

        Error Summary:
        ┌─────────────────────────────────────────────────────────────
        │ {error_excerpt_20_lines}
        └─────────────────────────────────────────────────────────────

        Suggested Actions:
        1. {action_1_based_on_error_type}
        2. {action_2_based_on_error_type}
        3. Run locally: {local_command}

        Next Step: Run `/plan debug {error_type}` to investigate

      ═══════════════════════════════════════════════════════════════
```

---

## Phase 5.0: Auto-fix Loop with Error Categories

```yaml
autofix_loop:
  description: "Detection, categorization and automatic correction of CI errors"

  #---------------------------------------------------------------------------
  # CONFIGURATION
  #---------------------------------------------------------------------------
  config:
    max_attempts: 3
    cooldown_between_attempts: 30s    # Wait before re-triggering CI
    autofix_per_attempt_timeout: 120s # 2 min max per fix attempt
    require_human_for:
      - security_scan
      - timeout
      - "confidence == LOW after 2 attempts"

  #---------------------------------------------------------------------------
  # ERROR CATEGORIES
  #---------------------------------------------------------------------------
  error_categories:
    #-------------------------------------------------------------------------
    # LINT ERRORS - Auto-fixable (HIGH confidence)
    #-------------------------------------------------------------------------
    lint_error:
      patterns:
        - "eslint.*error"
        - "prettier.*differ"
        - "golangci-lint.*"
        - "ruff.*error"
        - "shellcheck.*SC[0-9]+"
        - "stylelint.*"
      severity: LOW
      auto_fixable: true
      confidence: HIGH
      fix_strategy: "run_linter_fix"

    #-------------------------------------------------------------------------
    # TYPE ERRORS - Partially auto-fixable
    #-------------------------------------------------------------------------
    type_error:
      patterns:
        - "TS[0-9]+:"                    # TypeScript errors
        - "type.*incompatible"
        - "cannot find name"
        - "go build.*undefined:"         # Go type errors
        - "mypy.*error:"                 # Python mypy
      severity: MEDIUM
      auto_fixable: partial
      confidence: MEDIUM
      fix_strategy: "type_fix"

    #-------------------------------------------------------------------------
    # TEST FAILURES - Conditional auto-fix
    #-------------------------------------------------------------------------
    test_failure:
      patterns:
        - "FAIL.*test"
        - "AssertionError"
        - "expected.*but got"
        - "Error: expect\\("
        - "--- FAIL:"                    # Go test failures
        - "FAILED.*::.*::"               # pytest
      severity: HIGH
      auto_fixable: conditional
      confidence: MEDIUM
      fix_strategy: "test_analysis"

    #-------------------------------------------------------------------------
    # BUILD ERRORS - Requires careful analysis
    #-------------------------------------------------------------------------
    build_error:
      patterns:
        - "error: cannot find module"
        - "Module not found"
        - "compilation failed"
        - "SyntaxError:"
        - "package.*not found"
      severity: HIGH
      auto_fixable: partial
      confidence: LOW
      fix_strategy: "build_analysis"

    #-------------------------------------------------------------------------
    # SECURITY SCAN - NEVER auto-fix
    #-------------------------------------------------------------------------
    security_scan:
      patterns:
        - "CRITICAL.*vulnerability"
        - "HIGH.*CVE-"
        - "security.*violation"
        - "secret.*detected"
        - "trivy.*CRITICAL"
      severity: CRITICAL
      auto_fixable: false
      confidence: N/A
      fix_strategy: "user_intervention_required"

    #-------------------------------------------------------------------------
    # DEPENDENCY ERRORS - Often auto-fixable
    #-------------------------------------------------------------------------
    dependency_error:
      patterns:
        - "npm ERR!.*peer dep"
        - "cannot resolve dependency"
        - "go: module.*not found"
        - "pip.*ResolutionImpossible"
      severity: MEDIUM
      auto_fixable: true
      confidence: MEDIUM
      fix_strategy: "dependency_fix"

    #-------------------------------------------------------------------------
    # INFRASTRUCTURE ERRORS - Retry only
    #-------------------------------------------------------------------------
    infrastructure_error:
      patterns:
        - "rate limit"
        - "connection refused"
        - "503 Service Unavailable"
        - "ECONNRESET"
      severity: LOW
      auto_fixable: retry
      confidence: HIGH
      fix_strategy: "retry_ci"

  #---------------------------------------------------------------------------
  # LOOP ALGORITHM
  #---------------------------------------------------------------------------
  loop_algorithm:
    pseudocode: |
      attempt = 0
      fix_history = []

      WHILE attempt < max_attempts:
        attempt++

        # Step 1: Retrieve CI failure details
        failure = get_ci_failure_details()
        category = categorize_error(failure)

        # Step 2: Check if auto-fixable
        IF NOT category.auto_fixable:
          RETURN abort_with_report(category, failure)

        # Step 3: Detect circular fix
        IF is_circular_fix(category, fix_history):
          RETURN abort_with_circular_warning(fix_history)

        # Step 4: Apply fix strategy
        fix_result = apply_fix_strategy(category)
        fix_history.append({category, fix_result})

        IF fix_result.success:
          # Step 5: Commit and push
          commit_fix(fix_result)
          push_to_remote()

          # Step 6: Wait cooldown then re-poll CI
          sleep(cooldown_between_attempts)
          ci_status = poll_ci_with_backoff()  # Re-use Phase 2.5

          IF ci_status == SUCCESS:
            RETURN success_report(attempt, fix_history)
        ELSE:
          RETURN abort_with_fix_failure(fix_result)

      # Max attempts reached
      RETURN abort_max_attempts(fix_history)

  #---------------------------------------------------------------------------
  # FIX STRATEGIES
  #---------------------------------------------------------------------------
  fix_strategies:
    run_linter_fix:
      detect_linter:
        - check: "package.json"
          command: "npm run lint -- --fix"
        - check: ".golangci.yml"
          command: "golangci-lint run --fix"
        - check: "pyproject.toml [tool.ruff]"
          command: "ruff check --fix"
      commit_format: "fix(lint): auto-fix {linter} errors"

    type_fix:
      workflow:
        1_extract: "Parse CI log for specific type errors"
        2_analyze: "Identify the file and line"
        3_fix: "Apply minimal correction"
        4_verify: "npm run typecheck OR go build"
      commit_format: "fix(types): resolve {error_code} in {file}"

    test_analysis:
      conditions:
        assertion_mismatch:
          pattern: "expected.*but got"
          auto_fix: true
          strategy: "Update assertion if implementation changed"
        snapshot_mismatch:
          pattern: "snapshot.*differ"
          auto_fix: true
          strategy: "npm test -- -u"
        timeout:
          pattern: "exceeded timeout"
          auto_fix: false
      commit_format: "fix(test): update {test_name}"

    dependency_fix:
      strategies:
        npm: "npm install --legacy-peer-deps"
        go: "go mod tidy"
        pip: "pip install --upgrade"
      commit_format: "fix(deps): resolve {package} conflict"

    retry_ci:
      wait: 60s
      retrigger:
        github: "gh run rerun --failed"
        gitlab: "glab ci retry"

    user_intervention_required:
      action: "Generate detailed failure report"
      include:
        - "Error category and severity"
        - "Relevant CI log snippets (max 50 lines)"
        - "Affected files"
        - "Suggested manual steps"
      block_merge: true
```

**Output Phase 4 (Auto-fix Success):**

```
═══════════════════════════════════════════════════════════════
  /git --merge - Auto-fix Loop (Phase 4)
═══════════════════════════════════════════════════════════════

  Attempt 1/3 - lint_error
  -------------------------
    Category : lint_error (LOW severity)
    Confidence: HIGH
    Auto-fix : YES

    Error: eslint: 3 errors in src/utils/parser.ts
      ├─ Line 45: no-unused-vars
      ├─ Line 67: prefer-const
      └─ Line 89: no-console

    Fix: npm run lint -- --fix
    Result: ✓ Fixed

    Commit: fix(lint): auto-fix eslint errors in parser.ts
    Push: origin/feat/add-parser

    Re-polling CI...
      [10:32:45] ✓ CI PASSED (67s)

═══════════════════════════════════════════════════════════════
  ✓ Auto-fix Successful (1 attempt)
═══════════════════════════════════════════════════════════════

  Commits added: 1
    └─ fix(lint): auto-fix eslint errors in parser.ts

  Proceeding to Phase 5 (Merge)...

═══════════════════════════════════════════════════════════════
```

**Output Phase 4 (Security Block):**

```
═══════════════════════════════════════════════════════════════
  /git --merge - BLOCKED (Security Issue)
═══════════════════════════════════════════════════════════════

  ⛔ AUTO-FIX DISABLED for security issues

  Category: security_scan
  Severity: CRITICAL

  Vulnerability:
    ┌─────────────────────────────────────────────────────────┐
    │ CRITICAL CVE-2023-44487                                 │
    │ Package: golang.org/x/net v0.7.0                        │
    │ Fixed in: v0.17.0                                       │
    └─────────────────────────────────────────────────────────┘

  Required Actions:
    1. go get golang.org/x/net@v0.17.0 && go mod tidy
    2. trivy fs --severity CRITICAL .
    3. Re-run /git --merge

  ⚠️  Force merge NOT available for security issues.

═══════════════════════════════════════════════════════════════
```

---

## Phase 5.5: PR/MR Description Regeneration (MANDATORY before merge)

**Regenerates the PR/MR title and body from the final branch state.**

Between PR creation and merge, significant changes may be pushed (auto-fixes,
additional commits). The PR description becomes stale. Since squash merge uses
the PR title/body as the commit message, regeneration ensures accuracy.

```yaml
pr_regeneration_workflow:
  trigger: "ALWAYS (mandatory before merge)"
  position: "After Phase 5.0 (auto-fix), before Phase 6.0 (merge)"
  rationale: "Squash commit message comes from PR title/body — must reflect final state"

  1_get_full_diff:
    action: "Get complete diff between branch and main"
    tools:
      github: "mcp__github__pull_request_read (method: get_files)"
      fallback: "git diff main...HEAD --stat"
    output: "changed_files[] with additions/deletions"

  2_get_all_commits:
    action: "Get all commits on the branch"
    command: "git log main..HEAD --oneline"
    output: "commits[] (full branch history)"

  3_analyze_changes:
    action: "Categorize changes by type, scope, and impact"
    algorithm: |
      FOR each commit IN commits:
        IF message matches 'type(scope): description':
          categorize(type, scope, description)
        ELSE:
          infer_type_from_files(commit)
      GROUP BY type → feat, fix, docs, refactor, test, chore
      IDENTIFY primary_scope from most-changed directory
      COUNT files_changed, additions, deletions

  4_generate_pr_description:
    action: "Generate new PR title and body from scratch"
    title_format: "<type>(<scope>): <summary>"
    body_format: |
      ## Summary
      <bullet points of actual changes — what and why>

      ## Changes
      <file-level detail grouped by category>

      ## Test plan
      <bulleted checklist of verification steps>

  5_update_pr_mr:
    action: "Update PR/MR via MCP"
    tools:
      github: "mcp__github__update_pull_request"
      gitlab: "glab mr update"
    fields:
      - title (new conventional format)
      - body (regenerated from final state)

  6_log_regeneration:
    action: "Log the update in output"
```

**Output Phase 5.5:**

```text
═══════════════════════════════════════════════════════════════
  /git --merge - PR Description Regeneration (Phase 5.5)
═══════════════════════════════════════════════════════════════

  Branch: feat/add-auth (12 commits, 34 files changed)

  Analysis:
    ├─ feat: 8 commits (auth module, middleware, tests)
    ├─ fix: 3 commits (lint fixes, type corrections)
    └─ docs: 1 commit (CLAUDE.md updates)

  PR #42 updated:
    Title: feat(auth): add user authentication with JWT
    Body: Regenerated from 12 commits and 34 files

═══════════════════════════════════════════════════════════════
```

---

## Phase 6.0: Synthesize (Merge & Cleanup)

```yaml
merge_workflow:
  1_final_verify:
    action: "Verify ALL jobs passed (job-level check)"
    tools:
      github: mcp__github__pull_request_read
      gitlab: mcp__gitlab__get_merge_request
    condition: "ALL check_runs.conclusion == 'success'"

  1.5_pre_merge_test:
    action: "Test merge result BEFORE actual merge"
    commands:
      - "git fetch origin main"
      - "git merge origin/main --no-commit --no-ff"
      - "{test_command}"
      - "git merge --abort"  # cleanup
    on_failure: "ABORT merge, report conflicts/failures"

  2_merge:
    tools:
      github: mcp__github__merge_pull_request
      gitlab: mcp__gitlab__merge_merge_request
    method: "squash"

  3_cleanup:
    actions:
      - "git push origin --delete <branch>"
      - "git branch -D <branch>"
      - "git checkout main"
      - "git pull origin main"
```

**Final Output (GitHub):**

```
═══════════════════════════════════════════════════════════════
  ✓ PR #42 merged successfully
═══════════════════════════════════════════════════════════════

  Branch  : feat/add-auth → main
  Method  : squash
  Rebase  : ✓ Synced (was 3 commits behind)

  CI (job-level verification):
    ├─ lint      : ✓ passed
    ├─ build     : ✓ passed
    ├─ test      : ✓ passed
    └─ security  : ✓ passed

  Total CI Time: 2m 34s

  Commits : 5 commits → 1 squashed

  Cleanup:
    ✓ Remote branch deleted
    ✓ Local branch deleted
    ✓ Switched to main
    ✓ Pulled latest (now at abc1234)

═══════════════════════════════════════════════════════════════
```

**Final Output (GitLab):**

```
═══════════════════════════════════════════════════════════════
  ✓ MR !42 merged successfully
═══════════════════════════════════════════════════════════════

  Branch  : feat/add-auth → main
  Method  : squash
  Pipeline: ✓ Passed (#12345, 2m 34s)
  Commits : 5 commits → 1 squashed

  Cleanup:
    ✓ Remote branch deleted
    ✓ Local branch deleted
    ✓ Switched to main
    ✓ Pulled latest (now at abc1234)

═══════════════════════════════════════════════════════════════
```
