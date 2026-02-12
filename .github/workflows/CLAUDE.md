<!-- updated: 2026-02-12T17:00:00Z -->
# GitHub Actions Workflows

## Purpose

CI/CD automation for the devcontainer template.

## Workflows

| File | Description |
|------|-------------|
| `docker-images.yml` | Build and push devcontainer images |

## docker-images.yml

- **Trigger**: Push to main, PRs, daily schedule (4AM UTC)
- **Registry**: ghcr.io
- **Tags**: latest, commit SHA
- **Platforms**: linux/amd64, linux/arm64
- **Cache busting**: Scheduled builds pass `CACHE_BUST_DYNAMIC=YYYY-MM-DD` to pull latest tool versions

## Conventions

- Use `ubuntu-latest` runners
- Cache Docker layers for speed
- Action SHAs pinned with version comments
- Use GITHUB_TOKEN for authentication
