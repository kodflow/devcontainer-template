#!/bin/bash
# ============================================================================
# Universal Claude Code Installation Script
# ============================================================================
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kodflow/devcontainer-template/main/.devcontainer/install.sh | bash
#
# Or with custom target:
#   DC_TARGET=/path/to/project curl -fsSL ... | bash
#
# Or minimal installation (no docs):
#   curl -fsSL ... | bash -s -- --minimal
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================
REPO="kodflow/devcontainer-template"
BRANCH="main"
BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
API="https://api.github.com/repos/${REPO}/contents"

# Parse arguments
INSTALL_MINIMAL=false
for arg in "$@"; do
    case "$arg" in
        --minimal) INSTALL_MINIMAL=true ;;
        --help)
            cat <<EOF
Universal Claude Code Installation Script

Usage:
  curl -fsSL URL | bash                    # Full installation
  curl -fsSL URL | bash -s -- --minimal    # Skip documentation (155+ files)
  DC_TARGET=/path curl -fsSL URL | bash    # Custom target directory

Options:
  --minimal    Skip documentation installation (saves ~2.4MB, 155 files)
  --help       Show this help message

Installation Locations:
  Host Machine:    \$HOME/.claude/
  DevContainer:    /workspace/.devcontainer/images/.claude/

What Gets Installed:
  - Claude CLI (if not already installed)
  - 35 specialist agents
  - 11 slash commands (/git, /review, /plan, etc.)
  - 11 hook scripts (security, lint, format, etc.)
  - 155+ design patterns (unless --minimal)
  - Configuration files (settings.json, etc.)

Total: 239 files (~3.2MB) or 84 files (~0.8MB) with --minimal
EOF
            exit 0
            ;;
    esac
done

# ============================================================================
# Environment Detection
# ============================================================================
detect_environment() {
    echo "═══════════════════════════════════════════════"
    echo "  Universal Claude Code Installation"
    echo "═══════════════════════════════════════════════"
    echo ""

    # OS Detection
    case "$(uname -s)" in
        Linux*)  OS="linux" ;;
        Darwin*) OS="darwin" ;;
        MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
        *)       OS="unknown" ;;
    esac

    # Architecture Detection
    case "$(uname -m)" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *)            ARCH="unknown" ;;
    esac

    # Container Detection
    IS_CONTAINER=false
    if [ -f /.dockerenv ]; then
        IS_CONTAINER=true
    fi

    # Home Directory Detection
    HOME_DIR="${HOME:-/home/vscode}"

    # Target Directory (override via DC_TARGET env var)
    if [ "$IS_CONTAINER" = true ]; then
        TARGET_DIR="${DC_TARGET:-/workspace/.devcontainer/images/.claude}"
    else
        TARGET_DIR="${DC_TARGET:-$HOME_DIR/.claude}"
    fi

    echo "→ Environment Detection:"
    echo "  OS:         $OS"
    echo "  Arch:       $ARCH"
    echo "  Container:  $IS_CONTAINER"
    echo "  Home:       $HOME_DIR"
    echo "  Target:     $TARGET_DIR"
    echo ""
}

# ============================================================================
# Safe Download with Validation
# ============================================================================
safe_download() {
    local url="$1"
    local output="$2"
    local temp_file
    temp_file=$(mktemp)

    # Download with HTTP code
    local http_code
    http_code=$(curl -sL -w "%{http_code}" -o "$temp_file" "$url" 2>/dev/null || echo "000")

    # Validate download
    if [ "$http_code" != "200" ]; then
        rm -f "$temp_file"
        return 1
    fi

    # Check for HTML error pages (404 disguised as 200)
    if head -1 "$temp_file" 2>/dev/null | grep -qE "^404|^<!DOCTYPE|^<html"; then
        rm -f "$temp_file"
        return 1
    fi

    # Check not empty
    if [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        return 1
    fi

    # All good, move to destination
    mkdir -p "$(dirname "$output")"
    mv "$temp_file" "$output"
    return 0
}

# ============================================================================
# Install Claude CLI
# ============================================================================
install_claude_cli() {
    if command -v claude &>/dev/null; then
        echo "→ Claude CLI:"
        echo "  ✓ Already installed ($(command -v claude))"
        return 0
    fi

    echo "→ Installing Claude CLI..."

    # Method 1: npm (if available)
    if command -v npm &>/dev/null; then
        if npm install -g @anthropic-ai/claude-code 2>/dev/null; then
            echo "  ✓ Installed via npm"
            return 0
        fi
    fi

    # Method 2: Official installer
    if curl -fsSL https://claude.ai/install.sh | sh 2>/dev/null; then
        echo "  ✓ Installed via official script"
        return 0
    fi

    echo "  ⚠ Installation failed (may already be in PATH)"
    return 0  # Non-blocking
}

# ============================================================================
# Download Agents (35 files)
# ============================================================================
download_agents() {
    local target_dir="$1"
    mkdir -p "$target_dir/agents"

    echo "→ Downloading agents..."

    # Discover via GitHub API
    local agents
    agents=$(curl -sL "$API/.devcontainer/images/.claude/agents" 2>/dev/null | jq -r '.[].name' 2>/dev/null | grep '\.md$' || echo "")

    if [ -z "$agents" ]; then
        echo "  ⚠ Could not discover agents via API, using fallback"
        # Fallback: known agents list (truncated for brevity)
        agents="developer-orchestrator.md developer-specialist-go.md developer-specialist-python.md"
    fi

    local count=0
    local failed=0

    for agent in $agents; do
        if safe_download "$BASE/.devcontainer/images/.claude/agents/$agent" "$target_dir/agents/$agent"; then
            count=$((count + 1))
        else
            failed=$((failed + 1))
        fi
    done

    echo "  ✓ Downloaded $count agents"
    [ $failed -gt 0 ] && echo "  ⚠ Failed: $failed agents"
}

# ============================================================================
# Download Commands (11 files)
# ============================================================================
download_commands() {
    local target_dir="$1"
    mkdir -p "$target_dir/commands"

    echo "→ Downloading commands..."

    # Discover via GitHub API
    local commands
    commands=$(curl -sL "$API/.devcontainer/images/.claude/commands" 2>/dev/null | jq -r '.[].name' 2>/dev/null | grep '\.md$' || echo "")

    if [ -z "$commands" ]; then
        echo "  ⚠ Could not discover commands via API, using fallback"
        commands="git.md review.md plan.md do.md search.md update.md"
    fi

    local count=0
    local failed=0

    for cmd in $commands; do
        if safe_download "$BASE/.devcontainer/images/.claude/commands/$cmd" "$target_dir/commands/$cmd"; then
            count=$((count + 1))
        else
            failed=$((failed + 1))
        fi
    done

    echo "  ✓ Downloaded $count commands"
    [ $failed -gt 0 ] && echo "  ⚠ Failed: $failed commands"
}

# ============================================================================
# Download Scripts (11 files)
# ============================================================================
download_scripts() {
    local target_dir="$1"
    mkdir -p "$target_dir/scripts"

    echo "→ Downloading scripts..."

    # Discover via GitHub API
    local scripts
    scripts=$(curl -sL "$API/.devcontainer/images/.claude/scripts" 2>/dev/null | jq -r '.[].name' 2>/dev/null | grep '\.sh$' || echo "")

    if [ -z "$scripts" ]; then
        echo "  ⚠ Could not discover scripts via API, using fallback"
        scripts="format.sh lint.sh security.sh test.sh"
    fi

    local count=0
    local failed=0

    for script in $scripts; do
        if safe_download "$BASE/.devcontainer/images/.claude/scripts/$script" "$target_dir/scripts/$script"; then
            chmod +x "$target_dir/scripts/$script"
            count=$((count + 1))
        else
            failed=$((failed + 1))
        fi
    done

    echo "  ✓ Downloaded $count scripts"
    [ $failed -gt 0 ] && echo "  ⚠ Failed: $failed scripts"
}

# ============================================================================
# Download Documentation (155+ files) - OPTIONAL
# ============================================================================
download_docs() {
    local target_dir="$1"

    if [ "$INSTALL_MINIMAL" = true ]; then
        echo "→ Skipping documentation (--minimal mode)"
        return 0
    fi

    mkdir -p "$target_dir/docs"

    echo "→ Downloading documentation (this may take a moment)..."

    # Download root docs files
    local root_docs="CLAUDE.md README.md TEMPLATE-PATTERN.md TEMPLATE-README.md .markdownlint.json"
    local root_count=0

    for file in $root_docs; do
        if safe_download "$BASE/.devcontainer/images/.claude/docs/$file" "$target_dir/docs/$file"; then
            root_count=$((root_count + 1))
        fi
    done

    # Download category directories (20 categories)
    local categories
    categories=$(curl -sL "$API/.devcontainer/images/.claude/docs" 2>/dev/null | jq -r '.[] | select(.type == "dir") | .name' 2>/dev/null || echo "")

    if [ -z "$categories" ]; then
        echo "  ⚠ Could not discover doc categories, skipping patterns"
        return 0
    fi

    local pattern_count=0
    local failed=0

    for category in $categories; do
        mkdir -p "$target_dir/docs/$category"

        # Download all .md files in category
        local category_files
        category_files=$(curl -sL "$API/.devcontainer/images/.claude/docs/$category" 2>/dev/null | jq -r '.[].name' 2>/dev/null | grep '\.md$' || echo "")

        for file in $category_files; do
            if safe_download "$BASE/.devcontainer/images/.claude/docs/$category/$file" "$target_dir/docs/$category/$file"; then
                pattern_count=$((pattern_count + 1))
            else
                failed=$((failed + 1))
            fi
        done
    done

    echo "  ✓ Downloaded $root_count root files"
    echo "  ✓ Downloaded $pattern_count pattern files"
    [ $failed -gt 0 ] && echo "  ⚠ Failed: $failed files"
}

# ============================================================================
# Download Configuration Files
# ============================================================================
download_configs() {
    local target_dir="$1"

    echo "→ Downloading configurations..."

    local count=0

    if safe_download "$BASE/.devcontainer/images/.claude/settings.json" "$target_dir/settings.json"; then
        count=$((count + 1))
    fi

    if safe_download "$BASE/.devcontainer/images/.claude/.claude.json" "$target_dir/.claude.json"; then
        count=$((count + 1))
    fi

    # Download CLAUDE.md if not in container (host installation)
    if [ "$IS_CONTAINER" = false ] && [ ! -f "$HOME_DIR/CLAUDE.md" ]; then
        if safe_download "$BASE/CLAUDE.md" "$HOME_DIR/CLAUDE.md"; then
            echo "  ✓ Downloaded CLAUDE.md to $HOME_DIR/"
        fi
    fi

    echo "  ✓ Downloaded $count config files"
}

# ============================================================================
# Download Additional Tools (grepai, status-line)
# ============================================================================
download_tools() {
    echo "→ Installing additional tools..."

    local tool_count=0

    # Install grepai (semantic code search)
    if ! command -v grepai &>/dev/null; then
        mkdir -p "$HOME_DIR/.local/bin"

        local grepai_ext=""
        [ "$OS" = "windows" ] && grepai_ext=".exe"

        local grepai_url="https://github.com/yoanbernabeu/grepai/releases/latest/download/grepai_${OS}_${ARCH}${grepai_ext}"
        local grepai_tmp
        grepai_tmp=$(mktemp)

        if curl -fsL --retry 3 --proto '=https' --tlsv1.2 "$grepai_url" -o "$grepai_tmp" 2>/dev/null; then
            install -m 0755 "$grepai_tmp" "$HOME_DIR/.local/bin/grepai${grepai_ext}"
            tool_count=$((tool_count + 1))
            echo "  ✓ grepai installed"
        else
            echo "  ⚠ grepai download failed (optional)"
        fi
        rm -f "$grepai_tmp"
    else
        echo "  ✓ grepai already installed"
    fi

    # Install status-line (git status display)
    if ! command -v status-line &>/dev/null; then
        mkdir -p "$HOME_DIR/.local/bin"

        local status_ext=""
        [ "$OS" = "windows" ] && status_ext=".exe"

        local status_url="https://github.com/kodflow/status-line/releases/latest/download/status-line-${OS}-${ARCH}${status_ext}"
        local status_tmp
        status_tmp=$(mktemp)

        if curl -fsL --retry 3 --proto '=https' --tlsv1.2 "$status_url" -o "$status_tmp" 2>/dev/null; then
            install -m 0755 "$status_tmp" "$HOME_DIR/.local/bin/status-line${status_ext}"
            tool_count=$((tool_count + 1))
            echo "  ✓ status-line installed"
        else
            echo "  ⚠ status-line download failed (optional)"
        fi
        rm -f "$status_tmp"
    else
        echo "  ✓ status-line already installed"
    fi

    # Add to PATH if needed
    if [[ ":$PATH:" != *":$HOME_DIR/.local/bin:"* ]]; then
        # shellcheck disable=SC2016
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME_DIR/.bashrc" 2>/dev/null || true
        # shellcheck disable=SC2016
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME_DIR/.zshrc" 2>/dev/null || true
        echo "  → Added ~/.local/bin to PATH (restart shell to apply)"
    fi
}

# ============================================================================
# Verification
# ============================================================================
verify_installation() {
    local target_dir="$1"
    local errors=0

    echo ""
    echo "→ Verifying installation..."

    # Check Claude CLI
    if command -v claude &>/dev/null; then
        local claude_version
        claude_version=$(claude --version 2>/dev/null || echo "unknown")
        echo "  ✓ Claude CLI: $claude_version"
    else
        echo "  ✗ Claude CLI not found in PATH"
        errors=$((errors + 1))
    fi

    # Count assets
    local agent_count=0
    local cmd_count=0
    local script_count=0
    local doc_count=0

    [ -d "$target_dir/agents" ] && agent_count=$(find "$target_dir/agents" -name "*.md" 2>/dev/null | wc -l)
    [ -d "$target_dir/commands" ] && cmd_count=$(find "$target_dir/commands" -name "*.md" 2>/dev/null | wc -l)
    [ -d "$target_dir/scripts" ] && script_count=$(find "$target_dir/scripts" -name "*.sh" 2>/dev/null | wc -l)
    [ -d "$target_dir/docs" ] && doc_count=$(find "$target_dir/docs" -name "*.md" 2>/dev/null | wc -l)

    echo "  Assets installed:"
    echo "    Agents:   $agent_count / 35 expected"
    echo "    Commands: $cmd_count / 11 expected"
    echo "    Scripts:  $script_count / 11 expected"
    if [ "$INSTALL_MINIMAL" = false ]; then
        echo "    Docs:     $doc_count / 155+ expected"
    else
        echo "    Docs:     skipped (--minimal mode)"
    fi

    # Validate settings.json
    if [ -f "$target_dir/settings.json" ]; then
        if command -v jq &>/dev/null && jq empty "$target_dir/settings.json" 2>/dev/null; then
            echo "  ✓ settings.json is valid JSON"
        else
            echo "  ⚠ settings.json validation skipped (jq not available)"
        fi
    else
        echo "  ✗ settings.json not found"
        errors=$((errors + 1))
    fi

    echo ""
    if [ $errors -eq 0 ]; then
        echo "✓ Installation verified successfully"
        return 0
    else
        echo "⚠ Installation completed with $errors error(s)"
        return 1
    fi
}

# ============================================================================
# Main Installation Flow
# ============================================================================
main() {
    detect_environment

    install_claude_cli

    echo ""
    echo "→ Downloading Claude Code assets..."
    echo "  Target: $TARGET_DIR"
    echo ""

    download_agents "$TARGET_DIR"
    download_commands "$TARGET_DIR"
    download_scripts "$TARGET_DIR"
    download_docs "$TARGET_DIR"
    download_configs "$TARGET_DIR"

    echo ""
    download_tools

    verify_installation "$TARGET_DIR"

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  ✓ Installation Complete!"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  Installation directory: $TARGET_DIR"
    echo ""
    echo "  Available commands:"
    echo "    /git      - Git workflow (commit, branch, PR)"
    echo "    /review   - AI-powered code review"
    echo "    /plan     - Planning mode"
    echo "    /do       - Iterative task execution"
    echo "    /search   - Documentation research"
    echo "    /update   - DevContainer template update"
    echo ""
    if [ "$IS_CONTAINER" = false ]; then
        echo "  Next steps:"
        echo "    1. Restart your shell (or source ~/.bashrc)"
        echo "    2. Run: claude"
        echo ""
    else
        echo "  → Restart the DevContainer to apply changes"
        echo ""
    fi
    echo "═══════════════════════════════════════════════"
}

# Run main installation
main
