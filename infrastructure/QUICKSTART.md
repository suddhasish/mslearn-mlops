# 🚀 Quick Start - Infrastructure Restructuring

## TL;DR - Run This Now

```powershell
cd d:\MLOPS\MLOPS-AZURE\mslearn-mlops\infrastructure
.\setup-modular-infrastructure.ps1
```

That's it! The script handles everything automatically.

---

## What You Have Now

✅ **4 PowerShell Scripts Created:**

1. **`setup-modular-infrastructure.ps1`** - Complete automated workflow ⭐ **START HERE**
2. **`restructure-infrastructure.ps1`** - Detailed restructuring with full control
3. **`quick-restructure.ps1`** - Fast minimal-prompt version
4. **`validate-structure.ps1`** - Validation and verification

✅ **4 Infrastructure Modules:**
- `modules/networking/` - VNet, Subnets, NSGs
- `modules/storage/` - Storage Account, Container Registry
- `modules/ml-workspace/` - ML Workspace, Key Vault, App Insights
- `modules/aks/` - Kubernetes cluster

✅ **Documentation:**
- `MODULARIZATION_GUIDE.md` - Complete migration details
- `SCRIPTS_README.md` - Script documentation
- `modules/README.md` - Module documentation

---

## Step-by-Step (First Time)

### 1. Run Setup Script
```powershell
cd infrastructure
.\setup-modular-infrastructure.ps1
```

**What happens:**
- Backs up existing files to `backup-YYYYMMDD-HHMMSS/`
- Renames `main.tf` → `main-old.tf`
- Activates `main-new.tf` → `main.tf`
- Prompts for new project name (or press Enter to keep existing)
- Formats all Terraform files
- Validates configuration
- Stages files in git
- Asks if you want to commit

### 2. Review Changes (Optional)
```powershell
git status          # See what's staged
git diff main.tf    # Compare old vs new
```

### 3. Commit & Push
Answer 'y' when prompted, or run manually:
```powershell
git commit -m "Refactor: Modular infrastructure"
git push origin deployment-pipeline
```

### 4. Deploy
1. Go to GitHub: Actions tab
2. Select: "Infrastructure Deployment"
3. Click: "Run workflow"
4. Choose: `environment = dev`, `destroy = false`
5. Click: "Run workflow" button
6. Wait ~20-30 minutes

---

## Alternative: Quick Mode

For experienced users who want speed:

```powershell
.\quick-restructure.ps1
git add .
git commit -m "Refactor: Modular infrastructure"
git push
```

---

## Verification Checklist

After running setup script:

- [ ] Backup created in `backup-*/` directory
- [ ] `main.tf` now uses modules (check: `module "networking"`)
- [ ] `main-old.tf` exists (backup)
- [ ] All modules present in `modules/` directory
- [ ] Project name updated in tfvars files
- [ ] Git status shows staged changes
- [ ] Validation passed (12/12 checks)

Run validation anytime:
```powershell
.\validate-structure.ps1
```

---

## What Changed

### Before (Monolithic)
```
main.tf - 500+ lines
├── All resources defined inline
├── Hard to maintain
└── Difficult to reuse
```

### After (Modular)
```
main.tf - 150 lines
├── module "networking"
├── module "storage"
├── module "ml_workspace"
└── module "aks"
    └── Each module is self-contained
```

---

## Troubleshooting

### Script won't run
```powershell
# Fix execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Can't find modules
```powershell
# Verify you're in infrastructure directory
cd d:\MLOPS\MLOPS-AZURE\mslearn-mlops\infrastructure
ls modules/  # Should show 4 directories
```

### Terraform validation fails
```powershell
# Reinitialize
terraform init -upgrade
.\validate-structure.ps1
```

### Need to rollback
```powershell
mv main.tf main-new.tf
mv main-old.tf main.tf
mv outputs-old.tf outputs.tf
```

---

## Project Name Requirements

When prompted for project name:
- ✅ Lowercase letters only
- ✅ Numbers allowed
- ✅ Hyphens allowed
- ✅ Max 15 characters
- ❌ No uppercase
- ❌ No underscores
- ❌ No special chars

**Good:** `mlops-prod`, `ml-ops-2024`, `enterprise-ml`  
**Bad:** `MLOps_Prod`, `ml_ops_production_environment`

---

## After Deployment

### Verify Resources
```powershell
# Check resource group
az group show --name <project>-dev-rg

# Check ML workspace
az ml workspace show -n <project>-dev-mlw -g <project>-dev-rg

# Check AKS (if enabled)
az aks show -n <project>-dev-aks -g <project>-dev-rg
```

### View Outputs
In GitHub Actions, check the "Terraform Apply" step outputs for:
- Resource group name
- ML workspace URL
- AKS cluster FQDN
- Storage account name
- Key vault URI

---

## Files You Can Safely Delete Later

After successful deployment and verification:
- `main-old.tf` - Old monolithic version (keep for rollback)
- `outputs-old.tf` - Old outputs
- `aks-old.tf` - Old AKS config
- `main-new.tf` - Staging file (no longer needed)
- `outputs-new.tf` - Staging file (no longer needed)
- `backup-*/` directories - Keep at least one recent backup

---

## Need Help?

**Detailed Documentation:**
```powershell
cat MODULARIZATION_GUIDE.md      # Complete migration guide
cat SCRIPTS_README.md            # Script documentation  
cat modules/README.md            # Module documentation
```

**Quick Validation:**
```powershell
.\validate-structure.ps1         # 12-point checklist
```

**View Git Commands:**
```powershell
cat git-commands.txt             # After running restructure script
```

---

## Summary

✅ **Created:** 4 automation scripts  
✅ **Created:** 4 reusable modules  
✅ **Created:** 3 documentation files  
✅ **Ready for:** Fresh deployment  
✅ **Breaking changes:** Yes (requires new deployment)  
✅ **Rollback available:** Yes (backup files + git history)  

## 🎯 Next Action

**Run this command now:**
```powershell
cd d:\MLOPS\MLOPS-AZURE\mslearn-mlops\infrastructure
.\setup-modular-infrastructure.ps1
```

Then follow the prompts! 🚀
