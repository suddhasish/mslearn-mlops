# Resource Usage Mapping - MLOps Pipeline

This document shows how each Terraform-deployed resource is used in the MLOps workflows.

## 📦 Deployed Resources (DEV Environment)

Based on your infrastructure screenshot:

| Resource Name | Resource Type | Status |
|---------------|---------------|---------|
| `mlopsnew-dev-ai` | Application Insights | ✅ Deployed |
| `mlopsnew-dev-aks` | Kubernetes service | ✅ Deployed |
| `mlopsnew-dev-aks-nsg` | Network security group | ✅ Deployed |
| `mlopsnew-dev-auto-cost` | Automation Account | ✅ Deployed |
| `mlopsnew-dev-cost-alerts-ag` | Action group | ✅ Deployed |
| `mlopsnew-dev-kv-3kxldb` | Key Vault | ✅ Deployed |
| `mlopsnew-dev-law` | Log Analytics workspace | ✅ Deployed |
| `mlopsnew-dev-ml-identity` | Managed Identity | ✅ Deployed |
| `mlopsnew-dev-ml-nsg` | Network security group | ✅ Deployed |
| `mlopsnew-dev-mlw` | Azure Machine Learning workspace | ✅ Deployed |
| `mlopsnew-dev-underutilization-alert` | Log search alert rule | ✅ Deployed |
| `mlopsnew-dev-vnet` | Virtual network | ✅ Deployed |
| `mlopsnewdevacr3kxldb` | Container registry | ✅ Deployed |
| `mlopsnewdevst3kxldb` | Storage account | ✅ Deployed |
| `Scale-MLOps-Resources` | Runbook | ✅ Deployed |

---

## 🔄 Resource Usage in Workflows

### 1. **Azure Machine Learning Workspace** (`mlopsnew-dev-mlw`)

**Used In:** All ML workflows

**Purpose:** Central hub for ML operations

**Usage:**
```yaml
# cd-deploy.yml
az ml online-endpoint create \
  --workspace-name "${{ needs.resolve-inputs.outputs.aml_workspace }}" \
  # Value: mlopsnew-dev-mlw

az ml job create \
  --workspace-name mlopsnew-dev-mlw \
  --file jobs/train-job.yml
```

**Operations:**
- ✅ Register models
- ✅ Create online endpoints
- ✅ Deploy model versions
- ✅ Manage deployments (blue/green)
- ✅ Track experiments
- ✅ Monitor model performance

**Portal Link:**
`https://ml.azure.com/workspaces/mlopsnew-dev-mlw`

---

### 2. **Container Registry** (`mlopsnewdevacr3kxldb`)

**Used In:** Docker image building and deployment workflows

**Purpose:** Store Docker images for model inference

**Usage:**
```yaml
# Build and push custom inference images
- name: Build Docker Image
  run: |
    az acr login --name mlopsnewdevacr3kxldb
    docker build -t mlopsnewdevacr3kxldb.azurecr.io/inference:${{ github.sha }} .
    docker push mlopsnewdevacr3kxldb.azurecr.io/inference:${{ github.sha }}

# Deploy from ACR
- name: Deploy Model with Custom Image
  run: |
    az ml online-deployment create \
      --endpoint-name my-endpoint \
      --image mlopsnewdevacr3kxldb.azurecr.io/inference:latest
```

**Operations:**
- ✅ Store custom inference containers
- ✅ Store preprocessing images
- ✅ Version control for Docker images
- ✅ Integration with AML deployments
- ✅ Pull images for AKS deployments

**Admin Credentials:**
```bash
az acr credential show --name mlopsnewdevacr3kxldb
```

---

### 3. **Kubernetes Service (AKS)** (`mlopsnew-dev-aks`)

**Used In:** Production model deployment workflows

**Purpose:** Container orchestration for scalable inference

**Usage:**
```yaml
# Deploy to AKS
- name: Deploy Model to AKS
  run: |
    # Get AKS credentials
    az aks get-credentials \
      --name mlopsnew-dev-aks \
      --resource-group mlopsnew-dev-rg
    
    # Deploy inference service
    kubectl apply -f kubernetes/ml-inference-deployment.yaml
    
    # Scale deployment
    kubectl scale deployment ml-inference --replicas=3
    
    # Check status
    kubectl get pods -l app=ml-inference
```

**Kubernetes Resources Deployed:**
```yaml
# kubernetes/ml-inference-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-inference
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ml-inference
  template:
    spec:
      containers:
      - name: inference
        image: mlopsnewdevacr3kxldb.azurecr.io/inference:latest
        ports:
        - containerPort: 8080
```

**Operations:**
- ✅ Host scalable inference endpoints
- ✅ Auto-scaling based on load
- ✅ Rolling updates
- ✅ Health monitoring
- ✅ Load balancing

**Access:**
```bash
az aks get-credentials --name mlopsnew-dev-aks --resource-group mlopsnew-dev-rg
kubectl get nodes
kubectl get services
```

---

### 4. **Key Vault** (`mlopsnew-dev-kv-3kxldb`)

**Used In:** Secret management across all workflows

**Purpose:** Secure storage of credentials and API keys

**Usage:**
```yaml
# Store secrets
- name: Store Model API Key
  run: |
    az keyvault secret set \
      --vault-name mlopsnew-dev-kv-3kxldb \
      --name model-api-key \
      --value "${{ secrets.MODEL_API_KEY }}"

# Retrieve secrets
- name: Get Database Connection String
  run: |
    DB_CONN=$(az keyvault secret show \
      --vault-name mlopsnew-dev-kv-3kxldb \
      --name db-connection-string \
      --query value -o tsv)
    echo "::add-mask::$DB_CONN"
```

**Typical Secrets Stored:**
- Model API keys
- Database connection strings
- External service credentials
- Encryption keys
- Certificates

**Operations:**
- ✅ Store endpoint keys after deployment
- ✅ Retrieve DB credentials for feature store
- ✅ Manage certificate rotation
- ✅ Secure configuration management

---

### 5. **Storage Account** (`mlopsnewdevst3kxldb`)

**Used In:** Data management and ML artifact storage

**Purpose:** Default datastore for ML workspace

**Usage:**
```yaml
# Upload training data
- name: Upload Dataset
  run: |
    az storage blob upload-batch \
      --account-name mlopsnewdevst3kxldb \
      --destination datasets \
      --source ./data/ \
      --auth-mode login

# Access from Python
- name: Load Data in Training Script
  run: |
    from azure.ai.ml import MLClient
    ml_client = MLClient(...)
    datastore = ml_client.datastores.get_default()
    # Datastore points to mlopsnewdevst3kxldb
```

**Containers Used:**
- `azureml-blobstore-*` - Default ML workspace datastore
- `datasets` - Training/test data
- `models` - Model artifacts
- `logs` - Training logs
- `cost-exports` - Cost management exports

**Operations:**
- ✅ Store training datasets
- ✅ Store model artifacts
- ✅ Store experiment logs
- ✅ Store inference batch results
- ✅ Cost export data

---

### 6. **Application Insights** (`mlopsnew-dev-ai`)

**Used In:** Monitoring and logging

**Purpose:** Application performance monitoring

**Usage:**
```yaml
# Automatic integration with ML Workspace
# Logs collected automatically from:
- Online endpoint requests
- Model scoring latency
- Deployment errors
- Custom metrics

# Query metrics
- name: Check Endpoint Performance
  run: |
    az monitor app-insights query \
      --app mlopsnew-dev-ai \
      --analytics-query "requests | where name contains 'score' | summarize avg(duration)"
```

**Metrics Tracked:**
- ✅ Endpoint request count
- ✅ Response time (latency)
- ✅ Error rates
- ✅ Model scoring duration
- ✅ Dependency failures

**Dashboard:**
`https://portal.azure.com → Application Insights → mlopsnew-dev-ai`

---

### 7. **Log Analytics Workspace** (`mlopsnew-dev-law`)

**Used In:** Centralized logging and diagnostics

**Purpose:** Collect and analyze logs from all resources

**Usage:**
```yaml
# Query deployment logs
- name: Check Deployment Logs
  run: |
    az monitor log-analytics query \
      --workspace mlopsnew-dev-law \
      --analytics-query "AzureDiagnostics | where Category == 'ModelDataCollectionEvent'"

# Monitor AKS logs
- name: Get AKS Container Logs
  run: |
    az monitor log-analytics query \
      --workspace mlopsnew-dev-law \
      --analytics-query "ContainerLog | where TimeGenerated > ago(1h)"
```

**Log Sources:**
- AML workspace operations
- AKS cluster metrics
- Container logs
- Network security group logs
- Key Vault access logs

---

### 8. **Managed Identity** (`mlopsnew-dev-ml-identity`)

**Used In:** Service-to-service authentication

**Purpose:** Passwordless authentication for ML workspace

**Usage:**
```yaml
# Automatic authentication
# ML Workspace uses this identity to access:
- Storage Account (mlopsnewdevst3kxldb)
- Key Vault (mlopsnew-dev-kv-3kxldb)
- Container Registry (mlopsnewdevacr3kxldb)

# No credentials needed in code
from azure.identity import DefaultAzureCredential
credential = DefaultAzureCredential()  # Uses managed identity
```

**Permissions:**
- ✅ Storage Blob Data Contributor on storage account
- ✅ AcrPull on container registry
- ✅ Key Vault Secrets User

---

### 9. **Virtual Network** (`mlopsnew-dev-vnet`)

**Used In:** Network isolation and security

**Purpose:** Private networking for resources

**Subnets:**
```yaml
- training-subnet (10.0.1.0/24)
  - ML compute clusters
  
- inference-subnet (10.0.2.0/24)
  - Online endpoints
  - AKS nodes
  
- private-endpoints-subnet (10.0.3.0/24)
  - Private endpoints for storage, keyvault, ACR
```

**Network Security Groups:**
- `mlopsnew-dev-ml-nsg` - ML subnet rules
- `mlopsnew-dev-aks-nsg` - AKS subnet rules

---

### 10. **Cost Management Resources**

#### **Automation Account** (`mlopsnew-dev-auto-cost`)
- Runs cost optimization runbooks
- Scale-MLOps-Resources runbook
- Automated resource cleanup

#### **Action Group** (`mlopsnew-dev-cost-alerts-ag`)
```yaml
# Receives alerts for:
- Budget threshold exceeded (75%)
- Resource underutilization
- Cost forecast exceeded

# Notifications sent to:
EMAIL: devops@example.com (configured in terraform.tfvars)
```

#### **Underutilization Alert** (`mlopsnew-dev-underutilization-alert`)
- Monitors CPU usage < 20% for 6 hours
- Triggers cost optimization actions

---

## 🔗 Complete Workflow Example

Here's how resources work together in a typical deployment:

```yaml
name: Train and Deploy Model

jobs:
  train:
    steps:
      # 1. Use Storage Account for data
      - name: Load Training Data
        run: |
          az storage blob download-batch \
            --account-name mlopsnewdevst3kxldb \
            --source datasets \
            --destination ./data
      
      # 2. Submit training to ML Workspace
      - name: Train Model
        run: |
          az ml job create \
            --workspace-name mlopsnew-dev-mlw \
            --resource-group mlopsnew-dev-rg \
            --file jobs/train-job.yml
      
      # 3. Register model (stored in Storage Account)
      - name: Register Model
        run: |
          az ml model create \
            --workspace-name mlopsnew-dev-mlw \
            --name diabetes-classifier \
            --version 1
  
  build-image:
    needs: train
    steps:
      # 4. Build custom inference image
      - name: Build and Push Image
        run: |
          az acr login --name mlopsnewdevacr3kxldb
          docker build -t mlopsnewdevacr3kxldb.azurecr.io/inference:v1 .
          docker push mlopsnewdevacr3kxldb.azurecr.io/inference:v1
  
  deploy:
    needs: build-image
    steps:
      # 5. Deploy to ML Workspace endpoint (uses Managed Identity)
      - name: Deploy to Staging
        run: |
          az ml online-deployment create \
            --endpoint-name ml-endpoint-staging \
            --workspace-name mlopsnew-dev-mlw \
            --model diabetes-classifier:1 \
            --instance-type Standard_DS2_v2
      
      # 6. Get endpoint key from Key Vault
      - name: Get Endpoint Key
        run: |
          KEY=$(az keyvault secret show \
            --vault-name mlopsnew-dev-kv-3kxldb \
            --name endpoint-key \
            --query value -o tsv)
      
      # 7. Monitor with Application Insights
      # Automatic - metrics flow to mlopsnew-dev-ai
      
      # 8. Deploy to AKS for production
      - name: Deploy to AKS
        run: |
          az aks get-credentials --name mlopsnew-dev-aks
          kubectl apply -f kubernetes/deployment.yaml
          # Image pulled from mlopsnewdevacr3kxldb
```

---

## 📊 Resource Dependencies

```
mlopsnew-dev-mlw (ML Workspace)
├── Uses: mlopsnewdevst3kxldb (Storage)
├── Uses: mlopsnew-dev-kv-3kxldb (Key Vault)
├── Uses: mlopsnew-dev-ai (App Insights)
├── Uses: mlopsnew-dev-law (Log Analytics)
├── Uses: mlopsnew-dev-ml-identity (Managed Identity)
└── Uses: mlopsnew-dev-vnet (Virtual Network)

mlopsnew-dev-aks (AKS)
├── Pulls from: mlopsnewdevacr3kxldb (Container Registry)
├── Uses: mlopsnew-dev-vnet (Virtual Network)
├── Uses: mlopsnew-dev-aks-nsg (Network Security Group)
└── Logs to: mlopsnew-dev-law (Log Analytics)

Cost Management
├── mlopsnew-dev-auto-cost (Automation)
├── mlopsnew-dev-cost-alerts-ag (Action Group)
└── mlopsnew-dev-underutilization-alert (Alert Rule)
```

---

## 🎯 Quick Reference

**Deploy a model:**
```bash
az ml online-deployment create \
  --workspace-name mlopsnew-dev-mlw \
  --resource-group mlopsnew-dev-rg \
  --endpoint-name my-endpoint \
  --name my-deployment \
  --model my-model:1
```

**Deploy to AKS:**
```bash
az aks get-credentials --name mlopsnew-dev-aks --resource-group mlopsnew-dev-rg
kubectl apply -f deployment.yaml
```

**Push Docker image:**
```bash
az acr login --name mlopsnewdevacr3kxldb
docker push mlopsnewdevacr3kxldb.azurecr.io/myimage:latest
```

**Store secret:**
```bash
az keyvault secret set --vault-name mlopsnew-dev-kv-3kxldb --name my-secret --value "..."
```

**Upload data:**
```bash
az storage blob upload-batch --account-name mlopsnewdevst3kxldb --source ./data --destination datasets
```

---

## 📝 Notes

- All resources are in the same resource group: `mlopsnew-dev-rg`
- Subscription: `b2b8a5e6-9a34-494b-ba62-fe9be95bd398`
- Region: East US
- Environment: Development
- Cost Budget: $75/month (configured in Terraform)

For more details, see:
- [Infrastructure Integration Guide](INFRASTRUCTURE_INTEGRATION.md)
- [Quick Reference](QUICK_REFERENCE_INFRA.md)
- [Terraform Configuration](infrastructure/environments/dev/)
