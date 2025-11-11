# MLOps Lifecycle Guide - End-to-End Implementation

Complete guide for executing all phases of MLOps with clear separation between infrastructure and ML pipeline concerns.

---

## Table of Contents

1. [Overview & Architecture](#overview--architecture)
2. [Phase 0: Prerequisites & Setup](#phase-0-prerequisites--setup)
3. [Phase 1: Infrastructure Deployment](#phase-1-infrastructure-deployment)
4. [Phase 2: Local Experimentation](#phase-2-local-experimentation)
5. [Phase 3: Training Pipeline](#phase-3-training-pipeline)
6. [Phase 4: Model Registration & Validation](#phase-4-model-registration--validation)
7. [Phase 5: Model Deployment](#phase-5-model-deployment)
8. [Phase 6: CI/CD Automation](#phase-6-cicd-automation)
9. [Phase 7: Monitoring & Operations](#phase-7-monitoring--operations)
10. [Troubleshooting](#troubleshooting)

---

## Overview & Architecture

### MLOps Layers

```
┌─────────────────────────────────────────────────────────────┐
│             CI/CD Layer (GitHub Actions)                     │
│  Infrastructure Pipeline │ ML Training │ Deployment          │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│          Infrastructure Layer (Terraform)                    │
│  ML Workspace │ AKS │ Storage │ ACR │ Key Vault │ APIM     │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│            ML Experimentation Layer                          │
│  Notebooks │ Training Scripts │ Data Preparation            │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│            ML Operations Layer                               │
│  Training Jobs │ Model Registry │ Inference Endpoints       │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│        Monitoring & Observability Layer                      │
│  Application Insights │ Log Analytics │ Alerts              │
└─────────────────────────────────────────────────────────────┘
```

### Configuration Separation

| Concern | File | Purpose |
|---------|------|---------|
| **Infrastructure** | `infrastructure/terraform.tfvars.dev-edge-learning` | Azure resources, networking, compute |
| **ML Pipeline** | `src/job.yml` | Training job, data, compute target |
| **Deployment** | `kubernetes/ml-inference-deployment.yaml` | Inference endpoint, replicas, resources |
| **CI/CD** | `.github/workflows/*.yml` | Automation workflows |

---

## Phase 0: Prerequisites & Setup

### 0.1 Install Required Tools

```powershell
# Azure CLI
winget install Microsoft.AzureCLI

# Terraform
winget install Hashicorp.Terraform

# Kubectl
az aks install-cli

# Python 3.8+
winget install Python.Python.3.11

# Git
winget install Git.Git

# Verify installations
az --version
terraform --version
kubectl version --client
python --version
git --version
```

### 0.2 Install Python Dependencies

```powershell
cd D:\MLOPS\MLOPS-AZURE\mslearn-mlops
pip install -r requirements.txt
```

Expected packages:
- `azure-ai-ml` - Azure ML SDK
- `mlflow` - Experiment tracking
- `scikit-learn` - ML algorithms
- `pandas`, `numpy` - Data processing

### 0.3 Azure Login & Setup

```powershell
# Login to Azure
az login

# List subscriptions
az account list --output table

# Set active subscription
az account set --subscription "your-subscription-name"

# Verify current subscription
az account show --query "{Name:name, SubscriptionId:id}" -o table
```

### 0.4 Create Service Principal for Automation

```powershell
# Get subscription ID
$SUBSCRIPTION_ID = az account show --query id -o tsv

# Create service principal with Contributor role
$sp = az ad sp create-for-rbac `
  --name "terraform-mlops-sp" `
  --role Contributor `
  --scopes "/subscriptions/$SUBSCRIPTION_ID" | ConvertFrom-Json

# Format for GitHub secret
$credentials = @{
    clientId = $sp.appId
    clientSecret = $sp.password
    subscriptionId = $SUBSCRIPTION_ID
    tenantId = $sp.tenant
} | ConvertTo-Json -Compress

Write-Host "`n✅ Service Principal Created!"
Write-Host "`nCopy this JSON for GitHub secret AZURE_CLIENT_SECRET:"
Write-Host $credentials
```

### 0.5 Configure GitHub Secrets

Navigate to: **GitHub Repository → Settings → Secrets and variables → Actions → New repository secret**

| Secret Name | Value | Example |
|------------|-------|---------|
| `PROJECT_NAME` | Unique project identifier | `azureml-dev` |
| `AZURE_LOCATION` | Azure region | `eastus` |
| `NOTIFICATION_EMAIL` | Email for alerts | `ops@company.com` |
| `AZURE_CLIENT_SECRET` | Service principal JSON | `{"clientId":"..."}` |

### 0.6 Clone Repository

```powershell
cd D:\MLOPS
git clone https://github.com/your-org/mslearn-mlops.git
cd mslearn-mlops
```

---

## Phase 1: Infrastructure Deployment

### 1.1 Review Dev Configuration

```powershell
# Open configuration file
code infrastructure/terraform.tfvars.dev-edge-learning
```

**Key Settings:**

```hcl
# Core (replaced by GitHub secrets at runtime)
project_name = "VAR_PROJECT_NAME"
location     = "VAR_AZURE_LOCATION"
environment  = "dev"

# Inference Stack (enabled for learning)
enable_aks_deployment = true      # Kubernetes cluster
enable_api_management = true      # API Gateway
enable_front_door     = true      # Global routing
enable_redis_cache    = false     # Optional caching

# DevOps Integration (disabled in dev)
enable_devops_integration = false
enable_data_factory      = false

# Cost
monthly_budget_amount = 75        # Alert threshold
enable_cost_alerts    = true

# Compute
aks_node_count = 1               # Single node for dev
aks_vm_size    = "Standard_D4s_v3"
```

### 1.2 Setup Terraform Backend

The backend stores Terraform state remotely in Azure Storage for team collaboration.

```powershell
cd deployment

# Run backend setup
./setup-terraform-backend.ps1 `
  -ProjectName "azureml" `
  -Environment "dev" `
  -Location "eastus"
```

**What this creates:**
- Resource Group: `terraform-state-rg`
- Storage Account: `tfstateXXXXX` (unique suffix)
- Container: `tfstate`
- State File: `dev.mlops.tfstate`

### 1.3 Verify Backend Configuration

```powershell
cd ../infrastructure
code backend.tf
```

Ensure configuration matches your backend:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstateXXXXX"  # Your actual storage account
    container_name       = "tfstate"
    key                  = "dev.mlops.tfstate"
  }
}
```

### 1.4 Deploy Infrastructure via GitHub Actions

**Option A: Via GitHub UI (Recommended)**

1. Navigate to: **GitHub → Actions → Infrastructure Deployment**
2. Click: **Run workflow**
3. Configure:
   - **Environment**: `dev`
   - **Destroy**: `false` (leave unchecked)
4. Click: **Run workflow**

**Option B: Via Git Push**

```powershell
# Make any infrastructure change
code infrastructure/terraform.tfvars.dev-edge-learning

# Commit and push
git add infrastructure/
git commit -m "Update dev infrastructure configuration"
git push origin main
```

### 1.5 Monitor Deployment

**Pipeline Stages:**

```
1. terraform-validate     ✓ Syntax check (2-3 min)
2. terraform-plan-dev     ✓ Generate plan (3-5 min)
3. terraform-apply-dev    ✓ Deploy resources (20-30 min)
   ├─ Requires approval
   └─ Creates Azure resources
```

**Expected Resources Created:**

| Resource Type | Name Pattern | Purpose |
|---------------|-------------|---------|
| Resource Group | `{project}-dev-rg` | Container for all resources |
| ML Workspace | `{project}-dev-ml` | Azure ML workspace |
| AKS Cluster | `{project}-dev-aks` | Kubernetes for inference |
| Storage Account | `{project}devst{hash}` | Data & model storage |
| Container Registry | `{project}devacr{hash}` | Docker images |
| Key Vault | `{project}-dev-kv` | Secrets management |
| API Management | `{project}-dev-apim` | API gateway |
| Front Door | `{project}-dev-fd` | Global routing |
| Application Insights | `{project}-dev-appinsights` | Monitoring |
| Log Analytics | `{project}-dev-logs` | Log aggregation |
| Virtual Network | `{project}-dev-vnet` | Networking |

**Typical Deployment Times:**
- ML Workspace: ~5 minutes
- AKS Cluster: ~12-15 minutes (longest)
- API Management: ~8-10 minutes
- Other resources: ~5-10 minutes
- **Total: 20-30 minutes**

### 1.6 Verify Deployment

```powershell
# Set variables
$RG_NAME = "azureml-dev-rg"  # Update with your actual name

# List all resources
az resource list --resource-group $RG_NAME --output table

# Get ML Workspace details
$WORKSPACE_NAME = az ml workspace list `
  --resource-group $RG_NAME `
  --query "[0].name" -o tsv

Write-Host "✅ ML Workspace: $WORKSPACE_NAME"

# Get AKS Cluster details
$AKS_NAME = az aks list `
  --resource-group $RG_NAME `
  --query "[0].name" -o tsv

Write-Host "✅ AKS Cluster: $AKS_NAME"

# Verify AKS is running
az aks show `
  --resource-group $RG_NAME `
  --name $AKS_NAME `
  --query "{Name:name, Status:provisioningState, Version:kubernetesVersion}" -o table

# Get AKS credentials for kubectl
az aks get-credentials `
  --resource-group $RG_NAME `
  --name $AKS_NAME `
  --overwrite-existing

# Verify kubectl access
kubectl get nodes
kubectl get namespaces
```

### 1.7 Access Azure ML Studio

```powershell
# Open ML Studio in browser
Write-Host "Opening Azure ML Studio..."
Start-Process "https://ml.azure.com"

# Or get direct workspace URL
$workspaceId = az ml workspace show `
  --name $WORKSPACE_NAME `
  --resource-group $RG_NAME `
  --query "id" -o tsv

Write-Host "Direct link: https://ml.azure.com/?workspace=$workspaceId"
```

---

## Phase 2: Local Experimentation

### 2.1 Configure Azure ML CLI

```powershell
# Install/upgrade Azure ML extension
az extension add -n ml --upgrade -y

# Set defaults to avoid repeating parameters
az configure --defaults `
  group=$RG_NAME `
  workspace=$WORKSPACE_NAME `
  location=$LOCATION
```

### 2.2 Explore Training Data

```powershell
cd experimentation

# List data files
Get-ChildItem data/

# Preview CSV data
Get-Content data/diabetes.csv -Head 20 | Format-Table
```

**Expected Data Structure:**
- CSV file with features: age, bmi, blood_pressure, glucose, etc.
- Target variable: diabetes diagnosis (0/1)
- ~400-1000 rows typical for demo dataset

### 2.3 Run Jupyter Notebook (Optional)

```powershell
# Install Jupyter if not already installed
pip install jupyter notebook

# Start Jupyter server
jupyter notebook train-classification-model.ipynb
```

**Notebook Sections:**
1. **Data Loading** - Read CSV, check shape, preview
2. **Data Exploration** - Statistics, distributions, correlations
3. **Data Preprocessing** - Handle missing values, normalize
4. **Model Training** - Train scikit-learn classifier
5. **Evaluation** - Calculate accuracy, confusion matrix
6. **Model Export** - Save model for deployment

### 2.4 Test Training Script Locally

```powershell
cd ../src

# Review training script
code train.py
```

**Key Script Components:**

```python
import mlflow
from sklearn.ensemble import RandomForestClassifier
import pandas as pd

def main(args):
    # Load data
    data = pd.read_csv(args.data_path)
    
    # Split features and target
    X = data.drop('target', axis=1)
    y = data['target']
    
    # Train model
    model = RandomForestClassifier()
    model.fit(X, y)
    
    # Log metrics
    mlflow.log_metric("accuracy", accuracy)
    
    # Save model
    mlflow.sklearn.log_model(model, "model")
```

**Test Locally:**

```powershell
# Create virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Install dependencies
pip install azure-ai-ml mlflow scikit-learn pandas numpy

# Run training script
python train.py --data-path ../experimentation/data --epochs 5
```

---

## Phase 3: Training Pipeline

### 3.1 Create Compute Cluster

```powershell
# Check if compute exists
az ml compute list -o table

# Create CPU cluster if needed
az ml compute create `
  --name cpu-cluster `
  --type amlcompute `
  --size Standard_DS3_v2 `
  --min-instances 0 `
  --max-instances 4 `
  --idle-time-before-scale-down 120

# Verify
az ml compute show --name cpu-cluster -o table
```

**Compute Options:**

| VM Size | vCPUs | RAM | Use Case | Cost/hr |
|---------|-------|-----|----------|---------|
| Standard_DS3_v2 | 4 | 14GB | General training | ~$0.27 |
| Standard_NC6 | 6 | 56GB | GPU training | ~$1.80 |
| Standard_D4s_v3 | 4 | 16GB | Cost-effective | ~$0.19 |

### 3.2 Upload Training Data to Workspace

```powershell
cd ../src

# Create data asset configuration
@"
`$schema: https://azuremlschemas.azureedge.net/latest/data.schema.json
name: diabetes-data
version: 1
type: uri_folder
path: ../experimentation/data
description: Diabetes dataset for classification
tags:
  dataset_type: training
  source: local
"@ | Out-File -FilePath data.yml -Encoding utf8

# Register data asset
az ml data create --file data.yml

# Verify upload
az ml data list -o table
az ml data show --name diabetes-data --version 1
```

### 3.3 Review Training Job Configuration

```powershell
code job.yml
```

**Job Configuration Explained:**

```yaml
$schema: https://azuremlschemas.azureedge.net/latest/commandJob.schema.json

# Where to run
compute: azureml:cpu-cluster

# What to run
code: .
command: >-
  python train.py
  --data-path ${{inputs.data}}
  --epochs 10
  --learning-rate 0.01

# Input data
inputs:
  data:
    type: uri_folder
    path: azureml:diabetes-data:1  # Reference registered data

# Python environment
environment: azureml:AzureML-sklearn-1.0-ubuntu20.04-py38-cpu@latest

# Experiment tracking
experiment_name: diabetes-classification
display_name: diabetes-training-run

# Outputs
outputs:
  model:
    type: mlflow_model
```

### 3.4 Submit Training Job

```powershell
# Submit job
$JOB_NAME = az ml job create `
  --file job.yml `
  --query name -o tsv

Write-Host "✅ Job submitted: $JOB_NAME"
Write-Host "View in portal: https://ml.azure.com"
```

### 3.5 Monitor Training Job

```powershell
# Stream logs in real-time
az ml job stream --name $JOB_NAME

# Check status
az ml job show --name $JOB_NAME --query status -o tsv

# Get job metrics
az ml job show --name $JOB_NAME --query outputs -o json
```

**Job Lifecycle:**

```
Queued → Preparing → Running → Finalizing → Completed
  ↓         ↓          ↓           ↓            ↓
 1min     2-3min    5-10min      1min        Done
```

### 3.6 View Results in ML Studio

**In Azure ML Studio (https://ml.azure.com):**

1. Navigate to: **Jobs** (left menu)
2. Click on your job name
3. Explore tabs:
   - **Overview**: Status, duration, compute
   - **Metrics**: Accuracy, loss, custom metrics
   - **Images**: Charts, confusion matrix
   - **Outputs + logs**: Model files, logs
   - **Code**: Training script snapshot

### 3.7 Download Job Outputs

```powershell
# Download all outputs
az ml job download `
  --name $JOB_NAME `
  --download-path ./outputs

# Check downloaded files
Get-ChildItem ./outputs -Recurse
```

**Expected Outputs:**
- `model/` - MLflow model artifacts
- `logs/` - Training logs
- `metrics/` - Recorded metrics (JSON)

---

## Phase 4: Model Registration & Validation

### 4.1 Register Model from Training Job

```powershell
# Register model from job outputs
az ml model create `
  --name diabetes-classifier `
  --version 1 `
  --type mlflow_model `
  --path "azureml://jobs/$JOB_NAME/outputs/model" `
  --description "Diabetes classification model - RandomForest" `
  --tags "algorithm=RandomForest" "dataset=diabetes" "environment=dev"

Write-Host "✅ Model registered"
```

### 4.2 Verify Model Registration

```powershell
# List all models
az ml model list -o table

# Show specific model version
az ml model show `
  --name diabetes-classifier `
  --version 1 -o json
```

### 4.3 Download Model for Local Testing

```powershell
# Download model artifacts
az ml model download `
  --name diabetes-classifier `
  --version 1 `
  --download-path ./downloaded-model

# Check model structure
Get-ChildItem ./downloaded-model -Recurse
```

**Model Structure:**
```
downloaded-model/
├── MLmodel              # MLflow metadata
├── conda.yaml           # Environment dependencies
├── requirements.txt     # Python packages
├── python_env.yaml      # Python version
└── model.pkl            # Serialized model
```

### 4.4 Test Model Locally

```powershell
code test_model_local.py
```

```python
import mlflow
import pandas as pd

# Load model
model = mlflow.pyfunc.load_model("./downloaded-model")

# Create test data
test_data = pd.DataFrame({
    'age': [50, 35, 60],
    'bmi': [25.5, 28.0, 32.1],
    'blood_pressure': [120, 130, 140],
    # ... add all required features
})

# Make predictions
predictions = model.predict(test_data)
print(f"Predictions: {predictions}")
```

**Run Test:**

```powershell
python test_model_local.py
```

### 4.5 Compare Model Versions

```powershell
code compare_models.py
```

```python
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential

# Connect to workspace
ml_client = MLClient(
    DefaultAzureCredential(),
    subscription_id="your-sub-id",
    resource_group_name="azureml-dev-rg",
    workspace_name="azureml-dev-ml"
)

# Get all versions
models = ml_client.models.list(name="diabetes-classifier")

# Compare
for model in models:
    print(f"\nVersion: {model.version}")
    print(f"Tags: {model.tags}")
    print(f"Created: {model.creation_context.created_at}")
    
    # Get metrics from tags if stored
    if 'accuracy' in model.tags:
        print(f"Accuracy: {model.tags['accuracy']}")
```

---

## Phase 5: Model Deployment

### 5.1 Review Scoring Script

```powershell
cd ../src
code score.py
```

**Key Components:**

```python
import json
import mlflow
import numpy as np

# Global variables
MODEL = None
MODEL_VERSION = "1.0"
REQUEST_COUNT = 0
ERROR_COUNT = 0

def init():
    """Called once when container starts"""
    global MODEL
    import os
    
    # Load model from registered location
    model_path = os.path.join(
        os.getenv("AZUREML_MODEL_DIR"),
        "model"
    )
    MODEL = mlflow.pyfunc.load_model(model_path)
    print(f"✅ Model loaded: version {MODEL_VERSION}")

def run(raw_data):
    """Called for each request"""
    global REQUEST_COUNT, ERROR_COUNT
    REQUEST_COUNT += 1
    
    try:
        # Parse JSON input
        data = json.loads(raw_data)["data"]
        
        # Make prediction
        predictions = MODEL.predict(data)
        
        # Return results
        return predictions.tolist()
        
    except Exception as e:
        ERROR_COUNT += 1
        return json.dumps({"error": str(e)})

def health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "model_version": MODEL_VERSION,
        "requests_served": REQUEST_COUNT,
        "errors": ERROR_COUNT,
        "error_rate": ERROR_COUNT / REQUEST_COUNT if REQUEST_COUNT > 0 else 0
    }

def readiness():
    """Readiness probe for Kubernetes"""
    return {"ready": MODEL is not None}

def liveness():
    """Liveness probe for Kubernetes"""
    return {"alive": True}
```

### 5.2 Deploy to Azure Container Instance (Quick Test)

```powershell
# Create managed online endpoint
az ml online-endpoint create `
  --name diabetes-endpoint-dev

# Create deployment configuration
@"
`$schema: https://azuremlschemas.azureedge.net/latest/managedOnlineDeployment.schema.json
name: blue
endpoint_name: diabetes-endpoint-dev
model: azureml:diabetes-classifier:1
code_configuration:
  code: .
  scoring_script: score.py
instance_type: Standard_DS2_v2
instance_count: 1
environment: azureml:AzureML-sklearn-1.0-ubuntu20.04-py38-cpu@latest
"@ | Out-File -FilePath deployment.yml -Encoding utf8

# Deploy
az ml online-deployment create `
  --file deployment.yml `
  --all-traffic

# Wait for deployment
az ml online-endpoint show --name diabetes-endpoint-dev
```

### 5.3 Test Managed Endpoint

```powershell
# Get endpoint URI and key
$ENDPOINT_URI = az ml online-endpoint show `
  --name diabetes-endpoint-dev `
  --query scoring_uri -o tsv

$API_KEY = az ml online-endpoint get-credentials `
  --name diabetes-endpoint-dev `
  --query primaryKey -o tsv

# Create test request
$testData = @{
    data = @(
        @(50, 25.5, 120, 80, 180, 35, 0.5, 1.2)
    )
} | ConvertTo-Json -Depth 3

# Make prediction request
$headers = @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer $API_KEY"
}

$response = Invoke-RestMethod `
  -Uri $ENDPOINT_URI `
  -Method Post `
  -Headers $headers `
  -Body $testData

Write-Host "Prediction: $response"
```

### 5.4 Deploy to AKS (Production-Ready)

**Get AKS and ACR Details:**

```powershell
$RG_NAME = "azureml-dev-rg"

$AKS_NAME = az aks list `
  --resource-group $RG_NAME `
  --query "[0].name" -o tsv

$ACR_NAME = az acr list `
  --resource-group $RG_NAME `
  --query "[0].name" -o tsv

Write-Host "AKS: $AKS_NAME"
Write-Host "ACR: $ACR_NAME"

# Get AKS credentials
az aks get-credentials `
  --resource-group $RG_NAME `
  --name $AKS_NAME `
  --overwrite-existing
```

**Build Docker Image:**

```powershell
# Create Dockerfile
@"
FROM mcr.microsoft.com/azureml/minimal-ubuntu20.04-py38-cpu-inference:latest

# Install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy scoring script
COPY score.py /app/
COPY model/ /var/azureml-app/model/

# Set working directory
WORKDIR /app

# Expose port
EXPOSE 5001

# Run scoring service
CMD ["python", "score.py"]
"@ | Out-File -FilePath Dockerfile -Encoding utf8

# Login to ACR
az acr login --name $ACR_NAME

# Build and push
docker build -t $ACR_NAME.azurecr.io/diabetes-classifier:v1 .
docker push $ACR_NAME.azurecr.io/diabetes-classifier:v1
```

**Deploy to Kubernetes:**

```powershell
cd ../kubernetes

# Review deployment manifest
code ml-inference-deployment.yaml
```

**Update Image Reference:**

```powershell
# Replace placeholder with actual ACR name
(Get-Content ml-inference-deployment.yaml) `
  -replace 'yourregistry.azurecr.io', "$ACR_NAME.azurecr.io" |
  Set-Content ml-inference-deployment.yaml

# Apply deployment
kubectl apply -f ml-inference-deployment.yaml

# Apply HPA (autoscaling)
kubectl apply -f ml-inference-hpa.yaml
```

**Verify Deployment:**

```powershell
# Check deployment status
kubectl get deployments
kubectl rollout status deployment/diabetes-classifier

# Check pods
kubectl get pods -l app=diabetes-classifier

# Check service
kubectl get service diabetes-classifier-service

# Get external IP (may take few minutes)
$EXTERNAL_IP = kubectl get service diabetes-classifier-service `
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "External IP: $EXTERNAL_IP"
```

### 5.5 Test AKS Deployment

```powershell
# Wait for external IP
while ([string]::IsNullOrEmpty($EXTERNAL_IP)) {
    Start-Sleep -Seconds 10
    $EXTERNAL_IP = kubectl get service diabetes-classifier-service `
      -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    Write-Host "Waiting for external IP..."
}

Write-Host "✅ Service ready at: http://$EXTERNAL_IP"

# Test health endpoint
Invoke-RestMethod -Uri "http://$EXTERNAL_IP/health"

# Test prediction
$testData = @{
    data = @(
        @(50, 25.5, 120, 80, 180, 35, 0.5, 1.2)
    )
} | ConvertTo-Json -Depth 3

$prediction = Invoke-RestMethod `
  -Uri "http://$EXTERNAL_IP/score" `
  -Method Post `
  -Body $testData `
  -ContentType "application/json"

Write-Host "Prediction: $prediction"
```

### 5.6 Monitor Deployment

```powershell
# View logs
kubectl logs -l app=diabetes-classifier --tail=50 -f

# Check resource usage
kubectl top pods -l app=diabetes-classifier

# Check HPA status
kubectl get hpa diabetes-classifier-hpa

# View events
kubectl get events --sort-by='.lastTimestamp' --field-selector involvedObject.name=diabetes-classifier
```

---

## Phase 6: CI/CD Automation

### 6.1 Infrastructure CI/CD (Already Configured)

**Workflow File:** `.github/workflows/infrastructure-deploy.yml`

**Capabilities:**
- ✅ Automatic validation on PR
- ✅ Manual deployment (dev/prod)
- ✅ Full infrastructure destroy
- ✅ State lock auto-recovery
- ✅ Version-controlled configuration

**Usage:**

```powershell
# Option 1: Push infrastructure changes
git add infrastructure/
git commit -m "Update infrastructure"
git push

# Option 2: Manual trigger via GitHub UI
# Actions → Infrastructure Deployment → Run workflow
# Select: Environment (dev/prod) + Destroy (true/false)
```

### 6.2 ML Training CI/CD

**Create Training Workflow:**

```powershell
code .github/workflows/ml-training-pipeline.yml
```

```yaml
name: ML Training Pipeline

on:
  push:
    branches: [main]
    paths:
      - 'src/train.py'
      - 'src/job.yml'
      - 'experimentation/data/**'
  workflow_dispatch:
    inputs:
      experiment_name:
        description: 'Experiment name'
        required: true
        default: 'diabetes-classification'

env:
  RESOURCE_GROUP: 'azureml-dev-rg'
  WORKSPACE_NAME: 'azureml-dev-ml'

jobs:
  train-model:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CLIENT_SECRET }}
      
      - name: Install Azure ML CLI
        run: az extension add -n ml --upgrade -y
      
      - name: Upload Training Data
        run: |
          cd src
          az ml data create --file data.yml \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --workspace-name ${{ env.WORKSPACE_NAME }}
      
      - name: Submit Training Job
        id: train
        run: |
          cd src
          JOB_NAME=$(az ml job create --file job.yml \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --workspace-name ${{ env.WORKSPACE_NAME }} \
            --query name -o tsv)
          
          echo "job_name=$JOB_NAME" >> $GITHUB_OUTPUT
          echo "✅ Job submitted: $JOB_NAME"
      
      - name: Monitor Training Job
        run: |
          echo "Monitoring job: ${{ steps.train.outputs.job_name }}"
          az ml job stream --name ${{ steps.train.outputs.job_name }} \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --workspace-name ${{ env.WORKSPACE_NAME }}
      
      - name: Check Job Status
        run: |
          STATUS=$(az ml job show --name ${{ steps.train.outputs.job_name }} \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --workspace-name ${{ env.WORKSPACE_NAME }} \
            --query status -o tsv)
          
          if [ "$STATUS" != "Completed" ]; then
            echo "❌ Job failed with status: $STATUS"
            exit 1
          fi
          
          echo "✅ Job completed successfully"
      
      - name: Register Model
        run: |
          az ml model create \
            --name diabetes-classifier \
            --type mlflow_model \
            --path "azureml://jobs/${{ steps.train.outputs.job_name }}/outputs/model" \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --workspace-name ${{ env.WORKSPACE_NAME }}
          
          echo "✅ Model registered"
      
      - name: Create Job Summary
        run: |
          echo "## 🎯 Training Job Completed" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Job Name**: ${{ steps.train.outputs.job_name }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Status**: Completed ✅" >> $GITHUB_STEP_SUMMARY
          echo "- **Model**: diabetes-classifier (new version)" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "[View in ML Studio](https://ml.azure.com)" >> $GITHUB_STEP_SUMMARY
```

**Commit Workflow:**

```powershell
git add .github/workflows/ml-training-pipeline.yml
git commit -m "Add ML training pipeline"
git push
```

### 6.3 Model Deployment CI/CD

```powershell
code .github/workflows/model-deployment-pipeline.yml
```

```yaml
name: Model Deployment Pipeline

on:
  workflow_dispatch:
    inputs:
      model_version:
        description: 'Model version to deploy'
        required: true
        default: '1'
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - dev
          - prod

env:
  MODEL_NAME: 'diabetes-classifier'

jobs:
  deploy-to-aks:
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CLIENT_SECRET }}
      
      - name: Set Environment Variables
        run: |
          echo "RESOURCE_GROUP=azureml-${{ github.event.inputs.environment }}-rg" >> $GITHUB_ENV
          echo "WORKSPACE_NAME=azureml-${{ github.event.inputs.environment }}-ml" >> $GITHUB_ENV
      
      - name: Get AKS Credentials
        run: |
          AKS_NAME=$(az aks list \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --query "[0].name" -o tsv)
          
          az aks get-credentials \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --name $AKS_NAME \
            --overwrite-existing
          
          echo "AKS_NAME=$AKS_NAME" >> $GITHUB_ENV
      
      - name: Download Model
        run: |
          az extension add -n ml --upgrade -y
          
          az ml model download \
            --name ${{ env.MODEL_NAME }} \
            --version ${{ github.event.inputs.model_version }} \
            --download-path ./model \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --workspace-name ${{ env.WORKSPACE_NAME }}
      
      - name: Build and Push Docker Image
        run: |
          ACR_NAME=$(az acr list \
            --resource-group ${{ env.RESOURCE_GROUP }} \
            --query "[0].name" -o tsv)
          
          az acr login --name $ACR_NAME
          
          IMAGE_TAG="${{ github.event.inputs.model_version }}-${{ github.sha }}"
          IMAGE_NAME="$ACR_NAME.azurecr.io/${{ env.MODEL_NAME }}:$IMAGE_TAG"
          
          cd src
          docker build -t $IMAGE_NAME .
          docker push $IMAGE_NAME
          
          echo "IMAGE_NAME=$IMAGE_NAME" >> $GITHUB_ENV
      
      - name: Update Kubernetes Deployment
        run: |
          cd kubernetes
          
          # Update image in deployment manifest
          sed -i "s|image:.*|image: ${{ env.IMAGE_NAME }}|g" ml-inference-deployment.yaml
          
          # Apply deployment
          kubectl apply -f ml-inference-deployment.yaml
          kubectl apply -f ml-inference-hpa.yaml
          
          # Wait for rollout
          kubectl rollout status deployment/diabetes-classifier --timeout=5m
      
      - name: Verify Deployment
        run: |
          echo "## 🚀 Deployment Successful" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "- **Model**: ${{ env.MODEL_NAME }}:${{ github.event.inputs.model_version }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Environment**: ${{ github.event.inputs.environment }}" >> $GITHUB_STEP_SUMMARY
          echo "- **AKS Cluster**: ${{ env.AKS_NAME }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          
          # Get service endpoint
          EXTERNAL_IP=$(kubectl get service diabetes-classifier-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
          echo "- **Endpoint**: http://$EXTERNAL_IP" >> $GITHUB_STEP_SUMMARY
          
          # Get pod status
          kubectl get pods -l app=diabetes-classifier >> $GITHUB_STEP_SUMMARY
```

**Commit Workflow:**

```powershell
git add .github/workflows/model-deployment-pipeline.yml
git commit -m "Add model deployment pipeline"
git push
```

### 6.4 Complete Automation Flow

**End-to-End Workflow:**

```
1. Developer pushes code changes to src/train.py
   ↓
2. GitHub Actions: ML Training Pipeline triggers
   ├─ Uploads data
   ├─ Submits training job
   ├─ Monitors completion
   └─ Registers model (new version)
   ↓
3. Manual approval required for deployment
   ↓
4. GitHub Actions: Model Deployment Pipeline (manual trigger)
   ├─ Downloads model
   ├─ Builds Docker image
   ├─ Pushes to ACR
   ├─ Updates Kubernetes deployment
   └─ Verifies deployment
   ↓
5. Model live in production
```

**Trigger Workflows:**

```powershell
# Option 1: Automatic (push code)
git add src/train.py
git commit -m "Improve model performance"
git push  # → Triggers training pipeline

# Option 2: Manual (GitHub UI)
# Actions → ML Training Pipeline → Run workflow
# Actions → Model Deployment Pipeline → Run workflow → Select version
```

---

## Phase 7: Monitoring & Operations

### 7.1 Application Insights Setup

**Access Application Insights:**

```powershell
# Get Application Insights details
$APP_INSIGHTS = az monitor app-insights component list `
  --resource-group $RG_NAME `
  --query "[0].name" -o tsv

Write-Host "Application Insights: $APP_INSIGHTS"

# Get instrumentation key
$INSTRUMENTATION_KEY = az monitor app-insights component show `
  --app $APP_INSIGHTS `
  --resource-group $RG_NAME `
  --query instrumentationKey -o tsv

# Open in Azure Portal
Start-Process "https://portal.azure.com/#resource$(az monitor app-insights component show --app $APP_INSIGHTS --resource-group $RG_NAME --query id -o tsv)"
```

### 7.2 Query Application Insights Logs

**In Azure Portal: Application Insights → Logs**

**Sample KQL Queries:**

```kusto
// 1. Request latency (P50, P95, P99)
requests
| where timestamp > ago(1h)
| summarize 
    P50_ms = percentile(duration, 50),
    P95_ms = percentile(duration, 95),
    P99_ms = percentile(duration, 99),
    RequestCount = count()
    by bin(timestamp, 5m)
| render timechart

// 2. Error rate over time
requests
| where timestamp > ago(24h)
| summarize 
    TotalRequests = count(),
    FailedRequests = countif(success == false)
    by bin(timestamp, 1h)
| extend ErrorRate = (FailedRequests * 100.0) / TotalRequests
| render timechart with (ytitle="Error Rate %")

// 3. Top slow requests
requests
| where timestamp > ago(1h)
| where duration > 200  // Slower than 200ms
| top 20 by duration desc
| project timestamp, name, duration, resultCode, url

// 4. Request volume by hour
requests
| where timestamp > ago(7d)
| summarize RequestCount = count() by bin(timestamp, 1h)
| render timechart

// 5. Model prediction traces
traces
| where message contains "Prediction"
| project timestamp, message, severityLevel
| order by timestamp desc
| take 100

// 6. Application exceptions
exceptions
| where timestamp > ago(24h)
| project timestamp, type, outerMessage, innermostMessage
| order by timestamp desc
```

### 7.3 Monitor AKS Cluster

```powershell
# Node resource usage
kubectl top nodes

# Pod resource usage
kubectl top pods -l app=diabetes-classifier

# HPA status
kubectl get hpa diabetes-classifier-hpa

# Check autoscaling events
kubectl describe hpa diabetes-classifier-hpa

# View pod logs
kubectl logs -l app=diabetes-classifier --tail=100 -f

# Check pod health
kubectl get pods -l app=diabetes-classifier -o wide

# View recent events
kubectl get events --sort-by='.lastTimestamp' | Select-Object -Last 20
```

### 7.4 Cost Monitoring

```powershell
# View daily costs (last 7 days)
az consumption usage list `
  --start-date (Get-Date).AddDays(-7).ToString("yyyy-MM-dd") `
  --end-date (Get-Date).ToString("yyyy-MM-dd") `
  --query "[].{Date:usageStart,Cost:pretaxCost,Resource:instanceName}" `
  --output table

# Check budget status
az consumption budget list `
  --resource-group $RG_NAME `
  --query "[].{Name:name,Amount:amount,CurrentSpend:currentSpend.amount}" `
  --output table

# View cost by resource type
az consumption usage list `
  --start-date (Get-Date).AddDays(-30).ToString("yyyy-MM-dd") `
  --query "[].{Type:meterCategory,Cost:pretaxCost}" |
  ConvertFrom-Json |
  Group-Object Type |
  Select-Object Name, @{N='TotalCost';E={($_.Group | Measure-Object Cost -Sum).Sum}} |
  Sort-Object TotalCost -Descending
```

**Expected Monthly Costs (Dev Environment):**

| Resource | Monthly Cost | Percentage |
|----------|-------------|------------|
| AKS Cluster | $70-90 | 35-40% |
| API Management | $50 | 20-25% |
| Azure Front Door | $40-50 | 18-22% |
| ML Workspace | $10 | 4-5% |
| Storage | $5-10 | 2-4% |
| Log Analytics | $10-15 | 4-6% |
| Other | $10-20 | 4-8% |
| **Total** | **$220-260** | **100%** |

### 7.5 Review Configured Alerts

```powershell
# List all alert rules
az monitor metrics alert list `
  --resource-group $RG_NAME `
  --output table

# Show specific alert details
az monitor metrics alert show `
  --resource-group $RG_NAME `
  --name "SLO - P95 Latency" `
  --output json

# List action groups (notification channels)
az monitor action-group list `
  --resource-group $RG_NAME `
  --output table
```

**Pre-configured Alerts:**

1. **SLO P95 Latency** - Triggers if 95th percentile > 200ms
2. **SLO P99 Latency** - Triggers if 99th percentile > 500ms
3. **SLO Error Rate** - Triggers if error rate > 1%
4. **ML Job Failure** - Triggers when training jobs fail
5. **Budget Alert** - Triggers at 80% of monthly budget ($60 for dev)

### 7.6 Load Testing

```powershell
# Get service endpoint
$EXTERNAL_IP = kubectl get service diabetes-classifier-service `
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "Testing endpoint: http://$EXTERNAL_IP/score"

# Generate load (100 requests)
1..100 | ForEach-Object {
    $testData = @{
        data = @(
            @(50, 25.5, 120, 80, 180, 35, 0.5, 1.2)
        )
    } | ConvertTo-Json -Depth 3
    
    try {
        $response = Invoke-RestMethod `
          -Uri "http://$EXTERNAL_IP/score" `
          -Method Post `
          -Body $testData `
          -ContentType "application/json" `
          -TimeoutSec 5
        
        Write-Host "Request $_`: Success"
    }
    catch {
        Write-Host "Request $_`: Failed - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Check HPA scaling
Start-Sleep -Seconds 30
kubectl get hpa diabetes-classifier-hpa
kubectl get pods -l app=diabetes-classifier
```

### 7.7 Model Performance Monitoring

**Create Monitoring Script:**

```powershell
code src/monitor_model_performance.py
```

```python
from azure.ai.ml import MLClient
from azure.identity import DefaultAzureCredential
from azure.monitor.query import LogsQueryClient
from datetime import datetime, timedelta
import pandas as pd

# Connect to workspace
ml_client = MLClient(
    DefaultAzureCredential(),
    subscription_id="your-subscription-id",
    resource_group_name="azureml-dev-rg",
    workspace_name="azureml-dev-ml"
)

# Connect to Application Insights
logs_client = LogsQueryClient(DefaultAzureCredential())

# Query prediction logs
query = """
traces
| where message contains 'Prediction'
| project timestamp, message
| order by timestamp desc
| take 1000
"""

# Get logs from last 24 hours
end_time = datetime.utcnow()
start_time = end_time - timedelta(hours=24)

response = logs_client.query_workspace(
    workspace_id="your-app-insights-workspace-id",
    query=query,
    timespan=(start_time, end_time)
)

# Analyze predictions
predictions_df = pd.DataFrame(response.tables[0].rows)

# Calculate metrics
total_predictions = len(predictions_df)
avg_confidence = predictions_df['confidence'].mean()

print(f"📊 Model Performance (Last 24h)")
print(f"Total Predictions: {total_predictions}")
print(f"Average Confidence: {avg_confidence:.2%}")

# Check for drift
if avg_confidence < 0.70:
    print("⚠️ Low confidence detected - consider retraining")

# Log metrics to ML Workspace
from mlflow import log_metric, set_tracking_uri
set_tracking_uri(ml_client.workspaces.get("azureml-dev-ml").mlflow_tracking_uri)

log_metric("production_predictions_24h", total_predictions)
log_metric("production_avg_confidence", avg_confidence)
```

**Run Monitoring:**

```powershell
python src/monitor_model_performance.py
```

---

## Troubleshooting

### Issue 1: Terraform State Lock

**Symptom:**
```
Error: Error acquiring the state lock
Lock ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**Solution:**

```powershell
cd infrastructure

# Option 1: Auto-unlock (built into pipeline)
# Pipeline now automatically detects and unlocks

# Option 2: Manual unlock
$LOCK_ID = "lock-id-from-error-message"
terraform force-unlock -force $LOCK_ID

# Option 3: If state corrupted
# Check for errored.tfstate file
if (Test-Path errored.tfstate) {
    # Push errored state
    terraform state push errored.tfstate
    
    # Or start fresh (DANGEROUS - only if you know what you're doing)
    # Remove-Item .terraform/terraform.tfstate
    # terraform init -reconfigure
}
```

### Issue 2: AKS Cluster Issues

**Symptom:** Nodes not ready, pods crashing

**Diagnosis:**

```powershell
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check pod status
kubectl get pods -l app=diabetes-classifier
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name> --previous  # Previous container logs
kubectl logs <pod-name> -f  # Follow current logs

# Check events
kubectl get events --sort-by='.lastTimestamp' --field-selector involvedObject.name=<pod-name>
```

**Solutions:**

```powershell
# Solution 1: Restart deployment
kubectl rollout restart deployment/diabetes-classifier

# Solution 2: Scale down and up
kubectl scale deployment diabetes-classifier --replicas=0
Start-Sleep -Seconds 30
kubectl scale deployment diabetes-classifier --replicas=2

# Solution 3: Check ACR connectivity
$ACR_NAME = az acr list --resource-group $RG_NAME --query "[0].name" -o tsv
az aks check-acr --resource-group $RG_NAME --name $AKS_NAME --acr "$ACR_NAME.azurecr.io"

# Solution 4: Restart AKS node pool
az aks nodepool upgrade --resource-group $RG_NAME --cluster-name $AKS_NAME --name nodepool1 --node-image-only
```

### Issue 3: High Inference Latency

**Symptom:** P95 latency > 200ms, slow predictions

**Diagnosis:**

```powershell
# Check current latency in Application Insights
# Query: requests | where timestamp > ago(1h) | summarize P95=percentile(duration, 95)

# Check pod resource usage
kubectl top pods -l app=diabetes-classifier

# Check HPA status
kubectl get hpa diabetes-classifier-hpa
```

**Solutions:**

```powershell
# Solution 1: Scale up replicas
kubectl scale deployment diabetes-classifier --replicas=5

# Solution 2: Increase resource limits
kubectl edit deployment diabetes-classifier
# Update:
#   resources:
#     limits:
#       cpu: 2000m
#       memory: 4Gi

# Solution 3: Enable Redis caching
# Edit infrastructure/terraform.tfvars.dev-edge-learning
# Set: enable_redis_cache = true
# Re-deploy infrastructure

# Solution 4: Optimize model
# Use quantization, pruning, or model distillation
# Retrain with smaller model architecture
```

### Issue 4: Training Job Stuck or Failing

**Symptom:** Job shows "Running" indefinitely or fails

**Diagnosis:**

```powershell
# Check job status
az ml job show --name $JOB_NAME --query "{Status:status, Error:error}" -o table

# Stream logs
az ml job stream --name $JOB_NAME

# Check compute cluster
az ml compute show --name cpu-cluster --query "{State:provisioningState, Errors:provisioningErrors}" -o table

# List running jobs
az ml job list --query "[?status=='Running'].{Name:name,Status:status,Created:creationContext.createdAt}" -o table
```

**Solutions:**

```powershell
# Solution 1: Cancel and resubmit
az ml job cancel --name $JOB_NAME
az ml job create --file src/job.yml

# Solution 2: Check compute availability
az ml compute show --name cpu-cluster

# If compute is deallocated, it may take 5-10 minutes to start

# Solution 3: Increase timeout
# Edit src/job.yml
# Add: timeout_seconds: 3600  # 1 hour

# Solution 4: Use different compute
# Create new compute cluster
az ml compute create --name cpu-cluster-large --type amlcompute --size Standard_DS4_v2 --min-instances 0 --max-instances 4

# Update job.yml to use new cluster
# compute: azureml:cpu-cluster-large
```

### Issue 5: Model Registration Fails

**Symptom:** Can't register model from job

**Diagnosis:**

```powershell
# Check if job produced model output
az ml job show --name $JOB_NAME --query outputs -o json

# Verify model path exists
az ml job download --name $JOB_NAME --download-path ./outputs
Get-ChildItem ./outputs -Recurse
```

**Solutions:**

```powershell
# Solution 1: Ensure model is logged in training script
# In train.py, add:
# mlflow.sklearn.log_model(model, "model")

# Solution 2: Register from local path
az ml model create `
  --name diabetes-classifier `
  --version 1 `
  --path ./outputs/model `
  --type mlflow_model

# Solution 3: Check MLflow tracking URI
# In train.py:
# mlflow.set_tracking_uri(ml_client.workspaces.get(...).mlflow_tracking_uri)
```

### Issue 6: Deployment Health Check Fails

**Symptom:** Kubernetes pod status shows unhealthy

**Diagnosis:**

```powershell
# Check readiness probe
kubectl describe pod <pod-name> | Select-String -Pattern "Readiness"

# Test health endpoint locally
kubectl port-forward pod/<pod-name> 8080:5001
Invoke-RestMethod -Uri "http://localhost:8080/health"
```

**Solutions:**

```powershell
# Solution 1: Increase probe delays
kubectl edit deployment diabetes-classifier
# Update:
#   readinessProbe:
#     initialDelaySeconds: 30  # Increase from 10
#     periodSeconds: 10

# Solution 2: Check model loading
kubectl logs <pod-name> | Select-String -Pattern "Model loaded"

# Solution 3: Verify environment variables
kubectl describe pod <pod-name> | Select-String -Pattern "Environment"
```

### Issue 7: Cost Overruns

**Symptom:** Monthly cost exceeds budget

**Diagnosis:**

```powershell
# View current month costs
az consumption usage list `
  --start-date (Get-Date -Day 1).ToString("yyyy-MM-dd") `
  --end-date (Get-Date).ToString("yyyy-MM-dd") `
  --query "[].{Resource:instanceName,Cost:pretaxCost,Quantity:quantity}" |
  ConvertFrom-Json |
  Group-Object Resource |
  Select-Object Name, @{N='TotalCost';E={($_.Group | Measure-Object Cost -Sum).Sum}} |
  Sort-Object TotalCost -Descending
```

**Solutions:**

```powershell
# Solution 1: Scale down AKS
az aks scale --resource-group $RG_NAME --name $AKS_NAME --node-count 1

# Solution 2: Stop/start AKS when not in use
az aks stop --resource-group $RG_NAME --name $AKS_NAME  # Stop
az aks start --resource-group $RG_NAME --name $AKS_NAME  # Start

# Solution 3: Use minimal profile
# Edit infrastructure/terraform.tfvars.dev-edge-learning
# Set:
# enable_aks_deployment = false
# enable_api_management = false
# enable_front_door = false
# Re-deploy infrastructure

# Solution 4: Delete unused resources
az resource list --resource-group $RG_NAME --query "[].{Name:name,Type:type}" -o table
# Delete specific resources not needed

# Solution 5: Use Terraform destroy and recreate only when needed
# Destroy: Actions → Infrastructure Deployment → Run workflow → destroy=true
```

---

## Summary & Next Steps

### Completion Checklist

- [ ] **Phase 0**: ✅ Tools installed, Azure/GitHub configured
- [ ] **Phase 1**: ✅ Infrastructure deployed via GitHub Actions
- [ ] **Phase 2**: ✅ Local experimentation completed
- [ ] **Phase 3**: ✅ Training job submitted and completed
- [ ] **Phase 4**: ✅ Model registered and validated
- [ ] **Phase 5**: ✅ Model deployed to AKS with autoscaling
- [ ] **Phase 6**: ✅ CI/CD pipelines configured and tested
- [ ] **Phase 7**: ✅ Monitoring dashboards and alerts reviewed

### Configuration Files Reference

| File | Purpose | When to Edit |
|------|---------|--------------|
| `infrastructure/terraform.tfvars.dev-edge-learning` | Infrastructure config | Change resources, features |
| `infrastructure/terraform.tfvars.prod` | Production config | Production setup |
| `src/job.yml` | Training job config | Change hyperparameters, compute |
| `src/train.py` | Training logic | Improve model algorithm |
| `src/score.py` | Inference logic | Change prediction logic |
| `kubernetes/ml-inference-deployment.yaml` | K8s deployment | Scale, resource limits |
| `kubernetes/ml-inference-hpa.yaml` | Autoscaling | Scaling thresholds |
| `.github/workflows/*.yml` | CI/CD pipelines | Automation changes |

### Next Steps

1. **Enable Optional Features:**
   ```powershell
   # Enable Redis caching
   # Edit: infrastructure/terraform.tfvars.dev-edge-learning
   # Set: enable_redis_cache = true
   # Commit and run infrastructure pipeline
   ```

2. **Improve Model:**
   ```powershell
   # Edit training script
   code src/train.py
   # Add: feature engineering, hyperparameter tuning
   # Push to trigger training pipeline
   ```

3. **Setup Production:**
   ```powershell
   # Review production config
   code infrastructure/terraform.tfvars.prod
   # Deploy: Actions → Infrastructure Deployment → environment=prod
   ```

4. **Advanced Monitoring:**
   - Create custom Application Insights dashboards
   - Setup Slack/Teams notifications
   - Implement drift detection

5. **A/B Testing:**
   - Deploy multiple model versions
   - Route traffic for comparison
   - Analyze metrics

### Cost Optimization Tips

- **Stop AKS when not in use**: `az aks stop`
- **Use spot instances**: Cheaper for non-critical workloads
- **Enable autoscaling**: Only pay for what you use
- **Monitor and alert**: Stay on top of costs
- **Use minimal profile**: For learning/dev environments

### Resources

- **Azure ML Documentation**: https://docs.microsoft.com/azure/machine-learning
- **Terraform Azure Provider**: https://registry.terraform.io/providers/hashicorp/azurerm
- **Kubernetes Documentation**: https://kubernetes.io/docs
- **MLflow Documentation**: https://mlflow.org/docs/latest

### Related Guides

- [Configuration Management](CONFIGURATION_MANAGEMENT.md) - Version control setup
- [Inference Best Practices](documentation/09-inference-best-practices.md) - Optimization guide
- [Terraform Backend Setup](TERRAFORM_BACKEND_GUIDE.md) - State management
- [Pipeline Cleanup](PIPELINE_CLEANUP_CONFIG.md) - Resource cleanup
- [Quick Start](QUICK_START_FREE_TIER.md) - Fast setup guide

---

**Last Updated**: November 11, 2025  
**Environment**: Development (dev-edge-learning)  
**Estimated Cost**: $220-260/month  
**Version**: 2.0
