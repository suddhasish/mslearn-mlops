# Custom Role: MLOps Data Scientist
resource "azurerm_role_definition" "mlops_data_scientist" {
  count       = var.enable_custom_roles ? 1 : 0
  name        = "MLOps Data Scientist"
  scope       = var.resource_group_id
  description = "Can manage ML experiments, datasets, and models"

  permissions {
    actions = [
      "Microsoft.MachineLearningServices/workspaces/read",
      "Microsoft.MachineLearningServices/workspaces/experiments/*",
      "Microsoft.MachineLearningServices/workspaces/datasets/*",
      "Microsoft.MachineLearningServices/workspaces/models/*",
      "Microsoft.MachineLearningServices/workspaces/computes/read",
      "Microsoft.MachineLearningServices/workspaces/computes/start/action",
      "Microsoft.MachineLearningServices/workspaces/computes/stop/action",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/write",
    ]

    not_actions = []
  }

  assignable_scopes = [
    var.resource_group_id
  ]
}

# Custom Role: MLOps Engineer
resource "azurerm_role_definition" "mlops_engineer" {
  count       = var.enable_custom_roles ? 1 : 0
  name        = "MLOps Engineer"
  scope       = var.resource_group_id
  description = "Can manage infrastructure, deployments, and pipelines"

  permissions {
    actions = [
      "Microsoft.MachineLearningServices/workspaces/*",
      "Microsoft.ContainerRegistry/registries/*",
      "Microsoft.ContainerService/managedClusters/*",
      "Microsoft.Storage/storageAccounts/*",
      "Microsoft.KeyVault/vaults/secrets/read",
      "Microsoft.Insights/*",
    ]

    not_actions = [
      "Microsoft.MachineLearningServices/workspaces/delete",
    ]
  }

  assignable_scopes = [
    var.resource_group_id
  ]
}

# Custom Role: MLOps Viewer
resource "azurerm_role_definition" "mlops_viewer" {
  count       = var.enable_custom_roles ? 1 : 0
  name        = "MLOps Viewer"
  scope       = var.resource_group_id
  description = "Read-only access to ML resources"

  permissions {
    actions = [
      "*/read",
    ]

    not_actions = []
  }

  assignable_scopes = [
    var.resource_group_id
  ]
}

# Azure AD Application for CI/CD
resource "azuread_application" "mlops_cicd" {
  count        = var.enable_cicd_identity ? 1 : 0
  display_name = "${var.resource_prefix}-cicd"
}

# Service Principal for CI/CD
resource "azuread_service_principal" "mlops_cicd" {
  count        = var.enable_cicd_identity ? 1 : 0
  client_id    = azuread_application.mlops_cicd[0].client_id
  use_existing = true
}

# Service Principal Password
resource "azuread_application_password" "mlops_cicd" {
  count             = var.enable_cicd_identity ? 1 : 0
  application_id    = azuread_application.mlops_cicd[0].id
  end_date_relative = "8760h" # 1 year
}

# User-assigned identity for ML Workspace
resource "azurerm_user_assigned_identity" "ml_workspace" {
  name                = "${var.resource_prefix}-ml-identity"
  resource_group_name = basename(var.resource_group_id)
  location            = data.azurerm_resource_group.rg.location

  tags = var.tags
}

# Data source for resource group
data "azurerm_resource_group" "rg" {
  name = basename(var.resource_group_id)
}

# Grant CI/CD SP Contributor access to resource group
resource "azurerm_role_assignment" "cicd_contributor" {
  count                = var.enable_cicd_identity ? 1 : 0
  scope                = var.resource_group_id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.mlops_cicd[0].object_id
}

# Grant ML identity Storage Blob Data Contributor
resource "azurerm_role_assignment" "ml_storage" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.ml_workspace.principal_id
}

# Grant ML identity AcrPull
resource "azurerm_role_assignment" "ml_acr" {
  scope                = var.container_registry_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.ml_workspace.principal_id
}

# Grant ML identity Key Vault Secrets User
resource "azurerm_role_assignment" "ml_keyvault" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.ml_workspace.principal_id
  depends_on           = [azurerm_role_definition.mlops_data_scientist, azurerm_role_definition.mlops_engineer, azurerm_role_definition.mlops_viewer]
}

# Note: AKS to ACR role assignment is handled in the AKS module to avoid duplication

# Grant ML Workspace system identity Key Vault Secrets Officer for RBAC
resource "azurerm_role_assignment" "ml_workspace_kv_secrets_officer" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_machine_learning_workspace.ml.identity[0].principal_id
}

# Grant ML Workspace system identity Key Vault Crypto User for encryption
resource "azurerm_role_assignment" "ml_workspace_kv_crypto" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = data.azurerm_machine_learning_workspace.ml.identity[0].principal_id
}

# Data source for ML workspace
data "azurerm_machine_learning_workspace" "ml" {
  name                = split("/", var.ml_workspace_id)[8]
  resource_group_name = basename(var.resource_group_id)
}

# Key Vault Access Policy for CI/CD SP
resource "azurerm_key_vault_access_policy" "cicd" {
  count        = var.enable_cicd_identity ? 1 : 0
  key_vault_id = var.key_vault_id
  tenant_id    = var.tenant_id
  object_id    = azuread_service_principal.mlops_cicd[0].object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
  ]
}

# Store CI/CD credentials in Key Vault
resource "azurerm_key_vault_secret" "cicd_app_id" {
  count        = var.enable_cicd_identity ? 1 : 0
  name         = "cicd-app-id"
  value        = azuread_application.mlops_cicd[0].client_id
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_key_vault_access_policy.cicd]
}

resource "azurerm_key_vault_secret" "cicd_app_secret" {
  count        = var.enable_cicd_identity ? 1 : 0
  name         = "cicd-app-secret"
  value        = azuread_application_password.mlops_cicd[0].value
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_key_vault_access_policy.cicd]
}

resource "azurerm_key_vault_secret" "tenant_id" {
  count        = var.enable_cicd_identity ? 1 : 0
  name         = "tenant-id"
  value        = var.tenant_id
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_key_vault_access_policy.cicd]
}

resource "azurerm_key_vault_secret" "subscription_id" {
  count        = var.enable_cicd_identity ? 1 : 0
  name         = "subscription-id"
  value        = var.subscription_id
  key_vault_id = var.key_vault_id

  depends_on = [azurerm_key_vault_access_policy.cicd]
}
