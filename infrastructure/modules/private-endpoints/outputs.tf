output "private_dns_zone_ids" {
  description = "Map of Private DNS Zone IDs"
  value = var.enable_private_endpoints ? {
    storage      = azurerm_private_dns_zone.storage[0].id
    keyvault     = azurerm_private_dns_zone.keyvault[0].id
    acr          = azurerm_private_dns_zone.acr[0].id
    ml_workspace = azurerm_private_dns_zone.ml_workspace[0].id
    ml_notebooks = azurerm_private_dns_zone.ml_notebooks[0].id
  } : {}
}

output "private_endpoint_ids" {
  description = "Map of Private Endpoint IDs"
  value = var.enable_private_endpoints ? {
    storage      = azurerm_private_endpoint.storage[0].id
    keyvault     = azurerm_private_endpoint.keyvault[0].id
    acr          = azurerm_private_endpoint.acr[0].id
    ml_workspace = azurerm_private_endpoint.ml_workspace[0].id
  } : {}
}

output "nsg_id" {
  description = "Private Endpoint NSG ID"
  value       = var.enable_private_endpoints ? azurerm_network_security_group.private_endpoint_nsg[0].id : null
}

output "storage_private_endpoint_ip" {
  description = "Storage Private Endpoint IP Address"
  value       = var.enable_private_endpoints ? azurerm_private_endpoint.storage[0].private_service_connection[0].private_ip_address : null
}
