# Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  count               = var.enable_aks_deployment ? 1 : 0
  name                = "${var.resource_prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.resource_prefix}-aks"
  kubernetes_version  = "1.31"

  private_cluster_enabled = var.enable_private_endpoints

  default_node_pool {
    name                = "default"
    node_count          = var.aks_node_count
    vm_size             = var.aks_vm_size
    vnet_subnet_id      = var.aks_subnet_id
    enable_auto_scaling = var.aks_enable_auto_scaling
    min_count           = var.aks_enable_auto_scaling ? var.aks_min_nodes : null
    max_count           = var.aks_enable_auto_scaling ? var.aks_max_nodes : null
    os_disk_size_gb     = 100
    os_disk_type        = "Managed"

    temporary_name_for_rotation = "defaulttmp"

    enable_host_encryption = var.environment == "prod" ? true : false

    only_critical_addons_enabled = false

    upgrade_settings {
      max_surge = "10%"
    }

    tags = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = var.enable_network_policy ? "azure" : null
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
    load_balancer_sku = "standard"
  }

  # Monitoring
  dynamic "oms_agent" {
    for_each = var.enable_container_insights ? [1] : []
    content {
      log_analytics_workspace_id      = var.log_analytics_workspace_id
      msi_auth_for_monitoring_enabled = true
    }
  }

  role_based_access_control_enabled = var.enable_rbac

  local_account_disabled = var.environment == "prod" ? true : false

  dynamic "api_server_access_profile" {
    for_each = var.enable_private_endpoints ? [1] : []
    content {
      authorized_ip_ranges = []
      subnet_id            = var.aks_subnet_id
    }
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  microsoft_defender {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  automatic_channel_upgrade = "patch"

  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3]
    }
  }

  tags = var.tags
}

# GPU Node Pool
resource "azurerm_kubernetes_cluster_node_pool" "gpu_pool" {
  count                 = var.enable_aks_deployment ? 1 : 0
  name                  = "gpupool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[0].id
  vm_size               = "Standard_NC6s_v3"
  node_count            = 0
  enable_auto_scaling   = true
  min_count             = 0
  max_count             = 3
  vnet_subnet_id        = var.aks_subnet_id

  node_taints = ["gpu=true:NoSchedule"]

  node_labels = {
    "workload" = "gpu"
  }

  tags = var.tags
}

# Role Assignments
resource "azurerm_role_assignment" "aks_acr" {
  count                = var.enable_aks_deployment ? 1 : 0
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks[0].kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "aks_network" {
  count                = var.enable_aks_deployment ? 1 : 0
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks[0].identity[0].principal_id
}
