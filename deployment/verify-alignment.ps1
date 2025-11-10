param(
  [Parameter(Mandatory=$true)][string]$ResourceGroupName,
  [string]$VarFile = "infrastructure/terraform.tfvars",
  [string]$WorkingDir = "infrastructure",
  [switch]$RunPlan
)

# Purpose: Verify alignment between Azure resources and Terraform state for a given resource group
# - Lists Azure resources in the RG and compares with Terraform state resource IDs
# - Optionally runs `terraform plan -detailed-exitcode` to detect drift at config level
#
# Requirements: az CLI logged in; terraform installed; run from repo root (or pass -WorkingDir)

$ErrorActionPreference = "Stop"

function Ensure-Command {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name"
  }
}

Ensure-Command -Name az
Ensure-Command -Name terraform

# Resolve paths
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
# Move up from deployment folder to repo root if invoked from this script's folder
if ((Split-Path $repoRoot -Leaf) -eq 'deployment') {
  $repoRoot = Split-Path -Parent $repoRoot
}
$infraDir = Join-Path $repoRoot $WorkingDir
$varFilePath = Join-Path $repoRoot $VarFile

Write-Host "Repo root: $repoRoot"
Write-Host "Infra dir:  $infraDir"
Write-Host "Var file:   $varFilePath"

if (-not (Test-Path $infraDir)) { throw "Infra dir not found: $infraDir" }
if (-not (Test-Path $varFilePath)) { Write-Warning "Var file not found: $varFilePath (continuing)" }

# Get Azure resources in RG
Write-Host "Querying Azure resources in resource group $ResourceGroupName..."
$azResources = az resource list -g $ResourceGroupName --query "[].{id:id,name:name,type:type}" -o json | ConvertFrom-Json
$azureIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($r in $azResources) { [void]$azureIds.Add($r.id) }
Write-Host ("Azure resources: {0}" -f $azureIds.Count)

# Pull Terraform state as JSON
Push-Location $infraDir
try {
  Write-Host "Pulling Terraform state JSON..."
  $stateJson = terraform state pull
  if (-not $stateJson) { throw "Empty terraform state (is backend configured and accessible?)" }
  $state = $stateJson | ConvertFrom-Json
}
catch {
  Pop-Location
  throw $_
}

function Get-TerraformIds {
  param([object]$Node)
  $ids = New-Object System.Collections.Generic.List[string]
  if ($null -eq $Node) { return $ids }
  if ($Node.PSObject.Properties.Name -contains 'resources') {
    foreach ($res in $Node.resources) {
      if ($res.mode -ne 'managed') { continue }
      if ($res.instances) {
        foreach ($inst in $res.instances) {
          $id = $inst.attributes.id
          if ($id) { $ids.Add($id) }
        }
      }
      if ($res.depends_on) {
        # ignore depends_on
      }
    }
  }
  if ($Node.PSObject.Properties.Name -contains 'child_modules') {
    foreach ($mod in $Node.child_modules) {
      $ids.AddRange((Get-TerraformIds -Node $mod))
    }
  }
  return $ids
}

$tfIds = Get-TerraformIds -Node $state
$tfIdSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($id in $tfIds) { if ($id) { [void]$tfIdSet.Add($id) } }
Write-Host ("Terraform state resources: {0}" -f $tfIdSet.Count)

# Compare
$unmanagedInAzure = @()
foreach ($id in $azureIds) { if (-not $tfIdSet.Contains($id)) { $unmanagedInAzure += $id } }

$missingInAzure = @()
foreach ($id in $tfIdSet) { if (-not $azureIds.Contains($id)) { $missingInAzure += $id } }

Write-Host "--- Alignment Report ---"
if ($unmanagedInAzure.Count -eq 0 -and $missingInAzure.Count -eq 0) {
  Write-Host "Azure RG and Terraform state look aligned by resource IDs." -ForegroundColor Green
} else {
  if ($unmanagedInAzure.Count -gt 0) {
    Write-Warning "Resources in Azure but not in Terraform state (unmanaged):"
    $unmanagedInAzure | ForEach-Object { Write-Host "  $_" }
  }
  if ($missingInAzure.Count -gt 0) {
    Write-Warning "Resources in Terraform state but not found in Azure (stale/removed):"
    $missingInAzure | ForEach-Object { Write-Host "  $_" }
  }
}

if ($RunPlan.IsPresent) {
  Write-Host "Running terraform init/plan with detailed exit code..."
  try {
    terraform init -input=false | Out-Null
    $planCmd = @('plan','-detailed-exitcode','-input=false')
    if (Test-Path $varFilePath) { $planCmd += @('-var-file', (Resolve-Path $varFilePath)) }
    & terraform @planCmd
    $exit = $LASTEXITCODE
    if ($exit -eq 0) {
      Write-Host "Plan: ALIGNED (no changes)." -ForegroundColor Green
    } elseif ($exit -eq 2) {
      Write-Warning "Plan indicates DRIFT (changes present). Review plan output above."
    } else {
      throw "Plan failed with exit code $exit"
    }
  } finally { Pop-Location }
} else {
  Pop-Location
}
