FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install minimal system dependencies (for Kodflow environments)
# hadolint ignore=DL3008,DL3009
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Base tools
        curl \
        wget \
        ca-certificates \
        gnupg \
        lsb-release \
        # Build tools (required by many languages)
        build-essential \
        g++ \
        cmake \
        # Version control
        git \
        # Utilities
        jq \
        yq \
        zsh \
        unzip \
        zip \
        tar \
        # SSL/TLS
        libssl-dev \
        # Other common dependencies
        libpam0g-dev \
        software-properties-common \
        apt-transport-https && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Switch to vscode user
USER vscode
WORKDIR /home/vscode

# Create directories for persistent volumes
RUN mkdir -p \
    /home/vscode/.cache \
    /home/vscode/.config \
    /home/vscode/.local/bin \
    /home/vscode/.local/share \
    /home/vscode/.zsh_history_dir \
    /home/vscode/.claude \
    /home/vscode/.config/@anthropic \
    /home/vscode/.cache/@anthropic \
    /home/vscode/.local/share/@anthropic

# Install Oh My Zsh if not exists, then install Powerlevel10k theme and plugins
RUN if [ ! -d "$HOME/.oh-my-zsh" ]; then \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; \
    fi && \
    rm -rf "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" && \
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" && \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" && \
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

# Copy p10k configuration
COPY --chown=vscode:vscode hooks/shared/.p10k.zsh /home/vscode/.p10k.zsh

# Configure zshrc
RUN sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc" && \
    sed -i 's/^plugins=.*/plugins=(git docker aws gcloud kubectl helm terraform npm yarn rust golang zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc" && \
    { \
        echo ''; \
        echo '# To customize prompt, run "p10k configure" or edit ~/.p10k.zsh'; \
        echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'; \
        echo ''; \
        echo '# Persistent zsh history'; \
        echo 'export HISTFILE=~/.zsh_history_dir/.zsh_history'; \
        echo 'export HISTSIZE=10000'; \
        echo 'export SAVEHIST=10000'; \
        echo ''; \
        echo '# Kodflow environment initialization'; \
        echo 'if [ -f ~/.kodflow-env.sh ]; then'; \
        echo '  source ~/.kodflow-env.sh'; \
        echo 'fi'; \
    } >> "$HOME/.zshrc"

# Set working directory
WORKDIR /workspace
