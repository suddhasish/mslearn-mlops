output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.vnet.name
}

output "ml_subnet_id" {
  description = "ML Subnet ID"
  value       = azurerm_subnet.ml_subnet.id
}

output "aks_subnet_id" {
  description = "AKS Subnet ID"
  value       = azurerm_subnet.aks_subnet.id
}

output "private_endpoint_subnet_id" {
  description = "Private Endpoint Subnet ID"
  value       = azurerm_subnet.private_endpoint_subnet.id
}

output "ml_nsg_id" {
  description = "ML Network Security Group ID"
  value       = azurerm_network_security_group.ml_nsg.id
}

output "aks_nsg_id" {
  description = "AKS Network Security Group ID"
  value       = azurerm_network_security_group.aks_nsg.id
}
