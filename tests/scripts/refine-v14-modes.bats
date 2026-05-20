#!/usr/bin/env bats
# refine-v14-modes.bats — Skills Architecture v1.5
# WHY: lock the 3-mode contract (FULL / BARE / FROM-CONTRACT) plus the
# uniform 4000-char target and auto-detection from disk state. The
# free-form-to-/goal path is the one users will reach for most often;
# it MUST keep working without a plan + context pair and without an
# explicit --bare flag.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  REFINE_MD="$REPO_ROOT/.devcontainer/images/.claude/commands/refine.md"
  REFINE_DIR="$REPO_ROOT/.devcontainer/images/.claude/commands/refine"
  SYNTH="$REFINE_DIR/synthesis.md"
  RENDER="$REFINE_DIR/render.md"
  AUTO_MD="$REFINE_DIR/auto.md"
  DISPATCH="$REFINE_DIR/dispatch.md"
}

# -- Mode declaration -----------------------------------------------------

@test "TestRefineDeclaresThreeModes" {
  grep -q 'FULL' "$REFINE_MD"
  grep -q '\-\-bare' "$REFINE_MD"
  grep -q '\-\-from-contract' "$REFINE_MD"
}

@test "TestRefineBareFlagInArgumentsTable" {
  grep -q '`--bare`' "$REFINE_MD"
}

@test "TestRefineFromContractFlagInArgumentsTable" {
  grep -qE '`--from-contract <slug>`' "$REFINE_MD"
}

# -- Single 4000-char target ----------------------------------------------

@test "TestRefineTargets4000Always" {
  # Single rule, all modes
  grep -q 'targets 4000 chars' "$REFINE_MD"
  grep -q 'target = 4000 chars' "$SYNTH"
}

@test "TestRefineNoDualBudget" {
  # No leftover LIGHT-budget split (would be a v1.4 regression)
  ! grep -E 'LIGHT.*2000|2000.*LIGHT|--full-budget' "$REFINE_MD"
  ! grep -E '2000 chars by default|4096' "$SYNTH"
  ! grep -E '4096' "$RENDER"
  ! grep -E '4096' "$AUTO_MD"
  ! grep -E '4096' "$DISPATCH"
}

@test "TestRefineSchemaUses4000Target" {
  grep -q '"directive_char_target": 4000' "$SYNTH"
  grep -q '"directive": "<≤4000 chars>"' "$SYNTH"
}

@test "TestRefineAllowsShorterOutput" {
  # WHY: 4000 is the target ceiling, not a floor — natural shorter is fine
  grep -q 'never pads to hit 4000' "$SYNTH"
  grep -q 'natural output may be shorter' "$SYNTH" \
    || grep -q 'Natural output may be shorter' "$RENDER" \
    || grep -q 'output may be shorter' "$REFINE_MD"
}

# -- Auto-detection -------------------------------------------------------

@test "TestRefineAutoDetectsBareFromSpaces" {
  grep -q 'contains spaces' "$REFINE_MD"
  grep -q 'BARE (free-form description)' "$REFINE_MD"
}

@test "TestRefineAutoDetectsFullFromExistingFiles" {
  grep -q 'plans/<arg>.md + contexts/<arg>.md both exist' "$REFINE_MD"
  grep -qE '→ +FULL' "$REFINE_MD"
}

@test "TestRefineAutoDetectsFromContractWhenOnlyGoalExists" {
  grep -q 'goals/<arg>.md exists, no plan/context' "$REFINE_MD"
  grep -qE '→ +FROM-CONTRACT' "$REFINE_MD"
}

@test "TestRefineFlagsAreOverridesNotPrimary" {
  grep -q 'Explicit overrides for the edge cases' "$REFINE_MD"
  grep -q 'override the default detection' "$REFINE_MD"
}

# -- BARE pipeline --------------------------------------------------------

@test "TestRefineBareSkipsLensDispatch" {
  grep -q 'BARE.*skip\|skip.*BARE' "$DISPATCH"
  grep -q 'no proof triplets' "$RENDER"
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

# -- FROM-CONTRACT pipeline -----------------------------------------------

@test "TestRefineFromContractNeverOverwritesInput" {
  grep -q 'never overwritten' "$RENDER"
  grep -q 'contract_written.*false' "$SYNTH"
}

# -- AUTO lens depth (independent of char-cap) ----------------------------

@test "TestRefineAutoControlsOnlyLensDepth" {
  grep -q 'AUTO mode controls .*lens depth only' "$AUTO_MD"
  grep -q 'does NOT control the char-cap' "$AUTO_MD"
}

# -- Slug derivation ------------------------------------------------------

@test "TestRefineBareDerivesSlugDeterministically" {
  grep -q 'derive_slug' "$RENDER"
  grep -q 'fix-race-in-worker-go' "$RENDER"
}

@test "TestRefineSlugFlagOverridesDerivation" {
  grep -qE '`--slug <name>`' "$REFINE_MD"
}

# -- Synthesis pipeline integrity -----------------------------------------

@test "TestRefineSynthesisPipelineDiffersPerMode" {
  grep -q 'collect → dedup → rank → render → compact-to-4000' "$SYNTH"
  grep -q 'template → render → compact-to-4000' "$SYNTH"
  grep -q 'read → extract → render → compact-to-4000' "$SYNTH"
}

@test "TestRefineModeEnumInOutputSchema" {
  grep -q 'FULL|BARE|FROM_CONTRACT' "$SYNTH"
}

# -- Workflow narrative ---------------------------------------------------

@test "TestRefineQuickWorkflowSkipsPlanAndSearch" {
  # The whole point of auto-BARE per the user's question
  grep -q '/refine "fix race in worker.go pool init"' "$REFINE_MD"
  grep -q 'No explicit mode flag needed' "$REFINE_MD"
}
