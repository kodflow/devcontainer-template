# refine/synthesis.md — Skills Architecture v1.5

## Pipeline per mode

| Mode | Pipeline steps |
|---|---|
| FULL | `collect → dedup → rank → render → refine-pipeline → compact-to-minimum` |
| BARE | `template → render → refine-pipeline → compact-to-minimum` |
| FROM-CONTRACT | `read → extract → render → refine-pipeline → compact-to-minimum` |

The **refine-pipeline** step (post-lens, 10 mono-concern agents) is
documented in `dispatch.md`. The **compact-to-minimum** step is
mode-agnostic — single source of truth for the directive char-cap
lives in this file.

### Char-cap — ceiling, not target (v1.5)

```
ceiling   = 4000 chars  (hard tool limit on /goal directive)
target    = minimum viable length given the content
floor_warn = 800 chars  (suspect over-compression below this)
```

`/refine` enforces a **4000-char ceiling** in every mode. The number
4000 is the tool's hard limit — not an aesthetic goal. The design
target is the **minimum viable length** that still preserves the
contract (acceptance criteria, scope, evidence, rollback).

There is no LIGHT-vs-FULL ceiling split. The natural output is
whatever the content requires; the skill decides that based on
content, never on input shape or plan complexity. Below the 800-char
**floor warning**, the synthesis log emits a `suspect-over-compression`
note so a human reviewer can confirm the contract is still intact.

| Mode | Typical directive length | Notes |
|---|---|---|
| FULL with all 10 lenses + heavy findings | usually near ceiling (3500-4000) | Risk of bumping ceiling — refine-density-optimizer trims |
| FULL with only 4 critical lenses | often 1500-2500 | Minimum viable is naturally smaller |
| BARE with terse description | often 600-1200 | Floor warning may fire — usually fine |
| FROM-CONTRACT after manual trimming | whatever the contract holds | Re-derived directly from disk |

The skill never pads to hit the ceiling; it stops short when content
runs out. The ceiling is the **upper bound**, never the aim.

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

Read `.claude/goals/<slug>.md`. The file MUST have the v1.5 frontmatter
schema (slug, mode, generated_at). Reject if absent.

#### 2. Extract

Pull the **Acceptance criteria** + **Proof triplets** + **Rollback** +
**Out of scope** sections, ignore the rest. The full contract stays
untouched on disk; we only re-derive the runtime directive.

### Shared steps (all modes)

#### 4. Render

| Mode | What's written |
|---|---|
| FULL | `.claude/goals/<slug>.md` (full contract) + runtime directive |
| BARE | `.claude/goals/<slug>.md` (5-slot template) + runtime directive |
| FROM-CONTRACT | runtime directive only — input file is never overwritten |

#### 5. Refine-pipeline (post-render, post-lens)

The 10 mono-concern `refine-*` agents documented in `dispatch.md` run
in canonical order against the rendered directive. Each agent
compresses one dimension; outputs are additive, never merged. BARE
and FROM-CONTRACT skip agents 1-7 (no lens findings to compress) but
still run agents 8-10 (`refine-imperative-rewriter`,
`refine-chain-stripper`, `refine-density-optimizer`) on the rendered
directive.

#### 6. Compact-to-minimum

Single function, all modes. The ceiling is the only hard guarantee —
the natural target is the minimum viable length given the content.

```
compact_to_minimum(text, ceiling=4000, floor_warn=800):
  # First, hard ceiling enforcement
  if len(text) > ceiling:
    # Cut order (preserve highest-value content):
    #   1. trim low-severity findings (FULL only)
    #   2. trim non-critical lens findings (FULL only)
    #   3. compress prose to checklist
    #   4. strip filler words ("the", "very", "really", etc.)
    #   5. abbreviate sub-bullets, keep file paths + identifiers verbatim
    # Never trim:
    #   - blockers (FULL)
    #   - critical-lens findings (FULL)
    #   - WHAT slot (BARE)
    #   - acceptance criteria checklist (all modes)
    text = cut_until(text, ceiling)
  # Then, floor advisory (does not modify text — diagnostic only)
  if len(text) < floor_warn:
    emit_warning("suspect-over-compression", chars=len(text), floor=floor_warn)
  return text  # guaranteed <= ceiling
```

## Output schema (v1.5)

```json
{
  "mode": "FULL|BARE|FROM_CONTRACT",
  "lens_depth": "light|full|n/a",   // FULL only
  "lenses_run": N,
  "lenses_dropped": [...],
  "findings_total": N,
  "findings_after_dedup": N,
  "directive_char_count": N,
  "directive_char_target": 4000,
  "directive": "<≤4000 chars>",
  "contract_path": ".claude/goals/<slug>.md",
  "contract_written": true|false
}
```

`directive_char_target` is preserved as a schema field for the test
contract, but its semantic meaning is **char ceiling enforced by the
/goal tool** — not a length the synthesis aims for. The natural
target is the minimum viable length given the content.

`lenses_run`/`lenses_dropped`/`findings_*` are 0 / [] / 0 in BARE +
FROM-CONTRACT. `contract_written` is false in FROM-CONTRACT.
