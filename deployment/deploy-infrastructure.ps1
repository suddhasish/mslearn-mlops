# PowerShell Script for Azure MLOps Infrastructure Deployment
# Windows-compatible deployment script

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Auto,
    
    [Parameter()]
    [switch]$CheckOnly
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Check Terraform
    try {
        $tfVersion = terraform version -json | ConvertFrom-Json
        Write-Info "Terraform version: $($tfVersion.terraform_version)"
    }
    catch {
        Write-Err "Terraform is not installed. Please install from https://www.terraform.io/downloads"
        exit 1
    }
    
    # Check Azure CLI
    try {
        $azVersion = az version | ConvertFrom-Json
        Write-Info "Azure CLI version: $($azVersion.'azure-cli')"
    }
    catch {
        Write-Err "Azure CLI is not installed. Please install from https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    }
    
    Write-Info "All prerequisites are installed!"
}

# Azure Login
function Connect-AzureAccount {
    Write-Info "Checking Azure login status..."
    
    try {
        $account = az account show | ConvertFrom-Json
        Write-Info "Already logged in to Azure"
        Write-Info "Current subscription: $($account.name)"
    }
    catch {
        Write-Info "Not logged in to Azure. Initiating login..."
        az login
    }
}

# Setup Terraform backend
function Initialize-TerraformBackend {
    Write-Info "Setting up Terraform backend..."
    
    $stateRg = Read-Host "Enter resource group name for Terraform state (default: mlops-terraform-state-rg)"
    if ([string]::IsNullOrWhiteSpace($stateRg)) { $stateRg = "mlops-terraform-state-rg" }
    
    $stateStorage = Read-Host "Enter storage account name for Terraform state (default: mlopstfstate)"
    if ([string]::IsNullOrWhiteSpace($stateStorage)) { $stateStorage = "mlopstfstate" }
    
    $stateLocation = Read-Host "Enter location for state storage (default: eastus2)"
    if ([string]::IsNullOrWhiteSpace($stateLocation)) { $stateLocation = "eastus2" }
    
    # Create resource group
    Write-Info "Creating resource group for Terraform state..."
    az group create --name $stateRg --location $stateLocation --output none
    
    # Create storage account
    Write-Info "Creating storage account for Terraform state..."
    az storage account create `
        --name $stateStorage `
        --resource-group $stateRg `
        --location $stateLocation `
        --sku Standard_LRS `
        --encryption-services blob `
        --output none
    
    # Create container
    Write-Info "Creating blob container for Terraform state..."
    az storage container create `
        --name tfstate `
        --account-name $stateStorage `
        --output none
    
    Write-Info "Terraform backend configured successfully!"
    Write-Host ""
    Write-Info "Backend configuration:"
    Write-Host "  Resource Group: $stateRg"
    Write-Host "  Storage Account: $stateStorage"
    Write-Host "  Container: tfstate"
}

# Initialize Terraform
function Initialize-Terraform {
    Write-Info "Initializing Terraform..."
    
    Push-Location infrastructure
    
    if (Test-Path "backend.hcl") {
        terraform init -backend-config=backend.hcl
    }
    else {
        terraform init
    }
    
    Pop-Location
}

# Validate Terraform
function Test-TerraformConfig {
    Write-Info "Validating Terraform configuration..."
    
    Push-Location infrastructure
    terraform validate
    Pop-Location
    
    Write-Info "Terraform configuration is valid!"
}

# Plan Terraform
function New-TerraformPlan {
    Write-Info "Creating Terraform plan..."
    
    Push-Location infrastructure
    
    if (-not (Test-Path "terraform.tfvars")) {
        Write-Warn "terraform.tfvars not found. Please create it from terraform.tfvars.example"
        Pop-Location
        return $false
    }
    
    terraform plan -out=tfplan
    Pop-Location
    
    Write-Info "Terraform plan created successfully!"
    return $true
}

# Apply Terraform
function Deploy-Infrastructure {
    Write-Info "Applying Terraform configuration..."
    
    Push-Location infrastructure
    
    if (-not (Test-Path "tfplan")) {
        Write-Err "Terraform plan not found. Please run plan first."
        Pop-Location
        return $false
    }
    
    terraform apply tfplan
    
    # Save outputs
    terraform output -json | Out-File -FilePath "..\deployment\terraform-outputs.json" -Encoding utf8
    
    Pop-Location
    
    Write-Info "Infrastructure deployed successfully!"
    return $true
}

# Show summary
function Show-DeploymentSummary {
    Write-Info "Deployment Summary:"
    Write-Host ""
    
    if (Test-Path "deployment\terraform-outputs.json") {
        $outputs = Get-Content "deployment\terraform-outputs.json" | ConvertFrom-Json
        
        $mlWorkspace = $outputs.ml_workspace_name.value
        $aksCluster = $outputs.aks_cluster_name.value
        $resourceGroup = $outputs.resource_group_name.value
        
        Write-Host "  Resource Group: $resourceGroup"
        Write-Host "  ML Workspace: $mlWorkspace"
        Write-Host "  AKS Cluster: $aksCluster"
        Write-Host ""
        Write-Host "  Full outputs saved to: deployment\terraform-outputs.json"
    }
}

# Main menu
function Show-Menu {
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  Azure MLOps Infrastructure Setup" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Check Prerequisites"
    Write-Host "2. Azure Login"
    Write-Host "3. Setup Terraform Backend"
    Write-Host "4. Initialize Terraform"
    Write-Host "5. Validate Configuration"
    Write-Host "6. Plan Deployment"
    Write-Host "7. Apply Deployment"
    Write-Host "8. Full Deployment (All Steps)"
    Write-Host "9. Show Deployment Summary"
    Write-Host "0. Exit"
    Write-Host ""
    
    $option = Read-Host "Select an option"
    
    switch ($option) {
        "1" { Test-Prerequisites }
        "2" { Connect-AzureAccount }
        "3" { Initialize-TerraformBackend }
        "4" { Initialize-Terraform }
        "5" { Test-TerraformConfig }
        "6" { New-TerraformPlan }
        "7" { Deploy-Infrastructure }
        "8" {
            Test-Prerequisites
            Connect-AzureAccount
            Initialize-TerraformBackend
            Initialize-Terraform
            Test-TerraformConfig
            if (New-TerraformPlan) {
                $confirm = Read-Host "Do you want to apply this plan? (yes/no)"
                if ($confirm -eq "yes") {
                    Deploy-Infrastructure
                    Show-DeploymentSummary
                }
            }
        }
        "9" { Show-DeploymentSummary }
        "0" {
            Write-Info "Exiting..."
            exit 0
        }
        default {
            Write-Err "Invalid option"
        }
    }
    
    # Return to menu
    Read-Host "Press Enter to continue..."
    Show-Menu
}

# Script entry point
Write-Info "Azure MLOps Infrastructure Deployment"
Write-Host ""

if ($CheckOnly) {
    Test-Prerequisites
    exit 0
}

if ($Auto) {
    Test-Prerequisites
    Connect-AzureAccount
    Initialize-Terraform
    Test-TerraformConfig
    
    if (New-TerraformPlan) {
        $confirm = Read-Host "Do you want to apply this plan? (yes/no)"
        if ($confirm -eq "yes") {
            Deploy-Infrastructure
            Show-DeploymentSummary
        }
        else {
            Write-Info "Deployment cancelled"
        }
    }
}
else {
    Show-Menu
}