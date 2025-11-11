# Storage Account for ML workspace
resource "azurerm_storage_account" "storage" {
  name                = "${replace(var.resource_prefix, "-", "")}st${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  account_tier                     = "Standard"
  account_replication_type         = "GRS"
  account_kind                     = "StorageV2"
  https_traffic_only_enabled       = true
  min_tls_version                  = "TLS1_2"
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  shared_access_key_enabled        = true

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action             = var.enable_private_endpoints ? "Deny" : "Allow"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [var.ml_subnet_id]
  }

  tags = var.tags
}

# Container Registry for ML models and containers
resource "azurerm_container_registry" "acr" {
  name                = "${replace(var.resource_prefix, "-", "")}acr${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Premium"
  admin_enabled       = false

  network_rule_set {
    default_action = var.enable_private_endpoints ? "Deny" : "Allow"
  }

  public_network_access_enabled = !var.enable_private_endpoints

  trust_policy {
    enabled = true
  }

  retention_policy {
    enabled = true
    days    = 30
  }

  tags = var.tags
}
