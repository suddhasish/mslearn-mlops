# Azure DevOps MLOps Deployment Pipeline

This directory contains Azure DevOps YAML pipelines converted from GitHub Actions workflows.

## Overview

The `cd-deploy.yml` pipeline implements a complete MLOps continuous deployment workflow with:

- **Managed Online Endpoint** deployment to staging environment
- **Blue/Green deployment** strategy for production
- **Manual approval gates** before production rollout
- **Gradual traffic shifting** with automated testing (10% → 50% → 100%)
- **Automatic rollback** on test failures
- **Comprehensive validation** and health checks

## Prerequisites

### 1. Azure Service Connection

Create an Azure Resource Manager service connection in your Azure DevOps project:

1. Navigate to **Project Settings** → **Service connections**
2. Click **New service connection** → **Azure Resource Manager**
3. Choose **Service principal (automatic)** or **Service principal (manual)**
4. Configure the connection:
   - **Connection name**: `azure-mlops-service-connection`
   - **Subscription**: Select your Azure subscription
   - **Resource group**: Leave empty (pipeline needs access to multiple RGs)
   - Grant access to all pipelines (or configure per-pipeline)
5. Ensure the service principal has the following permissions:
   - **Contributor** role on the resource groups containing:
     - Azure Machine Learning workspace
     - Azure Container Registry
     - Azure Kubernetes Service
   - **Azure Machine Learning Workspace Contributor** role on ML workspaces

### 2. Variable Group

Create a variable group named `mlops-infrastructure` with the following variables:

| Variable Name | Description | Example Value |
|---------------|-------------|---------------|
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `b2b8a5e6-9a34-494b-ba62-fe9be95bd398` |
| `RESOURCE_GROUP` | Default resource group (optional) | `mlopsnew-dev-rg` |
| `ML_WORKSPACE` | Default ML workspace (optional) | `mlopsnew-dev-mlw` |
| `AZURE_ML_STAGING_ENDPOINT_NAME` | Staging endpoint name (optional) | `ml-endpoint-staging` |
| `AKS_NAMESPACE` | Kubernetes namespace (if using AKS) | `mlops-prod` |

**Note**: Most values are defined in the pipeline itself and can be overridden in the variable group if needed.

To create the variable group:

1. Navigate to **Pipelines** → **Library**
2. Click **+ Variable group**
3. Name: `mlops-infrastructure`
4. Add the required variables
5. Save

### 3. Environments

Create the following environments in Azure DevOps:

#### Staging Environment

1. Navigate to **Pipelines** → **Environments**
2. Click **New environment**
3. Name: `staging`
4. Resource: None (select blank)
5. Click **Create**
6. **Optional**: Add approvals and checks if you want manual approval for staging

#### Production Approval Environment

1. Create new environment named: `production-approval`
2. **Add Approval Check**:
   - Click the environment → Three dots menu → **Approvals and checks**
   - Add **Approvals**
   - Add approvers (users/groups who can approve production deployments)
   - **Minimum approvers**: 1 (or more for stricter controls)
   - **Timeout**: 30 days (adjust as needed)
3. This environment acts as a manual gate before production rollout

#### Production Environment

1. Create new environment named: `production`
2. **Optional**: Add additional checks:
   - Branch control (only allow deployments from main/production branch)
   - Business hours restrictions
   - Invoke REST API checks for external validation

### 4. Azure Infrastructure

Ensure the following Azure resources are deployed (typically via Terraform):

#### DEV Environment
- Resource Group: `mlopsnew-dev-rg`
- ML Workspace: `mlopsnew-dev-mlw`
- Container Registry: `mlopsnewdevacr3kxldb.azurecr.io`
- AKS Cluster: `mlopsnew-dev-aks`
- Key Vault: `mlopsnew-dev-kv-3kxldb`

#### PROD Environment
- Resource Group: `mlopsnew-prod-rg`
- ML Workspace: `mlopsnew-prod-mlw`
- Container Registry: `mlopsnewprodacr.azurecr.io`
- AKS Cluster: `mlopsnew-prod-aks`
- Key Vault: `mlopsnew-prod-kv`

## Pipeline Structure

The pipeline consists of 6 stages:

### Stage 1: Resolve Inputs
- Generates unique deployment ID
- Resolves environment-specific infrastructure settings
- Validates model name and version
- Sets output variables for downstream stages

### Stage 2: Deploy to Staging
- Creates or updates staging managed online endpoint
- Deploys model to staging environment
- Waits for deployment to be healthy
- Runs endpoint tests (optional, can be skipped)
- Outputs endpoint URL for validation

### Stage 3: Prepare Production
- Creates or updates production managed online endpoint
- Creates/updates BLUE deployment (if first-time setup)
- Creates GREEN deployment with new model version
- Tests GREEN deployment in isolation (0% traffic)
- Prepares for traffic shifting

### Stage 4: Production Approval
- **Manual approval gate** (requires human approval)
- Displays deployment summary and rollout plan
- Blocks until approved or rejected

### Stage 5: Gradual Rollout
- **Phase 1**: Shifts 10% traffic to GREEN → runs smoke tests
- **Phase 2**: Shifts 50% traffic to GREEN → runs smoke tests
- **Phase 3**: Shifts 100% traffic to GREEN → runs smoke tests
- **Automatic rollback** to BLUE if any phase fails
- Scales down BLUE deployment for cost savings (if successful)

### Stage 6: Post-Deployment Validation
- Verifies final traffic distribution (100% on GREEN)
- Logs deployment metrics
- Outputs success notification

## Running the Pipeline

### Import the Pipeline

1. Navigate to **Pipelines** → **Pipelines**
2. Click **New pipeline**
3. Select **Azure Repos Git** (or your repo source)
4. Select your repository
5. Choose **Existing Azure Pipelines YAML file**
6. Path: `/azure-pipelines/cd-deploy.yml`
7. Click **Continue** → **Save** (or **Run**)

### Manual Trigger

The pipeline is configured for **manual trigger only** with parameters:

1. Navigate to the pipeline
2. Click **Run pipeline**
3. Configure parameters:

| Parameter | Description | Default | Options |
|-----------|-------------|---------|---------|
| `environment` | Target environment | `dev` | `dev`, `prod` |
| `model_name` | Model to deploy | `diabetes-classifier` | Any registered model |
| `model_version` | Model version | `latest` | Version number or `latest` |
| `staging_instance_type` | Staging VM type | `Standard_DS2_v2` | Azure VM SKU |
| `staging_instance_count` | Staging instance count | `1` | Number (1-N) |
| `prod_instance_type` | Production VM type | `Standard_DS3_v2` | Azure VM SKU |
| `prod_instance_count` | Production instance count | `2` | Number (1-N) |
| `skip_staging_tests` | Skip staging tests | `false` | `true`, `false` |

4. Click **Run**

### Example: Deploy to DEV

```yaml
environment: dev
model_name: diabetes-classifier
model_version: latest
staging_instance_type: Standard_DS2_v2
staging_instance_count: 1
prod_instance_type: Standard_DS3_v2
prod_instance_count: 2
skip_staging_tests: false
```

### Example: Deploy to PROD

```yaml
environment: prod
model_name: diabetes-classifier
model_version: 3
staging_instance_type: Standard_DS3_v2
staging_instance_count: 2
prod_instance_type: Standard_DS3_v2
prod_instance_count: 3
skip_staging_tests: false
```

## Key Differences from GitHub Actions

This pipeline was converted from GitHub Actions (`.github/workflows/cd-deploy.yml`). Key differences:

### Authentication
- **GitHub Actions**: Uses `AZURE_CREDENTIALS` secret with service principal JSON
- **Azure DevOps**: Uses `azureSubscription` service connection
  ```yaml
  # GitHub Actions
  - uses: azure/login@v2
    with:
      creds: ${{ secrets.AZURE_CREDENTIALS }}
  
  # Azure DevOps
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'azure-mlops-service-connection'
  ```

### Job Dependencies
- **GitHub Actions**: Uses `needs:`
- **Azure DevOps**: Uses `dependsOn:`
  ```yaml
  # GitHub Actions
  job-b:
    needs: job-a
  
  # Azure DevOps
  - stage: StageB
    dependsOn: StageA
  ```

### Conditionals
- **GitHub Actions**: Uses `if:`
- **Azure DevOps**: Uses `condition:`
  ```yaml
  # GitHub Actions
  if: success()
  
  # Azure DevOps
  condition: succeeded()
  ```

### Outputs Between Jobs
- **GitHub Actions**: Uses `$GITHUB_OUTPUT` file
- **Azure DevOps**: Uses `##vso[task.setvariable]` logging command
  ```bash
  # GitHub Actions
  echo "variable=value" >> $GITHUB_OUTPUT
  
  # Azure DevOps
  echo "##vso[task.setvariable variable=variable;isOutput=true]value"
  ```

### Variable References
- **GitHub Actions**: Uses `${{ needs.job_id.outputs.variable }}`
- **Azure DevOps**: Uses `$[ stageDependencies.StageId.JobId.outputs['TaskName.VariableName'] ]`
  ```yaml
  # GitHub Actions
  run: echo "${{ needs.resolve-inputs.outputs.model_name }}"
  
  # Azure DevOps
  variables:
    model_name: $[ stageDependencies.ResolveInputs.ResolveInputsJob.outputs['ResolveInputs.model_name'] ]
  ```

### Masking Secrets
- **GitHub Actions**: `echo "::add-mask::$SECRET"`
- **Azure DevOps**: `echo "##vso[task.setvariable variable=SECRET;issecret=true]$VALUE"`

### Job Summaries
- **GitHub Actions**: Writes to `$GITHUB_STEP_SUMMARY` file
- **Azure DevOps**: Logs directly (displayed in pipeline logs)
  ```bash
  # GitHub Actions
  echo "### Summary" >> $GITHUB_STEP_SUMMARY
  
  # Azure DevOps
  echo "### Summary"  # Shown in logs
  ```

### Environment Protection
- **GitHub Actions**: Environment rules configured in GitHub UI
- **Azure DevOps**: Environment approvals configured in Environments section
  ```yaml
  # GitHub Actions
  environment:
    name: production
    url: ${{ steps.deploy.outputs.url }}
  
  # Azure DevOps
  - deployment: DeployJob
    environment: production
  ```

## Troubleshooting

### Common Issues

#### Issue: Service connection not found

**Error**: `Could not find service connection 'azure-mlops-service-connection'`

**Solution**:
1. Verify the service connection exists in **Project Settings** → **Service connections**
2. Ensure it's named exactly `azure-mlops-service-connection`
3. Grant the pipeline access to the service connection

#### Issue: Variable group not found

**Error**: `Could not find variable group 'mlops-infrastructure'`

**Solution**:
1. Create the variable group in **Pipelines** → **Library**
2. Add required variables (at minimum `AZURE_SUBSCRIPTION_ID`)
3. Link the variable group to the pipeline

#### Issue: Model not found

**Error**: `Model 'diabetes-classifier:latest' not found in workspace`

**Solution**:
1. Verify the model is registered in Azure ML workspace
2. Check the model name (case-sensitive)
3. If using version number, ensure it exists
4. Run model training pipeline first to register a model

#### Issue: Deployment timeout

**Error**: `Timeout waiting for deployment (exceeded 300 seconds)`

**Solution**:
1. Increase `MAX_WAIT_ITERATIONS` or `WAIT_INTERVAL_SECONDS` in pipeline variables
2. Check Azure ML workspace deployment logs for errors
3. Verify compute quota is available
4. Check for resource provisioning issues in Azure Portal

#### Issue: Approval timeout

**Error**: `The job was canceled because the approval expired`

**Solution**:
1. Increase approval timeout in Environment settings
2. Approve deployments more promptly
3. Configure approval notifications to alert approvers

#### Issue: Traffic distribution fails

**Error**: `Failed to update traffic distribution`

**Solution**:
1. Ensure both BLUE and GREEN deployments are in "Succeeded" state
2. Check that deployment names match exactly
3. Verify endpoint exists and is healthy
4. Review Azure ML service logs for API errors

#### Issue: Tests fail

**Error**: `Test script not found at scripts/test_endpoint.py`

**Solution**:
1. Create the test script (see template below)
2. Or set `skip_staging_tests: true` to skip tests
3. Ensure test script is committed to repository

### Test Script Template

If `scripts/test_endpoint.py` doesn't exist, create it:

```python
#!/usr/bin/env python3
"""
Endpoint testing script for Azure ML deployments
"""
import argparse
import json
import requests
import sys

def test_endpoint(url, key):
    """Test the ML endpoint with sample data"""
    
    # Sample test data (adjust for your model)
    test_data = {
        "data": [[1, 2, 3, 4, 5]]  # Replace with actual feature values
    }
    
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {key}"
    }
    
    try:
        print(f"Testing endpoint: {url}")
        response = requests.post(url, json=test_data, headers=headers, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            print(f"✓ Test passed - Status: {response.status_code}")
            print(f"Response: {json.dumps(result, indent=2)}")
            return True
        else:
            print(f"✗ Test failed - Status: {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"✗ Test failed with exception: {str(e)}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Test ML endpoint')
    parser.add_argument('--url', required=True, help='Endpoint URL')
    parser.add_argument('--key', required=True, help='Endpoint key')
    
    args = parser.parse_args()
    
    success = test_endpoint(args.url, args.key)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
```

Save as `/scripts/test_endpoint.py` and make it executable:
```bash
chmod +x scripts/test_endpoint.py
```

### Enable Debug Logging

To get more verbose output:

1. Edit the pipeline
2. Add a variable:
   ```yaml
   variables:
   - name: system.debug
     value: true
   ```
3. Save and run

This will show detailed logs for all tasks.

### View Deployment Logs in Azure Portal

1. Navigate to Azure ML workspace in Azure Portal
2. Go to **Endpoints** → Select your endpoint
3. Click on the deployment name
4. View **Logs** tab for detailed deployment logs
5. Check **Metrics** for performance data

## Migration Checklist

Use this checklist when migrating from GitHub Actions:

- [ ] Create Azure DevOps service connection (`azure-mlops-service-connection`)
- [ ] Create variable group (`mlops-infrastructure`)
- [ ] Create environments:
  - [ ] `staging`
  - [ ] `production-approval` (with approval gates)
  - [ ] `production`
- [ ] Configure approval gates on `production-approval` environment
- [ ] Import pipeline from YAML file
- [ ] Verify all Azure resources exist:
  - [ ] ML Workspace
  - [ ] Container Registry
  - [ ] AKS Cluster (if using)
  - [ ] Key Vault
- [ ] Test pipeline with dummy model:
  - [ ] Register a test model in Azure ML
  - [ ] Run pipeline in `dev` environment
  - [ ] Verify staging deployment
  - [ ] Approve production deployment
  - [ ] Verify production rollout
- [ ] Verify AKS deployment (if applicable)
- [ ] Test monitoring setup (if using Prometheus)
- [ ] Validate rollback procedure:
  - [ ] Intentionally fail a test
  - [ ] Verify automatic rollback to BLUE
- [ ] Document team-specific procedures
- [ ] Train team on approval process

## Additional Resources

- [Azure DevOps YAML Pipeline Schema](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
- [Azure ML CLI v2 Documentation](https://docs.microsoft.com/en-us/azure/machine-learning/how-to-configure-cli)
- [Service Connections in Azure DevOps](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints)
- [Environments in Azure DevOps](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/environments)
- [Approvals and Checks](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/approvals)

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review Azure DevOps pipeline logs
3. Check Azure ML workspace deployment logs
4. Contact your DevOps team or Azure ML administrator

---

**Last Updated**: 2024
**Converted From**: `.github/workflows/cd-deploy.yml`
**Pipeline Version**: 1.0
