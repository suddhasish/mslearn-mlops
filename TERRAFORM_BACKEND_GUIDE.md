# 🗄️ Terraform Remote Backend Configuration Guide

## Overview

This project uses **Azure Storage** as a remote backend for Terraform state management. Remote state provides:

- ✅ **State Locking**: Prevents concurrent modifications
- ✅ **Team Collaboration**: Shared state across team members
- ✅ **Security**: Encrypted state storage with versioning
- ✅ **Disaster Recovery**: Automatic backups and point-in-time restore

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│             GitHub Actions Workflow                     │
│  ┌──────────────┐         ┌──────────────┐            │
│  │  Dev Branch  │         │ Main Branch  │            │
│  │  (develop)   │         │ (production) │            │
│  └──────┬───────┘         └──────┬───────┘            │
│         │                        │                     │
│         ▼                        ▼                     │
│  ┌────────────────────────────────────────┐           │
│  │     Terraform Plan/Apply               │           │
│  └────────────────┬───────────────────────┘           │
└───────────────────┼───────────────────────────────────┘
                    │
                    ▼
    ┌───────────────────────────────────────────┐
    │     Azure Storage Backend                 │
    │  ┌─────────────┐    ┌─────────────┐      │
    │  │ dev.tfstate │    │prod.tfstate │      │
    │  │  (5MB)      │    │  (5MB)      │      │
    │  └─────────────┘    └─────────────┘      │
    │                                           │
    │  Features:                                │
    │  • Blob versioning enabled                │
    │  • Encryption at rest                     │
    │  • HTTPS only                             │
    │  • Resource lock (CanNotDelete)           │
    └───────────────────────────────────────────┘
```

---

## 🚀 Quick Setup

### Option 1: Automated Setup (Recommended)

**For Windows (PowerShell):**
```powershell
cd deployment
.\setup-terraform-backend.ps1 -Environment "both" -Location "eastus"
```

**For Linux/macOS (Bash):**
```bash
cd deployment
chmod +x setup-terraform-backend.sh
./setup-terraform-backend.sh both eastus mlops
```

**Parameters:**
- `Environment`: `dev`, `prod`, or `both`
- `Location`: Azure region (e.g., `eastus`, `westus2`, `westeurope`)
- `Prefix`: Resource naming prefix (default: `mlops`)

---

### Option 2: Manual Setup

#### Step 1: Create Resource Group
```bash
az group create \
  --name mlops-tfstate-dev-rg \
  --location eastus
```

#### Step 2: Create Storage Account
```bash
az storage account create \
  --resource-group mlops-tfstate-dev-rg \
  --name mlopstfstatedevXXXXX \
  --location eastus \
  --sku Standard_LRS \
  --encryption-services blob \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false
```
*Replace XXXXX with a unique 5-character string*

#### Step 3: Enable Versioning
```bash
az storage account blob-service-properties update \
  --account-name mlopstfstatedevXXXXX \
  --resource-group mlops-tfstate-dev-rg \
  --enable-versioning true
```

#### Step 4: Create Container
```bash
az storage container create \
  --name tfstate \
  --account-name mlopstfstatedevXXXXX \
  --account-key $(az storage account keys list \
    --resource-group mlops-tfstate-dev-rg \
    --account-name mlopstfstatedevXXXXX \
    --query '[0].value' -o tsv)
```

#### Step 5: Add Resource Lock
```bash
az lock create \
  --name terraform-state-lock \
  --resource-group mlops-tfstate-dev-rg \
  --lock-type CanNotDelete \
  --notes "Prevent accidental deletion of Terraform state"
```

---

## 🔐 GitHub Secrets Configuration

Add these secrets to your GitHub repository:  
**Settings → Secrets and variables → Actions → New repository secret**

### Required Secrets (Development)
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `TF_STATE_RESOURCE_GROUP` | Dev backend resource group | `mlops-tfstate-dev-rg` |
| `TF_STATE_STORAGE_ACCOUNT` | Dev storage account | `mlopstfstatedevabcde` |
| `AZURE_CREDENTIALS` | Dev service principal JSON | `{"clientId":"...","clientSecret":"..."}` |

### Required Secrets (Production)
| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `TF_STATE_RESOURCE_GROUP_PROD` | Prod backend resource group | `mlops-tfstate-prod-rg` |
| `TF_STATE_STORAGE_ACCOUNT_PROD` | Prod storage account | `mlopstfstateprodabcde` |
| `AZURE_CREDENTIALS_PROD` | Prod service principal JSON | `{"clientId":"...","clientSecret":"..."}` |

### Optional Secrets
| Secret Name | Description |
|-------------|-------------|
| `PROJECT_NAME` | Project identifier |
| `AZURE_LOCATION` | Azure region |
| `NOTIFICATION_EMAIL` | Alert email address |
| `SLACK_WEBHOOK_URL` | Slack notifications webhook |

---

## 📝 Local Development Setup

### 1. Copy Backend Template
```bash
cd infrastructure
cp backend.tf.example backend.tf
```

### 2. Edit backend.tf
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "mlops-tfstate-dev-rg"
    storage_account_name = "mlopstfstatedevabcde"
    container_name       = "tfstate"
    key                  = "dev.tfstate"
  }
}
```

### 3. Initialize Terraform
```bash
terraform init
```

Expected output:
```
Initializing the backend...

Successfully configured the backend "azurerm"!

Terraform has been successfully initialized!
```

### 4. Verify State Storage
```bash
terraform state list
```

---

## 🔄 GitHub Actions Workflow

The workflow automatically configures the backend for each environment:

### Development (on push to `develop`)
```yaml
- name: Setup Terraform Backend
  run: |
    cat > backend.tf << EOF
    terraform {
      backend "azurerm" {
        resource_group_name  = "${{ secrets.TF_STATE_RESOURCE_GROUP }}"
        storage_account_name = "${{ secrets.TF_STATE_STORAGE_ACCOUNT }}"
        container_name       = "tfstate"
        key                  = "dev.tfstate"
      }
    }
    EOF
```

### Production (on push to `main`)
```yaml
- name: Setup Terraform Backend
  run: |
    cat > backend.tf << EOF
    terraform {
      backend "azurerm" {
        resource_group_name  = "${{ secrets.TF_STATE_RESOURCE_GROUP_PROD }}"
        storage_account_name = "${{ secrets.TF_STATE_STORAGE_ACCOUNT_PROD }}"
        container_name       = "tfstate"
        key                  = "prod.tfstate"
      }
    }
    EOF
```

---

## 🛡️ Security Best Practices

### 1. State File Encryption
- ✅ Encryption at rest enabled by default
- ✅ TLS 1.2+ enforced for data in transit
- ✅ No public blob access allowed

### 2. Access Control
```bash
# Restrict access to specific IP ranges
az storage account network-rule add \
  --resource-group mlops-tfstate-dev-rg \
  --account-name mlopstfstatedevabcde \
  --ip-address YOUR_IP_ADDRESS
```

### 3. Audit Logging
```bash
# Enable diagnostic logs
az monitor diagnostic-settings create \
  --resource $(az storage account show \
    --name mlopstfstatedevabcde \
    --resource-group mlops-tfstate-dev-rg \
    --query id -o tsv) \
  --name "tfstate-audit-logs" \
  --logs '[{"category": "StorageRead", "enabled": true},
          {"category": "StorageWrite", "enabled": true}]' \
  --workspace YOUR_LOG_ANALYTICS_WORKSPACE_ID
```

### 4. Versioning & Soft Delete
```bash
# Enable soft delete (90-day retention)
az storage account blob-service-properties update \
  --account-name mlopstfstatedevabcde \
  --resource-group mlops-tfstate-dev-rg \
  --enable-delete-retention true \
  --delete-retention-days 90
```

---

## 🔧 Troubleshooting

### Issue: "Backend initialization required"
```bash
# Solution: Re-initialize backend
terraform init -reconfigure
```

### Issue: "Error acquiring state lock"
```bash
# Check lock info
az storage blob show \
  --account-name mlopstfstatedevabcde \
  --container-name tfstate \
  --name dev.tfstate \
  --query metadata

# Force unlock (use with caution!)
terraform force-unlock LOCK_ID
```

### Issue: "Storage account not found"
```bash
# Verify storage account exists
az storage account show \
  --name mlopstfstatedevabcde \
  --resource-group mlops-tfstate-dev-rg
```

### Issue: "403 Forbidden" during terraform init
```bash
# Verify Azure CLI login
az account show

# Re-login if needed
az login

# Check storage account permissions
az role assignment list \
  --assignee $(az account show --query user.name -o tsv) \
  --scope $(az storage account show \
    --name mlopstfstatedevabcde \
    --resource-group mlops-tfstate-dev-rg \
    --query id -o tsv)
```

---

## 🗑️ State Management Commands

### View State
```bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show azurerm_resource_group.mlops
```

### Move Resources
```bash
# Rename resource in state
terraform state mv \
  azurerm_storage_account.old_name \
  azurerm_storage_account.new_name
```

### Remove Resources
```bash
# Remove from state without destroying
terraform state rm azurerm_resource_group.example
```

### Pull State Locally
```bash
# Download current state
terraform state pull > backup.tfstate

# View state in JSON
terraform state pull | jq '.'
```

### Restore State
```bash
# Push state back (use with extreme caution!)
terraform state push backup.tfstate
```

---

## 💰 Cost Estimation

| Resource | SKU | Monthly Cost |
|----------|-----|--------------|
| Storage Account | Standard LRS | ~$0.02/GB |
| State File Storage | ~5MB typical | < $0.01 |
| Blob Versioning | Historical versions | ~$0.01 |
| Egress Traffic | Minimal | < $0.01 |
| **Total** | | **< $0.05/month** ✅ |

*State storage is essentially free for typical MLOps workloads*

---

## 📚 Additional Resources

- [Terraform Azure Backend Docs](https://www.terraform.io/docs/language/settings/backends/azurerm.html)
- [Azure Storage Security](https://docs.microsoft.com/azure/storage/common/storage-security-guide)
- [State Locking](https://www.terraform.io/docs/language/state/locking.html)
- [Terraform Workspaces](https://www.terraform.io/docs/language/state/workspaces.html)

---

## ✅ Verification Checklist

After setup, verify:

- [ ] Storage account created in Azure Portal
- [ ] `tfstate` container exists
- [ ] Blob versioning enabled
- [ ] Resource lock applied
- [ ] GitHub secrets configured
- [ ] `terraform init` succeeds locally
- [ ] GitHub Actions workflow runs successfully
- [ ] State file appears in Azure Storage after first apply

---

**Status:** ✅ Remote backend fully configured and ready for production use!
