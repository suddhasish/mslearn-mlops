param(
  [Parameter(Mandatory=$true)][string]$ResourceGroupName,
  [switch]$FrontDoor,
  [switch]$TrafficManager,
  [switch]$APIM,
  [switch]$AKS,
  [switch]$All,
  [switch]$Force
)

# Purpose: Manually clean up stuck Azure resources that timeout during Terraform destroy
# Use when: terraform destroy times out on Front Door, Traffic Manager, APIM, or AKS deletion
#
# Requirements: az CLI logged in with sufficient permissions

$ErrorActionPreference = "Stop"

function Remove-FrontDoorResources {
  param([string]$RG)
  Write-Host "Checking for Front Door profiles in $RG..." -ForegroundColor Cyan
  $profiles = az cdn fd profile list -g $RG --query "[].{name:name,id:id}" -o json | ConvertFrom-Json
  if ($profiles.Count -eq 0) {
    Write-Host "No Front Door profiles found." -ForegroundColor Green
    return
  }
  foreach ($profile in $profiles) {
    Write-Host "Deleting Front Door profile: $($profile.name)" -ForegroundColor Yellow
    if ($Force.IsPresent) {
      az cdn fd profile delete -g $RG --profile-name $profile.name --yes --no-wait
      Write-Host "  Deletion initiated (background)." -ForegroundColor Green
    } else {
      Write-Host "  Run with -Force to delete." -ForegroundColor Yellow
    }
  }
}

function Remove-TrafficManagerProfiles {
  param([string]$RG)
  Write-Host "Checking for Traffic Manager profiles in $RG..." -ForegroundColor Cyan
  $profiles = az network traffic-manager profile list -g $RG --query "[].{name:name,id:id}" -o json | ConvertFrom-Json
  if ($profiles.Count -eq 0) {
    Write-Host "No Traffic Manager profiles found." -ForegroundColor Green
    return
  }
  foreach ($profile in $profiles) {
    Write-Host "Deleting Traffic Manager profile: $($profile.name)" -ForegroundColor Yellow
    if ($Force.IsPresent) {
      az network traffic-manager profile delete -g $RG --name $profile.name --yes
      Write-Host "  Deleted." -ForegroundColor Green
    } else {
      Write-Host "  Run with -Force to delete." -ForegroundColor Yellow
    }
  }
}

function Remove-APIMInstances {
  param([string]$RG)
  Write-Host "Checking for API Management instances in $RG..." -ForegroundColor Cyan
  $instances = az apim list -g $RG --query "[].{name:name,id:id}" -o json | ConvertFrom-Json
  if ($instances.Count -eq 0) {
    Write-Host "No APIM instances found." -ForegroundColor Green
    return
  }
  foreach ($instance in $instances) {
    Write-Host "Deleting APIM instance: $($instance.name) (this can take 30+ minutes)" -ForegroundColor Yellow
    if ($Force.IsPresent) {
      az apim delete -g $RG --name $instance.name --yes --no-wait
      Write-Host "  Deletion initiated (background). Check portal for status." -ForegroundColor Green
    } else {
      Write-Host "  Run with -Force to delete." -ForegroundColor Yellow
    }
  }
}

function Remove-AKSClusters {
  param([string]$RG)
  Write-Host "Checking for AKS clusters in $RG..." -ForegroundColor Cyan
  $clusters = az aks list -g $RG --query "[].{name:name,id:id}" -o json | ConvertFrom-Json
  if ($clusters.Count -eq 0) {
    Write-Host "No AKS clusters found." -ForegroundColor Green
    return
  }
  foreach ($cluster in $clusters) {
    Write-Host "Deleting AKS cluster: $($cluster.name) (this can take 10+ minutes)" -ForegroundColor Yellow
    if ($Force.IsPresent) {
      az aks delete -g $RG --name $cluster.name --yes --no-wait
      Write-Host "  Deletion initiated (background). Check portal for status." -ForegroundColor Green
    } else {
      Write-Host "  Run with -Force to delete." -ForegroundColor Yellow
    }
  }
}

Write-Host "=== Azure Resource Cleanup Tool ===" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host ""

if (-not $Force.IsPresent) {
  Write-Warning "DRY RUN MODE: Add -Force to actually delete resources."
  Write-Host ""
}

if ($All.IsPresent) {
  Remove-FrontDoorResources -RG $ResourceGroupName
  Remove-TrafficManagerProfiles -RG $ResourceGroupName
  Remove-APIMInstances -RG $ResourceGroupName
  Remove-AKSClusters -RG $ResourceGroupName
} else {
  if ($FrontDoor.IsPresent) { Remove-FrontDoorResources -RG $ResourceGroupName }
  if ($TrafficManager.IsPresent) { Remove-TrafficManagerProfiles -RG $ResourceGroupName }
  if ($APIM.IsPresent) { Remove-APIMInstances -RG $ResourceGroupName }
  if ($AKS.IsPresent) { Remove-AKSClusters -RG $ResourceGroupName }
}

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Wait for background deletions to complete (check Azure Portal)."
Write-Host "2. Re-run terraform destroy or terraform apply to reconcile state."
Write-Host "3. If resources remain stuck, use: terraform state rm <resource-address>"
