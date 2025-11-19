#!/bin/bash
set -e

echo "========================================="
echo "Installing HashiCorp Tools Suite"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Environment variables
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-/home/vscode/.cache/terraform}"

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
sudo apt-get update && sudo apt-get install -y \
    curl \
    unzip \
    gnupg \
    software-properties-common

# Add HashiCorp GPG key
echo -e "${YELLOW}Adding HashiCorp repository...${NC}"
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update

# Install Terraform
echo -e "${YELLOW}Installing Terraform...${NC}"
sudo apt-get install -y terraform
TERRAFORM_VERSION=$(terraform version | head -n 1)
echo -e "${GREEN}✓ ${TERRAFORM_VERSION} installed${NC}"

# Install Vault
echo -e "${YELLOW}Installing Vault...${NC}"
sudo apt-get install -y vault
VAULT_VERSION=$(vault version | head -n 1)
echo -e "${GREEN}✓ ${VAULT_VERSION} installed${NC}"

# Install Consul
echo -e "${YELLOW}Installing Consul...${NC}"
sudo apt-get install -y consul
CONSUL_VERSION=$(consul version | head -n 1)
echo -e "${GREEN}✓ ${CONSUL_VERSION} installed${NC}"

# Install Nomad
echo -e "${YELLOW}Installing Nomad...${NC}"
sudo apt-get install -y nomad
NOMAD_VERSION=$(nomad version | head -n 1)
echo -e "${GREEN}✓ ${NOMAD_VERSION} installed${NC}"

# Install Packer
echo -e "${YELLOW}Installing Packer...${NC}"
sudo apt-get install -y packer
PACKER_VERSION=$(packer version)
echo -e "${GREEN}✓ Packer ${PACKER_VERSION} installed${NC}"

# Install Vagrant
echo -e "${YELLOW}Installing Vagrant...${NC}"
sudo apt-get install -y vagrant
VAGRANT_VERSION=$(vagrant version | head -n 1)
echo -e "${GREEN}✓ ${VAGRANT_VERSION} installed${NC}"

# Install Waypoint
echo -e "${YELLOW}Installing Waypoint...${NC}"
sudo apt-get install -y waypoint
WAYPOINT_VERSION=$(waypoint version | head -n 1)
echo -e "${GREEN}✓ ${WAYPOINT_VERSION} installed${NC}"

# Install Boundary
echo -e "${YELLOW}Installing Boundary...${NC}"
sudo apt-get install -y boundary
BOUNDARY_VERSION=$(boundary version | head -n 1)
echo -e "${GREEN}✓ ${BOUNDARY_VERSION} installed${NC}"

# Install terraform-ls (Terraform Language Server)
echo -e "${YELLOW}Installing terraform-ls...${NC}"
sudo apt-get install -y terraform-ls
echo -e "${GREEN}✓ terraform-ls installed${NC}"

# Create cache directories
mkdir -p "$TF_PLUGIN_CACHE_DIR"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}HashiCorp tools installed successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Installed components:"
echo "  - ${TERRAFORM_VERSION}"
echo "  - ${VAULT_VERSION}"
echo "  - ${CONSUL_VERSION}"
echo "  - ${NOMAD_VERSION}"
echo "  - Packer ${PACKER_VERSION}"
echo "  - ${VAGRANT_VERSION}"
echo "  - ${WAYPOINT_VERSION}"
echo "  - ${BOUNDARY_VERSION}"
echo "  - terraform-ls (Language Server)"
echo ""
echo "Cache directories:"
echo "  - Terraform plugins: $TF_PLUGIN_CACHE_DIR"
echo ""
echo "Quick start:"
echo "  - Terraform: terraform init && terraform plan"
echo "  - Vault: vault server -dev"
echo "  - Consul: consul agent -dev"
echo "  - Nomad: nomad agent -dev"
