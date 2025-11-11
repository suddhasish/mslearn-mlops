output "budget_id" {
  description = "Consumption Budget ID"
  value       = var.enable_cost_alerts ? azurerm_consumption_budget_resource_group.mlops[0].id : null
}

output "data_factory_id" {
  description = "Cost Analytics Data Factory ID"
  value       = var.enable_data_factory ? azurerm_data_factory.cost_analytics[0].id : null
}

output "data_factory_name" {
  description = "Cost Analytics Data Factory name"
  value       = var.enable_data_factory ? azurerm_data_factory.cost_analytics[0].name : null
}

output "logic_app_id" {
  description = "Cost Optimization Logic App ID"
  value       = var.enable_logic_app ? azurerm_logic_app_workflow.cost_optimization[0].id : null
}

output "automation_account_id" {
  description = "Automation Account ID"
  value       = var.enable_cost_alerts ? azurerm_automation_account.cost_optimization[0].id : null
}

output "automation_account_name" {
  description = "Automation Account name"
  value       = var.enable_cost_alerts ? azurerm_automation_account.cost_optimization[0].name : null
}

output "runbook_name" {
  description = "Scaling Runbook name"
  value       = var.enable_cost_alerts && var.aks_cluster_name != "" ? azurerm_automation_runbook.scale_resources[0].name : null
}
