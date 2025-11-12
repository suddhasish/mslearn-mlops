# DEV Environment - MLOps Infrastructure
# Minimal cost configuration for development and learning

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.30"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-tfstate-dev"
    storage_account_name = "mlopstfstatesuddha"
    container_name       = "tfstate"
    key                  = "dev.mlops.tfstate"
    subscription_id      = "b2b8a5e6-9a34-494b-ba62-fe9be95bd398"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Local variables
locals {
  environment     = "dev"
  project         = var.project_name
  suffix          = random_string.suffix.result
  resource_prefix = "${local.project}-${local.environment}"

  common_tags = merge(var.tags, {
    Environment  = local.environment
    Project      = local.project
    ManagedBy    = "Terraform"
    Owner        = var.owner
    CostCenter   = var.cost_center
    BusinessUnit = var.business_unit
  })
}

# Resource Group
resource "azurerm_resource_group" "mlops" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# ============================================================================
# CORE INFRASTRUCTURE MODULES
# ============================================================================

# Networking Module
module "networking" {
  source = "../../modules/networking"

  resource_prefix     = local.resource_prefix
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  allowed_subnet_cidr = var.allowed_subnet_cidr
  tags                = local.common_tags
}

# Storage Module
module "storage" {
  source = "../../modules/storage"

  resource_prefix          = local.resource_prefix
  location                 = azurerm_resource_group.mlops.location
  resource_group_name      = azurerm_resource_group.mlops.name
  suffix                   = local.suffix
  ml_subnet_id             = module.networking.ml_subnet_id
  enable_private_endpoints = var.enable_private_endpoints
  tags                     = local.common_tags
}

# ML Workspace Module
module "ml_workspace" {
  source = "../../modules/ml-workspace"

  resource_prefix          = local.resource_prefix
  location                 = azurerm_resource_group.mlops.location
  resource_group_name      = azurerm_resource_group.mlops.name
  suffix                   = local.suffix
  tenant_id                = data.azurerm_client_config.current.tenant_id
  ml_subnet_id             = module.networking.ml_subnet_id
  storage_account_id       = module.storage.storage_account_id
  container_registry_id    = module.storage.container_registry_id
  enable_private_endpoints = var.enable_private_endpoints
  enable_purge_protection  = var.enable_purge_protection
  ml_compute_name          = var.ml_compute_name
  enable_gpu_compute       = var.enable_gpu_compute
  tags                     = local.common_tags
}

# AKS Module
module "aks" {
  source = "../../modules/aks"

  resource_prefix            = local.resource_prefix
  location                   = azurerm_resource_group.mlops.location
  resource_group_name        = azurerm_resource_group.mlops.name
  environment                = local.environment
  aks_subnet_id              = module.networking.aks_subnet_id
  vnet_id                    = module.networking.vnet_id
  container_registry_id      = module.storage.container_registry_id
  log_analytics_workspace_id = module.ml_workspace.log_analytics_workspace_id
  enable_aks_deployment      = var.enable_aks_deployment
  aks_node_count             = var.aks_node_count
  aks_vm_size                = var.aks_vm_size
  aks_enable_auto_scaling    = var.aks_enable_auto_scaling
  aks_min_nodes              = var.aks_min_nodes
  aks_max_nodes              = var.aks_max_nodes
  enable_private_endpoints   = var.enable_private_endpoints
  enable_network_policy      = var.enable_network_policy
  enable_rbac                = var.enable_rbac
  enable_container_insights  = var.enable_container_insights
  enable_gpu_node_pool       = false # Disabled for dev (no GPU quota)
  tags                       = local.common_tags
}

# ============================================================================
# SECURITY & IDENTITY MODULES (Optional for DEV)
# ============================================================================

# RBAC Module
module "rbac" {
  source = "../../modules/rbac"

  resource_prefix         = local.resource_prefix
  resource_group_id       = azurerm_resource_group.mlops.id
  key_vault_id            = module.ml_workspace.key_vault_id
  ml_workspace_id         = module.ml_workspace.workspace_id
  storage_account_id      = module.storage.storage_account_id
  container_registry_id   = module.storage.container_registry_id
  aks_cluster_id          = var.enable_aks_deployment ? module.aks.cluster_id : ""
  tenant_id               = data.azurerm_client_config.current.tenant_id
  subscription_id         = data.azurerm_client_config.current.subscription_id
  client_config_object_id = data.azurerm_client_config.current.object_id
  enable_aks_deployment   = var.enable_aks_deployment
  enable_custom_roles     = var.enable_custom_roles
  enable_cicd_identity    = var.enable_cicd_identity
  tags                    = local.common_tags

  depends_on = [module.ml_workspace, module.storage, module.aks]
}

# ============================================================================
# COST MANAGEMENT MODULE
# ============================================================================

# Cost Management Module
module "cost_management" {
  source = "../../modules/cost-management"

  resource_prefix            = local.resource_prefix
  location                   = azurerm_resource_group.mlops.location
  resource_group_name        = azurerm_resource_group.mlops.name
  resource_group_id          = azurerm_resource_group.mlops.id
  storage_account_name       = module.storage.storage_account_name
  log_analytics_workspace_id = module.ml_workspace.log_analytics_workspace_id
  monitor_action_group_id    = module.ml_workspace.application_insights_id
  enable_cost_alerts         = var.enable_cost_alerts
  enable_data_factory        = var.enable_data_factory
  enable_logic_app           = var.enable_logic_app
  monthly_budget_amount      = var.monthly_budget_amount
  budget_alert_threshold     = var.budget_alert_threshold
  notification_email         = var.notification_email
  aks_cluster_name           = var.enable_aks_deployment ? module.aks.cluster_name : ""
  tags                       = local.common_tags

  depends_on = [module.ml_workspace, module.storage, module.aks]
}
