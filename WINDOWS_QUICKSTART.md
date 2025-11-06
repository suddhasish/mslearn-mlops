# Windows Quick Start Guide - MLOps Infrastructure

## 🚀 Complete Setup in 3 Commands

### Option 1: Fully Automated (Recommended)
```powershell
# Open PowerShell as Administrator
cd d:\MLOPS\MLOPS-AZURE\mslearn-mlops\deployment
.\setup-windows.ps1 -Environment dev
```

### Option 2: Interactive Menu
```powershell
cd d:\MLOPS\MLOPS-AZURE\mslearn-mlops\deployment
.\deploy-infrastructure.ps1
# Select option 8 for full deployment
```

## 📋 Prerequisites

### Required (Installed Automatically)
The `setup-windows.ps1` script will automatically install:
- ✅ Chocolatey (Package Manager)
- ✅ Terraform >= 1.6.0
- ✅ Azure CLI >= 2.50.0
- ✅ Git
- ✅ jq (JSON processor)

### Manual Prerequisites
- ✅ Windows 10/11 or Windows Server 2019+
- ✅ PowerShell 7+ ([Download](https://github.com/PowerShell/PowerShell/releases))
- ✅ Administrator access
- ✅ Azure subscription

## 🎯 Step-by-Step Guide

### Step 1: Open PowerShell as Administrator

**Method 1 - Start Menu:**
1. Press `Win + X`
2. Select "Windows PowerShell (Admin)" or "Terminal (Admin)"

**Method 2 - Search:**
1. Press `Win` key
2. Type "PowerShell"
3. Right-click "Windows PowerShell 7"
4. Select "Run as Administrator"

### Step 2: Navigate to Project Directory

```powershell
cd d:\MLOPS\MLOPS-AZURE\mslearn-mlops\deployment
```

### Step 3: Run Setup Script

```powershell
# For Development Environment
.\setup-windows.ps1 -Environment dev

# For Production Environment
.\setup-windows.ps1 -Environment prod
```

### Step 4: Follow the Prompts

The script will ask you for:

1. **Terraform State Storage**
   ```
   Resource Group: mlops-terraform-state-rg (press Enter for default)
   Storage Account: mlopstfstate1234 (press Enter for default)
   Location: eastus2 (press Enter for default)
   ```

2. **Project Configuration**
   ```
   Project Name: mlops-demo (press Enter for default)
   Azure Location: eastus2 (press Enter for default)
   Notification Email: your-email@company.com
   Slack Webhook: (optional, press Enter to skip)
   ```

3. **Deployment Confirmation**
   ```
   Do you want to apply this plan? (yes/no): yes
   ```

### Step 5: Wait for Deployment

⏱️ **Expected Time:**
- Development: ~15-20 minutes
- Production: ~25-30 minutes

You'll see progress updates like:
```
[INFO] Creating resource group...
[SUCCESS] Resource group created
[INFO] Deploying ML Workspace...
[INFO] Deploying AKS Cluster...
[SUCCESS] Infrastructure deployed successfully! 🎉
```

## 📊 What Gets Deployed

### Development Environment
- Azure ML Workspace
- AKS Cluster (2 nodes, scales to 5)
- Storage Account (100GB)
- Container Registry
- Key Vault
- Application Insights
- Log Analytics
- Virtual Network with 3 subnets
- Network Security Groups
- **Estimated Cost: $525/month**

### Production Environment  
- Azure ML Workspace
- AKS Cluster (3 nodes, scales to 10)
- Storage Account (500GB)
- Container Registry
- Key Vault with Purge Protection
- Application Insights
- Log Analytics (90-day retention)
- Virtual Network with Private Endpoints
- Network Security Groups
- Front Door + API Management
- Cost Management Alerts
- **Estimated Cost: $875/month**

## 🔧 Alternative Commands

### Just Check Prerequisites
```powershell
.\setup-windows.ps1 -SkipPrerequisites
```

### Use Existing Backend
```powershell
.\deploy-infrastructure.ps1
# Select individual options from menu
```

### Deploy Only (Skip Setup)
```powershell
cd ..\infrastructure
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## 📝 Post-Deployment Steps

### 1. Verify Deployment

```powershell
# Check deployment summary
cat .\DEPLOYMENT_SUMMARY_dev.md

# Or view JSON outputs
cat .\terraform-outputs-dev.json
```

### 2. Configure GitHub Secrets

Navigate to your GitHub repository and add these secrets:

```
Settings → Secrets and variables → Actions → New repository secret
```

**Required Secrets:**

| Secret Name | Value | How to Get |
|-------------|-------|------------|
| `AZURE_CREDENTIALS` | Service Principal JSON | See below ⬇️ |
| `TF_STATE_RESOURCE_GROUP` | `mlops-terraform-state-rg` | From setup |
| `TF_STATE_STORAGE_ACCOUNT` | `mlopstfstate1234` | From setup |
| `PROJECT_NAME` | `mlops-demo` | Your project name |
| `AZURE_LOCATION` | `eastus2` | Your location |
| `NOTIFICATION_EMAIL` | `your-email@company.com` | Your email |

**Get AZURE_CREDENTIALS:**

```powershell
# Get subscription ID
$subscriptionId = az account show --query id -o tsv

# Create service principal
$sp = az ad sp create-for-rbac `
  --name "mlops-github-actions" `
  --role Contributor `
  --scopes "/subscriptions/$subscriptionId" `
  --sdk-auth

# Copy the output JSON and paste as AZURE_CREDENTIALS secret
Write-Output $sp
```

**Optional Secrets:**
- `SLACK_WEBHOOK_URL`: Your Slack webhook for notifications
- `AZURE_CREDENTIALS_PROD`: Production service principal (for prod deployments)

### 3. Test the Setup

```powershell
# Login to Azure ML
az extension add -n ml --upgrade
az ml workspace show `
  --name (jq -r '.ml_workspace_name.value' .\terraform-outputs-dev.json) `
  --resource-group (jq -r '.resource_group_name.value' .\terraform-outputs-dev.json)

# Submit a test training job
cd ..\src
az ml job create --file job.yml
```

### 4. View in Azure Portal

```powershell
# Open ML Workspace in browser
$workspaceId = jq -r '.ml_workspace_id.value' ..\deployment\terraform-outputs-dev.json
Start-Process "https://portal.azure.com/#@/resource$workspaceId"

# Or open ML Studio directly
Start-Process "https://ml.azure.com"
```

## 🐛 Troubleshooting

### Issue: "Cannot be loaded because running scripts is disabled"

**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: "Chocolatey not found after installation"

**Solution:**
```powershell
# Close and reopen PowerShell as Administrator
# Or manually refresh environment
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

### Issue: "Az login fails"

**Solution:**
```powershell
# Use device code flow
az login --use-device-code

# Or use service principal
az login --service-principal `
  --username <app-id> `
  --password <password> `
  --tenant <tenant-id>
```

### Issue: "Terraform plan fails with quota limits"

**Solution:**
```powershell
# Check your quotas
az vm list-usage --location eastus2 --output table

# Request quota increase
# Go to: https://portal.azure.com → Subscriptions → Usage + quotas
```

### Issue: "Deployment takes too long"

**Solution:**
```powershell
# For dev environment, reduce resources in terraform.tfvars:
aks_node_count = 1
aks_max_nodes = 3
enable_data_factory = false
```

### Issue: "Cost concerns"

**Solution:**
```powershell
# Check estimated costs before deployment
cd ..\infrastructure
terraform plan -out=tfplan
terraform show tfplan | Select-String "will be created"

# Scale down after hours (optional automation script)
.\scripts\scale-down-resources.ps1
```

## 🔐 Security Best Practices

### 1. Secure Your terraform.tfvars
```powershell
# Never commit terraform.tfvars to Git
echo "*.tfvars" >> ..\.gitignore
```

### 2. Use Managed Identities
```powershell
# Your infrastructure is configured with managed identities by default
# No need to store credentials in code
```

### 3. Enable Private Endpoints (Production)
```powershell
# Already enabled for prod environment
# For dev, set in terraform.tfvars:
enable_private_endpoints = true
```

### 4. Rotate Service Principal Secrets
```powershell
# Every 90 days, rotate the GitHub Actions secret
az ad sp credential reset --id <app-id>
# Update AZURE_CREDENTIALS in GitHub
```

## 📈 Monitoring Your Deployment

### View Logs
```powershell
# Application Insights
$aiName = jq -r '.application_insights_name.value' .\terraform-outputs-dev.json
Start-Process "https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/*/providers/microsoft.insights/components/$aiName"

# AKS Logs
az aks get-credentials `
  --resource-group (jq -r '.resource_group_name.value' .\terraform-outputs-dev.json) `
  --name (jq -r '.aks_cluster_name.value' .\terraform-outputs-dev.json)

kubectl get pods --all-namespaces
```

### Cost Analysis
```powershell
# View current costs
az consumption usage list --start-date (Get-Date).AddDays(-30).ToString("yyyy-MM-dd") --output table

# Set up budget alerts (already configured via Terraform)
```

## 🎓 Next Steps

### 1. Run Your First ML Job
```powershell
cd ..\src
az ml job create --file job.yml --stream
```

### 2. Try Hyperparameter Tuning
```powershell
az ml job create --file hyperparameter_sweep.yml
```

### 3. Deploy a Model
```powershell
# After training, deploy to staging
az ml online-endpoint create --file deployment/endpoint-staging.yml
az ml online-deployment create --file deployment/deployment-staging.yml
```

### 4. Setup CI/CD
See [GitHub Actions Setup](./GITHUB_ACTIONS_SETUP.md)

## 💡 Tips for Windows Users

### Use Windows Terminal
- Modern, tabbed terminal experience
- Better rendering and performance
- [Download](https://aka.ms/terminal)

### PowerShell vs Command Prompt
- Always use **PowerShell 7+**, not Command Prompt
- PowerShell has better Azure integration

### WSL2 Alternative
If you prefer Linux commands:
```powershell
# Install WSL2
wsl --install

# Use Linux scripts
wsl
cd /mnt/d/MLOPS/MLOPS-AZURE/mslearn-mlops/deployment
./deploy-infrastructure.sh --auto
```

### VS Code Integration
```powershell
# Open project in VS Code
code d:\MLOPS\MLOPS-AZURE\mslearn-mlops

# Use integrated terminal (Ctrl + `)
```

## 📞 Getting Help

### Check Logs
```powershell
# Terraform logs
Get-Content ..\infrastructure\terraform.log

# Azure CLI logs
$env:AZURE_CLI_DIAGNOSTICS = "yes"
az <command>
```

### Community Support
- GitHub Issues: Create an issue with `[Windows]` tag
- Stack Overflow: Tag with `azure-mlops` + `windows`
- Azure Forums: [Microsoft Q&A](https://docs.microsoft.com/en-us/answers/topics/azure-machine-learning.html)

## ✅ Verification Checklist

After deployment, verify:

- [ ] All resources visible in Azure Portal
- [ ] ML Workspace accessible at ml.azure.com
- [ ] AKS cluster running (`kubectl get nodes`)
- [ ] Storage account accessible
- [ ] Application Insights receiving data
- [ ] GitHub secrets configured
- [ ] First training job completes successfully
- [ ] Cost alerts configured and working

---

**Ready to Deploy? Run this now:**

```powershell
cd d:\MLOPS\MLOPS-AZURE\mslearn-mlops\deployment
.\setup-windows.ps1 -Environment dev
```

🎉 **You'll have a production-ready MLOps platform in 20 minutes!**