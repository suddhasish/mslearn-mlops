# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "${var.resource_prefix}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# Application Insights
resource "azurerm_application_insights" "insights" {
  name                = "${var.resource_prefix}-ai"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.workspace.id
  retention_in_days   = 90

  lifecycle {
    replace_triggered_by = [
      null_resource.appinsights_workspace_migration
    ]
    create_before_destroy = true
  }

  tags = var.tags
}

# Migration trigger for Application Insights
resource "null_resource" "appinsights_workspace_migration" {
  triggers = {
    migration_version = "1"
    workspace_id      = azurerm_log_analytics_workspace.workspace.id
  }
}

# Key Vault
resource "azurerm_key_vault" "vault" {
  name                = "${var.resource_prefix}-kv-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  enabled_for_disk_encryption     = true
  enable_rbac_authorization       = true

  purge_protection_enabled   = var.enable_purge_protection
  soft_delete_retention_days = 7

  network_acls {
    default_action             = var.enable_private_endpoints ? "Deny" : "Allow"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.ml_subnet_id]
  }

  tags = var.tags
}

# Machine Learning Workspace
resource "azurerm_machine_learning_workspace" "workspace" {
  name                    = "${var.resource_prefix}-mlw"
  location                = var.location
  resource_group_name     = var.resource_group_name
  application_insights_id = azurerm_application_insights.insights.id
  key_vault_id            = azurerm_key_vault.vault.id
  storage_account_id      = var.storage_account_id
  container_registry_id   = var.container_registry_id

  identity {
    type = "SystemAssigned"
  }

  public_network_access_enabled = !var.enable_private_endpoints
  image_build_compute_name      = var.ml_compute_name

  tags = var.tags
}

# CPU Compute Cluster
resource "azurerm_machine_learning_compute_cluster" "cpu_cluster" {
  name                          = var.ml_compute_name
  location                      = var.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.workspace.id
  vm_priority                   = "Dedicated"
  vm_size                       = "Standard_DS3_v2"

  scale_settings {
    min_node_count                       = 0
    max_node_count                       = 4
    scale_down_nodes_after_idle_duration = "PT30S"
  }

  identity {
    type = "SystemAssigned"
  }

  subnet_resource_id = var.ml_subnet_id

  tags = var.tags
}

# GPU Compute Cluster (optional)
resource "azurerm_machine_learning_compute_cluster" "gpu_cluster" {
  count                         = var.enable_gpu_compute ? 1 : 0
  name                          = "${var.ml_compute_name}-gpu"
  location                      = var.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.workspace.id
  vm_priority                   = "LowPriority"
  vm_size                       = "Standard_NC6s_v3"

  scale_settings {
    min_node_count                       = 0
    max_node_count                       = 2
    scale_down_nodes_after_idle_duration = "PT120S"
  }

  identity {
    type = "SystemAssigned"
  }

  subnet_resource_id = var.ml_subnet_id

  tags = var.tags
}
