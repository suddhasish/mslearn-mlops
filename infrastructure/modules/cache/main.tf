# Redis Cache for MLOps caching
resource "azurerm_redis_cache" "mlops" {
  count               = var.enable_redis_cache ? 1 : 0
  name                = "${var.resource_prefix}-redis"
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.redis_cache_capacity
  family              = var.redis_cache_family
  sku_name            = var.redis_cache_sku_name

  minimum_tls_version = "1.2"

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  tags = var.tags
}

# Grant Key Vault Secrets Officer role to current principal for secret writing
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "terraform_kv_secrets_officer" {
  count                = var.enable_redis_cache ? 1 : 0
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Store Redis connection details in Key Vault
resource "azurerm_key_vault_secret" "redis_connection_string" {
  count        = var.enable_redis_cache ? 1 : 0
  name         = "redis-connection-string"
  value        = azurerm_redis_cache.mlops[0].primary_connection_string
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_role_assignment.terraform_kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "redis_host" {
  count        = var.enable_redis_cache ? 1 : 0
  name         = "redis-host"
  value        = azurerm_redis_cache.mlops[0].hostname
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_role_assignment.terraform_kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "redis_port" {
  count        = var.enable_redis_cache ? 1 : 0
  name         = "redis-port"
  value        = azurerm_redis_cache.mlops[0].ssl_port
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_role_assignment.terraform_kv_secrets_officer]
}

resource "azurerm_key_vault_secret" "redis_password" {
  count        = var.enable_redis_cache ? 1 : 0
  name         = "redis-password"
  value        = azurerm_redis_cache.mlops[0].primary_access_key
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_role_assignment.terraform_kv_secrets_officer]
}

# Diagnostic settings for Redis Cache
resource "azurerm_monitor_diagnostic_setting" "redis" {
  count                      = var.enable_redis_cache ? 1 : 0
  name                       = "${var.resource_prefix}-redis-diagnostics"
  target_resource_id         = azurerm_redis_cache.mlops[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ConnectedClientList"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Alert for high memory usage
resource "azurerm_monitor_metric_alert" "redis_memory" {
  count               = var.enable_redis_cache ? 1 : 0
  name                = "${var.resource_prefix}-redis-memory-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_redis_cache.mlops[0].id]
  description         = "Alert when Redis memory usage is high"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Cache/redis"
    metric_name      = "usedmemorypercentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = var.monitor_action_group_id
  }

  tags = var.tags
}

# Alert for cache miss rate
resource "azurerm_monitor_metric_alert" "redis_cache_miss" {
  count               = var.enable_redis_cache ? 1 : 0
  name                = "${var.resource_prefix}-redis-cachemiss-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_redis_cache.mlops[0].id]
  description         = "Alert when Redis cache miss rate is high"
  severity            = 3
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Cache/redis"
    metric_name      = "cachemissrate"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 20
  }

  action {
    action_group_id = var.monitor_action_group_id
  }

  tags = var.tags
}
