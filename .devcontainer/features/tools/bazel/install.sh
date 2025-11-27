#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Retry function with exponential backoff
retry_exponential() {
    local max_attempts=$1
    local initial_delay=$2
    shift 2
    local attempt=1
    local delay=$initial_delay
    local exit_code=0

    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            if [ $attempt -gt 1 ]; then
                log_success "Command succeeded on attempt $attempt"
            fi
            return 0
        fi

        exit_code=$?

        if [ $attempt -lt $max_attempts ]; then
            log_warning "Command failed, retrying in ${delay}s... (attempt $attempt/$max_attempts)"
            sleep "$delay"
            delay=$((delay * 2))
        else
            log_error "Command failed after $max_attempts attempts"
        fi

        ((attempt++))
    done

    return $exit_code
}

# apt-get with retry and lock handling
apt_get_retry() {
    local max_attempts=5
    local attempt=1
    local delay=10

    while [ $attempt -le $max_attempts ]; do
        # Wait for apt locks to be released
        local lock_wait=0
        while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
              sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
              sudo fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
            if [ $lock_wait -eq 0 ]; then
                log_warning "Waiting for apt locks to be released..."
            fi
            sleep 2
            lock_wait=$((lock_wait + 2))

            if [ $lock_wait -ge 60 ]; then
                log_warning "Forcing apt lock release after 60s wait"
                sudo rm -f /var/lib/dpkg/lock-frontend
                sudo rm -f /var/lib/apt/lists/lock
                sudo rm -f /var/cache/apt/archives/lock
                sudo dpkg --configure -a || true
                break
            fi
        done

        # Try apt-get command
        if sudo apt-get "$@"; then
            if [ $attempt -gt 1 ]; then
                log_success "apt-get succeeded on attempt $attempt"
            fi
            return 0
        fi

        exit_code=$?

        if [ $attempt -lt $max_attempts ]; then
            log_warning "apt-get failed, running update and retrying in ${delay}s... (attempt $attempt/$max_attempts)"
            sudo apt-get update --fix-missing || true
            sudo dpkg --configure -a || true
            sleep "$delay"
        else
            log_error "apt-get failed after $max_attempts attempts"
        fi

        ((attempt++))
    done

    return $exit_code
}

# Download with retry and resume support
download_retry() {
    local url=$1
    local output=$2
    shift 2

    log_info "Downloading: $url"

    retry_exponential 5 3 curl -fsSL \
        --connect-timeout 30 \
        --max-time 300 \
        --retry 3 \
        --retry-delay 5 \
        --retry-max-time 60 \
        -C - \
        -o "$output" \
        "$url"
}

# Safe directory creation
mkdir_safe() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || sudo mkdir -p "$dir"

        if [ "$(whoami)" = "vscode" ]; then
            sudo chown -R vscode:vscode "$dir" 2>/dev/null || true
        fi
    fi
}

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
