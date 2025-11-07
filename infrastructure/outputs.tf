# Output Values for Infrastructure Resources
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

# Machine Learning Workspace
output "ml_workspace_name" {
  description = "Name of the Azure Machine Learning workspace"
  value       = azurerm_machine_learning_workspace.mlops.name
}

output "ml_workspace_id" {
  description = "Resource ID of the Azure Machine Learning workspace"
  value       = azurerm_machine_learning_workspace.mlops.id
}

output "ml_workspace_discovery_url" {
  description = "Discovery URL for the ML workspace"
  value       = azurerm_machine_learning_workspace.mlops.discovery_url
}

# Storage Account
output "storage_account_name" {
  description = "Name of the primary storage account"
  value       = azurerm_storage_account.mlops.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Primary blob endpoint for the storage account"
  value       = azurerm_storage_account.mlops.primary_blob_endpoint
}

# Container Registry
output "container_registry_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.mlops.name
}

output "container_registry_login_server" {
  description = "Login server URL for the container registry"
  value       = azurerm_container_registry.mlops.login_server
}

# Key Vault
output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = azurerm_key_vault.mlops.name
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = azurerm_key_vault.mlops.vault_uri
}

# AKS Cluster
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.mlops.name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.mlops.fqdn
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.mlops.id
}

output "aks_kube_config" {
  description = "Kubernetes configuration for the AKS cluster"
  value       = azurerm_kubernetes_cluster.mlops.kube_config_raw
  sensitive   = true
}

# Application Insights
output "application_insights_name" {
  description = "Name of the Application Insights instance"
  value       = azurerm_application_insights.mlops.name
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.mlops.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = azurerm_application_insights.mlops.connection_string
  sensitive   = true
}

# Log Analytics Workspace
output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.mlops.name
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.mlops.id
}

# Network Information
output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.mlops.name
}

output "ml_subnet_id" {
  description = "Resource ID of the ML subnet"
  value       = azurerm_subnet.ml_subnet.id
}

output "aks_subnet_id" {
  description = "Resource ID of the AKS subnet"
  value       = azurerm_subnet.aks_subnet.id
}

# Machine Learning Compute
output "ml_compute_cluster_name" {
  description = "Name of the ML compute cluster"
  value       = azurerm_machine_learning_compute_cluster.cpu_cluster.name
}

output "ml_gpu_compute_cluster_name" {
  description = "Name of the ML GPU compute cluster"
  value       = azurerm_machine_learning_compute_cluster.gpu_cluster.name
}

# API Management
output "api_management_name" {
  description = "Name of the API Management instance"
  value       = azurerm_api_management.mlops.name
}

output "api_management_gateway_url" {
  description = "Gateway URL for API Management"
  value       = azurerm_api_management.mlops.gateway_url
}

# Front Door
output "front_door_profile_name" {
  description = "Name of the Azure Front Door profile"
  value       = azurerm_cdn_frontdoor_profile.mlops.name
}

output "front_door_endpoint_hostname" {
  description = "Hostname of the Front Door endpoint"
  value       = azurerm_cdn_frontdoor_endpoint.mlops.host_name
}

# Service Principal for CI/CD
output "cicd_service_principal_application_id" {
  description = "Application ID of the CI/CD service principal"
  value       = azuread_application.mlops_cicd.client_id
}

output "cicd_service_principal_object_id" {
  description = "Object ID of the CI/CD service principal"
  value       = azuread_service_principal.mlops_cicd.object_id
}

# Budget Information
output "monthly_budget_amount" {
  description = "Monthly budget amount configured for cost management"
  value       = var.monthly_budget_amount
}

# Event Grid Topic
output "eventgrid_topic_name" {
  description = "Name of the Event Grid topic for ML events"
  value       = var.enable_devops_integration ? azurerm_eventgrid_topic.mlops_events[0].name : null
}

output "eventgrid_topic_endpoint" {
  description = "Endpoint URL of the Event Grid topic"
  value       = var.enable_devops_integration ? azurerm_eventgrid_topic.mlops_events[0].endpoint : null
}

# Function App
output "function_app_name" {
  description = "Name of the Function App for event processing"
  value       = var.enable_devops_integration ? azurerm_linux_function_app.mlops_functions[0].name : null
}

output "function_app_hostname" {
  description = "Default hostname of the Function App"
  value       = var.enable_devops_integration ? azurerm_linux_function_app.mlops_functions[0].default_hostname : null
}

# Private Endpoints (only if enabled)
output "private_endpoints_enabled" {
  description = "Whether private endpoints are enabled"
  value       = local.enable_private_endpoints
}

# DevOps Integration Outputs
output "devops_integration_enabled" {
  description = "Whether Azure DevOps integration is enabled"
  value       = var.enable_devops_integration
}

output "powerbi_embedded_name" {
  description = "Name of the Power BI Embedded instance (if enabled)"
  value       = var.enable_devops_integration ? azurerm_powerbi_embedded.mlops_analytics[0].name : null
}

output "sql_server_name" {
  description = "Name of the SQL Server for DevOps analytics (if enabled)"
  value       = var.enable_devops_integration ? azurerm_mssql_server.devops_analytics[0].name : null
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

# Monitoring Outputs
output "action_group_name" {
  description = "Name of the Azure Monitor action group for alerts"
  value       = azurerm_monitor_action_group.mlops_alerts.name
}

# Cost Management
output "cost_export_enabled" {
  description = "Whether cost management export is configured"
  value       = true
}

output "automation_account_name" {
  description = "Name of the Automation Account for cost optimization (if enabled)"
  value       = var.enable_cost_alerts ? azurerm_automation_account.cost_optimization[0].name : null
}

# Communication Services
output "communication_service_name" {
  description = "Name of the Communication Service for notifications"
  value       = azurerm_communication_service.mlops.name
}

# Synapse Analytics (if enabled)
output "synapse_workspace_name" {
  description = "Name of the Synapse workspace (if enabled)"
  value       = var.enable_synapse ? azurerm_synapse_workspace.mlops[0].name : null
}

# Deployment Summary
output "deployment_summary" {
  description = "Summary of the deployed MLOps infrastructure"
  value = {
    resource_group       = azurerm_resource_group.mlops.name
    ml_workspace         = azurerm_machine_learning_workspace.mlops.name
    aks_cluster          = azurerm_kubernetes_cluster.mlops.name
    storage_account      = azurerm_storage_account.mlops.name
    container_registry   = azurerm_container_registry.mlops.name
    key_vault            = azurerm_key_vault.mlops.name
    application_insights = azurerm_application_insights.mlops.name
    private_endpoints    = local.enable_private_endpoints ? "Enabled" : "Disabled"
    cost_management      = var.enable_cost_alerts ? "Enabled" : "Disabled"
    devops_integration   = var.enable_devops_integration ? "Enabled" : "Disabled"
    monthly_budget       = "$${var.monthly_budget_amount}"
    environment          = local.environment
  }
}