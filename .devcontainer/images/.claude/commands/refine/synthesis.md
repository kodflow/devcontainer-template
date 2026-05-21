# refine/synthesis.md — Skills Architecture v1.5

## Pipeline per mode

| Mode | Pipeline steps |
|---|---|
| FULL | `collect → dedup → rank → render → compact-to-4000` |
| BARE | `template → render → compact-to-4000` |
| FROM-CONTRACT | `read → extract → render → compact-to-4000` |

The **compact-to-4000** step is mode-agnostic — single source of truth
for the directive char-cap lives in this file.

### Char-cap — single rule for all modes (v1.5)

```
target = 4000 chars  (hard tool limit on /goal directive)
```

`/refine` targets 4000 chars **always**. There is no LIGHT-vs-FULL
budget split. The natural output may be shorter when there's simply
less to say; the skill decides that based on content, never on input
shape or plan complexity.

| Mode | Natural shorter output? |
|---|---|
| FULL with all 10 lenses + heavy findings | usually near 4000 |
| FULL with only 4 critical lenses | often 2000-3500 |
| BARE with terse description | often 800-1500 |
| FROM-CONTRACT after manual trimming | whatever the contract holds |

The skill never pads to hit 4000; it just stops short when content runs out.

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

#### 5. Compact-to-4000

Single function, all modes:

```
compact_to_target(text, target=4000):
  if len(text) <= target:
    return text  # no compaction needed
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
  return compacted_text  # guaranteed <= target
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

`lenses_run`/`lenses_dropped`/`findings_*` are 0 / [] / 0 in BARE +
FROM-CONTRACT. `contract_written` is false in FROM-CONTRACT.
