# Quick Reference: Using Terraform Infrastructure in Workflows

## 🚀 Quick Setup (3 Steps)

### 1. Extract Infrastructure Details
```powershell
# From repository root
cd infrastructure/environments/dev
terraform output
```

### 2. Run Setup Script
```powershell
# From repository root
.\scripts\setup-github-secrets.ps1 -Environment both
```

### 3. Verify in GitHub
Go to: `https://github.com/YOUR_USERNAME/mslearn-mlops/settings/variables/actions`

---

## 📋 Available Variables

After running the setup script, these variables are available in your workflows:

### DEV Environment
| Variable | Description | Example Value |
|----------|-------------|---------------|
| `AZURE_RESOURCE_GROUP_DEV` | Resource group name | `myproject-dev-rg` |
| `AZURE_ML_WORKSPACE_DEV` | ML Workspace name | `myproject-dev-mlw` |
| `AZURE_CONTAINER_REGISTRY_DEV` | ACR login server | `myprojectdevacr.azurecr.io` |
| `AZURE_STORAGE_ACCOUNT_DEV` | Storage account name | `myprojectdevsa` |
| `AZURE_KEY_VAULT_DEV` | Key Vault name | `myproject-dev-kv` |
| `AZURE_AKS_CLUSTER_DEV` | AKS cluster name | `myproject-dev-aks` |

### PROD Environment
| Variable | Description | Example Value |
|----------|-------------|---------------|
| `AZURE_RESOURCE_GROUP_PROD` | Resource group name | `myproject-prod-rg` |
| `AZURE_ML_WORKSPACE_PROD` | ML Workspace name | `myproject-prod-mlw` |
| `AZURE_CONTAINER_REGISTRY_PROD` | ACR login server | `myprojectprodacr.azurecr.io` |
| `AZURE_STORAGE_ACCOUNT_PROD` | Storage account name | `myprojectprodsa` |
| `AZURE_KEY_VAULT_PROD` | Key Vault name | `myproject-prod-kv` |
| `AZURE_AKS_CLUSTER_PROD` | AKS cluster name | `myproject-prod-aks` |

### Common
| Variable | Description | Example Value |
|----------|-------------|---------------|
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `b2b8a5e6-9a34-...` |

---

## 🔐 Required Secret

**AZURE_CREDENTIALS** - Service principal with contributor access

### Create Service Principal
```powershell
az ad sp create-for-rbac \
  --name "github-actions-mlops" \
  --role contributor \
  --scopes /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398 \
  --sdk-auth > azure-credentials.json
```

### Add to GitHub
```powershell
gh secret set AZURE_CREDENTIALS < azure-credentials.json
```

---

## 💡 Usage Examples in Workflows

### Train Model in DEV
```yaml
- name: Run Training Job
  run: |
    az ml job create \
      --file jobs/train-job.yml \
      --workspace-name ${{ vars.AZURE_ML_WORKSPACE_DEV }} \
      --resource-group ${{ vars.AZURE_RESOURCE_GROUP_DEV }} \
      --subscription ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

### Deploy to AKS (PROD)
```yaml
- name: Deploy to Production AKS
  run: |
    az aks get-credentials \
      --name ${{ vars.AZURE_AKS_CLUSTER_PROD }} \
      --resource-group ${{ vars.AZURE_RESOURCE_GROUP_PROD }}
    kubectl apply -f kubernetes/deployment.yaml
```

### Push Docker Image
```yaml
- name: Build and Push Image
  run: |
    az acr login --name ${{ vars.AZURE_CONTAINER_REGISTRY_DEV }}
    docker build -t ${{ vars.AZURE_CONTAINER_REGISTRY_DEV }}/myapp:${{ github.sha }} .
    docker push ${{ vars.AZURE_CONTAINER_REGISTRY_DEV }}/myapp:${{ github.sha }}
```

### Access Key Vault
```yaml
- name: Get Secret from Key Vault
  run: |
    SECRET=$(az keyvault secret show \
      --vault-name ${{ vars.AZURE_KEY_VAULT_DEV }} \
      --name my-secret \
      --query value -o tsv)
    echo "::add-mask::$SECRET"
```

---

## 🔄 Update After Infrastructure Changes

If you redeploy or change Terraform infrastructure:

```powershell
# Re-run the setup script
.\scripts\setup-github-secrets.ps1 -Environment both
```

---

## ✅ Validation Commands

### Test Azure ML Access
```powershell
az ml workspace show \
  --name $(gh variable get AZURE_ML_WORKSPACE_DEV) \
  --resource-group $(gh variable get AZURE_RESOURCE_GROUP_DEV)
```

### Test ACR Access
```powershell
az acr login --name $(gh variable get AZURE_CONTAINER_REGISTRY_DEV)
```

### Test AKS Access
```powershell
az aks get-credentials \
  --name $(gh variable get AZURE_AKS_CLUSTER_DEV) \
  --resource-group $(gh variable get AZURE_RESOURCE_GROUP_DEV)
kubectl get nodes
```

---

## 🔧 Troubleshooting

### Variables not showing up
```powershell
# List all variables
gh variable list

# Set manually if needed
gh variable set AZURE_ML_WORKSPACE_DEV --body "your-workspace-name"
```

### Authentication failures
```powershell
# Verify service principal
az ad sp list --display-name "github-actions-mlops"

# Test login
az login --service-principal \
  --username <client-id> \
  --password <client-secret> \
  --tenant <tenant-id>
```

### Can't find Terraform outputs
```powershell
# Check state file exists
cd infrastructure/environments/dev
Test-Path terraform.tfstate

# Re-initialize if needed
terraform init
terraform refresh
```

---

## 📚 Related Documentation

- [Full Integration Guide](INFRASTRUCTURE_INTEGRATION.md)
- [Terraform Environments](infrastructure/environments/README.md)
- [GitHub Actions Workflows](.github/workflows/)

---

## 🎯 Next Steps After Setup

1. ✅ Verify all variables in GitHub settings
2. ✅ Test authentication with a simple workflow
3. ✅ Update existing workflows to use variables instead of hardcoded values
4. ✅ Test each workflow (train, deploy, etc.)
5. ✅ Monitor costs in Azure Cost Management
