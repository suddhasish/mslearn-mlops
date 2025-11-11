# Output Values for Modular Infrastructure
# Provides essential information for connecting to deployed resources

# Resource Group Information
output "resource_group_name" {
  description = "Name of the resource group containing all MLOps resources"
  value       = azurerm_resource_group.mlops.name
}

output "resource_group_location" {
  description = "Azure region where resources are deployed"
  value       = azurerm_resource_group.mlops.location
}

# Networking Module Outputs
output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = module.networking.vnet_name
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = module.networking.vnet_id
}

output "ml_subnet_id" {
  description = "Resource ID of the ML subnet"
  value       = module.networking.ml_subnet_id
}

output "aks_subnet_id" {
  description = "Resource ID of the AKS subnet"
  value       = module.networking.aks_subnet_id
}

# Storage Module Outputs
output "storage_account_name" {
  description = "Name of the primary storage account"
  value       = module.storage.storage_account_name
}

output "storage_account_id" {
  description = "ID of the primary storage account"
  value       = module.storage.storage_account_id
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint for the storage account"
  value       = module.storage.storage_account_primary_blob_endpoint
}

output "container_registry_name" {
  description = "Name of the Azure Container Registry"
  value       = module.storage.container_registry_name
}

output "container_registry_id" {
  description = "ID of the Azure Container Registry"
  value       = module.storage.container_registry_id
}

output "container_registry_login_server" {
  description = "Login server URL for the container registry"
  value       = module.storage.container_registry_login_server
}

# ML Workspace Module Outputs
output "ml_workspace_name" {
  description = "Name of the Azure Machine Learning workspace"
  value       = module.ml_workspace.workspace_name
}

output "ml_workspace_id" {
  description = "Resource ID of the Azure Machine Learning workspace"
  value       = module.ml_workspace.workspace_id
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = module.ml_workspace.key_vault_name
}

output "key_vault_id" {
  description = "ID of the Azure Key Vault"
  value       = module.ml_workspace.key_vault_id
}

output "application_insights_name" {
  description = "Name of the Application Insights instance"
  value       = module.ml_workspace.application_insights_name
}

output "application_insights_id" {
  description = "ID of the Application Insights instance"
  value       = module.ml_workspace.application_insights_id
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = module.ml_workspace.application_insights_instrumentation_key
  sensitive   = true
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = module.ml_workspace.log_analytics_workspace_name
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace"
  value       = module.ml_workspace.log_analytics_workspace_id
}

# AKS Module Outputs
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster"
  value       = module.aks.cluster_id
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.cluster_fqdn
}

output "aks_kube_config" {
  description = "Kubernetes configuration for the AKS cluster"
  value       = module.aks.kube_config
  sensitive   = true
}

# Environment and Project Information
output "environment" {
  description = "Environment name (dev, staging, prod)"
  value       = local.environment
}

output "project_name" {
  description = "Project name used for resource naming"
  value       = local.project
}

output "resource_prefix" {
  description = "Resource prefix used for naming"
  value       = local.resource_prefix
}

# RBAC Module Outputs
output "rbac_ml_identity_id" {
  description = "ML Workspace User-Assigned Identity ID"
  value       = module.rbac.ml_identity_id
}

output "rbac_cicd_app_id" {
  description = "CI/CD Application (Client) ID"
  value       = var.enable_cicd_identity ? module.rbac.cicd_app_id : null
}

# Cache Module Outputs
output "cache_redis_hostname" {
  description = "Redis Cache hostname"
  value       = var.enable_redis_cache ? module.cache.redis_cache_hostname : null
}

output "cache_redis_port" {
  description = "Redis Cache SSL port"
  value       = var.enable_redis_cache ? module.cache.redis_cache_ssl_port : null
}

# DevOps Integration Module Outputs
output "devops_data_factory_name" {
  description = "Data Factory name"
  value       = var.enable_devops_integration && var.enable_data_factory ? module.devops_integration.data_factory_name : null
}

output "devops_sql_server_name" {
  description = "SQL Server name"
  value       = var.enable_devops_integration && var.enable_mssql ? module.devops_integration.sql_server_name : null
}

# Cost Management Module Outputs
output "cost_budget_id" {
  description = "Consumption Budget ID"
  value       = var.enable_cost_alerts ? module.cost_management.budget_id : null
}

output "cost_automation_account_name" {
  description = "Automation Account name"
  value       = var.enable_cost_alerts ? module.cost_management.automation_account_name : null
}

# Private Endpoints Module Outputs
output "private_endpoints_dns_zones" {
  description = "Private DNS Zone IDs"
  value       = var.enable_private_endpoints ? module.private_endpoints.private_dns_zone_ids : {}
}

# Deployment Summary
output "deployment_summary" {
  description = "Summary of the deployed MLOps infrastructure"
  value = {
    resource_group       = azurerm_resource_group.mlops.name
    ml_workspace         = module.ml_workspace.workspace_name
    aks_cluster          = module.aks.cluster_name
    storage_account      = module.storage.storage_account_name
    container_registry   = module.storage.container_registry_name
    key_vault            = module.ml_workspace.key_vault_name
    application_insights = module.ml_workspace.application_insights_name
    redis_cache          = var.enable_redis_cache ? "Enabled" : "Disabled"
    private_endpoints    = local.enable_private_endpoints ? "Enabled" : "Disabled"
    custom_rbac          = var.enable_custom_roles ? "Enabled" : "Disabled"
    devops_integration   = var.enable_devops_integration ? "Enabled" : "Disabled"
    cost_management      = var.enable_cost_alerts ? "Enabled" : "Disabled"
    environment          = local.environment
    location             = azurerm_resource_group.mlops.location
    subscription_id      = data.azurerm_client_config.current.subscription_id
  }
}
