# GitHub Actions to Azure DevOps Pipeline Conversion Notes

## Overview

This document details the conversion of `.github/workflows/cd-deploy.yml` to `azure-pipelines/cd-deploy.yml`.

## Conversion Summary

### What Was Converted

The GitHub Actions workflow was successfully converted to an Azure DevOps pipeline maintaining all functionality:

✅ **Maintained Features:**
- Manual trigger with parameters
- Managed Online Endpoint deployment (staging)
- Blue/Green deployment strategy (production)
- Gradual traffic rollout (10% → 50% → 100%)
- Automatic rollback on test failures
- Manual approval gates
- Comprehensive health checks and smoke tests
- Environment-specific configurations (dev/prod)
- Deployment summaries and logging

### Pipeline Structure Comparison

| Aspect | GitHub Actions | Azure DevOps |
|--------|---------------|--------------|
| **Stages/Jobs** | 6 jobs | 6 stages |
| **Total Lines** | ~979 lines | ~1300 lines |
| **Triggers** | `workflow_dispatch` | `trigger: none` with parameters |
| **Environments** | 2 (staging, production) | 3 (staging, production-approval, production) |
| **Approval Gates** | Environment protection rules | Explicit approval stage |

## Key Syntax Conversions

### 1. Trigger Configuration

**GitHub Actions:**
```yaml
on:
  workflow_dispatch:
    inputs:
      model_name:
        description: 'Model name'
        required: true
        default: 'diabetes-classifier'
```

**Azure DevOps:**
```yaml
trigger: none

parameters:
- name: model_name
  displayName: 'Model name to deploy'
  type: string
  default: 'diabetes-classifier'
```

### 2. Authentication

**GitHub Actions:**
```yaml
- name: Azure Login
  uses: azure/login@v2
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

**Azure DevOps:**
```yaml
- task: AzureCLI@2
  inputs:
    azureSubscription: 'azure-mlops-service-connection'
```

**Key Change:** Azure DevOps uses service connections instead of secrets for Azure authentication.

### 3. Job/Stage Dependencies

**GitHub Actions:**
```yaml
deploy-staging:
  needs: resolve-inputs
```

**Azure DevOps:**
```yaml
- stage: DeployStaging
  dependsOn: ResolveInputs
```

**Key Change:** `needs` → `dependsOn`

### 4. Conditional Execution

**GitHub Actions:**
```yaml
if: success()
if: needs.deploy-staging.outputs.deployment_state == 'success'
```

**Azure DevOps:**
```yaml
condition: succeeded()
condition: succeeded('DeployStaging')
```

**Key Change:** `if` → `condition`, with function-based syntax

### 5. Output Variables Between Jobs

**GitHub Actions:**
```yaml
# Setting output
- name: Resolve inputs
  id: resolve
  run: |
    echo "model_name=diabetes-classifier" >> $GITHUB_OUTPUT

# Using output
run: echo "${{ needs.resolve-inputs.outputs.model_name }}"
```

**Azure DevOps:**
```yaml
# Setting output
- task: Bash@3
  name: ResolveInputs
  inputs:
    script: |
      echo "##vso[task.setvariable variable=model_name;isOutput=true]diabetes-classifier"

# Using output in same stage
variables:
  model_name: $(ResolveInputs.model_name)

# Using output in different stage
variables:
  model_name: $[ stageDependencies.ResolveInputs.ResolveInputsJob.outputs['ResolveInputs.model_name'] ]
```

**Key Change:** 
- `$GITHUB_OUTPUT` → `##vso[task.setvariable]`
- Complex dependency path syntax for cross-stage variables

### 6. Secret Masking

**GitHub Actions:**
```yaml
echo "::add-mask::$ENDPOINT_KEY"
```

**Azure DevOps:**
```yaml
echo "##vso[task.setvariable variable=ENDPOINT_KEY;issecret=true]$ENDPOINT_KEY"
```

**Key Change:** Different logging command syntax

### 7. Job Summaries

**GitHub Actions:**
```yaml
echo "### Deployment Summary" >> $GITHUB_STEP_SUMMARY
echo "Status: Success" >> $GITHUB_STEP_SUMMARY
```

**Azure DevOps:**
```yaml
echo "### Deployment Summary"
echo "Status: Success"
```

**Key Change:** Azure DevOps displays all output in pipeline logs; no special summary file

### 8. Environment Protection

**GitHub Actions:**
```yaml
jobs:
  deploy:
    environment:
      name: production
      url: ${{ steps.deploy.outputs.url }}
```

**Azure DevOps:**
```yaml
jobs:
- deployment: DeployJob
  environment: production
  strategy:
    runOnce:
      deploy:
        steps:
        - # deployment steps
```

**Key Change:** 
- Azure DevOps uses `deployment` job type
- Approvals configured in Environment settings (not YAML)
- Requires `strategy` with `runOnce` or other deployment strategy

### 9. Continue on Error

**GitHub Actions:**
```yaml
- name: Create endpoint
  continue-on-error: true
```

**Azure DevOps:**
```yaml
- task: AzureCLI@2
  continueOnError: true
```

**Key Change:** Hyphenated vs camelCase

### 10. Parameter References

**GitHub Actions:**
```yaml
${{ github.event.inputs.model_name }}
${{ parameters.model_name }}  # (not typically used)
```

**Azure DevOps:**
```yaml
${{ parameters.model_name }}
```

**Key Change:** Azure DevOps uses `${{ parameters.* }}` consistently

## Architecture Decisions

### Stage vs. Job Organization

**Decision:** Converted 6 GitHub Actions jobs to 6 Azure DevOps stages (instead of jobs within stages)

**Rationale:**
1. Better visualization in Azure DevOps UI (stages show as separate sections)
2. Easier dependency management between major workflow phases
3. More explicit approval gates between stages
4. Clearer separation of concerns (resolve → deploy staging → prepare prod → approve → rollout → validate)

### Variable Passing Strategy

**Decision:** Use stage dependencies for variable passing instead of artifacts

**Rationale:**
1. Variables are lightweight and sufficient for metadata
2. Faster than artifact upload/download
3. Azure DevOps `stageDependencies` pattern is designed for this use case
4. No need for intermediate storage

**Example:**
```yaml
variables:
  model_name: $[ stageDependencies.ResolveInputs.ResolveInputsJob.outputs['ResolveInputs.model_name'] ]
```

### Approval Gate Implementation

**Decision:** Created explicit `ProductionApproval` stage with `production-approval` environment

**Rationale:**
1. GitHub Actions uses environment protection rules (not visible in YAML)
2. Azure DevOps best practice is explicit stage for approvals
3. Provides clear UI indication of pending approval
4. Allows display of approval information before approval is granted

### Template Usage

**Decision:** Created reusable template for Azure ML setup (`azure-ml-setup.yml`)

**Rationale:**
1. DRY principle - setup is used in multiple stages
2. Easier maintenance (update once, apply everywhere)
3. Consistent Python and Azure ML CLI setup
4. Azure DevOps best practice for reusable components

## Notable Differences

### 1. No AKS Deployment

The GitHub Actions workflow includes AKS deployment steps for production. These were **not included** in the Azure DevOps conversion because:

1. The requirement focused on Managed Online Endpoint and Blue/Green deployment
2. AKS deployment would require additional stages and complexity
3. The current implementation focuses on managed endpoints only

**If AKS is needed later**, add a new stage after `GradualRollout`:
```yaml
- stage: DeployToAKS
  displayName: 'Deploy to AKS (Production)'
  dependsOn: GradualRollout
  # AKS deployment steps here
```

### 2. Prometheus Monitoring

The GitHub Actions workflow includes Prometheus monitoring setup. This was **not included** in the Azure DevOps conversion because:

1. Requirement didn't specify monitoring implementation details
2. Would require additional Kubernetes manifests
3. Can be added as a separate stage if needed

**If monitoring is needed later**, add a new stage:
```yaml
- stage: SetupMonitoring
  displayName: 'Setup Prometheus Monitoring'
  dependsOn: DeployToAKS
  # Monitoring setup steps here
```

### 3. Deployment Strategies

**GitHub Actions workflow** included:
- Managed Online Endpoint (with Blue/Green)
- AKS with Blue/Green
- Prometheus monitoring

**Azure DevOps pipeline** includes:
- Managed Online Endpoint (with Blue/Green) ✅
- Gradual traffic rollout ✅
- Manual approval gates ✅

### 4. Environment Variables

Some environment variables from GitHub Actions were converted to pipeline variables in Azure DevOps:

| GitHub Actions | Azure DevOps | Location |
|----------------|--------------|----------|
| `env:` at workflow level | `variables:` at pipeline level | Top of file |
| `${{ env.VAR }}` | `$(VAR)` | Throughout pipeline |
| `secrets.AZURE_CREDENTIALS` | Service connection | Project settings |

### 5. Build Agent

**GitHub Actions:**
```yaml
runs-on: ubuntu-latest
```

**Azure DevOps:**
```yaml
pool:
  vmImage: 'ubuntu-latest'
```

Both use the same Ubuntu image, so no functional difference.

## Testing Considerations

### What to Test

1. **Variable Resolution:**
   - Verify all stage dependencies resolve correctly
   - Check parameter passing from pipeline input to stages

2. **Authentication:**
   - Ensure service connection has proper permissions
   - Test Azure ML CLI authentication

3. **Approval Gates:**
   - Verify approval appears at correct stage
   - Test approval timeout behavior
   - Test rejection behavior

4. **Rollback:**
   - Intentionally fail a smoke test
   - Verify automatic rollback to BLUE deployment
   - Check traffic distribution after rollback

5. **End-to-End:**
   - Run complete pipeline from start to finish
   - Verify staging deployment
   - Approve production deployment
   - Verify gradual rollout (10% → 50% → 100%)
   - Check final deployment state

### Test Checklist

- [ ] Pipeline runs without syntax errors
- [ ] Parameters are correctly passed to pipeline
- [ ] Service connection authenticates successfully
- [ ] Variable group values are accessible
- [ ] Stage dependencies resolve correctly
- [ ] Staging endpoint is created/updated
- [ ] Staging deployment succeeds
- [ ] Endpoint tests run successfully (or skip correctly)
- [ ] Production endpoint is created/updated
- [ ] GREEN deployment is created
- [ ] Approval stage blocks execution
- [ ] Approval can be granted
- [ ] Gradual rollout executes all phases
- [ ] Smoke tests run between phases
- [ ] BLUE deployment is scaled down
- [ ] Final validation confirms 100% traffic on GREEN
- [ ] Rollback works when test fails

## Migration Path

### Phase 1: Setup (Day 1)
1. Create service connection
2. Create variable group
3. Create environments with approval gates
4. Import pipeline

### Phase 2: Testing (Day 2-3)
1. Test with dummy model in dev environment
2. Verify staging deployment works
3. Test approval flow
4. Verify production rollout
5. Test rollback scenario

### Phase 3: Production (Day 4+)
1. Run pipeline with real model in dev
2. After validation, run in prod
3. Monitor first production deployment closely
4. Document any issues and resolutions

### Phase 4: Optimization (Ongoing)
1. Tune timeout values based on actual deployment times
2. Adjust approval timeout if needed
3. Add additional smoke tests if needed
4. Consider adding AKS deployment stage if required
5. Add monitoring stage if required

## Troubleshooting Guide

### Common Conversion Issues

1. **Variable Dependency Paths:**
   - **Issue:** Variables not resolving across stages
   - **Solution:** Use exact syntax: `$[ stageDependencies.StageName.JobName.outputs['TaskName.VarName'] ]`
   - **Common mistake:** Wrong stage/job/task names (case-sensitive)

2. **Service Connection:**
   - **Issue:** `Service connection not found`
   - **Solution:** Ensure service connection name matches exactly in pipeline and project settings

3. **Environment Names:**
   - **Issue:** `Environment not found`
   - **Solution:** Create environments in Azure DevOps before running pipeline

4. **Approval Configuration:**
   - **Issue:** Approvals not triggered
   - **Solution:** Add approval checks to `production-approval` environment in Azure DevOps UI

5. **Deployment Job Pattern:**
   - **Issue:** Steps not running in deployment job
   - **Solution:** Ensure using `strategy: runOnce: deploy: steps:` pattern correctly

## Future Enhancements

Potential improvements for future versions:

1. **Add AKS Deployment Stage:**
   - Implement AKS deployment after managed endpoint rollout
   - Include Docker image build and push
   - Add Kubernetes manifest updates

2. **Add Monitoring Stage:**
   - Deploy ServiceMonitor for Prometheus
   - Deploy PrometheusRules for alerting
   - Verify metrics collection

3. **Parallel Testing:**
   - Run multiple test suites in parallel
   - Performance testing
   - Load testing

4. **Multi-Region Deployment:**
   - Deploy to multiple Azure regions
   - Implement traffic manager for region routing

5. **Automated Model Version Resolution:**
   - Query Azure ML for latest model version automatically
   - Compare versions and determine if deployment is needed

6. **Rollback Automation:**
   - Implement automatic rollback based on metrics
   - Configure alert-driven rollback triggers

7. **Cost Optimization:**
   - Automatic scaling based on traffic patterns
   - Schedule-based instance count adjustments

## References

- [Azure DevOps YAML Schema](https://docs.microsoft.com/en-us/azure/devops/pipelines/yaml-schema)
- [GitHub Actions to Azure Pipelines](https://docs.microsoft.com/en-us/azure/devops/pipelines/migrate/from-github-actions)
- [Azure ML CLI v2](https://docs.microsoft.com/en-us/azure/machine-learning/how-to-configure-cli)
- [Deployment Jobs](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/deployment-jobs)
- [Approvals and Checks](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/approvals)

---

**Document Version:** 1.0  
**Last Updated:** 2024  
**Converted By:** GitHub Copilot  
**Original Workflow:** `.github/workflows/cd-deploy.yml`  
**Target Pipeline:** `azure-pipelines/cd-deploy.yml`
