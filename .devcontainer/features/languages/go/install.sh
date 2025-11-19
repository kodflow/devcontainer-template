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
export GVM_ROOT="${GVM_ROOT:-/home/vscode/.cache/gvm}"
export GO_VERSION="${GO_VERSION:-latest}"
export GOPATH="${GOPATH:-/home/vscode/.cache/go}"
export GOCACHE="${GOCACHE:-/home/vscode/.cache/go-build}"
export GOMODCACHE="${GOMODCACHE:-/home/vscode/.cache/go/pkg/mod}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    curl \
    git \
    make \
    binutils \
    bison \
    gcc \
    build-essential

# Install GVM (Go Version Manager)
echo -e "${YELLOW}Installing GVM...${NC}"
bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)

# Source GVM
[[ -s "$HOME/.gvm/scripts/gvm" ]] && source "$HOME/.gvm/scripts/gvm"

# Get latest Go version
if [ "$GO_VERSION" = "latest" ]; then
    echo -e "${YELLOW}Fetching latest Go version...${NC}"
    GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1)
fi

echo -e "${YELLOW}Installing Go ${GO_VERSION}...${NC}"

# Install Go binary directly (GVM can be tricky for latest versions)
GO_ARCHIVE="${GO_VERSION}.linux-amd64.tar.gz"
curl -OL "https://go.dev/dl/${GO_ARCHIVE}"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "$GO_ARCHIVE"
rm "$GO_ARCHIVE"

# Setup Go environment
export PATH="/usr/local/go/bin:$GOPATH/bin:$PATH"

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
go install github.com/cosmtrek/air@latest
echo -e "${GREEN}✓ air installed${NC}"

# KTN-Linter (Kodflow custom linter)
echo -e "${YELLOW}Installing KTN-Linter...${NC}"
KTN_VERSION="v1.3.39"
KTN_URL="https://github.com/kodflow/ktn-linter/releases/download/${KTN_VERSION}/ktn-linter-linux-amd64"
curl -fsSL --retry 3 --retry-delay 5 -o /tmp/ktn-linter "$KTN_URL"
chmod +x /tmp/ktn-linter
sudo mv /tmp/ktn-linter /usr/local/bin/ktn-linter
echo -e "${GREEN}✓ KTN-Linter ${KTN_VERSION} installed${NC}"

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
echo "  - ktn-linter ${KTN_VERSION} (Kodflow custom linter)"
echo ""
echo "Cache directories:"
echo "  - GOPATH: $GOPATH"
echo "  - GOCACHE: $GOCACHE"
echo "  - GOMODCACHE: $GOMODCACHE"
