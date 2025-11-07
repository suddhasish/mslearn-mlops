# Azure MLOps Infrastructure - Main Configuration
# Provides complete enterprise-grade MLOps infrastructure for senior management showcase

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

  # Remote backend configured in backend.tf
}

# Configure the Azure Provider
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

# Data sources for current client configuration
data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# Generate random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Local variables for consistent naming and tagging
locals {
  environment = var.environment
  project     = var.project_name
  suffix      = random_string.suffix.result

  # Consistent naming convention
  resource_prefix = "${local.project}-${local.environment}"

  # Common tags applied to all resources
  common_tags = {
    Environment  = local.environment
    Project      = local.project
    ManagedBy    = "Terraform"
    Owner        = var.owner
    CostCenter   = var.cost_center
    BusinessUnit = var.business_unit
    CreatedDate  = formatdate("YYYY-MM-DD", timestamp())
  }

  # Security and compliance settings
  allowed_subnet_cidr      = var.allowed_subnet_cidr
  enable_private_endpoints = var.enable_private_endpoints
}

# Resource Group
resource "azurerm_resource_group" "mlops" {
  name     = "${local.resource_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# Virtual Network for secure networking
resource "azurerm_virtual_network" "mlops" {
  name                = "${local.resource_prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  tags                = local.common_tags
}

# Subnets for different components
resource "azurerm_subnet" "ml_subnet" {
  name                 = "ml-subnet"
  resource_group_name  = azurerm_resource_group.mlops.name
  virtual_network_name = azurerm_virtual_network.mlops.name
  address_prefixes     = ["10.0.1.0/24"]

  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.ContainerRegistry"
  ]
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.mlops.name
  virtual_network_name = azurerm_virtual_network.mlops.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "private_endpoint_subnet" {
  name                 = "private-endpoint-subnet"
  resource_group_name  = azurerm_resource_group.mlops.name
  virtual_network_name = azurerm_virtual_network.mlops.name
  address_prefixes     = ["10.0.3.0/24"]

  private_endpoint_network_policies = "Disabled"
}

# Network Security Groups
resource "azurerm_network_security_group" "ml_nsg" {
  name                = "${local.resource_prefix}-ml-nsg"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureML"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["29876", "29877"]
    source_address_prefix      = "AzureMachineLearning"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Associate NSG with ML subnet
resource "azurerm_subnet_network_security_group_association" "ml_nsg_association" {
  subnet_id                 = azurerm_subnet.ml_subnet.id
  network_security_group_id = azurerm_network_security_group.ml_nsg.id
}

# Key Vault for secrets management
resource "azurerm_key_vault" "mlops" {
  name                = "${local.resource_prefix}-kv-${local.suffix}"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  enabled_for_disk_encryption     = true
  enable_rbac_authorization       = true

  purge_protection_enabled   = var.enable_purge_protection
  soft_delete_retention_days = 7

  network_acls {
    default_action             = local.enable_private_endpoints ? "Deny" : "Allow"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.ml_subnet.id]
  }

  tags = local.common_tags
}

# Storage Account for ML workspace
resource "azurerm_storage_account" "mlops" {
  name                = "${replace(local.resource_prefix, "-", "")}st${local.suffix}"
  resource_group_name = azurerm_resource_group.mlops.name
  location            = azurerm_resource_group.mlops.location

  account_tier                     = "Standard"
  account_replication_type         = "GRS"
  account_kind                     = "StorageV2"
  enable_https_traffic_only        = true
  min_tls_version                  = "TLS1_2"
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  shared_access_key_enabled        = true

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action             = local.enable_private_endpoints ? "Deny" : "Allow"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [azurerm_subnet.ml_subnet.id]
  }

  tags = local.common_tags
}

# Container Registry for ML models and containers
resource "azurerm_container_registry" "mlops" {
  name                = "${replace(local.resource_prefix, "-", "")}acr${local.suffix}"
  resource_group_name = azurerm_resource_group.mlops.name
  location            = azurerm_resource_group.mlops.location
  sku                 = "Premium"
  admin_enabled       = false

  network_rule_set {
    default_action = local.enable_private_endpoints ? "Deny" : "Allow"

    virtual_network {
      action    = "Allow"
      subnet_id = azurerm_subnet.ml_subnet.id
    }
  }

  public_network_access_enabled = !local.enable_private_endpoints

  trust_policy {
    enabled = true
  }

  retention_policy {
    enabled = true
    days    = 30
  }

  tags = local.common_tags
}

# Application Insights for monitoring
resource "azurerm_application_insights" "mlops" {
  name                = "${local.resource_prefix}-ai"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  application_type    = "web"

  retention_in_days = 90

  tags = local.common_tags
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "mlops" {
  name                = "${local.resource_prefix}-law"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}

# Machine Learning Workspace
resource "azurerm_machine_learning_workspace" "mlops" {
  name                    = "${local.resource_prefix}-mlw"
  location                = azurerm_resource_group.mlops.location
  resource_group_name     = azurerm_resource_group.mlops.name
  application_insights_id = azurerm_application_insights.mlops.id
  key_vault_id            = azurerm_key_vault.mlops.id
  storage_account_id      = azurerm_storage_account.mlops.id
  container_registry_id   = azurerm_container_registry.mlops.id

  identity {
    type = "SystemAssigned"
  }

  public_network_access_enabled = !local.enable_private_endpoints
  image_build_compute_name      = var.ml_compute_name

  tags = local.common_tags
}

# Machine Learning Compute Cluster
resource "azurerm_machine_learning_compute_cluster" "cpu_cluster" {
  name                          = var.ml_compute_name
  location                      = azurerm_resource_group.mlops.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.mlops.id
  vm_priority                   = "Dedicated"
  vm_size                       = "Standard_DS3_v2"

  scale_settings {
    min_node_count                       = 0
    max_node_count                       = 4
    scale_down_nodes_after_idle_duration = "PT30S"
  }

  identity {
    type = "SystemAssigned"
  }

  subnet_resource_id = azurerm_subnet.ml_subnet.id

  tags = local.common_tags
}

# Machine Learning Compute Cluster for GPU workloads
resource "azurerm_machine_learning_compute_cluster" "gpu_cluster" {
  name                          = "${var.ml_compute_name}-gpu"
  location                      = azurerm_resource_group.mlops.location
  machine_learning_workspace_id = azurerm_machine_learning_workspace.mlops.id
  vm_priority                   = "LowPriority"
  vm_size                       = "Standard_NC6s_v3"

  scale_settings {
    min_node_count                       = 0
    max_node_count                       = 2
    scale_down_nodes_after_idle_duration = "PT120S"
  }

  identity {
    type = "SystemAssigned"
  }

  subnet_resource_id = azurerm_subnet.ml_subnet.id

  tags = local.common_tags
}