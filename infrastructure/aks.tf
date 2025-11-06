# Azure Kubernetes Service (AKS) for Production Model Deployments
# Provides enterprise-grade container orchestration with auto-scaling

resource "azurerm_kubernetes_cluster" "mlops" {
  name                = "${local.resource_prefix}-aks"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  dns_prefix          = "${local.resource_prefix}-aks"
  kubernetes_version  = "1.28"

  private_cluster_enabled = local.enable_private_endpoints

  default_node_pool {
    name                = "default"
    node_count          = var.aks_node_count
    vm_size             = var.aks_vm_size
    vnet_subnet_id      = azurerm_subnet.aks_subnet.id
    enable_auto_scaling = var.aks_enable_auto_scaling
    min_count           = var.aks_enable_auto_scaling ? var.aks_min_nodes : null
    max_count           = var.aks_enable_auto_scaling ? var.aks_max_nodes : null
    os_disk_size_gb     = 100
    os_disk_type        = "Managed"

    upgrade_settings {
      max_surge = "10%"
    }

    tags = local.common_tags
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

  # Azure AD Integration
  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.enable_aad_integration ? [1] : []
    content {
      managed            = true
      azure_rbac_enabled = var.enable_rbac
    }
  }

  # Monitoring
  dynamic "oms_agent" {
    for_each = var.enable_container_insights ? [1] : []
    content {
      log_analytics_workspace_id = azurerm_log_analytics_workspace.mlops.id
    }
  }

  # Security
  role_based_access_control_enabled = var.enable_rbac

  # Auto-upgrade
  automatic_channel_upgrade = "patch"

  # Maintenance window
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 3]
    }
  }

  tags = local.common_tags
}

# Additional Node Pool for GPU workloads
resource "azurerm_kubernetes_cluster_node_pool" "gpu_pool" {
  name                  = "gpupool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.mlops.id
  vm_size               = "Standard_NC6s_v3"
  node_count            = 0
  enable_auto_scaling   = true
  min_count             = 0
  max_count             = 3
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id

  node_taints = ["gpu=true:NoSchedule"]

  node_labels = {
    "workload" = "gpu"
  }

  tags = local.common_tags
}

# Role assignments for AKS
resource "azurerm_role_assignment" "aks_acr" {
  scope                = azurerm_container_registry.mlops.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.mlops.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "aks_network" {
  scope                = azurerm_virtual_network.mlops.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.mlops.identity[0].principal_id
}

# Azure Front Door for global load balancing and WAF
resource "azurerm_cdn_frontdoor_profile" "mlops" {
  name                = "${local.resource_prefix}-fd"
  resource_group_name = azurerm_resource_group.mlops.name
  sku_name            = "Standard_AzureFrontDoor"

  tags = local.common_tags
}

resource "azurerm_cdn_frontdoor_endpoint" "mlops" {
  name                     = "${local.resource_prefix}-fd-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.mlops.id

  tags = local.common_tags
}

# API Management for ML model APIs
resource "azurerm_api_management" "mlops" {
  name                = "${local.resource_prefix}-apim"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  publisher_name      = var.owner
  publisher_email     = var.notification_email != "" ? var.notification_email : "admin@example.com"
  sku_name            = "Developer_1"

  virtual_network_type = local.enable_private_endpoints ? "Internal" : "None"

  dynamic "virtual_network_configuration" {
    for_each = local.enable_private_endpoints ? [1] : []
    content {
      subnet_id = azurerm_subnet.ml_subnet.id
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Traffic Manager for multi-region deployments
resource "azurerm_traffic_manager_profile" "mlops" {
  name                   = "${local.resource_prefix}-tm"
  resource_group_name    = azurerm_resource_group.mlops.name
  traffic_routing_method = "Performance"

  dns_config {
    relative_name = "${local.resource_prefix}-ml-api"
    ttl           = 300
  }

  monitor_config {
    protocol                     = "HTTPS"
    port                         = 443
    path                         = "/health"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }

  tags = local.common_tags
}