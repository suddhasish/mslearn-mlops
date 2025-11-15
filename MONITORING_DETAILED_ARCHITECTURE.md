# MLOps Monitoring Architecture - Complete Technical Guide

**Version:** 1.0  
**Last Updated:** November 15, 2025  
**Status:** Production Ready

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Component Deep Dive](#component-deep-dive)
3. [Data Flow & Lifecycle](#data-flow--lifecycle)
4. [Metrics Instrumentation](#metrics-instrumentation)
5. [Service Discovery](#service-discovery)
6. [Alert Configuration](#alert-configuration)
7. [Storage & Query Engine](#storage--query-engine)
8. [Visualization Layer](#visualization-layer)
9. [Deployment Automation](#deployment-automation)
10. [Troubleshooting Guide](#troubleshooting-guide)
11. [Production Best Practices](#production-best-practices)

---

## Architecture Overview

### System Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│                           USER REQUEST                               │
│                    POST /score {"data": [...]}                       │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Azure Load Balancer Service                       │
│                    Type: LoadBalancer                                │
│                    External IP: 48.223.198.209                       │
│                    Port: 80 → Target: 5001                          │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Kubernetes Service: ml-inference                        │
│              Selector: app=ml-inference                              │
│              ClusterIP: 172.16.74.22                                │
│              Endpoints: 10.0.2.16, 10.0.2.31, 10.0.2.48             │
└─────┬───────────────┬───────────────┬───────────────┬───────────────┘
      │               │               │               │
      ▼               ▼               ▼               ▼
┌──────────┐    ┌──────────┐    ┌──────────┐    Prometheus
│  Pod 1   │    │  Pod 2   │    │  Pod 3   │    Scrapes ↓
│ Flask    │    │ Flask    │    │ Flask    │         
│ score.py │    │ score.py │    │ score.py │    ┌────────────┐
│ :5001    │    │ :5001    │    │ :5001    │────│ Prometheus │
└──────────┘    └──────────┘    └──────────┘    │  Server    │
      │               │               │          │  :9090     │
      └───────────────┴───────────────┘          └─────┬──────┘
                      │                                │
              /metrics endpoint                        │
              (Prometheus format)                      │
                                                       ▼
                                            ┌──────────────────┐
                                            │   Alertmanager   │
                                            │   - Routes       │
                                            │   - Deduplicates │
                                            │   - Notifies     │
                                            └──────────────────┘
                                                       │
                                                       ▼
                                            ┌──────────────────┐
                                            │     Grafana      │
                                            │  http://....:59  │
                                            │  Dashboards      │
                                            └──────────────────┘
```

### Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Instrumentation** | `prometheus_client` (Python) | Generate metrics in application code |
| **Exposition** | Flask `/metrics` endpoint | Expose metrics in Prometheus format |
| **Service Discovery** | Kubernetes ServiceMonitor CRD | Tell Prometheus which pods to scrape |
| **Collection** | Prometheus Server | Scrape and store time-series data |
| **Alert Rules** | PrometheusRule CRD | Define alerting thresholds |
| **Alert Routing** | Alertmanager | Route, deduplicate, and send alerts |
| **Visualization** | Grafana | Dashboard and exploration UI |
| **Deployment** | Helm (kube-prometheus-stack) | Package all components together |

---

## Component Deep Dive

### 1. Application Instrumentation Layer

#### File Structure
```
src/
├── score.py              # ML inference with Prometheus metrics
├── app.py               # Flask app (if separate)
└── Dockerfile           # Adds /metrics endpoint to Flask
```

#### score.py - Metrics Definition

```python
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
import time
import json

# =============================================================================
# METRIC DEFINITIONS (Module Level - Created Once)
# =============================================================================

# COUNTER: Monotonically increasing value (never decreases)
# Use for: Total requests, total errors, total bytes processed
prediction_requests_total = Counter(
    'prediction_requests_total',              # Metric name
    'Total number of prediction requests',    # Help text
    ['model_name', 'model_version', 'status'] # Labels for filtering
)

# Labels allow filtering like:
# prediction_requests_total{status="success"}
# prediction_requests_total{status="failure"}

prediction_errors_total = Counter(
    'prediction_errors_total',
    'Total number of prediction errors',
    ['model_name', 'model_version', 'error_type']
)

# HISTOGRAM: Tracks distribution of values
# Use for: Request duration, response size, batch size
prediction_duration_seconds = Histogram(
    'prediction_duration_seconds',
    'Time spent processing prediction request',
    ['model_name', 'model_version'],
    buckets=(
        0.005, 0.01, 0.025, 0.05, 0.075, 0.1,    # 5ms to 100ms
        0.25, 0.5, 0.75, 1.0,                     # 250ms to 1s
        2.5, 5.0, 7.5, 10.0, float('inf')        # 2.5s to infinity
    )
)
# Histogram generates multiple series:
# - prediction_duration_seconds_bucket{le="0.005"}  # Requests < 5ms
# - prediction_duration_seconds_bucket{le="0.01"}   # Requests < 10ms
# - prediction_duration_seconds_sum                 # Total time
# - prediction_duration_seconds_count               # Total requests

# GAUGE: Value that can go up or down
# Use for: Current memory usage, queue length, active connections
model_info = Gauge(
    'model_info',
    'Information about the loaded model',
    ['model_name', 'model_version', 'deployment', 'sklearn_version']
)

# =============================================================================
# INITIALIZATION - Called Once When Container Starts
# =============================================================================

def init():
    """Initialize model and set static metrics"""
    global model, MODEL_NAME, MODEL_VERSION, DEPLOYMENT_NAME
    
    logger.info(f"Initializing model service - Version: {MODEL_VERSION}")
    
    # Load ML model
    model_path = os.getenv('AZUREML_MODEL_FILE', '/app/model/model.pkl')
    model = joblib.load(model_path)
    
    # Set model info gauge (stays at 1.0 while pod is alive)
    model_info.labels(
        model_name=MODEL_NAME,
        model_version=MODEL_VERSION,
        deployment=DEPLOYMENT_NAME,
        sklearn_version=sklearn.__version__
    ).set(1)
    
    logger.info("Model initialization completed")

# =============================================================================
# REQUEST HANDLING - Called For Each Prediction
# =============================================================================

def run(raw_data):
    """Process prediction request and record metrics"""
    
    # Start timing
    start_time = time.time()
    
    try:
        # Parse input
        data = json.loads(raw_data)
        input_data = data['data']
        
        # Validate input shape
        if not isinstance(input_data, list) or len(input_data[0]) != 9:
            raise ValueError("Input must be list of 9 features")
        
        # Make prediction
        prediction = model.predict(input_data)
        result = prediction.tolist()
        
        # ===== RECORD SUCCESS METRICS =====
        
        # Increment success counter
        prediction_requests_total.labels(
            model_name=MODEL_NAME,
            model_version=MODEL_VERSION,
            status='success'
        ).inc()  # Increment by 1
        
        # Record duration in histogram
        duration = time.time() - start_time
        prediction_duration_seconds.labels(
            model_name=MODEL_NAME,
            model_version=MODEL_VERSION
        ).observe(duration)  # Add sample to histogram
        
        logger.info(f"Prediction successful in {duration:.3f}s")
        
        return json.dumps({"result": result})
        
    except ValueError as e:
        # Input validation error
        prediction_errors_total.labels(
            model_name=MODEL_NAME,
            model_version=MODEL_VERSION,
            error_type='invalid_input'
        ).inc()
        
        prediction_requests_total.labels(
            model_name=MODEL_NAME,
            model_version=MODEL_VERSION,
            status='failure'
        ).inc()
        
        logger.error(f"Invalid input: {e}")
        raise
        
    except Exception as e:
        # Model prediction error
        prediction_errors_total.labels(
            model_name=MODEL_NAME,
            model_version=MODEL_VERSION,
            error_type='model_error'
        ).inc()
        
        prediction_requests_total.labels(
            model_name=MODEL_NAME,
            model_version=MODEL_VERSION,
            status='failure'
        ).inc()
        
        logger.error(f"Prediction failed: {e}")
        raise

# =============================================================================
# METRICS EXPOSITION - Returns Prometheus Format
# =============================================================================

def metrics():
    """Return metrics in Prometheus exposition format"""
    return generate_latest(REGISTRY)
```

#### Flask Integration (Dockerfile)

```python
# Added to Flask app initialization
from prometheus_client import CONTENT_TYPE_LATEST

@app.route("/metrics", methods=["GET"])
def metrics():
    """Prometheus metrics endpoint"""
    metrics_output = score.metrics()
    return metrics_output, 200, {"Content-Type": CONTENT_TYPE_LATEST}
```

#### Metrics Output Example

When Prometheus scrapes `http://pod-ip:5001/metrics`, it receives:

```prometheus
# HELP prediction_requests_total Total number of prediction requests
# TYPE prediction_requests_total counter
prediction_requests_total{deployment="production",model_name="diabetes_classification",model_version="1",status="success"} 1247.0
prediction_requests_total{deployment="production",model_name="diabetes_classification",model_version="1",status="failure"} 13.0

# HELP prediction_errors_total Total number of prediction errors
# TYPE prediction_errors_total counter
prediction_errors_total{deployment="production",error_type="invalid_input",model_name="diabetes_classification",model_version="1"} 8.0
prediction_errors_total{deployment="production",error_type="model_error",model_name="diabetes_classification",model_version="1"} 5.0

# HELP prediction_duration_seconds Time spent processing prediction request
# TYPE prediction_duration_seconds histogram
prediction_duration_seconds_bucket{deployment="production",le="0.005",model_name="diabetes_classification",model_version="1"} 234.0
prediction_duration_seconds_bucket{deployment="production",le="0.01",model_name="diabetes_classification",model_version="1"} 567.0
prediction_duration_seconds_bucket{deployment="production",le="0.025",model_name="diabetes_classification",model_version="1"} 1100.0
prediction_duration_seconds_bucket{deployment="production",le="0.05",model_name="diabetes_classification",model_version="1"} 1200.0
prediction_duration_seconds_bucket{deployment="production",le="+Inf",model_name="diabetes_classification",model_version="1"} 1260.0
prediction_duration_seconds_sum{deployment="production",model_name="diabetes_classification",model_version="1"} 18.456
prediction_duration_seconds_count{deployment="production",model_name="diabetes_classification",model_version="1"} 1260.0

# HELP model_info Information about the loaded model
# TYPE model_info gauge
model_info{deployment="production",model_name="diabetes_classification",model_version="1",sklearn_version="1.5.0"} 1.0
```

### Metric Types Explained

**Counter:**
- Starts at 0
- Only increases (never decreases)
- Resets to 0 on pod restart
- Use `rate()` or `increase()` to calculate change over time

**Histogram:**
- Records observations in buckets
- Generates `_bucket`, `_sum`, `_count` series
- Used with `histogram_quantile()` for percentiles
- Example: Calculate p95 latency

**Gauge:**
- Can increase or decrease
- Represents current state
- Example: Memory usage, queue depth

---

## Service Discovery

### ServiceMonitor CRD

**File:** `kubernetes/ml-inference-servicemonitor.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ml-inference-servicemonitor
  namespace: production
  labels:
    app: ml-inference
    release: prometheus  # ← CRITICAL: Matches prometheus operator selector
spec:
  selector:
    matchLabels:
      app: ml-inference  # ← Finds Service with this label
  endpoints:
  - port: http           # ← Matches Service port NAME (not number)
    path: /metrics       # ← Metrics endpoint path
    interval: 30s        # ← Scrape frequency
    scrapeTimeout: 10s   # ← Max time to wait for response
```

### How ServiceMonitor Works

#### Step 1: Prometheus Operator Discovery

```
Prometheus Operator (Pod)
  ↓
Watches Kubernetes API for:
  - ServiceMonitor objects
  - PrometheusRule objects
  - Prometheus objects
  ↓
Detects new ServiceMonitor: ml-inference-servicemonitor
```

#### Step 2: Service Lookup

```
ServiceMonitor selector: app=ml-inference
  ↓
Queries Kubernetes API:
  "Find Service with label app=ml-inference in namespace production"
  ↓
Found: Service/ml-inference
  ↓
Service selector: app=ml-inference
  ↓
Queries Kubernetes API:
  "Find Pods with label app=ml-inference"
  ↓
Found 3 Pods:
  - ml-inference-7f4564b58f-49v5m (IP: 10.0.2.16)
  - ml-inference-7f4564b58f-8xk2l (IP: 10.0.2.31)
  - ml-inference-7f4564b58f-92npl (IP: 10.0.2.48)
```

#### Step 3: Prometheus Configuration Generation

Prometheus Operator automatically generates this scrape config:

```yaml
scrape_configs:
- job_name: serviceMonitor/production/ml-inference-servicemonitor/0
  honor_labels: false
  kubernetes_sd_configs:
  - role: endpoints
    namespaces:
      names:
      - production
  
  scrape_interval: 30s
  scrape_timeout: 10s
  
  relabel_configs:
  # Keep only endpoints matching service label
  - source_labels: [__meta_kubernetes_service_label_app]
    regex: ml-inference
    action: keep
  
  # Keep only endpoints matching port name
  - source_labels: [__meta_kubernetes_endpoint_port_name]
    regex: http
    action: keep
  
  # Set metrics path
  - target_label: __metrics_path__
    replacement: /metrics
  
  # Add namespace label
  - source_labels: [__meta_kubernetes_namespace]
    target_label: namespace
  
  # Add pod name label
  - source_labels: [__meta_kubernetes_pod_name]
    target_label: pod
  
  # Add service name label
  - source_labels: [__meta_kubernetes_service_name]
    target_label: service
```

#### Step 4: Active Scraping

```
Every 30 seconds, Prometheus executes:

Scrape 1:
  HTTP GET http://10.0.2.16:5001/metrics
  Timeout: 10s
  Response: 200 OK (metrics data)
  Store: prediction_requests_total{pod="...-49v5m"} 100 @timestamp

Scrape 2:
  HTTP GET http://10.0.2.31:5001/metrics
  Timeout: 10s
  Response: 200 OK (metrics data)
  Store: prediction_requests_total{pod="...-8xk2l"} 95 @timestamp

Scrape 3:
  HTTP GET http://10.0.2.48:5001/metrics
  Timeout: 10s
  Response: 200 OK (metrics data)
  Store: prediction_requests_total{pod="...-92npl"} 103 @timestamp
```

### Troubleshooting Service Discovery

#### Check if ServiceMonitor is applied:
```bash
kubectl get servicemonitor -n production
# Should show: ml-inference-servicemonitor
```

#### Check Prometheus targets:
```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Open browser: http://localhost:9090/targets
# Look for: production/ml-inference-servicemonitor/0
# Status should be: UP (green)
```

#### Common Issues:

| Issue | Cause | Solution |
|-------|-------|----------|
| Target not appearing | ServiceMonitor label mismatch | Check `release: prometheus` label matches operator config |
| Target DOWN (red) | Metrics endpoint not responding | Check pod logs, verify `/metrics` endpoint works |
| No metrics after scrape | Empty response | Verify `score.metrics()` returns data |
| Connection refused | Wrong port | Check Service port name matches ServiceMonitor `port` field |

---

## Alert Configuration

### PrometheusRule CRD

**File:** `kubernetes/ml-inference-alerts.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ml-inference-alerts
  namespace: production
  labels:
    app: ml-inference
    prometheus: kube-prometheus  # ← Must match Prometheus ruleSelector
spec:
  groups:
  - name: ml-inference
    interval: 30s  # Evaluate rules every 30 seconds
    rules:
    
    # =========================================================================
    # ALERT 1: High Error Rate
    # =========================================================================
    - alert: HighErrorRate
      # PromQL expression that triggers alert when TRUE
      expr: |
        (
          rate(prediction_errors_total{namespace="production"}[5m])
          /
          rate(prediction_requests_total{namespace="production"}[5m])
        ) > 0.05
      
      # Alert must be TRUE for this duration before firing
      for: 5m
      
      # Labels attached to alert (used for routing)
      labels:
        severity: critical
        component: ml-inference
        team: ml-platform
      
      # Human-readable annotations
      annotations:
        summary: "High error rate detected in ML inference service"
        description: |
          Error rate is {{ $value | humanizePercentage }} over the last 5 minutes.
          This exceeds the 5% threshold.
          
          Current error rate: {{ $value | humanizePercentage }}
          Threshold: 5%
          
          Affected deployment: {{ $labels.deployment }}
          Model: {{ $labels.model_name }}:{{ $labels.model_version }}
        
        runbook_url: "https://wiki.company.com/runbooks/ml-inference-high-errors"
        dashboard_url: "http://128.203.69.59/d/ml-inference"
    
    # =========================================================================
    # ALERT 2: Slow Inference (p95 Latency)
    # =========================================================================
    - alert: SlowInference
      expr: |
        histogram_quantile(
          0.95,
          rate(prediction_duration_seconds_bucket{namespace="production"}[5m])
        ) > 2
      
      for: 5m
      
      labels:
        severity: warning
        component: ml-inference
        team: ml-platform
      
      annotations:
        summary: "ML inference latency is high"
        description: |
          95th percentile latency is {{ $value | humanizeDuration }} over the last 5 minutes.
          This exceeds the 2 second SLA.
          
          Current p95: {{ $value | humanizeDuration }}
          Threshold: 2s
          
          Possible causes:
          - Resource constraints (CPU/Memory)
          - Large batch sizes
          - Model complexity increase
        
        runbook_url: "https://wiki.company.com/runbooks/ml-inference-slow"
    
    # =========================================================================
    # ALERT 3: No Requests (Service Down?)
    # =========================================================================
    - alert: NoInferenceRequests
      expr: |
        rate(prediction_requests_total{namespace="production"}[10m]) == 0
      
      for: 10m
      
      labels:
        severity: warning
        component: ml-inference
      
      annotations:
        summary: "No inference requests received"
        description: |
          The ML inference service has not received any requests in the last 10 minutes.
          This could indicate:
          - Service discovery issue
          - Upstream service failure
          - Network connectivity problem
    
    # =========================================================================
    # ALERT 4: High Memory Usage
    # =========================================================================
    - alert: HighMemoryUsage
      expr: |
        (
          container_memory_working_set_bytes{namespace="production",pod=~"ml-inference-.*"}
          /
          container_spec_memory_limit_bytes{namespace="production",pod=~"ml-inference-.*"}
        ) > 0.9
      
      for: 5m
      
      labels:
        severity: warning
        component: ml-inference
      
      annotations:
        summary: "ML inference pod using >90% memory"
        description: |
          Pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} of its memory limit.
          Risk of OOMKilled if memory continues to grow.
```

### Alert Lifecycle

#### Phase 1: Inactive
```
Alert rule defined in PrometheusRule
  ↓
Prometheus evaluates every 30s
  ↓
Query result: FALSE
  ↓
Status: Inactive (no action)
```

#### Phase 2: Pending
```
Time: 10:00:00
  Query: rate(prediction_errors_total[5m]) / rate(prediction_requests_total[5m]) > 0.05
  Result: 0.08 (8% error rate)
  Condition: TRUE
  ↓
Alert enters "Pending" state
  ↓
Time: 10:00:30 (30s later)
  Query re-evaluated
  Result: 0.09
  Condition: TRUE
  ↓
Still Pending (for: 5m not elapsed yet)
  ↓
... continues every 30s ...
  ↓
Time: 10:05:00 (5 minutes elapsed)
  Query re-evaluated
  Result: 0.07
  Condition: TRUE
  ↓
"for: 5m" duration satisfied → Alert FIRES!
```

#### Phase 3: Firing
```
Alert status changes to "Firing"
  ↓
Prometheus sends alert to Alertmanager
  ↓
Alertmanager receives:
{
  "status": "firing",
  "labels": {
    "alertname": "HighErrorRate",
    "severity": "critical",
    "component": "ml-inference"
  },
  "annotations": {
    "summary": "High error rate detected...",
    "description": "Error rate is 7% over the last 5 minutes..."
  },
  "startsAt": "2025-11-15T10:05:00Z",
  "generatorURL": "http://prometheus:9090/graph?..."
}
  ↓
Alertmanager processes alert:
  1. Check for duplicates (deduplication)
  2. Group related alerts
  3. Apply routing rules
  4. Apply silences (if any)
  ↓
Route to receivers based on labels:
  - severity=critical → PagerDuty + Slack
  - team=ml-platform → #ml-alerts channel
  ↓
Send notifications
```

#### Phase 4: Resolved
```
Time: 10:15:00
  Query re-evaluated
  Result: 0.03 (3% error rate)
  Condition: FALSE
  ↓
Alert status changes to "Resolved"
  ↓
Prometheus sends resolution to Alertmanager
  ↓
Alertmanager sends "resolved" notification:
  - Slack: "✅ HighErrorRate resolved"
  - PagerDuty: Incident auto-resolved
```

### PromQL Query Breakdown

#### Query: Error Rate
```promql
(
  rate(prediction_errors_total{namespace="production"}[5m])
  /
  rate(prediction_requests_total{namespace="production"}[5m])
) > 0.05
```

**Step-by-step execution:**
```
1. rate(prediction_errors_total{namespace="production"}[5m])
   - Fetches prediction_errors_total for last 5 minutes
   - Calculates per-second rate of increase
   - Example: 24 errors in 300s = 0.08 errors/sec

2. rate(prediction_requests_total{namespace="production"}[5m])
   - Fetches prediction_requests_total for last 5 minutes
   - Calculates per-second rate
   - Example: 300 requests in 300s = 1.0 requests/sec

3. Division:
   0.08 / 1.0 = 0.08 (8%)

4. Comparison:
   0.08 > 0.05 → TRUE → Alert condition met
```

#### Query: p95 Latency
```promql
histogram_quantile(
  0.95,
  rate(prediction_duration_seconds_bucket{namespace="production"}[5m])
) > 2
```

**How histogram_quantile works:**
```
Input histogram buckets (from last 5 minutes):
le=0.005: 120 observations
le=0.01:  240 observations
le=0.025: 450 observations
le=0.05:  580 observations
le=0.1:   620 observations
le=0.5:   710 observations
le=1.0:   750 observations
le=2.0:   790 observations
le=5.0:   800 observations
le=+Inf:  800 observations (total)

Calculate 95th percentile:
- 95% of 800 = 760th observation
- 760th falls between le=2.0 (790 obs) and le=1.0 (750 obs)
- Linear interpolation: ~1.8 seconds

Result: 1.8 < 2.0 → FALSE → No alert
```

---

## Storage & Query Engine

### Prometheus Time-Series Database

#### Data Model

Every metric is stored as a time-series with this structure:

```
metric_name{label1="value1", label2="value2"} value timestamp
```

**Example:**
```
prediction_requests_total{
  namespace="production",
  pod="ml-inference-7f4564b58f-49v5m",
  model_name="diabetes_classification",
  model_version="1",
  status="success"
} 1247 1699934400
```

#### Storage Layout

```
/prometheus/data/
├── wal/                           # Write-Ahead Log (recent data)
│   ├── 00000001
│   ├── 00000002
│   └── checkpoint.00000001        # Periodic checkpoint
│
├── 01HJKL3M4N5P6Q7R8S9T0U1V2W/  # Block 1 (2 hours of data)
│   ├── chunks/
│   │   ├── 000001                 # Compressed time-series samples
│   │   ├── 000002
│   │   └── 000003
│   ├── index                      # Fast label lookup
│   ├── meta.json                  # Block metadata
│   └── tombstones                 # Deleted series
│
├── 01HJKL3M4N5P6Q7R8S9T0U1V3X/  # Block 2 (2 hours of data)
│   ├── chunks/
│   ├── index
│   ├── meta.json
│   └── tombstones
│
└── ...
```

#### Data Compression

Prometheus uses aggressive compression:

```
Raw data size: ~15 bytes per sample
- timestamp: 8 bytes
- value: 8 bytes (float64)
- minus overhead

Compressed: ~1.3 bytes per sample (!)
- Delta-of-delta timestamp encoding
- XOR floating point compression
- LZ4 compression on top

Example:
- 1 million samples/sec
- Raw: 15 MB/sec
- Compressed: 1.3 MB/sec
- Storage for 15 days: ~1.5 TB raw → ~130 GB compressed
```

### Query Execution

#### Example Query: `rate(prediction_requests_total[5m])`

**Step 1: Parse Query**
```
Parser → AST (Abstract Syntax Tree):
rate(
  VectorSelector{
    name: "prediction_requests_total",
    range: 5m
  }
)
```

**Step 2: Fetch Time-Series**
```
Query time: 10:30:00
Range: [10:25:00, 10:30:00]

Index lookup:
  metric_name="prediction_requests_total"
  → Found 6 time-series (3 pods × 2 statuses)

For each series, load samples from blocks/WAL:
  Series 1 (pod1, status=success):
    10:25:00 → 1000
    10:25:30 → 1005
    10:26:00 → 1010
    ...
    10:30:00 → 1050
    
  Series 2 (pod1, status=failure):
    10:25:00 → 10
    10:25:30 → 11
    ...
```

**Step 3: Apply rate() Function**
```
For each series:
  first_value = value at 10:25:00
  last_value = value at 10:30:00
  time_range = 300 seconds
  
  rate = (last_value - first_value) / time_range
  
Series 1: (1050 - 1000) / 300 = 0.167 req/sec
Series 2: (15 - 10) / 300 = 0.017 req/sec
```

**Step 4: Return Results**
```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {
          "namespace": "production",
          "pod": "ml-inference-7f4564b58f-49v5m",
          "status": "success"
        },
        "value": [1699934400, "0.167"]
      },
      {
        "metric": {
          "namespace": "production",
          "pod": "ml-inference-7f4564b58f-49v5m",
          "status": "failure"
        },
        "value": [1699934400, "0.017"]
      }
    ]
  }
}
```

---

## Visualization Layer

### Grafana Dashboard

**File:** `kubernetes/grafana-dashboard.json`

```json
{
  "dashboard": {
    "title": "ML Inference Monitoring",
    "panels": [
      {
        "id": 1,
        "title": "Request Rate",
        "type": "graph",
        "targets": [{
          "expr": "sum(rate(prediction_requests_total[5m]))",
          "legendFormat": "Total Requests/sec"
        }],
        "yaxes": [{
          "format": "reqps",
          "label": "Requests per Second"
        }]
      },
      {
        "id": 2,
        "title": "Error Rate %",
        "type": "graph",
        "targets": [{
          "expr": "sum(rate(prediction_errors_total[5m])) / sum(rate(prediction_requests_total[5m])) * 100",
          "legendFormat": "Error Rate"
        }],
        "alert": {
          "conditions": [{
            "evaluator": {
              "params": [5],
              "type": "gt"
            }
          }]
        },
        "yaxes": [{
          "format": "percent",
          "max": 100,
          "min": 0
        }]
      },
      {
        "id": 3,
        "title": "Latency Percentiles",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.50, rate(prediction_duration_seconds_bucket[5m]))",
            "legendFormat": "p50"
          },
          {
            "expr": "histogram_quantile(0.95, rate(prediction_duration_seconds_bucket[5m]))",
            "legendFormat": "p95"
          },
          {
            "expr": "histogram_quantile(0.99, rate(prediction_duration_seconds_bucket[5m]))",
            "legendFormat": "p99"
          }
        ],
        "yaxes": [{
          "format": "s",
          "label": "Duration"
        }]
      }
    ]
  }
}
```

### Query Flow: Grafana → Prometheus

```
User opens dashboard: http://128.203.69.59/d/ml-inference
  ↓
Grafana loads dashboard JSON from database
  ↓
For each panel, Grafana executes:
  1. Parse panel.targets[].expr
  2. Build Prometheus API request
  3. Send HTTP request to Prometheus
  ↓
Example request:
  GET http://prometheus-service:9090/api/v1/query_range
  ?query=sum(rate(prediction_requests_total[5m]))
  &start=1699930800
  &end=1699934400
  &step=30
  ↓
Prometheus executes query:
  - Fetch time-series
  - Apply rate() function
  - Apply sum() aggregation
  - Return results
  ↓
Grafana receives response:
{
  "data": {
    "result": [{
      "values": [
        [1699930800, "5.2"],
        [1699930830, "5.8"],
        [1699930860, "6.1"],
        ...
      ]
    }]
  }
}
  ↓
Grafana renders graph:
  - Plot values on time axis
  - Apply formatting (units, colors)
  - Add legend
  - Display to user
```

---

## Deployment Automation

### GitHub Actions Workflow

**File:** `.github/workflows/cd-deploy.yml`

```yaml
# Step 1: Always deploy ServiceMonitor and Alerts (after every deployment)
- name: Setup monitoring (ServiceMonitor and Alerts)
  run: |
    kubectl apply -f kubernetes/ml-inference-servicemonitor.yaml
    kubectl apply -f kubernetes/ml-inference-alerts.yaml
    
    # Verify
    kubectl get servicemonitor -n production -l app=ml-inference
    kubectl get prometheusrule -n production -l app=ml-inference

# Step 2: Optional full monitoring stack installation
- name: Install Prometheus + Grafana stack
  if: inputs.setup_monitoring == 'true'
  run: |
    helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --create-namespace \
      --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
      --set prometheus.prometheusSpec.retention=15d \
      --set prometheus.prometheusSpec.retentionSize=50GB \
      --set grafana.adminPassword=Admin123! \
      --set grafana.service.type=LoadBalancer \
      --wait --timeout 25m
```

### What Gets Installed

**kube-prometheus-stack Helm chart deploys:**

```
Namespace: monitoring
├── prometheus-operator (Deployment)
│   └── Pod: prometheus-operator-xxx
│       Purpose: Watches for ServiceMonitor/PrometheusRule CRDs
│       Resources: 200Mi memory, 100m CPU
│
├── prometheus (StatefulSet)
│   ├── Pod: prometheus-kube-prometheus-stack-0
│   │   Purpose: Scrapes metrics, stores data, evaluates rules
│   │   Resources: 2Gi memory, 1 CPU
│   └── PVC: prometheus-kube-prometheus-stack-db-0
│       Size: 50Gi
│       Purpose: Persistent storage for time-series data
│
├── grafana (Deployment)
│   ├── Pod: kube-prometheus-stack-grafana-xxx
│   │   Purpose: Dashboard UI, query Prometheus
│   │   Resources: 500Mi memory, 100m CPU
│   └── Service: kube-prometheus-stack-grafana (LoadBalancer)
│       External IP: 128.203.69.59
│
├── alertmanager (StatefulSet)
│   ├── Pod: alertmanager-kube-prometheus-stack-0
│   │   Purpose: Route and send alerts
│   │   Resources: 500Mi memory, 50m CPU
│   └── PVC: alertmanager-kube-prometheus-stack-db-0
│       Size: 10Gi
│
└── kube-state-metrics (Deployment)
    └── Pod: kube-prometheus-stack-kube-state-metrics-xxx
        Purpose: Expose Kubernetes object metrics
        Resources: 50Mi memory, 10m CPU
```

---

## Troubleshooting Guide

### Issue 1: Metrics Not Appearing in Prometheus

**Symptoms:**
- ServiceMonitor exists
- Pods are running
- Prometheus targets show as DOWN

**Diagnosis:**
```bash
# 1. Check if metrics endpoint works directly
kubectl port-forward -n production svc/ml-inference 5001:80
curl http://localhost:5001/metrics

# Expected: Prometheus-formatted metrics
# If empty or error → problem in application

# 2. Check ServiceMonitor configuration
kubectl describe servicemonitor ml-inference-servicemonitor -n production

# 3. Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open: http://localhost:9090/targets
# Look for: production/ml-inference-servicemonitor/0

# 4. Check Prometheus logs
kubectl logs -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus
```

**Solutions:**

| Symptom | Cause | Fix |
|---------|-------|-----|
| Target not listed | ServiceMonitor label mismatch | Add `release: prometheus` label |
| Target DOWN | Metrics endpoint not responding | Check pod logs for Flask errors |
| Empty metrics | `generate_latest()` not called | Verify `/metrics` route implementation |
| Connection refused | Wrong port | Check Service port matches `5001` |

### Issue 2: Alerts Not Firing

**Diagnosis:**
```bash
# 1. Check if PrometheusRule is loaded
kubectl get prometheusrule -n production
kubectl describe prometheusrule ml-inference-alerts -n production

# 2. Check Prometheus rules
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open: http://localhost:9090/rules
# Look for: production/ml-inference/HighErrorRate

# 3. Manually execute alert query
# In Prometheus UI, run:
rate(prediction_errors_total[5m]) / rate(prediction_requests_total[5m])

# 4. Check alert status
# In Prometheus UI: Alerts tab
# Status: Inactive | Pending | Firing
```

**Common Issues:**

1. **Query returns no data**
   - Check if metrics exist: `prediction_errors_total`
   - Verify label selectors match

2. **Query returns value but alert not firing**
   - Check `for: 5m` duration not elapsed
   - Check alert is in "Pending" state

3. **Alert firing but no notification**
   - Check Alertmanager config
   - Verify receiver configuration

### Issue 3: Grafana Dashboard Shows No Data

**Diagnosis:**
```bash
# 1. Check Grafana can reach Prometheus
kubectl logs -n monitoring deployment/kube-prometheus-stack-grafana

# 2. Test Prometheus query manually
curl -G http://prometheus-service:9090/api/v1/query \
  --data-urlencode 'query=sum(rate(prediction_requests_total[5m]))'

# 3. Check dashboard datasource configuration
# In Grafana: Configuration → Data Sources → Prometheus
# URL should be: http://kube-prometheus-stack-prometheus:9090
```

---

## Production Best Practices

### 1. Metric Naming Conventions

**Follow Prometheus naming best practices:**

```python
# ✅ GOOD
prediction_requests_total       # Clear, follows _total convention for counters
prediction_duration_seconds     # Clear unit (seconds)
model_info                      # Descriptive

# ❌ BAD
requests                        # Too generic
prediction_time                 # Unclear unit
ml_model                        # Vague purpose
```

### 2. Label Cardinality

**Keep label cardinality low:**

```python
# ❌ BAD - Unbounded cardinality
prediction_requests_total{
    user_id="user_12345",           # Millions of unique values!
    request_id="req_abc123",        # Every request is unique!
    timestamp="2025-11-15T10:30:00" # Infinite values!
}

# ✅ GOOD - Bounded cardinality
prediction_requests_total{
    model_name="diabetes_classification",  # Fixed set of models
    model_version="1",                     # Limited versions
    status="success"                       # Only 2 values: success/failure
}
```

**Why?** Each unique label combination creates a new time-series. High cardinality → millions of series → memory explosion.

### 3. Scrape Intervals

**Balance granularity vs load:**

```yaml
# Development/Testing
interval: 15s  # High granularity, OK for small scale

# Production (default)
interval: 30s  # Good balance

# High-scale production
interval: 60s  # Reduce load, still acceptable for most use cases
```

### 4. Retention Policy

```yaml
prometheus:
  prometheusSpec:
    retention: 15d           # Keep 15 days of data
    retentionSize: 50GB      # OR until 50GB used (whichever comes first)
```

**Retention strategy:**
- Short-term: Prometheus (15 days)
- Long-term: Archive to object storage (S3, GCS) with Thanos or Cortex

### 5. Alert Fatigue Prevention

```yaml
# Use appropriate "for" durations
for: 5m   # Don't alert on transient spikes

# Use severity levels
severity: critical   # Pages on-call engineer
severity: warning    # Logs to Slack, no page
severity: info       # Dashboard only

# Group related alerts
group_by: ['alertname', 'namespace']
group_wait: 30s
group_interval: 5m
```

### 6. Resource Limits

```yaml
# Prometheus pod
resources:
  requests:
    memory: 2Gi
    cpu: 1000m
  limits:
    memory: 4Gi
    cpu: 2000m

# Grafana pod
resources:
  requests:
    memory: 500Mi
    cpu: 100m
  limits:
    memory: 1Gi
    cpu: 500m
```

---

## Complete Monitoring Flow Summary

```
┌─────────────────────────────────────────────────────────────────────┐
│                    1. USER MAKES PREDICTION REQUEST                  │
│                    POST /score {"data": [[...]]}                     │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 2. FLASK APP PROCESSES REQUEST                       │
│                 - Calls score.run()                                  │
│                 - Increments metrics in memory:                      │
│                   prediction_requests_total.inc()                    │
│                   prediction_duration_seconds.observe()              │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 3. METRICS STORED IN-MEMORY                          │
│                 - Counter values updated                             │
│                 - Histogram buckets incremented                      │
│                 - Waiting for Prometheus to scrape                   │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼ (Every 30 seconds)
┌─────────────────────────────────────────────────────────────────────┐
│                 4. PROMETHEUS SCRAPES /metrics                       │
│                 - ServiceMonitor defines targets                     │
│                 - HTTP GET http://pod-ip:5001/metrics                │
│                 - Receives Prometheus-formatted text                 │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 5. PROMETHEUS STORES TIME-SERIES                     │
│                 - Parsed metrics saved to TSDB                       │
│                 - Compressed and indexed                             │
│                 - Available for querying                             │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼ (Every 30 seconds)
┌─────────────────────────────────────────────────────────────────────┐
│                 6. PROMETHEUS EVALUATES ALERTS                       │
│                 - PrometheusRule defines conditions                  │
│                 - Execute PromQL queries                             │
│                 - Check if thresholds exceeded                       │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 ▼ (If alert fires)
┌─────────────────────────────────────────────────────────────────────┐
│                 7. ALERTMANAGER ROUTES NOTIFICATION                  │
│                 - Receives alert from Prometheus                     │
│                 - Applies routing rules                              │
│                 - Sends to Slack/PagerDuty/Email                     │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼ (On demand)
┌─────────────────────────────────────────────────────────────────────┐
│                 8. GRAFANA DISPLAYS DASHBOARD                        │
│                 - User opens http://128.203.69.59                    │
│                 - Grafana queries Prometheus API                     │
│                 - Renders graphs and visualizations                  │
│                 - Auto-refreshes every 30 seconds                    │
└─────────────────────────────────────────────────────────────────────┘
```

**Timeline Example:**
```
00:00:00 - User makes prediction
00:00:00.023 - Metrics incremented
00:00:30 - Prometheus scrapes (metrics stored)
00:00:30 - Alert evaluated (no threshold exceeded)
00:01:00 - Prometheus scrapes again
...
00:05:00 - Alert evaluated (error rate 8% > 5% threshold)
00:05:00 - Alert enters "Pending" state
...
00:10:00 - Alert fires (pending for 5 minutes)
00:10:01 - Alertmanager sends Slack notification
00:10:05 - Engineer opens Grafana dashboard
00:10:10 - Engineer investigates, identifies issue
00:15:00 - Fix deployed, error rate drops to 2%
00:20:00 - Alert automatically resolves
```

---

## Quick Reference

### Essential Commands

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n production

# Check PrometheusRule
kubectl get prometheusrule -n production

# Port-forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Port-forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Test metrics endpoint
kubectl port-forward -n production svc/ml-inference 5001:80
curl http://localhost:5001/metrics

# Check Prometheus targets
# Open: http://localhost:9090/targets

# Check alert rules
# Open: http://localhost:9090/rules

# Check active alerts
# Open: http://localhost:9090/alerts
```

### Key URLs

- **Grafana Dashboard:** http://128.203.69.59 (admin / Admin123!)
- **Prometheus UI:** Port-forward required (port 9090)
- **Alertmanager UI:** Port-forward required (port 9093)
- **ML Inference Metrics:** http://<ml-service-ip>:5001/metrics

---

**Document End** | For questions or issues, refer to troubleshooting guide or team documentation.
