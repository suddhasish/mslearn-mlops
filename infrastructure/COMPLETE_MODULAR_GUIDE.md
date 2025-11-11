# Complete Modular Infrastructure - Deployment Guide

## 🎯 Overview

Your MLOps infrastructure is now **fully modularized** with ALL components organized into focused, reusable modules. No .tf files remain in the root except orchestration files.

## 📁 New Structure

```
infrastructure/
├── main-new.tf              # Complete orchestration (ALL 9 modules)
├── outputs-new.tf           # Aggregate module outputs  
├── variables.tf             # Input variables
├── backend.tf               # Terraform state configuration
├── terraform.tfvars.dev-edge-learning    # DEV environment
├── terraform.tfvars.prod                 # PROD environment
│
├── modules/
│   ├── networking/          # VNet, Subnets, NSGs
│   ├── storage/             # Storage Account, ACR
│   ├── ml-workspace/        # ML Workspace, Key Vault, App Insights, Compute
│   ├── aks/                 # Kubernetes cluster
│   ├── rbac/                # Custom roles, service principals, identities
│   ├── private-endpoints/   # Private DNS zones, private endpoints
│   ├── cache/               # Redis cache with monitoring
│   ├── devops-integration/  # Data Factory, Power BI, SQL, Event Grid, Functions
│   └── cost-management/     # Budgets, automation, cost optimization
│
└── environments/
    ├── dev/
    └── prod/
```

## 🚀 Quick Start

### Option 1: Use Automation Script

```powershell
cd infrastructure
.\setup-modular-infrastructure.ps1 -ProjectName "your-project-name"
```

### Option 2: Manual Steps

```powershell
# 1. Backup existing structure
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
mkdir "backup-$timestamp"
Copy-Item *.tf "backup-$timestamp\"

# 2. Activate new modular structure
Move-Item main.tf main-old.tf -Force
Move-Item outputs.tf outputs-old.tf -Force
Move-Item main-new.tf main.tf -Force
Move-Item outputs-new.tf outputs.tf -Force

# 3. Initialize Terraform
terraform init -upgrade

# 4. Validate
terraform validate

# 5. Plan for DEV
terraform plan -var-file="terraform.tfvars.dev-edge-learning"

# 6. Apply
terraform apply -var-file="terraform.tfvars.dev-edge-learning"
```

## 🏗️ Module Overview

### Core Infrastructure (Always Deployed)

| Module | Components | Purpose |
|--------|------------|---------|
| **networking** | VNet, 3 Subnets, 2 NSGs | Network foundation |
| **storage** | Storage Account, ACR | Blob storage, container images |
| **ml-workspace** | ML Workspace, Key Vault, App Insights, Log Analytics, Compute | ML experimentation & training |
| **aks** | Kubernetes cluster | Model serving & orchestration |

### Security & Identity (Optional)

| Module | Components | Enabled By | Cost Impact |
|--------|------------|------------|-------------|
| **rbac** | Custom roles, CI/CD identity, managed identities | `enable_custom_roles`, `enable_cicd_identity` | Minimal |
| **private-endpoints** | Private DNS zones, private endpoints | `enable_private_endpoints` | ~$10/month/endpoint |

### Performance & Caching (Optional)

| Module | Components | Enabled By | Cost Impact |
|--------|------------|------------|-------------|
| **cache** | Redis Standard C1, monitoring alerts | `enable_redis_cache` | ~$15/month |

### DevOps & Analytics (Optional)

| Module | Components | Enabled By | Cost Impact |
|--------|------------|------------|-------------|
| **devops-integration** | Data Factory, Power BI (A1), SQL (GP_S_Gen5_1), Event Grid, Functions, Stream Analytics, Event Hub, Synapse, Communication Service | `enable_devops_integration`, `enable_powerbi`, `enable_mssql`, etc. | ~$500-1500/month |

### Cost Management (Always Deployed)

| Module | Components | Enabled By | Cost Impact |
|--------|------------|------------|-------------|
| **cost-management** | Budget alerts, automation account, runbooks | `enable_cost_alerts`, `enable_data_factory`, `enable_logic_app` | Minimal |

## 🌍 Environments

### DEV Environment (`terraform.tfvars.dev-edge-learning`)
- **Purpose**: Learning & development
- **AKS**: 1 node, no auto-scaling
- **Cost**: ~$75/month
- **Features Enabled**: AKS, API Management, Front Door, Traffic Manager
- **Features Disabled**: Redis, DevOps Integration, Private Endpoints, GPU

### PROD Environment (`terraform.tfvars.prod`)
- **Purpose**: Production workloads
- **AKS**: 3 nodes, auto-scaling (2-10 nodes)
- **Cost**: ~$500/month
- **Features Enabled**: All core + Private Endpoints, Custom RBAC, CI/CD Identity
- **Features Optionally Enabled**: Redis, DevOps Integration

## 📊 Feature Flags

Control what gets deployed using these variables:

### Core Features
```hcl
enable_aks_deployment      = true   # Kubernetes cluster
enable_api_management      = true   # API Gateway
enable_front_door          = true   # CDN & WAF
enable_traffic_manager     = true   # Global load balancer
```

### Security
```hcl
enable_private_endpoints   = false  # Private networking
enable_custom_roles        = false  # Custom RBAC roles
enable_cicd_identity       = false  # CI/CD service principal
enable_purge_protection    = false  # Key Vault purge protection
```

### Performance
```hcl
enable_redis_cache         = false  # Redis caching
enable_gpu_compute         = false  # GPU compute cluster
```

### DevOps Integration
```hcl
enable_devops_integration  = false  # Master switch
enable_data_factory        = false  # Data pipelines
enable_powerbi             = false  # Analytics dashboards
enable_mssql               = false  # SQL database
enable_synapse             = false  # Advanced analytics
```

### Cost Management
```hcl
enable_cost_alerts         = true   # Budget monitoring
enable_logic_app           = false  # Cost optimization workflows
monthly_budget_amount      = 75     # Monthly budget in USD
```

## 🔄 Migration from Old Structure

If you have existing infrastructure:

### State Migration Approach

```powershell
# 1. Create new modular infrastructure in parallel
terraform plan -var-file="terraform.tfvars.dev-edge-learning" -out=tfplan

# 2. Review the plan carefully - expect recreations

# 3. Apply with approval
terraform apply tfplan

# 4. Migrate state (if needed)
terraform state mv azurerm_virtual_network.mlops module.networking.azurerm_virtual_network.mlops
# Repeat for each resource...
```

### Fresh Deployment Approach (Recommended)

```powershell
# 1. Destroy old infrastructure
terraform destroy -var-file="terraform.tfvars.dev-edge-learning"

# 2. Activate new structure
.\restructure-infrastructure.ps1 -ProjectName "your-project"

# 3. Deploy fresh
terraform init
terraform apply -var-file="terraform.tfvars.dev-edge-learning"
```

## 🧪 Testing

### Validate Structure
```powershell
.\validate-structure.ps1
```

### Test DEV Environment
```powershell
terraform plan -var-file="terraform.tfvars.dev-edge-learning"
```

### Test PROD Environment
```powershell
terraform plan -var-file="terraform.tfvars.prod"
```

## 📈 Cost Estimates

### DEV Environment
- **Base**: ~$50/month (Storage, ML Workspace, 1-node AKS)
- **+ API Gateway**: ~$15/month
- **+ Front Door**: ~$10/month
- **Total**: ~$75/month

### PROD Environment
- **Base**: ~$300/month (Storage, ML Workspace, 3-node AKS with auto-scaling)
- **+ API Gateway**: ~$35/month
- **+ Front Door**: ~$20/month
- **+ Private Endpoints**: ~$40/month (4 endpoints)
- **+ Redis Cache**: ~$15/month
- **+ Custom RBAC/Identity**: Minimal
- **Total**: ~$410-500/month (before DevOps integration)

### Optional DevOps Integration
- **Power BI Embedded (A1)**: ~$245/month
- **SQL Database (GP_S_Gen5_1)**: ~$90/month (with auto-pause)
- **Data Factory**: Pay-per-use (~$50-200/month)
- **Stream Analytics (3 SU)**: ~$250/month
- **Event Hub**: ~$20/month
- **Synapse**: Pay-per-query (~$100-500/month)
- **Total DevOps**: ~$500-1500/month additional

## 🔐 Security Best Practices

### DEV Environment
- Public endpoints (cost-effective learning)
- No purge protection (easier cleanup)
- Shared credentials OK

### PROD Environment
- **Enable** `enable_private_endpoints = true`
- **Enable** `enable_purge_protection = true`
- **Enable** `enable_custom_roles = true`
- **Enable** `enable_cicd_identity = true`
- Use Azure AD authentication
- Enable audit logging (90-day retention)

## 🤝 GitHub Actions Integration

The infrastructure is ready for GitHub Actions deployment. Your pipeline file:

`.github/workflows/infrastructure-deploy.yml`

Key workflow:
1. Checkout code
2. Setup Terraform
3. `terraform init`
4. `terraform plan -var-file="terraform.tfvars.$ENV"`
5. `terraform apply -var-file="terraform.tfvars.$ENV"`

## 📚 Module Documentation

Each module has its own README:
- See `modules/*/README.md` for detailed documentation
- Variables, outputs, and usage examples included

## 🐛 Troubleshooting

### Module Not Found Error
```
terraform init -upgrade
```

### State Lock Error
```powershell
# If using Azure backend
az storage blob delete --account-name <storage> --container-name <container> --name terraform.tflock
```

### Variable Not Defined
Check that your tfvars file includes all required variables from `variables.tf`

### Private Endpoint Creation Fails
Ensure you have network permissions and the subnet is properly configured

## 📞 Support

For issues:
1. Check module-specific README files
2. Review `MODULARIZATION_GUIDE.md`
3. Run `.\validate-structure.ps1` for diagnostics

## 🎉 Success Criteria

✅ All modules in `modules/` directory  
✅ No loose .tf files in root (except main.tf, outputs.tf, variables.tf, backend.tf)  
✅ Both DEV and PROD tfvars configured  
✅ `terraform validate` passes  
✅ `terraform plan` shows expected resources  
✅ GitHub Actions pipeline ready

**Your infrastructure is now production-grade and fully modular! 🚀**
