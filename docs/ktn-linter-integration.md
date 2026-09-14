# ktn-linter Integration Contract

## Overview

This document defines the integration between `devcontainer-template` and `ktn-linter` for Claude Code hooks and MCP server configuration.

**Architecture: the `kodflow-hooks` marketplace plugin embeds ktn-linter calls in its own hook scripts, ktn-linter provides the runtime logic.**

```
┌───────────────────────────────────────────────────────────────┐
│              kodflow-hooks (marketplace plugin)                 │
│  - ktn-linter calls embedded in on-tool.sh (PreToolUse) and    │
│    on-stop.sh (Stop) — no PostToolUse call                     │
│  - Graceful degradation if ktn-linter not running               │
│  - MCP fragment system (requires_binary gate)                  │
└──────────────────────────┬────────────────────────────────────┘
                           │ HTTP calls (localhost:7717)
┌──────────────────────────▼────────────────────────────────────┐
│                    KTN-LINTER (runtime)                         │
│  - HTTP endpoints: /hooks/pre-tool-use, post-tool-use, stop    │
│  - ScanReport canonique + severity-first formatting            │
│  - Session tracking + package-scoped validation                │
└───────────────────────────────────────────────────────────────┘
```

## Responsibilities

### Template (devcontainer-template)

| Responsibility | Details |
|---------------|---------|
| **Binary** | Installs ktn-linter (Go feature) |
| **MCP registration** | Fragment at `/etc/mcp/features/go.mcp.json` with `requires_binary` gate |
| **Hook integration** | Delegated to the `kodflow-hooks` marketplace plugin — ktn-linter calls embedded in `on-tool.sh` (PreToolUse) and `on-stop.sh` (Stop); no PostToolUse call |
| **Graceful degradation** | Calls exit silently if ktn-linter is not running (curl fails → continue) |
| **Permissions** | `Bash(ktn-linter:*)` pre-authorized in settings.json |

### ktn-linter

| Responsibility | Details |
|---------------|---------|
| **HTTP server** | Listens on port 7717, exposes `/hooks/*` endpoints |
| **Lint logic** | ScanReport, severity ordering, phase grouping |
| **Response format** | Returns `hookSpecificOutput` JSON or plain text |
| **Session tracking** | Tracks edited packages via SessionID |
| **No settings.json writes** | The `kodflow-hooks` plugin's `hooks.json` handles all hook declarations |

### Consumer project

| Responsibility | Details |
|---------------|---------|
| **Zero manual configuration** | PreToolUse and Stop calls are embedded in `on-tool.sh` / `on-stop.sh` once the `kodflow-hooks` plugin is installed. |
| **Port override** | Set `KTN_LINTER_PORT` so `on-tool.sh` / `on-stop.sh` match your ktn-linter server. |

## Hook Integration Points

ktn-linter calls are embedded directly in the `kodflow-hooks` plugin's two
relevant scripts — no separate files, no PostToolUse call.

### `on-tool.sh` — PreToolUse (Write|Edit|MultiEdit|NotebookEdit)

After the protected-path check, probes `127.0.0.1:$KTN_LINTER_PORT` with a
bash `/dev/tcp` check and, only if it answers, calls `/hooks/pre-tool-use` to
surface existing package issues.

- Skips non-code files (*.md, *.json, *.yaml, *.yml, *.toml, /tmp/*, .claude/*)
- Curl timeout: 4s (within the hook's 15s timeout)
- Phase scope: `structural,signatures` (override: `KTN_PRE_PHASES`)
- Fail-open: nothing is called when the port doesn't answer; curl failure continues silently

### PostToolUse — no ktn-linter call

`on-tool.sh`'s PostToolUse path formats the file and logs; it does not call
ktn-linter. Lint feedback now happens at PreToolUse (structural/signatures,
per edit) and at Stop (full phase set, session-scoped) instead.

### `on-stop.sh` — Stop

Same port probe as PreToolUse; if the port answers, calls `/hooks/stop` for
session-level validation before the turn ends.

- Curl timeout: 28s (within the hook's 45s timeout)
- Phase scope: `structural,signatures,logic,performance,modern,style,comment,tests` (override: `KTN_STOP_PHASES`)
- A `decision: "block"` response is passed through verbatim; otherwise its text joins the single Stop feedback document (alongside the session-scoped `project-linter lint` run and the per-directory CLAUDE.md reminder)
- Never blocks session stop outright — only a `block` decision does, and that comes from ktn-linter itself

### Phase scope (per-request override, ktn-linter ≥ #190)

`on-tool.sh` (PreToolUse) and `on-stop.sh` (Stop) each inject an explicit `phases` field into the JSON request body, scoped to what the event-type actually needs to surface. The server's YAML config (`.ktn-linter.yaml`) is **not** consulted when `phases` is present — it acts as a per-request override. Empty/absent `phases` → YAML default (back-compat for servers pre-#190, which ignore the unknown field).

Override per-project via env vars (comma-separated, no spaces):

```bash
export KTN_PRE_PHASES=structural,signatures,modern
export KTN_STOP_PHASES=structural,signatures,logic,performance,modern,style,comment,tests,health
```

Defensive: if `jq` is missing, the scripts fall through to the raw `${INPUT:-{}}` body — server uses YAML default, no failure.

## Review Scope (diff | full)

`review_scope` is a ROOT field in `.ktn-linter.yaml` (sibling of `phases:`), default `diff`:

```yaml
version: 1
review_scope: diff   # diff (default) | full
phases:
  enabled: [1,2,3,4,5,6,7,8]
```

- **diff** = the MCP daemon surfaces ONLY issues on code changed vs the default branch (3-dot merge-base + staged + unstaged + untracked); pre-existing debt on untouched lines stays hidden.
- **full** = surface every issue across the whole project (legacy behaviour).
- **Fail-safe & loud:** no `.git`, shallow clone, or unresolved default branch ⇒ automatic full scan + `diff_warning` in the response (never a silent empty diff).
- **Filtering is response-time only:** the analysis cache always holds the full set, so switching diff↔full never triggers a re-scan.

> **Default changed.** An existing MCP user with NO `review_scope` field silently moves from whole-project to diff-only. Set `review_scope: full` to restore the old view.

### Per-command behaviour

`review_scope` is honoured by the daemon/MCP surface ONLY; the CLI `lint` is unaffected.

| Surface | Honours `review_scope`? | Behaviour |
|---|---|---|
| `ktn-linter serve` (daemon) | yes | diff by default |
| MCP `scan` tool | yes | diff by default; per-request `scope: "full"\|"diff"` override → full set from the same cached scan, no re-analysis |
| MCP `dump` tool | yes (full) | whole-project enumeration |
| HTTP `/scan` | yes | same per-request `scope` override |
| `ktn-linter lint` (CLI) | no | always full (CI/audit path) |
| `make lint` | no | wraps the CLI → full |

### Per-request override

The MCP `scan` tool accepts a per-request `scope` that overrides the server default:

```jsonc
{ "path": "./...", "mode": "cached", "scope": "full" }   // whole project, instant, no rescan
{ "path": "./...", "scope": "diff" }                      // force diff even if server default is full
```

Note: empty/unknown `scope` falls back to the server's configured `review_scope`.

### Daemon guard on `ktn-linter lint`

The CLI now preflights `GET :7717/health` and ABORTS (exit code `DaemonActive=42`) if the daemon is live, steering the caller to the MCP `scan`/`dump` tools to avoid redundant from-scratch rescans. Bypass (exceptional): `--force` or `KTN_FORCE_LOCAL=1` — prints a loud "EXCEPTIONAL OVERRIDE" notice.

IMPORTANT: a template-consumer project's `make lint` should NOT blindly add `--force` — the guard is the desired behaviour there (only ktn-linter's own repo passes `--force` because it self-lints with its own daemon live).

### Recommendation

Consumer projects that ship a `.ktn-linter.yaml` should PIN `review_scope: diff` explicitly with a comment, so the default-change is visible to readers. (The devcontainer-template itself is not a Go project and ships no `.ktn-linter.yaml`.)

## Hook Flow

```
Agent wants to edit file.go
        │
        ▼
┌─ PreToolUse ──────────────────────────────┐
│  on-tool.sh → protect files, then          │
│               package context (structural, │  ← "3 existing warnings in this package"
│               signatures) if port answers  │
└───────────────────────────────────────────┘
        │
        ▼
    Agent edits file.go
        │
        ▼
┌─ PostToolUse ─────────────────────────────┐
│  on-tool.sh → format file, edited-file    │
│               tracker, log (no ktn-linter │
│               call)                       │
└───────────────────────────────────────────┘
        │
        ▼
    ... more edits ...
        │
        ▼
┌─ Stop ────────────────────────────────────┐
│  on-stop.sh → session validation (full     │  ← "2 packages scanned, 0 violations"
│               phase set) + terminal bell   │
└───────────────────────────────────────────┘
```

## Timeout Justification

| Hook | Timeout | Curl | Rationale |
|------|---------|------|-----------|
| PreToolUse | 15s | 4s (`on-tool.sh`) | Must be fast — quick HTTP call to cached package state |
| PostToolUse | 20s | N/A — no ktn-linter call | Formatting only; lint feedback moved to PreToolUse and Stop |
| Stop | 45s | 28s (`on-stop.sh`) | Full project scan of packages touched this session, runs once at session end |

## Canonical Hooks Doctrine (Future)

ktn-linter hooks are evolving toward a canonical model based on `ScanReport`:

| Concept | Description |
|---------|-------------|
| **ScanReport** | Canonical data structure for all lint results (findings, severity, phase, location) |
| **HookSummary** | Text formatter that derives hook output from ScanReport |
| **Severity-first** | Stop feedback shows critical/error first, then warnings |
| **Phase ordering** | Results grouped by lint phase (syntax → semantics → style) |
| **SessionStore** | Tracks which packages were edited during the session |
| **Stop optimization** | Only scans packages touched during the session (via SessionID) |

### Forward compatibility

The `kodflow-hooks` plugin's hook calls are **endpoint-agnostic** — they forward the full hook input JSON to ktn-linter and relay the response. When ktn-linter evolves its response format (ScanReport v2, new fields), the scripts don't need to change.

### Health phase: `claude-rtk-hook` (proposed upstream)

> **Status:** local spec, not yet wired upstream. Tracking issue:
> `<TBD: open issue at kodflow/ktn-linter>` — when opened, link here and add
> `claude-rtk-hook` to `KTN_STOP_PHASES` defaults in `on-stop.sh`. Until then,
> **no template-side change** — this section documents intent only.

A new `health` phase (8) sub-rule that fires once at session end via the
`/hooks/stop` endpoint. Reports the same RTK mode/reason that `postStart.sh`
records at container start, so `Stop` events double-check the doctrine after
a session of edits.

**Signal source.** The rule reads `~/.claude/logs/<branch>/rtk-mode.json`
(written by `init_rtk` in `postStart.sh`, which only ever writes
`mode=degraded` with a reason); if absent, RTK is healthy and the rule stays
silent. The file schema is documented as a fixture in
`tests/scripts/rtk-config-toml.bats` (runtime artifact, never committed).

**Severity.** `info` — non-blocking, matches the project doctrine that
runtime degradation is visible but never blocking. Could be elevated to
`warning` upstream once the rule is stable; controllable per-project via
`KTN_*_SEVERITY` env (existing override pattern).

**Output (proposed).**

```text
[health][claude-rtk-hook] mode=degraded  reason=no-binary
                          fix=reinstall rtk, then restart the container
[health][claude-rtk-hook] mode=degraded  reason=config-invalid
                          fix=check ~/.config/rtk/config.toml schema
```

No line is emitted when `rtk-mode.json` is absent: the rewrite is then live
in `on-tool.sh` and there is nothing to report.

**Why it matters at session end.** A degraded mode mid-session means every
`rtk discover` entry from that session is a savings miss — visible in /audit
but easy to miss across many short sessions. The `Stop` summary surfaces it
when the operator is most likely to act.

## MCP Server Registration

```
Build time:
  .devcontainer/features/languages/go/install.sh
    → downloads ktn-linter binary
    → writes /etc/mcp/features/go.mcp.json

Runtime (every container start):
  postStart.sh → step_mcp_configuration()
    → checks: command -v ktn-linter (requires_binary gate)
    → if found: merges into /workspace/mcp.json
    → if not found: silently skips
```

**Port:** 7717 (configurable via `KTN_LINTER_PORT` env var in hook scripts).

## Idempotence Guarantees

| Scenario | Behavior |
|----------|----------|
| Container rebuild (×10) | `kodflow-hooks` plugin reinstalled/updated by `postStart.sh`, ktn-linter calls always present |
| ktn-linter not installed | curl fails silently, rest of hook script runs normally |
| ktn-linter not running | curl connection refused, rest of hook script runs normally |
| ktn-linter running | Full lint integration active |
| User has custom hooks in settings.local.json | Template hooks preserved, local overrides apply |

## Health Check

```bash
# 1. Binary installed?
which ktn-linter && ktn-linter --version

# 2. MCP server registered?
jq '.mcpServers["ktn-linter"]' /workspace/mcp.json

# 3. Hook scripts have ktn-linter integration? (kodflow-hooks plugin checkout)
grep -l "ktn-linter" <marketplace-checkout>/plugins/kodflow-hooks/hooks/scripts/{on-tool,on-stop}.sh

# 4. Server responding?
curl -sf http://localhost:7717/health && echo "OK" || echo "Not running"
```

## Override & Disable

### Change port

Set `KTN_LINTER_PORT` environment variable (default: 7717). Read by `on-tool.sh` (PreToolUse) and `on-stop.sh` (Stop) in the `kodflow-hooks` plugin.

### Disable ktn-linter hooks only

Set the environment variable to a non-listening port:

```bash
export KTN_LINTER_PORT=0
```

The port probe (`bash /dev/tcp`) then fails and neither script calls ktn-linter.

### Disable all hooks for an event

Override in `settings.local.json`:
```json
{ "hooks": { "PostToolUse": [] } }
```

**Warning:** This disables ALL PostToolUse hooks, including formatting.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| No lint feedback on edits | ktn-linter not running | Start with `ktn-linter serve` |
| `/lint` command fails | Binary not installed | Enable Go feature, rebuild container |
| MCP server missing from mcp.json | Binary not in PATH | Check `which ktn-linter` |
| Port conflict on 7717 | Another service using port | Set `KTN_LINTER_PORT=7718` |
| Stop hook timeout | Large session, slow scan | Check ktn-linter logs, consider `KTN_STOP_PHASES` scope-down |
| Hook scripts missing ktn-linter calls | Stale `kodflow-hooks` plugin version | Run `/update` to refresh the marketplace plugins |
