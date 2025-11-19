#!/bin/bash
set -e

# Load utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils.sh"

echo "========================================="
echo "Installing Bazel Build System"
echo "========================================="

# Get options from feature
BAZELISK_VERSION="${BAZELISKVERSION:-v1.27.0}"
BUILDTOOLS_VERSION="${BUILDTOOLSVERSION:-v8.2.1}"

# Environment variables
export BAZEL_USER_ROOT="${BAZEL_USER_ROOT:-/home/vscode/.cache/bazel}"

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH_SUFFIX="amd64"
        ;;
    aarch64|arm64)
        ARCH_SUFFIX="arm64"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

log_info "Detected architecture: $ARCH_SUFFIX"

# Install dependencies
log_info "Installing dependencies..."
apt_get_retry update
apt_get_retry install -y \
    curl \
    ca-certificates \
    gnupg \
    python3 \
    unzip \
    zip

# Install Bazelisk (Bazel version manager)
log_info "Installing Bazelisk ${BAZELISK_VERSION}..."
BAZELISK_URL="https://github.com/bazelbuild/bazelisk/releases/download/${BAZELISK_VERSION}/bazelisk-linux-${ARCH_SUFFIX}"
download_retry "$BAZELISK_URL" "/tmp/bazelisk"
chmod +x /tmp/bazelisk
sudo mv /tmp/bazelisk /usr/local/bin/bazelisk
sudo ln -sf /usr/local/bin/bazelisk /usr/local/bin/bazel
log_success "Bazelisk ${BAZELISK_VERSION} installed"

# Install Buildifier (BUILD file formatter)
log_info "Installing Buildifier ${BUILDTOOLS_VERSION}..."
BUILDIFIER_URL="https://github.com/bazelbuild/buildtools/releases/download/${BUILDTOOLS_VERSION}/buildifier-linux-${ARCH_SUFFIX}"
download_retry "$BUILDIFIER_URL" "/tmp/buildifier"
chmod +x /tmp/buildifier
sudo mv /tmp/buildifier /usr/local/bin/buildifier
log_success "Buildifier ${BUILDTOOLS_VERSION} installed"

# Install Buildozer (BUILD file editor)
log_info "Installing Buildozer ${BUILDTOOLS_VERSION}..."
BUILDOZER_URL="https://github.com/bazelbuild/buildtools/releases/download/${BUILDTOOLS_VERSION}/buildozer-linux-${ARCH_SUFFIX}"
download_retry "$BUILDOZER_URL" "/tmp/buildozer"
chmod +x /tmp/buildozer
sudo mv /tmp/buildozer /usr/local/bin/buildozer
log_success "Buildozer ${BUILDTOOLS_VERSION} installed"

# Create Bazel cache directory
mkdir_safe "$BAZEL_USER_ROOT"

# Verify installations
BAZELISK_INSTALLED=$(bazelisk version 2>&1 || echo "Bazelisk")
BUILDIFIER_INSTALLED=$(buildifier --version 2>&1 | head -1 || echo "buildifier")
BUILDOZER_INSTALLED=$(buildozer --help 2>&1 | head -1 | grep -o "buildozer" || echo "buildozer")

echo ""
log_success "========================================="
log_success "Bazel environment installed successfully!"
log_success "========================================="
echo ""
echo "Installed components:"
echo "  - ${BAZELISK_INSTALLED}"
echo "  - ${BUILDIFIER_INSTALLED}"
echo "  - ${BUILDOZER_INSTALLED}"
echo ""
echo "Cache directory:"
echo "  - BAZEL_USER_ROOT: $BAZEL_USER_ROOT"
echo ""
echo "Supported languages:"
echo "  - Java"
echo "  - C/C++"
echo "  - Go"
echo "  - Python"
echo "  - Rust"
echo "  - Android"
echo "  - iOS"
echo "  - Kotlin"
echo "  - Scala"
echo ""
echo "Quick start:"
echo "  - Create a WORKSPACE file in your project root"
echo "  - Create BUILD files for your targets"
echo "  - Run: bazel build //..."
echo "  - Format BUILD files: buildifier -r ."
echo "  - Edit BUILD files: buildozer 'add deps //path/to:dep' //target:name"
echo ""
echo "Documentation: https://bazel.build"
echo ""

# Exit successfully
exit 0
