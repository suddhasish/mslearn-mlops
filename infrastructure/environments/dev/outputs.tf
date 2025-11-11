# DEV Environment Outputs

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.mlops.name
}

output "resource_group_location" {
  description = "Resource group location"
  value       = azurerm_resource_group.mlops.location
}

output "ml_workspace_name" {
  description = "ML Workspace name"
  value       = module.ml_workspace.workspace_name
}

output "ml_workspace_id" {
  description = "ML Workspace ID"
  value       = module.ml_workspace.workspace_id
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "AKS cluster ID"
  value       = module.aks.cluster_id
}

output "storage_account_name" {
  description = "Storage account name"
  value       = module.storage.storage_account_name
}

output "container_registry_name" {
  description = "Container registry name"
  value       = module.storage.container_registry_name
}

output "container_registry_login_server" {
  description = "Container registry login server"
  value       = module.storage.container_registry_login_server
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = module.ml_workspace.key_vault_name
}

output "application_insights_name" {
  description = "Application Insights name"
  value       = module.ml_workspace.application_insights_name
}

output "deployment_summary" {
  description = "DEV environment deployment summary"
  value = {
    environment        = "dev"
    resource_group     = azurerm_resource_group.mlops.name
    ml_workspace       = module.ml_workspace.workspace_name
    aks_cluster        = module.aks.cluster_name
    storage_account    = module.storage.storage_account_name
    container_registry = module.storage.container_registry_name
    key_vault          = module.ml_workspace.key_vault_name
    location           = azurerm_resource_group.mlops.location
    cost_management    = var.enable_cost_alerts ? "Enabled" : "Disabled"
    monthly_budget     = var.monthly_budget_amount
  }
}
