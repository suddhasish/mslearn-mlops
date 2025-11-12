# Setup GitHub Secrets and Variables from Terraform Infrastructure
# This script extracts Terraform outputs and configures GitHub repository

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("dev", "prod", "both")]
    [string]$Environment = "both",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# Colors for output
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Cyan }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }

Write-Info "=== GitHub Secrets & Variables Setup ==="
Write-Info "Environment: $Environment"
Write-Info "Dry Run: $DryRun"
Write-Host ""

# Check prerequisites
Write-Info "Checking prerequisites..."

# Check if GitHub CLI is installed
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Error "GitHub CLI (gh) is not installed. Install from: https://cli.github.com/"
    exit 1
}

# Check GitHub authentication
try {
    $ghAuth = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Not authenticated with GitHub CLI. Run: gh auth login"
        exit 1
    }
    Write-Success "GitHub CLI authenticated"
} catch {
    Write-Error "Failed to check GitHub auth status"
    exit 1
}

# Check if in git repository
if (!(Test-Path .git)) {
    Write-Error "Not in a git repository. Run this script from the repository root."
    exit 1
}

# Get repository info
if ([string]::IsNullOrEmpty($GitHubRepo)) {
    try {
        $remoteUrl = git remote get-url origin
        if ($remoteUrl -match "github\.com[:/](.+/.+?)(\.git)?$") {
            $GitHubRepo = $matches[1]
            Write-Success "Detected repository: $GitHubRepo"
        } else {
            Write-Error "Could not detect GitHub repository from git remote"
            exit 1
        }
    } catch {
        Write-Error "Failed to get git remote URL"
        exit 1
    }
}

# Function to get Terraform outputs
function Get-TerraformOutputs {
    param([string]$EnvPath)
    
    Write-Info "Reading Terraform outputs from: $EnvPath"
    
    if (!(Test-Path "$EnvPath/terraform.tfstate")) {
        Write-Warning "No terraform.tfstate found in $EnvPath"
        Write-Warning "Make sure Terraform has been applied in this environment"
        return $null
    }
    
    Push-Location $EnvPath
    try {
        $outputs = terraform output -json | ConvertFrom-Json
        Write-Success "Successfully read Terraform outputs"
        return $outputs
    } catch {
        Write-Error "Failed to read Terraform outputs: $_"
        return $null
    } finally {
        Pop-Location
    }
}

# Function to set GitHub secret
function Set-GitHubSecret {
    param(
        [string]$Name,
        [string]$Value
    )
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would set secret: $Name"
        return
    }
    
    try {
        $Value | gh secret set $Name --repo $GitHubRepo
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Set secret: $Name"
        } else {
            Write-Error "Failed to set secret: $Name"
        }
    } catch {
        Write-Error "Error setting secret $Name : $_"
    }
}

# Function to set GitHub variable
function Set-GitHubVariable {
    param(
        [string]$Name,
        [string]$Value
    )
    
    if ($DryRun) {
        Write-Info "[DRY RUN] Would set variable: $Name = $Value"
        return
    }
    
    try {
        gh variable set $Name --body $Value --repo $GitHubRepo
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Set variable: $Name = $Value"
        } else {
            Write-Error "Failed to set variable: $Name"
        }
    } catch {
        Write-Error "Error setting variable $Name : $_"
    }
}

# Function to extract value from Terraform output
function Get-OutputValue {
    param($Output)
    
    if ($Output.value) {
        return $Output.value
    }
    return ""
}

# Process DEV environment
if ($Environment -eq "dev" -or $Environment -eq "both") {
    Write-Host ""
    Write-Info "=== Processing DEV Environment ==="
    
    $devOutputs = Get-TerraformOutputs -EnvPath "infrastructure/environments/dev"
    
    if ($devOutputs) {
        Set-GitHubVariable -Name "AZURE_RESOURCE_GROUP_DEV" -Value (Get-OutputValue $devOutputs.resource_group_name)
        Set-GitHubVariable -Name "AZURE_ML_WORKSPACE_DEV" -Value (Get-OutputValue $devOutputs.ml_workspace_name)
        Set-GitHubVariable -Name "AZURE_CONTAINER_REGISTRY_DEV" -Value (Get-OutputValue $devOutputs.container_registry_login_server)
        Set-GitHubVariable -Name "AZURE_STORAGE_ACCOUNT_DEV" -Value (Get-OutputValue $devOutputs.storage_account_name)
        Set-GitHubVariable -Name "AZURE_KEY_VAULT_DEV" -Value (Get-OutputValue $devOutputs.key_vault_name)
        
        $aksName = Get-OutputValue $devOutputs.aks_cluster_name
        if (![string]::IsNullOrEmpty($aksName)) {
            Set-GitHubVariable -Name "AZURE_AKS_CLUSTER_DEV" -Value $aksName
        }
        
        # Set common subscription ID if available
        $subId = Get-OutputValue $devOutputs.subscription_id
        if (![string]::IsNullOrEmpty($subId)) {
            Set-GitHubVariable -Name "AZURE_SUBSCRIPTION_ID" -Value $subId
        } else {
            Set-GitHubVariable -Name "AZURE_SUBSCRIPTION_ID" -Value "b2b8a5e6-9a34-494b-ba62-fe9be95bd398"
        }
    }
}

# Process PROD environment
if ($Environment -eq "prod" -or $Environment -eq "both") {
    Write-Host ""
    Write-Info "=== Processing PROD Environment ==="
    
    $prodOutputs = Get-TerraformOutputs -EnvPath "infrastructure/environments/prod"
    
    if ($prodOutputs) {
        Set-GitHubVariable -Name "AZURE_RESOURCE_GROUP_PROD" -Value (Get-OutputValue $prodOutputs.resource_group_name)
        Set-GitHubVariable -Name "AZURE_ML_WORKSPACE_PROD" -Value (Get-OutputValue $prodOutputs.ml_workspace_name)
        Set-GitHubVariable -Name "AZURE_CONTAINER_REGISTRY_PROD" -Value (Get-OutputValue $prodOutputs.container_registry_login_server)
        Set-GitHubVariable -Name "AZURE_STORAGE_ACCOUNT_PROD" -Value (Get-OutputValue $prodOutputs.storage_account_name)
        Set-GitHubVariable -Name "AZURE_KEY_VAULT_PROD" -Value (Get-OutputValue $prodOutputs.key_vault_name)
        
        $aksName = Get-OutputValue $prodOutputs.aks_cluster_name
        if (![string]::IsNullOrEmpty($aksName)) {
            Set-GitHubVariable -Name "AZURE_AKS_CLUSTER_PROD" -Value $aksName
        }
    }
}

# Check for AZURE_CREDENTIALS secret
Write-Host ""
Write-Info "=== Checking AZURE_CREDENTIALS Secret ==="

try {
    $secrets = gh secret list --repo $GitHubRepo 2>&1
    if ($secrets -match "AZURE_CREDENTIALS") {
        Write-Success "AZURE_CREDENTIALS secret already exists"
    } else {
        Write-Warning "AZURE_CREDENTIALS secret not found"
        Write-Info "You need to create a service principal and add it as a secret."
        Write-Info "Run the following command:"
        Write-Host ""
        Write-Host "az ad sp create-for-rbac --name 'github-actions-mlops' --role contributor --scopes /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398 --sdk-auth" -ForegroundColor Yellow
        Write-Host ""
        Write-Info "Then add the output as AZURE_CREDENTIALS secret in GitHub"
        Write-Info "Or run: gh secret set AZURE_CREDENTIALS --repo $GitHubRepo < credentials.json"
    }
} catch {
    Write-Warning "Could not check for AZURE_CREDENTIALS secret"
}

Write-Host ""
Write-Success "=== Setup Complete ==="
Write-Host ""
Write-Info "Next steps:"
Write-Info "1. Verify secrets in GitHub: https://github.com/$GitHubRepo/settings/secrets/actions"
Write-Info "2. Verify variables in GitHub: https://github.com/$GitHubRepo/settings/variables/actions"
Write-Info "3. Test your workflows to ensure they can access the infrastructure"
Write-Host ""

# Summary
Write-Info "=== Summary ==="
if ($Environment -eq "dev" -or $Environment -eq "both") {
    Write-Host "DEV Environment Variables:" -ForegroundColor Cyan
    Write-Host "  - AZURE_RESOURCE_GROUP_DEV"
    Write-Host "  - AZURE_ML_WORKSPACE_DEV"
    Write-Host "  - AZURE_CONTAINER_REGISTRY_DEV"
    Write-Host "  - AZURE_STORAGE_ACCOUNT_DEV"
    Write-Host "  - AZURE_KEY_VAULT_DEV"
    Write-Host "  - AZURE_AKS_CLUSTER_DEV (if AKS enabled)"
}

if ($Environment -eq "prod" -or $Environment -eq "both") {
    Write-Host "PROD Environment Variables:" -ForegroundColor Cyan
    Write-Host "  - AZURE_RESOURCE_GROUP_PROD"
    Write-Host "  - AZURE_ML_WORKSPACE_PROD"
    Write-Host "  - AZURE_CONTAINER_REGISTRY_PROD"
    Write-Host "  - AZURE_STORAGE_ACCOUNT_PROD"
    Write-Host "  - AZURE_KEY_VAULT_PROD"
    Write-Host "  - AZURE_AKS_CLUSTER_PROD (if AKS enabled)"
}

Write-Host "Common Variables:" -ForegroundColor Cyan
Write-Host "  - AZURE_SUBSCRIPTION_ID"
Write-Host ""
Write-Host "Required Secret:" -ForegroundColor Cyan
Write-Host "  - AZURE_CREDENTIALS (service principal JSON)"
