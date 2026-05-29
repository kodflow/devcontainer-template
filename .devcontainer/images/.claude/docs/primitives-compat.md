# Claude Code Primitives — Compatibility & Fallback Policy

This document declares which primitives the skills initiative depends on,
and the documented fallback for each when the primitive is `absent`.

## Probe at session start

`probe-primitives.sh` is called during the `postCreate.sh` lifecycle and
emits `.claude/state/primitives.json` with the availability matrix plus
the `ExitPlanMode` input schema. Skills consult this file before invoking
a primitive — `present` uses it, `absent` triggers the documented
fallback, `unknown` defers the decision to the calling skill.

## Per-primitive

### Monitor
- Required by: `/git --watch` (W5b), `/do:loop` (W1), `/test`/`/infra` long-run (W8)
- Probe: `jq -e '.tools[] | select(.name=="Monitor")' <schema>`
- Fallback: inline polling loop with `sleep` — slower, no event semantics
- Acceptance test: `TestClaudePrimitiveAvailability_Monitor`

### Workflow
- Required by: `/search` (web-complement engine — the `research` workflow)
- Probe: `jq -e '.tools[] | select(.name=="Workflow")' <schema>`
- **Status is MANDATORY-by-doctrine, NOT gate-by-probe.** `/search` always invokes
  `Workflow({name:'research', …})` whenever the local-first gate does not
  short-circuit; it does **not** consult this matrix entry to decide. The probe
  records availability for diagnostics/`/audit` only. (History: `/search`
  originally gated on a `primitives.json.Workflow` key that the probe never
  emitted — an unsatisfiable gate that disabled the engine entirely. The key is
  now emitted for completeness; the gate was removed.)
- Fallback: legacy parallel `Task`-agent path in `search/parallel.md` — used ONLY
  if the `Workflow` tool call itself errors, never as a routine choice.
- Acceptance test: `TestClaudePrimitiveAvailability_Workflow`

### Skill
- Required by: PR1 (4 active chains), PR3 (`/refine` → `/do`)
- Probe: `jq -e '.tools[] | select(.name=="Skill")' <schema>`
- Fallback: print magic-string suggestion; user invokes next skill manually
- Acceptance test: `TestClaudePrimitiveAvailability_Skill`

### ExitPlanMode
- Required by: PR1 (`/plan` Phase 6.0)
- Probe: `jq -e '.tools[] | select(.name=="ExitPlanMode")' <schema>`
- Schema record: `.ExitPlanMode.input_schema` captured for PR1 validation
- Fallback: write plan to `.claude/plans/<slug>.md`; user runs `/do --plan <path>` manually
- Acceptance test: `TestClaudePrimitiveAvailability_ExitPlanMode`

### EnterPlanMode
- Required by: legacy `/plan` only — not required by skills modernization
- Probe: `jq -e '.tools[] | select(.name=="EnterPlanMode")' <schema>`
- Fallback: skip (Phase 6.0 writes plan file directly)
- Acceptance test: `TestClaudePrimitiveAvailability_EnterPlanMode`

### PushNotification
- Required by: PR5b (`/do` loop, `/git --merge`), PR8 (long-op terminal states)
- Probe: `jq -e '.tools[] | select(.name=="PushNotification")' <schema>`
- Fallback: stderr `[BELL]` line only
- Acceptance test: `TestClaudePrimitiveAvailability_PushNotification`

### CronCreate
- Required by: PR8 (`/audit --watch`, `/ktn` daily health probe)
- Probe: `jq -e '.tools[] | select(.name=="CronCreate")' <schema>`
- Fallback: skip scheduled features with documented TODO marker
- Acceptance test: `TestClaudePrimitiveAvailability_CronCreate`

### AskUserQuestion
- Required by: PR1 (`/do` questions phase when interactive)
- Probe: `jq -e '.tools[] | select(.name=="AskUserQuestion")' <schema>`
- Fallback: plain stderr prompt + `read -r line`
- Acceptance test: `TestClaudePrimitiveAvailability_AskUserQuestion`

### Bash run_in_background
- Required by: PR8 (Monitor companion for long-running commands)
- Probe: `jq -e '.tools[] | select(.name=="Bash") | .input_schema.properties.run_in_background' <schema>`
- Fallback: inline `&` + `wait` (no notification on completion)
- Acceptance test: `TestClaudePrimitiveAvailability_BashRunInBackground`

### Task
- Required by: PR3 (`/refine` lens dispatch — parallel work)
- Probe: `jq -e '.tools[] | select(.name=="Task")' <schema>`
- Fallback: sequential `Agent` calls (slower; no fanout)
- Acceptance test: `TestClaudePrimitiveAvailability_Task`

### Agent
- Required by: PR3 (`/refine` lens dispatch — single-agent path)
- Probe: `jq -e '.tools[] | select(.name=="Agent")' <schema>`
- Fallback: skip lens; annotate telemetry
- Acceptance test: `TestClaudePrimitiveAvailability_Agent`

### TaskCreate
- Required by: PR3 (`/refine` lens dispatch — task tracking)
- Probe: `jq -e '.tools[] | select(.name=="TaskCreate")' <schema>`
- Fallback: inline TODO list in goal contract
- Acceptance test: `TestClaudePrimitiveAvailability_TaskCreate`

### TaskUpdate
- Required by: PR3 (`/refine` lens dispatch — status mutation)
- Probe: `jq -e '.tools[] | select(.name=="TaskUpdate")' <schema>`
- Fallback: skip status mutation
- Acceptance test: `TestClaudePrimitiveAvailability_TaskUpdate`

### mcp__github__*
- Required by: PR1 (`/git --merge` via `mcp__github__merge_pull_request`), PR8 (`/feature --gh-sync`)
- Probe: `jq -e '.mcpServers.github' .mcp.json`
- Fallback: `gh` CLI (current behavior of legacy skills)
- Acceptance test: `TestClaudePrimitiveAvailability_McpGithub`

### mcp__gitlab__*
- Required by: PR1 (`/git --merge` GitLab path) — auto-detected from remote
- Probe: `jq -e '.mcpServers.gitlab' .mcp.json`
- Fallback: `glab` CLI
- Acceptance test: `TestClaudePrimitiveAvailability_McpGitlab`

### mcp__ide__getDiagnostics
- Required by: PR7 (`/lint` migration to IDE diagnostics)
- Probe: `jq -e '.tools[] | select(.name=="mcp__ide__getDiagnostics")' <schema>`
- Fallback: shell out to language linter (current `/lint` behavior)
- Acceptance test: `TestClaudePrimitiveAvailability_McpIdeDiagnostics`

### mcp__context7__*
- Required by: PR4 (`/search` migration — official-source documentation)
- Probe: `jq -e '.mcpServers.context7' .mcp.json`
- Fallback: WebFetch + whitelist (current `/search` behavior)
- Acceptance test: `TestClaudePrimitiveAvailability_McpContext7`

## Baseline (not probed)

`Read`, `Write`, `Glob`, `Grep`, `Bash` (without `run_in_background`) —
their absence indicates a broken Claude Code runtime; no fallback is
documented because the agent cannot function at all without them.
