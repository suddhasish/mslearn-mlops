output "custom_role_ids" {
  description = "Map of custom role definition IDs"
  value = var.enable_custom_roles ? {
    data_scientist = azurerm_role_definition.mlops_data_scientist[0].id
    engineer       = azurerm_role_definition.mlops_engineer[0].id
    viewer         = azurerm_role_definition.mlops_viewer[0].id
  } : {}
}

output "cicd_app_id" {
  description = "CI/CD Application (Client) ID"
  value       = var.enable_cicd_identity ? azuread_application.mlops_cicd[0].client_id : null
}

output "cicd_sp_object_id" {
  description = "CI/CD Service Principal Object ID"
  value       = var.enable_cicd_identity ? azuread_service_principal.mlops_cicd[0].object_id : null
}

output "cicd_app_secret" {
  description = "CI/CD Application Secret"
  value       = var.enable_cicd_identity ? azuread_application_password.mlops_cicd[0].value : null
  sensitive   = true
}

output "ml_identity_id" {
  description = "ML Workspace User-Assigned Identity ID"
  value       = azurerm_user_assigned_identity.ml_workspace.id
}

output "ml_identity_principal_id" {
  description = "ML Workspace User-Assigned Identity Principal ID"
  value       = azurerm_user_assigned_identity.ml_workspace.principal_id
}

output "ml_identity_client_id" {
  description = "ML Workspace User-Assigned Identity Client ID"
  value       = azurerm_user_assigned_identity.ml_workspace.client_id
}
