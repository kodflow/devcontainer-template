<!-- updated: 2026-02-23T12:00:00Z -->
# GitHub Actions Workflows

## Purpose

CI/CD automation for the devcontainer template.

## Workflows

| File | Description |
|------|-------------|
| `docker-images.yml` | Build and push devcontainer images |
| `release-please.yml` | Automated versioning, changelog, and asset publishing |

## docker-images.yml

- **Trigger**: Push to main, PRs, daily schedule (4AM UTC)
- **Registry**: ghcr.io
- **Tags**: latest, commit SHA
- **Platforms**: linux/amd64, linux/arm64
- **Cache busting**: Scheduled builds pass `CACHE_BUST_DYNAMIC=YYYY-MM-DD` to pull latest tool versions

## release-please.yml

- **Trigger**: Push to main
- **Job 1 (release-please)**: Creates/updates a release PR with changelog. On merge, creates a GitHub Release with a semver tag.
- **Job 2 (publish-assets)**: On new release, generates `claude-assets.tar.gz` and uploads it as a release asset.
- **Config**: `.release-please-config.json` + `.release-please-manifest.json`

## Conventions

- Use `ubuntu-latest` runners
- Cache Docker layers for speed
- Action SHAs pinned with version comments
- Use GITHUB_TOKEN for authentication
