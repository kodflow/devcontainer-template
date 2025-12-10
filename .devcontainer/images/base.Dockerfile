# syntax=docker/dockerfile:1.4
# Kodflow Base Image - All tools, no languages
# Build: docker buildx build --platform linux/amd64,linux/arm64 -f base.Dockerfile -t ghcr.io/kodflow/.repository:base .
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Build arguments
ARG TARGETARCH
ARG BUILDKIT_INLINE_CACHE=1

# Environment
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# ============================================================================
# STAGE 1: System Dependencies
# ============================================================================
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Base tools
        curl \
        wget \
        ca-certificates \
        gnupg \
        gnupg2 \
        lsb-release \
        # Build tools
        build-essential \
        g++ \
        gcc \
        make \
        cmake \
        pkg-config \
        # Version control
        git \
        # Utilities
        jq \
        yq \
        zsh \
        unzip \
        zip \
        tar \
        xz-utils \
        file \
        # SSL/TLS
        libssl-dev \
        # Other dependencies
        libpam0g-dev \
        software-properties-common \
        apt-transport-https \
        # Python build dependencies (for pyenv)
        libffi-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libncurses5-dev \
        libncursesw5-dev \
        liblzma-dev \
        zlib1g-dev \
        # Ruby build dependencies
        libgdbm-dev \
        libyaml-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ============================================================================
# STAGE 2: Tools Installation (as root)
# ============================================================================

# --- HashiCorp Tools ---
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y terraform vault consul nomad packer terraform-ls && \
    rm -rf /var/lib/apt/lists/*

# --- Cloud CLIs ---
# AWS CLI v2
RUN ARCH_AWS=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") && \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_AWS}.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

# Google Cloud SDK
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && \
    apt-get install -y google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin && \
    rm -rf /var/lib/apt/lists/*

# Azure CLI
RUN curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash

# --- Kubernetes Tools ---
# kubectl
RUN ARCH_K8S=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH_K8S}/kubectl" -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

# Helm
RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# --- Ansible ---
RUN add-apt-repository --yes --update ppa:ansible/ansible && \
    apt-get install -y ansible && \
    rm -rf /var/lib/apt/lists/*

# --- Bazel/Bazelisk ---
RUN ARCH_BAZEL=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-${ARCH_BAZEL}" -o /usr/local/bin/bazel && \
    chmod +x /usr/local/bin/bazel

# ============================================================================
# STAGE 3: User Setup
# ============================================================================
USER vscode
WORKDIR /home/vscode

# Create cache and config directories
RUN mkdir -p \
    /home/vscode/.cache \
    /home/vscode/.config \
    /home/vscode/.local/bin \
    /home/vscode/.local/share \
    /home/vscode/.zsh_history_dir \
    /home/vscode/.cache/terraform \
    /home/vscode/.cache/helm \
    /home/vscode/.config/aws \
    /home/vscode/.config/gcloud \
    /home/vscode/.config/azure \
    /home/vscode/.kube \
    /home/vscode/.cache/bazel \
    /home/vscode/.claude \
    /home/vscode/.config/@anthropic \
    /home/vscode/.cache/@anthropic \
    /home/vscode/.local/share/@anthropic

# Install Oh My Zsh + Powerlevel10k + plugins
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

# Configure zshrc
RUN sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc" && \
    sed -i 's/^plugins=.*/plugins=(git docker aws gcloud kubectl helm terraform zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc" && \
    { \
        echo ''; \
        echo '# Powerlevel10k instant prompt'; \
        echo 'if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then'; \
        echo '  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"'; \
        echo 'fi'; \
        echo ''; \
        echo '# Powerlevel10k configuration'; \
        echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'; \
        echo ''; \
        echo '# Persistent zsh history'; \
        echo 'export HISTFILE=~/.zsh_history_dir/.zsh_history'; \
        echo 'export HISTSIZE=50000'; \
        echo 'export SAVEHIST=50000'; \
        echo ''; \
        echo '# Kodflow environment'; \
        echo '[[ -f ~/.kodflow-env.sh ]] && source ~/.kodflow-env.sh'; \
    } >> "$HOME/.zshrc"

# Environment variables for caches
ENV TF_PLUGIN_CACHE_DIR=/home/vscode/.cache/terraform \
    HELM_CACHE_HOME=/home/vscode/.cache/helm \
    AWS_CONFIG_FILE=/home/vscode/.config/aws/config \
    AWS_SHARED_CREDENTIALS_FILE=/home/vscode/.config/aws/credentials \
    AWS_CLI_CACHE_DIR=/home/vscode/.cache/aws \
    CLOUDSDK_CONFIG=/home/vscode/.config/gcloud \
    AZURE_CONFIG_DIR=/home/vscode/.config/azure \
    KUBECONFIG=/home/vscode/.kube/config \
    BAZEL_USER_ROOT=/home/vscode/.cache/bazel \
    CLAUDE_CONFIG_DIR=/home/vscode/.claude \
    PATH=/home/vscode/.local/bin:$PATH

WORKDIR /workspace

# Labels
LABEL org.opencontainers.image.source="https://github.com/kodflow/.repository" \
      org.opencontainers.image.description="Kodflow Base Image - Development tools without languages" \
      org.opencontainers.image.licenses="MIT"
