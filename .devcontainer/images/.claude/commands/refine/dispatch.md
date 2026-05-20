# refine/dispatch.md — Skills Architecture v1.4 (PR3, fix #17)

> **v1.4 note:** this phase is FULL-mode only. `--bare` and
> `--from-contract` skip lens dispatch entirely — they jump straight to
> the synthesis pipeline (which itself adapts to the mode). The
> single-source-of-truth budget logic in `synthesis.md` is what BARE and
> FROM-CONTRACT reuse without reimplementing it.


## Lenses (10)

| Phase | Critical? | Default agent | Effort |
|---|---|---|---|
| `lens-1-correctness`  | yes | developer-executor-correctness   | xhigh  |
| `lens-2-security`     |     | developer-executor-security      | high   |
| `lens-3-edge-cases`   |     | developer-executor-correctness   | high   |
| `lens-4-rollback`     |     | devops-executor-linux            | medium |
| `lens-5-testability`  | yes | developer-executor-quality       | high   |
| `lens-6-dependency`   |     | devops-specialist-security       | medium |
| `lens-7-performance`  |     | developer-executor-design        | high   |
| `lens-8-observability`|     | developer-executor-shell         | medium |
| `lens-9-scope`        | yes | developer-orchestrator           | medium |
| `lens-10-goal-detect` | yes | developer-specialist-review      | high   |

LIGHT mode runs only critical lenses (1, 5, 9, 10). FULL mode runs all 10.

## Dispatch sequence

```bash
# 1. Try router
ROUTER=~/.claude/scripts/route-agent.sh
DISPATCH=$(bash "$ROUTER" --skill /refine --phase "$LENS" --profile "$PROFILE")
RC=$?

# 2. Router exit 0 or 10 → use returned dispatch JSON
# 3. Router exit 20-31 → static fallback (fix #17)
if [ "$RC" -ge 20 ] && [ "$RC" -le 31 ]; then
  source ~/.claude/scripts/refine-static-fallback.sh
  DISPATCH=$(refine_static_lens "$LENS")
  [ -z "$DISPATCH" ] && {
    # Drop lens; annotate telemetry
    echo "{\"lens\":\"$LENS\",\"dropped\":true}" >> ~/.claude/logs/refine-dropped-lenses.jsonl
    continue
  }
fi

# 4. Hand off to actual agent invocation (Task or Agent primitive)
```

## Router-independence invariant

Critical lenses (1, 5, 9, 10) MUST reach the agent invocation step even
when `route-agent.sh` returns exit 20-31. This is enforced by the static
fallback above and verified by `TestRefineFallsBackToStaticWhenRouterErrors`.
