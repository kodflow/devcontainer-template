#!/bin/bash
set -e

echo "========================================="
echo "Installing Infrastructure as Code Tools"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    curl \
    wget

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        K8S_ARCH="amd64"
        ;;
    aarch64|arm64)
        K8S_ARCH="arm64"
        ;;
    armv7l)
        K8S_ARCH="arm"
        ;;
    *)
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${YELLOW}Detected architecture: $ARCH (K8s arch: $K8S_ARCH)${NC}"

# Install Ansible
echo -e "${YELLOW}Installing Ansible...${NC}"
sudo apt-get install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible

ANSIBLE_VERSION=$(ansible --version | head -n 1)
echo -e "${GREEN}✓ ${ANSIBLE_VERSION} installed${NC}"

# Install kubectl (if not already installed)
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}Installing kubectl...${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${K8S_ARCH}/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
    KUBECTL_VERSION=$(kubectl version --client --short 2>&1 | grep -i "client version" || echo "kubectl installed")
    echo -e "${GREEN}✓ ${KUBECTL_VERSION}${NC}"
else
    echo -e "${GREEN}✓ kubectl already installed${NC}"
fi

# Install Helm
echo -e "${YELLOW}Installing Helm...${NC}"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
HELM_VERSION=$(helm version --short)
echo -e "${GREEN}✓ Helm ${HELM_VERSION} installed${NC}"

# Create cache directories
mkdir -p /home/vscode/.kube
mkdir -p /home/vscode/.cache/helm

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}IaC tools installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${ANSIBLE_VERSION}"
echo "  - kubectl"
echo "  - Helm ${HELM_VERSION}"
echo ""
echo "Configuration directories:"
echo "  - Kubernetes: /home/vscode/.kube"
echo "  - Helm: /home/vscode/.cache/helm"
echo ""
echo "Quick start:"
echo "  - Ansible: ansible-playbook playbook.yml"
echo "  - kubectl: kubectl get pods"
echo "  - Helm: helm install myapp ./mychart"
echo ""
