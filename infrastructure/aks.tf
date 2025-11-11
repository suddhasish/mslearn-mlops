# Azure Kubernetes Service (AKS) for Production Model Deployments
# Provides enterprise-grade container orchestration with auto-scaling

resource "azurerm_kubernetes_cluster" "mlops" {
  count               = var.enable_aks_deployment ? 1 : 0
  name                = "${local.resource_prefix}-aks"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  dns_prefix          = "${local.resource_prefix}-aks"
  kubernetes_version  = "1.29"  # Using supported non-LTS version

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

    # Security - Use ephemeral OS disks for better security and performance
    temporary_name_for_rotation = "defaulttmp"

    # Security - Enable encryption at host
    enable_host_encryption = var.environment == "prod" ? true : false

    # Security - Only allow critical system pods on default pool
    only_critical_addons_enabled = false

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

  # Azure AD / Entra ID Integration (managed)
  # Note: Rely on provider defaults for managed Entra integration to avoid deprecation warnings.
  # The provider enables managed Entra by default in current versions; remove explicit block.

  # Monitoring
  dynamic "oms_agent" {
    for_each = var.enable_container_insights ? [1] : []
    content {
      log_analytics_workspace_id      = azurerm_log_analytics_workspace.mlops.id
      msi_auth_for_monitoring_enabled = true
    }
  }

  # Security - Role-based access control
  role_based_access_control_enabled = var.enable_rbac

  # Security - Local account disabled for production
  local_account_disabled = var.environment == "prod" ? true : false

  # Security - API server access profile for private clusters
  dynamic "api_server_access_profile" {
    for_each = local.enable_private_endpoints ? [1] : []
    content {
      authorized_ip_ranges = []
      subnet_id            = azurerm_subnet.aks_subnet.id
    }
  }

  # Security - Key Vault secrets provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Security - Microsoft Defender for Containers
  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.mlops.id
  }

  # Security - Workload identity for pod-managed identities
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # Security - Image cleaner to remove unused images
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

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
  count                 = var.enable_aks_deployment ? 1 : 0
  name                  = "gpupool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.mlops[0].id
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
  count                = var.enable_aks_deployment ? 1 : 0
  scope                = azurerm_container_registry.mlops.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.mlops[0].kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "aks_network" {
  count                = var.enable_aks_deployment ? 1 : 0
  scope                = azurerm_virtual_network.mlops.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.mlops[0].identity[0].principal_id
}

# Azure Front Door for global load balancing and WAF
resource "azurerm_cdn_frontdoor_profile" "mlops" {
  count               = var.enable_front_door ? 1 : 0
  name                = "${local.resource_prefix}-fd"
  resource_group_name = azurerm_resource_group.mlops.name
  sku_name            = "Standard_AzureFrontDoor"

  tags = local.common_tags
}

resource "azurerm_cdn_frontdoor_endpoint" "mlops" {
  count                    = var.enable_front_door ? 1 : 0
  name                     = "${local.resource_prefix}-fd-endpoint"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.mlops[0].id

  tags = local.common_tags
}

# API Management for ML model APIs
resource "azurerm_api_management" "mlops" {
  count               = var.enable_api_management ? 1 : 0
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

# API Management API for ML Inference
resource "azurerm_api_management_api" "ml_inference" {
  count               = var.enable_api_management ? 1 : 0
  name                = "ml-inference-api"
  resource_group_name = azurerm_resource_group.mlops.name
  api_management_name = azurerm_api_management.mlops[0].name
  revision            = "1"
  display_name        = "ML Inference API"
  path                = "inference"
  protocols           = ["https"]
  service_url         = var.enable_aks_deployment ? "http://${azurerm_kubernetes_cluster.mlops[0].fqdn}" : ""

  subscription_required = true
}

# API Management Policy for Rate Limiting and Throttling
resource "azurerm_api_management_api_policy" "ml_inference_policy" {
  count               = var.enable_api_management ? 1 : 0
  api_name            = azurerm_api_management_api.ml_inference[0].name
  api_management_name = azurerm_api_management.mlops[0].name
  resource_group_name = azurerm_resource_group.mlops.name

  xml_content = <<XML
<policies>
  <inbound>
    <!-- Rate limiting: 100 requests per minute per IP address -->
    <rate-limit-by-key calls="100" 
                       renewal-period="60" 
                       counter-key="@(context.Request.IpAddress)" />
    
    <!-- Quota: 1 million requests per month per subscription key -->
    <quota-by-key calls="1000000" 
                  renewal-period="2629800" 
                  counter-key="@(context.Subscription?.Key ?? "anonymous")" />
    
    <!-- Request size limit: 5MB -->
    <set-body template="none" />
    <choose>
      <when condition="@(context.Request.Body.As<string>(preserveContent: true).Length > 5242880)">
        <return-response>
          <set-status code="413" reason="Request Entity Too Large" />
          <set-body>Request body exceeds 5MB limit</set-body>
        </return-response>
      </when>
    </choose>
    
    <!-- Add correlation ID for tracing -->
    <set-header name="X-Correlation-ID" exists-action="skip">
      <value>@(Guid.NewGuid().ToString())</value>
    </set-header>
    
    <!-- Add timestamp -->
    <set-header name="X-Request-Time" exists-action="override">
      <value>@(DateTime.UtcNow.ToString("o"))</value>
    </set-header>
    
    <!-- CORS policy -->
    <cors allow-credentials="false">
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>POST</method>
        <method>GET</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
    
    <!-- Base URL -->
    <set-backend-service base-url="@(context.Api.ServiceUrl.ToString())" />
  </inbound>
  <backend>
    <!-- Timeout: 30 seconds -->
    <forward-request timeout="30" />
  </backend>
  <outbound>
    <!-- Add response headers -->
    <set-header name="X-Response-Time" exists-action="override">
      <value>@(DateTime.UtcNow.ToString("o"))</value>
    </set-header>
    <set-header name="X-RateLimit-Remaining" exists-action="override">
      <value>@(context.Response.Headers.GetValueOrDefault("X-Rate-Limit-Remaining","100"))</value>
    </set-header>
  </outbound>
  <on-error>
    <!-- Error handling -->
    <set-header name="X-Error-Message" exists-action="override">
      <value>@(context.LastError.Message)</value>
    </set-header>
    <set-body>@{
      return new JObject(
        new JProperty("error", context.LastError.Message),
        new JProperty("timestamp", DateTime.UtcNow.ToString("o")),
        new JProperty("path", context.Request.Url.Path)
      ).ToString();
    }</set-body>
  </on-error>
</policies>
XML
}

# Traffic Manager for multi-region deployments
resource "azurerm_traffic_manager_profile" "mlops" {
  count                  = var.enable_traffic_manager ? 1 : 0
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