# MLOps Infrastructure Architecture

Comprehensive architecture diagram showing all Azure resources defined in Terraform, organized by layer and feature flags.

## Core Infrastructure (Always Deployed)

```mermaid
flowchart TB
    subgraph Core["Core Platform (Always)"]
        RG[Resource Group]
        VNet[Virtual Network]
        MLSubnet[ML Subnet]
        AKSSubnet[AKS Subnet]
        PESubnet[Private Endpoint Subnet]
        MLNSG[ML NSG]
        AKSNSG[AKS NSG]
    end
    
    subgraph Storage["Storage & Registry"]
        STG[Storage Account]
        ACR[Container Registry]
        KV[Key Vault]
    end
    
    subgraph MLPlatform["ML Platform"]
        AML[Azure ML Workspace]
        CPUCluster[CPU Compute Cluster]
        GPUCluster[GPU Compute Cluster]
    end
    
    subgraph Monitoring["Observability (Always)"]
        LA[Log Analytics]
        AI[Application Insights]
        ActionGroup[Monitor Action Group]
        Alerts[Metric Alerts]
        Workbook[Workbook Dashboard]
    end
    
    RG --> VNet
    VNet --> MLSubnet
    VNet --> AKSSubnet
    VNet --> PESubnet
    MLSubnet --> MLNSG
    AKSSubnet --> AKSNSG
    AML --> STG
    AML --> KV
    AML --> ACR
    AML --> LA
    AML --> AI
    CPUCluster --> AML
    GPUCluster --> AML
    
    classDef core fill:#e1f5ff,stroke:#0078d4,stroke-width:2px;
    classDef storage fill:#fff4ce,stroke:#f4b400,stroke-width:2px;
    classDef ml fill:#d4edda,stroke:#28a745,stroke-width:2px;
    classDef monitor fill:#f8d7da,stroke:#dc3545,stroke-width:2px;
    
    class RG,VNet,MLSubnet,AKSSubnet,PESubnet,MLNSG,AKSNSG core;
    class STG,ACR,KV storage;
    class AML,CPUCluster,GPUCluster ml;
    class LA,AI,ActionGroup,Alerts,Workbook monitor;
```

## Optional: Serving & Edge Stack (enable_aks_deployment, enable_api_management, enable_front_door, enable_traffic_manager)

```mermaid
flowchart LR
    User[Users/Clients]
    
    subgraph Edge["Edge Routing (Optional)"]
        FD[Front Door]
        TM[Traffic Manager]
    end
    
    subgraph API["API Layer (Optional)"]
        APIM[API Management]
    end
    
    subgraph Serving["Serving (Optional)"]
        AKS[AKS Cluster]
        GPUPool[AKS GPU Node Pool]
    end
    
    User --> FD
    FD --> TM
    TM --> APIM
    APIM --> AKS
    AKS --> GPUPool
    
    classDef edge fill:#cfe2ff,stroke:#0d6efd,stroke-width:2px;
    classDef api fill:#fff3cd,stroke:#ffc107,stroke-width:2px;
    classDef serving fill:#d1e7dd,stroke:#198754,stroke-width:2px;
    
    class FD,TM edge;
    class APIM api;
    class AKS,GPUPool serving;
```

## Optional: DevOps Integration (enable_devops_integration + sub-flags)

```mermaid
flowchart TD
    subgraph DevOps["DevOps Integration (Optional)"]
        ADF[Data Factory]
        EventGrid[Event Grid Topic]
        EventSub[Event Subscription]
        AppPlan[App Service Plan]
        FuncApp[Function App]
        EventHub[Event Hub]
        StreamAnalytics[Stream Analytics]
    end
    
    subgraph Analytics["Analytics (Optional)"]
        PowerBI[Power BI Embedded]
        SQL[SQL Server & DB]
        Synapse[Synapse Workspace]
        DLGen2[Data Lake Gen2]
    end
    
    subgraph AI["AI Services (Optional)"]
        CogServ[Cognitive Services]
        CommServ[Communication Service]
    end
    
    EventGrid --> EventSub
    EventSub --> FuncApp
    FuncApp --> EventHub
    EventHub --> StreamAnalytics
    StreamAnalytics --> SQL
    SQL --> PowerBI
    Synapse --> DLGen2
    
    classDef devops fill:#e7e7ff,stroke:#6610f2,stroke-width:2px;
    classDef analytics fill:#ffe5e5,stroke:#d63384,stroke-width:2px;
    classDef ai fill:#d5f4e6,stroke:#20c997,stroke-width:2px;
    
    class ADF,EventGrid,EventSub,AppPlan,FuncApp,EventHub,StreamAnalytics devops;
    class PowerBI,SQL,Synapse,DLGen2 analytics;
    class CogServ,CommServ ai;
```

## Optional: Cost Management & Optimization (enable_cost_alerts, enable_logic_app)

```mermaid
flowchart TD
    subgraph Cost["Cost Management (Optional)"]
        Budget[Consumption Budget]
        CostAlert[Cost Alert]
        CostADF[Data Factory - Cost Analytics]
        LogicApp[Logic App Workflow]
        AutoAcct[Automation Account]
        Runbook[Scale Resources Runbook]
        Schedule[Automation Schedule]
    end
    
    Budget --> CostAlert
    CostAlert --> LogicApp
    AutoAcct --> Runbook
    AutoAcct --> Schedule
    
    classDef cost fill:#fff4e5,stroke:#fd7e14,stroke-width:2px;
    class Budget,CostAlert,CostADF,LogicApp,AutoAcct,Runbook,Schedule cost;
```

## Optional: Security & RBAC (enable_custom_roles, enable_cicd_identity)

```mermaid
flowchart TD
    subgraph Security["Security & RBAC (Optional)"]
        CustomRole1[ML Data Scientist Role]
        CustomRole2[ML Engineer Role]
        CustomRole3[ML Viewer Role]
        AADApp[AAD Application]
        SP[Service Principal]
        UAI[User Assigned Identity]
    end
    
    subgraph PrivateNet["Private Networking (enable_private_endpoints)"]
        PE1[Storage Private Endpoint]
        PE2[Key Vault Private Endpoint]
        PE3[ACR Private Endpoint]
        PE4[ML Workspace Private Endpoint]
        DNS[Private DNS Zones]
    end
    
    AADApp --> SP
    PE1 --> DNS
    PE2 --> DNS
    PE3 --> DNS
    PE4 --> DNS
    
    classDef security fill:#f8d7da,stroke:#dc3545,stroke-width:2px;
    classDef private fill:#e2e3e5,stroke:#6c757d,stroke-width:2px;
    
    class CustomRole1,CustomRole2,CustomRole3,AADApp,SP,UAI security;
    class PE1,PE2,PE3,PE4,DNS private;
```

## Resource Summary by Profile

### YOUR CURRENT PROFILES

#### Minimal Profile (`terraform.tfvars.minimal`)
**Purpose**: Smallest safe footprint for training + inference (MVP)

**Core Infrastructure (Always Deployed)**
- ✅ Resource Group
- ✅ Virtual Network (VNet) with 3 Subnets (ML, AKS, Private Endpoint)
- ✅ Network Security Groups (ML NSG, AKS NSG)
- ✅ Storage Account (datasets, artifacts, model files)
- ✅ Azure Container Registry (ACR) - container images
- ✅ Key Vault (secrets, keys, certificates)

**ML Platform**
- ✅ Azure ML Workspace
- ✅ CPU Compute Cluster (autoscale to 0)
- ✅ GPU Compute Cluster (autoscale to 0)

**Monitoring & Observability**
- ✅ Log Analytics Workspace
- ✅ Application Insights
- ✅ Monitor Action Group (email alerts)
- ✅ Metric Alerts (ML job failures, storage availability)
- ✅ Workbook Dashboard
- ✅ Diagnostic Settings (ML Workspace, Storage)

**Cost Management**
- ✅ Consumption Budget ($50/month alert)
- ✅ Data Factory (cost analytics)
- ✅ Automation Account + Runbook (cost optimization)
- ✅ Automation Schedule (hourly checks)

**NOT Included in Minimal**
- ❌ AKS, APIM, Front Door, Traffic Manager
- ❌ DevOps Integration (Function App, Event Grid, Stream Analytics, Event Hub)
- ❌ Analytics (Power BI, SQL, Synapse, Data Lake Gen2)
- ❌ AI Services (Cognitive Services, Communication Service)
- ❌ Logic Apps
- ❌ Custom RBAC Roles, CI/CD Identity
- ❌ Private Endpoints

**Estimated Monthly Cost**: ~$0-50 (mostly ML compute when running jobs)

---

#### DEV Edge Learning Profile (`terraform.tfvars.dev-edge-learning`)
**Purpose**: Full-scale inference routing practice (AKS + APIM + Front Door + Traffic Manager)

**Everything in Minimal Profile, PLUS:**

**Serving & Edge Stack**
- ✅ AKS Cluster (1 node, Standard_D4s_v3) + GPU Node Pool
- ✅ API Management (Developer_1 SKU, public endpoint)
- ✅ Azure Front Door (Standard SKU, global entry point)
- ✅ Traffic Manager (DNS-based routing/failover)
- ✅ AKS Diagnostic Settings
- ✅ AKS Metric Alerts (CPU/memory usage)

**Still NOT Included**
- ❌ DevOps Integration (Function App, Event Grid, etc.)
- ❌ Analytics (Power BI, SQL, Synapse)
- ❌ Custom Roles, CI/CD Identity
- ❌ Private Endpoints (using public for learning simplicity)

**Estimated Monthly Cost**: ~$75-150 (AKS node + APIM + Front Door usage)

---

### Full Enterprise (Hypothetical - all flags enabled)
**For reference only - not defined in your current tfvars files**

- ✅ All Core + ML + Monitoring
- ✅ AKS + APIM + Front Door + Traffic Manager
- ✅ DevOps Integration (Function App, Event Grid, Stream Analytics, Event Hub)
- ✅ Analytics (Power BI, SQL Server + DB, Synapse + Data Lake Gen2)
- ✅ AI Services (Cognitive Services, Communication Service)
- ✅ Cost Management (Budget, Automation, Logic Apps)
- ✅ Custom Roles (ML Data Scientist, ML Engineer, ML Viewer), CI/CD Identity
- ✅ Private Endpoints (Storage, Key Vault, ACR, ML Workspace)
- ✅ Private DNS Zones

**Estimated Monthly Cost**: $500+ (APIM, SQL, Synapse, Function Apps, private networking)

## How to Verify Alignment

Use the verification script to compare your actual Azure resources with Terraform:

```powershell
# Compare Azure RG vs Terraform state
./deployment/verify-alignment.ps1 -ResourceGroupName <your-rg>

# Run plan to detect drift
./deployment/verify-alignment.ps1 -ResourceGroupName <your-rg> -VarFile infrastructure/terraform.tfvars.minimal -RunPlan
```

See `documentation/INFRA_ALIGNMENT.md` for details.

## Notes
- Diagrams reflect Terraform definitions, not necessarily deployed resources (depends on tfvars flags)
- For aligned infra: ensure `terraform plan` shows 0 to add/change/destroy
- Use import script (`infrastructure/import-existing-resources.sh`) if resources exist outside Terraform
