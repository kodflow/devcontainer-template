---
name: review
description: |
  AI-powered code review using RLM (Recursive Language Model) decomposition.
  Analyzes code changes for security, quality, and best practices.
  Use when: running /review, analyzing PR changes, pre-commit checks,
  or when user asks for code review feedback.
allowed-tools:
  - "Bash(git diff:*)"
  - "Bash(git status:*)"
  - "Bash(git log:*)"
  - "Bash(git remote:*)"
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "mcp__grepai__*"
  - "mcp__github__*"
  - "mcp__codacy__*"
  - "mcp__playwright__*"
---

# Review - AI Code Review (RLM Architecture)

## Overview

Intelligent code review using **Recursive Language Model** decomposition:

- **Phase 0**: PR Context Detection (branch, CI, comments)
- **Phase 1**: Feedback Collection (ALL comments/reviews/suggestions)
- **Phase 2**: Peek before full analysis
- **Phase 3**: Decompose into parallel sub-tasks
- **Phase 4**: Synthesize + Challenge feedback
- **Phase 5**: Generate /plan

## Usage

```
/review                    # Review current changes (git diff)
/review --pr [number]      # Review specific PR
/review --staged           # Review staged changes only
/review --file <path>      # Review specific file
/review --security         # Security-focused review only
/review --quality          # Quality-focused review only
```

## Phase 0 : PR Context Detection (OBLIGATOIRE)

**Avant toute review, détecter le contexte PR :**

```yaml
pr_context_detection:
  1_detect_pr:
    action: "Identifier si on est sur une PR"
    tools:
      - "git branch --show-current"
      - "mcp__github__list_pull_requests (head: current_branch)"
    output:
      on_pr: true/false
      pr_number: <number> | null
      pr_url: <url> | null

  2_check_ci:
    condition: "on_pr == true"
    action: "Vérifier statut CI/CD"
    tools:
      - "mcp__github__get_pull_request_status"
      - "gh pr checks" (fallback)
    output:
      ci_status: "pending|passing|failing"
      ci_jobs: [{name, status, url}]

  3_wait_ci:
    condition: "ci_status == 'pending'"
    action: "Attendre fin du pipeline"
    strategy:
      poll_interval: 30s
      max_wait: 15min
      on_timeout: "Continue with warning"
    output: |
      ═══════════════════════════════════════════
        CI Pipeline: {status}
        Jobs: ✓ build, ✓ test, ⏳ lint
        Waiting... (2m 34s / 15m max)
      ═══════════════════════════════════════════
```

**Output Phase 0 :**

```
═══════════════════════════════════════════════════════════════
  /review - PR Context Detection
═══════════════════════════════════════════════════════════════

  Branch: feat/post-compact-hook
  PR: #97 (open)
  URL: https://github.com/owner/repo/pull/97

  CI Pipeline:
    ✓ build (passed, 1m 23s)
    ✓ test (passed, 2m 45s)
    ✓ lint (passed, 45s)
    Status: ALL PASSING

  Proceeding to Phase 1...

═══════════════════════════════════════════════════════════════
```

---

## Phase 1 : Feedback Collection (TOUT LIRE)

**Collecter TOUS les commentaires, reviews, suggestions sur la PR :**

```yaml
feedback_collection:
  1_fetch_all:
    action: "Récupérer TOUS les feedbacks sans exception"
    tools:
      - "mcp__github__get_pull_request_reviews"
      - "mcp__github__get_pull_request_comments"
      - "mcp__codacy__codacy_list_pull_request_issues"
    output:
      reviews: [{author, state, body}]
      comments: [{author, body, path, line}]
      suggestions: [{author, body, suggested_code}]

  2_classify_feedback:
    action: "Classifier chaque feedback"
    categories:
      human_review:
        criteria: "author != bot"
        action: "Contexte prioritaire"
      ai_review:
        criteria: "author contains 'bot' or 'coderabbit' or 'qodo'"
        action: "Extraire axes comportementaux"
      question:
        criteria: "body contains '?' or 'should we' or 'what about'"
        action: "Préparer réponse (user valide)"
      suggestion:
        criteria: "suggested_code != null"
        action: "Évaluer pertinence"

  3_extract_behaviors:
    action: "Pour chaque AI review pertinente, extraire l'axe"
    template: |
      Suggestion: "{original_text}"
      Behavior: "{extracted_pattern}"
      Category: "{shell_safety|pattern|security|quality}"
      Add to: "{workflow_section}"
```

**Classification des feedbacks :**

| Type | Auteur | Action |
|------|--------|--------|
| Human Review | utilisateur réel | Contexte prioritaire |
| AI Review (bot) | coderabbit, qodo, etc. | Extraire comportements |
| Question | any | Préparer réponse → user valide |
| Suggestion | any | Évaluer pertinence avec contexte |

---

## Phase 1.5 : Questions & Réponses (si questions détectées)

```yaml
question_handling:
  rule: "JAMAIS mentionner l'IA dans les réponses"

  workflow:
    1_collect_questions:
      - "Extraire toutes les questions des reviews"
      - "Grouper par thème"

    2_prepare_answers:
      format: |
        ## Question: {question}
        **Auteur:** {author}
        **Contexte:** {file}:{line}

        **Réponse proposée:**
        {answer_without_ai_mention}

        **Poster cette réponse?** [Oui/Non/Modifier]

    3_user_validation:
      action: "AskUserQuestion pour chaque réponse"
      options:
        - "Poster telle quelle"
        - "Modifier avant de poster"
        - "Ignorer"

    4_post_response:
      tool: "mcp__github__add_issue_comment"
      rule: |
        INTERDICTION ABSOLUE de mentionner:
        - "Claude", "AI", "IA", "assistant"
        - "j'ai été généré", "automatiquement"
        - Toute référence à l'intelligence artificielle
```

**Template de réponse (sans mention IA) :**

```markdown
<!-- BON -->
Concernant votre question sur {topic}:

{answer}

Cette approche a été choisie car {rationale}.

<!-- INTERDIT -->
❌ "L'IA suggère que..."
❌ "Claude recommande..."
❌ "Cette réponse a été générée..."
```

---

## Phase 1.6 : Extraction des Axes Comportementaux (AI Reviews)

```yaml
behavior_extraction:
  description: |
    Pour chaque suggestion pertinente des bots (coderabbit, qodo),
    extraire le COMPORTEMENT sous-jacent pour enrichir le workflow.

  process:
    1_filter_relevant:
      criteria:
        - "importance >= 6/10"
        - "Not already in workflow"
        - "Actionable pattern"

    2_extract_pattern:
      from: "Use temporary file to prevent partial writes"
      to:
        behavior: "Downloads should use mktemp + cleanup"
        category: "shell_safety"
        axis: "1_download_safety"

    3_add_to_workflow:
      action: "Enrichir review.md avec le nouvel axe"
      auto: false  # Demander confirmation user

  example:
    bot_says: |
      "Make the post-compact.sh hook more resilient by handling
      potential failures from cat and jq"
    extracted:
      behavior: "Hook scripts should handle empty input gracefully"
      axis: "5_input_resilience"
      check: "Gère entrée vide/malformée?"
```

---

## Phase 2 : Challenge des Feedbacks

```yaml
feedback_challenge:
  description: |
    Avec NOTRE contexte (codebase, historique, intent),
    challenger la pertinence des suggestions.

  process:
    1_assess_relevance:
      for_each_suggestion:
        - "Est-ce dans le scope de la PR?"
        - "Est-ce applicable à notre stack?"
        - "Avons-nous plus de contexte?"

    2_classify:
      relevant:
        action: "Intégrer dans review"
        confidence: "HIGH"
      partially_relevant:
        action: "Signaler avec nuance"
        confidence: "MEDIUM"
      off_topic:
        action: "Ignorer ou contester"
        reason: "Explain why not applicable"

    3_ask_user_if_needed:
      condition: "Ambiguïté sur pertinence"
      tool: "AskUserQuestion"
      question: |
        Le bot suggère: {suggestion}
        Notre contexte indique: {our_context}

        Cette suggestion est-elle pertinente?

  challenge_criteria:
    - "Suggestion générique vs notre cas spécifique"
    - "Pattern déjà implémenté ailleurs"
    - "Trade-off conscient (perf vs safety)"
    - "Limitation technique connue"
```

**Table de challenge :**

| Situation | Action |
|-----------|--------|
| Bot suggère X, déjà fait ailleurs | "Pattern existant dans {file}" |
| Bot suggère X, hors scope PR | "Hors scope, créer issue séparée" |
| Bot suggère X, trade-off voulu | "Trade-off conscient: {raison}" |
| Bot a raison, on a tort | "Suggestion valide, à intégrer" |

---

## RLM Workflow (Phases 3-4)

```yaml
review_workflow:
  3_peek:
    action: "Quick scan of changes"
    tools: [Glob, "git diff --stat"]
    output: "file_list, change_summary"

  3b_decompose:
    action: "Categorize files by type"
    categories:
      - security: "*.go, *.py, *.js, *.ts (auth, crypto, input)"
      - quality: "All code files (complexity, style)"
      - shell_safety: "*.sh, install.sh, Dockerfile (download, paths)"
      - tests: "*_test.*, *.test.*, *.spec.*"
      - config: "*.yaml, *.json, *.toml, mcp.json, Dockerfile"

  3c_parallel_dispatch:
    action: "Launch sub-agents via Task tool"
    agents:
      - security-scanner (context: fork)
      - quality-checker (context: fork)
      - shell-safety-checker (context: fork, if *.sh present)
    mode: "parallel"

  4_synthesize:
    action: "Combine results + feedback challenge"
    inputs:
      - agent_results: "Security, quality, shell safety findings"
      - pr_feedback: "Classified comments/reviews from Phase 1"
      - behaviors: "Extracted patterns from AI reviews"
    format: "Prioritized markdown report"
```

---

## Phase 5 : Generate /plan

```yaml
plan_generation:
  description: |
    Après synthèse complète, générer un plan d'action
    qui intègre tous les inputs collectés.

  inputs:
    - our_review: "Notre analyse code"
    - bot_feedback: "Suggestions pertinentes des bots"
    - user_questions: "Questions à répondre"
    - behaviors: "Nouveaux axes pour le workflow"

  workflow:
    1_prioritize:
      action: "Classer les actions par priorité"
      order:
        - "CRITICAL: Security issues"
        - "HIGH: Bot suggestions validées"
        - "MEDIUM: Quality improvements"
        - "LOW: Workflow enhancements"

    2_generate_plan:
      format: |
        ## /plan - Review Implementation

        ### Critical (must fix)
        1. {issue} - {file}:{line}
           Action: {fix}

        ### High Priority (validated bot suggestions)
        1. {suggestion} - Source: {bot}
           Action: {implementation}

        ### Medium (quality)
        1. {improvement}

        ### Workflow Enhancement
        1. Add axis "{new_axis}" to review.md

        ### Questions to Answer
        1. "{question}" by {author}
           Proposed answer: {answer}
           [Validate before posting]

    3_user_validation:
      action: "Présenter le plan pour approbation"
      tool: "AskUserQuestion"
      question: |
        Plan généré avec {n} actions:
        - {critical_count} critiques
        - {high_count} haute priorité
        - {medium_count} moyennes

        Exécuter ce plan?

    4_execute_or_refine:
      on_approve: "Exécuter via /apply"
      on_reject: "Affiner avec feedback user"
```

**Output Phase 5 :**

```
═══════════════════════════════════════════════════════════════
  /review - Plan Generated
═══════════════════════════════════════════════════════════════

  Review Summary:
    ├─ Our findings: 3 issues (0 critical, 2 major, 1 minor)
    ├─ Bot feedback: 5 suggestions (3 relevant, 2 off-topic)
    ├─ Questions: 1 to answer
    └─ New behaviors: 1 to add to workflow

  Generated Plan: 7 actions
    ├─ CRITICAL: 0
    ├─ HIGH: 3 (validated bot suggestions)
    ├─ MEDIUM: 2
    ├─ LOW: 1 (workflow enhancement)
    └─ QUESTIONS: 1 (pending user validation)

  → Use /apply to execute or refine

═══════════════════════════════════════════════════════════════
```

## Output Format

```markdown
# Code Review: <scope>

## Summary
<1-2 sentences overall assessment>

## Critical Issues
> Must fix before merge

### [CRITICAL] `file:line` - Title
**Problem:** Description
**Fix:** Suggestion
**Reference:** URL

## Major Issues
> Strongly recommended

## Minor Issues
> Nice to have (max 5 shown)

## Shell Safety Analysis (si *.sh présents)
> Scripts shell et téléchargements

### Download Safety
| Check | File:Line | Status |
|-------|-----------|--------|
| Temp file usage | `install.sh:102` | ⚠ Missing mktemp |
| Retry logic | `install.sh:102` | ⚠ No --retry |
| TLS enforcement | `install.sh:102` | ⚠ No --proto |
| Cleanup | `install.sh:112` | ✗ Missing rm -f |

### Path Determinism
| Config | Path Type | Recommendation |
|--------|-----------|----------------|
| mcp.json:grepai | Relative | Use /home/vscode/.local/bin/grepai |

### Fallback Completeness
| Binary | Fallback | Discoverable |
|--------|----------|--------------|
| grepai | go install | ⚠ Not copied to ~/.local/bin |

### Input Resilience
| Script | Handles Empty | Graceful Errors |
|--------|---------------|-----------------|
| post-compact.sh | ⚠ No | ⚠ set -e strict |

## Pattern Analysis
> Design patterns assessment

### Patterns Identified
| Pattern | Location | Status |
|---------|----------|--------|
| Singleton | `src/db.ts` | ✓ Correct |
| Factory | `src/handlers/` | ⚠ Missing reset |

### Pattern Suggestions
| Problem | Suggested Pattern | Reference |
|---------|-------------------|-----------|
| Repeated DB connections | Object Pool | .claude/docs/performance/README.md |
| Complex object creation | Builder | .claude/docs/creational/README.md |

## Commendations
> What's done well

## Metrics
| Metric | Value |
|--------|-------|
| Files | N |
| Critical | N |
| Major | N |
```

## MCP Integration

**Priority MCP tools:**

| Action | MCP Tool |
|--------|----------|
| PR files | `mcp__github__get_pull_request_files` |
| PR diff | `mcp__codacy__codacy_get_pull_request_git_diff` |
| Issues | `mcp__codacy__codacy_list_pull_request_issues` |
| Security | `mcp__codacy__codacy_search_repository_srm_items` |

**Fallback CLI:**

- `git diff`, `gh pr view --json files`

## Agents Architecture

This skill uses specialized agents via the Task tool:

```
/review
    │
    ├─→ code-reviewer (orchestrator)
    │       │
    │       ├─→ security-scanner (parallel, context: fork)
    │       │     Tools: Codacy SRM, bandit, semgrep, trivy, gitleaks
    │       │     Focus: OWASP Top 10, secrets, injection, crypto
    │       │
    │       ├─→ quality-checker (parallel, context: fork)
    │       │     Tools: Codacy issues, eslint, pylint, shellcheck
    │       │     Focus: Complexity, duplication, style, dead code
    │       │
    │       └─→ shell-safety-checker (parallel, context: fork, if *.sh)
    │             Tools: shellcheck, grep patterns
    │             Focus: Download safety, path determinism, input resilience
    │             Axes: 6 behavioral checks (see shell_safety_axes)
    │
    └─→ Synthesized Report
```

**Agent dispatch example:**

```yaml
Task:
  subagent_type: Explore
  prompt: |
    Load the security-scanner agent from ~/.claude/agents/security-scanner.md
    Analyze: {file_list}
    Diff: {diff_content}
    Return JSON only.
```

## Shell Safety Checks (OBLIGATOIRE pour *.sh)

Lors de review de scripts shell, appliquer ces axes comportementaux :

```yaml
shell_safety_axes:
  1_download_safety:
    description: "Sécurité téléchargements binaires"
    checks:
      - "Utilise fichier temporaire (mktemp)?"
      - "curl avec --retry et --proto '=https'?"
      - "Utilise 'install -m' au lieu de chmod?"
      - "Supprime le fichier temp après usage?"
    bad_pattern: |
      curl -sL "$URL" -o "$DEST" && chmod +x "$DEST"
    good_pattern: |
      tmp="$(mktemp)"
      if curl -fsL --retry 3 --proto '=https' "$URL" -o "$tmp"; then
          install -m 0755 "$tmp" "$DEST"
      fi
      rm -f "$tmp"

  2_download_robustness:
    description: "Robustesse téléchargements scripts"
    checks:
      - "Track les échecs de download?"
      - "Exit si échec critique?"
      - "Évite silent failures (2>/dev/null seul)?"
    bad_pattern: |
      curl -sL "$URL" -o "$FILE" 2>/dev/null
    good_pattern: |
      if curl -fsL "$URL" -o "$FILE" 2>/dev/null; then
          chmod +x "$FILE"
      else
          echo "⚠ Failed: $FILE" >&2
          download_failed=1
      fi

  3_path_determinism:
    description: "Chemins déterministes"
    checks:
      - "Configs MCP utilisent chemins absolus?"
      - "Ne dépend pas de PATH pour binaires critiques?"
    bad_pattern: |
      "command": "grepai"
    good_pattern: |
      "command": "/home/vscode/.local/bin/grepai"

  4_fallback_completeness:
    description: "Fallbacks complets"
    checks:
      - "Fallback place binaire au bon endroit?"
      - "Copie depuis GOBIN vers destination attendue?"
    bad_pattern: |
      go install github.com/foo/bar@latest
    good_pattern: |
      if go install github.com/foo/bar@latest; then
          GOBIN_PATH="$(go env GOBIN 2>/dev/null || echo "$(go env GOPATH)/bin")"
          [ -x "${GOBIN_PATH}/bar" ] && cp -f "${GOBIN_PATH}/bar" "$HOME/.local/bin/"
      fi

  5_input_resilience:
    description: "Résilience entrées"
    checks:
      - "Gère entrée vide/malformée?"
      - "Vérifie disponibilité jq?"
      - "set -e avec handling graceful?"
    bad_pattern: |
      INPUT=$(cat)
      SOURCE=$(echo "$INPUT" | jq -r '.source')
    good_pattern: |
      INPUT="$(cat || true)"
      SOURCE=""
      if command -v jq >/dev/null 2>&1; then
          SOURCE="$(printf '%s' "$INPUT" | jq -r '.source // ""' 2>/dev/null || true)"
      fi

  6_url_validation:
    description: "Validation URLs"
    checks:
      - "URL de release existe réellement?"
      - "Fallback si binaire pré-compilé absent?"
      - "Script d'installation officiel utilisé si dispo?"
    warning: |
      Vérifier que github.com/<repo>/releases publie réellement des binaires.
      Sinon utiliser: go install ou script officiel.
```

**Intégration dans le workflow :**

```yaml
parallel_dispatch_enhanced:
  agents:
    - security-scanner
    - quality-checker
    - shell-safety-checker  # Nouveau pour *.sh
```

---

## Pattern Consultation (OBLIGATOIRE)

Lors de chaque review, consulter `.claude/docs/` pour :

```yaml
pattern_analysis:
  1_identify:
    action: "Grep pour patterns connus dans le code"
    patterns:
      - "class.*Factory" → Factory pattern
      - "getInstance" → Singleton pattern
      - "subscribe.*notify" → Observer pattern
      - "execute.*undo" → Command pattern

  2_validate:
    action: "Comparer avec docs/"
    check:
      - "Pattern correctement implémenté?"
      - "Manque-t-il des éléments?"
      - "Anti-patterns présents?"

  3_suggest:
    action: "Identifier améliorations possibles"
    consult:
      - ".claude/docs/README.md" (tableau de décision)
      - Category README pour détails
```

**Quand suggérer un pattern :**

| Code Smell | Pattern Suggéré | Référence |
|------------|-----------------|-----------|
| new() répétés | Factory/Builder | creational/README.md |
| If/else sur types | Strategy/State | behavioral/README.md |
| Callbacks imbriqués | Promise/Async | concurrency/README.md |
| Données dupliquées | Flyweight/Cache | performance/README.md |
| Couplage fort | Mediator/Observer | behavioral/README.md |

---

## Guard-rails

| Action | Status |
|--------|--------|
| Auto-approve/merge | FORBIDDEN |
| Skip security issues | FORBIDDEN |
| Modify code directly | FORBIDDEN |
| Post without user review | FORBIDDEN |
| Skip pattern analysis | FORBIDDEN |
| Skip shell safety for *.sh | FORBIDDEN |
| Ignore download patterns | FORBIDDEN |
| Accept relative paths in MCP config | FORBIDDEN |
| Skip Phase 0 (PR context) | FORBIDDEN |
| Skip Phase 1 (feedback collection) | FORBIDDEN |
| Post comment without user validation | FORBIDDEN |
| Mention AI in PR responses | **ABSOLUTE FORBIDDEN** |
| Ignore bot suggestions without analysis | FORBIDDEN |
| Challenge feedback without context | FORBIDDEN |

## Review Iteration Loop

```yaml
review_iteration:
  description: |
    Amélioration continue du workflow /review basée sur les
    retours des bots (qodo, coderabbit, etc.)

  process:
    1_collect: "Collecter suggestions des bots après PR"
    2_extract: "Extraire les COMPORTEMENTS (pas les fixes)"
    3_categorize: "Ajouter à la catégorie appropriée"
    4_document: "Enrichir shell_safety_axes ou pattern_consultation"
    5_commit: "Commit l'amélioration du workflow"

  categories:
    - shell_safety_axes: "Comportements scripts shell"
    - pattern_consultation: "Design patterns code"
    - security_checks: "Vulnérabilités OWASP"
    - quality_checks: "Complexité, style, tests"

  example:
    bot_suggestion: |
      "Use temporary file to prevent partial writes"
    extracted_behavior: |
      "Downloads should use mktemp + cleanup"
    added_to: "shell_safety_axes.1_download_safety"
```
