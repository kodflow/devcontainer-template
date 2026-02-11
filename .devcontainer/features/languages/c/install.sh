#!/bin/bash
set -e

echo "========================================="
echo "Installing C Development Environment"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect architecture
ARCH=$(uname -m)
echo -e "${YELLOW}Detected architecture: ${ARCH}${NC}"

# Install C development packages
echo -e "${YELLOW}Installing C compilers and development tools...${NC}"
sudo apt-get update && sudo apt-get install -y \
    gcc \
    clang \
    clang-format \
    clang-tidy \
    valgrind \
    gdb \
    cmake \
    make \
    pkg-config \
    build-essential

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}C environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - gcc          $(gcc --version | head -n 1)"
echo "  - clang        $(clang --version | head -n 1)"
echo "  - clang-format $(clang-format --version)"
echo "  - clang-tidy   $(clang-tidy --version | head -n 1)"
echo "  - valgrind     $(valgrind --version)"
echo "  - gdb          $(gdb --version | head -n 1)"
echo "  - cmake        $(cmake --version | head -n 1)"
echo "  - make         $(make --version | head -n 1)"
echo "  - pkg-config   $(pkg-config --version)"
echo ""
