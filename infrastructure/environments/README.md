# MLOps Infrastructure - Environment-Specific Deployment

This directory contains environment-specific Terraform configurations following best practices for infrastructure-as-code management.

## Directory Structure

```
infrastructure/
├── modules/              # Shared reusable modules
│   ├── networking/
│   ├── storage/
│   ├── ml-workspace/
│   ├── aks/
│   ├── rbac/
│   ├── private-endpoints/
│   ├── cache/
│   ├── devops-integration/
│   └── cost-management/
└── environments/         # Environment-specific configurations
    ├── dev/             # Development environment
    │   ├── main.tf      # Dev orchestration & backend
    │   ├── outputs.tf   # Dev outputs
    │   ├── variables.tf # Dev variable declarations
    │   └── terraform.tfvars # Dev-specific values
    └── prod/            # Production environment
        ├── main.tf      # Prod orchestration & backend
        ├── outputs.tf   # Prod outputs
        ├── variables.tf # Prod variable declarations
        └── terraform.tfvars # Prod-specific values
```

## Key Features

### Separation of Concerns
- Each environment has its own **complete set of Terraform files**
- **Independent state files** per environment
- **Environment-specific backend configuration** embedded in main.tf
- **Different module configurations** per environment

### Development Environment
**Location:** `environments/dev/`

**Cost-Optimized Configuration:**
- Monthly budget: ~$50-75
- Single-node AKS cluster (no auto-scaling)
- No private endpoints
- No Redis cache
- No DevOps integration
- 30-day log retention
- Public endpoints for easy access

**Enabled Modules:**
- ✅ Networking (VNet, subnets, NSGs)
- ✅ Storage (Storage Account, Container Registry)
- ✅ ML Workspace (Key Vault, App Insights, Log Analytics, CPU compute)
- ✅ AKS (1 node, Standard_D2s_v3)
- ✅ RBAC (basic managed identity)
- ✅ Cost Management (budget alerts)

**Backend State:**
- Storage Account: `mlopstfstatesuddha`
- Resource Group: `rg-tfstate-dev`
- State File: `dev.mlops.tfstate`

### Production Environment
**Location:** `environments/prod/`

**Production-Grade Configuration:**
- Monthly budget: ~$500
- 3-node AKS cluster with auto-scaling (2-10 nodes)
- Private endpoints enabled
- Redis cache available (optional)
- DevOps integration available (optional)
- 90-day log retention
- Enhanced security (purge protection, RBAC)

**Enabled Modules:**
- ✅ All development modules PLUS:
- ✅ Private Endpoints (Storage, Key Vault, ACR, ML Workspace)
- ✅ Cache (Redis Standard C1)
- ✅ Enhanced RBAC (custom roles, CI/CD service principal)

**Backend State:**
- Storage Account: `mlopstfstateprodsuddha`
- Resource Group: `rg-tfstate-prod`
- State File: `prod.mlops.tfstate`

## Usage

### Deploy Development Environment

```bash
cd infrastructure/environments/dev

# Initialize Terraform (connects to dev state)
terraform init

# Review changes
terraform plan

# Deploy
terraform apply
```

### Deploy Production Environment

```bash
cd infrastructure/environments/prod

# Initialize Terraform (connects to prod state)
terraform init

# Review changes
terraform plan

# Deploy (requires manual approval)
terraform apply
```

### Destroy Environment

```bash
# For dev
cd infrastructure/environments/dev
terraform destroy

# For prod
cd infrastructure/environments/prod
terraform destroy
```

## GitHub Actions Integration

The CI/CD pipeline automatically uses the correct environment directory:

**Development Workflow:**
- Triggers on: Pull requests, manual dispatch with `environment=dev`
- Working directory: `./infrastructure/environments/dev`
- State file: `dev.mlops.tfstate`
- Auto-approves: Manual dispatch only

**Production Workflow:**
- Triggers on: Push to main, manual dispatch with `environment=prod`
- Working directory: `./infrastructure/environments/prod`
- State file: `prod.mlops.tfstate`
- Requires: Manual approval via GitHub Environment protection

## Configuration Management

### terraform.tfvars Structure

Both environments use the same variable structure but different values:

```hcl
# Required variables (must be set via secrets in CI/CD)
project_name       = "VAR_PROJECT_NAME"      # Injected from GitHub secret
location           = "VAR_AZURE_LOCATION"     # Injected from GitHub secret
notification_email = "VAR_NOTIFICATION_EMAIL" # Injected from GitHub secret

# Environment-specific toggles
enable_aks_deployment    = true/false
enable_private_endpoints = true/false
enable_redis_cache       = true/false
enable_custom_roles      = true/false
enable_cicd_identity     = true/false

# Sizing parameters
aks_node_count           = 1 (dev) / 3 (prod)
aks_enable_auto_scaling  = false (dev) / true (prod)
monthly_budget_amount    = 75 (dev) / 500 (prod)
```

### Secrets Required

Set these in GitHub Repository Settings → Secrets:

1. **PROJECT_NAME**: Your project prefix (e.g., "mlops-demo")
2. **AZURE_LOCATION**: Azure region (e.g., "eastus")
3. **NOTIFICATION_EMAIL**: Email for budget alerts
4. **AZURE_CLIENT_SECRET**: Azure service principal credentials (JSON)

## Best Practices

### ✅ DO

- Keep environments isolated - never mix dev/prod deployments
- Test changes in dev before promoting to prod
- Use version control for all terraform.tfvars changes
- Review plans carefully before applying
- Tag resources consistently using common_tags

### ❌ DON'T

- Don't manually edit resources in Azure Portal (use Terraform)
- Don't share state files between environments
- Don't commit secrets to terraform.tfvars (use GitHub secrets)
- Don't run terraform from root directory (always use environment dirs)
- Don't skip terraform plan before apply

## Module Paths

All modules are referenced using relative paths from environment directories:

```hcl
module "networking" {
  source = "../../modules/networking"
  # ...
}
```

This allows both dev and prod to share the same module code while configuring them differently.

## State Management

### Backend Configuration

Each environment has its own backend configuration in `main.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-<env>"
    storage_account_name = "mlopstfstate<env>suddha"
    container_name       = "tfstate"
    key                  = "<env>.mlops.tfstate"
    subscription_id      = "b2b8a5e6-9a34-494b-ba62-fe9be95bd398"
  }
}
```

### State Locking

- Azure Storage provides automatic state locking
- If state is locked, GitHub Actions will attempt force-unlock
- Manual unlock: `terraform force-unlock <LOCK_ID>`

## Troubleshooting

### "Module not found" error
```bash
# Ensure you're in the correct directory
cd infrastructure/environments/dev  # or prod
terraform init -upgrade
```

### "Backend configuration changed"
```bash
terraform init -reconfigure
```

### "State locked" error
```bash
# Get lock ID from error message
terraform force-unlock <LOCK_ID>
```

### Import existing resources
```bash
cd infrastructure
./import-existing-resources.sh <PROJECT_NAME> <ENVIRONMENT> <SUBSCRIPTION_ID>
```

## Cost Optimization

### Development
- Use minimal node counts (1 node)
- Disable unused features (private endpoints, cache, GPU)
- Use public endpoints (no egress costs)
- 30-day log retention
- **Estimated cost: $50-75/month**

### Production
- Right-size node counts (3-10 nodes with auto-scaling)
- Enable security features (private endpoints, purge protection)
- 90-day log retention for compliance
- Use reserved instances for cost savings (manual setup)
- **Estimated cost: $410-500/month**

## Next Steps

1. **Initial Setup:**
   ```bash
   cd infrastructure/environments/dev
   terraform init
   terraform plan
   terraform apply
   ```

2. **Verify Deployment:**
   - Check Azure Portal for resources
   - Test ML Workspace: https://ml.azure.com
   - Verify AKS cluster: `az aks get-credentials`

3. **Run ML Training:**
   ```bash
   az ml job create --file src/job.yml
   ```

4. **Monitor Costs:**
   - Azure Cost Management
   - Budget alerts configured automatically
   - Log Analytics for usage metrics

## Support

For issues or questions:
- Check documentation in `/documentation` directory
- Review GitHub Actions logs for deployment errors
- Consult Azure Portal for resource status
- Review Terraform state: `terraform show`
