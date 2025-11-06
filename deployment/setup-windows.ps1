# Complete Windows Setup Script for MLOps Infrastructure
# Run this script to set up everything from scratch

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('dev', 'prod')]
    [string]$Environment = 'dev',
    
    [Parameter()]
    [switch]$SkipPrerequisites,
    
    [Parameter()]
    [switch]$DeployOnly
)

$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Colors
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    $color = switch ($Type) {
        'Info'    { 'Cyan' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error'   { 'Red' }
    }
    
    $prefix = switch ($Type) {
        'Info'    { '[INFO]' }
        'Success' { '[SUCCESS]' }
        'Warning' { '[WARNING]' }
        'Error'   { '[ERROR]' }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

# Banner
function Show-Banner {
    Clear-Host
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║          Azure MLOps Infrastructure Setup (Windows)         ║" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║                    Environment: $Environment                        ║" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

# Check if running as Administrator
function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Install Chocolatey
function Install-Chocolatey {
    Write-ColorOutput "Checking Chocolatey installation..." -Type Info
    
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "Installing Chocolatey..." -Type Info
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        Write-ColorOutput "Chocolatey installed successfully!" -Type Success
    } else {
        Write-ColorOutput "Chocolatey already installed" -Type Success
    }
}

# Install Prerequisites
function Install-Prerequisites {
    Write-ColorOutput "Installing prerequisites..." -Type Info
    
    # Install Terraform
    if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "Installing Terraform..." -Type Info
        choco install terraform -y
    } else {
        $tfVersion = terraform version -json | ConvertFrom-Json
        Write-ColorOutput "Terraform already installed: $($tfVersion.terraform_version)" -Type Success
    }
    
    # Install Azure CLI
    if (!(Get-Command az -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "Installing Azure CLI..." -Type Info
        choco install azure-cli -y
    } else {
        $azVersion = az version | ConvertFrom-Json
        Write-ColorOutput "Azure CLI already installed: $($azVersion.'azure-cli')" -Type Success
    }
    
    # Install Git
    if (!(Get-Command git -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "Installing Git..." -Type Info
        choco install git -y
    } else {
        Write-ColorOutput "Git already installed" -Type Success
    }
    
    # Install jq for JSON processing
    if (!(Get-Command jq -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "Installing jq..." -Type Info
        choco install jq -y
    } else {
        Write-ColorOutput "jq already installed" -Type Success
    }
    
    # Refresh environment variables
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-ColorOutput "All prerequisites installed!" -Type Success
}

# Azure Login
function Connect-ToAzure {
    Write-ColorOutput "Checking Azure login status..." -Type Info
    
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        Write-ColorOutput "Already logged in to Azure" -Type Success
        Write-ColorOutput "Subscription: $($account.name)" -Type Info
        Write-ColorOutput "Tenant: $($account.tenantId)" -Type Info
        
        $confirm = Read-Host "Do you want to use this subscription? (Y/n)"
        if ($confirm -eq 'n' -or $confirm -eq 'N') {
            az login
        }
    }
    catch {
        Write-ColorOutput "Not logged in to Azure. Initiating login..." -Type Warning
        az login
        
        # Show available subscriptions
        Write-ColorOutput "Available subscriptions:" -Type Info
        az account list --output table
        
        $selectSub = Read-Host "Do you want to select a different subscription? (y/N)"
        if ($selectSub -eq 'y' -or $selectSub -eq 'Y') {
            $subId = Read-Host "Enter subscription ID"
            az account set --subscription $subId
        }
    }
    
    # Verify login
    $account = az account show | ConvertFrom-Json
    Write-ColorOutput "Using subscription: $($account.name)" -Type Success
}

# Setup Terraform Backend
function Initialize-TerraformBackend {
    Write-ColorOutput "Setting up Terraform backend storage..." -Type Info
    
    $stateRg = Read-Host "Enter resource group name for Terraform state [mlops-terraform-state-rg]"
    if ([string]::IsNullOrWhiteSpace($stateRg)) { $stateRg = "mlops-terraform-state-rg" }
    
    $stateStorage = Read-Host "Enter storage account name for Terraform state [mlopstfstate$(Get-Random -Minimum 1000 -Maximum 9999)]"
    if ([string]::IsNullOrWhiteSpace($stateStorage)) { 
        $stateStorage = "mlopstfstate$(Get-Random -Minimum 1000 -Maximum 9999)" 
    }
    
    $stateLocation = Read-Host "Enter location for state storage [eastus2]"
    if ([string]::IsNullOrWhiteSpace($stateLocation)) { $stateLocation = "eastus2" }
    
    Write-ColorOutput "Creating Terraform state storage..." -Type Info
    Write-ColorOutput "  Resource Group: $stateRg" -Type Info
    Write-ColorOutput "  Storage Account: $stateStorage" -Type Info
    Write-ColorOutput "  Location: $stateLocation" -Type Info
    
    # Create resource group
    az group create --name $stateRg --location $stateLocation --output none
    Write-ColorOutput "Resource group created" -Type Success
    
    # Create storage account
    az storage account create `
        --name $stateStorage `
        --resource-group $stateRg `
        --location $stateLocation `
        --sku Standard_LRS `
        --encryption-services blob `
        --https-only true `
        --min-tls-version TLS1_2 `
        --output none
    Write-ColorOutput "Storage account created" -Type Success
    
    # Create container
    az storage container create `
        --name tfstate `
        --account-name $stateStorage `
        --output none
    Write-ColorOutput "Blob container created" -Type Success
    
    # Return backend config
    return @{
        ResourceGroup = $stateRg
        StorageAccount = $stateStorage
        Location = $stateLocation
    }
}

# Create Terraform Variables File
function New-TerraformVarsFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Environment
    )
    
    Write-ColorOutput "Configuring Terraform variables for $Environment..." -Type Info
    
    $projectName = Read-Host "Enter project name [mlops-demo]"
    if ([string]::IsNullOrWhiteSpace($projectName)) { $projectName = "mlops-demo" }
    
    $location = Read-Host "Enter Azure location [eastus2]"
    if ([string]::IsNullOrWhiteSpace($location)) { $location = "eastus2" }
    
    $email = Read-Host "Enter notification email"
    
    $slackWebhook = Read-Host "Enter Slack webhook URL (optional, press Enter to skip)"
    
    $tfVarsContent = @"
# Terraform Variables - $Environment Environment
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

environment                = "$Environment"
project_name              = "$projectName"
location                  = "$location"
owner                     = "MLOps Team"
cost_center               = "ML Engineering"
business_unit             = "Data Science"

# Network Configuration
allowed_subnet_cidr       = "10.0.0.0/8"
enable_private_endpoints  = $(if ($Environment -eq 'prod') { 'true' } else { 'false' })
enable_purge_protection   = $(if ($Environment -eq 'prod') { 'true' } else { 'false' })

# Compute Configuration
ml_compute_name          = "cpu-cluster"
aks_node_count          = $(if ($Environment -eq 'prod') { '3' } else { '2' })
aks_vm_size             = "Standard_D4s_v3"
aks_enable_auto_scaling = true
aks_min_nodes           = $(if ($Environment -eq 'prod') { '2' } else { '1' })
aks_max_nodes           = $(if ($Environment -eq 'prod') { '10' } else { '5' })

# Monitoring Configuration
enable_container_insights = true
log_retention_days       = $(if ($Environment -eq 'prod') { '90' } else { '30' })

# Security Configuration
enable_network_policy    = true
enable_rbac             = true
enable_aad_integration  = true

# Cost Management
enable_cost_alerts      = true
monthly_budget_amount   = $(if ($Environment -eq 'prod') { '5000' } else { '1000' })
budget_alert_threshold  = 80

# Azure DevOps Integration
enable_devops_integration = true
devops_project_name       = "MLOps Project"

# Data Services
enable_data_factory      = true
enable_synapse          = false
enable_cognitive_services = false

# Backup and Recovery
enable_backup           = $(if ($Environment -eq 'prod') { 'true' } else { 'false' })
backup_retention_days   = $(if ($Environment -eq 'prod') { '90' } else { '30' })

# Notifications
notification_email       = "$email"
enable_slack_notifications = $(if ([string]::IsNullOrWhiteSpace($slackWebhook)) { 'false' } else { 'true' })
slack_webhook_url        = "$slackWebhook"
"@

    $tfVarsPath = Join-Path $PSScriptRoot "..\infrastructure\terraform.tfvars"
    $tfVarsContent | Out-File -FilePath $tfVarsPath -Encoding UTF8
    
    Write-ColorOutput "Terraform variables file created: $tfVarsPath" -Type Success
    
    return @{
        ProjectName = $projectName
        Location = $location
        Email = $email
    }
}

# Deploy Infrastructure
function Deploy-Infrastructure {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$BackendConfig,
        
        [Parameter(Mandatory=$true)]
        [string]$Environment
    )
    
    Write-ColorOutput "Starting infrastructure deployment for $Environment..." -Type Info
    
    $infraPath = Join-Path $PSScriptRoot "..\infrastructure"
    Push-Location $infraPath
    
    try {
        # Create backend configuration
        $backendContent = @"
terraform {
  backend "azurerm" {
    resource_group_name  = "$($BackendConfig.ResourceGroup)"
    storage_account_name = "$($BackendConfig.StorageAccount)"
    container_name       = "tfstate"
    key                  = "$Environment.tfstate"
  }
}
"@
        $backendContent | Out-File -FilePath "backend.tf" -Encoding UTF8
        Write-ColorOutput "Backend configuration created" -Type Success
        
        # Initialize Terraform
        Write-ColorOutput "Initializing Terraform..." -Type Info
        terraform init
        if ($LASTEXITCODE -ne 0) { throw "Terraform init failed" }
        Write-ColorOutput "Terraform initialized" -Type Success
        
        # Validate
        Write-ColorOutput "Validating Terraform configuration..." -Type Info
        terraform validate
        if ($LASTEXITCODE -ne 0) { throw "Terraform validation failed" }
        Write-ColorOutput "Terraform configuration valid" -Type Success
        
        # Plan
        Write-ColorOutput "Creating Terraform plan..." -Type Info
        terraform plan -out="tfplan-$Environment"
        if ($LASTEXITCODE -ne 0) { throw "Terraform plan failed" }
        Write-ColorOutput "Terraform plan created" -Type Success
        
        # Show plan summary
        Write-Host ""
        Write-ColorOutput "Plan Summary:" -Type Info
        terraform show -json "tfplan-$Environment" | jq -r '.resource_changes[] | "\(.change.actions[0]): \(.type) - \(.name)"'
        Write-Host ""
        
        # Confirm
        $confirm = Read-Host "Do you want to apply this plan? (yes/no)"
        if ($confirm -ne 'yes') {
            Write-ColorOutput "Deployment cancelled by user" -Type Warning
            Pop-Location
            return $false
        }
        
        # Apply
        Write-ColorOutput "Applying Terraform configuration..." -Type Info
        Write-ColorOutput "This may take 15-30 minutes..." -Type Warning
        terraform apply -auto-approve "tfplan-$Environment"
        if ($LASTEXITCODE -ne 0) { throw "Terraform apply failed" }
        Write-ColorOutput "Infrastructure deployed successfully!" -Type Success
        
        # Get outputs
        Write-ColorOutput "Retrieving deployment outputs..." -Type Info
        terraform output -json | Out-File -FilePath "outputs-$Environment.json" -Encoding UTF8
        
        # Save outputs to deployment folder
        $deploymentOutputPath = Join-Path $PSScriptRoot "terraform-outputs-$Environment.json"
        Copy-Item "outputs-$Environment.json" $deploymentOutputPath
        
        Write-ColorOutput "Outputs saved to: $deploymentOutputPath" -Type Success
        
        Pop-Location
        return $true
    }
    catch {
        Write-ColorOutput "Deployment failed: $_" -Type Error
        Pop-Location
        return $false
    }
}

# Show Deployment Summary
function Show-DeploymentSummary {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Environment
    )
    
    $outputPath = Join-Path $PSScriptRoot "terraform-outputs-$Environment.json"
    
    if (Test-Path $outputPath) {
        $outputs = Get-Content $outputPath | ConvertFrom-Json
        
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  Deployment Summary - $Environment Environment" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Resource Group:      " -NoNewline; Write-Host $outputs.resource_group_name.value -ForegroundColor Green
        Write-Host "Location:            " -NoNewline; Write-Host $outputs.resource_group_location.value -ForegroundColor Green
        Write-Host "ML Workspace:        " -NoNewline; Write-Host $outputs.ml_workspace_name.value -ForegroundColor Green
        Write-Host "AKS Cluster:         " -NoNewline; Write-Host $outputs.aks_cluster_name.value -ForegroundColor Green
        Write-Host "Storage Account:     " -NoNewline; Write-Host $outputs.storage_account_name.value -ForegroundColor Green
        Write-Host "Container Registry:  " -NoNewline; Write-Host $outputs.container_registry_name.value -ForegroundColor Green
        Write-Host "Key Vault:           " -NoNewline; Write-Host $outputs.key_vault_name.value -ForegroundColor Green
        Write-Host "Application Insights:" -NoNewline; Write-Host $outputs.application_insights_name.value -ForegroundColor Green
        Write-Host ""
        Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Yellow
        Write-Host "  1. Navigate to Azure ML Studio: https://ml.azure.com" -ForegroundColor White
        Write-Host "  2. Test training job: az ml job create --file src/job.yml" -ForegroundColor White
        Write-Host "  3. View in Azure Portal: https://portal.azure.com" -ForegroundColor White
        Write-Host ""
        
        # Create markdown summary file
        $summaryPath = Join-Path $PSScriptRoot "DEPLOYMENT_SUMMARY_$Environment.md"
        $summaryContent = @"
# Deployment Summary - $Environment Environment

**Deployment Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Deployed Resources

| Resource Type | Resource Name |
|---------------|---------------|
| Resource Group | $($outputs.resource_group_name.value) |
| Location | $($outputs.resource_group_location.value) |
| ML Workspace | $($outputs.ml_workspace_name.value) |
| AKS Cluster | $($outputs.aks_cluster_name.value) |
| Storage Account | $($outputs.storage_account_name.value) |
| Container Registry | $($outputs.container_registry_name.value) |
| Key Vault | $($outputs.key_vault_name.value) |
| Application Insights | $($outputs.application_insights_name.value) |

## Access Information

- **Azure ML Studio**: [https://ml.azure.com](https://ml.azure.com)
- **Azure Portal**: [View Resources](https://portal.azure.com/#@/resource$($outputs.ml_workspace_id.value))

## Next Steps

1. Configure GitHub Secrets
2. Run training job
3. Deploy model to staging
4. Monitor in Application Insights

## Cost Estimate

- **Environment**: $Environment
- **Monthly Budget**: $$($outputs.deployment_summary.value.monthly_budget)
- **Alert Threshold**: 80%

---
*Generated by MLOps Setup Script*
"@
        $summaryContent | Out-File -FilePath $summaryPath -Encoding UTF8
        Write-ColorOutput "Summary saved to: $summaryPath" -Type Success
    }
    else {
        Write-ColorOutput "No deployment outputs found" -Type Warning
    }
}

# Main execution
try {
    Show-Banner
    
    if (-not (Test-Administrator)) {
        Write-ColorOutput "This script requires Administrator privileges" -Type Error
        Write-ColorOutput "Please run PowerShell as Administrator and try again" -Type Warning
        exit 1
    }
    
    # Step 1: Install Prerequisites
    if (-not $SkipPrerequisites) {
        Write-ColorOutput "Step 1/5: Installing prerequisites..." -Type Info
        Install-Chocolatey
        Install-Prerequisites
        Write-Host ""
        Read-Host "Press Enter to continue..."
    }
    
    # Step 2: Azure Login
    Write-ColorOutput "Step 2/5: Azure Login..." -Type Info
    Connect-ToAzure
    Write-Host ""
    Read-Host "Press Enter to continue..."
    
    # Step 3: Setup Backend
    Write-ColorOutput "Step 3/5: Setting up Terraform backend..." -Type Info
    $backendConfig = Initialize-TerraformBackend
    Write-Host ""
    Read-Host "Press Enter to continue..."
    
    # Step 4: Configure Variables
    Write-ColorOutput "Step 4/5: Configuring Terraform variables..." -Type Info
    $varsConfig = New-TerraformVarsFile -Environment $Environment
    Write-Host ""
    Read-Host "Press Enter to continue..."
    
    # Step 5: Deploy
    Write-ColorOutput "Step 5/5: Deploying infrastructure..." -Type Info
    $success = Deploy-Infrastructure -BackendConfig $backendConfig -Environment $Environment
    
    if ($success) {
        Write-Host ""
        Show-DeploymentSummary -Environment $Environment
        Write-ColorOutput "Deployment completed successfully! 🎉" -Type Success
    }
    else {
        Write-ColorOutput "Deployment failed. Check the logs above for details." -Type Error
        exit 1
    }
}
catch {
    Write-ColorOutput "An error occurred: $_" -Type Error
    Write-ColorOutput $_.ScriptStackTrace -Type Error
    exit 1
}