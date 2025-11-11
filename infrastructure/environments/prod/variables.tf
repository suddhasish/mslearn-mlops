# PROD Environment Variables

# ============================================================================
# REQUIRED VARIABLES
# ============================================================================

variable "project_name" {
  description = "Name of the project (used as prefix)"
  type        = string
}

variable "notification_email" {
  description = "Email for budget and alert notifications"
  type        = string
}

# ============================================================================
# BASIC CONFIGURATION
# ============================================================================

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "MLOps Team"
}

variable "cost_center" {
  description = "Cost center for billing"
  type        = string
  default     = "ML-Engineering"
}

variable "business_unit" {
  description = "Business unit owning the resources"
  type        = string
  default     = "Data Science"
}

# ============================================================================
# NETWORKING CONFIGURATION
# ============================================================================

variable "allowed_subnet_cidr" {
  description = "Allowed subnet CIDR for NSG rules"
  type        = string
  default     = "10.0.0.0/16"
}

# ============================================================================
# FEATURE FLAGS - PRODUCTION DEFAULTS
# ============================================================================

variable "enable_aks_deployment" {
  description = "Enable AKS deployment"
  type        = bool
  default     = true
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints for enhanced security"
  type        = bool
  default     = true
}

variable "enable_purge_protection" {
  description = "Enable purge protection for Key Vault"
  type        = bool
  default     = true
}

variable "enable_gpu_compute" {
  description = "Enable GPU compute for ML workspace"
  type        = bool
  default     = false
}

variable "enable_custom_roles" {
  description = "Enable custom RBAC roles"
  type        = bool
  default     = true
}

variable "enable_cicd_identity" {
  description = "Enable CI/CD service principal"
  type        = bool
  default     = true
}

variable "enable_redis_cache" {
  description = "Enable Redis cache"
  type        = bool
  default     = false
}

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

variable "enable_container_insights" {
  description = "Enable container insights for AKS"
  type        = bool
  default     = true
}

variable "enable_cost_alerts" {
  description = "Enable cost management alerts"
  type        = bool
  default     = true
}

variable "enable_data_factory" {
  description = "Enable Azure Data Factory"
  type        = bool
  default     = false
}

variable "enable_logic_app" {
  description = "Enable Logic App for cost optimization"
  type        = bool
  default     = false
}

# ============================================================================
# AKS CONFIGURATION - PRODUCTION SETTINGS
# ============================================================================

variable "aks_node_count" {
  description = "Number of nodes in the AKS cluster"
  type        = number
  default     = 3
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
  description = "Minimum number of nodes for AKS auto-scaling"
  type        = number
  default     = 2
}

variable "aks_max_nodes" {
  description = "Maximum number of nodes for AKS auto-scaling"
  type        = number
  default     = 10
}

# ============================================================================
# ML WORKSPACE CONFIGURATION
# ============================================================================

variable "ml_compute_name" {
  description = "Name of the ML compute instance"
  type        = string
  default     = "cpu-cluster"
}

# ============================================================================
# REDIS CACHE CONFIGURATION
# ============================================================================

variable "redis_cache_capacity" {
  description = "Redis cache capacity (0-6)"
  type        = number
  default     = 1
}

variable "redis_cache_family" {
  description = "Redis cache family (C for Basic/Standard, P for Premium)"
  type        = string
  default     = "C"
}

variable "redis_cache_sku_name" {
  description = "Redis cache SKU (Basic, Standard, Premium)"
  type        = string
  default     = "Standard"
}

# ============================================================================
# COST MANAGEMENT - PRODUCTION BUDGET
# ============================================================================

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 500
}

variable "budget_alert_threshold" {
  description = "Budget alert threshold percentage"
  type        = number
  default     = 80
}

# ============================================================================
# TAGS
# ============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Compliance = "Required"
    Backup     = "Daily"
  }
}
