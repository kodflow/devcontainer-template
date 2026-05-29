#!/usr/bin/env bats
# no-grepai-prescription.bats — skills-cleanup C1
# WHY: grepai/ollama dropped 2026-04. No command file may PRESCRIBE it as a tool
# (case-insensitive — "GrepAI" capitalised slipped past an earlier case-sensitive grep).
# Allowlist: update/apply.md (migration note) + audit.md (absence-check).

setup() { REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"; }

@test "TestNoGrepaiPrescriptionInCommands" {
  cd "$REPO_ROOT"
  local hits
  hits=$(grep -RIli grepai .devcontainer/images/.claude/commands/ 2>/dev/null \
         | grep -vE 'update/apply.md|audit.md' || true)
  [ -z "$hits" ] || { echo "grepai still prescribed in:"; echo "$hits"; return 1; }
}

@test "TestNoGrepaiInMcpFirstRule" {
  cd "$REPO_ROOT"
  ! grep -iq grepai .claude/rules/mcp-first.md
}
