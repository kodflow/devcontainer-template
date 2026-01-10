# syntax=docker/dockerfile:1.4
# hadolint global ignore=DL3008
# =============================================================================
# Base Development Image
# =============================================================================
# Single base image with all tools + Claude Code (standalone)
# Languages (including Node.js) are added via devcontainer features at runtime
#
# Build:
#   docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/kodflow/devcontainer-template:latest .
# =============================================================================

# Base image uses tagged version for multi-arch support (amd64/arm64)
# Note: Digest pinning not used as it would require platform-specific digests
# The devcontainers base images are published by Microsoft with regular security updates
ARG BASE_IMAGE=mcr.microsoft.com/devcontainers/base:ubuntu-24.04
# hadolint ignore=DL3006
FROM ${BASE_IMAGE}

ARG TARGETARCH
ARG BUILDKIT_INLINE_CACHE=1

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# =============================================================================
# System Dependencies
# =============================================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl ca-certificates gnupg gnupg2 lsb-release \
        build-essential g++ gcc make cmake pkg-config \
        git jq yq zsh unzip zip tar xz-utils file \
        libssl-dev libpam0g-dev software-properties-common apt-transport-https \
        libffi-dev libbz2-dev libreadline-dev libsqlite3-dev \
        libncurses5-dev libncursesw5-dev liblzma-dev zlib1g-dev \
        libgdbm-dev libyaml-dev \
        libsecret-1-0 libsecret-1-dev dbus-x11 gnome-keyring \
        taskwarrior shellcheck && \
    apt-get clean

# =============================================================================
# HashiCorp Tools (Terraform, Vault, Consul, Nomad, Packer)
# =============================================================================
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y --no-install-recommends terraform vault consul nomad packer terraform-ls && \
    rm -rf /var/lib/apt/lists/*

# =============================================================================
# Cloud CLIs (AWS, GCP, Azure)
# =============================================================================
# AWS CLI v2
RUN ARCH_AWS=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") && \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_AWS}.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscliv2.zip

# Google Cloud SDK
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && apt-get install -y --no-install-recommends google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin && \
    rm -rf /var/lib/apt/lists/*

# Azure CLI
RUN curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash

# GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y --no-install-recommends gh && \
    rm -rf /var/lib/apt/lists/*

# =============================================================================
# Kubernetes Tools (kubectl, Helm)
# =============================================================================
ARG KUBECTL_VERSION=1.35.0
ARG HELM_VERSION=4.0.4

RUN ARCH_K8S=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH_K8S}/kubectl" -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${ARCH_K8S}.tar.gz" | tar xz -C /tmp && \
    mv /tmp/linux-${ARCH_K8S}/helm /usr/local/bin/helm && \
    rm -rf /tmp/linux-${ARCH_K8S}

# =============================================================================
# Ansible
# =============================================================================
RUN add-apt-repository --yes --update ppa:ansible/ansible && \
    apt-get install -y --no-install-recommends ansible && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 1Password CLI (op) - For secrets management
# =============================================================================
RUN curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" > /etc/apt/sources.list.d/1password.list && \
    mkdir -p /etc/debsig/policies/AC2D62742012EA22/ && \
    curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol -o /etc/debsig/policies/AC2D62742012EA22/1password.pol && \
    mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 && \
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc | gpg --dearmor -o /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg && \
    apt-get update && apt-get install -y --no-install-recommends 1password-cli && \
    rm -rf /var/lib/apt/lists/*

# =============================================================================
# Bazelisk (Bazel version manager)
# Pinned version for supply-chain security
# =============================================================================
ARG BAZELISK_VERSION=1.27.0
RUN ARCH_BAZEL=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/bazelbuild/bazelisk/releases/download/v${BAZELISK_VERSION}/bazelisk-linux-${ARCH_BAZEL}" -o /usr/local/bin/bazel && \
    chmod +x /usr/local/bin/bazel

# =============================================================================
# User Setup
# =============================================================================
USER vscode
WORKDIR /home/vscode

# Create cache and config directories
# Note: .config/op must exist with correct ownership for 1Password CLI (requires 700 perms)
RUN mkdir -p .cache .config .local/bin .local/share .zsh_history_dir \
    .cache/{terraform,helm,aws,bazel} \
    .config/{aws,gcloud,azure,op} .kube \
    .claude .config/@anthropic .cache/@anthropic .local/share/@anthropic

# Oh My Zsh + Powerlevel10k (force fresh install to ensure completeness)
RUN rm -rf ~/.oh-my-zsh && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

# Copy p10k configuration
COPY --chown=vscode:vscode .p10k.zsh /home/vscode/.p10k.zsh

# Configure zsh
RUN sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc && \
    sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc && \
    printf '\n[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh\nexport HISTFILE=~/.zsh_history_dir/.zsh_history\nexport HISTSIZE=50000\nexport SAVEHIST=50000\n[[ -f ~/.devcontainer-env.sh ]] && source ~/.devcontainer-env.sh\n' >> ~/.zshrc

# =============================================================================
# Claude Code (standalone installation - no Node.js required)
# =============================================================================
# Using official installer: https://claude.ai/install.sh
# This avoids requiring Node.js/npm in the base image.
# If you need Node.js for your project, enable the "nodejs" feature.
# Note: The official installer creates the symlink at ~/.local/bin/claude automatically.
#
# CACHE_BUST_DYNAMIC: Forces cache invalidation for dynamic installations.
# Set to current date (YYYY-MM-DD) during scheduled builds to pull latest versions.
# See: https://docs.docker.com/build/cache/invalidation/
ARG CACHE_BUST_DYNAMIC=stable
RUN curl -fsSL https://claude.ai/install.sh | bash

# =============================================================================
# CodeRabbit CLI (AI Code Reviews)
# =============================================================================
# Also affected by CACHE_BUST_DYNAMIC for scheduled updates
RUN curl -fsSL https://cli.coderabbit.ai/install.sh | sh

# =============================================================================
# Claude Configuration (backup to /etc/claude-defaults/ for volume restoration)
# =============================================================================
COPY --chown=vscode:vscode .claude/ /home/vscode/.claude/
RUN chmod -R 755 /home/vscode/.claude/scripts/ && \
    mkdir -p /home/vscode/.claude/sessions

# =============================================================================
# Claude Defaults Backup (for volume restoration)
# =============================================================================
USER root
RUN mkdir -p /etc/claude-defaults
COPY --chown=root:root .claude/commands/ /etc/claude-defaults/commands/
COPY --chown=root:root .claude/scripts/ /etc/claude-defaults/scripts/
COPY --chown=root:root .claude/agents/ /etc/claude-defaults/agents/
COPY --chown=root:root .claude/settings.json /etc/claude-defaults/settings.json
RUN chmod -R 755 /etc/claude-defaults/
USER vscode

# =============================================================================
# MCP Template (secrets injected at runtime via postStart.sh)
# =============================================================================
USER root
RUN mkdir -p /etc/mcp
COPY --chown=vscode:vscode mcp.json.tpl /etc/mcp/mcp.json.tpl
USER vscode

# =============================================================================
# Status Line & ktn-linter (installed directly to ~/.local/bin/)
# Pinned versions + checksum verification for supply-chain security
# =============================================================================
ARG STATUS_LINE_VERSION=v0.6.2
ARG KTN_LINTER_VERSION=v1.3.90
# Checksums for supply-chain verification (from official releases)
ARG STATUS_LINE_SHA256_AMD64=6ba6b53162444fbc87f40e76b236e459ac6f88b99d2bdc183379a693592240a3
ARG STATUS_LINE_SHA256_ARM64=8bfd15968a836276a075fd6dd5b86f075ff3a7eb11dec8e3c5733bcef83ece74
ARG KTN_LINTER_SHA256_AMD64=152bdc455eaf119b7e52c72d8b3f0804ec94586e934afc6ce758995dc69b2f6f
ARG KTN_LINTER_SHA256_ARM64=a48bfd057d405ae3727a43b20926dd9641837af268b216e1e4dace5560a24b48
RUN mkdir -p ~/.local/bin && \
    ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    # status-line with checksum verification
    curl -fsSL "https://github.com/kodflow/status-line/releases/download/${STATUS_LINE_VERSION}/status-line-linux-${ARCH}" \
      -o ~/.local/bin/status-line && \
    EXPECTED_SL_SHA=$([ "$ARCH" = "arm64" ] && echo "$STATUS_LINE_SHA256_ARM64" || echo "$STATUS_LINE_SHA256_AMD64") && \
    echo "$EXPECTED_SL_SHA  $HOME/.local/bin/status-line" | sha256sum -c - && \
    chmod +x ~/.local/bin/status-line && \
    # ktn-linter with checksum verification
    curl -fsSL "https://github.com/kodflow/ktn-linter/releases/download/${KTN_LINTER_VERSION}/ktn-linter-linux-${ARCH}" \
      -o ~/.local/bin/ktn-linter && \
    EXPECTED_KTN_SHA=$([ "$ARCH" = "arm64" ] && echo "$KTN_LINTER_SHA256_ARM64" || echo "$KTN_LINTER_SHA256_AMD64") && \
    echo "$EXPECTED_KTN_SHA  $HOME/.local/bin/ktn-linter" | sha256sum -c - && \
    chmod +x ~/.local/bin/ktn-linter

# =============================================================================
# xdg-open wrapper (for headless container - displays URL instead of opening)
# =============================================================================
RUN printf '%s\n' '#!/bin/sh' \
    '[ $# -eq 0 ] && { echo "Usage: xdg-open <url> [url...]" >&2; exit 2; }' \
    'for url in "$@"; do printf "\n  Open in browser: %s\n" "$url"; done' \
    'echo ""' \
    > ~/.local/bin/xdg-open && chmod +x ~/.local/bin/xdg-open

# =============================================================================
# Environment Variables
# =============================================================================
ENV TF_PLUGIN_CACHE_DIR=/home/vscode/.cache/terraform \
    HELM_CACHE_HOME=/home/vscode/.cache/helm \
    KUBECONFIG=/home/vscode/.kube/config \
    BAZEL_USER_ROOT=/home/vscode/.cache/bazel \
    CLAUDE_CONFIG_DIR=/home/vscode/.claude \
    PATH=/home/vscode/.local/bin:$PATH

WORKDIR /workspace

# =============================================================================
# Labels
# =============================================================================
LABEL org.opencontainers.image.source="https://github.com/kodflow/devcontainer-template" \
      org.opencontainers.image.description="Base Development Image - All tools + Claude Code included" \
      org.opencontainers.image.licenses="MIT"
