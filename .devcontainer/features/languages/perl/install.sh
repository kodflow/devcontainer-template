#!/bin/bash
set -e

echo "========================================="
echo "Installing Perl Development Environment"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Install Perl and cpanminus
echo -e "${YELLOW}Installing Perl and cpanminus...${NC}"
sudo apt-get update && sudo apt-get install -y \
    perl \
    cpanminus \
    make \
    gcc

PERL_INSTALLED=$(perl --version | head -n 2 | tail -n 1)
echo -e "${GREEN}${PERL_INSTALLED}${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Install Perl development modules
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Installing Perl::Tidy...${NC}"
if sudo cpanm --notest Perl::Tidy 2>/dev/null; then
    echo -e "${GREEN}Perl::Tidy installed${NC}"
else
    echo -e "${RED}Perl::Tidy failed to install${NC}"
fi

echo -e "${YELLOW}Installing Perl::Critic...${NC}"
if sudo cpanm --notest Perl::Critic 2>/dev/null; then
    echo -e "${GREEN}Perl::Critic installed${NC}"
else
    echo -e "${RED}Perl::Critic failed to install${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Perl environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${PERL_INSTALLED}"
echo "  - cpanminus (package manager)"
echo ""
echo "Development modules:"
echo "  - Perl::Tidy (formatter)"
echo "  - Perl::Critic (linter)"
echo ""
