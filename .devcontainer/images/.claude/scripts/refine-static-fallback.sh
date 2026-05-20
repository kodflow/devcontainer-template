#!/usr/bin/env bash
# refine-static-fallback.sh — Skills Architecture v1.3 (PR3, fix #17)
#
# WHY: /refine's critical lenses must keep running even if route-agent.sh
# is broken (exit 20-31). This file pins agent + effort + criticality per
# lens so a router crash can't dark-fail the whole skill.

declare -A STATIC_LENS_MAP=(
  ["lens-1-correctness"]="developer-executor-correctness:xhigh:critical"
  ["lens-2-security"]="developer-executor-security:high"
  ["lens-3-edge-cases"]="developer-executor-correctness:high"
  ["lens-4-rollback"]="devops-executor-linux:medium"
  ["lens-5-testability"]="developer-executor-quality:high:critical"
  ["lens-6-dependency"]="devops-specialist-security:medium"
  ["lens-7-performance"]="developer-executor-design:high"
  ["lens-8-observability"]="developer-executor-shell:medium"
  ["lens-9-scope"]="developer-orchestrator:medium:critical"
  ["lens-10-goal-detect"]="developer-specialist-review:high:critical"
)

# Print a JSON dispatch entry for a given lens phase.
# Usage: refine_static_lens <lens-phase> [json|fields]
refine_static_lens() {
  local lens="$1"
  local format="${2:-json}"
  local entry="${STATIC_LENS_MAP[$lens]:-}"
  [[ -z "$entry" ]] && return 1
  local agent effort critical
  agent="${entry%%:*}"
  local rest="${entry#*:}"
  effort="${rest%%:*}"
  if [[ "$rest" == *:* ]]; then
    critical="${rest#*:}"
  else
    critical=""
  fi
  case "$format" in
    json)
      printf '{"subagent_type":"%s","resolved_model":"unknown","model_source":"static-fallback","effort":"%s","count":1,"matched_rule_id":"static:%s","fallback_used":true,"critical":%s,"expanded_from_template":false}\n' \
        "$agent" "$effort" "$lens" "$([[ "$critical" == "critical" ]] && echo true || echo false)"
      ;;
    fields)
      echo "$agent $effort $critical"
      ;;
  esac
}

# When sourced, expose the map and helper. When executed directly, dispatch.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  refine_static_lens "$@"
fi
