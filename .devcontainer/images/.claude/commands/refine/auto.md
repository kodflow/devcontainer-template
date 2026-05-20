# refine/auto.md — Skills Architecture v1.3 (PR3, fix #3, #4, #14, #15)

## Decision tree

```bash
# Source the frontmatter helper (handles .md-with-YAML correctly)
source ~/.claude/scripts/frontmatter.sh

auto_select_mode() {
  local plan_path="$1"

  # WHY: read frontmatter via helper, never `yq` on the full .md file.
  local risk loc pub_api sec devinf
  risk=$(frontmatter_get "$plan_path" '.risk // "missing"')
  loc=$(frontmatter_get "$plan_path" '.loc_estimate_max // -1')
  pub_api=$(frontmatter_get "$plan_path" '.touches_public_api // "missing"')
  sec=$(frontmatter_get "$plan_path" '.touches_security_surface // "missing"')
  devinf=$(frontmatter_get "$plan_path" '.touches_dev_infra // "missing"')

  # Missing / non-numeric metadata → FULL (safe default per fix #4)
  for field in "$risk" "$pub_api" "$sec" "$devinf"; do
    [ "$field" = "missing" ] && { echo "FULL"; return; }
  done
  case "$loc" in
    ''|*[!0-9]*) echo "FULL"; return ;;
  esac

  # LIGHT criteria: ALL must hold
  #   loc_estimate_max ≤ 500  (500 = LIGHT, 501 = FULL)
  #   risk ∈ {low, medium}
  #   touches_public_api == false
  #   touches_security_surface == false
  #   touches_dev_infra == false
  if [ "$loc" -le 500 ] \
     && { [ "$risk" = "low" ] || [ "$risk" = "medium" ]; } \
     && [ "$pub_api" = "false" ] \
     && [ "$sec" = "false" ] \
     && [ "$devinf" = "false" ]; then
    echo "LIGHT"
  else
    echo "FULL"
  fi
}
```

## Boundaries (locked by tests)

| `loc_estimate_max` | `risk` | `touches_*` | Mode |
|---|---|---|---|
| `≤ 500` | `low`/`medium` | all `false` | **LIGHT** |
| `501+` | any | any | **FULL** |
| any | `high`/`critical` | any | **FULL** |
| any | any | any `true` | **FULL** |
| missing | any | any | **FULL** |
| non-numeric | any | any | **FULL** |
