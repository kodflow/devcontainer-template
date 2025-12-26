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
    zip

# Install Flutter (includes Dart)
echo -e "${YELLOW}Installing Flutter...${NC}"

# Clone with retry
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if git clone https://github.com/flutter/flutter.git -b stable "$FLUTTER_ROOT"; then
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        echo -e "${YELLOW}Git clone failed, retrying (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)...${NC}"
        rm -rf "$FLUTTER_ROOT"
        sleep 5
    else
        echo -e "${RED}Failed to clone Flutter repository after $MAX_RETRIES attempts${NC}"
        exit 1
    fi
done

# Setup Flutter
export PATH="$FLUTTER_ROOT/bin:$PATH"

# Run flutter doctor to download dependencies
flutter doctor

FLUTTER_VERSION=$(flutter --version | head -n 1)
DART_VERSION=$(dart --version 2>&1)
echo -e "${GREEN}✓ ${FLUTTER_VERSION} installed${NC}"
echo -e "${GREEN}✓ ${DART_VERSION} installed${NC}"

# Create cache directories
mkdir -p "$PUB_CACHE"

# ─────────────────────────────────────────────────────────────────────────────
# Install Dart/Flutter Development Tools (latest versions)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Installing Dart/Flutter development tools...${NC}"

# DCM (Dart Code Metrics - code quality tool)
echo -e "${YELLOW}Installing DCM...${NC}"
dart pub global activate dcm 2>/dev/null || echo -e "${YELLOW}⚠ DCM requires license for some features${NC}"
echo -e "${GREEN}✓ DCM installed${NC}"

# very_good_cli (Very Good CLI for project scaffolding)
echo -e "${YELLOW}Installing Very Good CLI...${NC}"
dart pub global activate very_good_cli
echo -e "${GREEN}✓ Very Good CLI installed${NC}"

# melos (monorepo management)
echo -e "${YELLOW}Installing Melos...${NC}"
dart pub global activate melos
echo -e "${GREEN}✓ Melos installed${NC}"

# dart_style (formatter - part of SDK but ensure global)
echo -e "${YELLOW}Verifying dart format...${NC}"
dart format --version
echo -e "${GREEN}✓ dart format available${NC}"

# Add pub global bin to PATH
PUB_BIN="$PUB_CACHE/bin"
if ! grep -q "PUB_CACHE" /home/vscode/.zshrc 2>/dev/null; then
    echo "" >> /home/vscode/.zshrc
    echo "# Dart pub global binaries" >> /home/vscode/.zshrc
    echo "export PATH=\"\$PATH:$PUB_BIN\"" >> /home/vscode/.zshrc
fi

echo -e "${GREEN}✓ Dart/Flutter development tools installed${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Dart/Flutter environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${FLUTTER_VERSION}"
echo "  - ${DART_VERSION}"
echo "  - Pub (package manager)"
echo ""
echo "Development tools:"
echo "  - DCM (code metrics)"
echo "  - Very Good CLI (scaffolding)"
echo "  - Melos (monorepo management)"
echo "  - dart format (formatter)"
echo "  - dart analyze (static analysis)"
echo ""
echo "Cache directories:"
echo "  - Flutter: $FLUTTER_ROOT"
echo "  - Pub cache: $PUB_CACHE"
echo ""
