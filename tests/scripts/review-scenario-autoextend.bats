#!/usr/bin/env bats
# review-scenario-autoextend.bats — skills-cleanup (transverse, auto-progressive)
# WHY: GI6 — /review auto-extension is OFF by default and never writes a scenario
# without an explicit flag + confirmation token. Skips until C8 lands it.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  REVIEW="$REPO_ROOT/.devcontainer/images/.claude/commands/review.md"
}

@test "TestAutoExtendOffByDefault" {
  grep -q 'REVIEW_SCENARIO_AUTOEXTEND' "$REVIEW" 2>/dev/null \
    || skip "auto-extension not yet implemented (pre-C8)"
  # OFF by default
  grep -qE 'AUTOEXTEND=0|default.*off|off.*default' "$REVIEW"
  # explicit activation flag + confirmation token gate documented
  grep -q -- '--extend-scenario' "$REVIEW"
  grep -qiE 'confirmation token|token .*present' "$REVIEW"
}
