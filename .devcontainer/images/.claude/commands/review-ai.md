# Review-AI - Automated PR Review Resolution

$ARGUMENTS

---

## Description

Agent automatisé qui résout les commentaires de review sur une PR existante.

**Workflow :**
1. Vérifie qu'une PR existe pour la branche courante
2. Récupère les commentaires de **Qodo** (PR-Agent) et **CodeRabbit**
3. Itère pour corriger chaque commentaire
4. Fait la même chose avec **Codacy**
5. Push les corrections et re-vérifie

**Pré-requis :**
- Une PR doit exister (sinon → `/git --commit`)
- Les reviewers (Qodo, CodeRabbit, Codacy) doivent être configurés sur le repo

---

## Arguments

| Pattern | Action |
|---------|--------|
| (vide) | Résout tous les commentaires (Qodo + CodeRabbit + Codacy) |
| `--qodo` | Résout uniquement les commentaires Qodo |
| `--coderabbit` | Résout uniquement les commentaires CodeRabbit |
| `--codacy` | Résout uniquement les issues Codacy |
| `--dry-run` | Liste les commentaires sans les corriger |
| `--help` | Affiche l'aide |

---

## --help

Quand `--help` est passé, afficher :

```
═══════════════════════════════════════════════
  /review-ai - Automated PR Review Resolution
═══════════════════════════════════════════════

Usage: /review-ai [options]

Options:
  (vide)          Résout tous les commentaires
  --qodo          Qodo (PR-Agent) uniquement
  --coderabbit    CodeRabbit uniquement
  --codacy        Codacy uniquement
  --dry-run       Liste sans corriger
  --help          Affiche cette aide

Bots reconnus:
  - qodo-merge-pro[bot]    Qodo PR-Agent
  - coderabbitai[bot]      CodeRabbit
  - codacy-production[bot] Codacy

Exemples:
  /review-ai                Corrige tout
  /review-ai --qodo         Qodo uniquement
  /review-ai --dry-run      Voir les commentaires

Workflow recommandé:
  1. /git --commit           ← Créer la PR
  2. Attendre les reviews
  3. /review-ai              ← Corriger auto
  4. /git --merge            ← Merger
═══════════════════════════════════════════════
```

---

## Priorité des outils

**IMPORTANT** : Toujours privilégier MCP GitHub.

| Action | Priorité 1 (MCP) | Fallback (CLI) |
|--------|------------------|----------------|
| Lister PRs | `mcp__github__list_pull_requests` | `gh pr list` |
| Commentaires PR | `mcp__github__list_pull_request_reviews` | `gh api` |
| Review comments | `mcp__github__get_pull_request_comments` | `gh api` |
| Fichiers PR | `mcp__github__get_pull_request_files` | `gh pr diff` |

**Extraction owner/repo** :
```bash
git remote get-url origin | sed -E 's#.*[:/]([^/]+)/([^/.]+)(\.git)?$#\1 \2#'
```

---

## Workflow Principal

### Phase 1: Détection PR

```yaml
detect_pr:
  1_get_branch:
    command: "git branch --show-current"

  2_get_remote:
    command: "git remote get-url origin"
    extract: "owner, repo"

  3_find_pr:
    priority: MCP
    method: |
      mcp__github__list_pull_requests({
        owner: "<owner>",
        repo: "<repo>",
        state: "open",
        head: "<owner>:<branch>"
      })
    fallback: |
      gh pr view --json number,url,title 2>/dev/null

  4_no_pr_action:
    if_no_pr: |
      ═══════════════════════════════════════════════
        /review-ai - Aucune PR trouvée
      ═══════════════════════════════════════════════

        Branche: <branch>

        Aucune PR n'existe pour cette branche.

        → Créez d'abord une PR avec: /git --commit

      ═══════════════════════════════════════════════
    then: EXIT
```

### Phase 2: Collecte des Commentaires

```yaml
collect_comments:
  bots:
    qodo:
      username: "qodo-merge-pro[bot]"
      alt_usernames: ["qodo-merge[bot]", "pr-agent[bot]"]
      priority: "P0 > P1 > P2"

    coderabbit:
      username: "coderabbitai[bot]"
      types:
        - review_comments  # Commentaires inline
        - issue_comments   # Commentaires généraux

    codacy:
      username: "codacy-production[bot]"
      alt_usernames: ["codacy[bot]"]

  api_calls:
    # Commentaires de review (inline sur le code)
    review_comments: |
      mcp__github__get_pull_request_comments({
        owner: "<owner>",
        repo: "<repo>",
        pull_number: <number>
      })
      # Fallback:
      gh api repos/<owner>/<repo>/pulls/<number>/comments

    # Commentaires généraux (issue comments)
    issue_comments: |
      gh api repos/<owner>/<repo>/issues/<number>/comments

    # Reviews avec leurs commentaires
    reviews: |
      gh api repos/<owner>/<repo>/pulls/<number>/reviews
```

### Phase 3: Parsing des Commentaires

```yaml
parse_comments:
  qodo_format:
    # Qodo structure ses commentaires avec des sections
    patterns:
      - "**Category:**"
      - "**Severity:**"
      - "**Description:**"
      - "**Suggestion:**"
      - "```suggestion"  # Code block avec fix

    priority_mapping:
      "P0": "CRITICAL"
      "P1": "MAJOR"
      "P2": "MINOR"
      "blocker": "CRITICAL"
      "major": "MAJOR"
      "minor": "MINOR"

  coderabbit_format:
    # CodeRabbit utilise des emojis et headers
    patterns:
      - "<!-- coderabbitai"  # Metadata
      - "**Issue:**"
      - "**Suggestion:**"
      - "<details>"  # Collapsible sections

  codacy_format:
    # Codacy poste des issues avec règles
    patterns:
      - "Codacy found"
      - "**Rule:**"
      - "**Category:**"

  output_structure:
    - file: "path/to/file.ts"
      line: 42
      bot: "qodo"
      severity: "P0"
      issue: "Description du problème"
      suggestion: "Code suggéré ou null"
      comment_id: 123456
```

### Phase 4: Résolution Itérative

```yaml
resolve_loop:
  for_each_comment:
    sorted_by: ["severity DESC", "file ASC", "line ASC"]

    steps:
      1_read_context:
        action: "Read file around the line"
        context_lines: 20  # 10 before, 10 after

      2_understand_issue:
        analyze:
          - "Quel est le problème identifié?"
          - "La suggestion est-elle applicable?"
          - "Y a-t-il des effets de bord?"

      3_apply_fix:
        if_suggestion_exists:
          action: "Apply suggestion with Edit tool"
        else:
          action: "Reason about fix and apply"

      4_verify:
        checks:
          - "Le fichier est syntaxiquement correct"
          - "Les tests passent (si applicable)"
          - "Pas de régression introduite"

      5_mark_resolved:
        # OBLIGATOIRE: répondre au commentaire pour que le bot le marque résolu
        priority: MCP

        # Commentaire général sur la PR (MCP disponible)
        mcp_method: |
          mcp__github__add_issue_comment({
            owner: "<owner>",
            repo: "<repo>",
            issue_number: <pr_number>,
            body: "@<bot_name> Fixed in <commit_sha>: <description>"
          })

        # Réponse inline review comment (pas de MCP dédié, fallback API)
        fallback_inline: |
          gh api repos/<owner>/<repo>/pulls/<pr_number>/comments/<comment_id>/replies \
            -X POST -f body="Fixed in <commit_sha> - <description>"

  commit_strategy:
    # Grouper les fixes par fichier ou par batch
    batch_size: 5  # Commit toutes les 5 corrections
    message_format: "fix(review): address <bot> feedback"
```

### Phase 5: Push et Vérification

```yaml
finalize:
  1_commit_remaining:
    action: "Commit any uncommitted fixes"
    message: "fix(review): address review comments"

  2_push:
    action: "git push"

  3_wait_ci:
    timeout: 300  # 5 minutes max
    poll_interval: 30

  4_recheck_comments:
    action: "Re-fetch comments"
    goal: "Verify bots haven't added new issues"

  5_iterate:
    if_new_comments:
      action: "Return to Phase 2"
      max_iterations: 3
    else:
      action: "Complete"
```

---

## Output Format

### Mode Normal

```
═══════════════════════════════════════════════
  /review-ai - PR #42
═══════════════════════════════════════════════

  Branche : feat/add-auth
  PR      : #42 - Add user authentication
  URL     : https://github.com/owner/repo/pull/42

───────────────────────────────────────────────
  Collecte des commentaires...
───────────────────────────────────────────────

  Qodo (PR-Agent):
    P0 (Critical) : 2
    P1 (Major)    : 3
    P2 (Minor)    : 1

  CodeRabbit:
    Issues        : 4
    Suggestions   : 2

  Codacy:
    Issues        : 1

  Total à traiter : 13 commentaires

───────────────────────────────────────────────
  Résolution en cours...
───────────────────────────────────────────────

  [1/13] src/auth.ts:42 (Qodo P0)
         SQL injection vulnerability
         → Fixed: Using parameterized query

  [2/13] src/auth.ts:67 (Qodo P0)
         Hardcoded secret
         → Fixed: Using environment variable

  [3/13] src/api/users.ts:23 (CodeRabbit)
         Missing input validation
         → Fixed: Added zod schema validation

  ... (continuer)

───────────────────────────────────────────────
  Commit & Push
───────────────────────────────────────────────

  Commit : fix(review): address 13 review comments
  Push   : origin/feat/add-auth

───────────────────────────────────────────────
  Vérification CI...
───────────────────────────────────────────────

  Status : ✓ Passed (2m 34s)

───────────────────────────────────────────────
  Re-vérification des reviews...
───────────────────────────────────────────────

  Nouveaux commentaires : 0

═══════════════════════════════════════════════
  ✓ Tous les commentaires ont été résolus
═══════════════════════════════════════════════

  Résumé:
    Qodo       : 6/6 résolus
    CodeRabbit : 6/6 résolus
    Codacy     : 1/1 résolu

  Prochaine étape: /git --merge

═══════════════════════════════════════════════
```

### Mode --dry-run

```
═══════════════════════════════════════════════
  /review-ai --dry-run - PR #42
═══════════════════════════════════════════════

  Mode: DRY-RUN (aucune modification)

───────────────────────────────────────────────
  Commentaires Qodo (6)
───────────────────────────────────────────────

  P0 CRITICAL:

  1. src/auth.ts:42
     SQL injection vulnerability
     Suggestion: Use parameterized query

  2. src/auth.ts:67
     Hardcoded secret in source code
     Suggestion: Use environment variable

  P1 MAJOR:

  3. src/api/users.ts:89
     Missing error handling
     Suggestion: Add try-catch block

  ...

───────────────────────────────────────────────
  Commentaires CodeRabbit (6)
───────────────────────────────────────────────

  1. src/models/user.ts:15
     Consider adding input validation

  ...

───────────────────────────────────────────────
  Issues Codacy (1)
───────────────────────────────────────────────

  1. src/utils/crypto.ts:23
     Use of weak cryptographic algorithm (MD5)
     Rule: security/weak-crypto

═══════════════════════════════════════════════
  Total: 13 commentaires à traiter

  Pour appliquer les corrections:
    /review-ai
═══════════════════════════════════════════════
```

---

## Stratégies de Résolution par Bot

### Qodo (PR-Agent)

```yaml
qodo_strategy:
  priority_order: ["P0", "P1", "P2"]

  comment_types:
    code_suggestion:
      # Qodo fournit souvent des ```suggestion blocks
      detect: "```suggestion"
      action: "Apply directly with Edit tool"

    security_issue:
      detect: ["security", "vulnerability", "injection", "XSS"]
      action: "Apply fix, verify with security scan"

    performance:
      detect: ["performance", "O(n)", "memory", "leak"]
      action: "Apply optimization"

    style:
      detect: ["style", "naming", "convention"]
      action: "Apply if P1+, skip if P2 and many issues"
```

### CodeRabbit

```yaml
coderabbit_strategy:
  comment_types:
    inline_suggestion:
      detect: "<details>" or "**Suggestion:**"
      action: "Extract and apply code block"

    architectural:
      detect: ["pattern", "architecture", "design"]
      action: "Evaluate impact, apply if localized"

    nitpick:
      detect: "nitpick" or "nit:"
      action: "Apply only if < 5 total issues"
```

### Codacy

```yaml
codacy_strategy:
  # Codacy utilise des règles prédéfinies
  approach: "Rule-based fixes"

  common_rules:
    weak_crypto:
      detect: "weak-crypto" or "MD5" or "SHA1"
      fix: "Replace with SHA256/SHA3"

    sql_injection:
      detect: "sql-injection"
      fix: "Parameterized queries"

    code_style:
      detect: "code-style"
      fix: "Apply linter auto-fix"
```

---

## Gestion des Conflits

```yaml
conflict_handling:
  same_line_multiple_bots:
    strategy: "Merge suggestions or pick highest priority"
    preference: ["security fix", "Qodo P0", "CodeRabbit", "Codacy"]

  conflicting_suggestions:
    action: "Ask user via AskUserQuestion"

  unfixable_issue:
    action: "Log as skipped, continue with others"
    notify: "Post comment explaining why skipped"
```

---

## Limites et Garde-fous

| Action | Statut |
|--------|--------|
| Modifier sans PR existante | INTERDIT |
| Ignorer les P0/CRITICAL | INTERDIT |
| Push sur main/master | INTERDIT |
| Plus de 3 itérations | STOP + rapport |
| Fix qui casse les tests | ROLLBACK |

---

## Voir aussi

| Commande | Description |
|----------|-------------|
| `/review` | Review locale avec The Hive |
| `/git --commit` | Créer PR |
| `/git --merge` | Merger la PR |
