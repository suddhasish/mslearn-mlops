# Application Insights Workspace Migration

## Issue
When Application Insights was initially deployed without `workspace_id`, Azure doesn't allow adding it later. The resource must be recreated.

## Solution Implemented
Added automatic migration handling in `infrastructure/main.tf`:

1. **null_resource.appinsights_workspace_migration** - Migration trigger
2. **lifecycle.replace_triggered_by** - Forces Application Insights recreation
3. **lifecycle.create_before_destroy** - Minimizes downtime during migration

## How It Works

### First Deployment (No App Insights exists)
- App Insights created with `workspace_id` from the start ✅
- No migration needed

### Existing Deployment (App Insights without workspace_id)
- Pipeline detects App Insights needs `workspace_id`
- `null_resource` triggers replacement
- App Insights recreated with `workspace_id` linked to Log Analytics
- All telemetry data preserved (stored in Log Analytics)

## Migration Process

### Automatic (via Pipeline)
```bash
terraform init
terraform plan  # Shows App Insights will be replaced
terraform apply # Recreates with workspace_id
```

### Manual Trigger (if needed)
Edit `main.tf` and increment `migration_version`:
```hcl
triggers = {
  migration_version = "2"  # Changed from "1"
  workspace_id      = azurerm_log_analytics_workspace.mlops.id
}
```

## What Happens During Migration

1. **Terraform Plan**: Shows `azurerm_application_insights.mlops` will be replaced
2. **Terraform Apply**:
   - Creates new Application Insights with same name (but different ID)
   - Configures `workspace_id` properly
   - Deletes old Application Insights
3. **Data Impact**: None - all data remains in Log Analytics workspace

## Verification

After migration, verify:
```bash
# Check App Insights has workspace_id
terraform state show azurerm_application_insights.mlops | grep workspace_id

# Should show:
# workspace_id = "/subscriptions/.../resourceGroups/.../providers/Microsoft.OperationalInsights/workspaces/..."
```

## When to Remove Migration Code

Safe to remove after **all environments** successfully migrated:

1. Dev environment migrated ✅
2. Staging environment migrated ✅  
3. Production environment migrated ✅

### Cleanup Steps
Remove from `main.tf`:
1. Delete `null_resource.appinsights_workspace_migration` block
2. Remove `replace_triggered_by` from Application Insights lifecycle
3. Keep `create_before_destroy = true` (best practice)

```hcl
# After cleanup, Application Insights should look like:
resource "azurerm_application_insights" "mlops" {
  name                = "${local.resource_prefix}-ai"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.mlops.id
  retention_in_days   = 90

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}
```

## Troubleshooting

### Error: "workspace_id can not be removed after set"
**Cause**: Trying to add workspace_id to existing App Insights  
**Fix**: Migration code handles this automatically by recreating resource

### Error: "Application Insights name already exists"
**Cause**: Old resource not fully deleted  
**Fix**: Wait 2-3 minutes for Azure deletion, then retry

### Data Loss Concern
**Answer**: No data loss - all telemetry stored in Log Analytics workspace, not in App Insights resource itself

## Timeline
- **Added**: 2025-11-11
- **Remove After**: All environments successfully migrated (estimated 2025-11-30)

## Related Files
- `infrastructure/main.tf` - Migration code
- `deployment/fix-appinsights-workspace.ps1` - Manual fix script (alternative)
- `.github/workflows/infrastructure-deploy.yml` - Pipeline handles automatically
