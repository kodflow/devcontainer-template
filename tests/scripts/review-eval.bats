#!/usr/bin/env bats
# review-eval.bats — CI guard for the /review trust anchor.
# WHY: review-eval.sh is the regression harness that proves the non-LLM verifier
# still INVALIDATES fake-pass manifests and the canary still detects its seeded
# defect. If the gate rots (a refactor stops failing bad manifests), the harness
# exits nonzero and this test goes red — the rot can no longer ship green.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  EVAL="$REPO_ROOT/.devcontainer/images/.claude/scripts/review-eval.sh"
}

@test "TestReviewEvalHarnessAllCasesPass" {
  [ -f "$EVAL" ] || skip "review-eval.sh not present"
  run bash "$EVAL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"EVAL: PASS"* ]]
}
