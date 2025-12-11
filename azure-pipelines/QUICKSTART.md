# Azure DevOps Pipeline - Quick Start Guide

This guide will help you get the MLOps CD pipeline running in Azure DevOps in 15 minutes.

## Prerequisites

Before you begin, ensure you have:
- ✅ Azure DevOps organization and project
- ✅ Azure subscription with:
  - Azure Machine Learning workspace
  - Container Registry
  - AKS cluster (optional)
- ✅ A registered model in Azure ML workspace
- ✅ Admin access to Azure DevOps project

## Quick Setup (5 Steps)

### Step 1: Create Service Connection (2 minutes)

1. In Azure DevOps, go to **Project Settings** → **Service connections**
2. Click **New service connection** → **Azure Resource Manager**
3. Choose **Service principal (automatic)**
4. Fill in:
   - **Subscription**: Your Azure subscription
   - **Resource group**: Leave blank
   - **Service connection name**: `azure-mlops-service-connection`
5. Check "Grant access permission to all pipelines"
6. Click **Save**

### Step 2: Create Variable Group (1 minute)

1. Go to **Pipelines** → **Library**
2. Click **+ Variable group**
3. Name: `mlops-infrastructure`
4. Add variable:
   - **Name**: `AZURE_SUBSCRIPTION_ID`
   - **Value**: Your Azure subscription ID (e.g., `b2b8a5e6-9a34-494b-ba62-fe9be95bd398`)
5. Click **Save**

### Step 3: Create Environments (3 minutes)

Create three environments:

#### Environment 1: staging
1. Go to **Pipelines** → **Environments**
2. Click **New environment**
3. Name: `staging`
4. Click **Create**

#### Environment 2: production-approval
1. Click **New environment**
2. Name: `production-approval`
3. Click **Create**
4. Click the environment → **⋮ (menu)** → **Approvals and checks**
5. Click **Approvals**
6. Add yourself as approver
7. Click **Create**

#### Environment 3: production
1. Click **New environment**
2. Name: `production`
3. Click **Create**

### Step 4: Import Pipeline (2 minutes)

1. Go to **Pipelines** → **Pipelines**
2. Click **New pipeline**
3. Select **Azure Repos Git** (or your source)
4. Select your repository
5. Choose **Existing Azure Pipelines YAML file**
6. Path: `/azure-pipelines/cd-deploy.yml`
7. Click **Continue**
8. Click **Save** (don't run yet)

### Step 5: Run Pipeline (7 minutes)

1. Click **Run pipeline**
2. Configure parameters:
   ```
   environment: dev
   model_name: <your-model-name>
   model_version: latest
   staging_instance_type: Standard_DS2_v2
   staging_instance_count: 1
   prod_instance_type: Standard_DS3_v2
   prod_instance_count: 2
   skip_staging_tests: false
   ```
3. Click **Run**
4. Wait for stages to complete:
   - ✅ Resolve Inputs (~1 min)
   - ✅ Deploy to Staging (~3 min)
   - ✅ Prepare Production (~3 min)
   - ⏸️ **Approval Required** → Click **Review** → **Approve**
   - ✅ Gradual Rollout (~5 min)
   - ✅ Post-Deployment Validation (~1 min)

## What Happens During Pipeline Execution

### Stage 1: Resolve Inputs ⚙️
- Generates unique deployment ID
- Resolves infrastructure settings based on environment (dev/prod)
- Validates parameters
- **Duration**: ~1 minute

### Stage 2: Deploy to Staging 🚀
- Creates managed online endpoint (if needed)
- Deploys model to staging
- Waits for deployment to be healthy
- Runs endpoint tests
- **Duration**: ~3-5 minutes
- **Output**: Staging endpoint URL

### Stage 3: Prepare Production 🎯
- Creates production endpoint (if needed)
- Creates BLUE deployment (first-time only)
- Creates GREEN deployment with new model
- Tests GREEN in isolation (0% traffic)
- **Duration**: ~3-5 minutes
- **Output**: GREEN deployment ready

### Stage 4: Production Approval 🔒
- **Manual approval required**
- Displays deployment summary
- Shows rollout plan
- **Duration**: Depends on approver availability
- **Action**: Approve or reject

### Stage 5: Gradual Rollout 📊
- Phase 1: 10% → GREEN, smoke test ✅
- Phase 2: 50% → GREEN, smoke test ✅
- Phase 3: 100% → GREEN, smoke test ✅
- Automatic rollback if any test fails ❌
- Scales down BLUE to 0 instances (cost savings)
- **Duration**: ~5-7 minutes

### Stage 6: Post-Deployment Validation ✔️
- Verifies 100% traffic on GREEN
- Logs deployment metrics
- Success notification
- **Duration**: ~1 minute

## Troubleshooting

### Pipeline fails to start
**Error**: "Could not find service connection"
- ✅ Verify service connection name is exactly `azure-mlops-service-connection`
- ✅ Grant pipeline access to service connection

### Stage fails: "Model not found"
**Error**: "Model 'xyz:latest' not found"
- ✅ Register a model in Azure ML workspace first
- ✅ Use exact model name (case-sensitive)
- ✅ Or specify a version number instead of 'latest'

### Approval stage timeout
**Error**: "Approval expired"
- ✅ Increase timeout in environment settings
- ✅ Approve within 30 days (default)

### Rollback triggered
**Warning**: "ROLLBACK INITIATED"
- ✅ Check endpoint test script (`scripts/test_endpoint.py`)
- ✅ Verify endpoint is responding correctly
- ✅ Review smoke test logs for failures

## Next Steps

### After First Successful Run

1. **Review Deployments**
   - Azure Portal → ML Workspace → Endpoints
   - Verify staging endpoint
   - Verify production endpoint
   - Check traffic distribution (should be 100% GREEN)

2. **Test Endpoints**
   ```bash
   # Get endpoint URL and key from pipeline logs
   curl -X POST "$ENDPOINT_URL" \
     -H "Authorization: Bearer $ENDPOINT_KEY" \
     -H "Content-Type: application/json" \
     -d '{"data": [[59, 2, 32.1, 101.0, 157, 93.2, 38.0, 4.0, 4.8598]]}'
   ```

3. **Monitor Deployments**
   - Azure Portal → ML Workspace → Endpoints
   - View metrics (requests, latency, errors)
   - Review logs

4. **Set Up Alerts** (Optional)
   - Configure Azure Monitor alerts for:
     - High error rate
     - High latency
     - Low availability

### Customize for Your Use Case

1. **Adjust Instance Types**
   - Modify default parameters for your workload
   - Consider cost vs. performance trade-offs

2. **Customize Tests**
   - Edit `scripts/test_endpoint.py`
   - Add your model-specific test data
   - Add additional validation logic

3. **Configure Approval Gates**
   - Add multiple approvers
   - Set up business hours restrictions
   - Add pre-approval checks

4. **Add Notifications**
   - Configure email notifications for approvals
   - Set up Slack/Teams notifications
   - Add deployment status updates

## Common Parameters

### Development Deployment
```yaml
environment: dev
model_name: my-model
model_version: latest
staging_instance_type: Standard_DS2_v2
staging_instance_count: 1
prod_instance_type: Standard_DS2_v2
prod_instance_count: 1
skip_staging_tests: false
```

### Production Deployment
```yaml
environment: prod
model_name: my-model
model_version: 5  # specific version
staging_instance_type: Standard_DS3_v2
staging_instance_count: 2
prod_instance_type: Standard_DS3_v2
prod_instance_count: 3
skip_staging_tests: false
```

### Quick Test (Skip Tests)
```yaml
environment: dev
model_name: my-model
model_version: latest
staging_instance_type: Standard_DS2_v2
staging_instance_count: 1
prod_instance_type: Standard_DS2_v2
prod_instance_count: 1
skip_staging_tests: true  # ⚠️ Not recommended
```

## Pipeline Execution Time

| Stage | Typical Duration | Can Fail? |
|-------|------------------|-----------|
| Resolve Inputs | 1 minute | ❌ No |
| Deploy to Staging | 3-5 minutes | ✅ Yes |
| Prepare Production | 3-5 minutes | ✅ Yes |
| Production Approval | Variable | ✅ Yes (if rejected/timeout) |
| Gradual Rollout | 5-7 minutes | ✅ Yes (automatic rollback) |
| Post-Deployment | 1 minute | ❌ No (validation only) |
| **Total** | **15-20 minutes** + approval time | |

## Success Indicators

✅ **Pipeline succeeded if:**
- All stages show green checkmarks
- Staging endpoint is deployed
- Production approval was granted
- Gradual rollout completed all phases (10% → 50% → 100%)
- Final validation confirms 100% traffic on GREEN
- No rollback occurred

## Getting Help

1. **Pipeline Logs**: Click on failed task to view detailed logs
2. **Azure Portal**: Check Azure ML workspace for deployment status
3. **README**: See `azure-pipelines/README.md` for detailed documentation
4. **Conversion Notes**: See `azure-pipelines/CONVERSION_NOTES.md` for technical details
5. **Test Script**: Edit `scripts/test_endpoint.py` to match your model

## Cost Considerations

💰 **Cost Optimization Tips:**
1. Use smaller instance types in dev environment
2. Scale down BLUE deployment after successful rollout (done automatically)
3. Delete old endpoints if no longer needed
4. Use spot instances for non-production (if available)
5. Monitor instance usage and right-size

## Security Best Practices

🔒 **Security Checklist:**
- ✅ Service principal has minimum required permissions
- ✅ Secrets are masked in pipeline logs
- ✅ Approval gates are configured for production
- ✅ Only authorized users can approve deployments
- ✅ Endpoint keys are stored securely (not in logs)
- ✅ Pipeline is triggered manually (not on every commit)

## FAQ

**Q: Can I deploy to production without staging?**
A: No, the pipeline requires staging deployment first for safety.

**Q: Can I skip the approval gate?**
A: You can remove the approval check from the environment, but it's not recommended.

**Q: What happens if a rollback occurs?**
A: Traffic is automatically routed back to BLUE deployment (previous version).

**Q: Can I deploy multiple models in parallel?**
A: Not with this pipeline. Run separate pipeline instances for each model.

**Q: How do I rollback manually?**
A: Use Azure Portal → ML Workspace → Endpoints → Update traffic distribution.

**Q: Can I use this with other ML frameworks?**
A: Yes, but you may need to update `scripts/test_endpoint.py` for your input format.

---

**Need more help?** See the complete documentation in `azure-pipelines/README.md`
