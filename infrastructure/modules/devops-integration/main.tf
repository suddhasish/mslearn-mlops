# Data Factory for DevOps analytics
resource "azurerm_data_factory" "devops_analytics" {
  count               = var.enable_devops_integration && var.enable_data_factory ? 1 : 0
  name                = "${var.resource_prefix}-df-devops"
  location            = var.location
  resource_group_name = var.resource_group_name

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Power BI Embedded for analytics dashboards
resource "azurerm_powerbi_embedded" "mlops_analytics" {
  count               = var.enable_devops_integration && var.enable_powerbi ? 1 : 0
  name                = "${var.resource_prefix}pbimlops"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "A1"
  administrators      = [var.notification_email]

  tags = var.tags
}

# SQL Server for analytics storage
resource "azurerm_mssql_server" "mlops_analytics" {
  count                        = var.enable_devops_integration && var.enable_mssql ? 1 : 0
  name                         = "${var.resource_prefix}-sql-analytics"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = random_password.sql_admin[0].result

  azuread_administrator {
    login_username = var.notification_email
    object_id      = data.azurerm_client_config.current.object_id
  }

  tags = var.tags
}

# Random password for SQL admin
resource "random_password" "sql_admin" {
  count   = var.enable_devops_integration && var.enable_mssql ? 1 : 0
  length  = 24
  special = true
}

# Store SQL admin password in Key Vault
resource "azurerm_key_vault_secret" "sql_admin_password" {
  count        = var.enable_devops_integration && var.enable_mssql ? 1 : 0
  name         = "sql-admin-password"
  value        = random_password.sql_admin[0].result
  key_vault_id = var.key_vault_id
}

# SQL Database for analytics
resource "azurerm_mssql_database" "mlops_analytics" {
  count      = var.enable_devops_integration && var.enable_mssql ? 1 : 0
  name       = "${var.resource_prefix}-sqldb-analytics"
  server_id  = azurerm_mssql_server.mlops_analytics[0].id
  sku_name   = "GP_S_Gen5_1"
  min_capacity = 0.5
  auto_pause_delay_in_minutes = 60

  tags = var.tags
}

# Event Grid Topic for model deployment events
resource "azurerm_eventgrid_topic" "ml_events" {
  count               = var.enable_devops_integration ? 1 : 0
  name                = "${var.resource_prefix}-ml-events"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Event Grid Subscription for model deployment notifications
resource "azurerm_eventgrid_event_subscription" "ml_deployment" {
  count = var.enable_devops_integration ? 1 : 0
  name  = "${var.resource_prefix}-ml-deployment-sub"
  scope = var.ml_workspace_id

  webhook_endpoint {
    url = var.slack_webhook_url != "" ? var.slack_webhook_url : "https://example.com/webhook"
  }

  included_event_types = [
    "Microsoft.MachineLearningServices.ModelDeployed",
    "Microsoft.MachineLearningServices.ModelRegistered"
  ]

  retry_policy {
    max_delivery_attempts = 30
    event_time_to_live    = 1440
  }
}

# Service Plan for Function App
resource "azurerm_service_plan" "mlops_functions" {
  count               = var.enable_devops_integration ? 1 : 0
  name                = "${var.resource_prefix}-func-plan"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "Y1"

  tags = var.tags
}

# Function App for event processing
resource "azurerm_linux_function_app" "ml_events_processor" {
  count               = var.enable_devops_integration ? 1 : 0
  name                = "${var.resource_prefix}-func-events"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.mlops_functions[0].id

  storage_account_name       = var.storage_account_name
  storage_account_access_key = var.storage_account_primary_access_key

  site_config {
    application_stack {
      python_version = "3.9"
    }
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "python"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = var.application_insights_instrumentation_key
    "EVENTHUB_CONNECTION_STRING"     = var.enable_devops_integration ? azurerm_eventhub_namespace.ml_performance[0].default_primary_connection_string : ""
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Stream Analytics Job for real-time analytics
resource "azurerm_stream_analytics_job" "ml_analytics" {
  count                                = var.enable_devops_integration ? 1 : 0
  name                                 = "${var.resource_prefix}-stream-analytics"
  location                             = var.location
  resource_group_name                  = var.resource_group_name
  streaming_units                      = 3
  transformation_query                 = <<QUERY
SELECT
    System.Timestamp() AS WindowEnd,
    model_name,
    AVG(prediction_latency) AS avg_latency,
    COUNT(*) AS prediction_count
INTO
    [output]
FROM
    [input]
TIMESTAMP BY event_time
GROUP BY
    model_name,
    TumblingWindow(minute, 5)
QUERY
  compatibility_level                  = "1.2"
  data_locale                          = "en-US"
  output_error_policy                  = "Stop"
  events_outoforder_max_delay_in_seconds = 5
  events_outoforder_policy             = "Adjust"
  events_late_arrival_max_delay_in_seconds = 5

  tags = var.tags
}

# Event Hub Namespace
resource "azurerm_eventhub_namespace" "ml_performance" {
  count               = var.enable_devops_integration ? 1 : 0
  name                = "${var.resource_prefix}-eventhub-ns"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  capacity            = 1

  tags = var.tags
}

# Event Hub for model performance metrics
resource "azurerm_eventhub" "model_performance" {
  count               = var.enable_devops_integration ? 1 : 0
  name                = "model-performance"
  namespace_name      = azurerm_eventhub_namespace.ml_performance[0].name
  resource_group_name = var.resource_group_name
  partition_count     = 2
  message_retention   = 1
}

# Cognitive Services for text analytics
resource "azurerm_cognitive_account" "text_analytics" {
  count               = var.enable_devops_integration && var.enable_cognitive_services ? 1 : 0
  name                = "${var.resource_prefix}-textanalytics"
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "TextAnalytics"
  sku_name            = "S0"

  tags = var.tags
}

# Synapse Workspace for advanced analytics
resource "azurerm_synapse_workspace" "mlops" {
  count                                = var.enable_devops_integration && var.enable_synapse ? 1 : 0
  name                                 = "${var.resource_prefix}-synapse"
  location                             = var.location
  resource_group_name                  = var.resource_group_name
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.synapse[0].id
  sql_administrator_login              = "sqladmin"
  sql_administrator_login_password     = random_password.synapse_admin[0].result

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Random password for Synapse admin
resource "random_password" "synapse_admin" {
  count   = var.enable_devops_integration && var.enable_synapse ? 1 : 0
  length  = 24
  special = true
}

# Data Lake Gen2 Filesystem for Synapse
resource "azurerm_storage_data_lake_gen2_filesystem" "synapse" {
  count              = var.enable_devops_integration && var.enable_synapse ? 1 : 0
  name               = "synapse"
  storage_account_id = var.storage_account_id
}

# Communication Service for notifications
resource "azurerm_communication_service" "mlops" {
  count               = var.enable_devops_integration && var.enable_communication_service ? 1 : 0
  name                = "${var.resource_prefix}-comm-service"
  resource_group_name = var.resource_group_name
  data_location       = "United States"

  tags = var.tags
}

# Data sources
data "azurerm_client_config" "current" {}

# Role assignment for Function App to access ML Workspace
resource "azurerm_role_assignment" "function_ml_access" {
  count                = var.enable_devops_integration ? 1 : 0
  scope                = var.ml_workspace_id
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_function_app.ml_events_processor[0].identity[0].principal_id
}

# Role assignment for Function App to send Event Grid events
resource "azurerm_role_assignment" "function_eventgrid_access" {
  count                = var.enable_devops_integration ? 1 : 0
  scope                = azurerm_eventgrid_topic.ml_events[0].id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = azurerm_linux_function_app.ml_events_processor[0].identity[0].principal_id
}
