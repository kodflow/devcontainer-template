# Phase 1.0: Local Documentation (LOCAL-FIRST)

**ALWAYS execute first. Local documentation is VALIDATED and takes priority.**

```yaml
local_first:
  source: "~/.claude/docs/"
  index: "~/.claude/docs/README.md"

  workflow:
    1_search_local:
      action: |
        Grep("~/.claude/docs/", pattern=<keywords>)
        Glob("~/.claude/docs/**/*.md", pattern=<topic>)
      output: [matching_files]

    2_read_matches:
      action: |
        FOR each matching_file:
          Read(matching_file)
          Extract: definition, examples, related patterns
      output: local_knowledge

    3_evaluate_coverage:
      # "Local" means VALIDATED docs ONLY: ~/.claude/docs/** and the repo's
      # docs/*.md. Project SOURCE CODE, git history, and your own reasoning are
      # NOT "local coverage" — answering from them is a GAP, not a short-circuit.
      # This is the rule #382 enforces: the engine is the DEFAULT; LOCAL_COMPLETE
      # is the rare exception, never an escape hatch to skip the Workflow.
      rule: |
        Let matched_docs = the validated-doc files (~/.claude/docs/**, docs/*.md)
        that ACTUALLY CONTAIN the answer. You MUST be able to name them.

        IF matched_docs is non-empty AND those files cover >= 80% of the query:
          status = "LOCAL_COMPLETE"
          → write .claude/contexts/<slug>.md from local, STOP (skip the engine)
          → MUST list matched_docs as evidence in the Phase 1.0 output below
        ELSE:
          # Covers: zero matched validated-doc files; the answer would come from
          # project code / git history / reasoning; only partial doc coverage.
          status = (matched_docs cover >= 40% of the query) ? "LOCAL_PARTIAL"
                                                            : "LOCAL_NONE"
          → compute GAPS, then Workflow({name:'research', ...}) is MANDATORY

      anti_escape_hatch: |
        A topic being "100% internal to this repo" does NOT make it
        LOCAL_COMPLETE. Internal/codebase topics have NO entry in ~/.claude/docs/
        → matched_docs is empty → LOCAL_NONE (or PARTIAL) → the engine MUST run.
        If you cannot cite validated-doc files that hold the answer, you are NOT
        LOCAL_COMPLETE. Reading source code to synthesize an answer is exactly the
        case the engine exists for — run it.

  categories_mapping:
    design_patterns: "creational/, structural/, behavioral/"
    performance: "performance/"
    concurrency: "concurrency/"
    enterprise: "enterprise/"
    messaging: "messaging/"
    ddd: "ddd/"
    functional: "functional/"
    architecture: "architectural/"
    cloud: "cloud/, resilience/"
    security: "security/"
    testing: "testing/"
    devops: "devops/"
    integration: "integration/"
    principles: "principles/"
```

**Output Phase 1.0:**

```
═══════════════════════════════════════════════
  /search - Local Documentation Check
═══════════════════════════════════════════════

  Query    : <query>
  Keywords : <k1>, <k2>, <k3>

  Local Search (~/.claude/docs/):
    ├─ Matches: 3 files
    │   ├─ behavioral/observer.md (95% match)
    │   ├─ behavioral/README.md (70% match)
    │   └─ principles/solid.md (40% match)
    │
    └─ Coverage: 85% → LOCAL_COMPLETE

  Status: ✓ Using local documentation (validated)
  External search: SKIPPED (local sufficient)

═══════════════════════════════════════════════
```

**If LOCAL_PARTIAL:**

```
═══════════════════════════════════════════════
  /search - Local Documentation Check
═══════════════════════════════════════════════

  Query    : "OAuth2 JWT authentication"
  Keywords : OAuth2, JWT, authentication

  Local Search (~/.claude/docs/):
    ├─ Matches: 1 file
    │   └─ security/README.md (50% match)
    │
    └─ Coverage: 50% → LOCAL_PARTIAL

  Status: ⚠ Partial local coverage
  Gaps identified:
    ├─ OAuth2 flow details (not in local)
    └─ JWT implementation specifics (not in local)

  Action: External search for gaps only

═══════════════════════════════════════════════
```

---

## Phase 2.0: Decomposition (RLM Pattern: Peek + Grep)

**Analyze the query BEFORE any search:**

1. **Peek** - Identify complexity
   - Simple query (1 concept) → Direct Phase 1
   - Complex query (2+ concepts) → Decompose

2. **Grep** - Extract keywords
   ```
   Query: "OAuth2 with JWT for REST API"
   Keywords: [OAuth2, JWT, API, REST]
   Technologies: [OAuth2 → rfc-editor.org, JWT → tools.ietf.org]
   ```

3. **Systematic parallelization**
   - Always launch up to 6 Task agents in parallel
   - Cover all relevant domains

**Output Phase 2.0:**
```
═══════════════════════════════════════════════
  /search - RLM Decomposition
═══════════════════════════════════════════════

  Query    : <query>
  Keywords : <k1>, <k2>, <k3>

  Decomposition:
    ├─ Sub-query 1: <concept1> → <domain1>
    ├─ Sub-query 2: <concept2> → <domain2>
    └─ Sub-query 3: <concept3> → <domain3>

  Strategy: PARALLEL (6 Task agents max)

═══════════════════════════════════════════════
```
