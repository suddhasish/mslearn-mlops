# Private DNS Zone for Storage (Blob)
resource "azurerm_private_dns_zone" "storage" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "keyvault" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Private DNS Zone for Container Registry
resource "azurerm_private_dns_zone" "acr" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Private DNS Zone for ML Workspace
resource "azurerm_private_dns_zone" "ml_workspace" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "privatelink.api.azureml.ms"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Private DNS Zone for ML Notebooks
resource "azurerm_private_dns_zone" "ml_notebooks" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link DNS Zones to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  count                 = var.enable_private_endpoints ? 1 : 0
  name                  = "${var.resource_prefix}-storage-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.storage[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  count                 = var.enable_private_endpoints ? 1 : 0
  name                  = "${var.resource_prefix}-keyvault-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  count                 = var.enable_private_endpoints ? 1 : 0
  name                  = "${var.resource_prefix}-acr-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "ml_workspace" {
  count                 = var.enable_private_endpoints ? 1 : 0
  name                  = "${var.resource_prefix}-ml-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.ml_workspace[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "ml_notebooks" {
  count                 = var.enable_private_endpoints ? 1 : 0
  name                  = "${var.resource_prefix}-notebooks-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.ml_notebooks[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

# Private Endpoint for Storage (Blob)
resource "azurerm_private_endpoint" "storage" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "${var.resource_prefix}-storage-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.resource_prefix}-storage-psc"
    private_connection_resource_id = var.storage_account_id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "storage-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.storage[0].id]
  }

  tags = var.tags
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "keyvault" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "${var.resource_prefix}-keyvault-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.resource_prefix}-keyvault-psc"
    private_connection_resource_id = var.key_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "keyvault-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.keyvault[0].id]
  }

  tags = var.tags
}

# Private Endpoint for Container Registry
resource "azurerm_private_endpoint" "acr" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "${var.resource_prefix}-acr-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.resource_prefix}-acr-psc"
    private_connection_resource_id = var.container_registry_id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }

  tags = var.tags
}

# Private Endpoint for ML Workspace
resource "azurerm_private_endpoint" "ml_workspace" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "${var.resource_prefix}-ml-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.resource_prefix}-ml-psc"
    private_connection_resource_id = var.ml_workspace_id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "ml-dns-group"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.ml_workspace[0].id,
      azurerm_private_dns_zone.ml_notebooks[0].id
    ]
  }

  tags = var.tags
}

# Network Security Group for Private Endpoints
resource "azurerm_network_security_group" "private_endpoint_nsg" {
  count               = var.enable_private_endpoints ? 1 : 0
  name                = "${var.resource_prefix}-pe-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowVnetInBound"
    priority                   = 100
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
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Associate NSG with Private Endpoint Subnet
resource "azurerm_subnet_network_security_group_association" "private_endpoint" {
  count                     = var.enable_private_endpoints ? 1 : 0
  subnet_id                 = var.private_endpoint_subnet_id
  network_security_group_id = azurerm_network_security_group.private_endpoint_nsg[0].id
}
