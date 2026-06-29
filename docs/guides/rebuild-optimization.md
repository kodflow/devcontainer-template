# Rebuild-time optimization (Q5)

The devcontainer "rebuild" costs ~3h. The keystone insight from the
challenge-setup-2026 audit: **the time is not in `docker build` — it is in the
per-language `features/languages/<lang>/install.sh` scripts running at
container-create, with no Docker layer cache.** Stop building toolchains on the
developer's machine and the problem collapses.

This guide is the phased plan. Items marked ✅ landed in the `feat/review-v2-brutal`
branch; the rest are sequenced follow-ups.

## Phase 1 — Keystone: prebuilt GHCR image (biggest win)

`docker-images.yml` already builds + pushes the full image to
`ghcr.io/kodflow/devcontainer-template:latest`. Reference it from
`docker-compose.yml` instead of building locally:

```yaml
services:
  devcontainer:
    image: ghcr.io/kodflow/devcontainer-template:latest   # pull, don't build
    build:                                                  # fallback for --build
      context: .
      dockerfile: Dockerfile
      pull: true
```

A rebuild becomes a `docker pull` of cached layers: **~3h → minutes.** Shipped
**commented** today (zero behaviour change); flip once the GHCR publish is green
for your platforms. See [ADR 0001](../adr/0001-prebuilt-ghcr-devcontainer-image.md).

## Phase 0 — Quick wins (de-risk the CI build)

- ✅ **Dart shallow clone + idempotence** — `dart-flutter/install.sh` re-cloned the
  full Flutter history every create (~4–8 min). Now `--depth 1` + skip when the
  SDK is already present.
- **Feed `GITHUB_TOKEN` to feature installs** — unauthenticated GitHub API calls
  hit the 60 req/h limit, cascading to slow source compiles. Pass a token at
  build/create time (BuildKit secret or `containerEnv`) so
  `get_github_latest_version` authenticates (5000 req/h). Never bake the token.
- ✅ **Provision dead gates** (govulncheck, miri) so agents don't fetch them ad hoc.
- **Persist toolchain caches** across rebuilds via the existing named volumes
  (`package-cache`, cargo/go cache dirs already point under `~/.cache`).

## Phase 2 — BuildKit caches (incremental CI builds)

In `docker-images.yml`, export/import a registry cache (NOT `type=gha` — its
~10 GB cap is blown by 26 languages):

```
--cache-to   type=registry,ref=ghcr.io/kodflow/devcontainer-template:buildcache,mode=max
--cache-from type=registry,ref=ghcr.io/kodflow/devcontainer-template:buildcache
```

For toolchains compiled in-image, add cache mounts (own the uid so installed
binaries still land in the real layer — never mount all of `CARGO_HOME`/`GOPATH`):

```dockerfile
RUN --mount=type=cache,target=/home/vscode/.cache/cargo/registry,uid=1000,gid=1000 \
    --mount=type=cache,target=/root/.cache/go-build,uid=1000,gid=1000 \
    ...
```

## Phase 3 — `mise` for runtime toolchains (follow-up)

Replace ~14 bespoke runtime `install.sh` with [`mise`](https://mise.jdx.dev)
(precompiled, cached, ~2–7× faster than asdf). Persist `MISE_DATA_DIR` /
`MISE_CACHE_DIR`. Keep the ~11 system compilers (gcc, gfortran, GnuCOBOL…) on
apt — mise does not manage those. Larger surface change; sequence after Phase 1.

## Explicitly out of scope (overkill / category errors)

- **Calico** — a Kubernetes CNI; nothing to do with build speed. (Named in the
  original ask; clarified here.)
- **Lazy-pull snapshotters** (eStargz / SOCI / nydus) — high operational
  complexity for marginal gain at this scale.
- **cargo-chef** — app-level dependency caching, not relevant to a base image.
- **proto / asdf** — no advantage over `mise`.

## Expected impact (ordered)

1. Phase 1 (prebuilt image) — collapses the 3h. Do this first.
2. Phase 0 quick wins — de-risk and speed the CI build that Phase 1 depends on.
3. Phase 2 (registry cache) — fast *incremental* CI image builds.
4. Phase 3 (mise) — structural simplification + faster cold toolchain installs.
