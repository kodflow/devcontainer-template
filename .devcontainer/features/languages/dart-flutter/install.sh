#!/bin/bash
set -e

echo "========================================="
echo "Installing Dart/Flutter Development Environment"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Environment variables
export FLUTTER_ROOT="${FLUTTER_ROOT:-/home/vscode/.cache/flutter}"
export PUB_CACHE="${PUB_CACHE:-/home/vscode/.cache/pub-cache}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev

# Install Flutter (includes Dart)
echo -e "${YELLOW}Installing Flutter...${NC}"
git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_ROOT"

# Setup Flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"

# Run flutter doctor to download dependencies
flutter doctor

FLUTTER_VERSION=$(flutter --version | head -n 1)
DART_VERSION=$(dart --version 2>&1)
echo -e "${GREEN}✓ ${FLUTTER_VERSION} installed${NC}"
echo -e "${GREEN}✓ ${DART_VERSION} installed${NC}"

# Enable Flutter platforms
echo -e "${YELLOW}Enabling Flutter platforms...${NC}"
flutter config --enable-web
flutter config --enable-linux-desktop
echo -e "${GREEN}✓ Flutter platforms enabled${NC}"

# Install development tools
echo -e "${YELLOW}Installing development tools...${NC}"

# Dart formatter and analyzer (included with SDK)
echo -e "${GREEN}✓ dart format (built-in)${NC}"
echo -e "${GREEN}✓ dart analyze (built-in)${NC}"

# Create cache directories
mkdir -p "$PUB_CACHE"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Dart/Flutter environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${FLUTTER_VERSION}"
echo "  - ${DART_VERSION}"
echo "  - Flutter Web support"
echo "  - Flutter Linux Desktop support"
echo "  - dart format"
echo "  - dart analyze"
echo ""
echo "Cache directories:"
echo "  - Flutter: $FLUTTER_ROOT"
echo "  - Pub cache: $PUB_CACHE"
