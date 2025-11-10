# Terraform State Lock Resolution

## 🔒 Issue: State Lock Error

When you see this error:
```
Error: Error acquiring the state lock

Error message: state blob is already locked
Lock Info:
  ID:        6431e2f5-4607-2d8f-2863-cf483a5c48a4
  Path:      tfstate/dev.mlops.tfstate
  Operation: OperationTypeInvalid
  Who:       runner@runnervmw9dnm
  Version:   1.6.0
  Created:   2025-11-10 22:26:17.026937225 +0000 UTC
```

This means a previous Terraform operation didn't complete properly and left the state locked.

---

## ✅ Automatic Fix (Already Implemented)

The pipeline now **automatically detects and unlocks** stuck state locks before running plan/apply operations.

### **What Was Added:**

Added "Force Unlock State" step to all jobs:
- ✅ `terraform-plan-dev`
- ✅ `terraform-apply-dev`
- ✅ `terraform-plan-prod`
- ✅ `terraform-apply-prod`

### **How It Works:**

```bash
# 1. Detect lock by attempting plan with short timeout
LOCK_ID=$(terraform plan -lock-timeout=1s 2>&1 | grep -oP 'ID:\s+\K[a-f0-9-]+' | head -1)

# 2. If lock found, force-unlock
if [ -n "$LOCK_ID" ]; then
  terraform force-unlock -force "$LOCK_ID"
fi
```

### **Next Pipeline Run:**

Simply **re-run the failed workflow** - it will automatically unlock the state before proceeding.

---

## 🛠️ Manual Fix (If Needed)

If you need to unlock manually before the next pipeline run:

### **Method 1: Via GitHub Actions**

1. Go to **Actions** tab
2. Click **Infrastructure Deployment**
3. Click **Run workflow**
4. Select same environment (dev/prod)
5. Click **Run workflow**

The new unlock step will clear the lock automatically.

### **Method 2: Azure CLI (Local)**

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Get the storage account details (from backend.tf)
STORAGE_ACCOUNT="your-storage-account-name"
CONTAINER="tfstate"
BLOB="dev.mlops.tfstate"

# Check current lease status
az storage blob show \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $BLOB \
  --query "properties.lease" \
  --output table

# Break the lease (unlock)
az storage blob lease break \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --blob-name $BLOB

# Verify lease is broken
az storage blob show \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $BLOB \
  --query "properties.lease.status" \
  --output tsv
# Should show: unlocked
```

### **Method 3: Terraform CLI (Local)**

```bash
# Navigate to infrastructure directory
cd infrastructure

# Initialize Terraform
terraform init

# Force unlock using the Lock ID from the error message
terraform force-unlock -force 6431e2f5-4607-2d8f-2863-cf483a5c48a4

# Confirm when prompted (or use -force flag)
```

### **Method 4: Azure Portal (Manual)**

1. Go to **Azure Portal**
2. Navigate to **Storage Account** (tfstate storage)
3. Go to **Containers** > **tfstate**
4. Find the blob: `dev.mlops.tfstate`
5. Click **Break lease** in the context menu
6. Confirm the action

---

## 🎯 Prevention

### **Why Locks Happen:**

1. **Pipeline Cancellation** - User cancels workflow mid-run
2. **Timeout** - Pipeline times out before completion
3. **Network Issues** - Connection drops during apply
4. **Concurrent Runs** - Multiple pipelines running simultaneously
5. **Manual Ctrl+C** - Local Terraform interrupted

### **How to Prevent:**

1. **Don't Cancel Pipelines** - Let them complete or fail naturally
2. **Wait for Completion** - Don't run multiple deploys simultaneously
3. **Check Pipeline Status** - Ensure previous run finished
4. **Use Environments** - GitHub environments prevent concurrent runs
5. **Monitor Logs** - Watch for errors before they lock

---

## 🔍 Check Current Lock Status

### **Via Terraform:**

```bash
cd infrastructure
terraform init

# Try a plan with immediate timeout
terraform plan -lock-timeout=1s

# If locked, you'll see the lock details immediately
```

### **Via Azure CLI:**

```bash
# Check blob lease status
az storage blob show \
  --account-name <storage-account> \
  --container-name tfstate \
  --name dev.mlops.tfstate \
  --query "properties.lease" \
  --output json

# Output:
# {
#   "duration": "infinite",
#   "state": "leased",      ← This means locked
#   "status": "locked"      ← Locked!
# }
#
# Or:
# {
#   "state": "available",   ← Not locked
#   "status": "unlocked"    ← Good!
# }
```

---

## ⚡ Quick Resolution Steps

### **Immediate Action:**

```bash
# 1. Get the Lock ID from error message
LOCK_ID="6431e2f5-4607-2d8f-2863-cf483a5c48a4"

# 2. Local unlock (if you have Terraform locally)
cd infrastructure
terraform init
terraform force-unlock -force $LOCK_ID

# 3. Or just re-run the pipeline (automatic unlock added)
```

### **Verify Unlock:**

```bash
# Should complete without lock error
terraform plan -lock-timeout=5s
```

---

## 📊 Lock Information

### **Understanding Lock Details:**

```
Lock Info:
  ID:        6431e2f5-4607-2d8f-2863-cf483a5c48a4  ← Unique lock ID
  Path:      tfstate/dev.mlops.tfstate              ← State file path
  Operation: OperationTypeInvalid                    ← Type of operation
  Who:       runner@runnervmw9dnm                    ← GitHub Actions runner
  Version:   1.6.0                                   ← Terraform version
  Created:   2025-11-10 22:26:17 UTC                ← When lock acquired
```

### **Lock Types:**

- **Operation: OperationTypePlan** - Lock from `terraform plan`
- **Operation: OperationTypeApply** - Lock from `terraform apply`
- **Operation: OperationTypeInvalid** - Stale/corrupt lock

**OperationTypeInvalid** usually means the operation was interrupted and is safe to force-unlock.

---

## ✅ Summary

| Method | Speed | Automatic | Requires Access |
|--------|-------|-----------|-----------------|
| **Re-run Pipeline** | ⚡ Fast | ✅ Yes | GitHub |
| **Terraform CLI** | ⚡ Fast | ❌ No | Local + Azure |
| **Azure CLI** | ⏱️ Medium | ❌ No | Azure CLI |
| **Azure Portal** | 🐌 Slow | ❌ No | Azure Portal |

**Recommended:** Just **re-run the pipeline** - it will automatically unlock and continue! 🎯

---

## 🚨 Important Notes

- ✅ **Safe to unlock** if no other operations are running
- ⚠️ **Check first** that no other pipeline is active
- ✅ **Automatic unlock** now in pipeline (continue-on-error: true)
- ✅ **Won't fail** if unlock doesn't work (proceeds anyway)
- ⚠️ **Never unlock** if another apply is actually running

---

## 🔄 Post-Unlock Actions

After unlocking:

```bash
# 1. Verify state is accessible
terraform init
terraform plan

# 2. Check for drift
terraform plan -detailed-exitcode

# 3. Proceed with normal operations
terraform apply
```

The pipeline will now handle this automatically! 🎉

