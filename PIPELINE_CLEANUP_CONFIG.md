# Pipeline Cleanup & Destroy Configuration

**Date**: November 11, 2025  
**Purpose**: Automatic cleanup of unwanted resources + full infrastructure destroy capability

---

## ✅ What Was Added

### 1. **Automatic Cleanup Steps**
Added automatic cleanup steps to the GitHub Actions pipeline (`infrastructure-deploy.yml`) that will **automatically delete unintentional resources** after each Terraform deployment.

### 2. **Full Infrastructure Destroy**
Added dedicated destroy jobs for both dev and prod environments that allow complete infrastructure teardown via GitHub Actions UI.

### **New Steps Added:**

1. **Cleanup Unwanted Resources** - Added to both `terraform-apply-dev` and `terraform-apply-prod` jobs
2. Runs immediately after `terraform apply` completes successfully
3. Uses `continue-on-error: true` so pipeline won't fail if resources don't exist

---

## 🗑️ Resources That Will Be Deleted

The cleanup step automatically removes:

### **DevOps Integration Components**
(From when `enable_devops_integration = true` was previously set)
- ❌ Event Grid Topic (`azureml-{env}-events`)
- ❌ Event Hubs Namespace (`azureml-{env}-eventhub-*`)
- ❌ Stream Analytics Job (`azureml-{env}-stream-analytics`)

### **Data Factory Resources**
(From when `enable_data_factory = true` was set in pipeline)
- ❌ Data Factory - Cost Analytics (`azureml-{env}-df-cost`)
- ❌ Data Factory - DevOps (`azureml-{env}-df-devops`)

### **Identity Management**
(From when `enable_cicd_identity = true` was previously set)
- ❌ User Assigned Managed Identity (`azureml-{env}-ml-identity`)

---

## 🔧 How It Works

### **Step 1: Terraform Apply**
```yaml
- name: Terraform Apply
  run: terraform apply -auto-approve tfplan-dev
```
Terraform creates/updates infrastructure based on current configuration.

### **Step 2: Automatic Cleanup**
```yaml
- name: Cleanup Unwanted Resources
  run: |
    # Safely delete resources that shouldn't exist
    delete_resource "azureml-dev-events" "Microsoft.EventGrid/topics"
    delete_resource "azureml-dev-df-cost" "Microsoft.DataFactory/factories"
    # ... etc
  continue-on-error: true
```

### **Step 3: Resource Detection**
- Checks if each resource exists before attempting deletion
- Uses `az resource show` to verify existence
- Only deletes if resource is found
- Logs whether resource was deleted or already gone

### **Step 4: Safe Execution**
- `continue-on-error: true` ensures pipeline continues even if cleanup fails
- Verbose logging shows exactly what was deleted
- Non-blocking: Won't stop your deployment

---

## 📊 Cleanup Logic

```bash
delete_resource() {
  resource_name=$1
  resource_type=$2
  resource_id="/subscriptions/$SUB/resourceGroups/$RG/providers/$resource_type/$resource_name"
  
  if az resource show --ids "$resource_id" &>/dev/null; then
    echo "🗑️  Deleting $resource_name..."
    az resource delete --ids "$resource_id"
  else
    echo "✅ $resource_name does not exist (already cleaned)"
  fi
}
```

---

## 🎯 When Cleanup Runs

### **Development Environment:**
- Runs after every successful deployment to `dev`
- Triggered by: `workflow_dispatch` with `environment=dev`

### **Production Environment:**
- Runs after every successful deployment to `prod`
- Triggered by: 
  - Push to `main` branch
  - `workflow_dispatch` with `environment=prod`

---

## 💡 Example Output

```
🧹 Cleaning up unintentional resources from previous deployments...
Resource Group: azureml-dev-rg
Subscription: 12345678-1234-1234-1234-123456789abc

🗑️  Deleting azureml-dev-events...
Successfully deleted resource: azureml-dev-events

🗑️  Deleting azureml-dev-eventhub-gsnytv...
Successfully deleted resource: azureml-dev-eventhub-gsnytv

✅ azureml-dev-stream-analytics does not exist (already cleaned)

🗑️  Deleting azureml-dev-df-cost...
Successfully deleted resource: azureml-dev-df-cost

🗑️  Deleting azureml-dev-df-devops...
Successfully deleted resource: azureml-dev-df-devops

✅ azureml-dev-ml-identity does not exist (already cleaned)

✅ Cleanup completed!
```

---

## ⚠️ Important Notes

### **What Gets Cleaned:**
- ✅ Resources from previous deployments with different configurations
- ✅ Resources that shouldn't exist based on current feature flags
- ✅ Resources not managed by current Terraform state

### **What Does NOT Get Cleaned:**
- ❌ Resources managed by Terraform (Terraform handles these)
- ❌ Core infrastructure (Storage, Key Vault, ML Workspace, etc.)
- ❌ Resources from different resource groups
- ❌ Automation Account (intentional with `enable_cost_alerts=true`)

### **Safety Features:**
- ✅ Checks existence before deletion
- ✅ Non-blocking (uses `continue-on-error: true`)
- ✅ Verbose logging for audit trail
- ✅ Only deletes specific known resources (not bulk deletion)
- ✅ Scoped to specific resource group

---

## 🚀 Next Deployment

The cleanup will run automatically on your next deployment:

### **Option 1: Trigger Dev Deployment**
```bash
# Via GitHub Actions UI:
# 1. Go to Actions tab
# 2. Select "Infrastructure Deployment"
# 3. Click "Run workflow"
# 4. Select "dev" environment
# 5. Keep "Destroy infrastructure" unchecked
```

### **Option 2: Push to Deployment Branch**
```bash
git add .github/workflows/infrastructure-deploy.yml
git commit -m "feat: add automatic cleanup of unwanted resources"
git push origin deployment-pipeline
```

The cleanup step will run and remove:
- Event Grid Topic
- Event Hubs Namespace
- Stream Analytics Job
- Both Data Factories
- Managed Identity

---

## 🔍 Verification

After the pipeline completes, verify cleanup:

### **Method 1: Pipeline Logs**
Check the "Cleanup Unwanted Resources" step in GitHub Actions output.

### **Method 2: Azure Portal**
```
1. Go to https://portal.azure.com
2. Navigate to resource group: azureml-dev-rg
3. Confirm unwanted resources are gone
```

### **Method 3: Azure CLI**
```bash
az resource list \
  --resource-group azureml-dev-rg \
  --query "[?type=='Microsoft.EventGrid/topics' || type=='Microsoft.EventHub/namespaces' || type=='Microsoft.StreamAnalytics/streamingjobs' || type=='Microsoft.DataFactory/factories'].{Name:name, Type:type}" \
  --output table
```

Should return empty (no results).

---

## 🎯 Expected Result

**Before Cleanup:**
```
24 resources in resource group
- Including: Event Grid, Event Hub, Stream Analytics, 2x Data Factory, Managed Identity
```

**After Cleanup:**
```
18 resources in resource group (expected for dev-edge-learning profile)
- Core ML infrastructure only
- Monitoring and alerts
- Networking components
- No DevOps integration or Data Factory resources
```

---

## 📝 Maintenance

### **To Add More Resources to Cleanup:**
Edit the cleanup step in `infrastructure-deploy.yml`:

```yaml
# Add new resource deletion
delete_resource "resource-name" "Microsoft.Provider/resourceType"
```

### **To Remove Cleanup:**
Simply delete or comment out the "Cleanup Unwanted Resources" step.

### **To Test Locally:**
```bash
# Set variables
export RG_NAME="azureml-dev-rg"
export SUBSCRIPTION_ID="your-sub-id"

# Test deletion
az resource delete \
  --ids "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.EventGrid/topics/azureml-dev-events"
```

---

## ✅ Summary

| Feature | Status |
|---------|--------|
| **Automatic Cleanup** | ✅ Enabled |
| **Dev Environment** | ✅ Configured |
| **Prod Environment** | ✅ Configured |
| **Safe Execution** | ✅ Non-blocking |
| **Audit Logging** | ✅ Verbose output |
| **Resource Detection** | ✅ Checks before delete |

The pipeline will now automatically clean up unwanted resources after every deployment, keeping your infrastructure aligned with your configuration files.

---

## 🗑️ Full Infrastructure Destroy

### **New Destroy Jobs Added:**

#### **1. terraform-destroy-dev**
- Completely destroys all dev environment infrastructure
- Requires manual trigger via `workflow_dispatch`
- Protected by GitHub environment: `dev-destroy`

#### **2. terraform-destroy-prod**
- Completely destroys all production infrastructure
- Requires manual trigger via `workflow_dispatch`
- Protected by GitHub environment: `production-destroy`

---

## 🚀 How to Destroy Infrastructure

### **Method 1: GitHub Actions UI (Recommended)**

1. Go to your repository on GitHub
2. Click **Actions** tab
3. Select **Infrastructure Deployment** workflow
4. Click **Run workflow** button
5. Configure:
   - **Branch**: `deployment-pipeline` (or `main`)
   - **Environment to deploy**: Select `dev` or `prod`
   - **Destroy infrastructure**: ✅ **Check this box**
6. Click **Run workflow**

### **Method 2: GitHub CLI**

```bash
# Destroy dev environment
gh workflow run infrastructure-deploy.yml \
  -f environment=dev \
  -f destroy=true

# Destroy prod environment
gh workflow run infrastructure-deploy.yml \
  -f environment=prod \
  -f destroy=true
```

### **Method 3: REST API**

```bash
curl -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/repos/{owner}/{repo}/actions/workflows/infrastructure-deploy.yml/dispatches \
  -d '{"ref":"deployment-pipeline","inputs":{"environment":"dev","destroy":"true"}}'
```

---

## ⚠️ Destroy Process Details

### **What Happens When You Destroy:**

1. **Validation** - Terraform configuration validated
2. **Init** - Terraform connects to Azure backend
3. **Destroy** - Runs `terraform destroy -auto-approve`
4. **Summary** - Creates destruction report in job summary

### **Resources That Will Be Destroyed:**

#### **Core Infrastructure:**
- ❌ Azure Machine Learning Workspace
- ❌ Storage Account (including all blobs, datasets, models)
- ❌ Container Registry (including all images)
- ❌ Key Vault (with purge protection depending on config)
- ❌ Virtual Network + all subnets
- ❌ Log Analytics Workspace
- ❌ Application Insights

#### **Compute Resources:**
- ❌ AKS Cluster (if enabled)
- ❌ ML Compute Clusters (CPU/GPU)

#### **Monitoring & Alerts:**
- ❌ All metric alerts
- ❌ All log alerts
- ❌ Action groups
- ❌ Workbooks

#### **Optional Services** (if enabled):
- ❌ API Management
- ❌ Azure Front Door
- ❌ Traffic Manager
- ❌ Redis Cache
- ❌ Event Grid
- ❌ Event Hubs
- ❌ Stream Analytics
- ❌ Data Factories
- ❌ Automation Accounts

### **What Is Preserved:**

- ✅ GitHub repository and code
- ✅ GitHub Actions workflow history
- ✅ GitHub secrets
- ✅ Terraform state file in Azure Storage (backend)
  - State shows resources as destroyed
  - Can be used to recreate identical infrastructure

---

## 🔒 Safety Features

### **1. Environment Protection**
Destroy jobs use separate GitHub environments:
- `dev-destroy` - For development
- `production-destroy` - For production

**Recommended Protection Rules:**
```yaml
# Settings > Environments > dev-destroy
- Required reviewers: 1 person
- Wait timer: 0 minutes

# Settings > Environments > production-destroy
- Required reviewers: 2 people
- Wait timer: 5 minutes
- Restrict to branches: main only
```

### **2. Manual Trigger Only**
Destroy only runs when:
- ✅ `workflow_dispatch` event (manual)
- ✅ `destroy` input is explicitly set to `true`
- ✅ Environment matches destroy job

**Never triggered by:**
- ❌ Push to branches
- ❌ Pull requests
- ❌ Scheduled runs

### **3. Explicit Confirmation Required**
User must:
1. Navigate to Actions tab
2. Select workflow
3. Click "Run workflow"
4. Check "Destroy infrastructure" box
5. Click "Run workflow" again

### **4. Audit Trail**
- ✅ GitHub Actions logs all destroy operations
- ✅ Job summary shows who destroyed and when
- ✅ Azure Activity Log records all resource deletions
- ✅ Terraform state preserved in backend

---

## 📊 Example Destroy Output

```
🗑️ Infrastructure Destroyed - Development

All infrastructure resources in the dev environment have been destroyed.

Destroyed by: @your-username
Timestamp: Mon Nov 11 15:30:45 UTC 2025

Terraform Destroy Summary:
- 38 resources destroyed
- 0 errors
- Duration: 8m 32s

Resources Destroyed:
✅ Resource Group: azureml-dev-rg
✅ ML Workspace: azureml-dev-mlw
✅ Storage Account: azuremldevst34jt8b
✅ Container Registry: azuremldevacr34jt8b
✅ Key Vault: azureml-dev-kv-34jt8b
✅ AKS Cluster: azureml-dev-aks
✅ Virtual Network: azureml-dev-vnet
... (32 more resources)
```

---

## 🔄 Recreating Infrastructure After Destroy

### **Full Recreation:**
```bash
# Via GitHub Actions
# 1. Actions > Infrastructure Deployment > Run workflow
# 2. Select environment: dev
# 3. Destroy infrastructure: UNCHECKED
# 4. Run workflow
```

### **Terraform State:**
After destroy, the Terraform state file shows:
```
Resources: 0 total, 0 added, 0 changed, 38 destroyed
```

To recreate identical infrastructure:
```bash
cd infrastructure
terraform init
terraform apply -var-file=terraform.tfvars.dev-edge-learning
```

All resources will be recreated with same configuration (new random suffixes may apply).

---

## 🎯 Use Cases for Destroy

### **When to Use Destroy:**

1. **Development Testing**
   - Test infrastructure-as-code changes
   - Verify clean deployment from scratch
   - Reset environment to known state

2. **Cost Optimization**
   - Destroy dev environment overnight/weekends
   - Recreate when needed
   - Minimize Azure spend

3. **Project Completion**
   - Clean up after demo/POC
   - Remove all resources when project ends
   - Ensure no lingering costs

4. **Environment Refresh**
   - Remove corrupted/misconfigured resources
   - Start fresh with updated configuration
   - Clean slate for troubleshooting

### **When NOT to Use Destroy:**

1. ❌ **Production with live data** - Permanent data loss
2. ❌ **During active ML training** - Jobs will fail
3. ❌ **Before backing up models** - Cannot recover deployed models
4. ❌ **When purge protection enabled** - Key Vault requires 90-day recovery

---

## ⚙️ Destroy Job Configuration

### **Dev Destroy Job:**
```yaml
terraform-destroy-dev:
  name: Destroy - Development
  needs: terraform-validate
  runs-on: ubuntu-latest
  if: github.event_name == 'workflow_dispatch' && 
      github.event.inputs.environment == 'dev' && 
      github.event.inputs.destroy == 'true'
  environment:
    name: dev-destroy
    url: https://portal.azure.com
```

### **Prod Destroy Job:**
```yaml
terraform-destroy-prod:
  name: Destroy - Production
  needs: terraform-validate
  runs-on: ubuntu-latest
  if: github.event_name == 'workflow_dispatch' && 
      github.event.inputs.environment == 'prod' && 
      github.event.inputs.destroy == 'true'
  environment:
    name: production-destroy
    url: https://portal.azure.com
```

---

## 🛡️ Setting Up Environment Protection

### **Step 1: Create Environments**

```bash
# In GitHub repository settings
Settings > Environments > New environment

Create:
1. dev-destroy
2. production-destroy
```

### **Step 2: Configure Protection Rules**

**For dev-destroy:**
```
✅ Required reviewers: Select 1 team member
✅ Wait timer: 0 minutes
✅ Deployment branches: All branches
```

**For production-destroy:**
```
✅ Required reviewers: Select 2 team members
✅ Wait timer: 5 minutes (cooling-off period)
✅ Deployment branches: main only
✅ Prevent self-review: Enabled
```

### **Step 3: Test Destroy Process**

```bash
# Test dev destroy
1. Run workflow with destroy=true for dev
2. Verify approval required
3. Approve and monitor destruction
4. Check Azure Portal - resource group should be gone

# Test recreation
5. Run workflow with destroy=false for dev
6. Verify infrastructure recreated
```

---

## 📝 Destroy Checklist

### **Before Destroying:**

- [ ] Backup any critical data/models
- [ ] Export ML experiment results
- [ ] Download container images (if needed)
- [ ] Document deployed model versions
- [ ] Notify team members
- [ ] Verify correct environment selected
- [ ] Check no active ML jobs running

### **After Destroying:**

- [ ] Verify resource group deleted in Azure Portal
- [ ] Check Terraform state shows 0 resources
- [ ] Review Azure Activity Log for deletions
- [ ] Update documentation
- [ ] Notify stakeholders

---

## ✅ Summary

| Feature | Dev | Prod | Notes |
|---------|-----|------|-------|
| **Destroy Job** | ✅ | ✅ | Manual trigger only |
| **Environment Protection** | Optional | Recommended | Approval required |
| **Wait Timer** | 0 min | 5 min | Cooling-off period |
| **Audit Trail** | ✅ | ✅ | GitHub + Azure logs |
| **State Preserved** | ✅ | ✅ | In Azure backend |
| **Recreate Possible** | ✅ | ✅ | Same configuration |

The pipeline now supports both **automatic cleanup** of unwanted resources and **full infrastructure destruction** on demand, giving you complete control over your Azure resources! 🎯

