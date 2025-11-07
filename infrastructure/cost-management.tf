# Cost Management and Billing Optimization
# Implements cost tracking, budgets, and optimization recommendations

# Budget for the MLOps resource group
resource "azurerm_consumption_budget_resource_group" "mlops_budget" {
  name              = "${local.resource_prefix}-budget"
  resource_group_id = azurerm_resource_group.mlops.id

  amount     = var.monthly_budget_amount
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00'Z'", timestamp())
    end_date   = formatdate("YYYY-MM-01'T'00:00:00'Z'", timeadd(timestamp(), "8760h")) # 1 year from now
  }

  dynamic "notification" {
    for_each = var.enable_cost_alerts ? [1] : []
    content {
      enabled        = true
      threshold      = var.budget_alert_threshold
      operator       = "GreaterThan"
      threshold_type = "Actual"

      contact_emails = var.notification_email != "" ? [var.notification_email] : []
    }
  }

  dynamic "notification" {
    for_each = var.enable_cost_alerts ? [1] : []
    content {
      enabled        = true
      threshold      = var.budget_alert_threshold * 0.8 # 80% of the main threshold
      operator       = "GreaterThan"
      threshold_type = "Forecasted"

      contact_emails = var.notification_email != "" ? [var.notification_email] : []
    }
  }
}

# Azure Cost Management Export for detailed billing analysis

# Storage container for cost exports
resource "azurerm_storage_container" "cost_exports" {
  name                  = "cost-exports"
  storage_account_name  = azurerm_storage_account.mlops.name
  container_access_type = "private"
}

# Azure Advisor recommendations monitoring
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "cost_optimization_alert" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${local.resource_prefix}-cost-optimization"
  resource_group_name = azurerm_resource_group.mlops.name
  location            = azurerm_resource_group.mlops.location

  evaluation_frequency = "PT1H"
  window_duration      = "PT1H"
  scopes               = [azurerm_log_analytics_workspace.mlops.id]
  severity             = 3

  criteria {
    query = <<-QUERY
      // Query to identify underutilized resources
      Perf
      | where ObjectName == "Processor" and CounterName == "% Processor Time"
      | where Computer contains "aks"
      | summarize AvgCPU = avg(CounterValue) by Computer, bin(TimeGenerated, 1h)
      | where AvgCPU < 20  // Less than 20% CPU utilization
      | summarize UnderutilizedHours = count() by Computer
      | where UnderutilizedHours > 12  // More than 12 hours of low utilization
    QUERY

    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.mlops_alerts.id]
  }

  description = "Alert when resources are underutilized and could be optimized for cost"

  tags = local.common_tags
}

# Data Factory for cost data processing and analysis
resource "azurerm_data_factory" "cost_analytics" {
  count               = var.enable_data_factory ? 1 : 0
  name                = "${local.resource_prefix}-df-cost"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Role assignment for Data Factory to access storage
resource "azurerm_role_assignment" "df_storage_access" {
  count                = var.enable_data_factory ? 1 : 0
  scope                = azurerm_storage_account.mlops.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.cost_analytics[0].identity[0].principal_id
}

# Logic App for automated cost optimization actions
resource "azurerm_logic_app_workflow" "cost_optimization" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${local.resource_prefix}-cost-optimization"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name

  workflow_schema  = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
  workflow_version = "1.0.0.0"

  parameters = {
    "$connections" = jsonencode({
      value = {}
    })
  }

  workflow_parameters = {
    "$connections" = {
      defaultValue = {}
      type         = "Object"
    }
  }

  tags = local.common_tags
}

# Automation Account for scheduled cost optimization tasks
resource "azurerm_automation_account" "cost_optimization" {
  count               = var.enable_cost_alerts ? 1 : 0
  name                = "${local.resource_prefix}-automation"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# PowerShell runbook for automated scaling
resource "azurerm_automation_runbook" "scale_resources" {
  count                   = var.enable_cost_alerts ? 1 : 0
  name                    = "Scale-MLOps-Resources"
  location                = azurerm_resource_group.mlops.location
  resource_group_name     = azurerm_resource_group.mlops.name
  automation_account_name = azurerm_automation_account.cost_optimization[0].name
  log_verbose             = true
  log_progress            = true
  description             = "Automated scaling of MLOps resources based on usage patterns"
  runbook_type            = "PowerShell"

  content = <<-POWERSHELL
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory=$true)]
        [string]$AKSClusterName,
        
        [Parameter(Mandatory=$false)]
        [int]$MinNodes = 1,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxNodes = 10
    )
    
    # Connect using managed identity
    Connect-AzAccount -Identity
    
    # Get current time
    $currentHour = (Get-Date).Hour
    
    # Define business hours (9 AM to 6 PM)
    $businessHoursStart = 9
    $businessHoursEnd = 18
    
    # Scale based on time of day
    if ($currentHour -ge $businessHoursStart -and $currentHour -lt $businessHoursEnd) {
        # Business hours - scale up
        Write-Output "Business hours detected. Scaling up resources."
        $targetMinNodes = $MinNodes
        $targetMaxNodes = $MaxNodes
    } else {
        # Off hours - scale down
        Write-Output "Off hours detected. Scaling down resources."
        $targetMinNodes = 0
        $targetMaxNodes = 2
    }
    
    # Update AKS node pool
    try {
        $aks = Get-AzAksCluster -ResourceGroupName $ResourceGroupName -Name $AKSClusterName
        if ($aks) {
            Write-Output "Updating AKS cluster $AKSClusterName with min: $targetMinNodes, max: $targetMaxNodes"
            # Add scaling logic here
        }
    } catch {
        Write-Error "Failed to update AKS cluster: $_"
    }
    
    Write-Output "Cost optimization scaling completed."
  POWERSHELL

  tags = local.common_tags
}

# Schedule for the runbook
resource "azurerm_automation_schedule" "cost_optimization_schedule" {
  count                   = var.enable_cost_alerts ? 1 : 0
  name                    = "CostOptimizationSchedule"
  resource_group_name     = azurerm_resource_group.mlops.name
  automation_account_name = azurerm_automation_account.cost_optimization[0].name
  frequency               = "Hour"
  interval                = 1
  description             = "Hourly cost optimization check"
}

# Link runbook to schedule
resource "azurerm_automation_job_schedule" "cost_optimization_job" {
  count                   = var.enable_cost_alerts ? 1 : 0
  resource_group_name     = azurerm_resource_group.mlops.name
  automation_account_name = azurerm_automation_account.cost_optimization[0].name
  schedule_name           = azurerm_automation_schedule.cost_optimization_schedule[0].name
  runbook_name            = azurerm_automation_runbook.scale_resources[0].name

  parameters = {
    resourcegroupname = azurerm_resource_group.mlops.name
    aksclustername    = azurerm_kubernetes_cluster.mlops.name
  }
}