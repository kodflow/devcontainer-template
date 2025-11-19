#!/bin/bash
set -e

echo "========================================="
echo "Installing Ruby Development Environment"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Environment variables
export RBENV_ROOT="${RBENV_ROOT:-/home/vscode/.cache/rbenv}"
export RUBY_VERSION="${RUBY_VERSION:-3.3}"
export GEM_HOME="${GEM_HOME:-/home/vscode/.cache/gems}"
export BUNDLE_PATH="${BUNDLE_PATH:-/home/vscode/.cache/bundle}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    git \
    curl \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    autoconf \
    bison \
    build-essential \
    libyaml-dev \
    libreadline-dev \
    libncurses5-dev \
    libffi-dev \
    libgdbm-dev

# Install rbenv (Ruby Version Manager)
echo -e "${YELLOW}Installing rbenv...${NC}"
git clone https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"

# Setup rbenv
export PATH="$RBENV_ROOT/bin:$PATH"
eval "$(rbenv init -)"

# Install Ruby (latest stable of specified major.minor)
echo -e "${YELLOW}Installing Ruby ${RUBY_VERSION}...${NC}"
LATEST_RUBY=$(rbenv install --list | grep -E "^\s*${RUBY_VERSION}\.[0-9]+$" | tail -1 | xargs)
rbenv install "$LATEST_RUBY"
rbenv global "$LATEST_RUBY"

RUBY_INSTALLED=$(ruby --version)
echo -e "${GREEN}✓ ${RUBY_INSTALLED} installed${NC}"

# Update RubyGems
echo -e "${YELLOW}Updating RubyGems...${NC}"
gem update --system
GEM_VERSION=$(gem --version)
echo -e "${GREEN}✓ RubyGems ${GEM_VERSION}${NC}"

# Install Bundler
echo -e "${YELLOW}Installing Bundler...${NC}"
gem install bundler
BUNDLER_VERSION=$(bundler --version)
echo -e "${GREEN}✓ ${BUNDLER_VERSION}${NC}"

# Install Rails
echo -e "${YELLOW}Installing Rails...${NC}"
gem install rails
RAILS_VERSION=$(rails --version)
echo -e "${GREEN}✓ ${RAILS_VERSION}${NC}"

# Install development tools
echo -e "${YELLOW}Installing development tools...${NC}"

# Rubocop (linter)
gem install rubocop
echo -e "${GREEN}✓ rubocop installed${NC}"

# Rubocop-rails
gem install rubocop-rails
echo -e "${GREEN}✓ rubocop-rails installed${NC}"

# Solargraph (language server)
gem install solargraph
echo -e "${GREEN}✓ solargraph installed${NC}"

# Pry (debugger)
gem install pry
echo -e "${GREEN}✓ pry installed${NC}"

# RSpec (testing framework)
gem install rspec
echo -e "${GREEN}✓ rspec installed${NC}"

# Create cache directories
mkdir -p "$GEM_HOME"
mkdir -p "$BUNDLE_PATH"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Ruby environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - rbenv (Ruby Version Manager)"
echo "  - ${RUBY_INSTALLED}"
echo "  - RubyGems ${GEM_VERSION}"
echo "  - ${BUNDLER_VERSION}"
echo "  - ${RAILS_VERSION}"
echo "  - rubocop (linter)"
echo "  - rubocop-rails"
echo "  - solargraph (language server)"
echo "  - pry (debugger)"
echo "  - rspec (testing framework)"
echo ""
echo "Cache directories:"
echo "  - rbenv: $RBENV_ROOT"
echo "  - gems: $GEM_HOME"
echo "  - bundler: $BUNDLE_PATH"
