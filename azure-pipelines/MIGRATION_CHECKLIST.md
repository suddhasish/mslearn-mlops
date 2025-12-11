# Azure DevOps Pipeline Migration Checklist

Use this checklist to track your migration from GitHub Actions to Azure DevOps.

## Phase 1: Pre-Migration Planning

### Infrastructure Assessment
- [ ] Verify Azure ML workspace exists and is accessible
- [ ] Verify Container Registry exists (if using AKS)
- [ ] Verify AKS cluster exists (if using AKS deployment)
- [ ] Verify Key Vault exists
- [ ] Document current infrastructure configuration
- [ ] List all registered models in Azure ML workspace
- [ ] Identify which models need to be deployed

### Access & Permissions
- [ ] Verify you have Owner or Contributor on Azure subscription
- [ ] Verify you have Project Administrator on Azure DevOps
- [ ] Identify who should be approvers for production deployments
- [ ] Document approval process and requirements
- [ ] Get sign-off from stakeholders for migration

### Current State Documentation
- [ ] Document GitHub Actions workflow configuration
- [ ] Document current deployment process
- [ ] Document any customizations or workarounds
- [ ] List all secrets and environment variables used
- [ ] Export current deployment history for reference

## Phase 2: Azure DevOps Setup

### Project Configuration
- [ ] Create or identify Azure DevOps project
- [ ] Ensure repository is connected to Azure DevOps
- [ ] Configure branch policies (if needed)
- [ ] Set up permissions for pipeline users

### Service Connection (Critical)
- [ ] Navigate to Project Settings → Service connections
- [ ] Create new Azure Resource Manager service connection
- [ ] Name: `azure-mlops-service-connection` (exact name)
- [ ] Choose subscription and authentication method
- [ ] Grant access to all pipelines
- [ ] Test connection
- [ ] Document service principal ID and permissions

### Variable Group
- [ ] Navigate to Pipelines → Library
- [ ] Create variable group: `mlops-infrastructure`
- [ ] Add variable: `AZURE_SUBSCRIPTION_ID`
- [ ] Add any other required variables from your setup
- [ ] Link variable group to pipeline (done in YAML)
- [ ] Test variable group is accessible

### Environments
- [ ] Create environment: `staging`
  - [ ] No approval required (testing environment)
  - [ ] Optional: Add checks if desired
- [ ] Create environment: `production-approval`
  - [ ] Add Approvals check
  - [ ] Add approvers (at least 1)
  - [ ] Set timeout: 30 days (or as needed)
  - [ ] Set "Minimum approvers": 1
  - [ ] Optional: Add "Requestor cannot approve"
- [ ] Create environment: `production`
  - [ ] Optional: Add additional checks
  - [ ] Optional: Add branch control
  - [ ] Optional: Add business hours restriction
- [ ] Test approval flow with dummy deployment

## Phase 3: Pipeline Creation

### Code Preparation
- [ ] Review pipeline files:
  - [ ] `azure-pipelines/cd-deploy.yml`
  - [ ] `azure-pipelines/templates/azure-ml-setup.yml`
  - [ ] `scripts/test_endpoint.py`
- [ ] Customize pipeline parameters for your environment
- [ ] Update infrastructure variable names if needed
- [ ] Update model names and versions
- [ ] Customize test script for your model input format

### Pipeline Import
- [ ] Navigate to Pipelines → Pipelines
- [ ] Click "New pipeline"
- [ ] Select repository source
- [ ] Choose "Existing Azure Pipelines YAML file"
- [ ] Path: `/azure-pipelines/cd-deploy.yml`
- [ ] Review pipeline YAML
- [ ] Click "Save" (don't run yet)

### Configuration Validation
- [ ] Verify service connection name matches in YAML
- [ ] Verify variable group name matches in YAML
- [ ] Verify environment names match in YAML
- [ ] Verify all parameters have default values
- [ ] Verify Azure resource names are correct
- [ ] Check pipeline triggers (should be `none`)

## Phase 4: Testing

### Dev Environment Testing
- [ ] Register a test model in Azure ML (if needed)
- [ ] Run pipeline with minimal configuration:
  - [ ] environment: `dev`
  - [ ] model_name: `<test-model>`
  - [ ] model_version: `latest`
  - [ ] skip_staging_tests: `false`
- [ ] Monitor Stage 1: Resolve Inputs
  - [ ] Check deployment ID generation
  - [ ] Verify infrastructure resolution
  - [ ] Check output variables
- [ ] Monitor Stage 2: Deploy to Staging
  - [ ] Check endpoint creation
  - [ ] Check deployment progress
  - [ ] Verify health checks
  - [ ] Check endpoint tests (if not skipped)
- [ ] Monitor Stage 3: Prepare Production
  - [ ] Check production endpoint creation
  - [ ] Check BLUE deployment (first-time)
  - [ ] Check GREEN deployment
  - [ ] Verify isolation tests
- [ ] Monitor Stage 4: Production Approval
  - [ ] Verify approval request appears
  - [ ] Check approval notification (email/Teams)
  - [ ] Review deployment information
  - [ ] Test approval flow
- [ ] Monitor Stage 5: Gradual Rollout
  - [ ] Check 10% traffic phase
  - [ ] Check 50% traffic phase
  - [ ] Check 100% traffic phase
  - [ ] Verify smoke tests between phases
  - [ ] Check BLUE scale-down
- [ ] Monitor Stage 6: Post-Deployment Validation
  - [ ] Verify traffic distribution
  - [ ] Check deployment metrics
  - [ ] Review final logs

### Rollback Testing
- [ ] Intentionally break endpoint test script
- [ ] Run pipeline
- [ ] Verify rollback is triggered
- [ ] Verify traffic returns to BLUE
- [ ] Verify error messages are clear
- [ ] Fix test script
- [ ] Re-run pipeline successfully

### Edge Case Testing
- [ ] Test with non-existent model (should fail gracefully)
- [ ] Test with invalid version (should fail gracefully)
- [ ] Test rejection of approval (should stop pipeline)
- [ ] Test timeout of approval (should timeout and stop)
- [ ] Test with skip_staging_tests: true
- [ ] Test with different instance types

## Phase 5: Production Validation

### Pre-Production Checks
- [ ] Review all test results from dev environment
- [ ] Verify all stages completed successfully
- [ ] Check deployment metrics in Azure Portal
- [ ] Verify endpoint responses are correct
- [ ] Document any issues and resolutions
- [ ] Get approval from stakeholders to proceed

### Production Deployment
- [ ] Run pipeline with production configuration:
  - [ ] environment: `prod`
  - [ ] model_name: `<production-model>`
  - [ ] model_version: `<specific-version>`
  - [ ] Appropriate instance types and counts
- [ ] Monitor all stages closely
- [ ] Have rollback plan ready
- [ ] Document any issues

### Post-Production Validation
- [ ] Verify staging endpoint is operational
- [ ] Verify production endpoint is operational
- [ ] Check traffic distribution (100% GREEN)
- [ ] Run manual tests against endpoints
- [ ] Check Azure Monitor metrics
- [ ] Verify no errors in logs
- [ ] Compare with previous deployment (if any)
- [ ] Document deployment details

## Phase 6: Monitoring & Documentation

### Monitoring Setup
- [ ] Configure Azure Monitor alerts:
  - [ ] High error rate alert
  - [ ] High latency alert
  - [ ] Low availability alert
- [ ] Set up Azure ML workspace monitoring
- [ ] Configure deployment dashboards
- [ ] Set up log analytics (if needed)
- [ ] Test alert notifications

### Documentation
- [ ] Document deployment process
- [ ] Document approval workflow
- [ ] Document rollback procedure
- [ ] Document troubleshooting steps
- [ ] Create runbook for common scenarios
- [ ] Train team on new pipeline
- [ ] Update operational procedures

### Team Enablement
- [ ] Share pipeline documentation with team
- [ ] Conduct training session on Azure DevOps pipeline
- [ ] Demonstrate approval process
- [ ] Show how to monitor deployments
- [ ] Explain rollback procedure
- [ ] Share troubleshooting guide
- [ ] Establish support process

## Phase 7: Optimization

### Performance Tuning
- [ ] Review pipeline execution times
- [ ] Identify bottlenecks
- [ ] Optimize wait times if needed
- [ ] Adjust retry logic if needed
- [ ] Consider parallel execution (if applicable)

### Cost Optimization
- [ ] Review compute instance types
- [ ] Right-size instances based on actual usage
- [ ] Consider auto-scaling policies
- [ ] Review instance counts
- [ ] Implement cost alerts
- [ ] Document cost savings

### Process Improvement
- [ ] Gather feedback from team
- [ ] Identify pain points
- [ ] Propose improvements
- [ ] Update documentation with learnings
- [ ] Consider additional automation
- [ ] Plan for future enhancements

## Phase 8: Decommissioning (Optional)

### GitHub Actions Cleanup
- [ ] Document final GitHub Actions deployment
- [ ] Archive GitHub Actions workflow
- [ ] Update README to point to Azure DevOps
- [ ] Disable GitHub Actions workflow (or delete)
- [ ] Preserve GitHub Actions logs for reference
- [ ] Update any links or references

### Communication
- [ ] Announce migration completion
- [ ] Share Azure DevOps pipeline link
- [ ] Update documentation and wikis
- [ ] Update deployment procedures
- [ ] Inform stakeholders
- [ ] Celebrate success! 🎉

## Quick Reference

### Critical Configuration Items
- **Service Connection**: `azure-mlops-service-connection`
- **Variable Group**: `mlops-infrastructure`
- **Environments**: `staging`, `production-approval`, `production`
- **Pipeline Path**: `/azure-pipelines/cd-deploy.yml`

### Key Parameters
- `environment`: `dev` or `prod`
- `model_name`: Your model name (case-sensitive)
- `model_version`: Version number or `latest`
- `skip_staging_tests`: `false` (recommended)

### Important Links
- Pipeline Documentation: `azure-pipelines/README.md`
- Quick Start Guide: `azure-pipelines/QUICKSTART.md`
- Conversion Notes: `azure-pipelines/CONVERSION_NOTES.md`

### Support Contacts
- Azure DevOps Admin: ___________________
- Azure ML Admin: ___________________
- Production Approvers: ___________________
- Team Lead: ___________________

## Notes

Use this section to track any issues, workarounds, or customizations:

```
Date: _________
Issue: 
Resolution: 

Date: _________
Issue: 
Resolution: 

Date: _________
Issue: 
Resolution: 
```

---

**Migration Status**: 
- [ ] Not Started
- [ ] In Progress
- [ ] Testing
- [ ] Completed

**Migration Date**: ___________________  
**Completed By**: ___________________  
**Sign-off**: ___________________

