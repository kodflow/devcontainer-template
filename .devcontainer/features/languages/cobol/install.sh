#!/bin/bash
set -e

echo "========================================="
echo "Installing COBOL Development Environment"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Install GnuCOBOL
echo -e "${YELLOW}Installing GnuCOBOL...${NC}"
sudo apt-get update && sudo apt-get install -y gnucobol

COBC_VERSION=$(cobc --version | head -n 1)
echo -e "${GREEN}+ ${COBC_VERSION} installed${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}COBOL environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${COBC_VERSION}"
echo ""
