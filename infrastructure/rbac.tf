# Role-Based Access Control (RBAC) Configuration
# Implements enterprise security with least privilege principles

# Custom Role Definitions
resource "azurerm_role_definition" "ml_data_scientist" {
  count = var.enable_custom_roles ? 1 : 0
  name  = "MLOps Data Scientist"
  scope = azurerm_resource_group.mlops.id

  description = "Custom role for data scientists with ML workspace access"

  permissions {
    actions = [
      "Microsoft.MachineLearningServices/workspaces/read",
      "Microsoft.MachineLearningServices/workspaces/experiments/*",
      "Microsoft.MachineLearningServices/workspaces/jobs/*",
      "Microsoft.MachineLearningServices/workspaces/models/read",
      "Microsoft.MachineLearningServices/workspaces/datasets/*",
      "Microsoft.MachineLearningServices/workspaces/datastores/read",
      "Microsoft.MachineLearningServices/workspaces/environments/read",
      "Microsoft.MachineLearningServices/workspaces/computes/read",
      "Microsoft.MachineLearningServices/workspaces/computes/start/action",
      "Microsoft.MachineLearningServices/workspaces/computes/stop/action",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/write",
      "Microsoft.KeyVault/vaults/secrets/read"
    ]

    not_actions = [
      "Microsoft.MachineLearningServices/workspaces/delete",
      "Microsoft.MachineLearningServices/workspaces/computes/write",
      "Microsoft.MachineLearningServices/workspaces/computes/delete"
    ]
  }

  assignable_scopes = [
    azurerm_resource_group.mlops.id
  ]
}

resource "azurerm_role_definition" "ml_engineer" {
  count = var.enable_custom_roles ? 1 : 0
  name  = "MLOps Engineer"
  scope = azurerm_resource_group.mlops.id

  description = "Custom role for ML engineers with deployment capabilities"

  permissions {
    actions = [
      "Microsoft.MachineLearningServices/workspaces/*",
      "Microsoft.Storage/storageAccounts/*",
      "Microsoft.ContainerRegistry/registries/*",
      "Microsoft.KeyVault/vaults/*",
      "Microsoft.Insights/components/*",
      "Microsoft.ContainerService/managedClusters/read",
      "Microsoft.ContainerService/managedClusters/listClusterUserCredential/action",
      "Microsoft.Resources/deployments/*"
    ]

    not_actions = [
      "Microsoft.MachineLearningServices/workspaces/delete",
      "Microsoft.Storage/storageAccounts/delete",
      "Microsoft.ContainerRegistry/registries/delete",
      "Microsoft.KeyVault/vaults/delete"
    ]
  }

  assignable_scopes = [
    azurerm_resource_group.mlops.id
  ]
}

resource "azurerm_role_definition" "ml_viewer" {
  count = var.enable_custom_roles ? 1 : 0
  name  = "MLOps Viewer"
  scope = azurerm_resource_group.mlops.id

  description = "Read-only access to ML resources for stakeholders"

  permissions {
    actions = [
      "Microsoft.MachineLearningServices/workspaces/read",
      "Microsoft.MachineLearningServices/workspaces/experiments/read",
      "Microsoft.MachineLearningServices/workspaces/jobs/read",
      "Microsoft.MachineLearningServices/workspaces/models/read",
      "Microsoft.MachineLearningServices/workspaces/datasets/read",
      "Microsoft.Insights/components/read",
      "Microsoft.Insights/components/query/read",
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.ContainerRegistry/registries/read"
    ]
  }

  assignable_scopes = [
    azurerm_resource_group.mlops.id
  ]
}

# Service Principal for CI/CD
resource "azuread_application" "mlops_cicd" {
  count        = var.enable_cicd_identity ? 1 : 0
  display_name = "${local.resource_prefix}-cicd-app"

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }

  tags = ["MLOps", "CI/CD", local.environment]
}

resource "azuread_service_principal" "mlops_cicd" {
  count        = var.enable_cicd_identity ? 1 : 0
  client_id    = azuread_application.mlops_cicd[0].client_id
  use_existing = true

  tags = ["MLOps", "CI/CD", local.environment]
}

resource "azuread_application_password" "mlops_cicd" {
  count                 = var.enable_cicd_identity ? 1 : 0
  application_object_id = azuread_application.mlops_cicd[0].object_id
  display_name          = "CI/CD Secret"
  end_date_relative     = "8760h" # 1 year
}

# Role Assignments for Service Principal
resource "azurerm_role_assignment" "cicd_ml_engineer" {
  count              = var.enable_cicd_identity && var.enable_custom_roles ? 1 : 0
  scope              = azurerm_resource_group.mlops.id
  role_definition_id = azurerm_role_definition.ml_engineer[0].role_definition_resource_id
  principal_id       = azuread_service_principal.mlops_cicd[0].object_id
}

resource "azurerm_role_assignment" "cicd_aks_contributor" {
  count                = var.enable_cicd_identity ? 1 : 0
  scope                = var.enable_aks_deployment ? azurerm_kubernetes_cluster.mlops[0].id : null
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.mlops_cicd[0].object_id
}

# Managed Identity for ML Workspace
resource "azurerm_user_assigned_identity" "ml_workspace" {
  name                = "${local.resource_prefix}-ml-identity"
  location            = azurerm_resource_group.mlops.location
  resource_group_name = azurerm_resource_group.mlops.name

  tags = local.common_tags
}

# Role assignments for ML Workspace identity
resource "azurerm_role_assignment" "ml_identity_storage" {
  scope                = azurerm_storage_account.mlops.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.ml_workspace.principal_id
}

resource "azurerm_role_assignment" "ml_identity_acr" {
  scope                = azurerm_container_registry.mlops.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.ml_workspace.principal_id
}

resource "azurerm_role_assignment" "ml_identity_keyvault" {
  scope                = azurerm_key_vault.mlops.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.ml_workspace.principal_id
}

# Key Vault Access Policies for ML Workspace System Identity
# Note: Using RBAC instead of access policies for RBAC-enabled Key Vault
# Access policies are deprecated when enable_rbac_authorization = true
resource "azurerm_role_assignment" "ml_workspace_kv_secrets" {
  scope                = azurerm_key_vault.mlops.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_machine_learning_workspace.mlops.identity[0].principal_id
  
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "ml_workspace_kv_crypto" {
  scope                = azurerm_key_vault.mlops.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = azurerm_machine_learning_workspace.mlops.identity[0].principal_id
  
  skip_service_principal_aad_check = true
}

# DEPRECATED: Access policy replaced by RBAC roles above
# Keeping as reference - DO NOT UNCOMMENT
# resource "azurerm_key_vault_access_policy" "ml_workspace" {
#   key_vault_id = azurerm_key_vault.mlops.id
#   tenant_id    = data.azurerm_client_config.current.tenant_id
#   object_id    = azurerm_machine_learning_workspace.mlops.identity[0].principal_id
#
#   secret_permissions = [
#     "Get",
#     "List",
#     "Set",
#     "Delete",
#     "Recover",
#     "Backup",
#     "Restore"
#   ]
#
#   key_permissions = [
#     "Get",
#     "List",
#     "Create",
#     "Delete",
#     "Update",
#     "Decrypt",
#     "Encrypt",
#     "UnwrapKey",
#     "WrapKey",
#     "Verify",
#     "Sign"
#   ]
# }

# Key Vault Access Policy for CI/CD Service Principal (still using access policies for external identity)
resource "azurerm_key_vault_access_policy" "cicd" {
  count        = var.enable_cicd_identity ? 1 : 0
  key_vault_id = azurerm_key_vault.mlops.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azuread_service_principal.mlops_cicd[0].object_id

  secret_permissions = [
    "Get",
    "List",
    "Set"
  ]
}

# Store CI/CD credentials in Key Vault
resource "azurerm_key_vault_secret" "cicd_app_id" {
  count        = var.enable_cicd_identity ? 1 : 0
  name         = "cicd-app-id"
  value        = azuread_application.mlops_cicd[0].client_id
  key_vault_id = azurerm_key_vault.mlops.id

  depends_on = [azurerm_key_vault_access_policy.cicd]

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "cicd_app_secret" {
  count        = var.enable_cicd_identity ? 1 : 0
  name         = "cicd-app-secret"
  value        = azuread_application_password.mlops_cicd[0].value
  key_vault_id = azurerm_key_vault.mlops.id

  depends_on = [azurerm_key_vault_access_policy.cicd]

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "tenant_id" {
  count        = var.enable_cicd_identity ? 1 : 0
  name         = "tenant-id"
  value        = data.azurerm_client_config.current.tenant_id
  key_vault_id = azurerm_key_vault.mlops.id

  depends_on = [azurerm_key_vault_access_policy.cicd]

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "subscription_id" {
  count        = var.enable_cicd_identity ? 1 : 0
  name         = "subscription-id"
  value        = data.azurerm_client_config.current.subscription_id
  key_vault_id = azurerm_key_vault.mlops.id

  depends_on = [azurerm_key_vault_access_policy.cicd]

  tags = local.common_tags
}