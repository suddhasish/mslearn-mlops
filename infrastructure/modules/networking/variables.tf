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

variable "allowed_subnet_cidr" {
  description = "CIDR block for allowed subnets"
  type        = string
  default     = "10.0.0.0/8"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
