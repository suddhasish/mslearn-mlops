# Infrastructure Integration Guide

## Overview
This guide explains how to connect your existing GitHub Actions pipelines with the Terraform-deployed Azure infrastructure.

## Prerequisites
- Terraform infrastructure deployed (dev or prod environment)
- GitHub repository with workflows
- GitHub CLI (`gh`) or access to GitHub Settings

## Step 1: Extract Infrastructure Outputs

After deploying your infrastructure, extract the outputs that your ML pipelines need.

### Get DEV Environment Outputs
```powershell
cd infrastructure/environments/dev
terraform output -json > dev-outputs.json
```

### Get PROD Environment Outputs
```powershell
cd infrastructure/environments/prod
terraform output -json > prod-outputs.json
```

### View Specific Outputs
```powershell
# View all outputs in readable format
terraform output

# Get specific values
terraform output -raw resource_group_name
terraform output -raw ml_workspace_name
terraform output -raw container_registry_login_server
terraform output -raw storage_account_name
terraform output -raw key_vault_name
terraform output -raw aks_cluster_name
```

## Step 2: Configure GitHub Secrets

Your pipelines need these secrets. Add them to GitHub repository settings:

### Required Secrets

**AZURE_CREDENTIALS** (Service Principal JSON):
```json
{
  "clientId": "<service-principal-client-id>",
  "clientSecret": "<service-principal-secret>",
  "subscriptionId": "b2b8a5e6-9a34-494b-ba62-fe9be95bd398",
  "tenantId": "<your-tenant-id>"
}
```

To create the service principal:
```powershell
# Create service principal
az ad sp create-for-rbac --name "github-actions-mlops" --role contributor --scopes /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398 --sdk-auth
```

### Using GitHub CLI
```powershell
# Set secrets using GitHub CLI
gh secret set AZURE_CREDENTIALS < azure-credentials.json
```

### Using GitHub Web UI
1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret

## Step 3: Configure GitHub Variables

Set these variables based on your Terraform outputs:

### DEV Environment Variables
```powershell
# Extract from Terraform outputs
cd infrastructure/environments/dev

$RG = terraform output -raw resource_group_name
$WS = terraform output -raw ml_workspace_name
$ACR = terraform output -raw container_registry_login_server
$SA = terraform output -raw storage_account_name
$KV = terraform output -raw key_vault_name
$AKS = terraform output -raw aks_cluster_name
$SUB = "b2b8a5e6-9a34-494b-ba62-fe9be95bd398"

# Set GitHub variables
gh variable set AZURE_RESOURCE_GROUP_DEV --body $RG
gh variable set AZURE_ML_WORKSPACE_DEV --body $WS
gh variable set AZURE_CONTAINER_REGISTRY_DEV --body $ACR
gh variable set AZURE_STORAGE_ACCOUNT_DEV --body $SA
gh variable set AZURE_KEY_VAULT_DEV --body $KV
gh variable set AZURE_AKS_CLUSTER_DEV --body $AKS
gh variable set AZURE_SUBSCRIPTION_ID --body $SUB
```

### PROD Environment Variables
```powershell
cd infrastructure/environments/prod

$RG = terraform output -raw resource_group_name
$WS = terraform output -raw ml_workspace_name
$ACR = terraform output -raw container_registry_login_server
$SA = terraform output -raw storage_account_name
$KV = terraform output -raw key_vault_name
$AKS = terraform output -raw aks_cluster_name

gh variable set AZURE_RESOURCE_GROUP_PROD --body $RG
gh variable set AZURE_ML_WORKSPACE_PROD --body $WS
gh variable set AZURE_CONTAINER_REGISTRY_PROD --body $ACR
gh variable set AZURE_STORAGE_ACCOUNT_PROD --body $SA
gh variable set AZURE_KEY_VAULT_PROD --body $KV
gh variable set AZURE_AKS_CLUSTER_PROD --body $AKS
```

## Step 4: Update Workflow Files to Use Variables

Your existing workflows can now reference these variables:

### Example: Using in Workflows
```yaml
jobs:
  train:
    runs-on: ubuntu-latest
    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Run ML Training
        run: |
          az ml job create \
            --workspace-name ${{ vars.AZURE_ML_WORKSPACE_DEV }} \
            --resource-group ${{ vars.AZURE_RESOURCE_GROUP_DEV }} \
            --subscription ${{ vars.AZURE_SUBSCRIPTION_ID }} \
            --file jobs/train-job.yml
```

### Example: Deploy to AKS
```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Get AKS credentials
        run: |
          az aks get-credentials \
            --resource-group ${{ vars.AZURE_RESOURCE_GROUP_PROD }} \
            --name ${{ vars.AZURE_AKS_CLUSTER_PROD }}
      
      - name: Deploy to AKS
        run: |
          kubectl apply -f kubernetes/ml-inference-deployment.yaml
```

## Step 5: Verify Integration

Test that your pipelines can access the infrastructure:

### Test Azure ML Workspace Access
```powershell
az ml workspace show \
  --name <workspace-name> \
  --resource-group <resource-group-name> \
  --subscription b2b8a5e6-9a34-494b-ba62-fe9be95bd398
```

### Test Container Registry Access
```powershell
az acr login --name <acr-name>
docker pull <acr-name>.azurecr.io/test:latest
```

### Test AKS Access
```powershell
az aks get-credentials \
  --resource-group <resource-group-name> \
  --name <aks-cluster-name>

kubectl get nodes
```

## Step 6: Update Existing Workflows

Your workflows need minimal changes. Just replace hardcoded values with variables:

### Before (Hardcoded):
```yaml
env:
  RESOURCE_GROUP: "rg-mlops-dev"
  WORKSPACE_NAME: "mlw-dev"
```

### After (Using Variables):
```yaml
env:
  RESOURCE_GROUP: ${{ vars.AZURE_RESOURCE_GROUP_DEV }}
  WORKSPACE_NAME: ${{ vars.AZURE_ML_WORKSPACE_DEV }}
```

## Infrastructure Resources Available

Based on your Terraform deployment, these resources are available:

### Networking
- Virtual Network: `<prefix>-vnet`
- Subnets: training, inference, private-endpoints
- Network Security Groups

### ML Workspace
- Azure ML Workspace
- Application Insights
- Log Analytics Workspace
- Key Vault (RBAC enabled)
- Storage Account (default datastore)

### Container Registry
- Azure Container Registry (Premium tier)
- Admin user enabled
- Geo-replication available in PROD

### Compute
- CPU Compute Cluster (auto-scaling)
- AKS Cluster (if enabled)

### Security & Identity
- User-assigned Managed Identity
- RBAC roles configured
- Private endpoints (in PROD)

### Cost Management
- Budget alerts
- Cost export automation
- Underutilization detection

## Common Workflow Patterns

### Pattern 1: Train Model in Dev
```yaml
name: Train Model
on: [push]
jobs:
  train:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - run: |
          az ml job create \
            --file jobs/train.yml \
            --workspace-name ${{ vars.AZURE_ML_WORKSPACE_DEV }} \
            --resource-group ${{ vars.AZURE_RESOURCE_GROUP_DEV }}
```

### Pattern 2: Deploy Model to Prod AKS
```yaml
name: Deploy to Production
on: 
  workflow_dispatch:
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - run: |
          az aks get-credentials \
            --name ${{ vars.AZURE_AKS_CLUSTER_PROD }} \
            --resource-group ${{ vars.AZURE_RESOURCE_GROUP_PROD }}
          kubectl apply -f kubernetes/
```

### Pattern 3: Build and Push Docker Image
```yaml
name: Build Docker Image
on: [push]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      - run: |
          az acr login --name ${{ vars.AZURE_CONTAINER_REGISTRY_DEV }}
          docker build -t ${{ vars.AZURE_CONTAINER_REGISTRY_DEV }}/myapp:${{ github.sha }} .
          docker push ${{ vars.AZURE_CONTAINER_REGISTRY_DEV }}/myapp:${{ github.sha }}
```

## Troubleshooting

### Issue: "Workspace not found"
**Solution:** Verify workspace name and resource group:
```powershell
az ml workspace list --resource-group <rg-name>
```

### Issue: "Access denied to Key Vault"
**Solution:** Add service principal to Key Vault access policies:
```powershell
az keyvault set-policy \
  --name <kv-name> \
  --spn <service-principal-client-id> \
  --secret-permissions get list
```

### Issue: "ACR authentication failed"
**Solution:** Verify ACR credentials:
```powershell
az acr credential show --name <acr-name>
```

### Issue: "AKS cluster not accessible"
**Solution:** Add service principal to AKS RBAC:
```powershell
az aks get-credentials --name <aks-name> --resource-group <rg-name> --admin
kubectl create clusterrolebinding github-actions --clusterrole=cluster-admin --user=<sp-client-id>
```

## Next Steps

1. ✅ Extract Terraform outputs
2. ✅ Configure GitHub secrets (AZURE_CREDENTIALS)
3. ✅ Configure GitHub variables (resource names)
4. ✅ Update workflow files to use variables
5. ✅ Test each workflow manually
6. ✅ Monitor costs and resource usage

## Reference

- [Terraform Outputs](infrastructure/environments/README.md)
- [GitHub Actions Variables](https://docs.github.com/en/actions/learn-github-actions/variables)
- [Azure ML CLI v2](https://learn.microsoft.com/en-us/azure/machine-learning/how-to-configure-cli)
- [AKS Integration](https://learn.microsoft.com/en-us/azure/aks/kubernetes-walkthrough)
