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

# Download Google Java Format
echo -e "${YELLOW}Installing Google Java Format...${NC}"
GOOGLE_JAVA_FORMAT_VERSION="1.24.0"
GOOGLE_JAVA_FORMAT_JAR="/home/vscode/.local/share/java/google-java-format.jar"
mkdir -p /home/vscode/.local/share/java
curl -fsSL "https://github.com/google/google-java-format/releases/download/v${GOOGLE_JAVA_FORMAT_VERSION}/google-java-format-${GOOGLE_JAVA_FORMAT_VERSION}-all-deps.jar" \
    -o "$GOOGLE_JAVA_FORMAT_JAR"
echo -e "${GREEN}✓ Google Java Format installed${NC}"

# Download Checkstyle
echo -e "${YELLOW}Installing Checkstyle...${NC}"
CHECKSTYLE_VERSION="10.20.1"
CHECKSTYLE_JAR="/home/vscode/.local/share/java/checkstyle.jar"
curl -fsSL "https://github.com/checkstyle/checkstyle/releases/download/checkstyle-${CHECKSTYLE_VERSION}/checkstyle-${CHECKSTYLE_VERSION}-all.jar" \
    -o "$CHECKSTYLE_JAR"
echo -e "${GREEN}✓ Checkstyle installed${NC}"

# Download SpotBugs
echo -e "${YELLOW}Installing SpotBugs...${NC}"
SPOTBUGS_VERSION="4.8.6"
SPOTBUGS_DIR="/home/vscode/.local/share/spotbugs"
mkdir -p "$SPOTBUGS_DIR"
curl -fsSL "https://github.com/spotbugs/spotbugs/releases/download/${SPOTBUGS_VERSION}/spotbugs-${SPOTBUGS_VERSION}.tgz" \
    | tar -xz -C "$SPOTBUGS_DIR" --strip-components=1
echo -e "${GREEN}✓ SpotBugs installed${NC}"

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
