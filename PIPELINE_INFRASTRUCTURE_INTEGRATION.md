# Pipeline-Infrastructure Integration Guide

## Overview
This guide explains how to link your GitHub Actions pipelines with the Terraform-provisioned infrastructure.

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Infrastructure Pipeline                       │
│  (.github/workflows/infrastructure-deploy.yml)                   │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              Terraform Provisions Resources                      │
│  • Azure ML Workspace                                            │
│  • AKS Cluster                                                   │
│  • Container Registry (ACR)                                      │
│  • Storage Account                                               │
│  • Key Vault                                                     │
│  • Application Insights                                          │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              Export Terraform Outputs                            │
│  • Store in GitHub Secrets/Variables                             │
│  • Or retrieve dynamically via Azure CLI                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  ML/CD Pipelines Use Resources                   │
│  • Training (02-manual-trigger-job.yml)                          │
│  • Hyperparameter Tuning (scheduled-hyper-tune.yml)              │
│  • Model Deployment (cd-deploy.yml)                              │
└─────────────────────────────────────────────────────────────────┘
```

## Step 1: Extract Terraform Outputs After Infrastructure Deployment

### Option A: Manual Extraction (One-time Setup)

After your infrastructure is deployed, run these commands:

#### For DEV Environment:
```bash
cd infrastructure/environments/dev
terraform output -json > outputs.json

# Extract values
$RESOURCE_GROUP = terraform output -raw resource_group_name
$ML_WORKSPACE = terraform output -raw ml_workspace_name
$AKS_CLUSTER = terraform output -raw aks_cluster_name
$ACR_NAME = terraform output -raw container_registry_name
$STORAGE_ACCOUNT = terraform output -raw storage_account_name
$KEY_VAULT = terraform output -raw key_vault_name
$APP_INSIGHTS = terraform output -raw application_insights_name
$SUBSCRIPTION_ID = "b2b8a5e6-9a34-494b-ba62-fe9be95bd398"

# Display summary
echo "DEV Environment Resources:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  ML Workspace: $ML_WORKSPACE"
echo "  AKS Cluster: $AKS_CLUSTER"
echo "  ACR: $ACR_NAME"
```

#### For PROD Environment:
```bash
cd infrastructure/environments/prod
terraform output -json > outputs.json

# Extract values
$RESOURCE_GROUP_PROD = terraform output -raw resource_group_name
$ML_WORKSPACE_PROD = terraform output -raw ml_workspace_name
$AKS_CLUSTER_PROD = terraform output -raw aks_cluster_name
$ACR_NAME_PROD = terraform output -raw container_registry_name
```

### Option B: Automated Extraction in GitHub Actions

Add this job to your `infrastructure-deploy.yml`:

```yaml
  export-outputs:
    needs: [dev-apply]  # or prod-apply
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_wrapper: false
        
    - name: Extract Dev Outputs
      id: dev_outputs
      working-directory: ./infrastructure/environments/dev
      run: |
        terraform init
        echo "resource_group=$(terraform output -raw resource_group_name)" >> $GITHUB_OUTPUT
        echo "ml_workspace=$(terraform output -raw ml_workspace_name)" >> $GITHUB_OUTPUT
        echo "aks_cluster=$(terraform output -raw aks_cluster_name)" >> $GITHUB_OUTPUT
        echo "acr_name=$(terraform output -raw container_registry_name)" >> $GITHUB_OUTPUT
        echo "acr_login_server=$(terraform output -raw container_registry_login_server)" >> $GITHUB_OUTPUT
        echo "storage_account=$(terraform output -raw storage_account_name)" >> $GITHUB_OUTPUT
        echo "key_vault=$(terraform output -raw key_vault_name)" >> $GITHUB_OUTPUT
        
    - name: Update GitHub Variables
      env:
        GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      run: |
        # Set repository variables for ML pipelines to use
        gh variable set DEV_RESOURCE_GROUP --body "${{ steps.dev_outputs.outputs.resource_group }}"
        gh variable set DEV_ML_WORKSPACE --body "${{ steps.dev_outputs.outputs.ml_workspace }}"
        gh variable set DEV_AKS_CLUSTER --body "${{ steps.dev_outputs.outputs.aks_cluster }}"
        gh variable set DEV_ACR_NAME --body "${{ steps.dev_outputs.outputs.acr_name }}"
        gh variable set DEV_ACR_LOGIN_SERVER --body "${{ steps.dev_outputs.outputs.acr_login_server }}"
        gh variable set DEV_STORAGE_ACCOUNT --body "${{ steps.dev_outputs.outputs.storage_account }}"
        gh variable set DEV_KEY_VAULT --body "${{ steps.dev_outputs.outputs.key_vault }}"
        gh variable set AZURE_SUBSCRIPTION_ID --body "b2b8a5e6-9a34-494b-ba62-fe9be95bd398"
```

## Step 2: Configure GitHub Secrets and Variables

### Required Secrets (Already configured):
- `AZURE_CREDENTIALS` - Service principal credentials for Azure authentication
- `PROJECT_NAME` - Project identifier
- `LOCATION` - Azure region
- `NOTIFICATION_EMAIL` - For alerts

### Add Infrastructure-Specific Variables:

Go to: **GitHub Repo → Settings → Secrets and variables → Actions → Variables**

#### DEV Environment Variables:
```
DEV_RESOURCE_GROUP=<from terraform output>
DEV_ML_WORKSPACE=<from terraform output>
DEV_AKS_CLUSTER=<from terraform output>
DEV_ACR_NAME=<from terraform output>
DEV_ACR_LOGIN_SERVER=<from terraform output>
DEV_STORAGE_ACCOUNT=<from terraform output>
DEV_KEY_VAULT=<from terraform output>
```

#### PROD Environment Variables:
```
PROD_RESOURCE_GROUP=<from terraform output>
PROD_ML_WORKSPACE=<from terraform output>
PROD_AKS_CLUSTER=<from terraform output>
PROD_ACR_NAME=<from terraform output>
PROD_ACR_LOGIN_SERVER=<from terraform output>
PROD_STORAGE_ACCOUNT=<from terraform output>
PROD_KEY_VAULT=<from terraform output>
```

#### Shared Variables:
```
AZURE_SUBSCRIPTION_ID=b2b8a5e6-9a34-494b-ba62-fe9be95bd398
AZURE_REGION=eastus
```

## Step 3: Update ML Training Pipeline

Update `.github/workflows/02-manual-trigger-job.yml`:

```yaml
env:
  # Use GitHub variables populated from Terraform outputs
  AZURE_ML_WORKSPACE: ${{ vars.DEV_ML_WORKSPACE }}
  AZURE_RESOURCE_GROUP: ${{ vars.DEV_RESOURCE_GROUP }}
  AZURE_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
  STORAGE_ACCOUNT: ${{ vars.DEV_STORAGE_ACCOUNT }}

jobs:
  train:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Verify Infrastructure
      run: |
        echo "Verifying ML Workspace exists..."
        az ml workspace show \
          --name $AZURE_ML_WORKSPACE \
          --resource-group $AZURE_RESOURCE_GROUP \
          --subscription $AZURE_SUBSCRIPTION_ID
          
    - name: Upload data to storage
      run: |
        az storage blob upload-batch \
          --account-name $STORAGE_ACCOUNT \
          --destination data \
          --source ./production/data \
          --auth-mode login
    
    - name: Submit training job
      run: |
        az ml job create \
          --file src/job.yml \
          --workspace-name $AZURE_ML_WORKSPACE \
          --resource-group $AZURE_RESOURCE_GROUP \
          --subscription $AZURE_SUBSCRIPTION_ID \
          --set experiment_name=diabetes-training-pipeline \
          --stream
```

## Step 4: Update CD Deployment Pipeline

Update `.github/workflows/cd-deploy.yml`:

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - dev
          - prod
      model_name:
        description: 'Model name to deploy'
        required: true
        default: 'diabetes-model'

jobs:
  resolve-infrastructure:
    runs-on: ubuntu-latest
    outputs:
      resource_group: ${{ steps.resolve.outputs.resource_group }}
      ml_workspace: ${{ steps.resolve.outputs.ml_workspace }}
      aks_cluster: ${{ steps.resolve.outputs.aks_cluster }}
      acr_name: ${{ steps.resolve.outputs.acr_name }}
      subscription_id: ${{ steps.resolve.outputs.subscription_id }}
    steps:
    - name: Resolve infrastructure for environment
      id: resolve
      run: |
        if [ "${{ github.event.inputs.environment }}" = "prod" ]; then
          echo "resource_group=${{ vars.PROD_RESOURCE_GROUP }}" >> $GITHUB_OUTPUT
          echo "ml_workspace=${{ vars.PROD_ML_WORKSPACE }}" >> $GITHUB_OUTPUT
          echo "aks_cluster=${{ vars.PROD_AKS_CLUSTER }}" >> $GITHUB_OUTPUT
          echo "acr_name=${{ vars.PROD_ACR_NAME }}" >> $GITHUB_OUTPUT
        else
          echo "resource_group=${{ vars.DEV_RESOURCE_GROUP }}" >> $GITHUB_OUTPUT
          echo "ml_workspace=${{ vars.DEV_ML_WORKSPACE }}" >> $GITHUB_OUTPUT
          echo "aks_cluster=${{ vars.DEV_AKS_CLUSTER }}" >> $GITHUB_OUTPUT
          echo "acr_name=${{ vars.DEV_ACR_NAME }}" >> $GITHUB_OUTPUT
        fi
        echo "subscription_id=${{ vars.AZURE_SUBSCRIPTION_ID }}" >> $GITHUB_OUTPUT

  deploy:
    needs: resolve-infrastructure
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Deploy to AKS
      run: |
        # Get AKS credentials
        az aks get-credentials \
          --name ${{ needs.resolve-infrastructure.outputs.aks_cluster }} \
          --resource-group ${{ needs.resolve-infrastructure.outputs.resource_group }} \
          --subscription ${{ needs.resolve-infrastructure.outputs.subscription_id }}
        
        # Deploy to Kubernetes
        kubectl apply -f kubernetes/ml-inference-deployment.yaml
```

## Step 5: Create Reusable Infrastructure Configuration

Create `.github/actions/setup-azure-ml/action.yml`:

```yaml
name: 'Setup Azure ML Context'
description: 'Configure Azure ML workspace context from Terraform outputs'
inputs:
  environment:
    description: 'Target environment (dev/prod)'
    required: true
    default: 'dev'
outputs:
  resource_group:
    description: 'Resource group name'
    value: ${{ steps.config.outputs.resource_group }}
  ml_workspace:
    description: 'ML workspace name'
    value: ${{ steps.config.outputs.ml_workspace }}
  aks_cluster:
    description: 'AKS cluster name'
    value: ${{ steps.config.outputs.aks_cluster }}
  subscription_id:
    description: 'Azure subscription ID'
    value: ${{ steps.config.outputs.subscription_id }}
runs:
  using: "composite"
  steps:
    - name: Load infrastructure config
      id: config
      shell: bash
      run: |
        if [ "${{ inputs.environment }}" = "prod" ]; then
          echo "resource_group=${{ vars.PROD_RESOURCE_GROUP }}" >> $GITHUB_OUTPUT
          echo "ml_workspace=${{ vars.PROD_ML_WORKSPACE }}" >> $GITHUB_OUTPUT
          echo "aks_cluster=${{ vars.PROD_AKS_CLUSTER }}" >> $GITHUB_OUTPUT
        else
          echo "resource_group=${{ vars.DEV_RESOURCE_GROUP }}" >> $GITHUB_OUTPUT
          echo "ml_workspace=${{ vars.DEV_ML_WORKSPACE }}" >> $GITHUB_OUTPUT
          echo "aks_cluster=${{ vars.DEV_AKS_CLUSTER }}" >> $GITHUB_OUTPUT
        fi
        echo "subscription_id=${{ vars.AZURE_SUBSCRIPTION_ID }}" >> $GITHUB_OUTPUT
    
    - name: Verify Azure ML workspace
      shell: bash
      run: |
        az ml workspace show \
          --name ${{ steps.config.outputs.ml_workspace }} \
          --resource-group ${{ steps.config.outputs.resource_group }} \
          --subscription ${{ steps.config.outputs.subscription_id }}
```

Then use it in your workflows:

```yaml
jobs:
  my-job:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Setup Azure ML
      id: azure_ml
      uses: ./.github/actions/setup-azure-ml
      with:
        environment: dev
    
    - name: Use infrastructure
      run: |
        echo "Deploying to: ${{ steps.azure_ml.outputs.ml_workspace }}"
```

## Step 6: Verification Checklist

After setting up the integration:

- [ ] Run `terraform output` in both dev and prod environments
- [ ] Verify all GitHub variables are set correctly
- [ ] Test Azure CLI authentication with `AZURE_CREDENTIALS` secret
- [ ] Run a simple ML job to verify workspace connectivity
- [ ] Test AKS deployment with a sample model
- [ ] Verify ACR access for container image push/pull
- [ ] Check Application Insights for monitoring data
- [ ] Confirm cost alerts are configured in Azure

## Step 7: Troubleshooting

### Common Issues:

1. **"Workspace not found"**
   ```bash
   # Verify workspace exists
   az ml workspace show --name <workspace> --resource-group <rg>
   ```

2. **"Authentication failed"**
   ```bash
   # Test service principal
   az login --service-principal \
     --username <client-id> \
     --password <client-secret> \
     --tenant <tenant-id>
   ```

3. **"AKS cluster not accessible"**
   ```bash
   # Verify RBAC permissions
   az aks get-credentials --name <cluster> --resource-group <rg>
   kubectl get nodes
   ```

4. **"ACR access denied"**
   ```bash
   # Check AKS to ACR role assignment
   az aks check-acr --name <cluster> --resource-group <rg> --acr <acr-name>
   ```

## Next Steps

1. **Set up monitoring**: Configure Application Insights for pipeline telemetry
2. **Enable A/B testing**: Use AKS multiple deployments for model comparison
3. **Implement drift detection**: Schedule regular model performance checks
4. **Cost optimization**: Use Azure Cost Management alerts (already configured in Terraform)
5. **Security hardening**: Enable Key Vault integration for secrets management

## Additional Resources

- [Azure ML CLI v2 Reference](https://learn.microsoft.com/en-us/cli/azure/ml)
- [GitHub Actions for Azure](https://github.com/marketplace?type=actions&query=azure)
- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
