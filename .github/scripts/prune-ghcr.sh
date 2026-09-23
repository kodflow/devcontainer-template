#!/bin/bash
# Prune old versions of a GHCR container package without breaking a tag.
#
# Keep rule, in order:
#   1. every version younger than --keep-days (default 7);
#   2. the version tagged `latest`;
#   3. the --keep-last (default 3) most recent tagged versions, so a package
#      that stopped building is never emptied down to nothing;
#   4. every manifest those kept versions reference. A multi-arch tag points
#      to an index whose per-platform images and attestations are UNTAGGED
#      versions: deleting "untagged" blindly would break the tag itself.
# Everything else is deleted, oldest first, at most --max-delete per run:
# GitHub throttles mutating calls, so a large backlog drains over several runs.
#
# Dry run by default; --apply deletes. Needs GH_TOKEN (or GITHUB_TOKEN) with
# admin on the package: a workflow's own token has it for the packages that
# workflow publishes.
set -euo pipefail

owner="" package="" keep_days=7 keep_last=3 max_delete=400 apply=false
while [ $# -gt 0 ]; do
  case "$1" in
    --owner) owner="$2"; shift 2 ;;
    --package) package="$2"; shift 2 ;;
    --keep-days) keep_days="$2"; shift 2 ;;
    --keep-last) keep_last="$2"; shift 2 ;;
    --max-delete) max_delete="$2"; shift 2 ;;
    --apply) apply=true; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
[ -n "$owner" ] && [ -n "$package" ] || { echo "usage: $0 --owner O --package P [--keep-days N] [--keep-last N] [--max-delete N] [--apply]" >&2; exit 2; }
token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
[ -n "$token" ] || { echo "GH_TOKEN or GITHUB_TOKEN is required" >&2; exit 2; }

api="https://api.github.com"
enc=$(jq -rn --arg p "$package" '$p|@uri')
kind=$(curl -fsS -H "Authorization: Bearer $token" "$api/users/$owner" | jq -r '.type')
scope=$([ "$kind" = "Organization" ] && echo orgs || echo users)
base="$api/$scope/$owner/packages/container/$enc/versions"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# All versions, every page.
page=1
: > "$work/pages"
while :; do
  body=$(curl -fsS -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" "$base?per_page=100&page=$page")
  [ "$(jq 'length' <<<"$body")" -eq 0 ] && break
  echo "$body" >> "$work/pages"
  page=$((page + 1))
done
jq -s 'add // []' "$work/pages" > "$work/versions.json"
total=$(jq 'length' "$work/versions.json")

# Rules 1-3, decided on the listing alone.
jq --argjson days "$keep_days" --argjson last "$keep_last" '
  (now - $days * 86400) as $cutoff
  | ([.[] | select(.metadata.container.tags | length > 0)] | sort_by(.created_at) | reverse | .[:$last] | map(.id)) as $recent
  | [.[] | select(
      (.created_at | fromdateiso8601) >= $cutoff
      or (.metadata.container.tags | index("latest"))
      or (.id as $id | $recent | index($id))
    )]' "$work/versions.json" > "$work/kept.json"

jq -e 'any(.[]; .metadata.container.tags | index("latest"))' "$work/kept.json" >/dev/null ||
  jq -e 'all(.[]; (.metadata.container.tags | index("latest")) | not)' "$work/versions.json" >/dev/null ||
  { echo "refusing: the version tagged latest is not in the keep set" >&2; exit 1; }

# Rule 4: pull each kept manifest and keep every digest it references.
reg_token=$(curl -fsS -u "token:$token" "https://ghcr.io/token?scope=repository:$owner/$package:pull&service=ghcr.io" | jq -r '.token')
accept="application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json"
# Walk the whole reference graph (an index may nest indexes). Any manifest
# that cannot be read aborts the run: an incomplete keep set would delete the
# per-platform images of a tag we meant to keep.
jq -r '.[].name' "$work/kept.json" | sort -u > "$work/keep-digests"
cp "$work/keep-digests" "$work/queue"
while [ -s "$work/queue" ]; do
  : > "$work/next"
  while IFS= read -r digest; do
    manifest=$(curl -fsS -H "Authorization: Bearer $reg_token" -H "Accept: $accept" \
      "https://ghcr.io/v2/$owner/$package/manifests/$digest") ||
      { echo "refusing: cannot read manifest $digest" >&2; exit 1; }
    jq -r '(.manifests // [])[].digest' <<<"$manifest" >> "$work/next"
  done < "$work/queue"
  sort -u "$work/next" | comm -23 - "$work/keep-digests" > "$work/queue"
  sort -u "$work/keep-digests" "$work/queue" -o "$work/keep-digests"
done

jq --rawfile keep "$work/keep-digests" '
  ($keep | split("\n") | map(select(length > 0))) as $k
  | [.[] | select(.name as $n | $k | index($n) | not)] | sort_by(.created_at)' \
  "$work/versions.json" > "$work/delete.json"
to_delete=$(jq 'length' "$work/delete.json")
[ "$to_delete" -lt "$total" ] || { echo "refusing: the rule would delete every version" >&2; exit 1; }

echo "$owner/$package: $total versions, keep $((total - to_delete)), delete $to_delete (this run: at most $max_delete)"
if [ "$apply" != true ]; then
  jq -r '.[:10][] | "  would delete \(.created_at[:10]) \(.name[:19]) \(.metadata.container.tags | join(","))"' "$work/delete.json"
  exit 0
fi

deleted=0
while IFS= read -r id; do
  [ "$deleted" -ge "$max_delete" ] && break
  done_this=false
  for _ in 1 2 3; do
    code=$(curl -sS -o "$work/resp" -w '%{http_code}' -X DELETE -D "$work/headers" \
      -H "Authorization: Bearer $token" -H "Accept: application/vnd.github+json" "$base/$id")
    case "$code" in
      204|404) deleted=$((deleted + 1)); done_this=true; break ;;
      429) ;;
      403) grep -qi 'rate limit' "$work/resp" ||
             { echo "delete $id refused: $(cat "$work/resp")" >&2; exit 1; } ;;
      *) echo "delete $id failed: HTTP $code $(cat "$work/resp")" >&2; exit 1 ;;
    esac
    # Secondary rate limit: honour Retry-After, else back off a minute.
    wait=$(awk 'tolower($1)=="retry-after:"{print $2+0}' "$work/headers")
    sleep "${wait:-60}"
  done
  [ "$done_this" = true ] || { echo "delete $id still rate-limited after 3 attempts; stopping, the next run resumes" >&2; break; }
  sleep 2
done < <(jq -r '.[].id' "$work/delete.json")
echo "deleted $deleted of $to_delete"
