#!/bin/bash
# Azure MLOps Infrastructure Deployment Script
# This script deploys the complete MLOps infrastructure using Terraform

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform from https://www.terraform.io/downloads"
        exit 1
    fi
    print_info "Terraform version: $(terraform version -json | jq -r '.terraform_version')"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install from https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    print_info "Azure CLI version: $(az version --output tsv --query \"'azure-cli'\")"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_warn "jq is not installed. Some features may not work properly."
    fi
}

# Login to Azure
azure_login() {
    print_info "Checking Azure login status..."
    
    if ! az account show &> /dev/null; then
        print_info "Not logged in to Azure. Initiating login..."
        az login
    else
        print_info "Already logged in to Azure"
        CURRENT_ACCOUNT=$(az account show --query name -o tsv)
        print_info "Current subscription: $CURRENT_ACCOUNT"
    fi
}

# Setup Terraform backend
setup_backend() {
    print_info "Setting up Terraform backend..."
    
    read -p "Enter resource group name for Terraform state (default: mlops-terraform-state-rg): " STATE_RG
    STATE_RG=${STATE_RG:-mlops-terraform-state-rg}
    
    read -p "Enter storage account name for Terraform state (default: mlopstfstate): " STATE_STORAGE
    STATE_STORAGE=${STATE_STORAGE:-mlopstfstate}
    
    read -p "Enter location for Terraform state storage (default: eastus2): " STATE_LOCATION
    STATE_LOCATION=${STATE_LOCATION:-eastus2}
    
    # Create resource group
    print_info "Creating resource group for Terraform state..."
    az group create --name "$STATE_RG" --location "$STATE_LOCATION" --output none
    
    # Create storage account
    print_info "Creating storage account for Terraform state..."
    az storage account create \
        --name "$STATE_STORAGE" \
        --resource-group "$STATE_RG" \
        --location "$STATE_LOCATION" \
        --sku Standard_LRS \
        --encryption-services blob \
        --output none
    
    # Create container
    print_info "Creating blob container for Terraform state..."
    az storage container create \
        --name tfstate \
        --account-name "$STATE_STORAGE" \
        --output none
    
    # Get storage account key
    STORAGE_KEY=$(az storage account keys list \
        --resource-group "$STATE_RG" \
        --account-name "$STATE_STORAGE" \
        --query '[0].value' -o tsv)
    
    print_info "Terraform backend configured successfully!"
    echo ""
    print_info "Backend configuration:"
    echo "  Resource Group: $STATE_RG"
    echo "  Storage Account: $STATE_STORAGE"
    echo "  Container: tfstate"
}

# Initialize Terraform
terraform_init() {
    print_info "Initializing Terraform..."
    
    cd infrastructure
    
    if [ -f "backend.hcl" ]; then
        terraform init -backend-config=backend.hcl
    else
        terraform init
    fi
    
    cd ..
}

# Validate Terraform configuration
terraform_validate() {
    print_info "Validating Terraform configuration..."
    
    cd infrastructure
    terraform validate
    cd ..
    
    print_info "Terraform configuration is valid!"
}

# Plan Terraform deployment
terraform_plan() {
    print_info "Creating Terraform plan..."
    
    cd infrastructure
    
    if [ ! -f "terraform.tfvars" ]; then
        print_warn "terraform.tfvars not found. Please create it from terraform.tfvars.example"
        cd ..
        return 1
    fi
    
    terraform plan -out=tfplan
    cd ..
    
    print_info "Terraform plan created successfully!"
}

# Apply Terraform configuration
terraform_apply() {
    print_info "Applying Terraform configuration..."
    
    cd infrastructure
    
    if [ ! -f "tfplan" ]; then
        print_error "Terraform plan not found. Please run 'terraform plan' first."
        cd ..
        return 1
    fi
    
    terraform apply tfplan
    
    # Save outputs
    terraform output -json > ../deployment/terraform-outputs.json
    
    cd ..
    
    print_info "Infrastructure deployed successfully!"
}

# Display deployment summary
show_summary() {
    print_info "Deployment Summary:"
    echo ""
    
    if [ -f "deployment/terraform-outputs.json" ]; then
        ML_WORKSPACE=$(jq -r '.ml_workspace_name.value' deployment/terraform-outputs.json)
        AKS_CLUSTER=$(jq -r '.aks_cluster_name.value' deployment/terraform-outputs.json)
        RESOURCE_GROUP=$(jq -r '.resource_group_name.value' deployment/terraform-outputs.json)
        
        echo "  Resource Group: $RESOURCE_GROUP"
        echo "  ML Workspace: $ML_WORKSPACE"
        echo "  AKS Cluster: $AKS_CLUSTER"
        echo ""
        echo "  Full outputs saved to: deployment/terraform-outputs.json"
    fi
}

# Main menu
main_menu() {
    echo ""
    echo "====================================="
    echo "  Azure MLOps Infrastructure Setup"
    echo "====================================="
    echo ""
    echo "1. Check Prerequisites"
    echo "2. Azure Login"
    echo "3. Setup Terraform Backend"
    echo "4. Initialize Terraform"
    echo "5. Validate Configuration"
    echo "6. Plan Deployment"
    echo "7. Apply Deployment"
    echo "8. Full Deployment (All Steps)"
    echo "9. Show Deployment Summary"
    echo "0. Exit"
    echo ""
    read -p "Select an option: " option
    
    case $option in
        1) check_prerequisites ;;
        2) azure_login ;;
        3) setup_backend ;;
        4) terraform_init ;;
        5) terraform_validate ;;
        6) terraform_plan ;;
        7) terraform_apply ;;
        8) 
            check_prerequisites
            azure_login
            setup_backend
            terraform_init
            terraform_validate
            terraform_plan
            terraform_apply
            show_summary
            ;;
        9) show_summary ;;
        0) 
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    
    # Return to menu
    read -p "Press Enter to continue..."
    main_menu
}

# Script entry point
print_info "Azure MLOps Infrastructure Deployment"
echo ""

# If running with --auto flag, do full deployment
if [ "${1:-}" == "--auto" ]; then
    check_prerequisites
    azure_login
    terraform_init
    terraform_validate
    terraform_plan
    
    read -p "Do you want to apply this plan? (yes/no): " CONFIRM
    if [ "$CONFIRM" == "yes" ]; then
        terraform_apply
        show_summary
    else
        print_info "Deployment cancelled"
    fi
else
    main_menu
fi