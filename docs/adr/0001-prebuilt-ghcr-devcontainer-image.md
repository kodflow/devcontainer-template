# 0001. Prebuilt GHCR image to collapse devcontainer rebuild time

- Status: Accepted
- Date: 2026-06-29
- Deciders: kodflow
- Related: challenge-setup-2026 audit (Q5), `docs/guides/rebuild-optimization.md`,
  `.github/workflows/docker-images.yml`, `.devcontainer/docker-compose.yml`

## Context

A full devcontainer rebuild takes ~3 hours, dominated not by `docker build` but
by the per-language `features/languages/<lang>/install.sh` scripts executing at
container-create on the developer's machine — there is no Docker layer cache for
that work, so every rebuild recompiles/redownloads toolchains. The pain spikes
when an agent needs a toolchain (Rust, etc.) on demand.

`docker-images.yml` already builds and pushes the complete image to
`ghcr.io/kodflow/devcontainer-template:latest`, but `docker-compose.yml` uses a
local `build:` stanza, so consumers rebuild from scratch instead of pulling the
prebuilt layers.

## Decision

We will make the prebuilt GHCR image the primary source for the devcontainer,
referencing it via `image:` in `docker-compose.yml`, with the local `build:`
retained as a fallback (`docker compose build`). A rebuild then collapses to a
`docker pull` of cached layers (~3h → minutes).

Rollout is staged to avoid breaking consumers:
1. (this change) Ship the `image:` line **commented** in `docker-compose.yml`
   with a pointer here — zero behaviour change, one uncomment away.
2. Confirm `docker-images.yml` publishes green for the targeted platform(s)
   (amd64 + arm64).
3. Uncomment `image:` and verify a clean machine pulls instead of builds.

## Options considered

1. **Prebuilt GHCR image referenced by `image:` (chosen)** — biggest win for the
   least change; the publish pipeline already exists. Build moves off the
   developer's machine to CI.
2. **`mise` to replace ~14 runtime `install.sh`** — real speedup (precompiled,
   cached toolchains) but larger surface change; complementary, not a substitute.
   Tracked in the rebuild-optimization guide as a follow-up.
3. **Lazy-pull snapshotters (eStargz/SOCI/nydus)** — overkill for this scale;
   high operational complexity for marginal gain. Rejected.
4. **Status quo (local `build:`)** — the ~3h problem. Rejected.

## Consequences

- Positive: rebuilds become pulls; on-demand toolchain availability is near-
  instant after first pull; build cost centralizes in CI where it is cached.
- Negative / cost: consumers must authenticate to GHCR to pull; the published
  image must stay current (already the daily/weekly cadence); local
  source-change iteration uses `docker compose build` explicitly.
- Follow-ups: BuildKit registry cache (`--cache-to type=registry,mode=max`) in
  CI for incremental image builds; quick-win install.sh fixes (Dart shallow
  clone — done; `GITHUB_TOKEN` to feature installs); evaluate `mise`. See the
  guide.
