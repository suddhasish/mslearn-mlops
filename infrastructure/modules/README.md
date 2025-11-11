# MLOps Infrastructure Modules

This directory contains reusable Terraform modules for MLOps infrastructure on Azure.

## Module Structure

```
modules/
├── networking/          # VNet, Subnets, NSGs
├── storage/            # Storage Account, Container Registry
├── ml-workspace/       # ML Workspace, App Insights, Key Vault, Compute
├── aks/                # Azure Kubernetes Service
└── api-gateway/        # API Management, Front Door (optional)
```

## Module Descriptions

### Networking Module
**Purpose:** Provides network infrastructure with security controls

**Resources:**
- Virtual Network (10.0.0.0/16)
- ML Subnet (10.0.1.0/24) with service endpoints
- AKS Subnet (10.0.2.0/24)
- Private Endpoint Subnet (10.0.3.0/24)
- Network Security Groups for ML and AKS

**Outputs:** VNet ID, Subnet IDs, NSG IDs

### Storage Module
**Purpose:** Manages data storage and container images

**Resources:**
- Storage Account (GRS, versioning enabled)
- Azure Container Registry (Premium SKU)

**Outputs:** Storage Account details, ACR login server

### ML Workspace Module
**Purpose:** Core Azure ML infrastructure

**Resources:**
- Log Analytics Workspace
- Application Insights (linked to LA Workspace)
- Key Vault
- Machine Learning Workspace
- CPU Compute Cluster
- GPU Compute Cluster (optional)

**Outputs:** Workspace ID, Key Vault details, App Insights key

### AKS Module
**Purpose:** Kubernetes cluster for model serving

**Resources:**
- AKS Cluster (v1.29)
- GPU Node Pool (optional)
- Role assignments (AcrPull, Network Contributor)
- Security features: RBAC, Workload Identity, Microsoft Defender

**Outputs:** Cluster FQDN, kube config, identity IDs

## Usage Example

```hcl
module "networking" {
  source = "./modules/networking"
  
  resource_prefix     = "mlops-dev"
  location            = "eastus"
  resource_group_name = "mlops-dev-rg"
  tags                = local.common_tags
}

module "storage" {
  source = "./modules/storage"
  
  resource_prefix     = "mlops-dev"
  location            = "eastus"
  resource_group_name = "mlops-dev-rg"
  suffix              = "abc123"
  ml_subnet_id        = module.networking.ml_subnet_id
  tags                = local.common_tags
}
```

## Module Dependencies

```
networking (no dependencies)
    ↓
storage (requires: ml_subnet_id)
    ↓
ml-workspace (requires: ml_subnet_id, storage_account_id, container_registry_id)
    ↓
aks (requires: aks_subnet_id, vnet_id, container_registry_id, log_analytics_workspace_id)
```

## Benefits of Modular Design

1. **Reusability:** Use modules across multiple environments
2. **Maintainability:** Update modules independently
3. **Testing:** Test modules in isolation
4. **Clear Dependencies:** Explicit input/output relationships
5. **Separation of Concerns:** Each module has a single responsibility

## Migration from Monolithic Structure

The old structure had all resources in a single `main.tf` (500+ lines). The new modular structure:

- **Before:** `main.tf` (500 lines) - hard to maintain
- **After:** 4 modules (100-150 lines each) - easy to understand

## Best Practices

1. **Module Versioning:** Pin module versions in production
2. **Output Everything:** Expose all IDs, names, and connection strings
3. **Minimal Variables:** Only expose what needs to be configurable
4. **Documentation:** Document inputs, outputs, and examples
5. **Testing:** Use `terraform validate` on each module

## Future Enhancements

- **Monitoring Module:** Extract monitoring resources
- **Security Module:** Extract RBAC and private endpoints
- **Data Module:** Add Data Factory, Synapse modules
- **Registry:** Publish modules to Terraform Registry
