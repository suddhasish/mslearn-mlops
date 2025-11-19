# MLOps Interview Preparation Guide
## Employee Attrition Prediction Project

**Candidate Name:** [Your Name]  
**Project Duration:** [Timeline]  
**Technology Stack:** Azure ML, AKS, Prometheus, Grafana, GitHub Actions, Terraform, Docker, Kubernetes

---

## Project Overview

**Business Problem:**
Developed an end-to-end MLOps solution for predicting employee attrition, enabling HR teams to proactively identify at-risk employees and implement retention strategies. The model analyzes 9 key features including tenure, satisfaction metrics, performance ratings, and work patterns to predict turnover probability.

**Impact:**
- Reduced employee turnover prediction latency from hours to <100ms
- Achieved 99.9% uptime for production inference endpoints
- Enabled real-time HR interventions through low-latency predictions
- Established enterprise-grade MLOps practices with full audit trails

---

## Interview Question 1: End-to-End MLOps Pipeline Architecture

### Question:
*"Walk me through the complete MLOps pipeline you built for the employee attrition prediction model. How did you architect it for automated training, validation, and deployment?"*

### Answer:

**Architecture Overview:**

I architected a comprehensive MLOps pipeline on Azure ML with three main stages: training, validation, and deployment. Let me walk you through each component:

#### 1. Automated Training Pipeline

**Implementation:**
- Used **Azure ML Pipelines** for orchestrated training workflows
- Built modular Python scripts in `src/` directory:
  - `train.py` - Model training with scikit-learn LogisticRegression
  - Data preprocessing with feature engineering for attrition indicators
  - Cross-validation with stratified K-fold for imbalanced classes

**Code Structure:**
```python
# src/train.py highlights
def train_model(data_path, model_output_path):
    # Load employee data (9 features)
    df = pd.read_csv(data_path)
    
    # Features: tenure, age, satisfaction_score, performance_rating, 
    #          work_hours, projects_count, promotion_flag, salary, department_code
    X = df.drop('attrition', axis=1)
    y = df['attrition']
    
    # Train with class balancing for attrition (minority class)
    model = LogisticRegression(class_weight='balanced', max_iter=1000)
    model.fit(X, y)
    
    # Save with versioning
    joblib.dump(model, model_output_path)
    
    # Log metrics to MLflow
    mlflow.log_metric("accuracy", accuracy)
    mlflow.log_metric("auc_roc", auc_score)
    mlflow.log_metric("precision_attrition_class", precision)
```

**Automation:**
- Triggered via GitHub Actions on data changes or manual dispatch
- Automated hyperparameter tuning with Azure ML HyperDrive (planned for v2)
- Experiment tracking with **MLflow** for reproducibility

#### 2. Model Validation & Testing

**Quality Gates Implemented:**

```yaml
# .github/workflows/ci-train-model.yml
- name: Run Unit Tests
  run: pytest tests/ --cov=src --cov-report=xml
  
- name: Validate Model Performance
  run: |
    python scripts/validate_model.py \
      --min-accuracy 0.80 \
      --min-auc 0.85 \
      --check-fairness \
      --bias-threshold 0.1

- name: Test Data Drift
  run: |
    python scripts/test_drift.py \
      --reference-data data/reference.csv \
      --current-data data/latest.csv
```

**Validation Criteria:**
- **Performance thresholds:** AUC-ROC ≥ 0.85, Accuracy ≥ 80%
- **Fairness checks:** Ensured no bias across department demographics
- **Integration tests:** Validated prediction format and latency (<100ms requirement)
- **Data quality:** Schema validation, null checks, outlier detection

#### 3. Model Registry Integration

**Azure ML Model Registry:**
```python
# Register model with metadata
model = Model.register(
    workspace=ws,
    model_name="employee-attrition-classifier",
    model_path="outputs/model.pkl",
    tags={
        "framework": "scikit-learn",
        "version": model_version,
        "training_date": datetime.now().isoformat(),
        "auc_roc": auc_score,
        "data_version": data_hash
    },
    description="Predicts employee attrition probability based on 9 key features"
)
```

**Version Control:**
- Semantic versioning: v1.0.0, v1.1.0, v2.0.0
- Immutable model artifacts with SHA256 checksums
- Metadata tracking: training dataset version, hyperparameters, performance metrics
- Model lineage: Full traceability from data → training → deployment

#### 4. Deployment to Azure ML Managed Endpoints

**Staging Deployment:**
```yaml
# deployment/staging-deployment.yml
$schema: https://azuremlschemas.azureedge.net/latest/managedOnlineDeployment.schema.json
name: staging-deployment
endpoint_name: attrition-endpoint-staging
model: azureml:employee-attrition-classifier:1
instance_type: Standard_DS2_v2
instance_count: 1

request_settings:
  request_timeout_ms: 5000
  max_concurrent_requests_per_instance: 10

liveness_probe:
  initial_delay: 30
  period: 10
  timeout: 5
```

**Deployment Strategy:**
1. **Staging First:** Deploy to managed endpoint for validation
2. **Smoke Tests:** Automated endpoint testing with sample HR data
3. **Approval Gate:** Manual review before production
4. **Production Deployment:** Blue-green strategy to AKS

**99.9% Uptime Achievement:**
- Azure ML SLA-backed managed endpoints for staging
- Health probes: `/liveness` and `/readiness` endpoints
- Automatic failover with multiple instances
- Zero-downtime deployments with rolling updates

#### 5. CI/CD Automation

**GitHub Actions Workflows:**

```yaml
# .github/workflows/cd-deploy.yml (simplified)
on:
  workflow_dispatch:
    inputs:
      model_version:
        required: true
      
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    steps:
      - name: Download model from registry
        run: |
          az ml model download \
            --name employee-attrition-classifier \
            --version ${{ inputs.model_version }}
      
      - name: Deploy to staging
        run: |
          az ml online-deployment create \
            --file deployment/staging-deployment.yml
      
      - name: Run smoke tests
        run: |
          python scripts/test_endpoint.py \
            --endpoint $STAGING_ENDPOINT \
            --test-data test/sample_employees.csv
  
  await-approval:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment: production-approval
    steps:
      - name: Wait for approval
        run: echo "Awaiting production approval..."
  
  deploy-production-aks:
    needs: await-approval
    runs-on: ubuntu-latest
    steps:
      - name: Build Docker image
        run: docker build -t $ACR/attrition-model:$VERSION .
      
      - name: Deploy to AKS
        run: kubectl apply -f kubernetes/deployment.yaml
```

**Key Features:**
- Automated triggers on model registration
- Multi-environment progression (dev → staging → prod)
- Approval gates before production deployment
- Rollback capability with previous model versions

---

## Interview Question 2: Custom AKS-Based ML Serving Infrastructure

### Question:
*"You mentioned building custom AKS infrastructure that achieved 3x performance improvement. How did you design this, and what specific optimizations led to that performance gain?"*

### Answer:

**Context:**
While Azure ML managed endpoints provided 99.9% uptime for staging, we needed higher throughput for production workloads handling 10,000+ predictions/minute during peak HR review cycles. I designed a custom Kubernetes-based serving infrastructure on AKS.

#### Architecture Design

**High-Level Components:**

```
Internet
  ↓
Azure Load Balancer (External IP)
  ↓
AKS Ingress Controller (NGINX)
  ↓
Kubernetes Service (ml-inference)
  ↓
Pod Autoscaling (HPA: 3-10 pods)
  ↓
ML Inference Pods (Gunicorn + Flask)
  ↓
Prometheus Metrics Collection
  ↓
Grafana Dashboards
```

#### Performance Optimizations

**1. Custom Docker Image with Optimized Dependencies**

```dockerfile
# src/Dockerfile
FROM python:3.11-slim

# Install only production dependencies (slim image)
RUN pip install --no-cache-dir \
    scikit-learn==1.5.0 \
    pandas==2.2.0 \
    numpy==1.26.0 \
    joblib \
    gunicorn \
    flask \
    prometheus-client

# Copy model at build time (eliminates startup latency)
COPY model/model.pkl /app/model/model.pkl

# Gunicorn with 4 workers, 2 threads each = 8 concurrent requests/pod
CMD ["gunicorn", "--bind", "0.0.0.0:5001", \
     "--workers", "4", "--threads", "2", \
     "--timeout", "30", "--worker-class", "gthread", \
     "app:app"]
```

**Optimization:** Reduced image size from 1.2GB → 380MB, startup time from 45s → 8s

**2. Horizontal Pod Autoscaling (HPA)**

```yaml
# kubernetes/ml-inference-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ml-inference-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ml-inference
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Pods
    pods:
      metric:
        name: prediction_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Prevent flapping
    scaleUp:
      stabilizationWindowSeconds: 60   # Quick scale-up
```

**Optimization:** Auto-scales from 3→10 pods during peak, handles 1000+ req/sec

**3. Resource Optimization**

```yaml
# kubernetes/ml-inference-deployment.yaml
resources:
  requests:
    cpu: "250m"      # 0.25 CPU cores
    memory: "512Mi"  # 512MB RAM
  limits:
    cpu: "1000m"     # 1 CPU core max
    memory: "2Gi"    # 2GB RAM max
```

**Before optimization:**
- Managed endpoint: 1 instance, ~20 req/sec, 200ms p95 latency
- Cost: $200/month per endpoint

**After AKS optimization:**
- AKS cluster: 3-10 pods, ~300 req/sec, 50ms p95 latency
- Cost: $150/month (shared infrastructure)
- **3x throughput improvement, 4x latency improvement**

**4. Connection Pooling & Keep-Alive**

```python
# src/app.py
from flask import Flask
from werkzeug.serving import WSGIRequestHandler

app = Flask(__name__)

# Enable HTTP keep-alive for connection reuse
WSGIRequestHandler.protocol_version = "HTTP/1.1"

# Gunicorn worker configuration
workers = 4  # Based on CPU cores
threads = 2  # Threads per worker
worker_connections = 1000  # Max concurrent connections
keepalive = 5  # Keep-alive timeout
```

**5. Model Caching & Warm-Up**

```python
# src/score.py
import joblib

# Load model ONCE at startup (not per request)
model = None

def init():
    global model
    model_path = os.getenv('AZUREML_MODEL_FILE', '/app/model/model.pkl')
    model = joblib.load(model_path)
    
    # Warm up model with dummy prediction
    dummy_input = [[50, 35, 0.75, 3.5, 45, 4, 0, 75000, 1]]
    model.predict(dummy_input)
    
    logger.info("Model loaded and warmed up")

def run(raw_data):
    # Model already loaded - direct inference
    data = json.loads(raw_data)['data']
    prediction = model.predict(data)
    return json.dumps({"attrition_probability": prediction.tolist()})
```

#### Monitoring for Performance

**Prometheus Metrics:**
```python
# Track request latency
prediction_duration_seconds = Histogram(
    'prediction_duration_seconds',
    'Prediction request duration',
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0)
)

@prediction_duration_seconds.time()
def run(raw_data):
    # Inference code...
    pass
```

**Grafana Dashboard:**
- P50/P95/P99 latency tracking
- Requests per second
- Error rate monitoring
- Pod CPU/memory utilization

**Performance Results:**

| Metric | Azure ML Managed | Custom AKS | Improvement |
|--------|------------------|------------|-------------|
| **Throughput** | 20 req/sec | 300 req/sec | **15x** |
| **P95 Latency** | 200ms | 50ms | **4x faster** |
| **Concurrent Users** | 100 | 1000+ | **10x** |
| **Cost/month** | $200 | $150 | **25% cheaper** |
| **Startup Time** | 45s | 8s | **5.6x faster** |

---

## Interview Question 3: Blue-Green Deployment & A/B Testing

### Question:
*"You mentioned implementing blue-green deployment strategies. How did you implement this for the attrition model, and how did you conduct A/B testing?"*

### Answer:

#### Blue-Green Deployment Strategy

**Concept:**
Maintain two identical production environments ("blue" and "green"). Deploy new model version to inactive environment, validate, then switch traffic.

**Implementation on AKS:**

**1. Deployment Configuration**

```yaml
# kubernetes/blue-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-inference-blue
  labels:
    app: ml-inference
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ml-inference
      version: blue
  template:
    metadata:
      labels:
        app: ml-inference
        version: blue
    spec:
      containers:
      - name: inference
        image: myacr.azurecr.io/attrition-model:v1.2.0
        env:
        - name: MODEL_VERSION
          value: "1.2.0"
        - name: DEPLOYMENT_NAME
          value: "blue"

---
# kubernetes/green-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-inference-green
  labels:
    app: ml-inference
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ml-inference
      version: green
  template:
    metadata:
      labels:
        app: ml-inference
        version: green
    spec:
      containers:
      - name: inference
        image: myacr.azurecr.io/attrition-model:v1.3.0  # New version
        env:
        - name: MODEL_VERSION
          value: "1.3.0"
        - name: DEPLOYMENT_NAME
          value: "green"
```

**2. Traffic Switching with Service**

```yaml
# kubernetes/ml-inference-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: ml-inference
spec:
  selector:
    app: ml-inference
    version: blue  # ← Switch between "blue" and "green"
  ports:
  - port: 80
    targetPort: 5001
  type: LoadBalancer
```

**Deployment Process:**

```bash
# Step 1: Deploy new model to GREEN (inactive)
kubectl apply -f kubernetes/green-deployment.yaml

# Step 2: Wait for green pods to be ready
kubectl rollout status deployment/ml-inference-green

# Step 3: Validate green deployment with smoke tests
./scripts/validate_deployment.sh green

# Step 4: If validation passes, switch traffic
kubectl patch service ml-inference -p '{"spec":{"selector":{"version":"green"}}}'

# Step 5: Monitor for 15 minutes, check error rates

# Step 6: If issues detected, instant rollback
kubectl patch service ml-inference -p '{"spec":{"selector":{"version":"blue"}}}'

# Step 7: If stable, scale down old blue deployment
kubectl scale deployment ml-inference-blue --replicas=0
```

#### A/B Testing Framework

**Use Case:**
Test new model v1.3.0 (with added tenure-based features) against baseline v1.2.0 to measure impact on prediction accuracy and false positive rate.

**Implementation:**

**1. Traffic Splitting with Istio Virtual Service**

```yaml
# kubernetes/istio-virtual-service.yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ml-inference-ab-test
spec:
  hosts:
  - ml-inference.production.svc.cluster.local
  http:
  - match:
    - headers:
        x-user-group:
          exact: "pilot"  # Pilot group gets new model
    route:
    - destination:
        host: ml-inference
        subset: green
      weight: 100
  - route:
    - destination:
        host: ml-inference
        subset: blue
      weight: 70  # 70% traffic to old model
    - destination:
        host: ml-inference
        subset: green
      weight: 30  # 30% traffic to new model
```

**2. Experiment Tracking**

```python
# src/score.py - Enhanced with A/B test tracking
import mlflow

def run(raw_data):
    model_version = os.getenv('MODEL_VERSION', '1.2.0')
    
    # Make prediction
    prediction = model.predict(data)
    
    # Log to MLflow for comparison
    with mlflow.start_run(experiment_id="attrition_ab_test"):
        mlflow.log_param("model_version", model_version)
        mlflow.log_param("deployment", os.getenv('DEPLOYMENT_NAME'))
        mlflow.log_metric("prediction_value", prediction[0])
        mlflow.log_metric("confidence_score", prediction_proba[0])
    
    # Also track in Prometheus for real-time monitoring
    prediction_requests_total.labels(
        model_version=model_version,
        deployment=os.getenv('DEPLOYMENT_NAME')
    ).inc()
    
    return json.dumps({
        "attrition_probability": prediction.tolist(),
        "model_version": model_version
    })
```

**3. Analysis Dashboard**

**Grafana Queries for A/B Comparison:**

```promql
# Request rate by model version
sum(rate(prediction_requests_total{model_version="1.2.0"}[5m]))
sum(rate(prediction_requests_total{model_version="1.3.0"}[5m]))

# Error rate comparison
sum(rate(prediction_errors_total{model_version="1.2.0"}[5m])) 
  / sum(rate(prediction_requests_total{model_version="1.2.0"}[5m]))

# Latency comparison
histogram_quantile(0.95, 
  rate(prediction_duration_seconds_bucket{model_version="1.2.0"}[5m]))
```

**4. Statistical Significance Testing**

```python
# scripts/analyze_ab_test.py
import pandas as pd
from scipy import stats

# Fetch metrics from Prometheus
blue_metrics = fetch_metrics(deployment='blue', duration='7d')
green_metrics = fetch_metrics(deployment='green', duration='7d')

# Compare key metrics
results = {
    'latency_p95': {
        'blue': np.percentile(blue_metrics['latency'], 95),
        'green': np.percentile(green_metrics['latency'], 95)
    },
    'error_rate': {
        'blue': blue_metrics['errors'] / blue_metrics['requests'],
        'green': green_metrics['errors'] / green_metrics['requests']
    }
}

# Chi-square test for error rate difference
chi2, p_value = stats.chi2_contingency([
    [blue_metrics['errors'], blue_metrics['success']],
    [green_metrics['errors'], green_metrics['success']]
])

if p_value < 0.05:
    print(f"Statistically significant difference detected (p={p_value:.4f})")
    if results['error_rate']['green'] < results['error_rate']['blue']:
        print("✅ Green model performs better - safe to promote")
    else:
        print("❌ Green model performs worse - rollback recommended")
```

**A/B Test Results (Actual Project):**

| Metric | Model v1.2.0 (Blue) | Model v1.3.0 (Green) | Change |
|--------|---------------------|----------------------|--------|
| **False Positive Rate** | 12% | 8% | ✅ -33% |
| **False Negative Rate** | 15% | 14% | ✅ -7% |
| **P95 Latency** | 50ms | 52ms | ⚠️ +4% |
| **Error Rate** | 0.5% | 0.4% | ✅ -20% |
| **AUC-ROC** | 0.87 | 0.91 | ✅ +4.6% |

**Decision:** Promoted v1.3.0 to 100% traffic after 7-day A/B test showed statistically significant improvement in false positive rate (critical for HR use case).

---

## Interview Question 4: Data Drift Detection & Automated Retraining

### Question:
*"How did you implement data drift detection for the attrition model, and what was your automated retraining strategy?"*

### Answer:

**Challenge:**
Employee demographics and work patterns shift over time (remote work adoption, new benefits programs, department restructuring). Models trained on historical data become stale, leading to degraded predictions.

#### Data Drift Detection Implementation

**1. Drift Monitoring Architecture**

```
Production Inference Data
  ↓
Azure Blob Storage (Daily Batches)
  ↓
Azure ML Data Drift Monitor (Weekly Schedule)
  ↓
Statistical Tests (KS, PSI, Chi-Square)
  ↓
Drift Alert → Azure Monitor → Email/Slack
  ↓
Trigger Retraining Pipeline
```

**2. Azure ML Data Drift Configuration**

```python
# scripts/setup_drift_monitor.py
from azureml.datadrift import DataDriftDetector
from azureml.core import Workspace, Dataset

ws = Workspace.from_config()

# Reference dataset (training data)
baseline_dataset = Dataset.get_by_name(ws, 'employee-attrition-train-2024')

# Target dataset (production inference data)
target_dataset = Dataset.get_by_name(ws, 'employee-attrition-production')

# Create drift detector
drift_detector = DataDriftDetector.create_from_datasets(
    workspace=ws,
    name='attrition-drift-monitor',
    baseline_data_set=baseline_dataset,
    target_data_set=target_dataset,
    compute_target='cpu-cluster',
    frequency='Week',
    feature_list=['age', 'tenure', 'satisfaction_score', 'performance_rating',
                  'work_hours', 'projects_count', 'salary'],
    drift_threshold=0.3,  # Alert if drift magnitude > 30%
    latency=24  # Hours to wait for data collection
)

# Configure alerts
drift_detector.enable_schedule()
drift_detector.update_alerting_config(
    alert_emails=['ml-team@company.com'],
    alert_on=['DriftDetected']
)
```

**3. Statistical Drift Tests**

**Kolmogorov-Smirnov Test (Continuous Features):**
```python
# scripts/custom_drift_detection.py
from scipy import stats
import numpy as np

def detect_drift_ks(baseline_data, production_data, threshold=0.05):
    """
    Detect drift using Kolmogorov-Smirnov test
    Returns: drift_detected, p_value, ks_statistic
    """
    results = {}
    
    for column in ['age', 'tenure', 'satisfaction_score', 'work_hours', 'salary']:
        baseline_col = baseline_data[column].dropna()
        production_col = production_data[column].dropna()
        
        # KS test
        ks_stat, p_value = stats.ks_2samp(baseline_col, production_col)
        
        drift_detected = p_value < threshold
        results[column] = {
            'drift_detected': drift_detected,
            'p_value': p_value,
            'ks_statistic': ks_stat,
            'baseline_mean': baseline_col.mean(),
            'production_mean': production_col.mean(),
            'mean_shift': ((production_col.mean() - baseline_col.mean()) 
                          / baseline_col.mean() * 100)
        }
    
    return results
```

**Population Stability Index (Categorical Features):**
```python
def calculate_psi(baseline_data, production_data, column, bins=10):
    """
    Calculate Population Stability Index for drift detection
    PSI < 0.1: No significant drift
    PSI 0.1-0.25: Moderate drift
    PSI > 0.25: Significant drift - retrain recommended
    """
    baseline_counts, bin_edges = np.histogram(baseline_data[column], bins=bins)
    production_counts, _ = np.histogram(production_data[column], bins=bin_edges)
    
    # Normalize to percentages
    baseline_pct = baseline_counts / len(baseline_data) + 1e-10
    production_pct = production_counts / len(production_data) + 1e-10
    
    # Calculate PSI
    psi = np.sum((production_pct - baseline_pct) * np.log(production_pct / baseline_pct))
    
    return psi
```

**4. Real-Time Drift Monitoring Dashboard**

```python
# Prometheus custom metrics for drift
from prometheus_client import Gauge

data_drift_magnitude = Gauge(
    'data_drift_magnitude',
    'Magnitude of detected data drift',
    ['feature_name']
)

feature_mean_shift = Gauge(
    'feature_mean_shift_percent',
    'Percentage shift in feature mean',
    ['feature_name']
)

# Update metrics weekly
for feature, drift_info in drift_results.items():
    data_drift_magnitude.labels(feature_name=feature).set(
        drift_info['ks_statistic']
    )
    feature_mean_shift.labels(feature_name=feature).set(
        drift_info['mean_shift']
    )
```

#### Automated Retraining Pipeline

**1. Retraining Trigger Logic**

```python
# scripts/check_and_trigger_retraining.py
def should_retrain(drift_results, model_performance):
    """
    Decision logic for triggering retraining
    """
    # Condition 1: Significant drift detected
    high_drift_features = [
        f for f, info in drift_results.items() 
        if info['drift_detected'] and abs(info['mean_shift']) > 15
    ]
    
    # Condition 2: Model performance degradation
    current_auc = model_performance['auc_roc']
    baseline_auc = 0.87
    auc_degradation = (baseline_auc - current_auc) / baseline_auc
    
    # Condition 3: Error rate increase
    current_error_rate = model_performance['error_rate']
    baseline_error_rate = 0.005
    
    # Decision
    if len(high_drift_features) >= 3:
        return True, f"High drift in {len(high_drift_features)} features"
    
    if auc_degradation > 0.05:  # >5% AUC drop
        return True, f"AUC degraded by {auc_degradation:.2%}"
    
    if current_error_rate > baseline_error_rate * 1.5:
        return True, f"Error rate increased to {current_error_rate:.3%}"
    
    return False, "No retraining needed"
```

**2. Automated Retraining Workflow**

```yaml
# .github/workflows/auto-retrain.yml
name: Automated Model Retraining

on:
  schedule:
    - cron: '0 2 * * 1'  # Every Monday at 2 AM
  workflow_dispatch:
    inputs:
      force_retrain:
        type: boolean
        default: false

jobs:
  check-drift:
    runs-on: ubuntu-latest
    outputs:
      should_retrain: ${{ steps.drift.outputs.retrain }}
    steps:
      - name: Download production data
        run: |
          az storage blob download-batch \
            --source production-inference-data \
            --destination ./data/production \
            --pattern "*.csv"
      
      - name: Run drift detection
        id: drift
        run: |
          python scripts/check_and_trigger_retraining.py \
            --baseline-data data/train/baseline.csv \
            --production-data data/production/*.csv \
            --output drift_report.json
          
          SHOULD_RETRAIN=$(jq -r '.should_retrain' drift_report.json)
          echo "retrain=$SHOULD_RETRAIN" >> $GITHUB_OUTPUT
  
  retrain-model:
    needs: check-drift
    if: needs.check-drift.outputs.should_retrain == 'true' || inputs.force_retrain
    runs-on: ubuntu-latest
    steps:
      - name: Prepare training data
        run: |
          # Combine historical + recent production data
          python scripts/prepare_training_data.py \
            --historical data/train/baseline.csv \
            --recent data/production/*.csv \
            --output data/train/updated_train.csv \
            --validation-split 0.2
      
      - name: Train new model
        run: |
          python src/train.py \
            --data data/train/updated_train.csv \
            --output outputs/model.pkl \
            --log-metrics
      
      - name: Validate new model
        run: |
          python scripts/validate_model.py \
            --model outputs/model.pkl \
            --test-data data/train/test.csv \
            --min-auc 0.85
      
      - name: Register model
        run: |
          az ml model create \
            --name employee-attrition-classifier \
            --version auto-increment \
            --path outputs/model.pkl \
            --type custom_model
      
      - name: Trigger deployment pipeline
        run: |
          gh workflow run cd-deploy.yml \
            -f model_version=$(az ml model list --name employee-attrition-classifier --query '[0].version' -o tsv)
```

**3. Continuous Model Performance Monitoring**

```python
# scripts/monitor_model_performance.py
from azureml.core import Workspace, Model
import mlflow

def monitor_production_performance():
    """
    Track model performance in production using inference results
    """
    ws = Workspace.from_config()
    
    # Get production predictions and actual outcomes (with time lag)
    predictions = load_production_predictions(days=30)
    actuals = load_actual_attrition(days=30)  # HR system feedback
    
    # Calculate metrics
    from sklearn.metrics import roc_auc_score, precision_recall_fscore_support
    
    auc = roc_auc_score(actuals, predictions)
    precision, recall, f1, _ = precision_recall_fscore_support(
        actuals, (predictions > 0.5).astype(int), average='binary'
    )
    
    # Log to MLflow
    with mlflow.start_run(experiment_id="production_monitoring"):
        mlflow.log_metric("production_auc", auc)
        mlflow.log_metric("production_precision", precision)
        mlflow.log_metric("production_recall", recall)
        mlflow.log_metric("production_f1", f1)
    
    # Alert if degradation
    if auc < 0.82:  # Threshold
        send_alert(
            message=f"⚠️ Model AUC dropped to {auc:.3f} in production",
            severity="high"
        )
```

#### Impact & Results

**Before Automated Drift Detection:**
- Manual quarterly model retraining
- Average model degradation: 8% AUC drop over 3 months
- 4 incidents of poor predictions causing HR process issues

**After Automated System:**
- **75% reduction in model degradation incidents** (4 → 1 in 12 months)
- Proactive retraining triggered 6 times in first year based on drift signals
- Average AUC maintained >0.85 (vs. 0.79 baseline degradation)
- Automated remediation reduced manual intervention from 40 hours/quarter to 5 hours/quarter

**Drift Detection Example:**

```
Week 24 (June 2024): Drift Alert Triggered
- Feature: satisfaction_score
- Baseline mean: 3.8 (scale 1-5)
- Production mean: 3.2
- Mean shift: -15.8%
- KS statistic: 0.24 (p < 0.001)
- Reason: Company restructuring impacted morale

Action Taken:
1. Automated retraining triggered
2. New model trained on last 6 months of data
3. Validation: AUC 0.89 (vs. 0.82 with old model on recent data)
4. Deployed to production after A/B test
5. Incident prevented: Would have had 23% higher false positives with old model
```

---

## Interview Question 5: MLOps Governance Framework

### Question:
*"Walk me through the MLOps governance framework you established. How do you ensure compliance, auditability, and model versioning in a regulated environment?"*

### Answer:

**Context:**
In HR applications handling employee data, we need robust governance for compliance with GDPR, SOC 2, and internal audit requirements. I designed a comprehensive MLOps governance framework covering the entire model lifecycle.

#### 1. Model Versioning Strategy

**Semantic Versioning:**
```
MAJOR.MINOR.PATCH
  ↓     ↓     ↓
  2  .  1  .  3

MAJOR: Breaking changes (feature set changes, architecture changes)
MINOR: Model improvements (retraining, hyperparameter tuning)
PATCH: Bug fixes (deployment config, inference code fixes)
```

**Implementation:**

```python
# scripts/version_model.py
import hashlib
import json
from datetime import datetime

def version_model(model_path, training_config, data_version):
    """
    Generate comprehensive model version metadata
    """
    # Calculate model file hash for integrity verification
    with open(model_path, 'rb') as f:
        model_hash = hashlib.sha256(f.read()).hexdigest()
    
    # Calculate training data hash
    data_hash = hashlib.sha256(open(data_version, 'rb').read()).hexdigest()
    
    version_metadata = {
        "model_version": "2.1.3",
        "created_at": datetime.now().isoformat(),
        "model_hash": model_hash,
        "training_data_hash": data_hash,
        "training_config": {
            "algorithm": "LogisticRegression",
            "hyperparameters": training_config,
            "features": [
                "age", "tenure", "satisfaction_score", "performance_rating",
                "work_hours", "projects_count", "promotion_flag", 
                "salary", "department_code"
            ],
            "training_samples": 15000,
            "validation_samples": 3000
        },
        "performance_metrics": {
            "auc_roc": 0.89,
            "accuracy": 0.85,
            "precision": 0.82,
            "recall": 0.78,
            "f1_score": 0.80
        },
        "compliance": {
            "pii_removed": True,
            "bias_tested": True,
            "explainability_enabled": True,
            "data_retention_policy": "3_years"
        }
    }
    
    # Save metadata
    with open(f'models/metadata_v{version_metadata["model_version"]}.json', 'w') as f:
        json.dump(version_metadata, f, indent=2)
    
    return version_metadata
```

**Azure ML Model Registry Integration:**

```python
# Register with full lineage
from azureml.core import Model

model = Model.register(
    workspace=ws,
    model_name="employee-attrition-classifier",
    model_path="outputs/model.pkl",
    model_framework="ScikitLearn",
    model_framework_version="1.5.0",
    tags={
        "version": "2.1.3",
        "stage": "production",
        "training_date": "2024-11-15",
        "data_version": "2024-Q4",
        "approved_by": "ml-lead@company.com",
        "compliance_check": "passed"
    },
    properties={
        "auc_roc": "0.89",
        "training_samples": "15000",
        "features_count": "9"
    },
    description="Employee attrition prediction v2.1.3 - Improved feature engineering"
)

# Create version alias for easy rollback
model.add_alias("production-current")
model.add_alias("approved-2024-11")
```

#### 2. Experiment Tracking with MLflow

**Full Reproducibility:**

```python
# src/train.py - Enhanced with MLflow tracking
import mlflow
import mlflow.sklearn

mlflow.set_tracking_uri("https://mlflow.company.com")
mlflow.set_experiment("employee-attrition-prediction")

with mlflow.start_run(run_name=f"training_v{version}"):
    # Log parameters
    mlflow.log_param("model_type", "LogisticRegression")
    mlflow.log_param("max_iter", 1000)
    mlflow.log_param("class_weight", "balanced")
    mlflow.log_param("solver", "lbfgs")
    mlflow.log_param("random_state", 42)
    
    # Log dataset info
    mlflow.log_param("training_data_path", data_path)
    mlflow.log_param("training_data_hash", data_hash)
    mlflow.log_param("num_samples", len(X_train))
    mlflow.log_param("num_features", X_train.shape[1])
    
    # Train model
    model = LogisticRegression(
        max_iter=1000,
        class_weight='balanced',
        random_state=42
    )
    model.fit(X_train, y_train)
    
    # Evaluate
    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1]
    
    # Log metrics
    mlflow.log_metric("accuracy", accuracy_score(y_test, y_pred))
    mlflow.log_metric("precision", precision_score(y_test, y_pred))
    mlflow.log_metric("recall", recall_score(y_test, y_pred))
    mlflow.log_metric("f1_score", f1_score(y_test, y_pred))
    mlflow.log_metric("auc_roc", roc_auc_score(y_test, y_proba))
    
    # Log confusion matrix
    cm = confusion_matrix(y_test, y_pred)
    mlflow.log_dict({"confusion_matrix": cm.tolist()}, "confusion_matrix.json")
    
    # Log feature importance
    feature_importance = dict(zip(feature_names, model.coef_[0]))
    mlflow.log_dict(feature_importance, "feature_importance.json")
    
    # Log model artifact
    mlflow.sklearn.log_model(model, "model", registered_model_name="employee-attrition-classifier")
    
    # Log training script
    mlflow.log_artifact("src/train.py")
    
    # Log training data sample (for reproducibility verification)
    X_train.head(100).to_csv("training_sample.csv", index=False)
    mlflow.log_artifact("training_sample.csv")
    
    # Tag for organization
    mlflow.set_tag("team", "hr-analytics")
    mlflow.set_tag("project", "attrition-prediction")
    mlflow.set_tag("environment", "production")
    mlflow.set_tag("compliance_reviewed", "yes")
```

**Experiment Comparison:**

```python
# scripts/compare_experiments.py
import mlflow
import pandas as pd

def compare_model_versions():
    """
    Compare multiple training runs to select best model
    """
    client = mlflow.tracking.MlflowClient()
    experiment = client.get_experiment_by_name("employee-attrition-prediction")
    
    runs = client.search_runs(
        experiment_ids=[experiment.experiment_id],
        filter_string="tags.environment = 'production'",
        order_by=["metrics.auc_roc DESC"],
        max_results=10
    )
    
    # Create comparison dataframe
    comparison = pd.DataFrame([
        {
            "run_id": run.info.run_id,
            "version": run.data.tags.get("version"),
            "date": run.info.start_time,
            "auc_roc": run.data.metrics.get("auc_roc"),
            "accuracy": run.data.metrics.get("accuracy"),
            "precision": run.data.metrics.get("precision"),
            "recall": run.data.metrics.get("recall")
        }
        for run in runs
    ])
    
    print(comparison)
    return comparison
```

#### 3. Compliance-Ready Audit Trails

**Comprehensive Logging:**

```python
# scripts/audit_logger.py
import logging
import json
from datetime import datetime

class AuditLogger:
    """
    GDPR/SOC2 compliant audit logging for ML operations
    """
    
    def __init__(self, log_path="logs/ml_audit.jsonl"):
        self.log_path = log_path
        self.logger = logging.getLogger("ml_audit")
    
    def log_model_training(self, user, model_version, data_source):
        """Log model training event"""
        audit_entry = {
            "timestamp": datetime.now().isoformat(),
            "event_type": "MODEL_TRAINING",
            "user": user,
            "model_version": model_version,
            "data_source": data_source,
            "data_contains_pii": False,  # PII removed in preprocessing
            "data_anonymization": "applied",
            "compliance_check": "passed"
        }
        self._write_audit_log(audit_entry)
    
    def log_model_deployment(self, user, model_version, environment, approver):
        """Log model deployment event"""
        audit_entry = {
            "timestamp": datetime.now().isoformat(),
            "event_type": "MODEL_DEPLOYMENT",
            "user": user,
            "model_version": model_version,
            "environment": environment,
            "approved_by": approver,
            "approval_timestamp": datetime.now().isoformat(),
            "deployment_justification": "Improved AUC-ROC by 4.6% in A/B test"
        }
        self._write_audit_log(audit_entry)
    
    def log_prediction_request(self, user, model_version, num_records, purpose):
        """Log prediction request (batch predictions only - not individual)"""
        audit_entry = {
            "timestamp": datetime.now().isoformat(),
            "event_type": "PREDICTION_REQUEST",
            "user": user,
            "model_version": model_version,
            "num_records": num_records,
            "purpose": purpose,
            "data_access_authorized": True,
            "data_retention": "30_days"
        }
        self._write_audit_log(audit_entry)
    
    def log_model_access(self, user, model_version, access_type):
        """Log model artifact access"""
        audit_entry = {
            "timestamp": datetime.now().isoformat(),
            "event_type": "MODEL_ACCESS",
            "user": user,
            "model_version": model_version,
            "access_type": access_type,  # download, view_metadata, delete
            "ip_address": self._get_client_ip()
        }
        self._write_audit_log(audit_entry)
    
    def _write_audit_log(self, entry):
        """Write to append-only audit log"""
        with open(self.log_path, 'a') as f:
            f.write(json.dumps(entry) + '\n')
        
        # Also send to Azure Log Analytics for compliance team
        self._send_to_azure_monitor(entry)
```

**Audit Log Retention:**
```yaml
# Azure Policy for log retention
audit_logs:
  retention_period: 7_years  # SOC2 requirement
  encryption: AES-256
  access_control: RBAC
  immutable: true  # Cannot be deleted/modified
  backup_schedule: daily
  geo_replication: enabled
```

#### 4. Model Explainability & Bias Testing

**SHAP (SHapley Additive exPlanations) Integration:**

```python
# scripts/explain_model.py
import shap
import matplotlib.pyplot as plt

def generate_model_explanations(model, X_test, output_path="explanations/"):
    """
    Generate SHAP explanations for model interpretability
    Required for regulatory compliance
    """
    # Create SHAP explainer
    explainer = shap.Explainer(model, X_test)
    shap_values = explainer(X_test)
    
    # Global feature importance
    shap.summary_plot(shap_values, X_test, show=False)
    plt.savefig(f"{output_path}/global_importance.png")
    plt.close()
    
    # Feature importance values
    feature_importance = pd.DataFrame({
        'feature': X_test.columns,
        'importance': abs(shap_values.values).mean(axis=0)
    }).sort_values('importance', ascending=False)
    
    feature_importance.to_csv(f"{output_path}/feature_importance.csv", index=False)
    
    # Log to MLflow
    mlflow.log_artifact(f"{output_path}/global_importance.png")
    mlflow.log_artifact(f"{output_path}/feature_importance.csv")
    
    return feature_importance

def explain_individual_prediction(model, employee_data):
    """
    Explain specific prediction for HR review
    """
    explainer = shap.Explainer(model)
    shap_values = explainer(employee_data)
    
    explanation = {
        "prediction": model.predict_proba(employee_data)[0][1],
        "top_factors": []
    }
    
    # Top 5 contributing factors
    feature_contributions = zip(employee_data.columns, shap_values.values[0])
    sorted_contributions = sorted(feature_contributions, key=lambda x: abs(x[1]), reverse=True)
    
    for feature, contribution in sorted_contributions[:5]:
        explanation["top_factors"].append({
            "feature": feature,
            "value": employee_data[feature].values[0],
            "contribution": float(contribution),
            "impact": "increases" if contribution > 0 else "decreases"
        })
    
    return explanation
```

**Bias Detection & Mitigation:**

```python
# scripts/test_fairness.py
from fairlearn.metrics import MetricFrame, selection_rate, false_positive_rate
import pandas as pd

def test_model_fairness(model, X_test, y_test, sensitive_features):
    """
    Test model for bias across protected attributes
    Required for HR compliance
    """
    y_pred = model.predict(X_test)
    
    # Test across departments (proxy for demographic groups in HR data)
    metric_frame = MetricFrame(
        metrics={
            "selection_rate": selection_rate,
            "false_positive_rate": false_positive_rate,
            "false_negative_rate": lambda y_true, y_pred: 
                (y_true & ~y_pred).sum() / y_true.sum()
        },
        y_true=y_test,
        y_pred=y_pred,
        sensitive_features=sensitive_features['department']
    )
    
    # Check for disparate impact
    disparate_impact = (
        metric_frame.by_group['selection_rate'].min() /
        metric_frame.by_group['selection_rate'].max()
    )
    
    # 80% rule: Disparate impact should be >= 0.8
    fairness_passed = disparate_impact >= 0.8
    
    fairness_report = {
        "fairness_passed": fairness_passed,
        "disparate_impact": disparate_impact,
        "metrics_by_group": metric_frame.by_group.to_dict(),
        "max_fpr_difference": metric_frame.by_group['false_positive_rate'].max() - 
                             metric_frame.by_group['false_positive_rate'].min()
    }
    
    # Log to MLflow
    mlflow.log_dict(fairness_report, "fairness_report.json")
    mlflow.log_metric("disparate_impact", disparate_impact)
    
    if not fairness_passed:
        raise ValueError(f"Model failed fairness test: disparate impact = {disparate_impact:.3f}")
    
    return fairness_report
```

#### 5. Access Control & Security

**Role-Based Access Control (RBAC):**

```yaml
# Azure ML Workspace Roles
roles:
  ml_engineers:
    permissions:
      - read_experiments
      - create_experiments
      - register_models
      - read_compute
    members:
      - mlteam@company.com
  
  ml_lead:
    permissions:
      - all_ml_engineer_permissions
      - approve_model_deployment
      - delete_models
      - manage_compute
    members:
      - ml-lead@company.com
  
  data_scientists:
    permissions:
      - read_experiments
      - read_models
      - read_data
    members:
      - datascience@company.com
  
  compliance_auditors:
    permissions:
      - read_audit_logs
      - read_experiments
      - read_models
      - view_model_explanations
    members:
      - compliance@company.com
```

**Model Artifact Encryption:**

```python
# All model artifacts encrypted at rest
azure_ml_config = {
    "encryption": {
        "enabled": True,
        "key_vault": "mlops-keyvault",
        "key_name": "model-encryption-key",
        "key_version": "latest"
    },
    "network_isolation": {
        "private_endpoint": True,
        "vnet": "mlops-vnet",
        "subnet": "ml-workspace-subnet"
    }
}
```

#### 6. Compliance Checklist Integration

**Pre-Deployment Validation:**

```python
# scripts/compliance_check.py
class ComplianceValidator:
    """
    Automated compliance checks before model deployment
    """
    
    def validate_model_for_production(self, model_version):
        checks = {
            "version_metadata_complete": self._check_metadata(model_version),
            "performance_threshold_met": self._check_performance(model_version),
            "fairness_test_passed": self._check_fairness(model_version),
            "explainability_available": self._check_explainability(model_version),
            "audit_trail_complete": self._check_audit_logs(model_version),
            "security_scan_passed": self._check_security(model_version),
            "data_privacy_compliant": self._check_privacy(model_version),
            "approval_obtained": self._check_approval(model_version)
        }
        
        all_passed = all(checks.values())
        
        report = {
            "model_version": model_version,
            "compliance_status": "PASSED" if all_passed else "FAILED",
            "checks": checks,
            "timestamp": datetime.now().isoformat()
        }
        
        # Save compliance certificate
        with open(f"compliance/cert_{model_version}.json", 'w') as f:
            json.dump(report, f, indent=2)
        
        if not all_passed:
            failed_checks = [k for k, v in checks.items() if not v]
            raise ComplianceError(
                f"Model {model_version} failed compliance checks: {failed_checks}"
            )
        
        return report
```

#### Governance Framework Benefits

**Quantified Impact:**

1. **Audit Time Reduced:**
   - Before: 40 hours per quarterly audit
   - After: 8 hours (automated reports)
   - **80% reduction**

2. **Compliance Incidents:**
   - Before: 3 issues per year (missing documentation, unapproved deployments)
   - After: 0 issues in 12 months
   - **100% compliance**

3. **Model Rollback Speed:**
   - Before: 2 hours (manual process)
   - After: 5 minutes (versioned artifacts)
   - **96% faster**

4. **Experiment Reproducibility:**
   - Before: 60% reproducible (missing dependencies, data versions)
   - After: 100% reproducible (MLflow tracking)

---

## Additional Interview Talking Points

### Project Metrics & Business Impact

**Technical Achievements:**
- **Latency:** 50ms p95 inference latency (4x improvement over baseline)
- **Throughput:** 300 requests/second peak capacity (15x improvement)
- **Uptime:** 99.9% SLA achieved (staging) + 99.95% actual (production AKS)
- **Cost Optimization:** 25% reduction through AKS vs managed endpoints
- **Automation:** 80% reduction in manual deployment time

**Business Impact:**
- **Attrition Prediction Accuracy:** 89% AUC-ROC (vs 87% baseline)
- **False Positive Reduction:** 33% fewer false positives (v1.3.0 vs v1.2.0)
- **Time to Production:** 3 days (model training → prod) vs 2 weeks previously
- **HR Productivity:** Enabled proactive retention programs 2 months earlier
- **Cost Avoidance:** $50K/year in reduced employee turnover (estimated)

### Technology Choices & Trade-offs

**Why Azure ML + AKS Hybrid?**
- Azure ML for staging: Fast iteration, built-in monitoring, SLA-backed
- AKS for production: Cost-effective at scale, full control, custom optimizations
- Best of both worlds: Managed simplicity + performance flexibility

**Why Prometheus + Grafana?**
- Open-source, Kubernetes-native
- Powerful PromQL query language
- Industry-standard for observability
- Easy integration with alert managers
- Cost-effective vs commercial APM tools

**Why GitHub Actions vs Azure DevOps?**
- Single platform (code + CI/CD)
- Rich marketplace of actions
- Easy integration with GitHub repos
- YAML-based, version-controlled pipelines
- Free for public repos, affordable for private

### Lessons Learned

1. **Start with Monitoring:** Built Prometheus metrics into MVP, saved debugging time later
2. **Automate Everything:** Manual processes = human error; automated pipelines = consistency
3. **Version Everything:** Models, data, configs, code - full reproducibility is critical
4. **Test in Production-Like Environment:** Staging endpoint caught 3 major issues before prod
5. **Governance from Day 1:** Easier to build in compliance than retrofit later

### Future Enhancements

**If asked "What would you improve?"**

1. **Feature Store:** Centralize feature engineering for consistency across models
2. **Shadow Deployment:** Run new model versions in parallel with production for A/B testing
3. **GPU Support:** Add GPU nodes to AKS for deep learning models (future use cases)
4. **Multi-Region Deployment:** Geographic redundancy for global availability
5. **Advanced Drift Detection:** Real-time drift detection (vs weekly batch) using streaming data
6. **Automated Model Optimization:** AutoML for hyperparameter tuning on retraining triggers

---

## STAR Method Response Template

**For behavioral questions, use this structure:**

### Situation
"In my previous role, the HR team needed a way to predict employee attrition to implement proactive retention strategies..."

### Task
"I was tasked with building an end-to-end MLOps pipeline that could automate model training, ensure compliance with GDPR/SOC2, and provide real-time predictions with <100ms latency..."

### Action
"I architected a hybrid solution using Azure ML for staging and custom AKS infrastructure for production. Specifically, I:
1. Designed automated training pipelines with MLflow tracking
2. Implemented Prometheus monitoring with custom metrics
3. Built blue-green deployment strategy for zero-downtime updates
4. Created data drift detection with automated retraining triggers
5. Established comprehensive governance with audit trails and SHAP explainability"

### Result
"This resulted in 99.9% uptime, 3x performance improvement over managed endpoints, 75% reduction in model degradation incidents, and full compliance with audit requirements. The system has processed over 2 million predictions in production with zero compliance incidents."

---

## Quick Reference - Key Numbers to Memorize

| Metric | Value |
|--------|-------|
| **Uptime SLA** | 99.9% (staging), 99.95% (production) |
| **Latency (p95)** | 50ms |
| **Throughput** | 300 req/sec |
| **Performance Improvement** | 3x vs baseline |
| **Drift Detection Reduction** | 75% fewer incidents |
| **Cost Savings** | 25% (AKS vs managed) |
| **Model AUC-ROC** | 0.89 |
| **False Positive Reduction** | 33% (v1.3.0 vs v1.2.0) |
| **Deployment Time** | 3 days (vs 2 weeks) |
| **Audit Time Reduction** | 80% (40h → 8h) |
| **Features** | 9 (age, tenure, satisfaction, etc.) |
| **Training Samples** | 15,000 |
| **Autoscaling Range** | 3-10 pods |

---

**Good luck with your interview! This project demonstrates enterprise-grade MLOps expertise.** 🚀
