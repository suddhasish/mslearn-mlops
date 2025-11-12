# Quick Start: ML Pipeline with DEV Infrastructure

## 🎯 Overview
This setup uses the **DEV infrastructure** deployed via Terraform for both staging and production endpoints. This is a cost-effective approach for testing the full MLOps pipeline.

## ✅ Prerequisites (Already Done)

- ✅ Terraform infrastructure deployed (mlopsnew-dev-*)
- ✅ GitHub repository configured
- ✅ Azure resources available:
  - Resource Group: `mlopsnew-dev-rg`
  - ML Workspace: `mlopsnew-dev-mlw`
  - Container Registry: `mlopsnewdevacr3kxldb`
  - AKS Cluster: `mlopsnew-dev-aks`
  - Key Vault: `mlopsnew-dev-kv-3kxldb`
  - Storage Account: `mlopsnewdevst3kxldb`

## 🔧 Required Setup (One-Time)

### Step 1: Create Service Principal

```bash
# Create service principal with contributor access
az ad sp create-for-rbac \
  --name "github-actions-mlops" \
  --role contributor \
  --scopes /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg \
  --sdk-auth > azure-credentials.json
```

**Save the output** - you'll need it for GitHub secrets.

### Step 2: Add GitHub Secret

```bash
# Using GitHub CLI
gh secret set AZURE_CREDENTIALS < azure-credentials.json

# Or manually:
# 1. Go to: https://github.com/YOUR_USERNAME/mslearn-mlops/settings/secrets/actions
# 2. Click "New repository secret"
# 3. Name: AZURE_CREDENTIALS
# 4. Value: Paste the entire JSON output from Step 1
```

### Step 3: Grant ML Workspace Access

```bash
# Get the service principal client ID from azure-credentials.json
SP_CLIENT_ID=$(cat azure-credentials.json | jq -r '.clientId')

# Grant AzureML Data Scientist role
az role assignment create \
  --assignee $SP_CLIENT_ID \
  --role "AzureML Data Scientist" \
  --scope /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg/providers/Microsoft.MachineLearningServices/workspaces/mlopsnew-dev-mlw

# Grant ACR Pull access (for container images)
az role assignment create \
  --assignee $SP_CLIENT_ID \
  --role "AcrPull" \
  --scope /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg/providers/Microsoft.ContainerRegistry/registries/mlopsnewdevacr3kxldb

# Grant Key Vault Secrets User (for retrieving secrets)
az role assignment create \
  --assignee $SP_CLIENT_ID \
  --role "Key Vault Secrets User" \
  --scope /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg/providers/Microsoft.KeyVault/vaults/mlopsnew-dev-kv-3kxldb
```

### Step 4: Verify Setup

```bash
# Test Azure CLI login with service principal
az login --service-principal \
  --username $(cat azure-credentials.json | jq -r '.clientId') \
  --password $(cat azure-credentials.json | jq -r '.clientSecret') \
  --tenant $(cat azure-credentials.json | jq -r '.tenantId')

# Verify ML workspace access
az ml workspace show \
  --name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg

# Verify ACR access
az acr login --name mlopsnewdevacr3kxldb
```

## 🚀 Running the CD Pipeline

### Option 1: Manual Trigger (GitHub UI)

1. Go to: https://github.com/YOUR_USERNAME/mslearn-mlops/actions
2. Select "CD - MLOps Blue/Green Deployment with Approval"
3. Click "Run workflow"
4. Fill in:
   - **Model name**: `diabetes-classifier`
   - **Model version**: `latest` (or specific version like `1`, `2`)
5. Click "Run workflow"

### Option 2: Using GitHub CLI

```bash
gh workflow run cd-deploy.yml \
  -f model_name=diabetes-classifier \
  -f model_version=latest
```

## 📊 Pipeline Flow

The CD pipeline creates two endpoints in the **same DEV workspace**:

### 1. **Staging Endpoint** (`ml-endpoint-staging`)
- Purpose: Initial testing and validation
- Deployment: `staging-deployment`
- Traffic: 100% to staging deployment
- Tests: Runs automated endpoint tests

### 2. **Production Endpoint** (`ml-endpoint-production`)
- Purpose: Blue/Green deployment with gradual rollout
- Deployments:
  - `blue-deployment`: Currently serving production traffic
  - `green-deployment`: New version being validated
- Traffic shift: 0% → 10% → 50% → 100% (with validation at each step)
- Rollback: Automatic if any validation fails

## 🔍 Monitoring the Deployment

### View Endpoints in Azure Portal

```bash
# Open Azure ML Studio
az ml workspace show \
  --name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg \
  --query workspaceId -o tsv | \
  xargs -I {} echo "https://ml.azure.com/workspaces/{}"
```

Navigate to: **Endpoints** → **Real-time endpoints**

### Check Endpoint Status via CLI

```bash
# List all endpoints
az ml online-endpoint list \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg

# Get staging endpoint details
az ml online-endpoint show \
  --name ml-endpoint-staging \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg

# Get production endpoint traffic distribution
az ml online-endpoint show \
  --name ml-endpoint-production \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg \
  --query traffic
```

## 🧪 Testing Deployed Endpoints

### Get Endpoint Details

```bash
# Get staging endpoint URL and key
STAGING_URL=$(az ml online-endpoint show \
  --name ml-endpoint-staging \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg \
  --query scoring_uri -o tsv)

STAGING_KEY=$(az ml online-endpoint get-credentials \
  --name ml-endpoint-staging \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg \
  --query primaryKey -o tsv)

# Get production endpoint URL and key
PROD_URL=$(az ml online-endpoint show \
  --name ml-endpoint-production \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg \
  --query scoring_uri -o tsv)

PROD_KEY=$(az ml online-endpoint get-credentials \
  --name ml-endpoint-production \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg \
  --query primaryKey -o tsv)
```

### Test Endpoint

```bash
# Test staging endpoint
curl -X POST "$STAGING_URL" \
  -H "Authorization: Bearer $STAGING_KEY" \
  -H "Content-Type: application/json" \
  -d '{"data": [[1,2,3,4,5,6,7,8]]}'

# Test production endpoint
curl -X POST "$PROD_URL" \
  -H "Authorization: Bearer $PROD_KEY" \
  -H "Content-Type: application/json" \
  -d '{"data": [[1,2,3,4,5,6,7,8]]}'
```

## 🎭 Understanding Blue/Green Deployment

### Initial State (First Deployment)
```
Production Endpoint (ml-endpoint-production)
├── Blue Deployment: Model v1 (100% traffic) ✓
└── Green Deployment: Model v2 (0% traffic)
```

### After Approval - Gradual Rollout
```
Phase 1: Blue 90% | Green 10%  → Test → Pass ✓
Phase 2: Blue 50% | Green 50%  → Test → Pass ✓
Phase 3: Blue 0%  | Green 100% → Test → Pass ✓
```

### Final State
```
Production Endpoint (ml-endpoint-production)
├── Blue Deployment: Scaled to 0 (kept for rollback)
└── Green Deployment: Model v2 (100% traffic) ✓
```

## 💰 Cost Management

### Current Configuration (DEV)
- **Staging**: 1x Standard_DS2_v2 (only during deployment)
- **Production Blue**: 2x Standard_DS3_v2 → scaled to 0 after successful rollout
- **Production Green**: 1x Standard_DS3_v2 → scaled to 2 after successful rollout

### Cost Optimization Tips
1. Delete endpoints when not testing:
   ```bash
   az ml online-endpoint delete --name ml-endpoint-staging --workspace-name mlopsnew-dev-mlw --resource-group mlopsnew-dev-rg --yes
   az ml online-endpoint delete --name ml-endpoint-production --workspace-name mlopsnew-dev-mlw --resource-group mlopsnew-dev-rg --yes
   ```

2. Monitor costs in Azure Cost Management:
   ```bash
   # View in portal
   az portal dashboard show --name mlopsnew-dev-budget
   ```

## 🔧 Troubleshooting

### Issue: GitHub Actions can't access Azure

**Solution**: Verify service principal has correct permissions
```bash
# Check role assignments
az role assignment list \
  --assignee $SP_CLIENT_ID \
  --scope /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg
```

### Issue: Endpoint deployment fails

**Solution**: Check quota and logs
```bash
# Check regional quota
az ml compute list-usage \
  --location eastus \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg

# Get deployment logs
az ml online-deployment get-logs \
  --name staging-deployment \
  --endpoint-name ml-endpoint-staging \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg
```

### Issue: Model not found

**Solution**: Register model first
```bash
# List available models
az ml model list \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg

# Register a model
az ml model create \
  --name diabetes-classifier \
  --version 1 \
  --path models/ \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg
```

## 📚 Next Steps

1. ✅ **Train a model** - Use the training pipeline to create models
2. ✅ **Deploy to staging** - Run CD pipeline to test in staging
3. ✅ **Approve production** - Review and approve for production rollout
4. ✅ **Monitor performance** - Check Application Insights (mlopsnew-dev-ai)
5. ✅ **Iterate** - Deploy new model versions

## 📖 Additional Resources

- [Full Integration Guide](INFRASTRUCTURE_INTEGRATION.md)
- [Resource Usage Map](RESOURCE_USAGE_MAP.md)
- [Pipeline Setup Checklist](PIPELINE_SETUP_CHECKLIST.md)
- [Azure ML Documentation](https://learn.microsoft.com/en-us/azure/machine-learning/)

---

**Note**: This setup uses DEV infrastructure for both staging and production. For actual production workloads, deploy separate production infrastructure using `terraform apply` in `infrastructure/environments/prod/`.
