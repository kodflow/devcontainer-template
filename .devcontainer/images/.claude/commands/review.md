---
name: review
description: |
  AI-powered code review (RLM decomposition) for PRs or local diffs.
  Focus: security, quality, maintainability, shell safety, and review synthesis.
  Works in Claude Code with Git + MCP (GitHub/Codacy).
allowed-tools:
  - "Bash(git *)"
  - "Bash(gh *)"
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "mcp__github__*"
  - "mcp__codacy__*"
  - "mcp__grepai__*"
  - "Task(*)"
---

# Review - AI Code Review (RLM Architecture)

## Overview

Intelligent code review using **Recursive Language Model** decomposition:

| Phase | Name | Action |
|-------|------|--------|
| 0 | Context | Detect PR, branch, CI status |
| 1 | Intent | Analyze PR title/description/scope |
| 2 | Feedback | Collect ALL comments/reviews |
| 3 | Peek | Snapshot diff, categorize files |
| 4 | Analyze | Parallel sub-agents (security, quality, shell) |
| 5 | Challenge | Evaluate feedback relevance with context |
| 6 | Plan | Generate prioritized action plan |

**Principe RLM** : Peek → Decompose → Parallelize → Synthesize

---

## Usage

```
/review                    # Review current changes (auto-detect PR or local)
/review --pr [number]      # Review specific PR
/review --staged           # Review staged changes only
/review --file <path>      # Review specific file
/review --security         # Security-focused review only
/review --quality          # Quality-focused review only
/review --triage           # Large PR mode (>30 files or >1500 lines)
```

---

## Budget Controller (OBLIGATOIRE)

```yaml
budget_controller:
  thresholds:
    normal_mode:
      max_files: 30
      max_lines: 1500
      max_comments_ingested: 80
    triage_mode:
      trigger: "files > 30 OR lines > 1500"
      action: "Focus sur: unresolved threads, lignes modifiées, security only"

  output_limits:
    critical: unlimited
    high: 10
    medium: 5
    low: 3

  comment_priority:
    1: "Unresolved threads"
    2: "Comments on modified lines"
    3: "Human reviews"
    4: "AI bot suggestions"
```

**Décision automatique :**

| Situation | Mode |
|-----------|------|
| diff < 1500 lines, files < 30 | NORMAL |
| diff >= 1500 OR files >= 30 | TRIAGE |
| comments > 80 | FILTER (unresolved + modified lines only) |

---

## Phase 0 : Context Detection

**Identifier le contexte d'exécution :**

```yaml
context_detection:
  1_git_state:
    tools:
      - "git remote -v"
      - "git branch --show-current"
      - "git rev-parse --abbrev-ref HEAD@{upstream} 2>/dev/null || echo 'no-upstream'"
    output:
      current_branch: string
      upstream: string
      remote: "origin" | "upstream"

  2_pr_detection:
    tools:
      - "mcp__github__list_pull_requests(head: current_branch)"
    output:
      on_pr: boolean
      pr_number: number | null
      pr_url: string | null
      target_branch: string  # base branch de la PR

  3_diff_source:
    rule: |
      SI on_pr == true:
        source = "PR diff via MCP"
        base = target_branch
        head = current_branch
      SINON:
        source = "local diff"
        base = "git merge-base origin/main HEAD"
        head = "HEAD"
    output:
      diff_source: "pr" | "local"
      merge_base: string
      display: "Reviewing: {base}...{head}"

  4_ci_status:
    condition: "on_pr == true"
    tool: "mcp__github__get_pull_request_status"
    strategy:
      max_polls: 2
      poll_interval: 30s
      on_pending: "Continue avec warning 'CI pending'"
      on_failure: "Signaler dans report, ne pas bloquer"
    output:
      ci_status: "passing|pending|failing|unknown"
      ci_jobs: [{name, status, conclusion}]
```

**Output Phase 0 :**

```
═══════════════════════════════════════════════════════════════
  /review - Context Detection
═══════════════════════════════════════════════════════════════

  Branch: feat/post-compact-hook
  PR: #97 (open) → main
  Diff source: PR (mcp__github)
  Merge base: a60a896...847d6db

  CI Status: ✓ passing (3/3 jobs)
    ├─ build: passed (1m 23s)
    ├─ test: passed (2m 45s)
    └─ lint: passed (45s)

  Mode: NORMAL (18 files, 375 lines)

═══════════════════════════════════════════════════════════════
```

---

## Phase 1 : Intent Analysis

**Comprendre l'intention de la PR AVANT analyse lourde :**

```yaml
intent_analysis:
  inputs:
    - "mcp__github__get_pull_request (title, body, labels)"
    - "mcp__github__get_pull_request_files (file list)"
    - "git diff --stat"

  extract:
    title: string
    description: string (first 500 chars)
    labels: [string]
    files_changed: number
    lines_added: number
    lines_deleted: number
    directories_touched: [string]
    file_categories:
      security: count
      shell: count
      config: count
      tests: count
      docs: count
      code: count

  calibration:
    rule: |
      SI files_changed <= 5 AND only docs/config:
        analysis_depth = "light"
        skip_patterns = true
      SINON SI security_files > 0 OR shell_files > 0:
        analysis_depth = "deep"
        force_security_scan = true
      SINON:
        analysis_depth = "normal"
```

**Output Phase 1 :**

```
═══════════════════════════════════════════════════════════════
  /review - Intent Analysis
═══════════════════════════════════════════════════════════════

  Title: feat(hooks): add SessionStart hook
  Labels: [enhancement]

  Scope:
    ├─ Files: 18 (+375, -12)
    ├─ Dirs: .devcontainer/, .claude/
    └─ Categories: shell(2), config(3), code(13)

  Calibration:
    ├─ Depth: DEEP (shell files detected)
    ├─ Security scan: FORCED
    └─ Pattern analysis: CONDITIONAL

═══════════════════════════════════════════════════════════════
```

---

## Phase 2 : Feedback Collection

**Collecter les feedbacks avec budget et priorisation :**

```yaml
feedback_collection:
  1_fetch:
    tools:
      - "mcp__github__get_pull_request_reviews"
      - "mcp__github__get_pull_request_comments"
      - "mcp__codacy__codacy_list_pull_request_issues"

  2_budget_filter:
    rule: |
      SI count(all_feedback) > 80:
        filter = "unresolved + modified_lines_only"
      SINON:
        filter = "all"

  3_classify:
    method: |
      POUR chaque feedback:
        SI author.type == "Bot" OR author.login ends with "[bot]":
          category = "ai_review"
        SINON:
          category = "human_review"

        SI body contains "?" AND NOT suggestion_code:
          type = "question"
        SINON SI suggestion_code != null:
          type = "suggestion"
        SINON:
          type = "comment"

  4_prioritize:
    order:
      1: "unresolved human reviews"
      2: "questions (need response)"
      3: "suggestions on modified lines"
      4: "ai reviews (behavior extraction)"
      5: "resolved/outdated"
```

**Classification output :**

| Category | Type | Count | Priority |
|----------|------|-------|----------|
| Human | Question | 2 | HIGH |
| Human | Comment | 3 | MEDIUM |
| AI (coderabbit) | Suggestion | 5 | EXTRACT |
| AI (qodo) | Suggestion | 3 | EXTRACT |

---

## Phase 2.5 : Question Handling

**Préparer réponses pour questions humaines :**

```yaml
question_handling:
  rule_absolute: "JAMAIS mentionner AI/Claude/IA dans les réponses"

  forbidden_phrases:
    - "Claude", "AI", "IA", "assistant", "LLM"
    - "j'ai été généré", "automatiquement généré"
    - "l'intelligence artificielle suggère"

  workflow:
    1_collect: "Extraire questions des reviews humains"
    2_prepare: |
      POUR chaque question:
        answer = generate_answer(question, context)
        validate: no_forbidden_phrases(answer)

    3_present:
      format: |
        ## Question by {author}
        > {question_text}

        **Proposed answer:**
        {answer}

        [Post / Edit / Skip]

    4_user_validates: "AskUserQuestion avant de poster"
    5_post: "mcp__github__add_issue_comment (si validé)"
```

---

## Phase 2.6 : Behavior Extraction (AI Reviews)

**Extraire axes comportementaux des reviews AI :**

```yaml
behavior_extraction:
  filter:
    - "importance >= 6/10"
    - "not already in workflow"
    - "actionable pattern"

  extract:
    from: "{bot_suggestion_text}"
    to:
      behavior: "description courte du pattern"
      category: "shell_safety|security|quality|pattern"
      check: "question à ajouter au workflow"

  action:
    auto: false
    prompt_user: |
      Nouveau pattern détecté:
        Behavior: {behavior}
        Category: {category}

      Ajouter au workflow /review? [Oui/Non]
```

---

## Phase 3 : Peek & Decompose

**Snapshot du diff et catégorisation :**

```yaml
peek_decompose:
  1_diff_snapshot:
    tool: |
      SI diff_source == "pr":
        mcp__codacy__codacy_get_pull_request_git_diff
      SINON:
        git diff --merge-base {base}...HEAD

    extract:
      files: [{path, status, additions, deletions}]
      total_lines: number
      hunks_count: number

  2_categorize:
    rules:
      security:
        patterns: ["auth", "crypto", "password", "token", "secret", "jwt"]
        extensions: [".go", ".py", ".js", ".ts", ".java"]
      shell:
        extensions: [".sh"]
        files: ["Dockerfile", "Makefile"]
      config:
        extensions: [".json", ".yaml", ".yml", ".toml"]
        files: ["mcp.json", "settings.json", "*.config.*"]
      tests:
        patterns: ["*_test.*", "*.test.*", "*.spec.*", "test_*"]
      docs:
        extensions: [".md"]

  3_mode_decision:
    rule: |
      SI total_lines > 1500 OR files.count > 30:
        mode = "TRIAGE"
      SINON:
        mode = "NORMAL"
```

---

## Phase 4 : Parallel Analysis

**Lancer sub-agents avec contrat JSON strict :**

```yaml
parallel_analysis:
  dispatch:
    mode: "parallel (single message, multiple Task calls)"
    agents:
      - security-scanner
      - quality-checker
      - shell-safety-checker (si shell files > 0)

  agent_contract:
    input:
      files: [string]
      diff: string
      mode: "normal|triage"

    output_schema:
      agent: string
      summary: string (max 200 chars)
      findings:
        - severity: "CRITICAL|HIGH|MEDIUM|LOW"
          category: "security|quality|shell|tests|config"
          file: string
          line: number
          title: string (max 80 chars)
          evidence: string (max 200 chars, NO SECRETS)
          recommendation: string
          confidence: "HIGH|MEDIUM|LOW"
          in_modified_lines: boolean
      metrics:
        files_scanned: number
        findings_count: number

  severity_rubric:
    CRITICAL:
      - "Vuln exploitable (RCE, injection, auth bypass)"
      - "Secret/token exposé"
      - "Supply chain non vérifiée"
    HIGH:
      - "Bug probable (null deref, race condition)"
      - "Data loss potentiel"
      - "Performance killer"
    MEDIUM:
      - "Dette technique"
      - "Qualité/maintainabilité"
      - "Missing validation"
    LOW:
      - "Style/polish"
      - "Documentation"
      - "Naming conventions"
```

**Secret Masking Policy (OBLIGATOIRE) :**

```yaml
secret_masking:
  rule: "JAMAIS reposter tokens/secrets/URLs signées"

  patterns_to_mask:
    - "AKIA[0-9A-Z]{16}"           # AWS Access Key
    - "ghp_[a-zA-Z0-9]{36}"        # GitHub PAT
    - "sk-[a-zA-Z0-9]{48}"         # OpenAI key
    - "eyJ[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+\\.[a-zA-Z0-9_-]+"  # JWT
    - "-----BEGIN.*PRIVATE KEY-----"
    - "Bearer [a-zA-Z0-9._-]+"

  action: "Remplacer par [REDACTED] dans evidence/recommendation"
```

---

## Phase 5 : Challenge & Synthesize

**Évaluer pertinence avec NOTRE contexte :**

```yaml
challenge_feedback:
  timing: "APRÈS phases 3-4 (on a le contexte complet)"

  for_each_suggestion:
    evaluate:
      - "Dans le scope de la PR?"
      - "Applicable à notre stack/langage?"
      - "Pattern déjà implémenté ailleurs?"
      - "Trade-off conscient?"
      - "Suggestion générique vs cas spécifique?"

  classify:
    KEEP:
      action: "Intégrer dans findings"
      confidence: "HIGH"
    PARTIAL:
      action: "Signaler avec nuance"
      confidence: "MEDIUM"
    REJECT:
      action: "Ignorer avec raison"
      confidence: "LOW"
    DEFER:
      action: "Créer issue séparée"
      reason: "Hors scope PR"

  output_format:
    table:
      - suggestion: string
      - source: string (bot name)
      - verdict: "KEEP|PARTIAL|REJECT|DEFER"
      - rationale: string (1-2 lines)
      - action: "apply|issue|ignore"

  ask_user_if:
    - "Ambiguïté sur pertinence"
    - "Trade-off non documenté"
    - "Suggestion impacte architecture"
```

**Table de challenge :**

| Situation | Verdict | Action |
|-----------|---------|--------|
| Suggestion valide, applicable | KEEP | Apply now |
| Suggestion valide, hors scope | DEFER | Create issue |
| Suggestion générique, pas applicable | REJECT | Ignore + rationale |
| Trade-off conscient | REJECT | Document trade-off |
| Ambiguïté | ASK | User decision |

---

## Phase 6 : Generate Plan

**Synthèse finale avec actions priorisées :**

```yaml
plan_generation:
  inputs:
    - our_findings: "Phase 4 agent results"
    - validated_suggestions: "Phase 5 KEEP items"
    - questions: "Phase 2.5 pending questions"
    - behaviors: "Phase 2.6 extracted patterns"
    - deferred: "Phase 5 DEFER items"

  prioritize:
    order:
      1: "CRITICAL (security, exploitable)"
      2: "HIGH (validated suggestions, bugs)"
      3: "MEDIUM (quality, maintainability)"
      4: "LOW (style, polish)"
      5: "WORKFLOW (behavior extraction)"
      6: "QUESTIONS (pending user validation)"
      7: "DEFERRED (issues to create)"

  format: |
    ## /plan - Review Implementation

    ### Critical (must fix before merge)
    | # | Issue | File:Line | Action |
    |---|-------|-----------|--------|
    | 1 | {title} | {file}:{line} | {fix} |

    ### High Priority
    | # | Source | Suggestion | Action |
    |---|--------|------------|--------|
    | 1 | {bot} | {suggestion} | {implementation} |

    ### Medium
    ...

    ### Questions (pending validation)
    | # | Author | Question | Proposed Answer |
    |---|--------|----------|-----------------|
    | 1 | {author} | {question} | {answer} |

    ### Deferred (issues to create)
    | # | Title | Rationale |
    |---|-------|-----------|
    | 1 | {title} | {why_deferred} |

  user_validation:
    prompt: |
      Plan généré:
      - CRITICAL: {n}
      - HIGH: {n}
      - MEDIUM: {n}
      - Questions: {n}

      Exécuter? [Oui / Modifier / Refuser]
```

---

## Output Format

```markdown
# Code Review: PR #{number}

## Summary
{1-2 sentences assessment}
Mode: {NORMAL|TRIAGE}
CI: {status}

## Critical Issues
> Must fix before merge

### [CRITICAL] `file:line` - Title
**Problem:** {description}
**Evidence:** {code snippet, REDACTED if secret}
**Fix:** {actionable recommendation}
**Confidence:** HIGH

## High Priority
> From our analysis + validated bot suggestions

## Medium
> Quality improvements (max 5)

## Low
> Style/polish (max 3)

## Shell Safety (si *.sh présents)

### Download Safety
| Check | Status | File:Line |
|-------|--------|-----------|

### Path Determinism
| Config | Issue | Fix |
|--------|-------|-----|

## Pattern Analysis (CONDITIONAL)
> Triggered only if: complexity ↑, duplication, or core/ touched

### Patterns Identified
| Pattern | Location | Status |

### Suggestions
| Problem | Pattern | Reference |

## Challenged Feedback
| Suggestion | Source | Verdict | Rationale |
|------------|--------|---------|-----------|

## Questions (pending)
| Author | Question | Proposed Answer |

## Commendations
> What's done well

## Metrics
| Metric | Value |
|--------|-------|
| Mode | NORMAL |
| Files reviewed | 18 |
| Lines | +375/-12 |
| Critical | 0 |
| High | 3 |
| Medium | 2 |
| Suggestions kept | 3/8 |
```

---

## Pattern Consultation (CONDITIONNELLE)

**Déclencher UNIQUEMENT si :**

```yaml
pattern_triggers:
  conditions:
    - "complexity_increase > 20%"
    - "duplication_detected"
    - "directories: core/, domain/, pkg/, internal/"
    - "new_classes > 3"
    - "file size > 500 lines"

  skip_if:
    - "only docs/config changes"
    - "test files only"
    - "mode == TRIAGE"

  language_aware:
    go: "No 'class' keyword, check interfaces/structs"
    ts_js: "Factory, Singleton, Observer patterns"
    python: "Metaclass, decorator patterns"
    shell: "N/A - skip pattern analysis"
```

---

## Shell Safety Checks (si *.sh présents)

```yaml
shell_safety_axes:
  1_download_safety:
    checks:
      - "mktemp pour fichiers temporaires?"
      - "curl --retry --proto '=https'?"
      - "install -m au lieu de chmod?"
      - "rm -f cleanup?"

  2_download_robustness:
    checks:
      - "Track échecs de download?"
      - "Exit si critique?"
      - "Évite silent failures?"

  3_path_determinism:
    checks:
      - "Chemins absolus dans configs?"
      - "Pas de dépendance PATH implicite?"

  4_fallback_completeness:
    checks:
      - "Fallback copie binaire au bon endroit?"

  5_input_resilience:
    checks:
      - "Gère entrée vide?"
      - "set -e avec handling graceful?"

  6_url_validation:
    checks:
      - "URL release existe?"
      - "Script officiel si dispo?"
```

---

## Guard-rails

| Action | Status |
|--------|--------|
| Auto-approve/merge | FORBIDDEN |
| Skip security issues | FORBIDDEN |
| Modify code directly | FORBIDDEN |
| Post comment without user validation | FORBIDDEN |
| Mention AI in PR responses | **ABSOLUTE FORBIDDEN** |
| Skip Phase 0-1 (context/intent) | FORBIDDEN |
| Challenge without context (skip Phase 3-4) | FORBIDDEN |
| Expose secrets in evidence/output | FORBIDDEN |
| Ignore budget limits | FORBIDDEN |
| Pattern analysis on docs-only PR | SKIP (not forbidden) |

---

## No-Regression Checklist

```yaml
no_regression:
  check_in_pr:
    - "Tests ajoutés/ajustés pour changes?"
    - "Migration/rollback nécessaire?"
    - "Backward compatibility maintenue?"
    - "Config changes documentées?"
    - "Observability (logs/metrics) ajoutée?"
```

---

## Error Handling

```yaml
error_handling:
  mcp_rate_limit:
    action: "Backoff exponentiel (1s, 2s, 4s)"
    fallback: "git diff local"
    max_retries: 3

  agent_timeout:
    max_wait: 60s
    action: "Continue sans cet agent, signaler"

  large_diff:
    threshold: 5000 lines
    action: "Forcer TRIAGE mode, warning user"
```

---

## Agents Architecture

```
/review
    │
    ├─→ Phase 0-2: Context + Feedback (sequential)
    │
    ├─→ Phase 3-4: Parallel Analysis
    │       │
    │       ├─→ security-scanner (Task, context: fork)
    │       │     Schema: agent_contract
    │       │     Focus: OWASP, secrets, injection
    │       │
    │       ├─→ quality-checker (Task, context: fork)
    │       │     Schema: agent_contract
    │       │     Focus: complexity, duplication, style
    │       │
    │       └─→ shell-safety-checker (Task, context: fork)
    │             Condition: shell files > 0
    │             Focus: 6 behavioral axes
    │
    ├─→ Phase 5: Challenge (with full context)
    │
    └─→ Phase 6: Plan Generation
```

---

## Review Iteration Loop

```yaml
iteration_loop:
  description: |
    Amélioration continue basée sur retours bots.

  process:
    1: "Collecter suggestions bots (Phase 2.6)"
    2: "Extraire COMPORTEMENT (pas le fix)"
    3: "Catégoriser (shell/security/quality)"
    4: "Ajouter au workflow (user approuve)"
    5: "Commit l'amélioration"

  example:
    input: "Use mktemp to prevent partial writes"
    output:
      behavior: "Downloads should use temp files"
      category: "shell_safety"
      axis: "1_download_safety"
```
