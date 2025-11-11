# Infrastructure Restructuring Scripts

Scripts to transform your Terraform infrastructure from monolithic to modular design for fresh deployment.

## Quick Start

### Option 1: Complete Automated Setup (Recommended)
```powershell
cd infrastructure
.\setup-modular-infrastructure.ps1
```
This runs the complete workflow: restructure → validate → stage → commit

### Option 2: Quick Manual Restructure
```powershell
cd infrastructure
.\quick-restructure.ps1
```
Fast restructuring with minimal prompts. Then commit manually.

### Option 3: Detailed Control
```powershell
cd infrastructure
.\restructure-infrastructure.ps1 -ProjectName "your-project-name"
.\validate-structure.ps1
# Review, then commit
```

## Scripts Overview

### 1. `setup-modular-infrastructure.ps1` (Complete Workflow)
**Purpose:** One-command complete setup  
**What it does:**
- Checks prerequisites
- Restructures infrastructure  
- Validates configuration
- Stages git changes
- Optionally commits and pushes

**Usage:**
```powershell
# Interactive mode
.\setup-modular-infrastructure.ps1

# With project name
.\setup-modular-infrastructure.ps1 -ProjectName "mlops-prod"

# Auto-commit
.\setup-modular-infrastructure.ps1 -ProjectName "mlops-prod" -AutoCommit
```

**When to use:** First time setup or when you want everything done automatically

---

### 2. `restructure-infrastructure.ps1` (Detailed Restructuring)
**Purpose:** Comprehensive restructuring with full control  
**What it does:**
- Creates timestamped backup
- Renames old files (main.tf → main-old.tf)
- Activates modular structure (main-new.tf → main.tf)
- Updates project name in tfvars
- Formats Terraform files
- Validates configuration
- Cleans local state
- Generates git commands and deployment instructions

**Usage:**
```powershell
# Interactive (prompts for project name)
.\restructure-infrastructure.ps1

# With project name
.\restructure-infrastructure.ps1 -ProjectName "mlops-enterprise"

# Skip backup (not recommended)
.\restructure-infrastructure.ps1 -SkipBackup

# Skip validation
.\restructure-infrastructure.ps1 -SkipValidation
```

**Outputs:**
- `backup-YYYYMMDD-HHMMSS/` - Backup directory
- `git-commands.txt` - Ready-to-use git commands
- `DEPLOYMENT_INSTRUCTIONS.md` - Step-by-step deployment guide

**When to use:** When you need detailed control and want comprehensive documentation

---

### 3. `quick-restructure.ps1` (Fast & Simple)
**Purpose:** Minimal-prompt quick restructuring  
**What it does:**
- Quick backup
- Renames old files
- Activates new structure
- Updates project name (optional)
- Formats files
- Cleans state

**Usage:**
```powershell
.\quick-restructure.ps1
# Prompts once for project name, then executes
```

**When to use:** When you know what you're doing and want speed

---

### 4. `validate-structure.ps1` (Validation Only)
**Purpose:** Comprehensive validation without changes  
**What it does:**
- Checks module structure (12 validation checks)
- Validates Terraform syntax
- Verifies file consistency
- Checks tfvars format
- Reviews git status
- Provides detailed report

**Usage:**
```powershell
.\validate-structure.ps1
```

**Validation Checks:**
1. ✓ Main configuration files exist
2. ✓ Modules directory structure
3. ✓ Module file completeness
4. ✓ Terraform syntax validation
5. ✓ Module usage in main.tf
6. ✓ Outputs reference modules
7. ✓ Backup files present
8. ✓ Tfvars files exist
9. ✓ Project name format
10. ✓ Git repository detected
11. ✓ Clean state (no local state)
12. ✓ Documentation present

**When to use:** After restructuring, before committing, or anytime to verify structure

---

## Workflow Comparison

### Recommended Workflow (Complete)
```powershell
.\setup-modular-infrastructure.ps1 -ProjectName "mlops-prod"
# Answer 'y' to commit prompt
# Done! ✓
```

### Manual Workflow (Full Control)
```powershell
# 1. Restructure
.\restructure-infrastructure.ps1 -ProjectName "mlops-prod"

# 2. Validate
.\validate-structure.ps1

# 3. Review changes
git status
git diff main.tf

# 4. Commit (use commands from git-commands.txt)
git add .
git commit -m "Refactor: Modular infrastructure"
git push origin deployment-pipeline
```

### Quick Workflow (Experienced Users)
```powershell
.\quick-restructure.ps1
git add .
git commit -m "Refactor: Modular infrastructure"
git push
```

## What Gets Changed

### Files Renamed (backed up)
- `main.tf` → `main-old.tf`
- `outputs.tf` → `outputs-old.tf`
- `aks.tf` → `aks-old.tf`

### Files Activated
- `main-new.tf` → `main.tf` (modular version)
- `outputs-new.tf` → `outputs.tf` (module outputs)

### Files Updated
- `terraform.tfvars.dev-edge-learning` (project name)
- `terraform.tfvars.prod` (project name)
- `terraform.tfvars.minimal` (project name)
- `terraform.tfvars.free-tier` (project name)

### Files Created
- `backup-YYYYMMDD-HHMMSS/` - Backup directory
- `git-commands.txt` - Git commands
- `DEPLOYMENT_INSTRUCTIONS.md` - Deployment guide

### State Cleaned (for fresh deployment)
- `.terraform/` - Removed
- `.terraform.lock.hcl` - Removed
- `terraform.tfstate` - Removed
- `terraform.tfstate.backup` - Removed

## Module Structure

After restructuring:
```
infrastructure/
├── main.tf              # NEW - Orchestrates modules (150 lines)
├── outputs.tf           # NEW - Module output references
├── variables.tf         # UNCHANGED
├── backend.tf           # UNCHANGED
├── monitoring.tf        # UNCHANGED (complex interdependencies)
├── rbac.tf              # UNCHANGED
├── main-old.tf          # OLD - Backup of monolithic version
├── outputs-old.tf       # OLD - Backup
└── modules/
    ├── networking/      # VNet, Subnets, NSGs
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── storage/         # Storage, ACR
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ml-workspace/    # ML Workspace, Key Vault
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── aks/             # Kubernetes
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Rollback

If you need to rollback:
```powershell
# Restore old files
mv main.tf main-new.tf
mv outputs.tf outputs-new.tf
mv main-old.tf main.tf
mv outputs-old.tf outputs.tf
mv aks-old.tf aks.tf

# Reinitialize
terraform init -reconfigure
```

Or restore from backup:
```powershell
$backup = Get-ChildItem "backup-*" | Sort-Object CreationTime -Descending | Select-Object -First 1
Copy-Item "$backup\*" -Destination . -Force
```

## Troubleshooting

### "Modules directory not found"
**Solution:** Ensure you ran the restructuring from the correct directory and modules were created

### "Terraform not found"
**Solution:** Install Terraform or skip validation with `-SkipValidation`

### "Git not a repository"
**Solution:** Initialize git: `git init`

### "Permission denied"
**Solution:** Run PowerShell as Administrator or adjust execution policy:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Module validation failed"
**Solution:** Run `.\validate-structure.ps1` to see specific issues

## After Restructuring

### Next Steps
1. **Review Changes:** `git status`, `git diff`
2. **Commit:** `git commit -m "Refactor: Modular infrastructure"`
3. **Push:** `git push origin deployment-pipeline`
4. **Deploy:** GitHub Actions → Infrastructure Deployment → Run workflow

### Deployment
- Go to GitHub Actions
- Select "Infrastructure Deployment" workflow
- Choose: environment=dev, destroy=false
- Monitor deployment (~20-30 minutes)

### Verification
```powershell
# Check resource group
az group show --name <PROJECT>-dev-rg

# Check ML workspace
az ml workspace show --name <PROJECT>-dev-mlw --resource-group <PROJECT>-dev-rg

# Check AKS (if enabled)
az aks show --name <PROJECT>-dev-aks --resource-group <PROJECT>-dev-rg
```

## Documentation

- **MODULARIZATION_GUIDE.md** - Complete migration guide with state migration
- **DEPLOYMENT_INSTRUCTIONS.md** - Fresh deployment steps
- **modules/README.md** - Module documentation and best practices

## Support

For issues:
1. Run validation: `.\validate-structure.ps1`
2. Check logs in backup directory
3. Review MODULARIZATION_GUIDE.md
4. Check GitHub Actions logs after deployment
