variable "resource_prefix" {
  description = "Prefix for resource naming"
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

variable "suffix" {
  description = "Random suffix for unique naming"
  type        = string
}

variable "ml_subnet_id" {
  description = "ML Subnet ID for service endpoints"
  type        = string
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
