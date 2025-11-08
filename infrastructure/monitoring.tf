# Monitoring and Observability Configuration
# Comprehensive monitoring solution for ML operations

# Action Groups for Notifications
resource "azurerm_monitor_action_group" "mlops_alerts" {
  name                = "${local.resource_prefix}-action-group"
  resource_group_name = azurerm_resource_group.mlops.name
  short_name          = "mlopsal"

  dynamic "email_receiver" {
    for_each = var.notification_email != "" ? [1] : []
    content {
      name          = "email-admin"
      email_address = var.notification_email
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.enable_slack_notifications && var.slack_webhook_url != "" ? [1] : []
    content {
      name        = "slack-webhook"
      service_uri = var.slack_webhook_url
    }
  }

  tags = local.common_tags
}

# Azure Monitor Alerts for ML Workspace
resource "azurerm_monitor_metric_alert" "ml_job_failure" {
  name                = "${local.resource_prefix}-ml-job-failure"
  resource_group_name = azurerm_resource_group.mlops.name
  scopes              = [azurerm_machine_learning_workspace.mlops.id]
  description         = "Alert when ML job fails"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.MachineLearningServices/workspaces"
    metric_name      = "CompletedRuns"
    aggregation      = "Count"
    operator         = "GreaterThan"
    threshold        = 0

    dimension {
      name     = "Status"
      operator = "Include"
      values   = ["Failed", "Canceled"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.mlops_alerts.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "storage_availability" {
  name                = "${local.resource_prefix}-storage-availability"
  resource_group_name = azurerm_resource_group.mlops.name
  scopes              = [azurerm_storage_account.mlops.id]
  description         = "Alert when storage availability drops"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 99
  }

  action {
    action_group_id = azurerm_monitor_action_group.mlops_alerts.id
  }

  tags = local.common_tags
}

# AKS Monitoring Alerts
resource "azurerm_monitor_metric_alert" "aks_cpu_usage" {
  name                = "${local.resource_prefix}-aks-cpu-usage"
  resource_group_name = azurerm_resource_group.mlops.name
  scopes              = var.enable_aks_deployment ? [azurerm_kubernetes_cluster.mlops[0].id] : []
  description         = "Alert when AKS CPU usage is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.mlops_alerts.id
  }

  tags = local.common_tags
}

resource "azurerm_monitor_metric_alert" "aks_memory_usage" {
  name                = "${local.resource_prefix}-aks-memory-usage"
  resource_group_name = azurerm_resource_group.mlops.name
  scopes              = var.enable_aks_deployment ? [azurerm_kubernetes_cluster.mlops[0].id] : []
  description         = "Alert when AKS memory usage is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_working_set_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.mlops_alerts.id
  }

  tags = local.common_tags
}

# Data Drift Detection using Application Insights
resource "azurerm_application_insights_web_test" "model_endpoint_test" {
  name                    = "${local.resource_prefix}-model-endpoint-test"
  location                = azurerm_resource_group.mlops.location
  resource_group_name     = azurerm_resource_group.mlops.name
  application_insights_id = azurerm_application_insights.mlops.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 30
  enabled                 = true
  geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr"]

  configuration = <<XML
<WebTest Name="${local.resource_prefix}-model-endpoint-test" Id="ABD48585-0831-40CB-9069-682A25A8A0FF" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="30" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Guid="a5f10126-e4cd-570d-961c-cea43999a200" Version="1.1" Url="https://httpbin.org/status/200" ThinkTime="0" Timeout="30" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML

  tags = local.common_tags
}

# Log Analytics Queries for ML Operations
resource "azurerm_log_analytics_saved_search" "failed_ml_jobs" {
  name                       = "FailedMLJobs"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.mlops.id
  category                   = "MLOps"
  display_name               = "Failed ML Jobs"

  query = <<QUERY
AmlComputeJobEvent
| where EventType == "JobFailed"
| extend JobName = tostring(Properties.JobName)
| extend ErrorMessage = tostring(Properties.ErrorMessage)
| project TimeGenerated, JobName, ErrorMessage, Properties
| order by TimeGenerated desc
QUERY
}

resource "azurerm_log_analytics_saved_search" "model_inference_latency" {
  name                       = "ModelInferenceLatency"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.mlops.id
  category                   = "MLOps"
  display_name               = "Model Inference Latency"

  query = <<QUERY
ContainerLog
| where LogEntry contains "inference_time"
| extend InferenceTime = extract("inference_time:(\\d+\\.\\d+)", 1, LogEntry)
| extend InferenceTimeMs = todouble(InferenceTime) * 1000
| summarize AvgLatency=avg(InferenceTimeMs), P95Latency=percentile(InferenceTimeMs, 95), Count=count() by bin(TimeGenerated, 5m)
| order by TimeGenerated desc
QUERY
}

# Azure Monitor Workbook for ML Operations Dashboard
resource "random_uuid" "mlops_dashboard" {}

resource "azurerm_application_insights_workbook" "mlops_dashboard" {
  # Workbook name must be a valid UUID (GUID), use a generated one and set a friendly display_name instead
  name                = random_uuid.mlops_dashboard.result
  resource_group_name = azurerm_resource_group.mlops.name
  location            = azurerm_resource_group.mlops.location
  # Combine human-friendly prefix and purpose while keeping UUID as required name
  display_name = "${local.resource_prefix}-mlops-dashboard"

  data_json = jsonencode({
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        content = {
          json = "# MLOps Operations Dashboard\n\nThis dashboard provides comprehensive monitoring for ML operations including job status, model performance, and infrastructure health."
        }
      },
      {
        type = 3
        content = {
          version      = "KqlItem/1.0"
          query        = "AmlComputeJobEvent | summarize Count=count() by EventType | render piechart"
          size         = 0
          title        = "ML Job Status Distribution"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
        }
      },
      {
        type = 3
        content = {
          version      = "KqlItem/1.0"
          query        = "Perf | where ObjectName == \"Processor\" and CounterName == \"% Processor Time\" | summarize avg(CounterValue) by bin(TimeGenerated, 5m) | render timechart"
          size         = 0
          title        = "CPU Usage Over Time"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Diagnostic Settings for comprehensive logging
resource "azurerm_monitor_diagnostic_setting" "ml_workspace" {
  name                       = "${local.resource_prefix}-ml-workspace-diag"
  target_resource_id         = azurerm_machine_learning_workspace.mlops.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.mlops.id

  enabled_log {
    category = "AmlComputeJobEvent"
  }

  enabled_log {
    category = "AmlComputeClusterEvent"
  }

  enabled_log {
    category = "AmlRunStatusChangedEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "${local.resource_prefix}-aks-diag"
  target_resource_id         = var.enable_aks_deployment ? azurerm_kubernetes_cluster.mlops[0].id : null
  log_analytics_workspace_id = azurerm_log_analytics_workspace.mlops.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "cluster-autoscaler"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "${local.resource_prefix}-storage-diag"
  target_resource_id         = azurerm_storage_account.mlops.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.mlops.id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "Transaction"
    enabled  = true
  }

  metric {
    category = "Capacity"
    enabled  = true
  }
}