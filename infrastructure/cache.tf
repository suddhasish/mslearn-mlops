# Azure Cache for Redis - Inference Response Caching
# Provides low-latency caching for frequently-requested predictions
# and session management for stateful inference scenarios

resource "azurerm_redis_cache" "mlops" {
  count               = var.enable_redis_cache ? 1 : 0
  name                = "${local.resource_prefix}-redis"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  capacity            = 1
  family              = "C"  # Basic/Standard
  sku_name            = "Standard"  # Standard for production, Basic for dev
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
    enable_authentication = true
    maxmemory_reserved    = 2
    maxmemory_delta       = 2
    maxmemory_policy      = "allkeys-lru"  # Evict least recently used keys when memory full
  }

  # Optionally enable Redis persistence for data durability
  # redis_configuration {
  #   rdb_backup_enabled            = true
  #   rdb_backup_frequency          = 60
  #   rdb_backup_max_snapshot_count = 1
  # }

  # Network security
  public_network_access_enabled = !local.enable_private_endpoints

  tags = local.common_tags
}

# Role assignment for Terraform to write Redis secrets to Key Vault (RBAC-enabled vault)
resource "azurerm_role_assignment" "terraform_kv_secrets_officer" {
  count                = var.enable_redis_cache ? 1 : 0
  scope                = azurerm_key_vault.mlops.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id

  # Prevent circular dependency by skipping API call
  skip_service_principal_aad_check = true
}

# Store Redis connection string in Key Vault
resource "azurerm_key_vault_secret" "redis_connection_string" {
  count        = var.enable_redis_cache ? 1 : 0
  name         = "redis-connection-string"
  value        = azurerm_redis_cache.mlops[0].primary_connection_string
  key_vault_id = azurerm_key_vault.mlops.id

  depends_on = [
    azurerm_redis_cache.mlops,
    azurerm_role_assignment.terraform_kv_secrets_officer
  ]
}

resource "azurerm_key_vault_secret" "redis_host" {
  count        = var.enable_redis_cache ? 1 : 0
  name         = "redis-host"
  value        = azurerm_redis_cache.mlops[0].hostname
  key_vault_id = azurerm_key_vault.mlops.id

  depends_on = [
    azurerm_redis_cache.mlops,
    azurerm_role_assignment.terraform_kv_secrets_officer
  ]
}

resource "azurerm_key_vault_secret" "redis_port" {
  count        = var.enable_redis_cache ? 1 : 0
  name         = "redis-port"
  value        = tostring(azurerm_redis_cache.mlops[0].ssl_port)
  key_vault_id = azurerm_key_vault.mlops.id

  depends_on = [
    azurerm_redis_cache.mlops,
    azurerm_role_assignment.terraform_kv_secrets_officer
  ]
}

resource "azurerm_key_vault_secret" "redis_password" {
  count        = var.enable_redis_cache ? 1 : 0
  name         = "redis-password"
  value        = azurerm_redis_cache.mlops[0].primary_access_key
  key_vault_id = azurerm_key_vault.mlops.id

  depends_on = [
    azurerm_redis_cache.mlops,
    azurerm_role_assignment.terraform_kv_secrets_officer
  ]
}

# Diagnostic settings for Redis monitoring
resource "azurerm_monitor_diagnostic_setting" "redis" {
  count                      = var.enable_redis_cache ? 1 : 0
  name                       = "${local.resource_prefix}-redis-diag"
  target_resource_id         = azurerm_redis_cache.mlops[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.mlops.id

  enabled_log {
    category = "ConnectedClientList"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Alert for high cache utilization
resource "azurerm_monitor_metric_alert" "redis_memory_usage" {
  count               = var.enable_redis_cache ? 1 : 0
  name                = "${local.resource_prefix}-redis-memory-usage"
  resource_group_name = azurerm_resource_group.mlops.name
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
    action_group_id = azurerm_monitor_action_group.mlops_alerts.id
  }

  tags = local.common_tags
}

# Alert for cache miss rate
resource "azurerm_monitor_metric_alert" "redis_cache_miss_rate" {
  count               = var.enable_redis_cache ? 1 : 0
  name                = "${local.resource_prefix}-redis-cache-miss-rate"
  resource_group_name = azurerm_resource_group.mlops.name
  scopes              = [azurerm_redis_cache.mlops[0].id]
  description         = "Alert when Redis cache miss rate is high (>20%)"
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
    action_group_id = azurerm_monitor_action_group.mlops_alerts.id
  }

  tags = local.common_tags
}
