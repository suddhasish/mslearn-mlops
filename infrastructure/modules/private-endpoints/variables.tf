variable "resource_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "vnet_id" {
  description = "Virtual Network ID"
  type        = string
}

variable "vnet_name" {
  description = "Virtual Network name"
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Private Endpoint subnet ID"
  type        = string
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints for services"
  type        = bool
  default     = false
}

variable "storage_account_id" {
  description = "Storage account ID"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "key_vault_name" {
  description = "Key Vault name"
  type        = string
}

variable "container_registry_id" {
  description = "Container Registry ID"
  type        = string
}

variable "container_registry_name" {
  description = "Container Registry name"
  type        = string
}

variable "ml_workspace_id" {
  description = "ML Workspace ID"
  type        = string
}

variable "ml_workspace_name" {
  description = "ML Workspace name"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
