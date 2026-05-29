#!/usr/bin/env bats
# no-goal-state-regression.bats — skills-cleanup (transverse, auto-progressive)
# WHY: GI2 — goal-state.sh + the runtime state subsystem are removed (C2),
# never return. The contract file .claude/goals/<slug>.md is KEPT (GI9).
# Auto-detects: skips while goal-state.sh exists (pre-C2), enforces once removed.

setup() { REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"; }

@test "TestGoalStateSubsystemStaysRemoved" {
  cd "$REPO_ROOT"
  if [ -e .devcontainer/images/.claude/scripts/goal-state.sh ]; then
    skip "goal-state.sh not yet removed (pre-C2)"
  fi
  run bash -c "grep -RIn 'goal-state' .devcontainer/images/.claude/ | grep -vE 'CHANGELOG|historique'"
  [ "$status" -ne 0 ]
}
