# Manual Permissions Tracking

This document tracks all permissions that were manually added outside of Terraform configuration.

## Service Principal Permissions

### Service Principal Object ID
- **Object ID**: `58eefc11-4086-4073-ade7-bc94981b1627`
- **Used in**: GitHub secret `AZURE_CREDENTIALS`
- **Subscription**: `b2b8a5e6-9a34-494b-ba62-fe9be95bd398`

### Manually Added Role Assignments

#### 1. Reader Role on Resource Group
- **Date**: November 13, 2025
- **Role**: `Reader`
- **Scope**: `/subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg`
- **Reason**: Service principal needed to read AKS and ACR resources for dynamic infrastructure discovery in `cd-deploy.yml` workflow
- **Command**:
  ```bash
  az role assignment create \
    --assignee 58eefc11-4086-4073-ade7-bc94981b1627 \
    --role "Reader" \
    --scope "/subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg"
  ```
- **Error that triggered this**:
  ```
  ERROR: (AuthorizationFailed) The client does not have authorization to perform action 
  'Microsoft.ContainerService/managedClusters/read' over scope
  ```

## Terraform-Managed Permissions

The following permissions are managed by Terraform and do NOT need manual intervention:

### AKS Kubelet Identity - ACR Pull
- **Role**: `AcrPull`
- **Assigned to**: AKS kubelet managed identity
- **Scope**: ACR (`mlopsnewdevacr`)
- **Terraform Module**: `infrastructure/modules/aks/main.tf`
- **Resource**: `azurerm_role_assignment.aks_acr_pull`

### Azure ML Workspace Managed Identity
- **Role**: Various built-in roles for Azure ML operations
- **Assigned to**: Azure ML workspace managed identity
- **Scope**: Storage Account, Key Vault, Application Insights
- **Terraform Module**: `infrastructure/modules/ml-workspace/main.tf`

## Recommendations

### To Avoid Manual Permissions in Future

1. **Add to Terraform**: Include service principal Reader role in Terraform configuration:
   ```hcl
   # infrastructure/environments/dev/main.tf
   
   # Grant GitHub Actions service principal read access to resource group
   resource "azurerm_role_assignment" "github_sp_reader" {
     scope                = azurerm_resource_group.main.id
     role_definition_name = "Reader"
     principal_id         = var.github_service_principal_object_id
   }
   ```

2. **Add Variable**:
   ```hcl
   # infrastructure/environments/dev/variables.tf
   
   variable "github_service_principal_object_id" {
     type        = string
     description = "Object ID of GitHub Actions service principal"
     default     = "58eefc11-4086-4073-ade7-bc94981b1627"
   }
   ```

3. **Consider Using**: 
   - **Workload Identity Federation** instead of service principal secrets (more secure, no credential rotation needed)
   - **Managed Identity** for GitHub-hosted runners (if using self-hosted runners in Azure)

## Verification Commands

### Check Current Role Assignments
```bash
# List all role assignments for the service principal
az role assignment list \
  --assignee 58eefc11-4086-4073-ade7-bc94981b1627 \
  --all \
  --output table

# List role assignments on specific resource group
az role assignment list \
  --resource-group mlopsnew-dev-rg \
  --output table
```

### Check AKS Kubelet Identity Permissions
```bash
# Get AKS kubelet identity
KUBELET_IDENTITY=$(az aks show \
  --resource-group mlopsnew-dev-rg \
  --name mlopsnew-dev-aks \
  --query "identityProfile.kubeletidentity.objectId" -o tsv)

# List its role assignments
az role assignment list \
  --assignee $KUBELET_IDENTITY \
  --all \
  --output table
```

## Notes

- All manual permissions should eventually be codified in Terraform for infrastructure-as-code completeness
- Document any new manual permissions in this file immediately after adding them
- Review this file quarterly to identify permissions that should be moved to Terraform
