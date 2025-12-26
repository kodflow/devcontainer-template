#!/bin/bash
set -e

echo "========================================="
echo "Installing C/C++ Development Environment"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Install C/C++ toolchain
echo -e "${YELLOW}Installing C/C++ toolchain...${NC}"
sudo apt-get update && sudo apt-get install -y \
    build-essential \
    gcc \
    g++ \
    gdb \
    clang \
    make \
    cmake \
    git \
    curl

GCC_VERSION=$(gcc --version | head -n 1)
CLANG_VERSION=$(clang --version | head -n 1)
CMAKE_VERSION=$(cmake --version | head -n 1)
MAKE_VERSION=$(make --version | head -n 1)

echo -e "${GREEN}✓ ${GCC_VERSION} installed${NC}"
echo -e "${GREEN}✓ ${CLANG_VERSION} installed${NC}"
echo -e "${GREEN}✓ ${CMAKE_VERSION} installed${NC}"
echo -e "${GREEN}✓ ${MAKE_VERSION} installed${NC}"

# ─────────────────────────────────────────────────────────────────────────────
# Install C++ Development Tools (latest versions)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Installing C++ development tools...${NC}"

# clang-format (formatter - mandatory per RULES.md)
echo -e "${YELLOW}Installing clang-format...${NC}"
sudo apt-get install -y clang-format
echo -e "${GREEN}✓ clang-format installed${NC}"

# clang-tidy (linter - mandatory per RULES.md)
echo -e "${YELLOW}Installing clang-tidy...${NC}"
sudo apt-get install -y clang-tidy
echo -e "${GREEN}✓ clang-tidy installed${NC}"

# ccache (compilation cache)
echo -e "${YELLOW}Installing ccache...${NC}"
sudo apt-get install -y ccache
echo -e "${GREEN}✓ ccache installed${NC}"

# ninja (fast build system)
echo -e "${YELLOW}Installing ninja-build...${NC}"
sudo apt-get install -y ninja-build
NINJA_VERSION=$(ninja --version)
echo -e "${GREEN}✓ ninja ${NINJA_VERSION} installed${NC}"

# Google Test (testing framework per RULES.md)
# libgtest-dev only provides sources - we need to compile the libraries
echo -e "${YELLOW}Installing Google Test...${NC}"
sudo apt-get install -y libgtest-dev

# Build Google Test libraries from source
if [ -d "/usr/src/gtest" ] || [ -d "/usr/src/googletest" ]; then
    GTEST_SRC=$([ -d "/usr/src/googletest" ] && echo "/usr/src/googletest" || echo "/usr/src/gtest")
    cd "$GTEST_SRC"
    sudo cmake -B build -DCMAKE_BUILD_TYPE=Release .
    sudo cmake --build build --parallel
    sudo cp build/lib/*.a /usr/lib/ 2>/dev/null || sudo cp build/*.a /usr/lib/ 2>/dev/null || true
    cd - > /dev/null
    echo -e "${GREEN}✓ Google Test installed (headers + libraries)${NC}"
else
    echo -e "${YELLOW}⚠ Google Test sources not found, headers only${NC}"
fi

# cppcheck (static analysis)
echo -e "${YELLOW}Installing cppcheck...${NC}"
sudo apt-get install -y cppcheck
echo -e "${GREEN}✓ cppcheck installed${NC}"

# valgrind (memory checker)
echo -e "${YELLOW}Installing valgrind...${NC}"
sudo apt-get install -y valgrind
echo -e "${GREEN}✓ valgrind installed${NC}"

echo -e "${GREEN}✓ C++ development tools installed${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}C/C++ environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${GCC_VERSION}"
echo "  - ${CLANG_VERSION}"
echo "  - ${CMAKE_VERSION}"
echo "  - ${MAKE_VERSION}"
echo "  - gdb (debugger)"
echo ""
echo "Development tools:"
echo "  - clang-format (formatter)"
echo "  - clang-tidy (linter)"
echo "  - ccache (compilation cache)"
echo "  - ninja ${NINJA_VERSION} (build system)"
echo "  - Google Test (testing)"
echo "  - cppcheck (static analysis)"
echo "  - valgrind (memory checker)"
echo ""
