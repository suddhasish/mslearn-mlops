# Pipeline Setup Checklist

## ✅ Prerequisites (What You Already Have)

- [x] Terraform infrastructure deployed in DEV
  - Resource Group: `mlopsnew-dev-rg`
  - ML Workspace: `mlopsnew-dev-mlw`
  - Container Registry: `mlopsnewdevacr3kxldb`
  - AKS Cluster: `mlopsnew-dev-aks`
  - Storage Account: `mlopsnewdevst3kxldb`
  - Key Vault: `mlopsnew-dev-kv-3kxldb`

## 🔧 Required Configuration (One-Time Setup)

### 1. GitHub Secret: AZURE_CREDENTIALS

**Status**: ⚠️ REQUIRED - Must be configured

**What it is**: Service Principal credentials for GitHub Actions to authenticate with Azure

**How to create**:

```powershell
# Step 1: Create Service Principal
az ad sp create-for-rbac `
  --name "github-actions-mlops-cd" `
  --role contributor `
  --scopes /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398 `
  --sdk-auth > azure-credentials.json

# This will output JSON like:
# {
#   "clientId": "xxxxx",
#   "clientSecret": "xxxxx",
#   "subscriptionId": "b2b8a5e6-9a34-494b-ba62-fe9be95bd398",
#   "tenantId": "xxxxx",
#   "activeDirectoryEndpointUrl": "...",
#   ...
# }
```

**Step 2: Add to GitHub**:

Option A - Using GitHub CLI:
```powershell
gh secret set AZURE_CREDENTIALS < azure-credentials.json
```

Option B - Using GitHub Web UI:
1. Go to: https://github.com/suddhasish/mslearn-mlops/settings/secrets/actions
2. Click "New repository secret"
3. Name: `AZURE_CREDENTIALS`
4. Value: Paste the entire JSON output from Step 1
5. Click "Add secret"

**Step 3: Grant Service Principal Additional Permissions**:
```powershell
# Get the service principal client ID from the JSON
$SP_CLIENT_ID = "<client-id-from-json>"

# Grant ML Workspace access
az role assignment create `
  --assignee $SP_CLIENT_ID `
  --role "AzureML Data Scientist" `
  --scope /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg/providers/Microsoft.MachineLearningServices/workspaces/mlopsnew-dev-mlw

# Grant ACR push access (for building images)
az role assignment create `
  --assignee $SP_CLIENT_ID `
  --role "AcrPush" `
  --scope /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg/providers/Microsoft.ContainerRegistry/registries/mlopsnewdevacr3kxldb

# Grant Key Vault access
az role assignment create `
  --assignee $SP_CLIENT_ID `
  --role "Key Vault Secrets User" `
  --scope /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg/providers/Microsoft.KeyVault/vaults/mlopsnew-dev-kv-3kxldb
```

---

### 2. Test Endpoint Script

**Status**: ⚠️ REQUIRED - Must exist

**File**: `scripts/test_endpoint.py`

**Quick check**:
```powershell
Test-Path scripts/test_endpoint.py
```

If **False**, create the file:

```python
# scripts/test_endpoint.py
import argparse
import requests
import json
import sys

def test_endpoint(url, key):
    """Test ML endpoint with sample data"""
    
    # Sample test data for diabetes classifier
    test_data = {
        "data": [
            [1, 2, 3, 4, 5, 6, 7, 8, 9]  # Sample features
        ]
    }
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {key}"
    }
    
    try:
        print(f"Testing endpoint: {url}")
        response = requests.post(url, json=test_data, headers=headers, timeout=30)
        response.raise_for_status()
        
        result = response.json()
        print(f"✓ Test successful! Response: {result}")
        return 0
        
    except requests.exceptions.RequestException as e:
        print(f"✗ Test failed: {e}")
        return 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True, help="Endpoint URL")
    parser.add_argument("--key", required=True, help="Endpoint key")
    args = parser.parse_args()
    
    sys.exit(test_endpoint(args.url, args.key))
```

---

### 3. GitHub Production Environment

**Status**: ⚠️ REQUIRED for approval gate

**What it is**: Protected environment requiring manual approval before production deployment

**How to create**:

1. Go to: https://github.com/suddhasish/mslearn-mlops/settings/environments
2. Click "New environment"
3. Name: `production`
4. Click "Configure environment"
5. Enable "Required reviewers"
6. Add yourself (or team members) as reviewers
7. Click "Save protection rules"

**Why needed**: The CD workflow pauses at `await-production-approval` job and waits for manual approval before deploying to production.

---

### 4. Model Registration (First Time Only)

**Status**: ⚠️ REQUIRED before first deployment

**What it is**: You need at least one registered model in Azure ML Workspace

**How to register a model**:

Option A - Using Azure ML Studio:
1. Go to: https://ml.azure.com
2. Select workspace: `mlopsnew-dev-mlw`
3. Navigate to "Models"
4. Click "Register" → "From local files"
5. Upload your model file
6. Name: `diabetes-classifier`
7. Version will be auto-assigned (e.g., `1`)

Option B - Using Azure ML CLI:
```powershell
# First, train and save a model locally
# Then register it:

az ml model create `
  --name diabetes-classifier `
  --version 1 `
  --path ./model/diabetes_model.pkl `
  --type mlflow_model `
  --workspace-name mlopsnew-dev-mlw `
  --resource-group mlopsnew-dev-rg
```

Option C - Using Python SDK:
```python
from azure.ai.ml import MLClient
from azure.ai.ml.entities import Model
from azure.identity import DefaultAzureCredential

credential = DefaultAzureCredential()
ml_client = MLClient(
    credential=credential,
    subscription_id="b2b8a5e6-9a34-494b-ba62-fe9be95bd398",
    resource_group_name="mlopsnew-dev-rg",
    workspace_name="mlopsnew-dev-mlw"
)

model = Model(
    path="./model/diabetes_model.pkl",
    name="diabetes-classifier",
    description="Diabetes classification model"
)

ml_client.models.create_or_update(model)
```

---

## 🚀 Quick Validation

Run these commands to verify everything is ready:

```powershell
# 1. Check if GitHub secret exists
gh secret list | Select-String "AZURE_CREDENTIALS"

# 2. Check if test script exists
Test-Path scripts/test_endpoint.py

# 3. Verify Azure access
az login
az account set --subscription b2b8a5e6-9a34-494b-ba62-fe9be95bd398

# 4. Check ML Workspace access
az ml workspace show `
  --name mlopsnew-dev-mlw `
  --resource-group mlopsnew-dev-rg

# 5. List registered models
az ml model list `
  --workspace-name mlopsnew-dev-mlw `
  --resource-group mlopsnew-dev-rg

# 6. Check ACR access
az acr login --name mlopsnewdevacr3kxldb
```

---

## ✅ Pipeline Execution Steps

Once setup is complete:

### 1. Go to GitHub Actions
https://github.com/suddhasish/mslearn-mlops/actions/workflows/cd-deploy.yml

### 2. Click "Run workflow"

### 3. Fill in inputs:
- **Environment**: `dev`
- **Model name**: `diabetes-classifier` (or your model name)
- **Model version**: `1` (or your version)

### 4. Click "Run workflow" button

### 5. Pipeline will execute:
- ✅ Resolve infrastructure (automatic)
- ✅ Deploy to staging environment
- ✅ Test staging endpoint
- ✅ Prepare production (create GREEN deployment)
- ⏸️ Wait for approval (manual)
- ✅ Gradual rollout (10% → 50% → 100%)
- ✅ Post-deployment validation

---

## 🔍 Troubleshooting

### Issue: "AZURE_CREDENTIALS not found"
**Solution**: Complete Step 1 above

### Issue: "scripts/test_endpoint.py not found"
**Solution**: Create the file as shown in Step 2

### Issue: "Model 'diabetes-classifier' not found"
**Solution**: Register a model as shown in Step 4

### Issue: "Waiting for approval" never completes
**Solution**: Set up production environment as shown in Step 3

### Issue: "Unauthorized to access workspace"
**Solution**: Grant service principal permissions as shown in Step 1

### Issue: "Failed to push to ACR"
**Solution**: Grant AcrPush role to service principal

---

## 📊 What Happens After Setup

Once configured, the CD pipeline will:

1. **Automatically use your infrastructure** - No manual input needed
2. **Deploy to staging** - Create online endpoint in Azure ML
3. **Run tests** - Validate the deployment works
4. **Wait for approval** - You manually approve production deployment
5. **Blue/Green rollout** - Gradual traffic shift with automatic rollback
6. **Cost optimization** - Scale down old deployment after success

---

## 🎯 Next Steps After First Successful Deployment

1. ✅ Monitor costs in Azure Cost Management
2. ✅ Check Application Insights for metrics
3. ✅ Review Log Analytics for logs
4. ✅ Test the endpoint URLs
5. ✅ Deploy to PROD environment (when ready)

---

## 📚 Additional Resources

- [Full Integration Guide](INFRASTRUCTURE_INTEGRATION.md)
- [Resource Usage Map](RESOURCE_USAGE_MAP.md)
- [Quick Reference](QUICK_REFERENCE_INFRA.md)
- [CD Workflow](.github/workflows/cd-deploy.yml)
