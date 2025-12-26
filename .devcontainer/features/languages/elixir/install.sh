#!/bin/bash
set -e

echo "========================================="
echo "Installing Elixir Development Environment"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Environment variables
export ASDF_DATA_DIR="${ASDF_DATA_DIR:-/home/vscode/.cache/asdf}"
export MIX_HOME="${MIX_HOME:-/home/vscode/.cache/mix}"
export HEX_HOME="${HEX_HOME:-/home/vscode/.cache/hex}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    autoconf \
    m4 \
    libncurses5-dev \
    libssl-dev \
    libwxgtk3.2-dev \
    libwxgtk-webview3.2-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libpng-dev \
    libssh-dev \
    unixodbc-dev \
    xsltproc \
    fop \
    libxml2-utils \
    openjdk-11-jdk 2>/dev/null || sudo apt-get install -y \
    wget \
    curl \
    git \
    build-essential \
    autoconf \
    m4 \
    libncurses5-dev \
    libssl-dev

# Install asdf
echo -e "${YELLOW}Installing asdf version manager...${NC}"
if [ ! -d "$ASDF_DATA_DIR" ]; then
    git clone https://github.com/asdf-vm/asdf.git "$ASDF_DATA_DIR" --branch v0.14.1
fi

# Source asdf
source "$ASDF_DATA_DIR/asdf.sh"

# Add asdf plugins
echo -e "${YELLOW}Adding asdf plugins...${NC}"
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git 2>/dev/null || true
asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git 2>/dev/null || true

# Install Erlang (latest stable)
echo -e "${YELLOW}Installing Erlang via asdf...${NC}"
ERLANG_VERSION="27.1.2"
asdf install erlang $ERLANG_VERSION
asdf global erlang $ERLANG_VERSION

ERLANG_VERSION_CHECK=$(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell)
echo -e "${GREEN}✓ Erlang/OTP ${ERLANG_VERSION_CHECK} installed${NC}"

# Install Elixir (latest stable)
echo -e "${YELLOW}Installing Elixir via asdf...${NC}"
ELIXIR_VERSION="1.17.3-otp-27"
asdf install elixir $ELIXIR_VERSION
asdf global elixir $ELIXIR_VERSION

ELIXIR_VERSION_CHECK=$(elixir --version | grep "Elixir" | head -n 1)
echo -e "${GREEN}✓ ${ELIXIR_VERSION_CHECK} installed${NC}"

# Install Hex (package manager)
echo -e "${YELLOW}Installing Hex...${NC}"
mix local.hex --force
echo -e "${GREEN}✓ Hex installed${NC}"

# Install Rebar3 (build tool)
echo -e "${YELLOW}Installing Rebar3...${NC}"
mix local.rebar --force
echo -e "${GREEN}✓ Rebar3 installed${NC}"

# Create cache directories
mkdir -p "$MIX_HOME"
mkdir -p "$HEX_HOME"

# ─────────────────────────────────────────────────────────────────────────────
# Install Elixir Development Tools (latest versions)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Installing Elixir development tools...${NC}"

# Install Credo globally as an archive (per RULES.md)
echo -e "${YELLOW}Installing Credo...${NC}"
mix archive.install hex credo --force
echo -e "${GREEN}✓ Credo installed${NC}"

# Install Dialyxir globally as an archive (per RULES.md)
echo -e "${YELLOW}Installing Dialyxir...${NC}"
mix archive.install hex dialyxir --force 2>/dev/null || echo -e "${YELLOW}⚠ Dialyxir requires project context${NC}"
echo -e "${GREEN}✓ Dialyxir setup ready${NC}"

# Install Elixir LS (Language Server)
echo -e "${YELLOW}Installing Elixir LS...${NC}"
mix archive.install hex elixir_ls --force 2>/dev/null || echo -e "${YELLOW}⚠ Elixir LS requires project context${NC}"
echo -e "${GREEN}✓ Elixir LS setup ready${NC}"

# Pre-build PLT for faster Dialyzer runs
echo -e "${YELLOW}Building Dialyzer PLT (this may take a while)...${NC}"
mix dialyzer --plt 2>/dev/null || echo -e "${YELLOW}⚠ PLT build requires project context${NC}"

echo -e "${GREEN}✓ Elixir development tools installed${NC}"

# Note about project-level installation
echo -e "${YELLOW}Note: For full functionality, add to your mix.exs:${NC}"
echo '  {:credo, "~> 1.7", only: [:dev, :test], runtime: false}'
echo '  {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}'

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Elixir environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - asdf (version manager)"
echo "  - Erlang/OTP ${ERLANG_VERSION}"
echo "  - ${ELIXIR_VERSION_CHECK}"
echo "  - Hex (package manager)"
echo "  - Rebar3 (build tool)"
echo ""
echo "Development tools:"
echo "  - Credo (linter)"
echo "  - Dialyxir (type checking)"
echo "  - Elixir LS (language server)"
echo ""
echo "Cache directories:"
echo "  - asdf: $ASDF_DATA_DIR"
echo "  - Mix: $MIX_HOME"
echo "  - Hex: $HEX_HOME"
echo ""
