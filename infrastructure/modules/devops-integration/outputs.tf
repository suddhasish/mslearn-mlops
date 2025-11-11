output "data_factory_id" {
  description = "Data Factory ID"
  value       = var.enable_devops_integration && var.enable_data_factory ? azurerm_data_factory.devops_analytics[0].id : null
}

output "data_factory_name" {
  description = "Data Factory name"
  value       = var.enable_devops_integration && var.enable_data_factory ? azurerm_data_factory.devops_analytics[0].name : null
}

output "powerbi_name" {
  description = "Power BI Embedded name"
  value       = var.enable_devops_integration && var.enable_powerbi ? azurerm_powerbi_embedded.mlops_analytics[0].name : null
}

output "sql_server_name" {
  description = "SQL Server name"
  value       = var.enable_devops_integration && var.enable_mssql ? azurerm_mssql_server.mlops_analytics[0].name : null
}

output "sql_server_fqdn" {
  description = "SQL Server FQDN"
  value       = var.enable_devops_integration && var.enable_mssql ? azurerm_mssql_server.mlops_analytics[0].fully_qualified_domain_name : null
}

output "sql_database_name" {
  description = "SQL Database name"
  value       = var.enable_devops_integration && var.enable_mssql ? azurerm_mssql_database.mlops_analytics[0].name : null
}

output "eventgrid_topic_endpoint" {
  description = "Event Grid topic endpoint"
  value       = var.enable_devops_integration ? azurerm_eventgrid_topic.ml_events[0].endpoint : null
}

output "function_app_hostname" {
  description = "Function App hostname"
  value       = var.enable_devops_integration ? azurerm_linux_function_app.ml_events_processor[0].default_hostname : null
}

output "stream_analytics_name" {
  description = "Stream Analytics job name"
  value       = var.enable_devops_integration ? azurerm_stream_analytics_job.ml_analytics[0].name : null
}

output "eventhub_namespace_name" {
  description = "Event Hub namespace name"
  value       = var.enable_devops_integration ? azurerm_eventhub_namespace.ml_performance[0].name : null
}

output "cognitive_account_endpoint" {
  description = "Cognitive Services endpoint"
  value       = var.enable_devops_integration && var.enable_cognitive_services ? azurerm_cognitive_account.text_analytics[0].endpoint : null
}

output "synapse_workspace_name" {
  description = "Synapse workspace name"
  value       = var.enable_devops_integration && var.enable_synapse ? azurerm_synapse_workspace.mlops[0].name : null
}

output "communication_service_id" {
  description = "Communication Service ID"
  value       = var.enable_devops_integration && var.enable_communication_service ? azurerm_communication_service.mlops[0].id : null
}
