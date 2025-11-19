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

# Environment variables
export CCACHE_DIR="${CCACHE_DIR:-/home/vscode/.cache/ccache}"
export CONAN_USER_HOME="${CONAN_USER_HOME:-/home/vscode/.cache/conan}"
export VCPKG_ROOT="${VCPKG_ROOT:-/home/vscode/.cache/vcpkg}"
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-4}"

# Install dependencies
echo -e "${YELLOW}Installing C/C++ toolchain...${NC}"
sudo apt-get update && sudo apt-get install -y \
    build-essential \
    gcc \
    g++ \
    gdb \
    clang \
    clang-format \
    clang-tidy \
    lldb \
    make \
    cmake \
    ninja-build \
    ccache \
    pkg-config \
    autoconf \
    automake \
    libtool \
    valgrind \
    git \
    curl \
    zip \
    unzip \
    tar

GCC_VERSION=$(gcc --version | head -n 1)
CLANG_VERSION=$(clang --version | head -n 1)
echo -e "${GREEN}✓ ${GCC_VERSION} installed${NC}"
echo -e "${GREEN}✓ ${CLANG_VERSION} installed${NC}"

# Detect architecture for CMake
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        CMAKE_ARCH="x86_64"
        ;;
    aarch64|arm64)
        CMAKE_ARCH="aarch64"
        ;;
    *)
        echo -e "${RED}Unsupported architecture for CMake: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Detected architecture: $ARCH (CMake arch: $CMAKE_ARCH)${NC}"

# Install CMake (latest)
echo -e "${YELLOW}Installing latest CMake...${NC}"
CMAKE_VERSION="3.28.1"
wget https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${CMAKE_ARCH}.sh
sudo sh cmake-${CMAKE_VERSION}-linux-${CMAKE_ARCH}.sh --prefix=/usr/local --skip-license
rm cmake-${CMAKE_VERSION}-linux-${CMAKE_ARCH}.sh
CMAKE_INSTALLED=$(cmake --version | head -n 1)
echo -e "${GREEN}✓ ${CMAKE_INSTALLED} installed${NC}"

# Install Conan (C++ package manager)
echo -e "${YELLOW}Installing Conan...${NC}"
sudo apt-get install -y python3-pip python3-venv
pip3 install --break-system-packages --ignore-installed conan
CONAN_VERSION=$(conan --version)
echo -e "${GREEN}✓ ${CONAN_VERSION} installed${NC}"

# Install vcpkg (Microsoft C++ package manager)
echo -e "${YELLOW}Installing vcpkg...${NC}"
git clone https://github.com/Microsoft/vcpkg.git "$VCPKG_ROOT"
"$VCPKG_ROOT/bootstrap-vcpkg.sh"
echo -e "${GREEN}✓ vcpkg installed${NC}"

# Create cache directories
mkdir -p "$CCACHE_DIR"
mkdir -p "$CONAN_USER_HOME"

# Configure ccache
ccache --set-config=max_size=5G
echo -e "${GREEN}✓ ccache configured (5GB cache)${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}C/C++ environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${GCC_VERSION}"
echo "  - ${CLANG_VERSION}"
echo "  - ${CMAKE_INSTALLED}"
echo "  - gdb (debugger)"
echo "  - lldb (LLVM debugger)"
echo "  - clang-format (formatter)"
echo "  - clang-tidy (linter)"
echo "  - ninja (build system)"
echo "  - ccache (compiler cache)"
echo "  - ${CONAN_VERSION}"
echo "  - vcpkg (package manager)"
echo "  - valgrind (memory debugger)"
echo ""
echo "Cache directories:"
echo "  - ccache: $CCACHE_DIR"
echo "  - Conan: $CONAN_USER_HOME"
echo "  - vcpkg: $VCPKG_ROOT"
