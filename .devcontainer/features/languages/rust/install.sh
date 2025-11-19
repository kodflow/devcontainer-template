#!/bin/bash
set -e

echo "========================================="
echo "Installing Rust Development Environment"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Environment variables
export CARGO_HOME="${CARGO_HOME:-/home/vscode/.cache/cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-/home/vscode/.cache/rustup}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    curl \
    build-essential \
    gcc \
    make \
    cmake \
    pkg-config \
    libssl-dev

# Install rustup (Rust toolchain installer)
echo -e "${YELLOW}Installing rustup...${NC}"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path

# Setup Rust environment
export PATH="$CARGO_HOME/bin:$PATH"

# Source cargo env
source "$CARGO_HOME/env"

RUST_VERSION=$(rustc --version)
CARGO_VERSION=$(cargo --version)
echo -e "${GREEN}✓ ${RUST_VERSION} installed${NC}"
echo -e "${GREEN}✓ ${CARGO_VERSION} installed${NC}"

# Install stable, beta, and nightly toolchains
echo -e "${YELLOW}Installing toolchains...${NC}"
rustup toolchain install stable
rustup toolchain install nightly
rustup default stable
echo -e "${GREEN}✓ Toolchains installed (stable, nightly)${NC}"

# Install common components
echo -e "${YELLOW}Installing components...${NC}"

# rustfmt (formatter)
rustup component add rustfmt
echo -e "${GREEN}✓ rustfmt installed${NC}"

# clippy (linter)
rustup component add clippy
echo -e "${GREEN}✓ clippy installed${NC}"

# rust-src (source code)
rustup component add rust-src
echo -e "${GREEN}✓ rust-src installed${NC}"

# rust-analyzer (language server) - install via cargo
echo -e "${YELLOW}Installing rust-analyzer...${NC}"
rustup component add rust-analyzer
echo -e "${GREEN}✓ rust-analyzer installed${NC}"

# Install common cargo tools
echo -e "${YELLOW}Installing cargo tools...${NC}"

# cargo-edit (add/remove dependencies)
cargo install cargo-edit
echo -e "${GREEN}✓ cargo-edit installed${NC}"

# cargo-watch (auto-rebuild)
cargo install cargo-watch
echo -e "${GREEN}✓ cargo-watch installed${NC}"

# cargo-expand (macro expansion)
cargo install cargo-expand
echo -e "${GREEN}✓ cargo-expand installed${NC}"

# cargo-audit (security audit)
cargo install cargo-audit
echo -e "${GREEN}✓ cargo-audit installed${NC}"

# cargo-outdated (check for outdated dependencies)
cargo install cargo-outdated
echo -e "${GREEN}✓ cargo-outdated installed${NC}"

# cargo-tree (dependency tree)
cargo install cargo-tree
echo -e "${GREEN}✓ cargo-tree installed${NC}"

# cargo-nextest (better test runner)
cargo install cargo-nextest
echo -e "${GREEN}✓ cargo-nextest installed${NC}"

# cargo-criterion (benchmarking)
cargo install cargo-criterion
echo -e "${GREEN}✓ cargo-criterion installed${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Rust environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - rustup (Rust toolchain manager)"
echo "  - ${RUST_VERSION}"
echo "  - ${CARGO_VERSION}"
echo "  - Toolchains: stable, nightly"
echo "  - rustfmt (formatter)"
echo "  - clippy (linter)"
echo "  - rust-src"
echo "  - rust-analyzer (language server)"
echo "  - cargo-edit"
echo "  - cargo-watch"
echo "  - cargo-expand"
echo "  - cargo-audit"
echo "  - cargo-outdated"
echo "  - cargo-tree"
echo "  - cargo-nextest"
echo "  - cargo-criterion"
echo ""
echo "Cache directories:"
echo "  - CARGO_HOME: $CARGO_HOME"
echo "  - RUSTUP_HOME: $RUSTUP_HOME"
