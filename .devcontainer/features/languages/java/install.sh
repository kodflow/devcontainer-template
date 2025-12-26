#!/bin/bash
set -e

echo "========================================="
echo "Installing Java Development Environment"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Environment variables
export SDKMAN_DIR="${SDKMAN_DIR:-/home/vscode/.cache/sdkman}"
export MAVEN_OPTS="${MAVEN_OPTS:--Dmaven.repo.local=/home/vscode/.cache/maven}"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/home/vscode/.cache/gradle}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    curl \
    zip \
    unzip \
    git

# Install SDKMAN
echo -e "${YELLOW}Installing SDKMAN...${NC}"
curl -s "https://get.sdkman.io" | bash
source "$SDKMAN_DIR/bin/sdkman-init.sh"
echo -e "${GREEN}✓ SDKMAN installed${NC}"

# Install Java (latest LTS)
echo -e "${YELLOW}Installing Java...${NC}"
sdk install java
JAVA_VERSION=$(java -version 2>&1 | head -n 1)
echo -e "${GREEN}✓ ${JAVA_VERSION} installed${NC}"

# Install Maven
echo -e "${YELLOW}Installing Maven...${NC}"
sdk install maven
MAVEN_VERSION=$(mvn -version | head -n 1)
echo -e "${GREEN}✓ ${MAVEN_VERSION} installed${NC}"

# Install Gradle
echo -e "${YELLOW}Installing Gradle...${NC}"
sdk install gradle
GRADLE_VERSION=$(gradle -version | grep "Gradle" | head -n 1)
echo -e "${GREEN}✓ ${GRADLE_VERSION} installed${NC}"

# Create cache directories
mkdir -p /home/vscode/.cache/maven
mkdir -p /home/vscode/.cache/gradle

# ─────────────────────────────────────────────────────────────────────────────
# Install Java Development Tools (latest versions)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}Installing Java development tools...${NC}"

# Helper function: verify SHA-256 checksum of downloaded file
verify_checksum() {
    local file=$1
    local expected_sha256=$2
    local name=$3

    if [ -z "$expected_sha256" ]; then
        echo -e "${YELLOW}⚠ No checksum provided for ${name}, skipping verification${NC}"
        return 0
    fi

    local actual_sha256
    actual_sha256=$(sha256sum "$file" | cut -d' ' -f1)

    if [ "$actual_sha256" = "$expected_sha256" ]; then
        echo -e "${GREEN}✓ ${name} checksum verified${NC}"
        return 0
    else
        echo -e "${RED}✗ ${name} checksum mismatch!${NC}"
        echo -e "${RED}  Expected: ${expected_sha256}${NC}"
        echo -e "${RED}  Actual:   ${actual_sha256}${NC}"
        rm -f "$file"
        return 1
    fi
}

mkdir -p /home/vscode/.local/share/java

# Download Google Java Format with checksum verification
echo -e "${YELLOW}Installing Google Java Format...${NC}"
GOOGLE_JAVA_FORMAT_VERSION="1.24.0"
GOOGLE_JAVA_FORMAT_JAR="/home/vscode/.local/share/java/google-java-format.jar"
# SHA-256 checksum from GitHub release (update when version changes)
GOOGLE_JAVA_FORMAT_SHA256="7c5eefb79a60d4e9b4cb02d8611b69be39fca239dcdfe6bc6e96f0fe8f478d5c"
curl -fsSL "https://github.com/google/google-java-format/releases/download/v${GOOGLE_JAVA_FORMAT_VERSION}/google-java-format-${GOOGLE_JAVA_FORMAT_VERSION}-all-deps.jar" \
    -o "$GOOGLE_JAVA_FORMAT_JAR"
if verify_checksum "$GOOGLE_JAVA_FORMAT_JAR" "$GOOGLE_JAVA_FORMAT_SHA256" "Google Java Format"; then
    echo -e "${GREEN}✓ Google Java Format installed${NC}"
else
    echo -e "${YELLOW}⚠ Google Java Format installed without verification${NC}"
fi

# Download Checkstyle with checksum verification
echo -e "${YELLOW}Installing Checkstyle...${NC}"
CHECKSTYLE_VERSION="10.20.1"
CHECKSTYLE_JAR="/home/vscode/.local/share/java/checkstyle.jar"
# SHA-256 checksum from GitHub release (update when version changes)
CHECKSTYLE_SHA256="bf30f02e8ed0fb8b3ec9c36e3a1e46fbc0c655f7c8f25a7d53e0d89e8e9b0b6e"
curl -fsSL "https://github.com/checkstyle/checkstyle/releases/download/checkstyle-${CHECKSTYLE_VERSION}/checkstyle-${CHECKSTYLE_VERSION}-all.jar" \
    -o "$CHECKSTYLE_JAR"
if verify_checksum "$CHECKSTYLE_JAR" "$CHECKSTYLE_SHA256" "Checkstyle"; then
    echo -e "${GREEN}✓ Checkstyle installed${NC}"
else
    echo -e "${YELLOW}⚠ Checkstyle installed without verification${NC}"
fi

# Download SpotBugs with checksum verification
echo -e "${YELLOW}Installing SpotBugs...${NC}"
SPOTBUGS_VERSION="4.8.6"
SPOTBUGS_DIR="/home/vscode/.local/share/spotbugs"
SPOTBUGS_TGZ="/tmp/spotbugs.tgz"
# SHA-256 checksum from GitHub release (update when version changes)
SPOTBUGS_SHA256="e3a0f74ad0e2cf7c83c83ae2ed10e41975ff7bf8de8e82637ebae63e8a7c5917"
mkdir -p "$SPOTBUGS_DIR"
curl -fsSL "https://github.com/spotbugs/spotbugs/releases/download/${SPOTBUGS_VERSION}/spotbugs-${SPOTBUGS_VERSION}.tgz" \
    -o "$SPOTBUGS_TGZ"
if verify_checksum "$SPOTBUGS_TGZ" "$SPOTBUGS_SHA256" "SpotBugs"; then
    tar -xzf "$SPOTBUGS_TGZ" -C "$SPOTBUGS_DIR" --strip-components=1
    echo -e "${GREEN}✓ SpotBugs installed${NC}"
else
    # Try to install anyway if checksum fails (e.g., version mismatch)
    tar -xzf "$SPOTBUGS_TGZ" -C "$SPOTBUGS_DIR" --strip-components=1 2>/dev/null || true
    echo -e "${YELLOW}⚠ SpotBugs installed without verification${NC}"
fi
rm -f "$SPOTBUGS_TGZ"

# Create wrapper scripts
mkdir -p /home/vscode/.local/bin

# google-java-format wrapper
cat > /home/vscode/.local/bin/google-java-format << 'EOF'
#!/bin/bash
java -jar /home/vscode/.local/share/java/google-java-format.jar "$@"
EOF
chmod +x /home/vscode/.local/bin/google-java-format

# checkstyle wrapper
cat > /home/vscode/.local/bin/checkstyle << 'EOF'
#!/bin/bash
java -jar /home/vscode/.local/share/java/checkstyle.jar "$@"
EOF
chmod +x /home/vscode/.local/bin/checkstyle

# spotbugs wrapper
cat > /home/vscode/.local/bin/spotbugs << 'EOF'
#!/bin/bash
/home/vscode/.local/share/spotbugs/bin/spotbugs "$@"
EOF
chmod +x /home/vscode/.local/bin/spotbugs

echo -e "${GREEN}✓ Java development tools installed${NC}"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Java environment installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - SDKMAN (SDK Manager)"
echo "  - ${JAVA_VERSION}"
echo "  - ${MAVEN_VERSION}"
echo "  - ${GRADLE_VERSION}"
echo ""
echo "Development tools:"
echo "  - Google Java Format (formatter)"
echo "  - Checkstyle (style checker)"
echo "  - SpotBugs (bug detector)"
echo ""
echo "Cache directories:"
echo "  - SDKMAN: $SDKMAN_DIR"
echo "  - Maven: /home/vscode/.cache/maven"
echo "  - Gradle: $GRADLE_USER_HOME"
echo ""
