## Verifying infrastructure alignment with Terraform

Use the `deployment/verify-alignment.ps1` script to check if your Azure resources match Terraform state and optionally detect drift with a plan.

### What it does
- Lists Azure resources in your Resource Group and compares their resource IDs to Terraform state IDs.
- Optionally runs `terraform plan -detailed-exitcode` to detect configuration drift.
- Prints a concise report:
  - Azure-only (unmanaged) resources
  - Terraform-only (stale) resources
  - Plan status (aligned vs drift)

### Prerequisites
- Azure CLI installed and logged in (same subscription as your Terraform backend).
- Terraform installed.
- Run from repo root or let the script default to `infrastructure/`.

### Quick start (PowerShell)
```powershell
# From repo root
# 1) Compare Azure RG vs Terraform state
./deployment/verify-alignment.ps1 -ResourceGroupName <your-rg-name>

# 2) Also run terraform plan with your dev tfvars
./deployment/verify-alignment.ps1 -ResourceGroupName <your-rg-name> -VarFile infrastructure/terraform.tfvars.dev-edge-learning -RunPlan

# For minimal profile instead of edge learning
./deployment/verify-alignment.ps1 -ResourceGroupName <your-rg-name> -VarFile infrastructure/terraform.tfvars.minimal -RunPlan
```

### How to interpret results
- "Azure RG and Terraform state look aligned" → the resource IDs overlap fully.
- Unmanaged resources → consider importing with `infrastructure/import-existing-resources.sh` or removing them manually if they’re not needed.
- Stale Terraform resources → consider `terraform state rm` for those IDs if they were deleted outside Terraform.
- Plan: ALIGNED → 0 changes. Plan: DRIFT → review changes and apply or reconcile.

### Tips
- Ensure the CI service principal has Storage Blob Data Contributor on the state storage account, and clear any stale locks.
- Run `terraform fmt -check -recursive` and `terraform validate` before plans to catch formatting and basic HCL issues.
- If you see provider/region quota errors during plan, try a nearby region or disable premium flags in your tfvars.
