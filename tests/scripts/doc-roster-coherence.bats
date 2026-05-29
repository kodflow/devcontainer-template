#!/usr/bin/env bats
# doc-roster-coherence.bats — skills-cleanup C1
# WHY: deleted skills (/prompt) must not linger in live skill-roster tables.
# Migration/redirect mentions are legitimate (documentation-of-removal).

setup() { REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"; }

@test "TestNoPromptRowInLiveRosters" {
  cd "$REPO_ROOT"
  ! grep -RIn '/prompt' \
      CLAUDE.md \
      .devcontainer/images/.claude/CLAUDE.md \
      .devcontainer/images/CLAUDE.md \
      docs/commands/README.md \
    | grep -vE 'use /refine|migration'
}
