# ML Inference Best Practices Implementation Guide

This document explains the inference optimizations implemented in this MLOps platform and how to use them effectively.

## Table of Contents
1. [Overview](#overview)
2. [Horizontal Pod Autoscaling (HPA)](#horizontal-pod-autoscaling-hpa)
3. [API Management & Rate Limiting](#api-management--rate-limiting)
4. [Response Caching with Redis](#response-caching-with-redis)
5. [Health Checks & Probes](#health-checks--probes)
6. [Model Versioning & Metrics](#model-versioning--metrics)
7. [SLO Monitoring](#slo-monitoring)
8. [Input Validation](#input-validation)
9. [Deployment Checklist](#deployment-checklist)

---

## Overview

This implementation follows industry best practices for production ML inference:

- **Autoscaling**: Kubernetes HPA scales pods based on CPU/memory
- **Rate Limiting**: API Management enforces quotas and throttling
- **Caching**: Redis reduces latency for repeated predictions
- **Observability**: Comprehensive metrics, logs, and SLO tracking
- **Resilience**: Health probes, input validation, error handling

**Target SLOs:**
- P95 latency < 200ms
- P99 latency < 500ms
- Error rate < 1%
- Availability > 99.9%

---

## Horizontal Pod Autoscaling (HPA)

### Configuration

Location: `kubernetes/ml-inference-hpa.yaml`

```yaml
minReplicas: 2  # High availability
maxReplicas: 10 # Cost control
metrics:
  - CPU: 70%     # Scale up when CPU > 70%
  - Memory: 80%  # Scale up when memory > 80%
```

### Deployment

```bash
# Apply HPA to your AKS cluster
kubectl apply -f kubernetes/ml-inference-hpa.yaml

# Verify HPA status
kubectl get hpa ml-inference-hpa
kubectl describe hpa ml-inference-hpa
```

### Scaling Behavior

- **Scale Up**: Immediate when thresholds exceeded
- **Scale Down**: 5-minute stabilization window to prevent flapping
- **Max Scale Rate**: 100% increase (double) or +4 pods per minute

### Monitoring

```bash
# Watch scaling events
kubectl get hpa ml-inference-hpa --watch

# Check current replica count
kubectl get deployment ml-inference
```

---

## API Management & Rate Limiting

### Policies Configured

Location: `infrastructure/aks.tf` (APIM policy resource)

**Rate Limits:**
- 100 requests/minute per IP address
- 1,000,000 requests/month per subscription key
- 5MB request size limit

**Features:**
- Correlation ID injection for distributed tracing
- Request/response timestamps
- CORS support
- 30-second backend timeout
- Automatic error response formatting

### Enable APIM

```hcl
# In terraform.tfvars
enable_api_management = true
```

### Get APIM Gateway URL

```bash
az apimgw show --name <apim-name> --resource-group <rg> --query gatewayUrl -o tsv
```

### Test Rate Limiting

```bash
# This will hit rate limit after 100 requests
for i in {1..150}; do
  curl -X POST https://<apim-gateway>/inference/score \
    -H "Content-Type: application/json" \
    -d '{"data": [[1,2,3,4]]}' &
done
```

---

## Response Caching with Redis

### Infrastructure

Location: `infrastructure/cache.tf`

**Specifications:**
- SKU: Standard C1 (1GB cache)
- TLS 1.2 enforced
- Eviction policy: LRU (Least Recently Used)
- Connection strings stored in Key Vault

### Enable Redis Cache

```hcl
# In terraform.tfvars
enable_redis_cache = true
```

### Integrate with Inference Code

```python
# Example: Add Redis caching to score.py
import redis
import hashlib
import json

# Initialize Redis connection (in init())
redis_client = redis.Redis(
    host=os.getenv("REDIS_HOST"),
    port=int(os.getenv("REDIS_PORT", "6380")),
    password=os.getenv("REDIS_PASSWORD"),
    ssl=True,
    decode_responses=True
)

# In run() function
def run(request_body):
    # Generate cache key from input
    cache_key = hashlib.md5(json.dumps(request_body).encode()).hexdigest()
    
    # Check cache first
    cached = redis_client.get(cache_key)
    if cached:
        logger.info(f"Cache hit for request {request_id}")
        return json.loads(cached)
    
    # Make prediction
    result = model.predict(inputs)
    
    # Cache result (TTL: 1 hour)
    redis_client.setex(cache_key, 3600, json.dumps(result))
    
    return result
```

### Monitor Cache Performance

```bash
# Cache hit rate
az monitor metrics list \
  --resource <redis-id> \
  --metric "cachehitrate" \
  --interval PT5M
```

---

## Health Checks & Probes

### Endpoints Available

**`health()`** - Combined readiness/liveness check
- Returns 200 if model loaded
- Returns 503 if model not loaded
- Includes uptime, request count, error rate

**`readiness()`** - Kubernetes readiness probe
- Checks if service can handle traffic

**`liveness()`** - Kubernetes liveness probe
- Checks if service is alive (may not be ready yet during init)

### Kubernetes Configuration

```yaml
# Add to your deployment.yaml
livenessProbe:
  httpGet:
    path: /liveness
    port: 5001
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /readiness
    port: 5001
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
```

### Test Health Endpoints

```bash
# Health check
curl http://<service-url>/health

# Example response:
{
  "status": "healthy",
  "model_loaded": true,
  "model_name": "diabetes-classifier",
  "model_version": "v1.2.3",
  "uptime_seconds": 3600.45,
  "total_requests": 15234,
  "error_count": 12,
  "error_rate_percent": 0.08
}
```

---

## Model Versioning & Metrics

### Environment Variables

Set these in your deployment:

```yaml
env:
  - name: MODEL_VERSION
    value: "v1.2.3"
  - name: MODEL_NAME
    value: "diabetes-classifier"
  - name: DEPLOYMENT_NAME
    value: "production"
```

### Response Metadata

Every inference response includes:

```json
{
  "predictions": [0, 1, 0],
  "metadata": {
    "model_name": "diabetes-classifier",
    "model_version": "v1.2.3",
    "deployment": "production",
    "request_id": "1699564800123-42",
    "inference_time_ms": 12.34,
    "timestamp": "2025-11-09T10:00:00.000Z",
    "num_predictions": 3
  }
}
```

### Tracking Metrics

```python
# Metrics are automatically logged
logger.info(f"Request {request_id} completed in {inference_duration*1000:.2f}ms")

# Global counters available:
# - REQUEST_COUNT: Total requests processed
# - ERROR_COUNT: Total errors encountered
# - INIT_TIME: Service start time
```

---

## SLO Monitoring

### Defined SLOs

Location: `infrastructure/monitoring.tf`

**Latency SLOs:**
- P95 < 200ms (Severity 2 alert)
- P99 < 500ms (Severity 3 alert)

**Availability SLO:**
- Error rate < 1% (Severity 1 alert)

### Log Analytics Queries

**P50/P95/P99 Dashboard Query:**
```kql
ContainerLog
| where LogEntry contains "completed in"
| extend InferenceTimeMs = todouble(extract("completed in (\\d+\\.\\d+)ms", 1, LogEntry))
| where isnotnull(InferenceTimeMs)
| summarize 
    P50=percentile(InferenceTimeMs, 50),
    P95=percentile(InferenceTimeMs, 95),
    P99=percentile(InferenceTimeMs, 99),
    TotalRequests=count()
    by bin(TimeGenerated, 5m)
```

**Error Rate Query:**
```kql
ContainerLog
| where LogEntry contains "Request" and (LogEntry contains "completed" or LogEntry contains "failed")
| extend IsError = iff(LogEntry contains "failed", 1, 0)
| summarize ErrorCount=sum(IsError), TotalCount=count() by bin(TimeGenerated, 5m)
| extend ErrorRate = (ErrorCount * 100.0) / TotalCount
```

### SLO Alerting

Alerts trigger when:
- P95 > 200ms for 2 consecutive 5-minute windows
- P99 > 500ms for 2 consecutive 5-minute windows
- Error rate > 1% for 2 consecutive 5-minute windows

Alerts send to configured action group (email/webhook).

---

## Input Validation

### Protections Implemented

**Size Limits:**
- Max request payload: 10MB
- Max array elements: 100,000
- Max array dimensions: 2 (1D or 2D only)

**Validation Logic:**

```python
def _validate_input(data, max_batch_size=100, max_features=1000):
    """Validate input data to prevent malicious requests."""
    if data is None:
        raise ValueError("Request body is empty or None")
    
    if isinstance(data, str) and len(data) > 10_000_000:
        raise ValueError("Request payload too large (>10MB)")
    
    return True
```

### Error Responses

Invalid inputs return structured errors:

```json
{
  "error": "Input array too large: 150000 elements. Maximum 100,000 allowed.",
  "trace": "...",
  "metadata": {
    "request_id": "...",
    "timestamp": "...",
    "model_version": "..."
  }
}
```

---

## Deployment Checklist

### 1. Infrastructure Setup

```bash
# Enable required features in terraform.tfvars
enable_aks_deployment    = true
enable_api_management    = true
enable_redis_cache       = true  # Optional but recommended

# Deploy infrastructure
cd infrastructure
terraform init
terraform plan -var-file=terraform.tfvars.dev-edge-learning
terraform apply
```

### 2. Deploy HPA

```bash
# Get AKS credentials
az aks get-credentials --name <aks-name> --resource-group <rg>

# Update HPA manifest with your deployment name
# Edit kubernetes/ml-inference-hpa.yaml: spec.scaleTargetRef.name

# Apply HPA
kubectl apply -f kubernetes/ml-inference-hpa.yaml
```

### 3. Configure Model Deployment

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-inference
spec:
  replicas: 2  # HPA will manage this
  template:
    spec:
      containers:
      - name: inference
        image: <acr>.azurecr.io/ml-inference:latest
        env:
          - name: MODEL_VERSION
            value: "v1.0.0"
          - name: MODEL_NAME
            value: "my-model"
          - name: REDIS_HOST
            valueFrom:
              secretKeyRef:
                name: redis-secret
                key: host
        resources:
          requests:
            cpu: "500m"
            memory: "1Gi"
          limits:
            cpu: "2000m"
            memory: "4Gi"
        livenessProbe:
          httpGet:
            path: /liveness
            port: 5001
          initialDelaySeconds: 30
        readinessProbe:
          httpGet:
            path: /readiness
            port: 5001
          initialDelaySeconds: 10
```

### 4. Verify Deployment

```bash
# Check HPA status
kubectl get hpa

# Check pod count (should be 2 initially)
kubectl get pods -l app=ml-inference

# Test health endpoint
kubectl port-forward svc/ml-inference 5001:5001
curl http://localhost:5001/health

# Send test inference request
curl -X POST http://localhost:5001/score \
  -H "Content-Type: application/json" \
  -d '{"data": [[1,2,3,4]]}'
```

### 5. Monitor Performance

```bash
# View logs
kubectl logs -l app=ml-inference --tail=100 -f

# Check metrics in Azure Portal
# Navigate to: Log Analytics Workspace > Logs > Run "InferenceSLOMetrics" query

# View APIM analytics
# Azure Portal > API Management > Analytics
```

---

## Performance Tuning

### HPA Tuning

- Increase `maxReplicas` if hitting capacity
- Lower CPU/memory thresholds for more aggressive scaling
- Adjust `stabilizationWindowSeconds` for scale-down behavior

### Redis Tuning

- Monitor cache hit rate (target: >80%)
- Adjust TTL based on model update frequency
- Consider Premium tier for persistence

### APIM Tuning

- Adjust rate limits based on traffic patterns
- Enable response caching in APIM for GET requests
- Configure backend pool for multiple replicas

---

## Troubleshooting

### HPA Not Scaling

```bash
# Check metrics server
kubectl get apiservice v1beta1.metrics.k8s.io

# Verify resource requests are set
kubectl describe deployment ml-inference

# Check HPA events
kubectl describe hpa ml-inference-hpa
```

### High Latency

1. Check P95/P99 metrics in Log Analytics
2. Verify HPA scaled up (check pod count)
3. Review Redis cache hit rate
4. Check for model loading issues in logs
5. Verify APIM backend timeout (30s default)

### Cache Misses

- Review cache key generation logic
- Check Redis memory usage
- Verify TTL not too short
- Consider increasing Redis capacity

---

## Next Steps

1. **A/B Testing**: Add traffic splitting between model versions
2. **Batch Inference**: Implement async batch endpoint with queues
3. **Model Explanation**: Add SHAP/LIME endpoints for interpretability
4. **Blue/Green Deployment**: Use Front Door weighted routing
5. **GPU Optimization**: Add ONNX Runtime with CUDA support

---

## References

- [Kubernetes HPA Documentation](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Azure APIM Policies](https://docs.microsoft.com/azure/api-management/api-management-policies)
- [Azure Cache for Redis](https://docs.microsoft.com/azure/azure-cache-for-redis/)
- [Azure Monitor SLO Tracking](https://docs.microsoft.com/azure/azure-monitor/logs/query-optimization)
