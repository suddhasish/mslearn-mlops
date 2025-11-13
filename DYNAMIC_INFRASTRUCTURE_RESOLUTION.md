# Dynamic Infrastructure Resolution in CD Workflow

## Overview

Updated the CD deployment workflow (`.github/workflows/cd-deploy.yml`) to dynamically resolve infrastructure resource names at runtime instead of using hardcoded values. This makes the workflow more robust and portable across environments.

## Changes Made

### 1. Removed Hardcoded Environment Variables

**Before:**
```yaml
env:
  AKS_CLUSTER_NAME: mlopsnew-dev-aks
  ACR_NAME: mlopsnewdevacr
  AKS_NAMESPACE: production
```

**After:**
```yaml
env:
  AKS_NAMESPACE: production
```

### 2. Added Infrastructure Discovery Step

Added a new step in the `resolve-inputs` job to query Azure for actual resource names:

```yaml
- name: Get infrastructure details
  id: get_infrastructure
  run: |
    # Query AKS cluster name from resource group
    AKS_NAME=$(az aks list --resource-group "${{ env.RESOURCE_GROUP }}" \
      --subscription "${{ env.AZURE_SUBSCRIPTION_ID }}" \
      --query "[0].name" -o tsv)
    
    # Query ACR name from resource group
    ACR_NAME=$(az acr list --resource-group "${{ env.RESOURCE_GROUP }}" \
      --subscription "${{ env.AZURE_SUBSCRIPTION_ID }}" \
      --query "[0].name" -o tsv)
    
    echo "aks_cluster_name=$AKS_NAME" >> $GITHUB_OUTPUT
    echo "acr_name=$ACR_NAME" >> $GITHUB_OUTPUT
    
    echo "Found AKS cluster: $AKS_NAME"
    echo "Found ACR: $ACR_NAME"
```

### 3. Added Job Outputs

Updated `resolve-inputs` job to expose infrastructure details:

```yaml
outputs:
  model_name: ${{ steps.resolve.outputs.model_name }}
  model_version: ${{ steps.resolve.outputs.model_version }}
  aml_workspace: ${{ steps.resolve.outputs.aml_workspace }}
  resource_group: ${{ steps.resolve.outputs.resource_group }}
  subscription_id: ${{ steps.resolve.outputs.subscription_id }}
  deployment_id: ${{ steps.resolve.outputs.deployment_id }}
  aks_cluster_name: ${{ steps.get_infrastructure.outputs.aks_cluster_name }}
  acr_name: ${{ steps.get_infrastructure.outputs.acr_name }}
```

### 4. Updated All References

#### ACR References
**Before:**
```yaml
az acr login --name ${{ env.ACR_NAME }}
ACR_LOGIN_SERVER=$(az acr show --name ${{ env.ACR_NAME }} --query loginServer -o tsv)
```

**After:**
```yaml
az acr login --name ${{ needs.resolve-inputs.outputs.acr_name }}
ACR_LOGIN_SERVER=$(az acr show --name ${{ needs.resolve-inputs.outputs.acr_name }} --query loginServer -o tsv)
```

#### AKS References
**Before:**
```yaml
az aks get-credentials --name ${{ env.AKS_CLUSTER_NAME }}
echo "**Cluster**: ${{ env.AKS_CLUSTER_NAME }}"
```

**After:**
```yaml
az aks get-credentials --name ${{ needs.resolve-inputs.outputs.aks_cluster_name }}
echo "**Cluster**: ${{ needs.resolve-inputs.outputs.aks_cluster_name }}"
```

#### Image Name References
Changed from environment variable to step output:

**Before:**
```yaml
echo "IMAGE_NAME=$IMAGE_NAME" >> $GITHUB_ENV
# Later used as: ${{ env.IMAGE_NAME }}
```

**After:**
```yaml
- name: Build and push Docker image to ACR
  id: build_image
  run: |
    echo "image_name=$IMAGE_NAME" >> $GITHUB_OUTPUT

# Later used as: ${{ steps.build_image.outputs.image_name }}
```

## Benefits

1. **Resilience to Naming Changes**: Workflow automatically adapts to changes in Terraform naming conventions (e.g., random suffixes)
2. **Environment Portability**: Same workflow works across DEV/PROD environments without hardcoding resource names
3. **Single Source of Truth**: Azure resource group is the authoritative source for infrastructure details
4. **Better Visibility**: Infrastructure details are discovered and displayed in workflow summary

## Testing Checklist

- [ ] Verify Azure CLI queries return correct resource names
- [ ] Confirm ACR login and image push succeeds
- [ ] Verify AKS credentials acquisition works
- [ ] Check kubectl commands execute against correct cluster
- [ ] Validate deployment manifest updates with correct image name
- [ ] Test end-to-end deployment flow (staging + production)

## Known Issues

The following lint warnings are expected and can be ignored:
- `AZURE_CREDENTIALS` secret warnings (GitHub secrets need to be configured in repository)
- `AZURE_ML_PRODUCTION_ENDPOINT_NAME` and related blue/green deployment variables (these are in disabled jobs for managed endpoint deployment)

## Infrastructure Assumptions

1. **Single AKS Cluster**: Workflow assumes one AKS cluster per resource group
2. **Single ACR**: Workflow assumes one ACR per resource group
3. **Query Order**: Uses `[0]` to select first resource from list queries

If multiple clusters/registries exist in the same resource group, consider adding additional filtering:
```bash
# Example: Filter by tag or name pattern
AKS_NAME=$(az aks list --resource-group "$RG" --query "[?tags.environment=='dev'].name | [0]" -o tsv)
```

## Related Files

- `.github/workflows/cd-deploy.yml` - Main workflow file
- `infrastructure/environments/dev/main.tf` - Terraform configuration for DEV resources
- `infrastructure/environments/dev/outputs.tf` - Terraform outputs (currently not used by workflow)

## Future Enhancements

1. **Terraform Outputs Integration**: Query Terraform state outputs instead of Azure directly
2. **Multi-Environment Support**: Add environment-specific filtering when supporting PROD environment
3. **Resource Validation**: Add checks to ensure required resources exist before proceeding
4. **Caching**: Cache infrastructure details across workflow runs to reduce API calls
