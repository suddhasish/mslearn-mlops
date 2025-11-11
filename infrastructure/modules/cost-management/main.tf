# Consumption Budget for Resource Group
resource "azurerm_consumption_budget_resource_group" "mlops" {
  count             = var.enable_cost_alerts ? 1 : 0
  name              = "${var.resource_prefix}-budget"
  resource_group_id = var.resource_group_id

  amount     = var.monthly_budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
  }

  notification {
    enabled   = true
    threshold = var.budget_alert_threshold
    operator  = "GreaterThan"

    contact_emails = [
      var.notification_email,
    ]
  }

  notification {
    enabled        = true
    threshold      = 64
    operator       = "GreaterThan"
    threshold_type = "Forecasted"

    contact_emails = [
      var.notification_email,
    ]
  }
}

# Storage Container for cost exports
resource "azurerm_storage_container" "cost_exports" {
  count                 = var.enable_cost_alerts ? 1 : 0
  name                  = "cost-exports"
  storage_account_name  = var.storage_account_name
  container_access_type = "private"
}

# Scheduled Query for underutilization detection
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "underutilization" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.resource_prefix}-underutilization-alert"
  location            = var.location
  resource_group_name = var.resource_group_name

  evaluation_frequency = "PT1H"
  window_duration      = "PT6H"
  scopes               = [var.log_analytics_workspace_id]
  severity             = 3
  criteria {
    query                   = <<-QUERY
      Perf
      | where ObjectName == "Processor" and CounterName == "% Processor Time"
      | summarize AvgCPU = avg(CounterValue) by Computer
      | where AvgCPU < 20
    QUERY
    time_aggregation_method = "Average"
    threshold               = 1
    operator                = "GreaterThanOrEqual"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  auto_mitigation_enabled          = false
  workspace_alerts_storage_enabled = false
  description                      = "Alert when resources are underutilized"
  display_name                     = "${var.resource_prefix}-underutilization-alert"
  enabled                          = true
  skip_query_validation            = false

  action {
    action_groups = [var.monitor_action_group_id]
  }

  tags = var.tags
}

# Data Factory for cost analytics
resource "azurerm_data_factory" "cost_analytics" {
  count               = var.enable_data_factory ? 1 : 0
  name                = "${var.resource_prefix}-df-cost"
  location            = var.location
  resource_group_name = var.resource_group_name

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Grant Data Factory access to Storage
resource "azurerm_role_assignment" "df_storage_access" {
  count                = var.enable_data_factory ? 1 : 0
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.storage_account_name}"
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.cost_analytics[0].identity[0].principal_id
}

# Logic App for cost optimization workflows
resource "azurerm_logic_app_workflow" "cost_optimization" {
  count               = var.enable_logic_app ? 1 : 0
  name                = "${var.resource_prefix}-logic-cost"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Automation Account for cost optimization
resource "azurerm_automation_account" "cost_optimization" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${var.resource_prefix}-auto-cost"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Automation Runbook for scaling
resource "azurerm_automation_runbook" "scale_resources" {
  count                   = var.enable_cost_alerts && var.aks_cluster_name != "" ? 1 : 0
  name                    = "Scale-MLOps-Resources"
  location                = var.location
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.cost_optimization[0].name
  log_verbose             = true
  log_progress            = true
  runbook_type            = "PowerShell"

  content = <<-CONTENT
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$AKSClusterName,
    
    [Parameter(Mandatory=$false)]
    [int]$NodeCount = 1
)

$connectionName = "AzureRunAsConnection"
try {
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
    Connect-AzAccount -ServicePrincipal -Tenant $servicePrincipalConnection.TenantId -ApplicationId $servicePrincipalConnection.ApplicationId -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
}
catch {
    Write-Error "Connection $connectionName not found."
    throw
}

$currentHour = (Get-Date).Hour
if ($currentHour -ge 9 -and $currentHour -lt 18) {
    Write-Output "Business hours detected. Scaling up to $NodeCount nodes."
    az aks scale --resource-group $ResourceGroupName --name $AKSClusterName --node-count $NodeCount
} else {
    Write-Output "Outside business hours. Scaling down to 0 nodes."
    az aks scale --resource-group $ResourceGroupName --name $AKSClusterName --node-count 0
}
CONTENT

  tags = var.tags
}

# Automation Schedule for hourly execution
resource "azurerm_automation_schedule" "hourly_scaling" {
  count                   = var.enable_cost_alerts && var.aks_cluster_name != "" ? 1 : 0
  name                    = "Hourly-Scaling-Schedule"
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.cost_optimization[0].name
  frequency               = "Hour"
  interval                = 1
  description             = "Runs every hour to check and adjust scaling"
}

# Link Schedule to Runbook
resource "azurerm_automation_job_schedule" "scale_resources" {
  count                   = var.enable_cost_alerts && var.aks_cluster_name != "" ? 1 : 0
  resource_group_name     = var.resource_group_name
  automation_account_name = azurerm_automation_account.cost_optimization[0].name
  schedule_name           = azurerm_automation_schedule.hourly_scaling[0].name
  runbook_name            = azurerm_automation_runbook.scale_resources[0].name

  parameters = {
    resourcegroupname = var.resource_group_name
    aksclustername    = var.aks_cluster_name
    nodecount         = 1
  }
}

# Data source
data "azurerm_client_config" "current" {}
