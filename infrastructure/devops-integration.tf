# Azure DevOps Integration and Collaboration Tools
# Enables enterprise collaboration with boards, pipelines, and Power BI integration

# Data Factory for DevOps analytics
resource "azurerm_data_factory" "devops_analytics" {
  count               = var.enable_devops_integration ? 1 : 0
  name                = "${local.resource_prefix}-df-devops"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Power BI Embedded for business dashboards
resource "azurerm_powerbi_embedded" "mlops_analytics" {
  count = (var.enable_devops_integration && var.enable_powerbi) ? 1 : 0
  # Name must be 4-64 chars and contain only lowercase letters or numbers
  name                = "${local.resource_prefix_pbi}pbi"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  sku_name            = "A1"
  administrators      = [data.azurerm_client_config.current.object_id]

  tags = local.common_tags
}

# SQL Database for DevOps metrics and reporting
resource "azurerm_mssql_server" "devops_analytics" {
  count                        = (var.enable_devops_integration && var.enable_mssql) ? 1 : 0
  name                         = "${local.resource_prefix}-sql-${local.suffix}"
  resource_group_name          = azurerm_resource_group.mlops.name
  location                     = azurerm_resource_group.mlops.location
  version                      = "12.0"
  administrator_login          = "mlopssqladmin"
  administrator_login_password = random_password.sql_admin[0].result
  minimum_tls_version          = "1.2"

  azuread_administrator {
    login_username = "Azure ML Admin"
    object_id      = data.azurerm_client_config.current.object_id
  }

  tags = local.common_tags
}

resource "azurerm_mssql_database" "devops_metrics" {
  count     = (var.enable_devops_integration && var.enable_mssql) ? 1 : 0
  name      = "DevOpsMetrics"
  server_id = azurerm_mssql_server.devops_analytics[0].id
  collation = "SQL_Latin1_General_CP1_CI_AS"
  sku_name  = "GP_S_Gen5_1"

  auto_pause_delay_in_minutes = 60
  min_capacity                = 0.5

  tags = local.common_tags
}

resource "random_password" "sql_admin" {
  count   = (var.enable_devops_integration && var.enable_mssql) ? 1 : 0
  length  = 16
  special = true
}

# Store SQL admin password in Key Vault
resource "azurerm_key_vault_secret" "sql_admin_password" {
  count        = (var.enable_devops_integration && var.enable_mssql) ? 1 : 0
  name         = "sql-admin-password"
  value        = random_password.sql_admin[0].result
  key_vault_id = azurerm_key_vault.mlops.id

  # Ensure Key Vault exists; do not require CI/CD access policy to allow MVP without AAD app
  depends_on = [azurerm_key_vault.mlops]

  tags = local.common_tags
}

# Event Grid for real-time notifications
resource "azurerm_eventgrid_topic" "mlops_events" {
  count               = var.enable_devops_integration ? 1 : 0
  name                = "${local.resource_prefix}-events"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name

  tags = local.common_tags
}

# Event Grid subscription for model deployment events
resource "azurerm_eventgrid_event_subscription" "model_deployment" {
  count = var.enable_devops_integration ? 1 : 0
  name  = "${local.resource_prefix}-model-deployment-events"
  scope = azurerm_machine_learning_workspace.mlops.id

  webhook_endpoint {
    url = "https://${azurerm_linux_function_app.mlops_functions[0].default_hostname}/api/ModelDeploymentWebhook"
  }

  included_event_types = [
    "Microsoft.MachineLearningServices.ModelRegistered",
    "Microsoft.MachineLearningServices.ModelDeployed"
  ]

  retry_policy {
    max_delivery_attempts = 30
    event_time_to_live    = 1440
  }
}

# Function App for event processing and notifications
resource "azurerm_service_plan" "functions" {
  count               = var.enable_devops_integration ? 1 : 0
  name                = "${local.resource_prefix}-func-plan"
  resource_group_name = azurerm_resource_group.mlops.name
  location            = azurerm_resource_group.mlops.location
  os_type             = "Linux"
  sku_name            = "Y1"

  tags = local.common_tags
}

resource "azurerm_linux_function_app" "mlops_functions" {
  count                      = var.enable_devops_integration ? 1 : 0
  name                       = "${local.resource_prefix}-func-${local.suffix}"
  location                   = azurerm_resource_group.mlops.location
  resource_group_name        = azurerm_resource_group.mlops.name
  service_plan_id            = azurerm_service_plan.functions[0].id
  storage_account_name       = azurerm_storage_account.mlops.name
  storage_account_access_key = azurerm_storage_account.mlops.primary_access_key

  site_config {
    always_on = false

    application_stack {
      python_version = "3.9"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.mlops.instrumentation_key
    "SLACK_WEBHOOK_URL"              = var.slack_webhook_url
    "NOTIFICATION_EMAIL"             = var.notification_email
    "ML_WORKSPACE_NAME"              = azurerm_machine_learning_workspace.mlops.name
    "RESOURCE_GROUP_NAME"            = azurerm_resource_group.mlops.name
    "SUBSCRIPTION_ID"                = data.azurerm_client_config.current.subscription_id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Stream Analytics for real-time model performance monitoring
resource "azurerm_stream_analytics_job" "model_performance" {
  count                                    = var.enable_devops_integration ? 1 : 0
  name                                     = "${local.resource_prefix}-stream-analytics"
  resource_group_name                      = azurerm_resource_group.mlops.name
  location                                 = azurerm_resource_group.mlops.location
  compatibility_level                      = "1.2"
  data_locale                              = "en-GB"
  events_late_arrival_max_delay_in_seconds = 60
  events_out_of_order_max_delay_in_seconds = 50
  events_out_of_order_policy               = "Adjust"
  output_error_policy                      = "Drop"
  streaming_units                          = 3

  transformation_query = <<QUERY
    SELECT 
        System.Timestamp() AS WindowEnd,
        AVG(responseTime) AS AvgResponseTime,
        COUNT(*) AS RequestCount,
        COUNT(CASE WHEN responseTime > 1000 THEN 1 END) AS SlowRequests
    INTO [PowerBIOutput]
    FROM [EventHubInput] TIMESTAMP BY EventProcessedUtcTime
    GROUP BY TumblingWindow(minute, 5)
  QUERY

  tags = local.common_tags
}

# Event Hub for streaming model performance data
resource "azurerm_eventhub_namespace" "mlops" {
  count               = var.enable_devops_integration ? 1 : 0
  name                = "${local.resource_prefix}-eventhub-${local.suffix}"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  sku                 = "Standard"
  capacity            = 1

  tags = local.common_tags
}

resource "azurerm_eventhub" "model_performance" {
  count               = var.enable_devops_integration ? 1 : 0
  name                = "model-performance"
  namespace_name      = azurerm_eventhub_namespace.mlops[0].name
  resource_group_name = azurerm_resource_group.mlops.name
  partition_count     = 2
  message_retention   = 1
}

# Cognitive Services for advanced analytics
resource "azurerm_cognitive_account" "text_analytics" {
  count               = var.enable_cognitive_services ? 1 : 0
  name                = "${local.resource_prefix}-cognitive"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  kind                = "TextAnalytics"
  sku_name            = "S0"

  # network_acls {
  #   default_action = "Allow"
  # }

  tags = local.common_tags
}

# Azure Synapse for big data analytics
resource "azurerm_synapse_workspace" "mlops" {
  count                                = var.enable_synapse ? 1 : 0
  name                                 = "${local.resource_prefix}-synapse"
  resource_group_name                  = azurerm_resource_group.mlops.name
  location                             = azurerm_resource_group.mlops.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.synapse[0].id
  sql_administrator_login              = "synapseadmin"
  sql_administrator_login_password     = random_password.synapse_admin[0].result

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "synapse" {
  count              = var.enable_synapse ? 1 : 0
  name               = "synapse"
  storage_account_id = azurerm_storage_account.mlops.id
}

resource "random_password" "synapse_admin" {
  count   = var.enable_synapse ? 1 : 0
  length  = 16
  special = true
}

# Communication Services for notifications
resource "azurerm_communication_service" "mlops" {
  count               = var.enable_communication_service ? 1 : 0
  name                = "${local.resource_prefix}-communication"
  resource_group_name = azurerm_resource_group.mlops.name
  data_location       = "United States"

  tags = local.common_tags
}

# Role assignments for DevOps integration
resource "azurerm_role_assignment" "function_ml_workspace" {
  count                = var.enable_devops_integration ? 1 : 0
  scope                = azurerm_machine_learning_workspace.mlops.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_function_app.mlops_functions[0].identity[0].principal_id
}

resource "azurerm_role_assignment" "function_eventgrid" {
  count                = var.enable_devops_integration ? 1 : 0
  scope                = azurerm_eventgrid_topic.mlops_events[0].id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = azurerm_linux_function_app.mlops_functions[0].identity[0].principal_id
}