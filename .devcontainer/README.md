# Development Container Configuration

This directory contains the configuration for the development container used with this project.

## Multi-Architecture Docker Images

The Docker images for this development container are automatically built for both `amd64` and `arm64` architectures and published to GitHub Container Registry (GHCR).

### Automatic Builds

GitHub Actions automatically builds and publishes multi-arch images when:
- Changes are pushed to the `main` branch affecting `.devcontainer/` files
- Pull requests are created with changes to `.devcontainer/` files
- Manual workflow dispatch is triggered

### Using Pre-built Images

By default, `docker-compose.yml` is configured to use the pre-built image from GHCR:

```yaml
image: ghcr.io/kodflow/devcontainer:latest
```

This provides several benefits:
- Faster container startup (no build required)
- Consistent environment across team members
- Automatic multi-architecture support (works on Apple Silicon and Intel/AMD)

### Building Locally

If you need to build the image locally (for testing or customization), you can:

1. Edit `.devcontainer/docker-compose.yml`
2. Comment out the `image:` line
3. Uncomment the `build:` section:

```yaml
# image: ghcr.io/kodflow/devcontainer:latest

build:
  context: .
  dockerfile: Dockerfile
  args:
    BUILDKIT_INLINE_CACHE: 1
```

## Environment Configuration

### 1Password Service Account

1. Copy the template file:
   ```bash
   cp .devcontainer/.env.example .devcontainer/.env
   ```

2. Edit `.devcontainer/.env` and add your 1Password service account token:
   ```bash
   OP_SERVICE_ACCOUNT_TOKEN="your-token-here"
   ```

3. The `.env` file is git-ignored and will not be committed

### Super Claude Alias

The container includes a `super-claude` alias that launches Claude Code with MCP support:

```bash
super-claude
```

This is equivalent to:
```bash
claude --dangerously-skip-permissions --mcp /home/vscode/.devcontainer/mcp.json
```

## Available Tags

The following image tags are available:

- `latest` - Latest build from the main branch
- `main` - Same as latest
- `main-<sha>` - Specific commit from main branch
- `pr-<number>` - Pull request builds (not pushed, build-only)

## Manual Image Pull

To manually pull the latest image:

```bash
docker pull ghcr.io/kodflow/devcontainer:latest
```

## Workflow File

The build workflow is defined in `.github/workflows/docker-build.yml` and uses:
- Docker Buildx for multi-architecture builds
- QEMU for cross-platform emulation
- GitHub Actions cache for faster builds
- GitHub Container Registry for image storage
