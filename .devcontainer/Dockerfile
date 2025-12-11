# Kodflow Development Container
# Uses pre-built base image from GHCR (includes all tools + Claude Code)
# Languages are added via devcontainer features as needed

FROM ghcr.io/kodflow/devcontainer:latest

# Copy p10k configuration
COPY --chown=vscode:vscode hooks/shared/.p10k.zsh /home/vscode/.p10k.zsh

WORKDIR /workspace
