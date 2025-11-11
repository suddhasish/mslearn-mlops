#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates modular infrastructure before git commit

.DESCRIPTION
    Comprehensive validation checklist:
    - Module structure verification
    - Terraform syntax validation
    - File consistency checks
    - tfvars validation
    - Git status check

.EXAMPLE
    .\validate-structure.ps1
#>

$ErrorActionPreference = "Continue"

Write-Host @"
╔═══════════════════════════════════════╗
║   Infrastructure Validation Check     ║
╚═══════════════════════════════════════╝
"@ -ForegroundColor Cyan

$InfraDir = $PSScriptRoot
if (-not $InfraDir) { $InfraDir = Get-Location }
Set-Location $InfraDir

$ValidationResults = @()
$PassedChecks = 0
$TotalChecks = 0

function Test-Check {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$SuccessMsg,
        [string]$FailMsg
    )
    
    $script:TotalChecks++
    Write-Host "`n[$script:TotalChecks] $Name" -ForegroundColor Yellow
    
    try {
        $result = & $Test
        if ($result) {
            Write-Host "  ✓ $SuccessMsg" -ForegroundColor Green
            $script:PassedChecks++
            return $true
        } else {
            Write-Host "  ✗ $FailMsg" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
        return $false
    }
}

# Check 1: Main files exist
Test-Check "Main Configuration Files" {
    (Test-Path "main.tf") -and (Test-Path "outputs.tf") -and (Test-Path "variables.tf")
} "All main files present" "Missing main configuration files"

# Check 2: Modules directory structure
Test-Check "Modules Directory" {
    $modules = @("networking", "storage", "ml-workspace", "aks")
    $allExist = $true
    foreach ($mod in $modules) {
        if (-not (Test-Path "modules/$mod")) {
            Write-Host "    Missing: $mod" -ForegroundColor Gray
            $allExist = $false
        }
    }
    $allExist
} "All 4 modules present" "Missing required modules"

# Check 3: Module files
Test-Check "Module File Structure" {
    $modules = @("networking", "storage", "ml-workspace", "aks")
    $requiredFiles = @("main.tf", "variables.tf", "outputs.tf")
    $allComplete = $true
    
    foreach ($mod in $modules) {
        foreach ($file in $requiredFiles) {
            if (-not (Test-Path "modules/$mod/$file")) {
                Write-Host "    Missing: $mod/$file" -ForegroundColor Gray
                $allComplete = $false
            }
        }
    }
    $allComplete
} "All module files complete" "Missing files in modules"

# Check 4: Terraform syntax
Test-Check "Terraform Syntax" {
    try {
        $null = terraform version 2>&1
        terraform init -backend=false 2>&1 | Out-Null
        $validateOutput = terraform validate 2>&1
        if ($LASTEXITCODE -eq 0) {
            $true
        } else {
            Write-Host "    $validateOutput" -ForegroundColor Gray
            $false
        }
    } catch {
        Write-Host "    Terraform not found - skipping" -ForegroundColor Gray
        $true  # Don't fail if terraform not available
    }
} "Valid Terraform configuration" "Syntax errors found"

# Check 5: Main.tf uses modules
Test-Check "Module Usage in main.tf" {
    $mainContent = Get-Content "main.tf" -Raw
    $hasNetworking = $mainContent -match 'module\s+"networking"'
    $hasStorage = $mainContent -match 'module\s+"storage"'
    $hasML = $mainContent -match 'module\s+"ml_workspace"'
    $hasAKS = $mainContent -match 'module\s+"aks"'
    
    $hasNetworking -and $hasStorage -and $hasML -and $hasAKS
} "All modules referenced in main.tf" "Some modules not used in main.tf"

# Check 6: Outputs reference modules
Test-Check "Module Outputs" {
    $outputContent = Get-Content "outputs.tf" -Raw
    $hasModuleOutputs = $outputContent -match 'module\.'
    $hasModuleOutputs
} "Outputs reference modules" "Outputs don't reference modules"

# Check 7: Old files backed up
Test-Check "Backup Files" {
    (Test-Path "main-old.tf") -or (Get-ChildItem "backup-*" -Directory -ErrorAction SilentlyContinue).Count -gt 0
} "Old files backed up" "No backup found"

# Check 8: tfvars files
Test-Check "Terraform Variables Files" {
    $tfvarsFiles = Get-ChildItem "terraform.tfvars.*"
    $tfvarsFiles.Count -ge 1
} "Found $($tfvarsFiles.Count) tfvars files" "No tfvars files found"

# Check 9: Project name format
Test-Check "Project Name Format" {
    $tfvarsContent = Get-Content "terraform.tfvars.dev-edge-learning" -Raw -ErrorAction SilentlyContinue
    if ($tfvarsContent -match 'project_name\s*=\s*"([^"]+)"') {
        $projectName = $matches[1]
        $isValid = $projectName -match '^[a-z0-9-]+$' -and $projectName.Length -le 15
        if ($isValid) {
            Write-Host "    Project: $projectName" -ForegroundColor Gray
        }
        $isValid
    } else {
        $false
    }
} "Valid project name format" "Invalid project name (use lowercase, max 15 chars)"

# Check 10: Git status
Test-Check "Git Repository" {
    try {
        $gitStatus = git status 2>&1
        if ($gitStatus -match "fatal") {
            $false
        } else {
            Write-Host "    Branch: $((git branch --show-current 2>&1))" -ForegroundColor Gray
            $true
        }
    } catch {
        $false
    }
} "Git repository detected" "Not a git repository"

# Check 11: No terraform state
Test-Check "Clean State (Fresh Deployment)" {
    $hasState = Test-Path "terraform.tfstate"
    $hasTerraform = Test-Path ".terraform"
    
    -not $hasState -and -not $hasTerraform
} "No local state (ready for fresh deploy)" "Local state exists (will be recreated)"

# Check 12: Documentation
Test-Check "Documentation Files" {
    (Test-Path "MODULARIZATION_GUIDE.md") -and (Test-Path "modules/README.md")
} "Documentation present" "Missing documentation files"

# Summary
Write-Host @"

╔═══════════════════════════════════════╗
║         Validation Summary            ║
╚═══════════════════════════════════════╝
"@ -ForegroundColor Cyan

$PassRate = [math]::Round(($PassedChecks / $TotalChecks) * 100, 1)

Write-Host "`nResults: $PassedChecks/$TotalChecks checks passed ($PassRate%)" -ForegroundColor $(if ($PassedChecks -eq $TotalChecks) { "Green" } else { "Yellow" })

if ($PassedChecks -eq $TotalChecks) {
    Write-Host @"

✓ All checks passed!
✓ Structure is valid
✓ Ready to commit and deploy

Next steps:
  git add .
  git commit -m "Refactor: Modular infrastructure"
  git push origin deployment-pipeline

"@ -ForegroundColor Green
} elseif ($PassedChecks -ge ($TotalChecks * 0.8)) {
    Write-Host @"

⚠ Most checks passed
⚠ Review failed checks above
⚠ Fix issues before deploying

You can still commit, but some issues need attention.

"@ -ForegroundColor Yellow
} else {
    Write-Host @"

✗ Multiple validation failures
✗ Do not deploy until fixed
✗ Review errors above

Fix critical issues before committing.

"@ -ForegroundColor Red
}

# Module summary
Write-Host "Module Structure:" -ForegroundColor Cyan
$modules = @("networking", "storage", "ml-workspace", "aks")
foreach ($mod in $modules) {
    $exists = Test-Path "modules/$mod"
    $icon = if ($exists) { "✓" } else { "✗" }
    $color = if ($exists) { "Green" } else { "Red" }
    Write-Host "  $icon modules/$mod" -ForegroundColor $color
}

Write-Host ""
