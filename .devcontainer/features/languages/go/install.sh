#!/bin/bash
set -e

echo "========================================="
echo "Installing Go Development Environment"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Environment variables
export GO_VERSION="${GO_VERSION:-latest}"
export GOROOT="${GOROOT:-/usr/local/go}"
export GOPATH="${GOPATH:-/home/vscode/.cache/go}"
export GOCACHE="${GOCACHE:-/home/vscode/.cache/go-build}"
export GOMODCACHE="${GOMODCACHE:-/home/vscode/.cache/go/pkg/mod}"
export PATH="$GOROOT/bin:$GOPATH/bin:$PATH"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    curl \
    git \
    make \
    gcc \
    build-essential

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        GO_ARCH="amd64"
        ;;
    aarch64|arm64)
        GO_ARCH="arm64"
        ;;
    armv7l)
        GO_ARCH="armv6l"
        ;;
    *)
        echo -e "${RED}✗ Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

# Get latest Go version if requested
if [ "$GO_VERSION" = "latest" ]; then
    echo -e "${YELLOW}Fetching latest Go version...${NC}"
    GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1 | sed 's/go//')
fi

# Download and install Go
echo -e "${YELLOW}Installing Go ${GO_VERSION} for ${GO_ARCH}...${NC}"
GO_TARBALL="go${GO_VERSION}.linux-${GO_ARCH}.tar.gz"
GO_URL="https://dl.google.com/go/${GO_TARBALL}"

# Download Go tarball
curl -fsSL --retry 3 --retry-delay 5 -o "/tmp/${GO_TARBALL}" "$GO_URL"

# Remove any existing Go installation
if [ -d "$GOROOT" ]; then
    echo -e "${YELLOW}Removing existing Go installation...${NC}"
    sudo rm -rf "$GOROOT"
fi

# Extract to /usr/local
sudo tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"

# Clean up
rm "/tmp/${GO_TARBALL}"

GO_INSTALLED=$(go version)
echo -e "${GREEN}✓ ${GO_INSTALLED} installed${NC}"

# Create necessary directories
mkdir -p "$GOPATH/bin"
mkdir -p "$GOPATH/pkg"
mkdir -p "$GOPATH/src"
mkdir -p "$GOCACHE"
mkdir -p "$GOMODCACHE"

# Install Go development tools
echo -e "${YELLOW}Installing Go development tools...${NC}"

# gopls (Go language server)
go install golang.org/x/tools/gopls@latest
echo -e "${GREEN}✓ gopls installed${NC}"

# golangci-lint (linter aggregator)
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b "$GOPATH/bin"
echo -e "${GREEN}✓ golangci-lint installed${NC}"

# gofumpt (stricter gofmt)
go install mvdan.cc/gofumpt@latest
echo -e "${GREEN}✓ gofumpt installed${NC}"

# goimports (import management)
go install golang.org/x/tools/cmd/goimports@latest
echo -e "${GREEN}✓ goimports installed${NC}"

# delve (debugger)
go install github.com/go-delve/delve/cmd/dlv@latest
echo -e "${GREEN}✓ delve installed${NC}"

# gotests (test generator)
go install github.com/cweill/gotests/gotests@latest
echo -e "${GREEN}✓ gotests installed${NC}"

# gomodifytags (struct tag editor)
go install github.com/fatih/gomodifytags@latest
echo -e "${GREEN}✓ gomodifytags installed${NC}"

# impl (interface implementation generator)
go install github.com/josharian/impl@latest
echo -e "${GREEN}✓ impl installed${NC}"

# staticcheck (static analysis)
go install honnef.co/go/tools/cmd/staticcheck@latest
echo -e "${GREEN}✓ staticcheck installed${NC}"

# air (live reload)
go install github.com/air-verse/air@latest
echo -e "${GREEN}✓ air installed${NC}"

# Detect architecture for KTN-Linter
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        KTN_ARCH="amd64"
        ;;
    aarch64|arm64)
        KTN_ARCH="arm64"
        ;;
    armv7l)
        KTN_ARCH="arm"
        ;;
    *)
        echo -e "${YELLOW}⚠ Unsupported architecture for KTN-Linter: $ARCH${NC}"
        KTN_ARCH=""
        ;;
esac

# KTN-Linter (Kodflow custom linter)
if [ -n "$KTN_ARCH" ]; then
    echo -e "${YELLOW}Installing KTN-Linter...${NC}"
    KTN_VERSION="v1.3.39"
    KTN_URL="https://github.com/kodflow/ktn-linter/releases/download/${KTN_VERSION}/ktn-linter-linux-${KTN_ARCH}"
    curl -fsSL --retry 3 --retry-delay 5 -o /tmp/ktn-linter "$KTN_URL"
    chmod +x /tmp/ktn-linter
    sudo mv /tmp/ktn-linter /usr/local/bin/ktn-linter
    echo -e "${GREEN}✓ KTN-Linter ${KTN_VERSION} installed${NC}"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Go environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${GO_INSTALLED}"
echo "  - gopls (language server)"
echo "  - golangci-lint (linter)"
echo "  - gofumpt (formatter)"
echo "  - goimports (import tool)"
echo "  - delve (debugger)"
echo "  - gotests (test generator)"
echo "  - gomodifytags (tag editor)"
echo "  - impl (interface generator)"
echo "  - staticcheck (static analyzer)"
echo "  - air (live reload)"
if [ -n "$KTN_ARCH" ]; then
    echo "  - ktn-linter ${KTN_VERSION:-v1.3.39} (Kodflow custom linter)"
fi
echo ""
echo "Environment variables:"
echo "  - GOROOT: $GOROOT"
echo "  - GOPATH: $GOPATH"
echo "  - GOCACHE: $GOCACHE"
echo "  - GOMODCACHE: $GOMODCACHE"
echo ""
