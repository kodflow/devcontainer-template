#!/bin/bash
# Initialize .env file before devcontainer build
# This script runs on the host machine before Docker Compose

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVCONTAINER_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$DEVCONTAINER_DIR/.env"

# Extract project name from git remote URL
REPO_NAME=$(basename "$(git config --get remote.origin.url)" .git)

# Sanitize project name for Docker Compose requirements:
# - Must start with a letter or number
# - Only lowercase alphanumeric, hyphens, and underscores allowed
REPO_NAME=$(echo "$REPO_NAME" | sed 's/^[^a-zA-Z0-9]*//' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g')

# If name is empty after sanitization, use a default
if [ -z "$REPO_NAME" ]; then
    REPO_NAME="devcontainer"
fi

echo "🔧 Initializing devcontainer environment..."
echo "📦 Project name: $REPO_NAME"

# If .env doesn't exist, create it from .env.example
if [ ! -f "$ENV_FILE" ]; then
    echo "📝 Creating .env from .env.example..."
    cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
fi

# Update or add COMPOSE_PROJECT_NAME in .env
if grep -q "^COMPOSE_PROJECT_NAME=" "$ENV_FILE"; then
    # Update existing line
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|^COMPOSE_PROJECT_NAME=.*|COMPOSE_PROJECT_NAME=$REPO_NAME|" "$ENV_FILE"
    else
        # Linux
        sed -i "s|^COMPOSE_PROJECT_NAME=.*|COMPOSE_PROJECT_NAME=$REPO_NAME|" "$ENV_FILE"
    fi
    echo "✅ Updated COMPOSE_PROJECT_NAME=$REPO_NAME in .env"
else
    # Add at the beginning of the file
    echo "COMPOSE_PROJECT_NAME=$REPO_NAME" | cat - "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
    echo "✅ Added COMPOSE_PROJECT_NAME=$REPO_NAME to .env"
fi

# ============================================================================
# Validate and fix devcontainer features
# ============================================================================
echo ""
echo "🔍 Validating devcontainer features..."

FEATURES_DIR="$DEVCONTAINER_DIR/features"
ERRORS=0
FIXED=0

for category in "$FEATURES_DIR"/*; do
    [ ! -d "$category" ] && continue

    for feature in "$category"/*; do
        [ ! -d "$feature" ] && continue

        feature_name="$(basename "$category")/$(basename "$feature")"

        # Check devcontainer-feature.json
        if [ ! -f "$feature/devcontainer-feature.json" ]; then
            echo "❌ $feature_name: Missing devcontainer-feature.json"
            ((ERRORS++))
            continue
        fi

        # Check install.sh
        if [ ! -f "$feature/install.sh" ]; then
            echo "❌ $feature_name: Missing install.sh"
            ((ERRORS++))
            continue
        fi

        # Fix permissions if needed
        if [ ! -x "$feature/install.sh" ]; then
            chmod +x "$feature/install.sh"
            ((FIXED++))
        fi
    done
done

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "❌ Found $ERRORS critical error(s) in features!"
    echo "   Please fix missing files before building the devcontainer."
    exit 1
fi

if [ $FIXED -gt 0 ]; then
    echo "✅ Fixed permissions on $FIXED install.sh file(s)"
fi

echo "✅ All features validated successfully"

# ============================================================================
# Clean up stale Docker resources (optional)
# ============================================================================
if [ -n "${DEVCONTAINER_CLEANUP:-}" ]; then
    echo ""
    echo "🧹 Cleaning up stale devcontainer resources..."

    # Stop and remove containers for this project
    docker compose -f "$DEVCONTAINER_DIR/docker-compose.yml" down 2>/dev/null || true

    echo "✅ Cleanup complete"
fi

echo ""
echo "✨ Environment initialization complete!"
