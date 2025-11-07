# GitHub Secrets Configuration for MLOps Infrastructure

This document lists all the GitHub secrets required to run the infrastructure deployment workflow.

## Required Secrets

Configure these secrets in your GitHub repository:
**Settings** → **Secrets and variables** → **Actions** → **New repository secret**

### 1. Azure Authentication (Single JSON Secret)

#### `AZURE_CLIENT_SECRET`
Complete Azure service principal credentials in JSON format.

**Value to set:**
```json
{
  "clientId": "8d64d26f-e524-44e2-b3f1-3dc6e8ff8f51",
  "clientSecret": "ZtT8Q~~vj7JOF7Ez-Gz-OaiKEE1Ko3.aa~",
  "subscriptionId": "b2b8a5e6-9a34-494b-ba62-fe9be95bd398",
  "tenantId": "d1c04857-a0c2-4d18-90f3-3d6561f397c8"
}
```

**Important:** 
- Copy the entire JSON block above with the correct field names
- Note: `clientId` (not `appId`), `clientSecret` (not `password`), `tenantId` (not `tenant`)

### 2. Project Configuration

#### `PROJECT_NAME`
Name of your MLOps project (used for resource naming).

**Value:** `azureml`

#### `AZURE_LOCATION`
Azure region for deploying resources.

**Value:** `eastus`

### 3. Notifications

#### `NOTIFICATION_EMAIL`
Email address for budget alerts and cost notifications.

**Value:** `suddhasiishkar@gmail.com`

#### `SLACK_WEBHOOK_URL` (Optional - Currently Disabled)
Slack webhook URL for deployment notifications (currently commented out in workflow).

**Example value:** `https://hooks.slack.com/services/YOUR/WEBHOOK/URL`

---

## Backend Configuration

The Terraform remote backend is **pre-configured** in `infrastructure/backend.tf` with these values:

```hcl
resource_group_name  = "rg-tfstate-dev"
storage_account_name = "mlopstfstatesuddha"
container_name       = "tfstate"
key                  = "dev.mlops.tfstate"
subscription_id      = "b2b8a5e6-9a34-494b-ba62-fe9be95bd398"
```

**No additional backend secrets are required** - the backend config is committed to the repository.

---

## Service Principal Permissions

Ensure your service principal has the following permissions:

1. **Contributor** role on the subscription (for resource creation)
2. **Storage Blob Data Contributor** on storage account `mlopstfstatesuddha` (for remote state)

To grant storage access:
```powershell
# Grant access to the storage account using the service principal appId
az role assignment create `
  --role "Storage Blob Data Contributor" `
  --assignee 8d64d26f-e524-44e2-b3f1-3dc6e8ff8f51 `
  --scope "/subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/rg-tfstate-dev/providers/Microsoft.Storage/storageAccounts/mlopstfstatesuddha"
```

---

## Quick Setup Checklist

- [ ] Update `AZURE_CLIENT_SECRET` with complete JSON (including subscriptionId)
- [ ] Add `PROJECT_NAME` = `azureml`
- [ ] Add `AZURE_LOCATION` = `eastus`
- [ ] Add `NOTIFICATION_EMAIL` = `suddhasiishkar@gmail.com`
- [ ] Grant service principal **Storage Blob Data Contributor** access (run command above)
- [ ] Verify backend container `tfstate` exists in storage account `mlopstfstatesuddha`
- [ ] Commit and push changes to trigger workflow

---

## Summary - Required GitHub Secrets

| Secret Name | Value |
|-------------|-------|
| `AZURE_CLIENT_SECRET` | Full JSON with appId, password, tenant, subscriptionId |
| `PROJECT_NAME` | `azureml` |
| `AZURE_LOCATION` | `eastus` |
| `NOTIFICATION_EMAIL` | `suddhasiishkar@gmail.com` |

---

## Testing the Setup

Once secrets are configured, test the workflow:

```bash
# Trigger manual workflow dispatch
# Go to GitHub Actions → Infrastructure Deployment → Run workflow
# Select environment: dev
```

Or push changes to trigger automatic deployment:

```bash
git add .
git commit -m "Configure Terraform backend"
git push origin main
```

---

## Troubleshooting

### Authentication Errors
- Verify `AZURE_CREDENTIALS` JSON is valid and complete
- Check service principal hasn't expired
- Ensure subscription ID matches in both credentials and backend config

### Backend Access Errors
- Confirm storage account `mlopstfstatesuddha` exists
- Verify container `tfstate` exists
- Check service principal has Storage Blob Data Contributor role
- Ensure firewall rules on storage account allow GitHub Actions IP ranges (or set to "Allow all networks" for testing)

### Resource Creation Errors
- Verify service principal has Contributor role on subscription
- Check Azure quota limits for VM SKUs and other resources
- Review terraform plan output for specific errors
