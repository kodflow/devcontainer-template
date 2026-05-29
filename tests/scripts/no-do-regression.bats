#!/usr/bin/env bats
# no-do-regression.bats — skills-cleanup (transverse, auto-progressive)
# WHY: GI1 — /do is removed (C2) and never comes back. Auto-detects phase:
# skips while do.md still exists (pre-C2), enforces once removed.

setup() { REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"; }

@test "TestDoCommandDoesNotComeBack" {
  cd "$REPO_ROOT"
  if [ -e .devcontainer/images/.claude/commands/do.md ]; then
    skip "/do not yet removed (pre-C2)"
  fi
  ! [ -d .devcontainer/images/.claude/commands/do ]
  run grep -RIn 'Skill(skill="do"' .devcontainer/images/.claude/commands/
  [ "$status" -ne 0 ]
}
