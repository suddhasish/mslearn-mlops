output "workspace_id" {
  description = "Machine Learning Workspace ID"
  value       = azurerm_machine_learning_workspace.workspace.id
}

output "workspace_name" {
  description = "Machine Learning Workspace name"
  value       = azurerm_machine_learning_workspace.workspace.name
}

output "key_vault_id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.vault.id
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.vault.name
}

output "application_insights_id" {
  description = "Application Insights ID"
  value       = azurerm_application_insights.insights.id
}

output "application_insights_name" {
  description = "Application Insights name"
  value       = azurerm_application_insights.insights.name
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.insights.instrumentation_key
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.workspace.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  value       = azurerm_log_analytics_workspace.workspace.name
}

output "aks_compute_name" {
  description = "AKS compute cluster name attached to Azure ML"
  value       = var.enable_aks_compute && var.aks_cluster_id != null ? azurerm_machine_learning_inference_cluster.aks_compute[0].name : null
}

output "aks_compute_id" {
  description = "AKS compute cluster ID in Azure ML"
  value       = var.enable_aks_compute && var.aks_cluster_id != null ? azurerm_machine_learning_inference_cluster.aks_compute[0].id : null
}
