#!/bin/bash
set -e

echo "========================================="
echo "Installing Assembly Development Environment"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Install assembly tools
echo -e "${YELLOW}Installing NASM, binutils, and GDB...${NC}"
sudo apt-get update && sudo apt-get install -y nasm binutils gdb

NASM_VERSION=$(nasm --version)
GDB_VERSION=$(gdb --version | head -n 1)

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Assembly environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${NASM_VERSION}"
echo "  - binutils (as, ld, objdump, readelf)"
echo "  - ${GDB_VERSION}"
echo ""
