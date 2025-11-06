# Private Endpoints for Secure Network Access
# Enables private connectivity to Azure services within the VNet

# Private DNS Zones
resource "azurerm_private_dns_zone" "storage" {
  count               = local.enable_private_endpoints ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.mlops.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "keyvault" {
  count               = local.enable_private_endpoints ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.mlops.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "acr" {
  count               = local.enable_private_endpoints ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.mlops.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "ml_workspace" {
  count               = local.enable_private_endpoints ? 1 : 0
  name                = "privatelink.api.azureml.ms"
  resource_group_name = azurerm_resource_group.mlops.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone" "ml_notebooks" {
  count               = local.enable_private_endpoints ? 1 : 0
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = azurerm_resource_group.mlops.name
  tags                = local.common_tags
}

# Link Private DNS Zones to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  count                 = local.enable_private_endpoints ? 1 : 0
  name                  = "storage-link"
  resource_group_name   = azurerm_resource_group.mlops.name
  private_dns_zone_name = azurerm_private_dns_zone.storage[0].name
  virtual_network_id    = azurerm_virtual_network.mlops.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  count                 = local.enable_private_endpoints ? 1 : 0
  name                  = "keyvault-link"
  resource_group_name   = azurerm_resource_group.mlops.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault[0].name
  virtual_network_id    = azurerm_virtual_network.mlops.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  count                 = local.enable_private_endpoints ? 1 : 0
  name                  = "acr-link"
  resource_group_name   = azurerm_resource_group.mlops.name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = azurerm_virtual_network.mlops.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "ml_workspace" {
  count                 = local.enable_private_endpoints ? 1 : 0
  name                  = "ml-workspace-link"
  resource_group_name   = azurerm_resource_group.mlops.name
  private_dns_zone_name = azurerm_private_dns_zone.ml_workspace[0].name
  virtual_network_id    = azurerm_virtual_network.mlops.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "ml_notebooks" {
  count                 = local.enable_private_endpoints ? 1 : 0
  name                  = "ml-notebooks-link"
  resource_group_name   = azurerm_resource_group.mlops.name
  private_dns_zone_name = azurerm_private_dns_zone.ml_notebooks[0].name
  virtual_network_id    = azurerm_virtual_network.mlops.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# Private Endpoints
resource "azurerm_private_endpoint" "storage" {
  count               = local.enable_private_endpoints ? 1 : 0
  name                = "${local.resource_prefix}-storage-pe"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_service_connection {
    name                           = "storage-connection"
    private_connection_resource_id = azurerm_storage_account.mlops.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage[0].id]
  }

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "keyvault" {
  count               = local.enable_private_endpoints ? 1 : 0
  name                = "${local.resource_prefix}-kv-pe"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_service_connection {
    name                           = "keyvault-connection"
    private_connection_resource_id = azurerm_key_vault.mlops.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault[0].id]
  }

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "acr" {
  count               = local.enable_private_endpoints ? 1 : 0
  name                = "${local.resource_prefix}-acr-pe"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_service_connection {
    name                           = "acr-connection"
    private_connection_resource_id = azurerm_container_registry.mlops.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }

  tags = local.common_tags
}

resource "azurerm_private_endpoint" "ml_workspace" {
  count               = local.enable_private_endpoints ? 1 : 0
  name                = "${local.resource_prefix}-mlw-pe"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  subnet_id           = azurerm_subnet.private_endpoint_subnet.id

  private_service_connection {
    name                           = "mlw-connection"
    private_connection_resource_id = azurerm_machine_learning_workspace.mlops.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "mlw-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.ml_workspace[0].id, azurerm_private_dns_zone.ml_notebooks[0].id]
  }

  tags = local.common_tags
}

# Network Security Rules for Private Endpoints
resource "azurerm_network_security_group" "private_endpoint_nsg" {
  count               = local.enable_private_endpoints ? 1 : 0
  name                = "${local.resource_prefix}-pe-nsg"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name

  security_rule {
    name                       = "AllowVnetInBound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInBound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "private_endpoint_nsg_association" {
  count                     = local.enable_private_endpoints ? 1 : 0
  subnet_id                 = azurerm_subnet.private_endpoint_subnet.id
  network_security_group_id = azurerm_network_security_group.private_endpoint_nsg[0].id
}