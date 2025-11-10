# Quick Reference: Destroy Infrastructure

## 🗑️ How to Destroy Infrastructure via GitHub Actions

### **Step-by-Step Guide:**

1. **Go to GitHub Repository**
   ```
   https://github.com/{your-org}/{your-repo}
   ```

2. **Navigate to Actions Tab**
   - Click "Actions" in the top menu

3. **Select Workflow**
   - Click "Infrastructure Deployment" from the list

4. **Run Workflow**
   - Click "Run workflow" button (top right)

5. **Configure Destruction**
   ```
   Branch: deployment-pipeline (or main)
   Environment to deploy: [Select dev or prod]
   Destroy infrastructure: ✅ CHECK THIS BOX
   ```

6. **Confirm**
   - Click "Run workflow" button

7. **Monitor Progress**
   - Click on the running workflow
   - Watch "Destroy - Development" or "Destroy - Production" job

---

## ⚡ Quick Commands

### **Via GitHub CLI:**

```bash
# Destroy dev environment
gh workflow run infrastructure-deploy.yml \
  --ref deployment-pipeline \
  -f environment=dev \
  -f destroy=true

# Destroy prod environment  
gh workflow run infrastructure-deploy.yml \
  --ref deployment-pipeline \
  -f environment=prod \
  -f destroy=true
```

---

## ⚠️ Important Notes

- **Manual trigger only** - Won't run automatically
- **Requires approval** - If environment protection enabled
- **Irreversible** - All resources deleted permanently
- **Data loss** - Backups won't prevent deletion
- **State preserved** - Can recreate with same config

---

## 🔄 Recreate After Destroy

```bash
# Via GitHub Actions UI:
# 1. Actions > Infrastructure Deployment > Run workflow
# 2. Environment: dev (or prod)
# 3. Destroy infrastructure: UNCHECKED ❌
# 4. Run workflow
```

---

## 🛡️ Setup Environment Protection (Recommended)

### **In GitHub:**
```
Settings > Environments > New environment

1. Create: dev-destroy
   - Required reviewers: 1 person
   
2. Create: production-destroy
   - Required reviewers: 2 people
   - Wait timer: 5 minutes
```

This adds approval requirement before destruction!

---

## ✅ What Gets Destroyed

Everything in the resource group:
- ML Workspace + all experiments
- Storage Account + all data
- Container Registry + all images
- AKS Cluster
- All monitoring & alerts
- All networking components
- All optional services (if enabled)

**Total:** ~18-40 resources depending on configuration

---

## 📋 Pre-Destroy Checklist

- [ ] Backup critical data
- [ ] Export ML models
- [ ] Download experiment results
- [ ] Notify team members
- [ ] Verify correct environment
- [ ] No active ML jobs running

---

## 🎯 When to Use Destroy

**Good Use Cases:**
- ✅ End of day in dev (save costs)
- ✅ Testing infrastructure changes
- ✅ Project completion
- ✅ Environment refresh

**Bad Use Cases:**
- ❌ Production with live services
- ❌ During active ML training
- ❌ Without backups
- ❌ When purge protection enabled

