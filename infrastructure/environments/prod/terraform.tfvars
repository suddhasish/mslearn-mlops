# Production Environment Configuration
# Values marked with VAR_ prefix are replaced from GitHub secrets at runtime

environment   = "prod"
project_name  = "VAR_PROJECT_NAME"
location      = "VAR_AZURE_LOCATION"
owner         = "MLOps Team"
cost_center   = "ML Engineering"
business_unit = "Data Science"

# Network Configuration - PRODUCTION SECURITY
allowed_subnet_cidr      = "10.0.0.0/8"
enable_private_endpoints = true
enable_purge_protection  = true

# Compute Configuration
ml_compute_name         = "cpu-cluster"
aks_node_count          = 3
aks_vm_size             = "Standard_D4s_v3"
aks_enable_auto_scaling = true
aks_min_nodes           = 2
aks_max_nodes           = 10

# Monitoring
enable_container_insights = true
log_retention_days        = 90

# Security
enable_network_policy  = true
enable_rbac            = true
enable_aad_integration = true

# Cost Management
enable_cost_alerts     = true
monthly_budget_amount  = 5000
budget_alert_threshold = 80

# DevOps Integration - ENABLED IN PROD
enable_devops_integration = true
devops_project_name       = "MLOps Project"

# Services
enable_data_factory       = true
enable_synapse            = false
enable_cognitive_services = false

# Backup
enable_backup         = true
backup_retention_days = 90

# Inference Best Practices
enable_redis_cache = false
enable_gpu_compute = false

# API Management
enable_api_management = true
enable_aks_deployment = true

# Front Door
enable_front_door = true

# Notifications
notification_email         = "VAR_NOTIFICATION_EMAIL"
enable_slack_notifications = false
