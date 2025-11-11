# Infrastructure Modularization Migration Guide

## Overview

Your infrastructure has been refactored from a monolithic structure to a modular design for better maintainability, reusability, and clarity.

## What Changed

### Old Structure (Monolithic)
```
infrastructure/
├── main.tf              # 500+ lines - ALL resources
├── variables.tf         # All variables
├── outputs.tf           # All outputs
├── aks.tf               # AKS-specific (200+ lines)
├── monitoring.tf        # Monitoring resources
├── rbac.tf              # Role assignments
└── other files...
```

### New Structure (Modular)
```
infrastructure/
├── main-new.tf          # 150 lines - module orchestration
├── variables.tf         # Same - no changes
├── outputs-new.tf       # Updated - references module outputs
└── modules/
    ├── networking/      # VNet, Subnets, NSGs
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── storage/         # Storage, ACR
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── ml-workspace/    # ML Workspace, App Insights, Key Vault
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── aks/             # AKS Cluster
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Migration Steps

### Option 1: Fresh Deployment (Recommended for Dev)

1. **Backup existing state:**
```powershell
cd d:\MLOPS\MLOPS-AZURE\mslearn-mlops\infrastructure
terraform state pull > backup-state.json
```

2. **Rename files:**
```powershell
mv main.tf main-old.tf
mv outputs.tf outputs-old.tf
mv main-new.tf main.tf
mv outputs-new.tf outputs.tf
```

3. **Initialize modules:**
```powershell
terraform init -upgrade
```

4. **Plan and verify:**
```powershell
terraform plan
```

5. **Apply changes:**
```powershell
terraform apply
```

### Option 2: State Migration (For Production)

If you have existing resources and want to avoid recreation:

1. **Move resources to modules:**
```powershell
# Example: Move VNet to networking module
terraform state mv azurerm_virtual_network.mlops module.networking.azurerm_virtual_network.vnet

# Move subnets
terraform state mv azurerm_subnet.ml_subnet module.networking.azurerm_subnet.ml_subnet
terraform state mv azurerm_subnet.aks_subnet module.networking.azurerm_subnet.aks_subnet

# Move storage resources
terraform state mv azurerm_storage_account.mlops module.storage.azurerm_storage_account.storage
terraform state mv azurerm_container_registry.mlops module.storage.azurerm_container_registry.acr

# Move ML workspace resources
terraform state mv azurerm_machine_learning_workspace.mlops module.ml_workspace.azurerm_machine_learning_workspace.workspace
terraform state mv azurerm_key_vault.mlops module.ml_workspace.azurerm_key_vault.vault
# ... and so on
```

2. **Verify no changes:**
```powershell
terraform plan
# Should show "No changes" if migration is complete
```

## Breaking Changes

### Resource References

**Before:**
```hcl
azurerm_storage_account.mlops.id
azurerm_virtual_network.mlops.name
```

**After:**
```hcl
module.storage.storage_account_id
module.networking.vnet_name
```

### Outputs

**Before:**
```hcl
output "storage_account_name" {
  value = azurerm_storage_account.mlops.name
}
```

**After:**
```hcl
output "storage_account_name" {
  value = module.storage.storage_account_name
}
```

## Files Kept in Root

Some files remain in the root directory because they have complex interdependencies:

- **monitoring.tf** - References resources from multiple modules
- **rbac.tf** - Role assignments across resources
- **cost-management.tf** - Budget and cost controls
- **devops-integration.tf** - Optional DevOps features
- **cache.tf** - Redis cache (optional)
- **private-endpoints.tf** - Cross-module networking

## Benefits

### 1. **Better Organization**
- Each module has a single responsibility
- Easy to find specific resources
- Clear dependencies between components

### 2. **Reusability**
- Use modules across dev/staging/prod
- Share modules between projects
- Publish to Terraform Registry

### 3. **Easier Testing**
- Test modules independently
- Faster validation cycles
- Isolated changes

### 4. **Simplified Maintenance**
- Update one module without affecting others
- Clear interfaces (variables/outputs)
- Easier code reviews

### 5. **Team Collaboration**
- Different teams can own different modules
- Parallel development
- Reduced merge conflicts

## Validation Checklist

After migration, verify:

- [ ] `terraform init` completes successfully
- [ ] `terraform validate` passes
- [ ] `terraform plan` shows expected changes (or no changes for state migration)
- [ ] All outputs are accessible
- [ ] Resources are correctly grouped in modules
- [ ] Dependencies between modules are correct
- [ ] GitHub Actions pipeline runs successfully

## Rollback Plan

If issues occur:

1. **Restore old files:**
```powershell
mv main.tf main-new.tf
mv outputs.tf outputs-new.tf
mv main-old.tf main.tf
mv outputs-old.tf outputs.tf
```

2. **Reinitialize:**
```powershell
terraform init -reconfigure
```

3. **Verify state:**
```powershell
terraform plan
# Should show no changes
```

## Next Steps

1. **Test in dev environment first**
2. **Update CI/CD pipelines** (if they reference specific resource names)
3. **Document module usage** for your team
4. **Consider creating more modules** (monitoring, security, etc.)
5. **Version modules** for production stability

## Support

For issues during migration:
1. Check `terraform.log` for detailed errors
2. Verify module paths are correct (`./modules/...`)
3. Ensure all module outputs are properly exported
4. Review state file for resource locations

## Example: Complete State Migration Script

```powershell
# Networking Module
terraform state mv azurerm_virtual_network.mlops module.networking.azurerm_virtual_network.vnet
terraform state mv azurerm_subnet.ml_subnet module.networking.azurerm_subnet.ml_subnet
terraform state mv azurerm_subnet.aks_subnet module.networking.azurerm_subnet.aks_subnet
terraform state mv azurerm_subnet.private_endpoint_subnet module.networking.azurerm_subnet.private_endpoint_subnet
terraform state mv azurerm_network_security_group.ml_nsg module.networking.azurerm_network_security_group.ml_nsg
terraform state mv azurerm_network_security_group.aks_nsg module.networking.azurerm_network_security_group.aks_nsg
terraform state mv azurerm_subnet_network_security_group_association.ml_nsg_association module.networking.azurerm_subnet_network_security_group_association.ml_nsg_association
terraform state mv azurerm_subnet_network_security_group_association.aks_nsg_association module.networking.azurerm_subnet_network_security_group_association.aks_nsg_association

# Storage Module
terraform state mv azurerm_storage_account.mlops module.storage.azurerm_storage_account.storage
terraform state mv azurerm_container_registry.mlops module.storage.azurerm_container_registry.acr

# ML Workspace Module
terraform state mv azurerm_log_analytics_workspace.mlops module.ml_workspace.azurerm_log_analytics_workspace.workspace
terraform state mv azurerm_application_insights.mlops module.ml_workspace.azurerm_application_insights.insights
terraform state mv null_resource.appinsights_workspace_migration module.ml_workspace.null_resource.appinsights_workspace_migration
terraform state mv azurerm_key_vault.mlops module.ml_workspace.azurerm_key_vault.vault
terraform state mv azurerm_machine_learning_workspace.mlops module.ml_workspace.azurerm_machine_learning_workspace.workspace
terraform state mv azurerm_machine_learning_compute_cluster.cpu_cluster module.ml_workspace.azurerm_machine_learning_compute_cluster.cpu_cluster

# If GPU cluster exists:
# terraform state mv 'azurerm_machine_learning_compute_cluster.gpu_cluster[0]' 'module.ml_workspace.azurerm_machine_learning_compute_cluster.gpu_cluster[0]'

# AKS Module (if AKS is enabled)
# terraform state mv 'azurerm_kubernetes_cluster.mlops[0]' 'module.aks.azurerm_kubernetes_cluster.aks[0]'
# terraform state mv 'azurerm_kubernetes_cluster_node_pool.gpu_pool[0]' 'module.aks.azurerm_kubernetes_cluster_node_pool.gpu_pool[0]'
# terraform state mv 'azurerm_role_assignment.aks_acr[0]' 'module.aks.azurerm_role_assignment.aks_acr[0]'
# terraform state mv 'azurerm_role_assignment.aks_network[0]' 'module.aks.azurerm_role_assignment.aks_network[0]'

# Verify
terraform plan
```

Save this script and run it step by step, checking for errors after each command.
