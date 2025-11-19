#!/bin/bash
set -e

echo "========================================="
echo "Installing Cloud CLIs (AWS, Google Cloud, Azure)"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Environment variables
export AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-/home/vscode/.config/aws/config}"
export AWS_SHARED_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-/home/vscode/.config/aws/credentials}"
export AWS_CLI_CACHE_DIR="${AWS_CLI_CACHE_DIR:-/home/vscode/.cache/aws}"
export CLOUDSDK_CONFIG="${CLOUDSDK_CONFIG:-/home/vscode/.config/gcloud}"
export AZURE_CONFIG_DIR="${AZURE_CONFIG_DIR:-/home/vscode/.config/azure}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    curl \
    unzip \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        AWS_ARCH="x86_64"
        ;;
    aarch64|arm64)
        AWS_ARCH="aarch64"
        ;;
    *)
        echo -e "${RED}Unsupported architecture for AWS CLI: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Detected architecture: $ARCH (AWS arch: $AWS_ARCH)${NC}"

# Install AWS CLI v2
echo -e "${YELLOW}Installing AWS CLI v2...${NC}"
curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

AWS_VERSION=$(aws --version)
echo -e "${GREEN}✓ ${AWS_VERSION} installed${NC}"

# Install Google Cloud SDK
echo -e "${YELLOW}Installing Google Cloud SDK...${NC}"
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt-get update && sudo apt-get install -y google-cloud-cli

GCLOUD_VERSION=$(gcloud version --format="value(core.version)")
echo -e "${GREEN}✓ Google Cloud SDK ${GCLOUD_VERSION} installed${NC}"

# Install Google Cloud components
echo -e "${YELLOW}Installing Google Cloud components...${NC}"
gcloud components install kubectl gke-gcloud-auth-plugin --quiet
echo -e "${GREEN}✓ kubectl and gke-gcloud-auth-plugin installed${NC}"

# Install Azure CLI
echo -e "${YELLOW}Installing Azure CLI...${NC}"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

AZURE_VERSION=$(az version --output json | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)
echo -e "${GREEN}✓ Azure CLI ${AZURE_VERSION} installed${NC}"

# Create config directories
mkdir -p /home/vscode/.config/aws
mkdir -p "$AWS_CLI_CACHE_DIR"
mkdir -p "$CLOUDSDK_CONFIG"
mkdir -p "$AZURE_CONFIG_DIR"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Cloud CLIs installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${AWS_VERSION}"
echo "  - Google Cloud SDK ${GCLOUD_VERSION}"
echo "  - kubectl (Kubernetes CLI)"
echo "  - Azure CLI ${AZURE_VERSION}"
echo ""
echo "Configuration directories:"
echo "  - AWS: /home/vscode/.config/aws"
echo "  - AWS cache: $AWS_CLI_CACHE_DIR"
echo "  - Google Cloud: $CLOUDSDK_CONFIG"
echo "  - Azure: $AZURE_CONFIG_DIR"
echo ""
echo "Usage:"
echo "  - AWS: aws configure"
echo "  - Google Cloud: gcloud init"
echo "  - Azure: az login"
