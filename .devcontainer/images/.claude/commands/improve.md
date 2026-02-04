# Improve - Continuous Documentation & Pattern Enhancement (RLM Multi-Agent)

## Description

Skill d'amélioration continue utilisant l'approche **RLM multi-agents**.
Lance un agent spécialisé pour CHAQUE fichier `.md` du projet.

### Deux modes de fonctionnement

```
┌─────────────────────────────────────────────────────────────────────┐
│                         /improve                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Mode 1: devcontainer-template         Mode 2: Autre projet         │
│  ┌─────────────────────────────┐      ┌─────────────────────────┐  │
│  │ Améliorer .claude/docs/     │      │ Analyser anti-patterns  │  │
│  │ ├─ MAJ best practices       │      │ ├─ Détecter violations  │  │
│  │ ├─ Corriger incohérences    │      │ ├─ Comparer avec docs   │  │
│  │ ├─ Affiner exemples         │      │ ├─ Créer issues GitHub  │  │
│  │ └─ Coupler sources          │      │ └─ Documenter positif   │  │
│  └─────────────────────────────┘      └─────────────────────────┘  │
│                                                                      │
│  Output: Fichiers modifiés             Output: Issues + rapport     │
│          + rapport amélioration                 patterns détectés   │
└─────────────────────────────────────────────────────────────────────┘
```

**Patterns RLM appliqués :**

- **Partition+Map** - Un agent par fichier .md (parallèle)
- **Peek** - Aperçu rapide avant analyse complète
- **WebSearch** - Recherche mises à jour best practices
- **Cross-Reference** - Validation multi-sources
- **Synthesize** - Consolidation des améliorations
- **Issue-Driven** - Création issues pour feedback loop

---

## Arguments

| Pattern | Action |
|---------|--------|
| `(none)` | Analyse complète (détection auto du mode) |
| `--check` | Dry-run : affiche les améliorations sans modifier |
| `--fix` | Applique automatiquement les corrections |
| `--category <name>` | Limite à une catégorie (ex: `devops`, `security`) |
| `--file <path>` | Analyse un seul fichier |
| `--missing` | Identifie les patterns manquants |
| `--issues` | Mode création d'issues uniquement |
| `--report` | Génère un rapport détaillé |
| `--help` | Affiche l'aide |

---

## --help

```
═══════════════════════════════════════════════════════════════════════
  /improve - Continuous Documentation & Pattern Enhancement
═══════════════════════════════════════════════════════════════════════

Usage: /improve [options]

Modes:
  AUTO-DETECTED based on current repository:
    • devcontainer-template → Documentation improvement
    • Other projects        → Anti-pattern detection + Issues

Options:
  (none)              Analyse complète
  --check             Dry-run (preview changes)
  --fix               Apply corrections automatically
  --category <name>   Limit to category (devops, security, etc.)
  --file <path>       Analyze single file
  --missing           Find missing patterns
  --issues            Create GitHub issues only
  --report            Generate detailed report
  --help              Show this help

RLM Strategy:
  1. Partition    - Group files by category
  2. Map          - Launch N parallel agents (1 per file)
  3. WebSearch    - Check latest best practices
  4. Validate     - Cross-reference sources
  5. Synthesize   - Consolidate improvements
  6. Apply/Issue  - Modify files or create issues

Examples:
  /improve                        # Full analysis
  /improve --check                # Preview without changes
  /improve --category security    # Only security patterns
  /improve --missing              # Find documentation gaps
  /improve --issues               # Create improvement issues

Output:
  Mode 1: Modified files + improvement report
  Mode 2: GitHub issues + pattern detection report

═══════════════════════════════════════════════════════════════════════
```

---

## Workflow RLM (8 phases)

### Phase 0 : Détection du mode

```yaml
mode_detection:
  step_1_check_repo:
    action: |
      git remote get-url origin 2>/dev/null

  step_2_determine_mode:
    rules:
      - if: "remote contains 'kodflow/devcontainer-template'"
        then: "MODE_DOCS_IMPROVEMENT"
        scope: ".claude/docs/**/*.md"

      - else:
        then: "MODE_ANTI_PATTERN"
        scope: "**/*.md + source files"
        target_repo: "kodflow/devcontainer-template"

  step_3_announce:
    output: |
      ═══════════════════════════════════════════════
        /improve - Mode Detection
      ═══════════════════════════════════════════════

        Repository: {repo_name}
        Mode: {MODE_DOCS_IMPROVEMENT | MODE_ANTI_PATTERN}

        Scope:
          {file_count} files to analyze
          {category_count} categories detected

      ═══════════════════════════════════════════════
```

---

### Phase 1 : Inventaire et partitionnement

```yaml
inventory:
  mode_docs:
    action: |
      Glob(".claude/docs/**/*.md")

    categorize:
      - category: "principles"
        files: [solid.md, dry.md, kiss.md, ...]
      - category: "creational"
        files: [factory.md, builder.md, ...]
      # ... autres catégories

  mode_antipattern:
    action: |
      # Inventaire des fichiers du projet
      Glob("**/*.md")
      Glob("**/*.{ts,js,py,go,rs,java}")

    categorize:
      - type: "documentation"
        files: [README.md, CLAUDE.md, ...]
      - type: "source_code"
        files: [src/**/*]
      - type: "configuration"
        files: [*.json, *.yaml, *.toml]

  output: |
    ═══════════════════════════════════════════════
      /improve - Inventory Complete
    ═══════════════════════════════════════════════

      Files to analyze: {total_count}

      By category:
        ├─ {category_1}: {count} files
        ├─ {category_2}: {count} files
        └─ {category_N}: {count} files

      Agents to launch: {min(total_count, 20)}

    ═══════════════════════════════════════════════
```

---

### Phase 2 : Lancement agents parallèles (RLM Pattern: Partition + Map)

**CRITIQUE : Lancer TOUS les agents dans UN SEUL message.**

```yaml
parallel_agents:
  mode_docs:
    agent_per_file:
      subagent_type: "general-purpose"
      model: "haiku"  # Fast for analysis
      prompt_template: |
        TASK: Analyze and improve pattern documentation

        FILE: {file_path}
        CATEGORY: {category}

        INSTRUCTIONS:
        1. READ the current file content
        2. IDENTIFY improvement opportunities:
           - Outdated information
           - Missing examples
           - Inconsistencies with other patterns
           - Unclear explanations
        3. WEB SEARCH for latest best practices:
           - Search: "{pattern_name} best practices 2024"
           - Check official documentation
           - Find new use cases
        4. PROPOSE improvements:
           - Content updates
           - New examples
           - Cross-references to add
           - Corrections

        OUTPUT FORMAT (JSON):
        {
          "file": "{file_path}",
          "status": "OK | NEEDS_UPDATE | OUTDATED | INCOMPLETE",
          "improvements": [
            {
              "type": "content | example | reference | fix",
              "description": "...",
              "current": "...",
              "proposed": "...",
              "source": "url or 'internal'"
            }
          ],
          "cross_references": ["related_pattern_1", "related_pattern_2"],
          "confidence": "HIGH | MEDIUM | LOW"
        }

  mode_antipattern:
    agent_per_file:
      subagent_type: "general-purpose"
      model: "haiku"
      prompt_template: |
        TASK: Detect anti-patterns and non-conformities

        FILE: {file_path}
        TYPE: {file_type}

        REFERENCE DOCS: /workspace/.claude/docs/

        INSTRUCTIONS:
        1. READ the file content
        2. COMPARE with documented patterns in .claude/docs/:
           - Check principles/ (SOLID, DRY, KISS, etc.)
           - Check relevant category patterns
        3. DETECT violations:
           - Anti-patterns
           - Missing patterns that should be applied
           - Inconsistencies with best practices
        4. DETECT positive patterns:
           - Good practices worth documenting
           - Interesting approaches
           - Innovations

        OUTPUT FORMAT (JSON):
        {
          "file": "{file_path}",
          "violations": [
            {
              "pattern": "pattern_name",
              "type": "VIOLATION | MISSING | IMPROVEMENT",
              "severity": "HIGH | MEDIUM | LOW",
              "description": "...",
              "code_excerpt": "...",
              "suggested_fix": "...",
              "doc_reference": ".claude/docs/path/to/pattern.md"
            }
          ],
          "positive_patterns": [
            {
              "pattern": "pattern_name or 'NEW'",
              "description": "...",
              "code_excerpt": "...",
              "worth_documenting": true | false
            }
          ]
        }

  execution:
    max_parallel: 20  # Limit to avoid overload
    batch_strategy: |
      SI file_count > 20:
        → Batch en groupes de 20
        → Attendre completion avant batch suivant
      SINON:
        → Lancer tous en parallèle
```

---

### Phase 3 : Collecte et agrégation

```yaml
aggregation:
  collect_results:
    action: |
      POUR chaque agent_result:
        → Parser JSON output
        → Valider structure
        → Ajouter au rapport

  aggregate:
    mode_docs:
      by_status:
        OK: [files...]
        NEEDS_UPDATE: [files...]
        OUTDATED: [files...]
        INCOMPLETE: [files...]

      by_category:
        principles: {ok: N, updates: N}
        creational: {ok: N, updates: N}
        # ...

    mode_antipattern:
      by_severity:
        HIGH: [violations...]
        MEDIUM: [violations...]
        LOW: [violations...]

      positive_patterns: [patterns...]

  output: |
    ═══════════════════════════════════════════════
      /improve - Analysis Complete
    ═══════════════════════════════════════════════

      Mode: {mode}
      Files analyzed: {total}

      {mode_docs}
      Status:
        ✓ OK: {ok_count}
        ⚠ Needs update: {update_count}
        ✗ Outdated: {outdated_count}
        ○ Incomplete: {incomplete_count}
      {/mode_docs}

      {mode_antipattern}
      Violations:
        🔴 HIGH: {high_count}
        🟡 MEDIUM: {medium_count}
        🟢 LOW: {low_count}

      Positive patterns found: {positive_count}
      {/mode_antipattern}

    ═══════════════════════════════════════════════
```

---

### Phase 4 : Validation croisée (WebSearch)

```yaml
cross_validation:
  for_each_improvement:
    action: |
      WebSearch("{pattern_name} {year} best practices")
      WebSearch("{pattern_name} official documentation")

    validate:
      - 3+ sources confirment → VALIDATED
      - 2 sources → MEDIUM confidence
      - 1 source → LOW confidence, flag for review
      - 0 sources → SKIP (ne pas inclure)

  sources_whitelist:
    - Official language docs (go.dev, docs.python.org, etc.)
    - Framework docs (react.dev, kubernetes.io, etc.)
    - Architecture references (martinfowler.com, refactoring.guru)
    - RFCs (rfc-editor.org, tools.ietf.org)
    - OWASP (owasp.org)
```

---

### Phase 5 : Application ou création d'issues

```yaml
application:
  mode_docs:
    if_flag_check:
      action: "Display proposed changes only"

    if_flag_fix:
      action: |
        POUR chaque improvement VALIDATED:
          Edit(file_path, old_string, new_string)

    default:
      action: |
        AskUserQuestion:
          "Appliquer les {N} améliorations validées ?"
          options:
            - "Oui, tout appliquer"
            - "Revoir une par une"
            - "Seulement HIGH confidence"
            - "Non, générer rapport uniquement"

  mode_antipattern:
    create_issues:
      target: "kodflow/devcontainer-template"

      for_violations:
        template: |
          ## Anti-Pattern Report: {pattern_name}

          **Source:** `{project_name}`
          **File:** `{file_path}:{line_number}`
          **Severity:** {severity}

          ### Violation Details

          {description}

          ### Code Excerpt

          ```{language}
          {code_excerpt}
          ```

          ### Expected Pattern

          Reference: `.claude/docs/{doc_reference}`

          {expected_pattern_summary}

          ### Suggested Documentation Improvement

          - [ ] Add clarification in `{doc_reference}`
          - [ ] Add example for this edge case
          - [ ] Update anti-pattern section

          ---
          _Auto-generated by `/improve` skill_

        labels:
          - "documentation"
          - "improvement"
          - "auto-generated"

      for_positive_patterns:
        template: |
          ## New Pattern Discovery: {pattern_name}

          **Source:** `{project_name}`
          **File:** `{file_path}`

          ### Pattern Description

          {description}

          ### Code Example

          ```{language}
          {code_excerpt}
          ```

          ### Proposed Documentation Location

          - Category: `{suggested_category}`
          - File: `.claude/docs/{category}/{pattern_name}.md`

          ### Why Document This

          {rationale}

          ---
          _Auto-generated by `/improve` skill_

        labels:
          - "documentation"
          - "new-pattern"
          - "auto-generated"
```

---

### Phase 6 : Génération du rapport

```yaml
report_generation:
  file: ".improve-report.md"

  template: |
    # Improve Report

    Generated: {ISO8601}
    Mode: {mode}
    Repository: {repo_name}

    ## Summary

    | Metric | Value |
    |--------|-------|
    | Files analyzed | {total_files} |
    | Improvements found | {improvements_count} |
    | Applied | {applied_count} |
    | Issues created | {issues_count} |

    ## {mode_docs: Documentation Improvements}

    ### By Category

    | Category | Files | OK | Updates | Outdated |
    |----------|-------|----|---------|---------|
    {category_rows}

    ### Improvements Applied

    {improvement_list}

    ### Pending Improvements

    {pending_list}

    ## {mode_antipattern: Anti-Pattern Analysis}

    ### Violations Found

    | File | Pattern | Severity | Issue |
    |------|---------|----------|-------|
    {violation_rows}

    ### Positive Patterns Discovered

    {positive_patterns_list}

    ### Issues Created

    {issues_list}

    ## Recommendations

    {recommendations}

    ---
    _Generated by /improve (RLM Multi-Agent)_
```

---

### Phase 7 : Nettoyage et feedback

```yaml
cleanup:
  actions:
    - Remove temporary files
    - Update .improve-cache if exists
    - Log execution metrics

  feedback_loop:
    if_issues_created:
      message: |
        ✓ {issue_count} issues créées sur kodflow/devcontainer-template

        Ces issues permettront d'améliorer la documentation pour
        éviter ces patterns dans les futurs projets.

        Voir: https://github.com/kodflow/devcontainer-template/issues?q=is:open+label:auto-generated
```

---

## Catégories supportées (Mode Docs)

| Catégorie | Scope | Patterns |
|-----------|-------|----------|
| `principles` | SOLID, DRY, KISS, YAGNI | ~10 |
| `creational` | Factory, Builder, Singleton | ~5 |
| `structural` | Adapter, Decorator, Proxy | ~7 |
| `behavioral` | Observer, Strategy, Command | ~11 |
| `performance` | Cache, Lazy Load, Pool | ~12 |
| `concurrency` | Thread Pool, Actor, Mutex | ~15 |
| `enterprise` | PoEAA (Martin Fowler) | ~40 |
| `messaging` | EIP patterns | ~31 |
| `ddd` | Aggregate, Entity, Repository | ~14 |
| `functional` | Monad, Functor, Either | ~15 |
| `architectural` | Hexagonal, CQRS, Event Sourcing | ~10 |
| `cloud` | Circuit Breaker, Saga | ~15 |
| `resilience` | Retry, Timeout, Bulkhead | ~10 |
| `security` | OAuth, JWT, RBAC | ~12 |
| `testing` | Mock, Stub, Fixture | ~15 |
| `devops` | GitOps, IaC, Blue-Green | ~12 |
| `integration` | API Gateway, BFF | ~8 |
| `refactoring` | Strangler Fig, Branch by Abstraction | ~5 |

---

## Détection anti-patterns (Mode Anti-Pattern)

### Catégories de violations

| Type | Description | Exemple |
|------|-------------|---------|
| `SOLID_VIOLATION` | Violation des principes SOLID | God class, Dependency Inversion |
| `DRY_VIOLATION` | Code dupliqué | Même logique à plusieurs endroits |
| `COUPLING` | Couplage fort | Dépendances circulaires |
| `MISSING_PATTERN` | Pattern manquant | Pas de Factory pour création complexe |
| `SECURITY` | Faille sécurité | Hardcoded secrets, Injection |
| `PERFORMANCE` | Issue performance | N+1 queries, Missing cache |
| `ERROR_HANDLING` | Mauvaise gestion erreurs | Silent catch, Missing retry |
| `NAMING` | Convention nommage | Inconsistent naming |
| `DOCUMENTATION` | Documentation manquante | Missing CLAUDE.md |

### Patterns positifs détectés

| Type | Description |
|------|-------------|
| `GOOD_PRACTICE` | Pratique exemplaire |
| `INNOVATION` | Approche innovante |
| `PATTERN_EXTENSION` | Extension d'un pattern existant |
| `NEW_PATTERN` | Pattern non documenté |

---

## GARDE-FOUS

| Action | Status |
|--------|--------|
| Modifier sans validation WebSearch | ❌ INTERDIT |
| Créer issue sans code excerpt | ❌ INTERDIT |
| Skip cross-validation | ❌ INTERDIT |
| Agents séquentiels (si parallélisable) | ❌ INTERDIT |
| Modifier fichiers hors .claude/docs/ (mode docs) | ❌ INTERDIT |
| Créer issues sur repo autre que template | ❌ INTERDIT |

---

## Exemples d'exécution

### Mode Documentation (devcontainer-template)

```
/improve

═══════════════════════════════════════════════
  /improve - Documentation Enhancement
═══════════════════════════════════════════════

  Mode: DOCS_IMPROVEMENT
  Scope: .claude/docs/**/*.md

  Files: 155
  Categories: 18

  Launching 20 parallel agents...

  Progress: ████████████████████ 100%

  Results:
    ✓ OK: 142
    ⚠ Needs update: 10
    ✗ Outdated: 2
    ○ Incomplete: 1

  Improvements validated: 23

  Apply changes? [Y/n]

═══════════════════════════════════════════════
```

### Mode Anti-Pattern (autre projet)

```
/improve

═══════════════════════════════════════════════
  /improve - Anti-Pattern Detection
═══════════════════════════════════════════════

  Mode: ANTI_PATTERN
  Repository: my-project
  Target: kodflow/devcontainer-template

  Files: 47
  Types: md(5), ts(30), json(12)

  Launching 20 parallel agents...

  Progress: ████████████████████ 100%

  Results:
    🔴 HIGH violations: 3
    🟡 MEDIUM violations: 8
    🟢 LOW violations: 15

    ✨ Positive patterns: 5

  Creating issues...
    ✓ Issue #156: SOLID violation in UserService
    ✓ Issue #157: Missing Circuit Breaker pattern
    ✓ Issue #158: New pattern - Typed Event Bus

  Report: .improve-report.md

═══════════════════════════════════════════════
```

---

## Configuration

```yaml
# .claude/improve.yml (optionnel)
improve:
  mode: auto  # auto | docs | antipattern

  docs:
    categories:
      - all  # ou liste spécifique
    skip_files:
      - "*/TEMPLATE-*.md"

  antipattern:
    severity_threshold: LOW  # LOW | MEDIUM | HIGH
    create_issues: true
    positive_patterns: true

  agents:
    max_parallel: 20
    model: haiku
    timeout: 120s
```
