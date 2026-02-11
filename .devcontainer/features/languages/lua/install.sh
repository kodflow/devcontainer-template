#!/bin/bash
set -e

echo "========================================="
echo "Installing Lua Development Environment"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  GH_ARCH="x86_64" ;;
    aarch64) GH_ARCH="aarch64" ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

# Install Lua and LuaRocks
echo -e "${YELLOW}Installing Lua 5.4 and LuaRocks...${NC}"
sudo apt-get update && sudo apt-get install -y \
    lua5.4 \
    liblua5.4-dev \
    luarocks \
    curl

echo -e "${GREEN}✓ Lua $(lua5.4 -v 2>&1 | head -n 1) installed${NC}"
echo -e "${GREEN}✓ LuaRocks $(luarocks --version | head -n 1) installed${NC}"

# Install StyLua (formatter) from GitHub releases
echo -e "${YELLOW}Installing StyLua (formatter)...${NC}"
STYLUA_VERSION=$(curl -s --connect-timeout 5 --max-time 10 \
    "https://api.github.com/repos/JohnnyMorganz/StyLua/releases/latest" \
    | sed -n 's/.*"tag_name": *"v\?\([^"]*\)".*/\1/p' | head -n 1)
STYLUA_VERSION="${STYLUA_VERSION:-2.0.2}"

STYLUA_URL="https://github.com/JohnnyMorganz/StyLua/releases/download/v${STYLUA_VERSION}/stylua-v${STYLUA_VERSION}-linux-${GH_ARCH}.zip"
if curl -fsSL --connect-timeout 10 --max-time 60 -o /tmp/stylua.zip "$STYLUA_URL"; then
    sudo unzip -o /tmp/stylua.zip -d /usr/local/bin/
    sudo chmod +x /usr/local/bin/stylua
    rm -f /tmp/stylua.zip
    echo -e "${GREEN}✓ StyLua ${STYLUA_VERSION} installed${NC}"
else
    echo -e "${YELLOW}⚠ StyLua download failed${NC}"
fi

# Install Luacheck (linter) via LuaRocks
echo -e "${YELLOW}Installing Luacheck (linter)...${NC}"
if sudo luarocks install luacheck; then
    echo -e "${GREEN}✓ Luacheck installed${NC}"
else
    echo -e "${YELLOW}⚠ Luacheck installation failed${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Lua environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - $(lua5.4 -v 2>&1 | head -n 1)"
echo "  - $(luarocks --version | head -n 1)"
echo ""
echo "Development tools:"
echo "  - StyLua (formatter)"
echo "  - Luacheck (linter)"
echo ""
