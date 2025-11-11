# Cleanup Soft-Deleted Resources Script
# This script purges soft-deleted Azure ML workspaces and Key Vaults

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus"
)

Write-Host "🧹 Cleaning up soft-deleted resources..." -ForegroundColor Cyan

# Check for soft-deleted ML workspaces
Write-Host "`n1. Checking for soft-deleted ML workspaces..."
$deletedWorkspaces = az ml workspace list-deleted --output json 2>$null | ConvertFrom-Json

if ($deletedWorkspaces) {
    foreach ($ws in $deletedWorkspaces) {
        if ($ws.name -eq $WorkspaceName) {
            Write-Host "   Found soft-deleted workspace: $($ws.name)" -ForegroundColor Yellow
            Write-Host "   Location: $($ws.location)"
            Write-Host "   Deletion Time: $($ws.deletionTime)"
            
            Write-Host "   Purging workspace..." -ForegroundColor Yellow
            
            try {
                az ml workspace delete `
                    --name $ws.name `
                    --resource-group $ws.resourceGroup `
                    --permanently-delete `
                    --yes `
                    --no-wait 2>$null
                
                Write-Host "   ✅ Workspace purge initiated" -ForegroundColor Green
            }
            catch {
                Write-Host "   ⚠️ Failed to purge workspace: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
else {
    Write-Host "   ✅ No soft-deleted ML workspaces found" -ForegroundColor Green
}

# Check for soft-deleted Key Vaults
Write-Host "`n2. Checking for soft-deleted Key Vaults..."
$subscription = az account show --query id -o tsv
$deletedVaults = az keyvault list-deleted --subscription $subscription --output json 2>$null | ConvertFrom-Json

if ($deletedVaults) {
    foreach ($vault in $deletedVaults) {
        if ($vault.name -like "*$ResourceGroupName*") {
            Write-Host "   Found soft-deleted vault: $($vault.name)" -ForegroundColor Yellow
            Write-Host "   Location: $($vault.properties.location)"
            Write-Host "   Deletion Time: $($vault.properties.deletionDate)"
            
            Write-Host "   Purging vault..." -ForegroundColor Yellow
            
            try {
                az keyvault purge `
                    --name $vault.name `
                    --location $vault.properties.location `
                    --no-wait 2>$null
                
                Write-Host "   ✅ Vault purge initiated" -ForegroundColor Green
            }
            catch {
                Write-Host "   ⚠️ Failed to purge vault: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}
else {
    Write-Host "   ✅ No soft-deleted Key Vaults found" -ForegroundColor Green
}

# Wait for purges to complete
Write-Host "`n3. Waiting for purge operations to complete (this may take 2-3 minutes)..."
Start-Sleep -Seconds 30

Write-Host "`n✅ Cleanup completed!" -ForegroundColor Green
Write-Host "   You can now run 'terraform apply' again.`n"

# Verify cleanup
Write-Host "Verification:"
Write-Host "- ML Workspaces: Run 'az ml workspace list-deleted'"
Write-Host "- Key Vaults: Run 'az keyvault list-deleted'`n"
