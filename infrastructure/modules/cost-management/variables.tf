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

variable "resource_group_id" {
  description = "Resource group ID"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  type        = string
}

variable "enable_cost_alerts" {
  description = "Enable cost monitoring alerts"
  type        = bool
  default     = true
}

variable "enable_data_factory" {
  description = "Enable Data Factory for cost analytics"
  type        = bool
  default     = false
}

variable "enable_logic_app" {
  description = "Enable Logic App for cost optimization"
  type        = bool
  default     = false
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 100
}

variable "budget_alert_threshold" {
  description = "Budget alert threshold percentage"
  type        = number
  default     = 80
}

variable "notification_email" {
  description = "Email for budget notifications"
  type        = string
}

variable "aks_cluster_name" {
  description = "AKS cluster name for automation"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
