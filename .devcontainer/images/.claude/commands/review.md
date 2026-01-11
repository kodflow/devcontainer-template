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

- **Peek** before full analysis (Glob, partial Read)
- **Decompose** into parallel sub-tasks
- **Synthesize** condensed results

## Usage

```
/review                    # Review current changes (git diff)
/review --pr [number]      # Review specific PR
/review --staged           # Review staged changes only
/review --file <path>      # Review specific file
/review --security         # Security-focused review only
/review --quality          # Quality-focused review only
```

## RLM Workflow

```yaml
review_workflow:
  1_peek:
    action: "Quick scan of changes"
    tools: [Glob, "git diff --stat"]
    output: "file_list, change_summary"

  2_decompose:
    action: "Categorize files by type"
    categories:
      - security: "*.go, *.py, *.js, *.ts (auth, crypto, input)"
      - quality: "All code files (complexity, style)"
      - shell_safety: "*.sh, install.sh, Dockerfile (download, paths)"
      - tests: "*_test.*, *.test.*, *.spec.*"
      - config: "*.yaml, *.json, *.toml, mcp.json, Dockerfile"

  3_parallel_dispatch:
    action: "Launch sub-agents via Task tool"
    agents:
      - security-scanner (context: fork)
      - quality-checker (context: fork)
      - shell-safety-checker (context: fork, if *.sh present)
    mode: "parallel"

  4_synthesize:
    action: "Combine results"
    format: "Prioritized markdown report"
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
