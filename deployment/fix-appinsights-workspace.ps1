# Fix Application Insights workspace_id Issue
# This script helps resolve the "workspace_id can not be removed after set" error

Write-Host "Application Insights Workspace ID Fix Script" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$resourceGroupName = Read-Host "Enter your resource group name (e.g., ***-dev-rg)"
$appInsightsName = Read-Host "Enter your Application Insights name (e.g., ***-dev-ai)"

Write-Host ""
Write-Host "Option 1: Recreate Application Insights (RECOMMENDED)" -ForegroundColor Yellow
Write-Host "  This will remove and recreate the resource with proper workspace_id" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 2: Update via Azure CLI (might not work)" -ForegroundColor Yellow
Write-Host "  Try to update the existing resource" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Choose option (1 or 2)"

if ($choice -eq "1") {
    Write-Host ""
    Write-Host "Step 1: Taint the resource in Terraform" -ForegroundColor Green
    Write-Host "Run this command:" -ForegroundColor Cyan
    Write-Host "  terraform taint azurerm_application_insights.mlops" -ForegroundColor White
    Write-Host ""
    Write-Host "Step 2: Apply Terraform" -ForegroundColor Green
    Write-Host "Run this command:" -ForegroundColor Cyan
    Write-Host "  terraform apply" -ForegroundColor White
    Write-Host ""
    Write-Host "This will destroy and recreate Application Insights with workspace_id linked." -ForegroundColor Yellow
    Write-Host "Note: Historical data will be preserved in Log Analytics." -ForegroundColor Gray
} 
elseif ($choice -eq "2") {
    Write-Host ""
    Write-Host "Getting Log Analytics workspace ID..." -ForegroundColor Green
    
    $lawName = $appInsightsName -replace "-ai$", "-law"
    $lawId = az monitor log-analytics workspace show `
        --resource-group $resourceGroupName `
        --workspace-name $lawName `
        --query id -o tsv
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Could not find Log Analytics workspace '$lawName'" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Log Analytics Workspace ID: $lawId" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Attempting to update Application Insights..." -ForegroundColor Green
    
    az monitor app-insights component update `
        --app $appInsightsName `
        --resource-group $resourceGroupName `
        --workspace $lawId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Success! Application Insights updated." -ForegroundColor Green
        Write-Host "Now run: terraform apply" -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "Failed to update. Use Option 1 instead." -ForegroundColor Red
    }
}
else {
    Write-Host "Invalid choice. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "After fixing Application Insights, run:" -ForegroundColor Yellow
Write-Host "  terraform plan" -ForegroundColor White
Write-Host "  terraform apply" -ForegroundColor White
