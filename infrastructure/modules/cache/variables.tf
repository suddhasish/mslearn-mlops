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

variable "key_vault_id" {
  description = "Key Vault ID for storing secrets"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostics"
  type        = string
}

variable "monitor_action_group_id" {
  description = "Monitor action group ID for alerts"
  type        = string
}

variable "enable_redis_cache" {
  description = "Enable Redis Cache deployment"
  type        = bool
  default     = false
}

variable "redis_cache_capacity" {
  description = "Redis cache capacity (0-6 for Standard)"
  type        = number
  default     = 1
}

variable "redis_cache_family" {
  description = "Redis cache family (C for Standard)"
  type        = string
  default     = "C"
}

variable "redis_cache_sku_name" {
  description = "Redis cache SKU name"
  type        = string
  default     = "Standard"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
