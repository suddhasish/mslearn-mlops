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

variable "suffix" {
  description = "Random suffix for unique names"
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

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
}

variable "storage_account_primary_access_key" {
  description = "Storage account primary access key"
  type        = string
  sensitive   = true
}

variable "key_vault_id" {
  description = "Key Vault ID"
  type        = string
}

variable "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  type        = string
  sensitive   = true
}

variable "enable_devops_integration" {
  description = "Enable DevOps integration features"
  type        = bool
  default     = false
}

variable "enable_powerbi" {
  description = "Enable Power BI Embedded"
  type        = bool
  default     = false
}

variable "enable_mssql" {
  description = "Enable SQL Server and Database"
  type        = bool
  default     = false
}

variable "enable_cognitive_services" {
  description = "Enable Cognitive Services"
  type        = bool
  default     = false
}

variable "enable_synapse" {
  description = "Enable Synapse Analytics"
  type        = bool
  default     = false
}

variable "enable_communication_service" {
  description = "Enable Communication Service"
  type        = bool
  default     = false
}

variable "enable_data_factory" {
  description = "Enable Data Factory"
  type        = bool
  default     = false
}

variable "notification_email" {
  description = "Email for notifications"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
