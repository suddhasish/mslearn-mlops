#!/bin/bash
# ============================================================================
# Setup Terraform Remote Backend - Bash Script
# ============================================================================
# This script creates Azure Storage for Terraform state management
# Supports both Development and Production environments
# ============================================================================

set -e

# Default values
ENVIRONMENT="${1:-dev}"
LOCATION="${2:-eastus}"
PREFIX="${3:-mlops}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}🚀 Setting up Terraform Remote Backend for Azure MLOps${NC}"
echo -e "${CYAN}============================================================================${NC}\n"

# Generate unique suffix
UNIQUE_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 6 | head -n 1)

# Function to create backend storage
create_backend() {
    local env=$1
    local loc=$2
    local pre=$3
    local suffix=$4
    
    local rg_name="${pre}-tfstate-${env}-rg"
    local storage_account="${pre}tfstate${env}${suffix}"
    local container_name="tfstate"
    
    echo -e "${YELLOW}📦 Creating backend for environment: ${env}${NC}"
    echo -e "${GRAY}   Resource Group: ${rg_name}${NC}"
    echo -e "${GRAY}   Storage Account: ${storage_account}${NC}"
    echo -e "${GRAY}   Container: ${container_name}${NC}\n"
    
    # Create resource group
    echo -e "→ Creating resource group..."
    az group create --name "${rg_name}" --location "${loc}" --output none
    echo -e "${GREEN}  ✓ Resource group created${NC}"
    
    # Create storage account
    echo -e "→ Creating storage account..."
    az storage account create \
        --resource-group "${rg_name}" \
        --name "${storage_account}" \
        --location "${loc}" \
        --sku Standard_LRS \
        --encryption-services blob \
        --https-only true \
        --min-tls-version TLS1_2 \
        --allow-blob-public-access false \
        --output none
    echo -e "${GREEN}  ✓ Storage account created${NC}"
    
    # Enable versioning
    echo -e "→ Enabling blob versioning..."
    az storage account blob-service-properties update \
        --account-name "${storage_account}" \
        --resource-group "${rg_name}" \
        --enable-versioning true \
        --output none || echo -e "${YELLOW}  ⚠ Failed to enable versioning (non-critical)${NC}"
    
    # Get storage account key
    echo -e "→ Retrieving storage account key..."
    local storage_key=$(az storage account keys list \
        --resource-group "${rg_name}" \
        --account-name "${storage_account}" \
        --query '[0].value' \
        --output tsv)
    echo -e "${GREEN}  ✓ Storage key retrieved${NC}"
    
    # Create blob container
    echo -e "→ Creating blob container..."
    az storage container create \
        --name "${container_name}" \
        --account-name "${storage_account}" \
        --account-key "${storage_key}" \
        --output none
    echo -e "${GREEN}  ✓ Blob container created${NC}"
    
    # Configure lock
    echo -e "→ Adding resource lock..."
    az lock create \
        --name "terraform-state-lock" \
        --resource-group "${rg_name}" \
        --lock-type CanNotDelete \
        --notes "Prevent accidental deletion of Terraform state" \
        --output none || echo -e "${YELLOW}  ⚠ Failed to create resource lock (non-critical)${NC}"
    
    echo -e "\n${GREEN}✅ Backend setup complete for ${env} environment!${NC}\n"
    
    # Store results
    echo "${rg_name}|${storage_account}|${container_name}" > "/tmp/backend_${env}.txt"
}

# Check prerequisites
echo -e "${YELLOW}🔍 Checking prerequisites...${NC}"
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found. Please install: https://docs.microsoft.com/cli/azure/install-azure-cli${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Azure CLI detected${NC}\n"

# Check login status
echo -e "→ Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Not logged in to Azure. Running az login...${NC}"
    az login
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "${GREEN}  ✓ Logged in to subscription: ${SUBSCRIPTION}${NC}\n"

# Create backends
if [[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "both" ]]; then
    create_backend "dev" "$LOCATION" "$PREFIX" "$UNIQUE_SUFFIX"
fi

if [[ "$ENVIRONMENT" == "prod" || "$ENVIRONMENT" == "both" ]]; then
    create_backend "prod" "$LOCATION" "$PREFIX" "$UNIQUE_SUFFIX"
fi

# Display summary
echo -e "\n${CYAN}============================================================================${NC}"
echo -e "${GREEN}🎉 Terraform Remote Backend Setup Complete!${NC}"
echo -e "${CYAN}============================================================================${NC}\n"

# Display configurations
for env in dev prod; do
    if [[ -f "/tmp/backend_${env}.txt" ]]; then
        IFS='|' read -r rg_name storage_account container_name < "/tmp/backend_${env}.txt"
        
        echo -e "${YELLOW}📋 Configuration for ${env} environment:${NC}"
        echo -e "${GRAY}"
        cat << EOF
        
Resource Group:    ${rg_name}
Storage Account:   ${storage_account}
Container:         ${container_name}
State File:        ${env}.tfstate

Backend Configuration (backend.tf):
────────────────────────────────────────────────
terraform {
  backend "azurerm" {
    resource_group_name  = "${rg_name}"
    storage_account_name = "${storage_account}"
    container_name       = "${container_name}"
    key                  = "${env}.tfstate"
  }
}
────────────────────────────────────────────────

EOF
        echo -e "${NC}"
        
        rm -f "/tmp/backend_${env}.txt"
    fi
done

# Display GitHub Secrets
echo -e "${YELLOW}🔐 GitHub Actions Secrets Configuration:${NC}"
echo -e "Add these secrets to your GitHub repository (Settings → Secrets → Actions):\n"

# Read dev config if exists
if [[ -f "/tmp/backend_dev.txt" ]]; then
    IFS='|' read -r rg_name storage_account container_name < "/tmp/backend_dev.txt"
    echo -e "${CYAN}DEV Environment:${NC}"
    echo -e "${GRAY}  TF_STATE_RESOURCE_GROUP: ${rg_name}${NC}"
    echo -e "${GRAY}  TF_STATE_STORAGE_ACCOUNT: ${storage_account}${NC}"
fi

# Read prod config if exists
if [[ -f "/tmp/backend_prod.txt" ]]; then
    IFS='|' read -r rg_name storage_account container_name < "/tmp/backend_prod.txt"
    echo -e "\n${CYAN}PROD Environment:${NC}"
    echo -e "${GRAY}  TF_STATE_RESOURCE_GROUP_PROD: ${rg_name}${NC}"
    echo -e "${GRAY}  TF_STATE_STORAGE_ACCOUNT_PROD: ${storage_account}${NC}"
fi

# Display next steps
echo -e "\n${YELLOW}📝 Next Steps:${NC}"
cat << 'EOF'
    
1. Add the secrets shown above to your GitHub repository
2. Navigate to infrastructure directory: cd infrastructure
3. Initialize Terraform: terraform init
4. Create terraform.tfvars from terraform.tfvars.free-tier
5. Run: terraform plan
6. Deploy: terraform apply

For GitHub Actions deployment:
- Push code to trigger workflow, or
- Run manually: gh workflow run infrastructure-deploy.yml

EOF

echo -e "${GREEN}✅ Setup complete! Your Terraform state will be stored securely in Azure Storage.${NC}\n"
