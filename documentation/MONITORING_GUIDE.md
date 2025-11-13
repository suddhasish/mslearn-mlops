# MLOps Monitoring Guide

This guide covers monitoring strategies for both staging (Azure ML) and production (AKS) deployments.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Stack                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Staging (Azure ML Managed Endpoint)                         │
│  ├── Application Insights (built-in)                         │
│  ├── Azure Monitor Metrics                                   │
│  └── Log Analytics Workspace                                 │
│                                                               │
│  Production (AKS)                                             │
│  ├── Prometheus (metrics collection)                         │
│  ├── Grafana (visualization)                                 │
│  ├── Application Insights (optional - Azure integration)     │
│  └── Azure Monitor for Containers                            │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Staging Monitoring (Azure ML Managed Endpoints)

### Built-in Azure Monitor

Your staging endpoint automatically sends metrics to Application Insights:

**Available Metrics:**
- Request rate (requests/sec)
- Request latency (p50, p95, p99)
- Error rate and HTTP status codes
- CPU/Memory utilization
- Model-specific metrics (if logged)

**Access via Azure Portal:**
```bash
# Navigate to:
Azure Portal → ML Workspace (mlopsnew-dev-mlw) 
           → Endpoints → ml-endpoint-staging 
           → Metrics/Logs
```

### Query with KQL (Kusto Query Language)

```kusto
// Request latency percentiles
requests
| where cloud_RoleName == "ml-endpoint-staging"
| summarize 
    avg_latency = avg(duration),
    p50 = percentile(duration, 50),
    p95 = percentile(duration, 95),
    p99 = percentile(duration, 99)
  by bin(timestamp, 5m)
| render timechart

// Error rate
requests
| where cloud_RoleName == "ml-endpoint-staging"
| summarize 
    total = count(),
    errors = countif(success == false)
  by bin(timestamp, 5m)
| extend error_rate = (errors * 100.0 / total)
| render timechart

// Top slowest requests
requests
| where cloud_RoleName == "ml-endpoint-staging"
| top 100 by duration desc
| project timestamp, name, duration, resultCode, url

// Exception tracking
exceptions
| where cloud_RoleName == "ml-endpoint-staging"
| summarize count() by type, outerMessage
| order by count_ desc
```

### Create Alerts

```bash
# CPU alert
az monitor metrics alert create \
  --name staging-high-cpu \
  --resource-group mlopsnew-dev-rg \
  --scopes /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg/providers/Microsoft.MachineLearningServices/workspaces/mlopsnew-dev-mlw/onlineEndpoints/ml-endpoint-staging \
  --condition "avg Percentage CPU > 80" \
  --window-size 5m \
  --evaluation-frequency 1m

# Error rate alert
az monitor metrics alert create \
  --name staging-high-errors \
  --resource-group mlopsnew-dev-rg \
  --scopes /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg/providers/Microsoft.MachineLearningServices/workspaces/mlopsnew-dev-mlw/onlineEndpoints/ml-endpoint-staging \
  --condition "avg RequestFailureRate > 5" \
  --window-size 5m \
  --evaluation-frequency 1m
```

---

## 2. Production Monitoring (AKS with Prometheus + Grafana)

### Option A: Full Stack Setup (Recommended)

#### Step 1: Install Prometheus Operator on AKS

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (includes Prometheus, Grafana, AlertManager)
kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.enabled=true \
  --set grafana.adminPassword='YourSecurePassword123!' \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi
```

#### Step 2: Expose Application Metrics

Add Prometheus metrics endpoint to your Flask app. Update `src/score.py`:

```python
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST

# Metrics
PREDICTION_COUNT = Counter('model_predictions_total', 'Total predictions', ['model_name', 'status'])
PREDICTION_LATENCY = Histogram('model_prediction_duration_seconds', 'Prediction latency', ['model_name'])
MODEL_VERSION = Gauge('model_version_info', 'Model version', ['model_name', 'version'])
ERROR_COUNT = Counter('model_errors_total', 'Total errors', ['model_name', 'error_type'])
```

Then add `/metrics` endpoint to your Flask wrapper in Dockerfile:

```python
@app.route("/metrics", methods=["GET"])
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}
```

#### Step 3: Create ServiceMonitor

Create `kubernetes/ml-inference-servicemonitor.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ml-inference-metrics
  namespace: production
  labels:
    app: ml-inference
spec:
  type: ClusterIP
  selector:
    app: ml-inference
  ports:
    - name: metrics
      port: 5001
      targetPort: 5001
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ml-inference
  namespace: production
  labels:
    app: ml-inference
    release: prometheus  # Must match Prometheus selector
spec:
  selector:
    matchLabels:
      app: ml-inference
  endpoints:
    - port: metrics
      path: /metrics
      interval: 30s
```

Apply:
```bash
kubectl apply -f kubernetes/ml-inference-servicemonitor.yaml
```

#### Step 4: Access Grafana

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access at: http://localhost:3000
# Username: admin
# Password: YourSecurePassword123!
```

#### Step 5: Import ML Inference Dashboard

Create custom dashboard in Grafana or use this JSON:

**Key Panels:**
- Request rate (requests/sec)
- Prediction latency (p50, p95, p99)
- Error rate
- Pod CPU/Memory usage
- Model version info

**Example PromQL Queries:**

```promql
# Request rate
rate(model_predictions_total[5m])

# Prediction latency (p95)
histogram_quantile(0.95, rate(model_prediction_duration_seconds_bucket[5m]))

# Error rate
rate(model_errors_total[5m]) / rate(model_predictions_total[5m]) * 100

# Pod CPU usage
rate(container_cpu_usage_seconds_total{namespace="production",pod=~"ml-inference.*"}[5m])

# Pod memory usage
container_memory_working_set_bytes{namespace="production",pod=~"ml-inference.*"}
```

---

### Option B: Azure Monitor for Containers (Simpler)

Azure provides native monitoring for AKS without Prometheus/Grafana:

#### Enable Container Insights

```bash
az aks enable-addons \
  --resource-group mlopsnew-dev-rg \
  --name mlopsnew-dev-aks \
  --addons monitoring \
  --workspace-resource-id /subscriptions/b2b8a5e6-9a34-494b-ba62-fe9be95bd398/resourceGroups/mlopsnew-dev-rg/providers/Microsoft.OperationalInsights/workspaces/mlopsnew-dev-law
```

**Available Metrics:**
- Container CPU/Memory
- Pod status and restarts
- Node resource utilization
- Kubernetes events

**Query Logs:**

```kusto
// Pod performance
Perf
| where ObjectName == "K8SContainer"
| where InstanceName contains "ml-inference"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m), CounterName
| render timechart

// Container logs
ContainerLog
| where Name contains "ml-inference"
| where LogEntry contains "ERROR" or LogEntry contains "WARN"
| project TimeGenerated, LogEntry
| order by TimeGenerated desc

// Pod restarts
KubePodInventory
| where Name contains "ml-inference"
| where Namespace == "production"
| summarize RestartCount = sum(ContainerRestartCount) by bin(TimeGenerated, 1h)
| render timechart
```

---

### Option C: Hybrid Approach (Best of Both Worlds)

Combine Prometheus/Grafana for detailed application metrics with Azure Monitor for infrastructure:

1. **Prometheus/Grafana**: Application-level metrics (predictions, latency, errors)
2. **Azure Monitor**: Infrastructure metrics (CPU, memory, disk, network)
3. **Application Insights**: Optional - add Azure SDK to push custom metrics

---

## 3. Custom Metrics Implementation

### Update score.py with Prometheus Metrics

Add to `src/score.py`:

```python
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST, REGISTRY
import time

# Initialize metrics
PREDICTION_COUNT = Counter(
    'model_predictions_total',
    'Total number of predictions',
    ['model_name', 'model_version', 'status']
)

PREDICTION_LATENCY = Histogram(
    'model_prediction_duration_seconds',
    'Time spent on prediction',
    ['model_name', 'model_version'],
    buckets=[0.001, 0.01, 0.05, 0.1, 0.5, 1.0, 2.5, 5.0, 10.0]
)

MODEL_INFO = Gauge(
    'model_info',
    'Model metadata',
    ['model_name', 'model_version', 'framework']
)

ERROR_COUNT = Counter(
    'model_errors_total',
    'Total number of errors',
    ['model_name', 'error_type']
)

def run(data):
    """Enhanced run function with metrics"""
    start_time = time.time()
    model_name = os.getenv("MODEL_NAME", "unknown")
    model_version = os.getenv("MODEL_VERSION", "unknown")
    
    try:
        # Existing prediction logic...
        result = MODEL.predict(X)
        
        # Record success
        duration = time.time() - start_time
        PREDICTION_LATENCY.labels(
            model_name=model_name,
            model_version=model_version
        ).observe(duration)
        
        PREDICTION_COUNT.labels(
            model_name=model_name,
            model_version=model_version,
            status='success'
        ).inc()
        
        return result
        
    except Exception as e:
        # Record error
        ERROR_COUNT.labels(
            model_name=model_name,
            error_type=type(e).__name__
        ).inc()
        
        PREDICTION_COUNT.labels(
            model_name=model_name,
            model_version=model_version,
            status='error'
        ).inc()
        
        raise

def get_metrics():
    """Return Prometheus metrics"""
    return generate_latest(REGISTRY), 200, {'Content-Type': CONTENT_TYPE_LATEST}
```

### Update Dockerfile to expose /metrics

Modify the Flask app creation in Dockerfile:

```dockerfile
# Add metrics endpoint
@app.route("/metrics", methods=["GET"])\n\
def metrics():\n\
    from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, REGISTRY\n\
    return generate_latest(REGISTRY), 200, {\"Content-Type\": CONTENT_TYPE_LATEST}\n\
```

---

## 4. Alerting

### Prometheus AlertManager Rules

Create `kubernetes/ml-inference-alerts.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ml-inference-alerts
  namespace: production
  labels:
    release: prometheus
spec:
  groups:
    - name: ml-inference
      interval: 30s
      rules:
        - alert: HighErrorRate
          expr: |
            rate(model_errors_total[5m]) / rate(model_predictions_total[5m]) > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "High error rate detected"
            description: "Error rate is {{ $value | humanizePercentage }} over the last 5 minutes"
        
        - alert: HighLatency
          expr: |
            histogram_quantile(0.95, rate(model_prediction_duration_seconds_bucket[5m])) > 2
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High prediction latency"
            description: "P95 latency is {{ $value }}s"
        
        - alert: PodCrashLooping
          expr: |
            rate(kube_pod_container_status_restarts_total{namespace="production",pod=~"ml-inference.*"}[15m]) > 0
          labels:
            severity: critical
          annotations:
            summary: "Pod is crash looping"
            description: "Pod {{ $labels.pod }} is restarting frequently"
```

---

## 5. Grafana Dashboard Example

**Dashboard ID:** Import from Grafana.com or create custom

**Key Metrics to Display:**

1. **Request Rate Panel** (Graph)
   ```promql
   sum(rate(model_predictions_total[5m])) by (status)
   ```

2. **Latency Percentiles** (Graph)
   ```promql
   histogram_quantile(0.50, rate(model_prediction_duration_seconds_bucket[5m]))
   histogram_quantile(0.95, rate(model_prediction_duration_seconds_bucket[5m]))
   histogram_quantile(0.99, rate(model_prediction_duration_seconds_bucket[5m]))
   ```

3. **Error Rate** (Single Stat)
   ```promql
   sum(rate(model_errors_total[5m])) / sum(rate(model_predictions_total[5m])) * 100
   ```

4. **Pod Resource Usage** (Graph)
   ```promql
   # CPU
   sum(rate(container_cpu_usage_seconds_total{namespace="production",pod=~"ml-inference.*"}[5m])) by (pod)
   
   # Memory
   sum(container_memory_working_set_bytes{namespace="production",pod=~"ml-inference.*"}) by (pod)
   ```

---

## 6. Quick Setup Commands

### For Full Monitoring Stack:

```bash
# 1. Install Prometheus + Grafana
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# 2. Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# 3. Apply ServiceMonitor
kubectl apply -f kubernetes/ml-inference-servicemonitor.yaml

# 4. Apply Alert Rules
kubectl apply -f kubernetes/ml-inference-alerts.yaml

# 5. Access Grafana at http://localhost:3000 (admin / prom-operator)
```

### For Azure Monitor Only:

```bash
# Enable Container Insights
az aks enable-addons \
  --resource-group mlopsnew-dev-rg \
  --name mlopsnew-dev-aks \
  --addons monitoring \
  --workspace-resource-id $(az monitor log-analytics workspace show \
    --resource-group mlopsnew-dev-rg \
    --workspace-name mlopsnew-dev-law \
    --query id -o tsv)

# View metrics in Azure Portal
```

---

## 7. Cost Considerations

| Solution | Cost | Setup Complexity | Features |
|----------|------|------------------|----------|
| Azure Monitor for Containers | $$ (pay per GB ingested) | Low | Basic metrics, logs |
| Prometheus + Grafana (self-hosted) | $ (compute only) | Medium | Full control, custom metrics |
| Azure Application Insights | $$$ (pay per GB) | Low | Deep integration, APM |
| Hybrid (Prometheus + Azure Monitor) | $$ | High | Best of both worlds |

**Recommendation:**
- **Start**: Azure Monitor for Containers (already have Log Analytics)
- **Scale**: Add Prometheus + Grafana for detailed application metrics
- **Enterprise**: Add Application Insights for full observability

---

## 8. Next Steps

1. Choose monitoring approach (recommend: Start with Azure Monitor, add Prometheus later)
2. Add Prometheus metrics to `score.py` (see code above)
3. Update Dockerfile to expose `/metrics` endpoint
4. Deploy ServiceMonitor and AlertManager rules
5. Create Grafana dashboards
6. Set up alerting (email/Slack/Teams)

Would you like me to implement any of these monitoring solutions now?
