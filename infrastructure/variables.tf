# Input Variables for Azure MLOps Infrastructure
# Configure these values based on your organization's requirements

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "mlops-enterprise"

  validation {
    condition     = length(var.project_name) <= 15 && can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must be 15 characters or less and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "East US 2"
}

variable "owner" {
  description = "Owner of the resources (for tagging)"
  type        = string
  default     = "MLOps Team"
}

variable "cost_center" {
  description = "Cost center for billing (for tagging)"
  type        = string
  default     = "ML Engineering"
}

variable "business_unit" {
  description = "Business unit (for tagging)"
  type        = string
  default     = "Data Science"
}

variable "allowed_subnet_cidr" {
  description = "CIDR block for allowed subnets"
  type        = string
  default     = "10.0.0.0/8"
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints for secure connectivity"
  type        = bool
  default     = true
}

variable "enable_purge_protection" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = false
}

variable "ml_compute_name" {
  description = "Name for ML compute cluster"
  type        = string
  default     = "cpu-cluster"
}

# AKS Configuration Variables
variable "aks_node_count" {
  description = "Initial number of AKS nodes"
  type        = number
  default     = 2

  validation {
    condition     = var.aks_node_count >= 1 && var.aks_node_count <= 10
    error_message = "AKS node count must be between 1 and 10."
  }
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "aks_enable_auto_scaling" {
  description = "Enable auto-scaling for AKS"
  type        = bool
  default     = true
}

variable "aks_min_nodes" {
  description = "Minimum number of AKS nodes for auto-scaling"
  type        = number
  default     = 1
}

variable "aks_max_nodes" {
  description = "Maximum number of AKS nodes for auto-scaling"
  type        = number
  default     = 10
}

# Monitoring Configuration
variable "enable_container_insights" {
  description = "Enable Container Insights for AKS monitoring"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 7 && var.log_retention_days <= 730
    error_message = "Log retention days must be between 7 and 730."
  }
}

# Security Configuration
variable "enable_network_policy" {
  description = "Enable network policy for AKS"
  type        = bool
  default     = true
}

variable "enable_rbac" {
  description = "Enable RBAC for AKS"
  type        = bool
  default     = true
}

variable "enable_aad_integration" {
  description = "Enable Azure AD integration for AKS"
  type        = bool
  default     = true
}

# Cost Management
variable "enable_cost_alerts" {
  description = "Enable cost management alerts"
  type        = bool
  default     = true
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD for cost alerts"
  type        = number
  default     = 1000
}

variable "budget_alert_threshold" {
  description = "Budget alert threshold percentage"
  type        = number
  default     = 80

  validation {
    condition     = var.budget_alert_threshold > 0 && var.budget_alert_threshold <= 100
    error_message = "Budget alert threshold must be between 1 and 100."
  }
}

# Azure DevOps Integration
variable "enable_devops_integration" {
  description = "Enable Azure DevOps integration (Function App, SQL, Power BI, Stream Analytics). Set to false for Azure free tier."
  type        = bool
  default     = false # Changed to false - not compatible with free tier
}

variable "devops_organization_url" {
  description = "Azure DevOps organization URL"
  type        = string
  default     = ""
}

variable "devops_project_name" {
  description = "Azure DevOps project name"
  type        = string
  default     = "MLOps Project"
}

# Data Science Configuration
variable "enable_data_factory" {
  description = "Enable Azure Data Factory for data pipeline orchestration"
  type        = bool
  default     = true
}

variable "enable_synapse" {
  description = "Enable Azure Synapse Analytics for big data processing"
  type        = bool
  default     = false
}

variable "enable_cognitive_services" {
  description = "Enable Azure Cognitive Services"
  type        = bool
  default     = false
}

# Backup and Disaster Recovery
variable "enable_backup" {
  description = "Enable backup for critical resources"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 30
}

# Notification Configuration
variable "notification_email" {
  description = "Email address for alerts and notifications"
  type        = string
  default     = ""
}

variable "enable_slack_notifications" {
  description = "Enable Slack notifications"
  type        = bool
  default     = false
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}