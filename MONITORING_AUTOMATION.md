# Monitoring Stack Automation

## Overview

The monitoring stack deployment is now integrated into the main CD workflow (`cd-deploy.yml`) with optional flags. No manual workflow invocation required!

## ✨ What's New

### Workflow Inputs

Two new optional inputs added to `cd-deploy.yml`:

```yaml
setup_monitoring: 
  description: 'Setup Prometheus + Grafana monitoring stack? (first-time only)'
  default: 'false'
  options: ['false', 'true']

setup_ingress:
  description: 'Setup NGINX Ingress for dashboard access? (first-time only)'
  default: 'false'
  options: ['false', 'true']
```

### Automated Components

#### 🔄 Always Deployed (Every Run)
- **ServiceMonitor**: Prometheus metrics scraping configuration
- **PrometheusRule**: Alert rules (High error rate, Slow inference)
- Automatic application during AKS deployment

#### 🎯 Optional Deployment (First-Time Setup)
- **Prometheus Operator + Server**: Metrics collection and storage
- **Grafana**: Dashboard visualization (admin / Admin123!)
- **cert-manager**: SSL certificate management
- **NGINX Ingress Controller**: Dashboard exposure
- **OAuth2 Proxy**: Azure AD authentication

## 🚀 Usage

### Standard Deployment (No Monitoring Setup)

```bash
# Deploy model to staging and production
gh workflow run cd-deploy.yml \
  -f model_name=diabetes_classification \
  -f model_version=latest
```

**What happens:**
- ✅ Model deploys to staging (Azure ML)
- ✅ Approval gate blocks production
- ✅ After approval, deploys to production AKS
- ✅ ServiceMonitor and Alerts automatically applied
- ⏭️  No monitoring stack installation

### First-Time with Full Monitoring Stack

```bash
# Deploy model + install monitoring stack
gh workflow run cd-deploy.yml \
  -f model_name=diabetes_classification \
  -f model_version=latest \
  -f setup_monitoring=true
```

**What happens:**
- ✅ Standard deployment flow
- ✅ After approval, installs Prometheus + Grafana
- ✅ Configures automatic metric scraping
- ✅ Sets up alert rules
- 📊 Grafana accessible via LoadBalancer IP

**Time:** ~15-20 minutes (monitoring installation adds ~5 minutes)

### First-Time with Monitoring + Ingress

```bash
# Full production setup with secure dashboard access
gh workflow run cd-deploy.yml \
  -f model_name=diabetes_classification \
  -f model_version=latest \
  -f setup_monitoring=true \
  -f setup_ingress=true
```

**What happens:**
- ✅ Everything from above
- ✅ Installs NGINX Ingress Controller
- ✅ Configures OAuth2 Proxy (if Azure AD secrets configured)
- ✅ Applies ingress rules for Grafana and Prometheus
- 🌐 Dashboards accessible via custom domains

**Time:** ~20-25 minutes (ingress adds ~5 minutes)

## 📊 Accessing Dashboards

### Option 1: LoadBalancer IP (Simple)

After deployment with `setup_monitoring=true`:

```bash
# Get Grafana URL
kubectl get svc -n monitoring kube-prometheus-stack-grafana

# Access: http://<EXTERNAL-IP>
# Login: admin / Admin123!
```

### Option 2: NGINX Ingress (Production)

After deployment with `setup_ingress=true`:

1. **Get Ingress IP:**
   ```bash
   kubectl get svc -n ingress-nginx ingress-nginx-controller
   ```

2. **Configure DNS:**
   ```
   grafana.yourdomain.com → <INGRESS-IP>
   prometheus.yourdomain.com → <INGRESS-IP>
   ```

3. **Update domains in ingress files:**
   - `kubernetes/ingress/grafana-ingress.yaml`
   - `kubernetes/ingress/prometheus-ingress.yaml`

4. **Configure Azure AD (Optional):**
   - Create Azure AD app registration
   - Add GitHub Secrets: `AZURE_AD_CLIENT_ID`, `AZURE_AD_CLIENT_SECRET`
   - See `DASHBOARD_EXPOSURE_GUIDE.md` for details

### Option 3: Port-Forward (Development)

```bash
# Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Access: http://localhost:3000 (Grafana), http://localhost:9090 (Prometheus)
```

## 📈 Importing Grafana Dashboard

1. Access Grafana (using any method above)
2. Navigate to **Dashboards** → **Import**
3. Upload `kubernetes/grafana-dashboard.json`
4. Select **Prometheus** as the data source
5. Click **Import**

**Dashboard includes:**
- Request rate (req/sec)
- Error rate (%)
- Latency percentiles (p50, p95, p99)
- Active pods
- Request duration histogram

## 🔍 Metrics Available

All metrics exposed on port 5001 `/metrics` endpoint:

```prometheus
# Total prediction requests
prediction_requests_total{model_name, model_version, status}

# Total prediction errors
prediction_errors_total{model_name, model_version, error_type}

# Prediction duration histogram
prediction_duration_seconds{model_name, model_version}

# Model information
model_info{model_name, model_version, deployment}
```

## 🚨 Alerts Configured

### HighErrorRate
- **Condition:** Error rate > 5% for 5 minutes
- **Severity:** Critical
- **Action:** Investigate logs, check model quality

### SlowInference
- **Condition:** p95 latency > 2 seconds for 5 minutes
- **Severity:** Warning
- **Action:** Check resource utilization, scale pods

## 🔧 Manual Workflows (Still Available)

If you prefer separate workflow runs for more control:

```bash
# Just monitoring stack
gh workflow run setup-monitoring.yml \
  -f aks_cluster_name=mlopsnew-dev-aks \
  -f grafana_password=Admin123!

# Just ingress setup
gh workflow run setup-ingress.yml \
  -f grafana_domain=grafana.yourdomain.com \
  -f prometheus_domain=prometheus.yourdomain.com
```

## 📁 Architecture

```
cd-deploy.yml (Main Workflow)
├── resolve-inputs
├── deploy-staging (Azure ML)
├── await-production-approval ⏸️
├── ┬ setup-monitoring-stack (Optional) 📊
│   ├── Install Helm repos
│   ├── Install cert-manager
│   ├── Install kube-prometheus-stack
│   ├── Apply ServiceMonitor + Alerts
│   └── Display access URLs
├── ┬ setup-ingress-dashboards (Optional) 🌐
│   ├── Install NGINX Ingress
│   ├── Deploy OAuth2 Proxy
│   ├── Apply ingress rules
│   └── Display DNS configuration
└── deploy-production-aks
    ├── Build Docker image
    ├── Push to ACR
    ├── Deploy to AKS
    ├── Apply ServiceMonitor + Alerts (Always) ✅
    └── Run smoke tests
```

## 🎯 Best Practices

### First Deployment
Run with `setup_monitoring=true` to install the full stack:
```bash
gh workflow run cd-deploy.yml \
  -f model_name=diabetes_classification \
  -f model_version=latest \
  -f setup_monitoring=true
```

### Subsequent Deployments
Use default flags (no monitoring installation):
```bash
gh workflow run cd-deploy.yml \
  -f model_name=diabetes_classification \
  -f model_version=2
```
ServiceMonitor and Alerts are always kept up-to-date automatically.

### Production Hardening
Add `setup_ingress=true` on first deployment and configure:
- Azure AD authentication
- Custom domain names
- SSL certificates via cert-manager
- IP whitelisting (optional)

## 🐛 Troubleshooting

### Monitoring stack not installed?
```bash
# Check if Prometheus Operator is running
kubectl get pods -n monitoring

# Expected:
# - alertmanager-*
# - prometheus-operator-*
# - prometheus-prometheus-*
# - grafana-*
```

### ServiceMonitor not working?
```bash
# Check ServiceMonitor exists
kubectl get servicemonitor -n production

# Check Prometheus targets
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Open: http://localhost:9090/targets
# Look for: production/ml-inference-servicemonitor
```

### Metrics not appearing?
```bash
# Check metrics endpoint
kubectl port-forward -n production svc/ml-inference-svc 5001:5001
curl http://localhost:5001/metrics

# Should see:
# prediction_requests_total
# prediction_errors_total
# prediction_duration_seconds_*
```

### Grafana LoadBalancer pending?
```bash
# Check service status
kubectl get svc -n monitoring kube-prometheus-stack-grafana

# If external IP is pending for >5 minutes:
# Option 1: Use port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Option 2: Change to NodePort
kubectl patch svc kube-prometheus-stack-grafana -n monitoring -p '{"spec":{"type":"NodePort"}}'
```

## 📚 Related Documentation

- **MONITORING_SETUP.md** - Detailed setup instructions
- **MONITORING_GUIDE.md** - Comprehensive monitoring guide
- **DASHBOARD_EXPOSURE_GUIDE.md** - Production dashboard exposure patterns
- **DASHBOARD_QUICK_REF.md** - Quick reference commands
- **deployment/verify-alignment.ps1** - Infrastructure verification script

## 💡 Key Benefits

✅ **No manual commands** - Everything via workflow inputs
✅ **Idempotent** - Safe to run multiple times
✅ **Progressive enhancement** - Start simple, add complexity
✅ **Production-ready** - Includes auth, SSL, alerts
✅ **Cost-efficient** - Only install once, reuse forever
✅ **Version controlled** - All config in Git

## 🎉 Summary

The monitoring stack is now seamlessly integrated into your deployment pipeline. Simply set `setup_monitoring=true` on your first deployment, and you'll have enterprise-grade observability with minimal effort. Subsequent deployments automatically keep your monitoring configuration up-to-date without reinstalling the stack.

**Happy Monitoring! 📊✨**
