# Monitoring Setup Guide

This guide explains how to set up and use monitoring for your ML inference endpoints.

## Quick Start

### Option 1: Automated Setup (Recommended)

The monitoring manifests (ServiceMonitor and Alert Rules) are **automatically applied** during every production deployment via the `cd-deploy.yml` workflow.

When you deploy to production AKS, the workflow will:
1. Deploy your ML inference service
2. Apply ServiceMonitor for Prometheus scraping
3. Apply Alert Rules for automated alerting

**No manual action needed!**

### Option 2: One-Time Prometheus + Grafana Setup

To install the full monitoring stack (Prometheus + Grafana), run the GitHub Actions workflow:

**Via GitHub UI:**
1. Go to: **Actions** → **Setup Monitoring Stack**
2. Click **Run workflow**
3. Use default values or specify custom AKS cluster
4. Wait ~5 minutes for installation

**Via GitHub CLI:**
```bash
gh workflow run setup-monitoring.yml
```

### Option 3: Manual Setup (Local)

If you prefer to set up locally:

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group mlopsnew-dev-rg \
  --name mlopsnew-dev-aks

# Run setup script
bash scripts/setup-monitoring.sh
```

---

## What Gets Deployed

### Automatically (Every Deployment)
✅ **ServiceMonitor** (`kubernetes/ml-inference-servicemonitor.yaml`)
- Configures Prometheus to scrape `/metrics` endpoint
- Collects application metrics every 30 seconds

✅ **Alert Rules** (`kubernetes/ml-inference-alerts.yaml`)
- High Error Rate alert (>5% errors for 5 minutes)
- High Latency alert (P95 > 2s for 5 minutes)
- Pod crash/restart alerts
- Resource usage alerts (CPU/Memory > 85%)

### One-Time Setup (Manual)
📊 **Prometheus Operator**
- Metrics collection and storage
- Query engine for metrics
- Alert evaluation

📈 **Grafana**
- Visualization dashboards
- Real-time charts and graphs
- Customizable panels

🔔 **AlertManager**
- Alert routing and notification
- Grouping and deduplication
- Integration with email/Slack/Teams

---

## Accessing Monitoring Tools

### Azure Monitor (Already Enabled)

Your AKS cluster already has Azure Monitor enabled.

**Access via Azure Portal:**
1. Go to: Azure Portal → AKS Cluster → Insights
2. View: Cluster metrics, container logs, pod status

**Query Logs:**
```bash
# View in Azure Portal → Log Analytics Workspace
az monitor log-analytics workspace show \
  --resource-group mlopsnew-dev-rg \
  --workspace-name mlopsnew-dev-law
```

### Grafana (After Setup)

```bash
# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access: http://localhost:3000
# Username: admin
# Password: (shown in workflow output)
```

**Import Dashboard:**
1. Go to: Dashboards → Import
2. Upload: `kubernetes/grafana-dashboard.json`
3. Select Prometheus data source

### Prometheus (After Setup)

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Access: http://localhost:9090
```

**Example Queries:**
```promql
# Request rate
rate(model_predictions_total[5m])

# Latency percentiles
histogram_quantile(0.95, rate(model_prediction_duration_seconds_bucket[5m]))

# Error rate
rate(model_errors_total[5m]) / rate(model_predictions_total[5m]) * 100

# Pod CPU usage
rate(container_cpu_usage_seconds_total{namespace="production",pod=~"ml-inference.*"}[5m])
```

### AlertManager (After Setup)

```bash
# Port-forward AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093

# Access: http://localhost:9093
```

---

## Available Metrics

Your ML inference service exposes these custom metrics at `http://ml-inference-svc:5001/metrics`:

| Metric | Type | Description |
|--------|------|-------------|
| `model_predictions_total` | Counter | Total predictions by model, version, status |
| `model_prediction_duration_seconds` | Histogram | Prediction latency distribution |
| `model_errors_total` | Counter | Total errors by model, version, error type |
| `model_info` | Gauge | Model metadata (name, version, deployment) |
| `model_batch_size` | Histogram | Input batch size distribution |

**Plus standard Kubernetes metrics:**
- Container CPU/Memory usage
- Pod restarts and status
- Network I/O
- Disk usage

---

## Alert Rules

Alerts are automatically configured for:

### Performance Alerts
- ⚠️ **HighErrorRate**: Error rate > 5% for 5 minutes
- ⚠️ **HighPredictionLatency**: P95 latency > 2 seconds
- 🔴 **VeryHighPredictionLatency**: P95 latency > 5 seconds
- ⚠️ **LowThroughput**: < 0.1 requests/second for 10 minutes

### Availability Alerts
- 🔴 **PodCrashLooping**: Pod restarting frequently
- ⚠️ **PodNotReady**: Pod not in Running state
- ⚠️ **HighMemoryUsage**: Memory > 85% of limit
- ⚠️ **HighCPUUsage**: CPU > 85% of limit

---

## Verification

### Check if Monitoring is Set Up

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n production -l app=ml-inference

# Check Alert Rules
kubectl get prometheusrule -n production -l app=ml-inference

# Check if Prometheus is installed
helm list -n monitoring

# Check metrics endpoint directly
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://ml-inference.production.svc.cluster.local:5001/metrics
```

### Test Metrics Collection

```bash
# Generate some requests to create metrics
curl -X POST http://<EXTERNAL_IP>/score \
  -H "Content-Type: application/json" \
  -d '{"input_data": [[1,78,41,33,311,50.79,0.42,24,0]]}'

# Check metrics in Prometheus (after port-forward)
# Query: model_predictions_total
```

---

## Customization

### Add Custom Metrics

Edit `src/score.py` to add new metrics:

```python
from prometheus_client import Counter, Histogram, Gauge

# Define custom metric
MY_CUSTOM_METRIC = Counter('my_custom_metric', 'Description', ['label1', 'label2'])

# Update metric in run() function
MY_CUSTOM_METRIC.labels(label1='value', label2='value').inc()
```

### Modify Alert Thresholds

Edit `kubernetes/ml-inference-alerts.yaml`:

```yaml
- alert: HighErrorRate
  expr: |
    rate(model_errors_total[5m]) / rate(model_predictions_total[5m]) > 0.05  # Change threshold here
  for: 5m  # Change duration here
```

Apply changes:
```bash
kubectl apply -f kubernetes/ml-inference-alerts.yaml
```

### Add Grafana Dashboard Panels

1. Access Grafana UI
2. Go to: Dashboard → Edit
3. Add Panel with PromQL query
4. Export JSON: Dashboard Settings → JSON Model
5. Save to `kubernetes/grafana-dashboard.json`

---

## Troubleshooting

### ServiceMonitor Not Working

**Problem:** Metrics not appearing in Prometheus

**Check:**
```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -n production

# Check if Prometheus Operator is installed
kubectl get pods -n monitoring | grep prometheus-operator
```

**Solution:** Run the setup workflow to install Prometheus Operator

### Metrics Endpoint Not Accessible

**Problem:** Cannot access `/metrics` endpoint

**Check:**
```bash
# Test from within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://ml-inference.production.svc.cluster.local:5001/metrics

# Check pod logs
kubectl logs -n production -l app=ml-inference --tail=50
```

**Solution:** Redeploy with updated code that includes metrics endpoint

### Grafana Shows "No Data"

**Problem:** Dashboard shows no data points

**Check:**
1. Verify Prometheus is scraping targets: Prometheus UI → Status → Targets
2. Check if metrics exist: Prometheus UI → Graph → Execute query
3. Verify time range in Grafana dashboard

**Solution:** Wait a few minutes for metrics to accumulate, or adjust time range

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                  Monitoring Architecture                 │
└─────────────────────────────────────────────────────────┘

  Production AKS Cluster
  ┌──────────────────────────────────────┐
  │                                      │
  │  ml-inference Pods                   │
  │  ├─ /score endpoint                  │
  │  ├─ /health endpoint                 │
  │  └─ /metrics endpoint ◄──────────┐   │
  │                                   │   │
  └──────────────────────────────────│───┘
                                     │
                 ┌───────────────────┘
                 │
  Monitoring Namespace
  ┌──────────────▼───────────────────────┐
  │                                      │
  │  Prometheus                          │
  │  ├─ ServiceMonitor (scrapes metrics)│
  │  ├─ PrometheusRule (evaluates alerts)│
  │  └─ TSDB (stores metrics)            │
  │            │                         │
  │            ├──► Grafana (visualize)  │
  │            └──► AlertManager (notify)│
  │                                      │
  └──────────────────────────────────────┘

  Azure Monitor
  ┌──────────────────────────────────────┐
  │                                      │
  │  Container Insights                  │
  │  ├─ Pod metrics (CPU/Memory)         │
  │  ├─ Container logs                   │
  │  └─ Kubernetes events                │
  │            │                         │
  │            └──► Log Analytics        │
  │                                      │
  └──────────────────────────────────────┘
```

---

## Cost Optimization

### Azure Monitor
- **Current**: Enabled (already paying for Log Analytics retention)
- **Cost**: ~$2-5/GB ingested
- **Optimization**: Reduce retention from 30 days to 7 days if needed

### Prometheus + Grafana
- **Current**: Self-hosted on AKS (no additional cost except compute)
- **Storage**: 20GB volume (~$3/month)
- **Compute**: Minimal (runs on existing AKS nodes)
- **Optimization**: Reduce retention from 7 days to 2 days

**Recommendation:** Keep both for comprehensive monitoring
- Azure Monitor: Infrastructure + compliance
- Prometheus/Grafana: Application metrics + custom dashboards

---

## Next Steps

1. ✅ Deploy your ML model (monitoring applied automatically)
2. Run setup workflow to install Prometheus + Grafana (one-time)
3. Access Grafana and import the dashboard
4. Configure AlertManager for notifications (Slack/email)
5. Create custom dashboards for your specific needs

**Questions?** See: `documentation/MONITORING_GUIDE.md` for detailed information
