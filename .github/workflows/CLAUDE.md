# GitHub Actions Workflows

## Purpose

CI/CD automation for the devcontainer template.

## Workflows

| File | Description |
|------|-------------|
| `docker-images.yml` | Build and push devcontainer images |

## docker-images.yml

- **Trigger**: Push to main, PRs
- **Registry**: ghcr.io
- **Tags**: latest, commit SHA

## Conventions

- Use `ubuntu-latest` runners
- Cache Docker layers for speed
- Run tests before pushing images
- Use GITHUB_TOKEN for authentication
