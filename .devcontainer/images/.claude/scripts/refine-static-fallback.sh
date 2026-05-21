#!/usr/bin/env bash
# refine-static-fallback.sh — Skills Architecture v1.5 (PR3, fix #17)
#
# WHY: /refine's critical lenses must keep running even if route-agent.sh
# is broken (exit 20-31). This file pins agent + effort + criticality per
# lens so a router crash can't dark-fail the whole skill.
#
# WHY a case statement and not an associative array: bats sources this
# file in a subshell that occasionally inherits STATIC_LENS_MAP as a
# regular indexed array from a prior context. Bash then treats
# `${STATIC_LENS_MAP[$lens]}` as arithmetic expansion on the string
# "lens-1-correctness" — the dashes look like subtraction and recursive
# variable evaluation triggers `expression recursion level exceeded`.
# A case statement is type-safe, faster, and immune to that bug.

# Print a JSON dispatch entry for a given lens phase.
# Usage: refine_static_lens <lens-phase> [json|fields]
refine_static_lens() {
  local lens="$1"
  local format="${2:-json}"
  local agent="" effort="" critical=""
  case "$lens" in
    lens-1-correctness)    agent="developer-executor-correctness"; effort="xhigh"; critical="critical" ;;
    lens-2-security)       agent="developer-executor-security";    effort="high"  ;;
    lens-3-edge-cases)     agent="developer-executor-correctness"; effort="high"  ;;
    lens-4-rollback)       agent="devops-executor-linux";          effort="medium" ;;
    lens-5-testability)    agent="developer-executor-quality";     effort="high"; critical="critical" ;;
    lens-6-dependency)     agent="devops-specialist-security";     effort="medium" ;;
    lens-7-performance)    agent="developer-executor-design";      effort="high"  ;;
    lens-8-observability)  agent="developer-executor-shell";       effort="medium" ;;
    lens-9-scope)          agent="developer-orchestrator";         effort="medium"; critical="critical" ;;
    lens-10-goal-detect)   agent="developer-specialist-review";    effort="high"; critical="critical" ;;
    *) return 1 ;;
  esac
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

# When sourced, expose the function. When executed directly, dispatch.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  refine_static_lens "$@"
fi
