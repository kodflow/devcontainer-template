# syntax=docker/dockerfile:1.4
# =============================================================================
# Kodflow Multi-Language Docker Image
# =============================================================================
# Build examples:
#   Base only:    docker buildx build --build-arg VARIANT=base -t kodflow:base .
#   Go:           docker buildx build --build-arg VARIANT=go -t kodflow:go .
#   Full:         docker buildx build --build-arg VARIANT=full -t kodflow:full .
#   Multi-arch:   docker buildx build --platform linux/amd64,linux/arm64 ...
# =============================================================================

# Global ARGs (must be before first FROM to be available for FROM instructions)
ARG BASE_IMAGE=mcr.microsoft.com/devcontainers/base:ubuntu-24.04
ARG VARIANT=base

# =============================================================================
# STAGE: Base - System dependencies and tools
# =============================================================================
FROM ${BASE_IMAGE} AS lang-base

ARG TARGETARCH
ARG BUILDKIT_INLINE_CACHE=1

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# System packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget ca-certificates gnupg gnupg2 lsb-release \
        build-essential g++ gcc make cmake pkg-config \
        git jq yq zsh unzip zip tar xz-utils file \
        libssl-dev libpam0g-dev software-properties-common apt-transport-https \
        libffi-dev libbz2-dev libreadline-dev libsqlite3-dev \
        libncurses5-dev libncursesw5-dev liblzma-dev zlib1g-dev \
        libgdbm-dev libyaml-dev && \
    apt-get clean

# HashiCorp Tools
RUN wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform vault consul nomad packer terraform-ls && \
    rm -rf /var/lib/apt/lists/*

# AWS CLI v2
RUN ARCH_AWS=$([ "$TARGETARCH" = "arm64" ] && echo "aarch64" || echo "x86_64") && \
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_AWS}.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscliv2.zip

# Google Cloud SDK
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && apt-get install -y google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin && \
    rm -rf /var/lib/apt/lists/*

# Azure CLI
RUN curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash

# kubectl + Helm
RUN ARCH_K8S=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH_K8S}/kubectl" -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl && \
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Ansible
RUN add-apt-repository --yes --update ppa:ansible/ansible && \
    apt-get install -y ansible && rm -rf /var/lib/apt/lists/*

# Bazelisk
RUN ARCH_BAZEL=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-${ARCH_BAZEL}" -o /usr/local/bin/bazel && \
    chmod +x /usr/local/bin/bazel

# User setup
USER vscode
WORKDIR /home/vscode

RUN mkdir -p .cache .config .local/bin .local/share .zsh_history_dir \
    .cache/{terraform,helm,aws,bazel,npm,yarn,pnpm,pip,poetry,go,go-build,cargo,rustup,gems,bundle,maven,gradle,composer,pub-cache,flutter,mix,hex,ccache} \
    .config/{aws,gcloud,azure,kube} \
    .claude .config/@anthropic .cache/@anthropic .local/share/@anthropic

# Oh My Zsh + Powerlevel10k (skip if already installed in base image)
RUN if [ ! -d "$HOME/.oh-my-zsh" ]; then \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; \
    fi && \
    rm -rf ~/.oh-my-zsh/custom/themes/powerlevel10k && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k && \
    rm -rf ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    rm -rf ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

RUN sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc && \
    sed -i 's/^plugins=.*/plugins=(git docker aws gcloud kubectl helm terraform zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc && \
    echo '\n[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh\nexport HISTFILE=~/.zsh_history_dir/.zsh_history\nexport HISTSIZE=50000\nexport SAVEHIST=50000\n[[ -f ~/.kodflow-env.sh ]] && source ~/.kodflow-env.sh' >> ~/.zshrc

ENV TF_PLUGIN_CACHE_DIR=/home/vscode/.cache/terraform \
    HELM_CACHE_HOME=/home/vscode/.cache/helm \
    KUBECONFIG=/home/vscode/.config/kube/config \
    BAZEL_USER_ROOT=/home/vscode/.cache/bazel \
    CLAUDE_CONFIG_DIR=/home/vscode/.claude \
    PATH=/home/vscode/.local/bin:/home/vscode/.local/share/npm-global/bin:$PATH

WORKDIR /workspace

# =============================================================================
# STAGE: Go
# =============================================================================
FROM lang-base AS lang-go
ARG TARGETARCH
ARG GO_VERSION=latest

USER root
RUN GO_ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    if [ "$GO_VERSION" = "latest" ]; then GO_VERSION=$(curl -sL https://go.dev/VERSION?m=text | head -1 | sed 's/go//'); fi && \
    curl -fsSL "https://dl.google.com/go/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" | tar -C /usr/local -xzf -

USER vscode
RUN mkdir -p ~/.cache/go/bin ~/.cache/go/pkg/mod ~/.cache/go-build
ENV GOROOT=/usr/local/go \
    GOPATH=/home/vscode/.cache/go \
    GOCACHE=/home/vscode/.cache/go-build \
    GOMODCACHE=/home/vscode/.cache/go/pkg/mod \
    PATH=/usr/local/go/bin:/home/vscode/.cache/go/bin:$PATH

# =============================================================================
# STAGE: Node.js
# =============================================================================
FROM lang-base AS lang-nodejs
ARG NODE_VERSION=lts/*

USER vscode
ENV NVM_DIR=/home/vscode/.cache/nvm \
    npm_config_cache=/home/vscode/.cache/npm \
    YARN_CACHE_FOLDER=/home/vscode/.cache/yarn \
    PNPM_HOME=/home/vscode/.cache/pnpm

RUN mkdir -p $NVM_DIR ~/.local/share/npm-global && \
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install "${NODE_VERSION}" && \
    nvm use "${NODE_VERSION}" && \
    nvm alias default "${NODE_VERSION}" && \
    npm install -g yarn pnpm npm@latest && \
    npm config set prefix ~/.local/share/npm-global && \
    # Create symlinks in .local/bin for node binaries
    ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | head -1)/bin/node" ~/.local/bin/node && \
    ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | head -1)/bin/npm" ~/.local/bin/npm && \
    ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | head -1)/bin/npx" ~/.local/bin/npx

ENV PATH=/home/vscode/.local/share/npm-global/bin:/home/vscode/.local/bin:/home/vscode/.cache/pnpm:$PATH

# =============================================================================
# STAGE: Python
# =============================================================================
FROM lang-base AS lang-python
ARG PYTHON_VERSION=3.12

USER vscode
ENV PYENV_ROOT=/home/vscode/.cache/pyenv \
    PIP_CACHE_DIR=/home/vscode/.cache/pip \
    POETRY_CACHE_DIR=/home/vscode/.cache/poetry \
    PIPENV_CACHE_DIR=/home/vscode/.cache/pipenv

RUN curl -fsSL https://pyenv.run | bash && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc && \
    $PYENV_ROOT/bin/pyenv install ${PYTHON_VERSION} && \
    $PYENV_ROOT/bin/pyenv global ${PYTHON_VERSION} && \
    PYTHON_FULL_VERSION=$(ls $PYENV_ROOT/versions | grep "^${PYTHON_VERSION}" | head -1) && \
    $PYENV_ROOT/versions/${PYTHON_FULL_VERSION}/bin/pip install --upgrade pip poetry pipenv

ENV PATH=/home/vscode/.cache/pyenv/shims:/home/vscode/.cache/pyenv/bin:$PATH

# =============================================================================
# STAGE: Rust
# =============================================================================
FROM lang-base AS lang-rust

USER vscode
ENV CARGO_HOME=/home/vscode/.cache/cargo \
    RUSTUP_HOME=/home/vscode/.cache/rustup

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path && \
    . "$CARGO_HOME/env" && \
    rustup toolchain install stable && \
    rustup default stable

ENV PATH=/home/vscode/.cache/cargo/bin:$PATH

# =============================================================================
# STAGE: Ruby
# =============================================================================
FROM lang-base AS lang-ruby
ARG RUBY_VERSION=3.3.10

USER vscode
ENV RBENV_ROOT=/home/vscode/.cache/rbenv \
    GEM_HOME=/home/vscode/.cache/gems \
    BUNDLE_PATH=/home/vscode/.cache/bundle

RUN git clone --depth=1 https://github.com/rbenv/rbenv.git $RBENV_ROOT && \
    git clone --depth=1 https://github.com/rbenv/ruby-build.git $RBENV_ROOT/plugins/ruby-build && \
    $RBENV_ROOT/bin/rbenv install ${RUBY_VERSION} && \
    $RBENV_ROOT/bin/rbenv global ${RUBY_VERSION}

ENV PATH=/home/vscode/.cache/rbenv/shims:/home/vscode/.cache/rbenv/bin:/home/vscode/.cache/gems/bin:$PATH

# =============================================================================
# STAGE: Java
# =============================================================================
FROM lang-base AS lang-java

USER vscode
ENV SDKMAN_DIR=/home/vscode/.cache/sdkman \
    MAVEN_OPTS="-Dmaven.repo.local=/home/vscode/.cache/maven" \
    GRADLE_USER_HOME=/home/vscode/.cache/gradle

RUN curl -fsSL https://get.sdkman.io | bash && \
    bash -c "source $SDKMAN_DIR/bin/sdkman-init.sh && sdk install java && sdk install maven && sdk install gradle"

ENV PATH=/home/vscode/.cache/sdkman/candidates/java/current/bin:/home/vscode/.cache/sdkman/candidates/maven/current/bin:/home/vscode/.cache/sdkman/candidates/gradle/current/bin:$PATH

# =============================================================================
# STAGE: PHP
# =============================================================================
FROM lang-base AS lang-php

USER root
RUN add-apt-repository --yes ppa:ondrej/php && \
    apt-get update && \
    apt-get install -y php php-cli php-fpm php-json php-common php-mysql php-zip php-gd php-mbstring php-curl php-xml php-pear php-bcmath && \
    rm -rf /var/lib/apt/lists/*

USER vscode
ENV COMPOSER_HOME=/home/vscode/.cache/composer \
    COMPOSER_CACHE_DIR=/home/vscode/.cache/composer/cache

RUN curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/home/vscode/.local/bin --filename=composer

ENV PATH=/home/vscode/.cache/composer/vendor/bin:$PATH

# =============================================================================
# STAGE: Dart/Flutter
# =============================================================================
FROM lang-base AS lang-dart

USER vscode
ENV PUB_CACHE=/home/vscode/.cache/pub-cache \
    FLUTTER_ROOT=/home/vscode/.cache/flutter

RUN git clone --depth=1 https://github.com/flutter/flutter.git -b stable $FLUTTER_ROOT && \
    $FLUTTER_ROOT/bin/flutter precache && \
    $FLUTTER_ROOT/bin/flutter config --no-analytics

ENV PATH=/home/vscode/.cache/flutter/bin:/home/vscode/.cache/pub-cache/bin:$PATH

# =============================================================================
# STAGE: Elixir
# =============================================================================
FROM lang-base AS lang-elixir

USER root
# Use Ubuntu 24.04's official packages (Erlang 26 + Elixir 1.15)
RUN apt-get update && apt-get install -y erlang elixir && \
    rm -rf /var/lib/apt/lists/*

USER vscode
ENV MIX_HOME=/home/vscode/.cache/mix \
    HEX_HOME=/home/vscode/.cache/hex

RUN mix local.hex --force && mix local.rebar --force

ENV PATH=/home/vscode/.cache/mix/escripts:$PATH

# =============================================================================
# STAGE: C/C++
# =============================================================================
FROM lang-base AS lang-cpp

USER root
RUN apt-get update && \
    apt-get install -y clang clang-format clang-tidy lldb gdb valgrind ccache python3-pip && \
    rm -rf /var/lib/apt/lists/* && \
    pip3 install --break-system-packages conan

USER vscode
ENV CCACHE_DIR=/home/vscode/.cache/ccache \
    CONAN_USER_HOME=/home/vscode/.cache/conan \
    CMAKE_BUILD_PARALLEL_LEVEL=4

# =============================================================================
# STAGE: Full (all languages)
# =============================================================================
FROM lang-base AS lang-full
ARG TARGETARCH

# Go
USER root
RUN GO_ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    GO_VERSION=$(curl -sL https://go.dev/VERSION?m=text | head -1 | sed 's/go//') && \
    curl -fsSL "https://dl.google.com/go/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" | tar -C /usr/local -xzf -

# PHP
RUN add-apt-repository --yes ppa:ondrej/php && \
    apt-get update && \
    apt-get install -y php php-cli php-fpm php-json php-common php-mysql php-zip php-gd php-mbstring php-curl php-xml php-pear php-bcmath && \
    rm -rf /var/lib/apt/lists/*

# C/C++
RUN apt-get update && \
    apt-get install -y clang clang-format clang-tidy lldb gdb valgrind ccache && \
    rm -rf /var/lib/apt/lists/*

# Erlang/Elixir (Ubuntu 24.04's official packages)
RUN apt-get update && apt-get install -y erlang elixir && \
    rm -rf /var/lib/apt/lists/*

USER vscode

# Node.js (via nvm)
ENV NVM_DIR=/home/vscode/.cache/nvm
RUN mkdir -p $NVM_DIR ~/.local/share/npm-global && \
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash && \
    . "$NVM_DIR/nvm.sh" && nvm install lts/* && nvm alias default lts/* && \
    npm install -g yarn pnpm npm@latest && \
    npm config set prefix ~/.local/share/npm-global && \
    ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | head -1)/bin/node" ~/.local/bin/node && \
    ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | head -1)/bin/npm" ~/.local/bin/npm && \
    ln -sf "$NVM_DIR/versions/node/$(ls $NVM_DIR/versions/node | head -1)/bin/npx" ~/.local/bin/npx

# Python (via pyenv)
ENV PYENV_ROOT=/home/vscode/.cache/pyenv
RUN curl -fsSL https://pyenv.run | bash && \
    $PYENV_ROOT/bin/pyenv install 3.12 && \
    $PYENV_ROOT/bin/pyenv global 3.12 && \
    $PYENV_ROOT/versions/3.12*/bin/pip install --upgrade pip poetry pipenv

# Rust
ENV CARGO_HOME=/home/vscode/.cache/cargo \
    RUSTUP_HOME=/home/vscode/.cache/rustup
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

# Ruby (via rbenv)
ENV RBENV_ROOT=/home/vscode/.cache/rbenv
RUN git clone --depth=1 https://github.com/rbenv/rbenv.git $RBENV_ROOT && \
    git clone --depth=1 https://github.com/rbenv/ruby-build.git $RBENV_ROOT/plugins/ruby-build && \
    $RBENV_ROOT/bin/rbenv install 3.3.10 && $RBENV_ROOT/bin/rbenv global 3.3.10

# Java (via SDKMAN)
ENV SDKMAN_DIR=/home/vscode/.cache/sdkman
RUN curl -fsSL https://get.sdkman.io | bash && \
    bash -c "source $SDKMAN_DIR/bin/sdkman-init.sh && sdk install java && sdk install maven && sdk install gradle"

# PHP Composer
RUN curl -fsSL https://getcomposer.org/installer | php -- --install-dir=/home/vscode/.local/bin --filename=composer

# Flutter
ENV FLUTTER_ROOT=/home/vscode/.cache/flutter
RUN git clone --depth=1 https://github.com/flutter/flutter.git -b stable $FLUTTER_ROOT && \
    $FLUTTER_ROOT/bin/flutter precache --no-analytics && \
    $FLUTTER_ROOT/bin/flutter config --no-analytics

# Elixir tools
ENV MIX_HOME=/home/vscode/.cache/mix \
    HEX_HOME=/home/vscode/.cache/hex
RUN mix local.hex --force && mix local.rebar --force

# Full environment
ENV GOROOT=/usr/local/go \
    GOPATH=/home/vscode/.cache/go \
    GOCACHE=/home/vscode/.cache/go-build \
    GOMODCACHE=/home/vscode/.cache/go/pkg/mod \
    npm_config_cache=/home/vscode/.cache/npm \
    YARN_CACHE_FOLDER=/home/vscode/.cache/yarn \
    PNPM_HOME=/home/vscode/.cache/pnpm \
    PIP_CACHE_DIR=/home/vscode/.cache/pip \
    POETRY_CACHE_DIR=/home/vscode/.cache/poetry \
    GEM_HOME=/home/vscode/.cache/gems \
    BUNDLE_PATH=/home/vscode/.cache/bundle \
    MAVEN_OPTS="-Dmaven.repo.local=/home/vscode/.cache/maven" \
    GRADLE_USER_HOME=/home/vscode/.cache/gradle \
    COMPOSER_HOME=/home/vscode/.cache/composer \
    COMPOSER_CACHE_DIR=/home/vscode/.cache/composer/cache \
    PUB_CACHE=/home/vscode/.cache/pub-cache \
    CCACHE_DIR=/home/vscode/.cache/ccache \
    PATH=/usr/local/go/bin:/home/vscode/.cache/go/bin:/home/vscode/.cache/cargo/bin:/home/vscode/.cache/pyenv/shims:/home/vscode/.cache/pyenv/bin:/home/vscode/.cache/rbenv/shims:/home/vscode/.cache/rbenv/bin:/home/vscode/.cache/gems/bin:/home/vscode/.cache/sdkman/candidates/java/current/bin:/home/vscode/.cache/sdkman/candidates/maven/current/bin:/home/vscode/.cache/sdkman/candidates/gradle/current/bin:/home/vscode/.cache/composer/vendor/bin:/home/vscode/.cache/flutter/bin:/home/vscode/.cache/pub-cache/bin:/home/vscode/.cache/mix/escripts:/home/vscode/.cache/pnpm:/home/vscode/.local/share/npm-global/bin:/home/vscode/.local/bin:$PATH

# =============================================================================
# FINAL STAGE: Select variant
# =============================================================================
# Re-declare ARG to use in FROM (value comes from build command or global default)
ARG VARIANT
FROM lang-${VARIANT} AS final

LABEL org.opencontainers.image.source="https://github.com/kodflow/.repository" \
      org.opencontainers.image.description="Kodflow Development Image" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /workspace
