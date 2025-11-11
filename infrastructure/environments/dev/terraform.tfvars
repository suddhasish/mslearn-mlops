# DEV Environment - Minimal Cost Configuration
# Core MLOps infrastructure for development and learning
# Values marked with VAR_ prefix are replaced from GitHub secrets at runtime

# Core context
project_name       = "VAR_PROJECT_NAME"
environment        = "dev"
location           = "VAR_AZURE_LOCATION"
owner              = "MLOps Team"
cost_center        = "ML Engineering"
business_unit      = "Data Science"
notification_email = "VAR_NOTIFICATION_EMAIL"

# Network Configuration
allowed_subnet_cidr      = "10.0.0.0/8"
enable_private_endpoints = false # Keep public for dev (cost savings)
enable_purge_protection  = false # Allow easy cleanup in dev

# ML Workspace & Compute
ml_compute_name    = "cpu-cluster"
enable_gpu_compute = false # Disabled in dev (requires quota)

# AKS Configuration - Minimal for dev
enable_aks_deployment   = true
aks_node_count          = 1
aks_vm_size             = "Standard_D4s_v3"
aks_enable_auto_scaling = false
aks_min_nodes           = 1
aks_max_nodes           = 3

# API Gateway & Edge (optional - disable to save ~$25/month)
enable_api_management  = false # Disabled for cost
enable_front_door      = false # Disabled for cost
enable_traffic_manager = false # Disabled for cost

# Monitoring
enable_container_insights = true
log_retention_days        = 30
enable_network_policy     = true
enable_rbac               = true

# Cost Management
enable_cost_alerts     = true
monthly_budget_amount  = 75
budget_alert_threshold = 80

# Optional Features - ALL DISABLED IN DEV
enable_redis_cache           = false
enable_devops_integration    = false
enable_data_factory          = false
enable_powerbi               = false
enable_mssql                 = false
enable_logic_app             = false
enable_communication_service = false
enable_custom_roles          = false
enable_cicd_identity         = false
enable_cognitive_services    = false
enable_synapse               = false

# Redis Cache (if enabled)
redis_cache_capacity = 1
redis_cache_family   = "C"
redis_cache_sku_name = "Standard"

# Slack notifications (optional)
slack_webhook_url = ""

# Tags
tags = {
  Environment = "dev"
  Scenario    = "minimal-cost"
  ManagedBy   = "Terraform"
}
