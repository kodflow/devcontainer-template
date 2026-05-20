# refine/synthesis.md — Skills Architecture v1.3 (PR3)

## Pipeline

```
collect → dedup → rank → budget → render → compact
```

### 1. Collect

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

### 2. Dedup

Two findings are duplicates iff their `claim` (lowercased, punctuation
stripped) matches AND their `evidence_paths` intersect. Keep the
finding from the lens with the higher criticality flag.

### 3. Rank

Severity then critical-lens-origin:

```
blocker (critical lens) > blocker > high (critical) > high > medium > low
```

### 4. Budget

Directive budget: 4096 chars (FULL), 2000 chars (LIGHT). Cuts happen by
trimming low-severity findings first, then non-critical lens findings,
never blockers or critical-lens findings.

### 5. Render

Two outputs:

- **`.claude/goals/<slug>.md`** — full contract, no budget. Proof
  triplets: `(claim, evidence, remediation)`.
- **runtime directive** — compact `/goal "..."` line within budget.

### 6. Compact

Replace prose with a tight checklist; strip filler words; keep file
paths and identifiers verbatim.

## Output schema

```json
{
  "mode": "LIGHT|FULL",
  "lenses_run": N,
  "lenses_dropped": [...],
  "findings_total": N,
  "findings_after_dedup": N,
  "directive_char_count": N,
  "directive": "<≤4096 chars>",
  "contract_path": ".claude/goals/<slug>.md"
}
```
