#!/usr/bin/env bats
# path-escape-denied.bats — skills-cleanup (transverse, auto-progressive)
# WHY: GI7 — /review writes are bounded to authorised dirs (anti path-traversal).
# Skips until the review scenario registry exists (pre-C7).

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SCEN="$REPO_ROOT/.devcontainer/images/.claude/commands/review/scenarios"
}

@test "TestReviewScenariosDirIsBounded" {
  [ -d "$SCEN" ] || skip "review scenarios not yet implemented (pre-C7)"
  # The scenario contract must declare a writes: path under an authorised dir.
  run bash -c "grep -RIhE 'writes:' '$SCEN' | grep -vE '\.claude/(plans|goals|contexts)/|review/scenarios/'"
  [ "$status" -ne 0 ]
}
