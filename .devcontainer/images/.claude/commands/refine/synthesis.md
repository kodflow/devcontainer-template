# refine/synthesis.md — Skills Architecture v1.4 (PR3 + v1.4 modes)

## Pipeline per mode

| Mode | Pipeline steps |
|---|---|
| FULL | `collect → dedup → rank → budget → render → compact` |
| BARE | `template → budget → render → compact` |
| FROM-CONTRACT | `read → extract → budget → render → compact` |

The **budget** and **compact** steps are mode-agnostic — single source
of truth for the 4096-char rule lives in this file.

### FULL pipeline

#### 1. Collect

Each lens returns JSON of shape:

```json
{
  "lens": "lens-N-<name>",
  "findings": [
    {"severity": "blocker|high|medium|low",
     "claim": "...",
     "evidence_paths": ["src/...", "tests/..."],
     "remediation": "..."}
  ]
}
```

#### 2. Dedup

Two findings are duplicates iff their `claim` (lowercased, punctuation
stripped) matches AND their `evidence_paths` intersect. Keep the
finding from the lens with the higher criticality flag.

#### 3. Rank

Severity then critical-lens-origin:

```
blocker (critical lens) > blocker > high (critical) > high > medium > low
```

### BARE pipeline

#### 1. Template

The free-form description is parsed into 5 slots. Each slot is optional;
missing slots are inferred from the description heuristically.

```
WHAT  : <action verb> <object> <details>
WHY   : <motivation>
WHERE : <files / modules / layers>
HOW   : <constraints, patterns, things to avoid>
DONE  : <measurable success criteria>
```

Heuristics:
- First sentence → WHAT
- Sentence starting with "because/parce que/since" → WHY
- File paths or directory mentions → WHERE
- "without/sans/avoid/never" clauses → HOW
- "tests pass / coverage ≥ N / 0 errors" patterns → DONE

If the description is already 5-line-structured, the parser preserves it.

### FROM-CONTRACT pipeline

#### 1. Read

Read `.claude/goals/<slug>.md`. The file MUST have the v1.4 frontmatter
schema (slug, mode, generated_at). Reject if absent.

#### 2. Extract

Pull the **Acceptance criteria** + **Proof triplets** + **Rollback** +
**Out of scope** sections, ignore the rest. The full contract stays
untouched on disk; we only re-derive the runtime directive.

### Shared steps (all modes)

#### 4. Budget

Directive budget:
- FULL: 4096 chars (FULL plan) or 2000 chars (LIGHT plan).
- BARE: 2000 chars by default, 4096 if `--full-budget` flag.
- FROM-CONTRACT: 4096 chars (the contract was the analysis; budget
  enforces what fits in `/goal`).

Cuts happen by trimming low-severity findings first (FULL), then
non-critical lens findings, never blockers or critical-lens findings.
For BARE, cuts trim HOW and DONE filler — WHAT/WHY/WHERE are kept intact.

#### 5. Render

| Mode | What's written |
|---|---|
| FULL | `.claude/goals/<slug>.md` (full contract) + runtime directive |
| BARE | `.claude/goals/<slug>.md` (5-slot template) + runtime directive |
| FROM-CONTRACT | runtime directive only — input file is never overwritten |

#### 6. Compact

Replace prose with a tight checklist; strip filler words; keep file
paths and identifiers verbatim. Same logic across all modes — this is
the single budget enforcer.

## Output schema (v1.4 — adds `mode` enum + bare/contract bookkeeping)

```json
{
  "mode": "FULL_LIGHT|FULL|BARE|FROM_CONTRACT",
  "lenses_run": N,
  "lenses_dropped": [...],
  "findings_total": N,
  "findings_after_dedup": N,
  "directive_char_count": N,
  "directive": "<≤4096 chars>",
  "contract_path": ".claude/goals/<slug>.md",
  "contract_written": true|false
}
```

`lenses_run`/`lenses_dropped`/`findings_*` are 0 / [] / 0 in BARE +
FROM-CONTRACT modes. `contract_written` is false in FROM-CONTRACT.
