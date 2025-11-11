# PROD Environment Outputs

# ============================================================================
# RESOURCE GROUP OUTPUTS
# ============================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.mlops.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.mlops.location
}

# ============================================================================
# NETWORKING OUTPUTS
# ============================================================================

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.networking.vnet_name
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.networking.vnet_id
}

# ============================================================================
# STORAGE OUTPUTS
# ============================================================================

output "storage_account_name" {
  description = "Name of the storage account"
  value       = module.storage.storage_account_name
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = module.storage.storage_account_id
}

output "container_registry_name" {
  description = "Name of the container registry"
  value       = module.storage.container_registry_name
}

output "container_registry_login_server" {
  description = "Login server for the container registry"
  value       = module.storage.container_registry_login_server
}

# ============================================================================
# ML WORKSPACE OUTPUTS
# ============================================================================

output "ml_workspace_name" {
  description = "Name of the ML workspace"
  value       = module.ml_workspace.workspace_name
}

output "ml_workspace_id" {
  description = "ID of the ML workspace"
  value       = module.ml_workspace.workspace_id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.ml_workspace.key_vault_name
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = module.ml_workspace.key_vault_id
}

output "application_insights_name" {
  description = "Name of Application Insights"
  value       = module.ml_workspace.application_insights_name
}

output "log_analytics_workspace_id" {
  description = "ID of Log Analytics workspace"
  value       = module.ml_workspace.log_analytics_workspace_id
}

# ============================================================================
# AKS OUTPUTS
# ============================================================================

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = var.enable_aks_deployment ? module.aks.cluster_name : null
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = var.enable_aks_deployment ? module.aks.cluster_id : null
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = var.enable_aks_deployment ? module.aks.cluster_fqdn : null
}

# ============================================================================
# RBAC OUTPUTS
# ============================================================================

output "ml_identity_principal_id" {
  description = "Principal ID of ML user managed identity"
  value       = module.rbac.ml_identity_principal_id
}

output "ml_identity_client_id" {
  description = "Client ID of ML user managed identity"
  value       = module.rbac.ml_identity_client_id
}

output "cicd_sp_object_id" {
  description = "Object ID of CI/CD service principal"
  value       = var.enable_cicd_identity ? module.rbac.cicd_sp_object_id : null
}

# ============================================================================
# PRIVATE ENDPOINTS OUTPUTS
# ============================================================================

output "private_dns_zones" {
  description = "Private DNS zones created for private endpoints"
  value       = var.enable_private_endpoints ? module.private_endpoints.private_dns_zones : {}
}

output "private_endpoints" {
  description = "Private endpoints created"
  value       = var.enable_private_endpoints ? module.private_endpoints.private_endpoints : {}
}

# ============================================================================
# CACHE OUTPUTS
# ============================================================================

output "redis_cache_name" {
  description = "Name of the Redis cache"
  value       = var.enable_redis_cache ? module.cache.redis_cache_name : null
}

output "redis_cache_hostname" {
  description = "Hostname of the Redis cache"
  value       = var.enable_redis_cache ? module.cache.redis_cache_hostname : null
}

# ============================================================================
# COST MANAGEMENT OUTPUTS
# ============================================================================

output "automation_account_name" {
  description = "Name of the automation account"
  value       = var.enable_cost_alerts ? module.cost_management.automation_account_name : null
}

output "monthly_budget_name" {
  description = "Name of the monthly budget"
  value       = var.enable_cost_alerts ? module.cost_management.monthly_budget_name : null
}

# ============================================================================
# DEPLOYMENT SUMMARY
# ============================================================================

output "deployment_summary" {
  description = "Summary of deployed resources and configuration"
  value = {
    environment               = "prod"
    resource_group            = azurerm_resource_group.mlops.name
    location                  = azurerm_resource_group.mlops.location
    ml_workspace              = module.ml_workspace.workspace_name
    aks_cluster               = var.enable_aks_deployment ? module.aks.cluster_name : "Disabled"
    private_endpoints_enabled = var.enable_private_endpoints
    redis_cache_enabled       = var.enable_redis_cache
    custom_roles_enabled      = var.enable_custom_roles
    cicd_identity_enabled     = var.enable_cicd_identity
    cost_alerts_enabled       = var.enable_cost_alerts
    monthly_budget            = var.monthly_budget_amount
    purge_protection_enabled  = var.enable_purge_protection
  }
}
