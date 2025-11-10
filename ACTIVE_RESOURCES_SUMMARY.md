# Active Resources Summary - Dev Edge Learning Profile

**Configuration File**: `terraform.tfvars.dev-edge-learning`  
**Date**: November 11, 2025  
**Estimated Monthly Cost**: ~$75-100 USD

---

## 📊 Resource Overview

Based on your **dev-edge-learning** configuration, here's what will be deployed:

### ✅ **ENABLED Resources** (Will Be Created)

#### **Core ML Infrastructure** (Always Created)
1. **Resource Group**: `mlops-dev-learning-dev-*`
2. **Azure Machine Learning Workspace**: Central ML hub
3. **Storage Account**: Blob storage for datasets, models, logs (GRS)
4. **Container Registry**: Docker images for ML containers (Basic SKU)
5. **Key Vault**: Secrets management (RBAC-enabled)
6. **Virtual Network**: Network isolation with 4 subnets
7. **Log Analytics Workspace**: Centralized logging (30-day retention)
8. **Application Insights**: APM and monitoring
9. **ML Compute Cluster (CPU)**: Standard_DS3_v2 for training jobs

#### **Inference & API Stack** (Enabled in Your Config)
10. **AKS Cluster**: 1 node, Standard_D4s_v3 (no autoscaling)
11. **API Management**: Developer_1 SKU with rate limiting policies
12. **Azure Front Door**: Standard SKU for global routing
13. **Traffic Manager**: Performance-based routing

#### **Monitoring & Alerts**
14. **Monitor Action Group**: Email notifications
15. **SLO Alerts** (3 alerts):
    - P95 latency > 200ms
    - P99 latency > 500ms  
    - Error rate > 1%
16. **ML Job Failure Alert**: Log-based query for failed jobs
17. **Cost Budget Alert**: Alert at $75 threshold (80% of $75)
18. **Application Insights Workbook**: ML Operations Dashboard

#### **Cost Management**
19. **Consumption Budget**: $75/month monitoring
20. **Cost Export**: Daily cost data to storage

#### **Security & RBAC**
21. **Role Assignments** (8+):
    - AKS → Virtual Network (Network Contributor)
    - AKS → ACR (AcrPull)
    - ML Workspace → Storage (Contributor)
    - ML Workspace → Key Vault (Secrets Officer, Crypto Officer)
    - Terraform → Key Vault (Secrets Officer)

#### **Network Components**
22. **Subnets** (4):
    - ML Subnet (10.0.1.0/24)
    - AKS Subnet (10.0.2.0/23)
    - Private Endpoint Subnet (10.0.4.0/24)
    - API Management Subnet (10.0.5.0/24)
23. **Network Security Groups** (3)

---

### ❌ **DISABLED Resources** (Will NOT Be Created)

#### **Disabled via Feature Flags**
- ❌ **Redis Cache** (`enable_redis_cache = false`) - Save ~$15/month
- ❌ **GPU Compute Cluster** (`enable_gpu_compute = false`) - Requires quota approval
- ❌ **Private Endpoints** (`enable_private_endpoints = false`) - Adds ~$50/month
- ❌ **Power BI Embedded** (`enable_powerbi = false`) - Premium feature
- ❌ **SQL Server** (`enable_mssql = false`) - Not needed for basic ML
- ❌ **Logic App** (`enable_logic_app = false`) - Advanced automation
- ❌ **Communication Service** (`enable_communication_service = false`) - SMS/Email service
- ❌ **Custom RBAC Roles** (`enable_custom_roles = false`) - Requires elevated permissions
- ❌ **CI/CD Identity** (`enable_cicd_identity = false`) - AAD app creation
- ❌ **Azure Synapse** - Not enabled
- ❌ **Cognitive Services** - Not enabled
- ❌ **Data Factory** - Not enabled for cost analytics

#### **DevOps Integration Components** (Default Off)
- ❌ **Event Grid Topic** - Requires `enable_devops_integration = true`
- ❌ **Function App** - Event processing
- ❌ **Stream Analytics** - Real-time analytics
- ❌ **Automation Account** - Cost optimization runbooks

---

## 📁 Infrastructure Files Breakdown

### **main.tf** (Core Resources)
- Resource Group
- Virtual Network + Subnets
- Storage Account (GRS, versioning enabled)
- Key Vault (RBAC-enabled, soft delete)
- Container Registry (Basic SKU)
- ML Workspace (with system-assigned identity)
- ML Compute Cluster (CPU only)
- ~~GPU Compute Cluster~~ (Conditional: disabled)
- Application Insights (with workspace link)
- Log Analytics Workspace

### **aks.tf** (Kubernetes & API)
- AKS Cluster (1 node, Standard_D4s_v3)
- APIM Instance (Developer_1 SKU)
- APIM ML Inference API definition
- APIM Rate Limiting Policy (100 req/min, 1M req/month)
- Azure Front Door Profile + Endpoint
- Traffic Manager Profile
- Role Assignments (AKS → VNet, AKS → ACR)

### **monitoring.tf** (Observability)
- Application Insights (linked to Log Analytics)
- Log Analytics Saved Searches (SLO metrics)
- 3 SLO Alerts (P95/P99 latency, error rate)
- ML Job Failure Alert (log-based)
- Monitor Action Group (email notifications)
- Application Insights Workbook (ML dashboard)
- Diagnostic Settings (Storage, Key Vault, ACR)

### **rbac.tf** (Access Control)
- ML Workspace → Key Vault RBAC roles
- ML Workspace → Storage access
- Terraform → Key Vault Secrets Officer
- ~~CI/CD Service Principal~~ (Disabled)
- ~~Custom Role Definitions~~ (Disabled)

### **cost-management.tf** (Budget & Governance)
- Consumption Budget ($75 alert)
- Cost Export (daily to storage)
- ~~Automation Account~~ (Disabled: `enable_cost_alerts = true` but no Logic App)
- ~~Cost Optimization Runbooks~~ (Disabled)

### **cache.tf** (Optional Caching)
- ~~Redis Cache~~ (Disabled: `enable_redis_cache = false`)
- ~~Redis Key Vault Secrets~~ (Disabled)
- ~~Redis Monitoring Alerts~~ (Disabled)

### **private-endpoints.tf** (Network Security)
- ~~All Private Endpoints~~ (Disabled: `enable_private_endpoints = false`)
- ~~Private DNS Zones~~ (Disabled)

### **devops-integration.tf** (Advanced Automation)
- ~~Event Grid Topic~~ (Disabled: `enable_devops_integration = false`)
- ~~Function App~~ (Disabled)
- ~~Stream Analytics~~ (Disabled)
- ~~Power BI Embedded~~ (Disabled)
- ~~SQL Server~~ (Disabled)

---

## 🔢 Resource Count Summary

| Category | Count | Notes |
|----------|-------|-------|
| **Core Services** | 9 | ML Workspace, Storage, ACR, Key Vault, VNet, etc. |
| **Compute** | 2 | AKS (1 node), CPU Cluster |
| **Networking** | 7 | VNet, 4 Subnets, 3 NSGs |
| **API & Routing** | 3 | APIM, Front Door, Traffic Manager |
| **Monitoring** | 7 | App Insights, Log Analytics, 5 Alerts, Workbook |
| **Security & RBAC** | 8+ | Role assignments |
| **Cost Management** | 2 | Budget, Cost Export |
| **TOTAL ACTIVE** | **~38 resources** | Approximate count |

---

## 💰 Cost Breakdown (Estimated Monthly)

| Resource | SKU/Size | Est. Cost |
|----------|----------|-----------|
| **AKS Cluster** | 1 x D4s_v3 | ~$120-140 |
| **API Management** | Developer_1 | ~$50 |
| **ML Compute (CPU)** | Pay-per-use | Variable |
| **Storage Account** | GRS | ~$5-10 |
| **Container Registry** | Basic | ~$5 |
| **Log Analytics** | 30-day retention | ~$2-5 |
| **Application Insights** | Basic | ~$2-5 |
| **Front Door** | Standard | ~$35-40 |
| **Traffic Manager** | Basic | ~$0.50 |
| **Key Vault** | Operations | ~$1 |
| **Virtual Network** | Standard | Free |
| **Total (without compute jobs)** | | **~$220-260/month** |

> ⚠️ **NOTE**: Your budget is set to $75/month, but the infrastructure costs more than that. To reduce costs:
> - Disable AKS: `enable_aks_deployment = false` (saves ~$120)
> - Disable APIM: `enable_api_management = false` (saves ~$50)
> - Disable Front Door: `enable_front_door = false` (saves ~$35-40)
> 
> **Minimal cost** (ML Workspace + Storage + ACR): ~$15-20/month

---

## 🚀 Next Steps

### **1. Review Configuration**
```bash
cd infrastructure
cat terraform.tfvars.dev-edge-learning
```

### **2. Adjust Budget or Resources**
Choose one:

**Option A: Increase Budget** (Keep all services)
```hcl
monthly_budget_amount = 250  # Match actual costs
```

**Option B: Reduce Services** (Stay under $75)
```hcl
enable_aks_deployment = false
enable_api_management = false  
enable_front_door = false
enable_traffic_manager = false
monthly_budget_amount = 75
```

### **3. Initialize and Deploy**
```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan -var-file=terraform.tfvars.dev-edge-learning

# Deploy infrastructure
terraform apply -var-file=terraform.tfvars.dev-edge-learning
```

### **4. View Deployed Resources**
```bash
# List all resources in state
terraform state list

# Get resource outputs
terraform output
```

### **5. Optional: Enable Redis Cache**
When ready for caching (adds ~$15/month):
```hcl
enable_redis_cache = true
```

### **6. Optional: Request GPU Quota**
For GPU workloads:
1. Request quota: https://aka.ms/azquotas
2. Update config: `enable_gpu_compute = true`
3. Re-apply: `terraform apply`

---

## 📝 Configuration Files Reference

- **terraform.tfvars.minimal**: Bare minimum (~$15/month)
- **terraform.tfvars.dev-edge-learning**: Learning stack (~$220/month) ← **CURRENT**
- **terraform.tfvars.free-tier**: Azure free tier compatible
- **terraform.tfvars.example**: Template with all options

---

## 🔍 How to Check Active Resources

Since Terraform state is in Azure backend, you can:

### **Method 1: GitHub Actions Workflow**
View the pipeline output artifact `terraform-outputs-dev`

### **Method 2: Azure Portal**
1. Go to https://portal.azure.com
2. Search for resource group: `mlops-dev-learning-dev-*`
3. View all resources in the group

### **Method 3: Azure CLI**
```bash
# Login
az login

# List resources in resource group
az resource list --resource-group mlops-dev-learning-dev-* --output table
```

### **Method 4: Terraform State (Requires Init)**
```bash
cd infrastructure
terraform init  # This will connect to Azure backend
terraform state list
```

---

## ⚠️ Important Notes

1. **Budget Mismatch**: Your configuration will deploy ~$220/month of resources but budget is set to $75
2. **No GPU Cluster**: Disabled by default (requires quota approval)
3. **No Redis Cache**: Disabled by default (opt-in feature)
4. **Public Networking**: Private endpoints disabled for cost savings
5. **Single AKS Node**: No autoscaling configured (cost control)
6. **30-Day Log Retention**: Logs kept for 30 days only

---

## 🎯 Recommended Actions

1. **Align budget with costs** or reduce services
2. **Run `terraform plan`** to preview exact resource count
3. **Monitor spending** in Azure Cost Management
4. **Enable features gradually** as needed (Redis, GPU, etc.)
5. **Consider minimal profile** if learning environment doesn't need full API stack

