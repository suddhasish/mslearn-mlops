# Fix AKS Version Conflict
# This script handles the AKS version upgrade issue by deleting the existing cluster

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "azureml-dev-rg",
    
    [Parameter(Mandatory=$false)]
    [string]$AksClusterName = "*-dev-aks"
)

Write-Host "🔧 Fixing AKS Version Conflict..." -ForegroundColor Cyan
Write-Host ""

# Step 1: List existing AKS clusters
Write-Host "1. Checking for existing AKS clusters..." -ForegroundColor Yellow
try {
    $clusters = az aks list --resource-group $ResourceGroupName --output json 2>$null | ConvertFrom-Json
    
    if ($clusters) {
        Write-Host "   Found $($clusters.Count) AKS cluster(s):" -ForegroundColor Yellow
        foreach ($cluster in $clusters) {
            Write-Host "   - Name: $($cluster.name)"
            Write-Host "     Version: $($cluster.kubernetesVersion)"
            Write-Host "     Status: $($cluster.provisioningState)"
        }
    }
    else {
        Write-Host "   ✅ No existing AKS clusters found" -ForegroundColor Green
        Write-Host "   You can proceed with 'terraform apply'"
        exit 0
    }
}
catch {
    Write-Host "   ⚠️ Could not list AKS clusters. Azure CLI may not be configured." -ForegroundColor Red
    Write-Host "   Run: az login" -ForegroundColor Yellow
    exit 1
}

# Step 2: Offer options
Write-Host ""
Write-Host "2. Resolution Options:" -ForegroundColor Cyan
Write-Host "   A) Delete existing AKS cluster and let Terraform create new one (RECOMMENDED)"
Write-Host "   B) Update Terraform to match existing version (1.28.15)"
Write-Host "   C) Cancel and handle manually"
Write-Host ""

$choice = Read-Host "Select option (A/B/C)"

switch ($choice.ToUpper()) {
    "A" {
        Write-Host ""
        Write-Host "⚠️ WARNING: This will DELETE the AKS cluster!" -ForegroundColor Red
        Write-Host "   - All deployed applications will be stopped"
        Write-Host "   - Persistent volumes may be deleted"
        Write-Host "   - Terraform will create a new cluster with version 1.29"
        Write-Host ""
        
        $confirm = Read-Host "Type 'DELETE' to confirm"
        
        if ($confirm -eq "DELETE") {
            foreach ($cluster in $clusters) {
                Write-Host ""
                Write-Host "   Deleting cluster: $($cluster.name)..." -ForegroundColor Yellow
                
                az aks delete `
                    --name $cluster.name `
                    --resource-group $ResourceGroupName `
                    --yes `
                    --no-wait
                
                Write-Host "   ✅ Deletion initiated (this will take 5-10 minutes)" -ForegroundColor Green
            }
            
            Write-Host ""
            Write-Host "   Waiting for deletion to complete..." -ForegroundColor Yellow
            Start-Sleep -Seconds 30
            
            Write-Host ""
            Write-Host "✅ Cluster deletion in progress!" -ForegroundColor Green
            Write-Host "   Wait 5-10 minutes, then run: terraform apply" -ForegroundColor Cyan
        }
        else {
            Write-Host "   ❌ Cancelled - cluster not deleted" -ForegroundColor Red
        }
    }
    
    "B" {
        Write-Host ""
        Write-Host "3. Updating Terraform configuration to match existing version..." -ForegroundColor Yellow
        
        $aksFilePath = Join-Path (Get-Location) "aks.tf"
        
        if (Test-Path $aksFilePath) {
            # Read current content
            $content = Get-Content $aksFilePath -Raw
            
            # Replace version
            $newContent = $content -replace 'kubernetes_version\s*=\s*"1\.29"', 'kubernetes_version  = "1.28.15"'
            
            # Write back
            Set-Content -Path $aksFilePath -Value $newContent -NoNewline
            
            Write-Host "   ✅ Updated aks.tf to use version 1.28.15" -ForegroundColor Green
            Write-Host ""
            Write-Host "   ⚠️ NOTE: Version 1.28.15 is LTS-only" -ForegroundColor Yellow
            Write-Host "   You'll need to either:"
            Write-Host "   - Upgrade cluster to Premium tier, OR"
            Write-Host "   - Delete cluster and use non-LTS version (recommended)"
            Write-Host ""
            Write-Host "   For now, you can run: terraform apply" -ForegroundColor Cyan
        }
        else {
            Write-Host "   ❌ Could not find aks.tf file" -ForegroundColor Red
        }
    }
    
    "C" {
        Write-Host ""
        Write-Host "   Manual steps:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   Option 1 - Delete via Azure CLI:"
        Write-Host "   az aks delete --name <cluster-name> --resource-group $ResourceGroupName --yes"
        Write-Host ""
        Write-Host "   Option 2 - Delete via Terraform:"
        Write-Host "   terraform destroy -target=azurerm_kubernetes_cluster.mlops[0]"
        Write-Host ""
        Write-Host "   Option 3 - Delete via Azure Portal:"
        Write-Host "   https://portal.azure.com → Resource Group → AKS → Delete"
        Write-Host ""
    }
    
    default {
        Write-Host ""
        Write-Host "   ❌ Invalid option selected" -ForegroundColor Red
    }
}

Write-Host ""
