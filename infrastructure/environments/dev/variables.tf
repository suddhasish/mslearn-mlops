# DEV Environment Variables

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "owner" {
  description = "Owner"
  type        = string
  default     = "MLOps Team"
}

variable "cost_center" {
  description = "Cost center"
  type        = string
  default     = "ML Engineering"
}

variable "business_unit" {
  description = "Business unit"
  type        = string
  default     = "Data Science"
}

variable "allowed_subnet_cidr" {
  description = "Allowed subnet CIDR"
  type        = string
  default     = "10.0.0.0/8"
}

variable "enable_private_endpoints" {
  description = "Enable private endpoints"
  type        = bool
  default     = false
}

variable "enable_purge_protection" {
  description = "Enable Key Vault purge protection"
  type        = bool
  default     = false
}

variable "ml_compute_name" {
  description = "ML compute cluster name"
  type        = string
  default     = "cpu-cluster"
}

variable "enable_gpu_compute" {
  description = "Enable GPU compute"
  type        = bool
  default     = false
}

variable "enable_aks_deployment" {
  description = "Enable AKS deployment"
  type        = bool
  default     = true
}

variable "aks_node_count" {
  description = "AKS node count"
  type        = number
  default     = 1
}

variable "aks_vm_size" {
  description = "AKS VM size"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "aks_enable_auto_scaling" {
  description = "Enable AKS auto-scaling"
  type        = bool
  default     = false
}

variable "aks_min_nodes" {
  description = "AKS minimum nodes"
  type        = number
  default     = 1
}

variable "aks_max_nodes" {
  description = "AKS maximum nodes"
  type        = number
  default     = 3
}

variable "enable_network_policy" {
  description = "Enable network policy"
  type        = bool
  default     = true
}

variable "enable_rbac" {
  description = "Enable RBAC"
  type        = bool
  default     = true
}

variable "enable_container_insights" {
  description = "Enable container insights"
  type        = bool
  default     = true
}

variable "enable_custom_roles" {
  description = "Enable custom RBAC roles"
  type        = bool
  default     = false
}

variable "enable_cicd_identity" {
  description = "Enable CI/CD identity"
  type        = bool
  default     = false
}

variable "enable_cost_alerts" {
  description = "Enable cost alerts"
  type        = bool
  default     = true
}

variable "enable_data_factory" {
  description = "Enable Data Factory"
  type        = bool
  default     = false
}

variable "enable_logic_app" {
  description = "Enable Logic App"
  type        = bool
  default     = false
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 75
}

variable "budget_alert_threshold" {
  description = "Budget alert threshold percentage"
  type        = number
  default     = 80
}

variable "notification_email" {
  description = "Notification email"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
