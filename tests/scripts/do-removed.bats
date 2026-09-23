#!/usr/bin/env bats
# do-removed.bats — skills-cleanup C2
# WHY: GI1+GI2 — /do and the orphan goal-state subsystem are gone for good.

setup() { REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"; }

@test "TestDoCommandFileRemoved" {
  ! [ -e "$REPO_ROOT/.devcontainer/images/.claude/commands/do.md" ]
  ! [ -d "$REPO_ROOT/.devcontainer/images/.claude/commands/do" ]
}

@test "TestGoalStateScriptRemoved" {
  ! [ -e "$REPO_ROOT/.devcontainer/images/.claude/scripts/goal-state.sh" ]
}

@test "TestNoSkillDoInvocations" {
  cd "$REPO_ROOT"
  run grep -RIn 'Skill(skill="do"' .devcontainer/images/.claude/commands/
  [ "$status" -ne 0 ]
}

@test "TestNoGoalStateReferences" {
  cd "$REPO_ROOT"
  run bash -c "grep -RIn 'goal-state' .devcontainer/images/.claude/ | grep -vE 'CHANGELOG|historique'"
  [ "$status" -ne 0 ]
}

@test "TestInstallShDropsDo" {
  cd "$REPO_ROOT"
  ! grep -q 'do.md' .devcontainer/install.sh
  # skills are no longer downloaded one file at a time: the installer
  # registers the marketplace and installs the plugin that carries /refine.
  # The names live in one list now, so assert the list names it and that the
  # loop installs each name from the kodflow marketplace.
  grep -q 'KODFLOW_PLUGINS=.*kodflow-workflow' .devcontainer/install.sh
  grep -q 'plugin install "$p@kodflow"' .devcontainer/install.sh
}
