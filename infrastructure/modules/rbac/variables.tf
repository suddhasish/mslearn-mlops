variable "resource_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID"
  type        = string
}

variable "key_vault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "ml_workspace_id" {
  description = "ML Workspace ID"
  type        = string
}

variable "storage_account_id" {
  description = "Storage account ID"
  type        = string
}

variable "container_registry_id" {
  description = "Container Registry ID"
  type        = string
}

variable "aks_cluster_id" {
  description = "AKS cluster ID"
  type        = string
  default     = ""
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "client_config_object_id" {
  description = "Current client object ID"
  type        = string
}

variable "enable_custom_roles" {
  description = "Enable custom RBAC roles"
  type        = bool
  default     = false
}

variable "enable_cicd_identity" {
  description = "Enable CI/CD service principal"
  type        = bool
  default     = false
}

variable "enable_aks_deployment" {
  description = "Whether AKS is deployed (controls AKS-related RBAC)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
