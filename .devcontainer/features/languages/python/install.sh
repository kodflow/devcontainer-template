#!/bin/bash
set -e

echo "========================================="
echo "Installing Python Development Environment"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Environment variables
export PYENV_ROOT="${PYENV_ROOT:-/home/vscode/.cache/pyenv}"
export PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
export PIP_CACHE_DIR="${PIP_CACHE_DIR:-/home/vscode/.cache/pip}"
export POETRY_CACHE_DIR="${POETRY_CACHE_DIR:-/home/vscode/.cache/poetry}"
export PIPENV_CACHE_DIR="${PIPENV_CACHE_DIR:-/home/vscode/.cache/pipenv}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    curl \
    git \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libxml2-dev \
    libxmlsec1-dev \
    libffi-dev \
    liblzma-dev

# Install pyenv (Python Version Manager)
echo -e "${YELLOW}Installing pyenv...${NC}"
curl https://pyenv.run | bash

# Setup pyenv
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Install Python (latest stable of specified major.minor)
echo -e "${YELLOW}Installing Python ${PYTHON_VERSION}...${NC}"
LATEST_PYTHON=$(pyenv install --list | grep -E "^\s*${PYTHON_VERSION}\.[0-9]+$" | tail -1 | xargs)
pyenv install "$LATEST_PYTHON"
pyenv global "$LATEST_PYTHON"

PYTHON_INSTALLED=$(python --version)
echo -e "${GREEN}✓ ${PYTHON_INSTALLED} installed${NC}"

# Upgrade pip
echo -e "${YELLOW}Upgrading pip...${NC}"
python -m pip install --break-system-packages --ignore-installed --upgrade pip
PIP_VERSION=$(pip --version)
echo -e "${GREEN}✓ ${PIP_VERSION}${NC}"

# Install Poetry
echo -e "${YELLOW}Installing Poetry...${NC}"
curl -sSL https://install.python-poetry.org | python3 -
export PATH="/home/vscode/.local/bin:$PATH"
POETRY_VERSION=$(poetry --version)
echo -e "${GREEN}✓ ${POETRY_VERSION}${NC}"

# Install Pipenv
echo -e "${YELLOW}Installing Pipenv...${NC}"
pip install --break-system-packages --ignore-installed pipenv
PIPENV_VERSION=$(pipenv --version)
echo -e "${GREEN}✓ ${PIPENV_VERSION}${NC}"

# Install common development tools
echo -e "${YELLOW}Installing development tools...${NC}"

# Black (code formatter)
pip install --break-system-packages --ignore-installed black
echo -e "${GREEN}✓ black installed${NC}"

# isort (import sorter)
pip install --break-system-packages --ignore-installed isort
echo -e "${GREEN}✓ isort installed${NC}"

# Flake8 (linter)
pip install --break-system-packages --ignore-installed flake8
echo -e "${GREEN}✓ flake8 installed${NC}"

# pylint (linter)
pip install --break-system-packages --ignore-installed pylint
echo -e "${GREEN}✓ pylint installed${NC}"

# mypy (type checker)
pip install --break-system-packages --ignore-installed mypy
echo -e "${GREEN}✓ mypy installed${NC}"

# pytest (testing framework)
pip install --break-system-packages --ignore-installed pytest pytest-cov pytest-asyncio
echo -e "${GREEN}✓ pytest installed${NC}"

# ipython (enhanced interactive shell)
pip install --break-system-packages --ignore-installed ipython
echo -e "${GREEN}✓ ipython installed${NC}"

# virtualenv
pip install --break-system-packages --ignore-installed virtualenv
echo -e "${GREEN}✓ virtualenv installed${NC}"

# Create cache directories
mkdir -p "$PIP_CACHE_DIR"
mkdir -p "$POETRY_CACHE_DIR"
mkdir -p "$PIPENV_CACHE_DIR"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Python environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - pyenv (Python Version Manager)"
echo "  - ${PYTHON_INSTALLED}"
echo "  - pip (upgraded)"
echo "  - Poetry"
echo "  - Pipenv"
echo "  - black (formatter)"
echo "  - isort (import sorter)"
echo "  - flake8 (linter)"
echo "  - pylint (linter)"
echo "  - mypy (type checker)"
echo "  - pytest (testing framework)"
echo "  - ipython (interactive shell)"
echo "  - virtualenv"
echo ""
echo "Cache directories:"
echo "  - pyenv: $PYENV_ROOT"
echo "  - pip: $PIP_CACHE_DIR"
echo "  - Poetry: $POETRY_CACHE_DIR"
echo "  - Pipenv: $PIPENV_CACHE_DIR"
