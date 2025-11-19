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

# Install Elixir (latest stable that works with Phoenix)
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

# Install Phoenix (web framework)
echo -e "${YELLOW}Installing Phoenix...${NC}"
mix archive.install hex phx_new --force
PHOENIX_VERSION=$(mix phx.new --version)
echo -e "${GREEN}✓ Phoenix ${PHOENIX_VERSION} installed${NC}"

# Create cache directories
mkdir -p "$MIX_HOME"
mkdir -p "$HEX_HOME"

# Add asdf to shell profile
echo -e "${YELLOW}Configuring shell environment...${NC}"
SHELL_PROFILE="/home/vscode/.kodflow-env.sh"
sudo mkdir -p "$(dirname "$SHELL_PROFILE")"
sudo touch "$SHELL_PROFILE"
sudo chown vscode:vscode "$SHELL_PROFILE"

if ! grep -q "asdf.sh" "$SHELL_PROFILE" 2>/dev/null; then
    cat >> "$SHELL_PROFILE" << 'EOF'

# asdf version manager
export ASDF_DATA_DIR="${ASDF_DATA_DIR:-/home/vscode/.cache/asdf}"
if [ -f "$ASDF_DATA_DIR/asdf.sh" ]; then
  source "$ASDF_DATA_DIR/asdf.sh"
fi
EOF
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Elixir environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - Erlang/OTP $ERLANG_VERSION"
echo "  - Elixir $ELIXIR_VERSION"
echo "  - Hex (package manager)"
echo "  - Rebar3 (build tool)"
echo "  - Phoenix $PHOENIX_VERSION"
echo ""
echo "Cache directories:"
echo "  - asdf: $ASDF_DATA_DIR"
echo "  - Mix: $MIX_HOME"
echo "  - Hex: $HEX_HOME"
echo ""
echo "Note: asdf is configured in ~/.kodflow-env.sh"
