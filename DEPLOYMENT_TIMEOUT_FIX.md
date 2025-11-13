# Deployment Timeout Troubleshooting

## Issues Fixed

### 1. AKS Rollout Timeout (Error: timed out waiting for condition)

**Problem:**
```
Waiting for deployment "ml-inference" rollout to finish: 1 out of 2 new replicas have been updated...
error: timed out waiting for the condition
```

**Root Causes:**
- 2 replicas trying to start simultaneously on resource-constrained cluster
- High resource requests (500m CPU, 1Gi RAM per pod)
- 10-minute timeout insufficient for image pull + pod startup

**Fixes Applied:**
✅ Reduced replicas: `2 → 1` (HPA will scale if needed)
✅ Reduced resources: `250m CPU, 512Mi RAM` (faster scheduling)
✅ Increased timeout: `10m → 15m`
✅ Added rolling update strategy: `maxSurge=1, maxUnavailable=0`
✅ Added detailed error output with pod status and events

### 2. Monitoring Stack Installation Timeout

**Problem:**
```
📊 Installing kube-prometheus-stack...
namespace/monitoring created
Error: INSTALLATION FAILED: context deadline exceeded
```

**Root Causes:**
- Helm chart installs 20+ components (Prometheus, Grafana, Alertmanager, Operators)
- Default resource requirements too high for development clusters
- 10-minute timeout insufficient for all pods to become ready

**Fixes Applied:**
✅ Increased timeout: `10m → 20m`
✅ Reduced Prometheus memory: `200Mi request, 1Gi limit`
✅ Reduced Grafana memory: `100Mi request, 500Mi limit`
✅ Reduced Alertmanager memory: `100Mi request, 500Mi limit`
✅ Added retry logic for Prometheus Operator readiness (10 attempts × 60s)
✅ Better progress visibility with pod status checks

## Quick Reference

### Check Deployment Status

```bash
# Check pod status
kubectl get pods -n production -l app=ml-inference

# Check pod details
kubectl describe pod <pod-name> -n production

# Check pod logs
kubectl logs <pod-name> -n production

# Check events
kubectl get events -n production --sort-by='.lastTimestamp'
```

### Check Monitoring Stack

```bash
# Check monitoring namespace pods
kubectl get pods -n monitoring

# Expected pods:
# - alertmanager-*
# - prometheus-operator-*
# - prometheus-prometheus-*
# - kube-prometheus-stack-grafana-*
# - kube-state-metrics-*
# - node-exporter-* (DaemonSet)

# Check if pods are pending
kubectl get pods -n monitoring | grep Pending

# Check resource usage
kubectl top pods -n monitoring
kubectl top nodes
```

### Force Restart Deployment

```bash
# If deployment is stuck
kubectl rollout restart deployment/ml-inference -n production

# Watch rollout progress
kubectl rollout status deployment/ml-inference -n production --timeout=15m
```

### Manually Scale Down/Up

```bash
# Scale to 0 (stops all pods)
kubectl scale deployment/ml-inference -n production --replicas=0

# Wait for pods to terminate
kubectl get pods -n production -w

# Scale back to 1
kubectl scale deployment/ml-inference -n production --replicas=1
```

### Clean Slate Approach

If deployment is completely stuck:

```bash
# Delete deployment
kubectl delete deployment ml-inference -n production

# Delete service
kubectl delete service ml-inference -n production

# Verify cleanup
kubectl get all -n production

# Re-run workflow
gh workflow run cd-deploy.yml \
  -f model_name=diabetes_classification \
  -f model_version=latest
```

## Resource Requirements

### Minimum Cluster Size

For successful deployment with monitoring:

| Component | CPU Request | Memory Request | Replicas |
|-----------|-------------|----------------|----------|
| ML Inference | 250m | 512Mi | 1 |
| Prometheus | 200m | 200Mi | 1 |
| Grafana | 100m | 100Mi | 1 |
| Alertmanager | 100m | 100Mi | 1 |
| Prometheus Operator | 100m | 100Mi | 1 |
| **Total** | **~1 CPU** | **~1.5Gi RAM** | **5 pods** |

**Recommended:**
- **Node Type:** Standard_DS2_v2 (2 vCPUs, 7GB RAM) or better
- **Node Count:** 2+ for high availability
- **System Pods:** Reserve ~500m CPU, ~500Mi RAM

### Check Cluster Capacity

```bash
# Check node resources
kubectl describe nodes

# Check allocatable resources
kubectl get nodes -o json | jq '.items[] | {name: .metadata.name, cpu: .status.allocatable.cpu, memory: .status.allocatable.memory}'

# Check pod resource usage
kubectl top nodes
kubectl top pods -A
```

## Workflow Changes

### Before (Issues)

```yaml
# Rollout timeout: 10m (insufficient)
kubectl rollout status --timeout=10m

# Monitoring timeout: 10m (insufficient)
helm install --wait --timeout 10m

# High resources: 500m CPU, 1Gi RAM
# Multiple replicas: 2 (doubled resource needs)
```

### After (Fixed)

```yaml
# Rollout timeout: 15m (with error handling)
if kubectl rollout status --timeout=15m; then
  echo "✅ Success"
else
  kubectl get pods
  kubectl get events
  exit 1
fi

# Monitoring timeout: 20m (with retries)
helm install --wait --timeout 20m \
  --set prometheus.resources.requests.memory=200Mi \
  --set grafana.resources.requests.memory=100Mi

# Lower resources: 250m CPU, 512Mi RAM
# Single replica: 1 (HPA can scale)
# Rolling update strategy: maxSurge=1, maxUnavailable=0
```

## Monitoring Optional

Remember: Monitoring stack installation is **optional**!

### Minimal Deployment (No Monitoring)
```bash
gh workflow run cd-deploy.yml \
  -f model_name=diabetes_classification \
  -f model_version=latest
```
- ⚡ Faster (no monitoring installation)
- 🎯 Focus on ML model deployment
- 📊 ServiceMonitor still applied (ready for future monitoring)

### With Monitoring (First-Time)
```bash
gh workflow run cd-deploy.yml \
  -f model_name=diabetes_classification \
  -f model_version=latest \
  -f setup_monitoring=true
```
- ⏱️ Takes 20-25 minutes total
- 📊 Full observability stack
- 🚀 One-time setup

## Common Errors

### Error: ImagePullBackOff

```bash
# Check image exists in ACR
az acr repository show-tags \
  --name mlopsnewdevacr \
  --repository ml-inference

# Check if AKS has ACR access
az aks check-acr \
  --name mlopsnew-dev-aks \
  --resource-group mlopsnew-dev-rg \
  --acr mlopsnewdevacr.azurecr.io
```

### Error: CrashLoopBackOff

```bash
# Check logs for Python errors
kubectl logs <pod-name> -n production

# Common issues:
# - Model file not found (AZUREML_MODEL_FILE path wrong)
# - Missing dependencies (check Dockerfile)
# - Port 5001 already in use
# - Insufficient memory
```

### Error: OOMKilled (Out of Memory)

```bash
# Pod killed due to memory limit
kubectl describe pod <pod-name> -n production

# Solution: Increase memory limit
# Edit kubernetes/ml-inference-deployment.yaml:
# memory: "2Gi" → "4Gi"
```

### Error: Pod Pending (Insufficient CPU/Memory)

```bash
# Check events
kubectl describe pod <pod-name> -n production

# Solution 1: Reduce resource requests
# Solution 2: Add more nodes to cluster
# Solution 3: Delete unused pods
```

## Validation

After deployment, verify everything works:

```bash
# 1. Check deployment status
kubectl get deployments -n production

# 2. Check pod health
kubectl get pods -n production

# 3. Test health endpoints
kubectl port-forward -n production svc/ml-inference-svc 5001:5001

# In another terminal:
curl http://localhost:5001/liveness   # Should return {"status": "healthy"}
curl http://localhost:5001/readiness  # Should return {"status": "ready"}

# 4. Test prediction
curl -X POST http://localhost:5001/score \
  -H "Content-Type: application/json" \
  -d '{"data": [[1,78,41,33,311,50.79,0.42,24,0]]}'

# 5. Check metrics
curl http://localhost:5001/metrics | grep prediction
```

## Performance Tips

### 1. Pre-pull Images

Speed up deployments by pre-pulling images:

```bash
# On each node (via DaemonSet or manual)
docker pull mlopsnewdevacr.azurecr.io/ml-inference:latest
```

### 2. Use Node Affinity

Pin ML workloads to specific nodes:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: workload
          operator: In
          values:
          - ml-inference
```

### 3. Use Priority Classes

Ensure ML pods get scheduled before non-critical workloads:

```yaml
priorityClassName: high-priority
```

### 4. Use Startup Probe

For slow-starting ML models:

```yaml
startupProbe:
  httpGet:
    path: /liveness
    port: 5001
  initialDelaySeconds: 0
  periodSeconds: 10
  failureThreshold: 30  # 5 minutes total
```

## Summary

✅ **Fixed:** AKS rollout timeout (10m → 15m)
✅ **Fixed:** Monitoring installation timeout (10m → 20m)
✅ **Fixed:** Resource constraints (reduced requests)
✅ **Fixed:** Replica count (2 → 1)
✅ **Added:** Better error messages and debugging info
✅ **Added:** Retry logic for operator readiness

Your deployments should now complete successfully! 🚀
