#!/usr/bin/env bats
# refine-v14-modes.bats — Skills Architecture v1.4
# WHY: lock the 3-mode contract (FULL / BARE / FROM-CONTRACT) so a
# future refactor can't silently re-couple the budget logic to a single
# input shape. The free-form-to-/goal path is the one users will reach
# for most often; it MUST keep working without a plan + context pair.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  REFINE_MD="$REPO_ROOT/.devcontainer/images/.claude/commands/refine.md"
  REFINE_DIR="$REPO_ROOT/.devcontainer/images/.claude/commands/refine"
  SYNTH="$REFINE_DIR/synthesis.md"
  RENDER="$REFINE_DIR/render.md"
  AUTO_MD="$REFINE_DIR/auto.md"
  DISPATCH="$REFINE_DIR/dispatch.md"
}

@test "TestRefineDeclaresThreeModes" {
  grep -q 'FULL' "$REFINE_MD"
  grep -q '\-\-bare' "$REFINE_MD"
  grep -q '\-\-from-contract' "$REFINE_MD"
}

@test "TestRefineBareFlagInArgumentsTable" {
  grep -qE '`--bare "<description>"`' "$REFINE_MD"
}

@test "TestRefineFromContractFlagInArgumentsTable" {
  grep -qE '`--from-contract <slug>`' "$REFINE_MD"
}

@test "TestRefineBareDefaultsToLightBudget" {
  # BARE default budget is 2000; --full-budget overrides
  grep -q '2000 chars by default' "$SYNTH"
  grep -q '\-\-full-budget' "$REFINE_MD"
}

@test "TestRefineFromContractUses4096Budget" {
  grep -q 'FROM-CONTRACT: 4096' "$SYNTH"
}

@test "TestRefineFromContractNeverOverwritesInput" {
  grep -q 'never overwritten' "$RENDER"
  grep -q 'contract_written.*false' "$SYNTH"
}

@test "TestRefineBareSkipsLensDispatch" {
  grep -q 'BARE.*skip' "$DISPATCH"
  grep -q 'no proof triplets' "$REFINE_MD"
}

@test "TestRefineBareAppliesWhatWhyWhereHowDoneTemplate" {
  grep -q 'WHAT/WHY/WHERE/HOW/DONE' "$REFINE_MD"
  grep -q 'WHAT  : ' "$SYNTH"
  grep -q 'WHY   : ' "$SYNTH"
  grep -q 'WHERE : ' "$SYNTH"
  grep -q 'HOW   : ' "$SYNTH"
  grep -q 'DONE  : ' "$SYNTH"
}

@test "TestRefineBareContractTemplateDeclared" {
  grep -q 'BARE contract template' "$RENDER"
  grep -q 'mode: BARE' "$RENDER"
}

@test "TestRefineAutoMdNotesBareSkipsIt" {
  grep -q 'FULL-mode only' "$AUTO_MD"
  grep -q '\-\-bare' "$AUTO_MD"
}

@test "TestRefineBareWorkflowAnswersStandaloneGoalQuestion" {
  # The whole point of --bare per the user's question: skip /plan + /search
  grep -q 'without going through /search and /plan' "$REFINE_MD"
}

@test "TestRefineBareDerivesSlugDeterministically" {
  grep -q 'derive_slug' "$RENDER"
  grep -q 'fix-race-in-worker-go' "$RENDER"
}

@test "TestRefineSlugFlagOverridesDerivation" {
  grep -qE '`--slug <name>`' "$REFINE_MD"
}

@test "TestRefineSynthesisPipelineDiffersPerMode" {
  # Single source of truth lives in synthesis.md; the per-mode pipeline
  # rows must be present so future refactors can't drop one.
  grep -q 'collect → dedup → rank → budget → render → compact' "$SYNTH"
  grep -q 'template → budget → render → compact' "$SYNTH"
  grep -q 'read → extract → budget → render → compact' "$SYNTH"
}

@test "TestRefineModeEnumExtendedInOutputSchema" {
  grep -q 'FULL_LIGHT|FULL|BARE|FROM_CONTRACT' "$SYNTH"
}
