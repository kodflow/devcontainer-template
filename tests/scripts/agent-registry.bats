#!/usr/bin/env bats
# agent-registry.bats — anti-drift guard for agents/registry.json
# WHY: registry.json carried a stale model_distribution (summed to 81 while 86
# agent files exist on disk) — challenge-setup-2026 audit, Q1. These tests
# recompute the counts from the agent frontmatter on disk and assert the
# registry matches, so any future add/remove/model-change that forgets to
# update registry.json fails CI instead of silently drifting.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  AGENTS="$REPO_ROOT/.devcontainer/images/.claude/agents"
  REGISTRY="$AGENTS/registry.json"
}

# Count agent .md files on disk (registry.json is JSON, not .md, so excluded).
disk_total() { ls "$AGENTS"/*.md 2>/dev/null | wc -l | tr -d ' '; }

# Count agents on disk whose frontmatter declares a given model.
disk_model_count() {
  local model="$1" n=0 f
  for f in "$AGENTS"/*.md; do
    awk -F': *' '/^model:/{gsub(/[ \t"]/,"",$2); print tolower($2); exit}' "$f" \
      | grep -qx "$model" && n=$((n + 1))
  done
  echo "$n"
}

reg() { jq -r "$1" "$REGISTRY"; }

@test "registry.json is valid JSON" {
  jq -e . "$REGISTRY" >/dev/null
}

@test "every agent .md declares a valid model" {
  local f bad=0
  for f in "$AGENTS"/*.md; do
    awk '/^---$/{c++; next} c==1{print}' "$f" \
      | grep -qE '^model: (haiku|sonnet|opus)' || { echo "missing/invalid model: $f"; bad=1; }
  done
  [ "$bad" -eq 0 ]
}

@test "total_agents matches the number of agent files on disk" {
  [ "$(reg '.total_agents')" -eq "$(disk_total)" ]
}

@test "model_distribution sums to total_agents" {
  [ "$(reg '[.model_distribution[]] | add')" -eq "$(reg '.total_agents')" ]
}

@test "model_distribution matches the on-disk frontmatter counts" {
  [ "$(reg '.model_distribution.opus   // 0')" -eq "$(disk_model_count opus)" ]
  [ "$(reg '.model_distribution.sonnet // 0')" -eq "$(disk_model_count sonnet)" ]
  [ "$(reg '.model_distribution.haiku  // 0')" -eq "$(disk_model_count haiku)" ]
}

@test "category counts sum to total_agents" {
  [ "$(reg '[.categories[].count] | add')" -eq "$(reg '.total_agents')" ]
}
