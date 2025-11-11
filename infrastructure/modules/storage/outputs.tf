output "storage_account_id" {
  description = "Storage Account ID"
  value       = azurerm_storage_account.storage.id
}

output "storage_account_name" {
  description = "Storage Account name"
  value       = azurerm_storage_account.storage.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Storage Account primary blob endpoint"
  value       = azurerm_storage_account.storage.primary_blob_endpoint
}

output "container_registry_id" {
  description = "Container Registry ID"
  value       = azurerm_container_registry.acr.id
}

output "container_registry_name" {
  description = "Container Registry name"
  value       = azurerm_container_registry.acr.name
}

output "container_registry_login_server" {
  description = "Container Registry login server"
  value       = azurerm_container_registry.acr.login_server
}
