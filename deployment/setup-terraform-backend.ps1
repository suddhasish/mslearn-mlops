# ============================================================================
# Setup Terraform Remote Backend - PowerShell Script
# ============================================================================
# This script creates Azure Storage for Terraform state management
# Supports both Development and Production environments
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod", "both")]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$Prefix = "mlops"
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Setting up Terraform Remote Backend for Azure MLOps" -ForegroundColor Cyan
Write-Host "============================================================================`n" -ForegroundColor Cyan

# Generate unique suffix
$uniqueSuffix = -join ((97..122) | Get-Random -Count 6 | ForEach-Object {[char]$_})

# Function to create backend storage
function New-TerraformBackend {
    param(
        [string]$Env,
        [string]$Loc,
        [string]$Pre,
        [string]$Suffix
    )
    
    $rgName = "${Pre}-tfstate-${Env}-rg"
    $storageAccountName = "${Pre}tfstate${Env}${Suffix}"
    $containerName = "tfstate"
    
    Write-Host "📦 Creating backend for environment: $Env" -ForegroundColor Yellow
    Write-Host "   Resource Group: $rgName" -ForegroundColor Gray
    Write-Host "   Storage Account: $storageAccountName" -ForegroundColor Gray
    Write-Host "   Container: $containerName`n" -ForegroundColor Gray
    
    # Create resource group
    Write-Host "→ Creating resource group..." -ForegroundColor White
    az group create --name $rgName --location $Loc --output none
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create resource group"
    }
    Write-Host "  ✓ Resource group created" -ForegroundColor Green
    
    # Create storage account
    Write-Host "→ Creating storage account..." -ForegroundColor White
    az storage account create `
        --resource-group $rgName `
        --name $storageAccountName `
        --location $Loc `
        --sku Standard_LRS `
        --encryption-services blob `
        --https-only true `
        --min-tls-version TLS1_2 `
        --allow-blob-public-access false `
        --output none
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create storage account"
    }
    Write-Host "  ✓ Storage account created" -ForegroundColor Green
    
    # Enable versioning for state file protection
    Write-Host "→ Enabling blob versioning..." -ForegroundColor White
    az storage account blob-service-properties update `
        --account-name $storageAccountName `
        --resource-group $rgName `
        --enable-versioning true `
        --output none
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  ⚠ Failed to enable versioning (non-critical)"
    } else {
        Write-Host "  ✓ Blob versioning enabled" -ForegroundColor Green
    }
    
    # Get storage account key
    Write-Host "→ Retrieving storage account key..." -ForegroundColor White
    $storageKey = az storage account keys list `
        --resource-group $rgName `
        --account-name $storageAccountName `
        --query '[0].value' `
        --output tsv
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve storage account key"
    }
    Write-Host "  ✓ Storage key retrieved" -ForegroundColor Green
    
    # Create blob container
    Write-Host "→ Creating blob container..." -ForegroundColor White
    az storage container create `
        --name $containerName `
        --account-name $storageAccountName `
        --account-key $storageKey `
        --output none
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create blob container"
    }
    Write-Host "  ✓ Blob container created" -ForegroundColor Green
    
    # Configure lock on resource group
    Write-Host "→ Adding resource lock..." -ForegroundColor White
    az lock create `
        --name "terraform-state-lock" `
        --resource-group $rgName `
        --lock-type CanNotDelete `
        --notes "Prevent accidental deletion of Terraform state" `
        --output none
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  ⚠ Failed to create resource lock (non-critical)"
    } else {
        Write-Host "  ✓ Resource lock created" -ForegroundColor Green
    }
    
    Write-Host "`n✅ Backend setup complete for $Env environment!`n" -ForegroundColor Green
    
    return @{
        ResourceGroup = $rgName
        StorageAccount = $storageAccountName
        Container = $containerName
        Key = $storageKey
    }
}

# Check if Azure CLI is installed
Write-Host "🔍 Checking prerequisites..." -ForegroundColor Yellow
$azVersion = az --version 2>&1 | Select-String "azure-cli" | Select-Object -First 1
if (-not $azVersion) {
    Write-Host "❌ Azure CLI not found. Please install: https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Azure CLI detected: $azVersion`n" -ForegroundColor Green

# Check if logged in
Write-Host "→ Checking Azure login status..." -ForegroundColor White
$account = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not logged in to Azure. Running az login..." -ForegroundColor Red
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Azure login failed" -ForegroundColor Red
        exit 1
    }
}

$subscription = az account show --query name -o tsv
Write-Host "  ✓ Logged in to subscription: $subscription`n" -ForegroundColor Green

# Create backends based on environment parameter
$results = @{}

try {
    if ($Environment -eq "dev" -or $Environment -eq "both") {
        $results["dev"] = New-TerraformBackend -Env "dev" -Loc $Location -Pre $Prefix -Suffix $uniqueSuffix
    }
    
    if ($Environment -eq "prod" -or $Environment -eq "both") {
        $results["prod"] = New-TerraformBackend -Env "prod" -Loc $Location -Pre $Prefix -Suffix $uniqueSuffix
    }
    
    Write-Host "`n============================================================================" -ForegroundColor Cyan
    Write-Host "🎉 Terraform Remote Backend Setup Complete!" -ForegroundColor Green
    Write-Host "============================================================================`n" -ForegroundColor Cyan
    
    # Display configuration summary
    foreach ($env in $results.Keys) {
        $config = $results[$env]
        
        Write-Host "📋 Configuration for $env environment:" -ForegroundColor Yellow
        Write-Host @"
        
Resource Group:    $($config.ResourceGroup)
Storage Account:   $($config.StorageAccount)
Container:         $($config.Container)
State File:        ${env}.tfstate

Backend Configuration (backend.tf):
────────────────────────────────────────────────
terraform {
  backend "azurerm" {
    resource_group_name  = "$($config.ResourceGroup)"
    storage_account_name = "$($config.StorageAccount)"
    container_name       = "$($config.Container)"
    key                  = "${env}.tfstate"
  }
}
────────────────────────────────────────────────

"@ -ForegroundColor Gray
    }
    
    # Display GitHub Secrets configuration
    Write-Host "`n🔐 GitHub Actions Secrets Configuration:" -ForegroundColor Yellow
    Write-Host "Add these secrets to your GitHub repository (Settings → Secrets → Actions):`n" -ForegroundColor White
    
    foreach ($env in $results.Keys) {
        $config = $results[$env]
        $envUpper = $env.ToUpper()
        
        if ($env -eq "dev") {
            Write-Host "DEV Environment:" -ForegroundColor Cyan
            Write-Host "  TF_STATE_RESOURCE_GROUP: $($config.ResourceGroup)" -ForegroundColor Gray
            Write-Host "  TF_STATE_STORAGE_ACCOUNT: $($config.StorageAccount)" -ForegroundColor Gray
        } else {
            Write-Host "`nPROD Environment:" -ForegroundColor Cyan
            Write-Host "  TF_STATE_RESOURCE_GROUP_PROD: $($config.ResourceGroup)" -ForegroundColor Gray
            Write-Host "  TF_STATE_STORAGE_ACCOUNT_PROD: $($config.StorageAccount)" -ForegroundColor Gray
        }
    }
    
    # Display next steps
    Write-Host "`n📝 Next Steps:" -ForegroundColor Yellow
    Write-Host @"
    
1. Add the secrets shown above to your GitHub repository
2. Navigate to infrastructure directory: cd infrastructure
3. Initialize Terraform: terraform init
4. Create terraform.tfvars from terraform.tfvars.free-tier
5. Run: terraform plan
6. Deploy: terraform apply

For GitHub Actions deployment:
- Push code to trigger workflow, or
- Run manually: gh workflow run infrastructure-deploy.yml

"@ -ForegroundColor White
    
    Write-Host "✅ Setup complete! Your Terraform state will be stored securely in Azure Storage.`n" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
