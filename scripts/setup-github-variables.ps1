# Setup GitHub Variables from Terraform Outputs
# This script extracts Terraform outputs and sets them as GitHub repository variables

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "prod", "both")]
    [string]$Environment = "both",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = "suddhasish/mslearn-mlops"
)

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  GitHub Variables Setup from Terraform Outputs" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# Check if GitHub CLI is installed
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: GitHub CLI (gh) is not installed." -ForegroundColor Red
    Write-Host "Install from: https://cli.github.com/" -ForegroundColor Yellow
    exit 1
}

# Check if authenticated
$ghStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Not authenticated with GitHub CLI." -ForegroundColor Red
    Write-Host "Run: gh auth login" -ForegroundColor Yellow
    exit 1
}

function Set-GitHubVariable {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Repo
    )
    
    Write-Host "Setting variable: $Name = $Value" -ForegroundColor Green
    
    # Check if variable exists
    $existing = gh variable list --repo $Repo 2>&1 | Select-String -Pattern "^$Name\s"
    
    if ($existing) {
        gh variable set $Name --body $Value --repo $Repo
    } else {
        gh variable set $Name --body $Value --repo $Repo
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARNING: Failed to set $Name" -ForegroundColor Yellow
    }
}

function Extract-TerraformOutputs {
    param(
        [string]$EnvironmentPath,
        [string]$EnvName
    )
    
    Write-Host "`nExtracting outputs for $EnvName environment..." -ForegroundColor Cyan
    Write-Host "Path: $EnvironmentPath" -ForegroundColor Gray
    
    Push-Location $EnvironmentPath
    
    # Initialize Terraform (silent)
    Write-Host "  Initializing Terraform..." -ForegroundColor Gray
    terraform init -backend=true -reconfigure *> $null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Terraform init failed" -ForegroundColor Red
        Pop-Location
        return $false
    }
    
    # Extract outputs
    try {
        $outputs = @{
            resource_group = (terraform output -raw resource_group_name 2>$null)
            ml_workspace = (terraform output -raw ml_workspace_name 2>$null)
            aks_cluster = (terraform output -raw aks_cluster_name 2>$null)
            acr_name = (terraform output -raw container_registry_name 2>$null)
            acr_login_server = (terraform output -raw container_registry_login_server 2>$null)
            storage_account = (terraform output -raw storage_account_name 2>$null)
            key_vault = (terraform output -raw key_vault_name 2>$null)
            app_insights = (terraform output -raw application_insights_name 2>$null)
        }
        
        Write-Host "`n  Extracted Outputs:" -ForegroundColor Green
        $outputs.GetEnumerator() | ForEach-Object {
            Write-Host "    $($_.Key): $($_.Value)" -ForegroundColor White
        }
        
        Pop-Location
        return $outputs
    }
    catch {
        Write-Host "  ERROR: Failed to extract outputs - $_" -ForegroundColor Red
        Pop-Location
        return $false
    }
}

function Set-EnvironmentVariables {
    param(
        [hashtable]$Outputs,
        [string]$EnvPrefix,
        [string]$Repo
    )
    
    Write-Host "`nSetting GitHub variables for $EnvPrefix..." -ForegroundColor Cyan
    
    Set-GitHubVariable -Name "${EnvPrefix}_RESOURCE_GROUP" -Value $Outputs.resource_group -Repo $Repo
    Set-GitHubVariable -Name "${EnvPrefix}_ML_WORKSPACE" -Value $Outputs.ml_workspace -Repo $Repo
    Set-GitHubVariable -Name "${EnvPrefix}_AKS_CLUSTER" -Value $Outputs.aks_cluster -Repo $Repo
    Set-GitHubVariable -Name "${EnvPrefix}_ACR_NAME" -Value $Outputs.acr_name -Repo $Repo
    Set-GitHubVariable -Name "${EnvPrefix}_ACR_LOGIN_SERVER" -Value $Outputs.acr_login_server -Repo $Repo
    Set-GitHubVariable -Name "${EnvPrefix}_STORAGE_ACCOUNT" -Value $Outputs.storage_account -Repo $Repo
    Set-GitHubVariable -Name "${EnvPrefix}_KEY_VAULT" -Value $Outputs.key_vault -Repo $Repo
    Set-GitHubVariable -Name "${EnvPrefix}_APP_INSIGHTS" -Value $Outputs.app_insights -Repo $Repo
}

# Get workspace root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = Split-Path -Parent $scriptDir
$infraRoot = Join-Path $workspaceRoot "infrastructure\environments"

# Process environments
$success = $true

if ($Environment -eq "dev" -or $Environment -eq "both") {
    $devPath = Join-Path $infraRoot "dev"
    
    if (Test-Path $devPath) {
        $devOutputs = Extract-TerraformOutputs -EnvironmentPath $devPath -EnvName "DEV"
        
        if ($devOutputs) {
            Set-EnvironmentVariables -Outputs $devOutputs -EnvPrefix "DEV" -Repo $GitHubRepo
        } else {
            $success = $false
        }
    } else {
        Write-Host "ERROR: DEV environment path not found: $devPath" -ForegroundColor Red
        $success = $false
    }
}

if ($Environment -eq "prod" -or $Environment -eq "both") {
    $prodPath = Join-Path $infraRoot "prod"
    
    if (Test-Path $prodPath) {
        $prodOutputs = Extract-TerraformOutputs -EnvironmentPath $prodPath -EnvName "PROD"
        
        if ($prodOutputs) {
            Set-EnvironmentVariables -Outputs $prodOutputs -EnvPrefix "PROD" -Repo $GitHubRepo
        } else {
            $success = $false
        }
    } else {
        Write-Host "ERROR: PROD environment path not found: $prodPath" -ForegroundColor Red
        $success = $false
    }
}

# Set shared variables
Write-Host "`nSetting shared variables..." -ForegroundColor Cyan
Set-GitHubVariable -Name "AZURE_SUBSCRIPTION_ID" -Value "b2b8a5e6-9a34-494b-ba62-fe9be95bd398" -Repo $GitHubRepo
Set-GitHubVariable -Name "AZURE_REGION" -Value "eastus" -Repo $GitHubRepo

Write-Host "`n=================================================" -ForegroundColor Cyan

if ($success) {
    Write-Host "✓ GitHub variables configured successfully!" -ForegroundColor Green
    Write-Host "`nVerify at: https://github.com/$GitHubRepo/settings/variables/actions" -ForegroundColor Yellow
} else {
    Write-Host "✗ Some errors occurred during setup" -ForegroundColor Red
    exit 1
}

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""
