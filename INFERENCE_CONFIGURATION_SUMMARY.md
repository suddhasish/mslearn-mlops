# Inference Best Practices - Configuration Summary

## ✅ All Infrastructure Flags Configured

### Feature Flag Added
- **`enable_redis_cache`**: Controls Azure Cache for Redis deployment

### Updated Files

#### 1. **terraform.tfvars.minimal** ✅
```hcl
enable_redis_cache = false  # Keep costs minimal
```

#### 2. **terraform.tfvars.dev-edge-learning** ✅
```hcl
enable_redis_cache = false  # Optional: set to true for caching tests (~$15/month)
```

#### 3. **terraform.tfvars.free-tier** ✅
```hcl
enable_redis_cache = false  # Disabled for free tier
```

#### 4. **terraform.tfvars.example** ✅
```hcl
enable_redis_cache = false  # Enable for inference caching
```

---

## New Infrastructure Resources

### 1. **cache.tf** (New File)
- `azurerm_redis_cache.mlops` - Redis cache with Standard C1 SKU
- `azurerm_role_assignment.terraform_kv_secrets_officer` - RBAC for Key Vault access
- `azurerm_key_vault_secret.redis_*` - 4 secrets stored in Key Vault:
  - `redis-connection-string`
  - `redis-host`
  - `redis-port`
  - `redis-password`
- `azurerm_monitor_diagnostic_setting.redis` - Log Analytics integration
- `azurerm_monitor_metric_alert.redis_memory_usage` - Alert at 85% memory
- `azurerm_monitor_metric_alert.redis_cache_miss_rate` - Alert at 20% miss rate

**Conditional**: Only created when `enable_redis_cache = true`

---

### 2. **aks.tf** (Updated)
- `azurerm_api_management_api.ml_inference` - ML Inference API definition
- `azurerm_api_management_api_policy.ml_inference_policy` - Rate limiting policies:
  - 100 requests/min per IP
  - 1M requests/month per subscription key
  - 5MB request size limit
  - Correlation ID injection
  - 30s backend timeout

**Conditional**: Only created when `enable_api_management = true`

---

### 3. **monitoring.tf** (Updated)
- `azurerm_log_analytics_saved_search.inference_slo_metrics` - P50/P95/P99 query
- `azurerm_monitor_scheduled_query_rules_alert_v2.inference_p95_latency` - P95 > 200ms alert
- `azurerm_monitor_scheduled_query_rules_alert_v2.inference_p99_latency` - P99 > 500ms alert
- `azurerm_monitor_scheduled_query_rules_alert_v2.inference_error_rate` - Error rate > 1% alert

**Conditional**: Only created when `enable_aks_deployment = true`

---

### 4. **outputs.tf** (Updated)
Added Redis outputs (conditional):
- `redis_cache_name`
- `redis_cache_hostname`
- `redis_cache_ssl_port`

---

## Application Code Updates

### **src/score.py** (Enhanced)
**New Features:**
- ✅ Model version tracking (`MODEL_VERSION`, `MODEL_NAME`, `DEPLOYMENT_NAME`)
- ✅ Request/error counters (`REQUEST_COUNT`, `ERROR_COUNT`)
- ✅ Inference latency tracking (milliseconds precision)
- ✅ Request ID generation for tracing
- ✅ Response metadata (timestamps, durations, request IDs)
- ✅ Health endpoints: `health()`, `readiness()`, `liveness()`
- ✅ Input validation (size limits, dimension checks)
- ✅ Structured error responses

**Backward Compatible**: All existing functionality preserved

---

## Kubernetes Manifests

### 1. **kubernetes/ml-inference-hpa.yaml** (New)
- Autoscaling: 2-10 replicas
- CPU threshold: 70%
- Memory threshold: 80%
- Scale-down: 5-minute stabilization
- Scale-up: Immediate

### 2. **kubernetes/ml-inference-deployment.yaml** (New)
- Sample deployment with health probes
- Resource requests/limits defined
- Liveness probe: `/liveness` endpoint
- Readiness probe: `/readiness` endpoint
- Service and Ingress templates

---

## Documentation

### **documentation/09-inference-best-practices.md** (New)
Complete guide covering:
- HPA deployment steps
- APIM rate limiting configuration
- Redis caching integration examples
- Health probe setup
- Model versioning
- SLO monitoring queries
- Input validation
- Troubleshooting guide
- Performance tuning

---

## Deployment Summary by Profile

### **Minimal Profile** (`terraform.tfvars.minimal`)
```hcl
enable_aks_deployment  = false
enable_api_management  = false
enable_front_door      = false
enable_traffic_manager = false
enable_redis_cache     = false
```
**Result**: No inference optimizations deployed (pure Azure ML managed endpoints)

---

### **Dev Edge Learning** (`terraform.tfvars.dev-edge-learning`)
```hcl
enable_aks_deployment  = true
enable_api_management  = true
enable_front_door      = true
enable_traffic_manager = true
enable_redis_cache     = false  # Optional
```
**Result**: 
- ✅ AKS with HPA capability
- ✅ APIM with rate limiting
- ✅ SLO monitoring alerts
- ❌ Redis cache (disabled by default)

**To Enable Redis**: Set `enable_redis_cache = true` (adds ~$15/month)

---

### **Free Tier** (`terraform.tfvars.free-tier`)
```hcl
enable_aks_deployment  = false
enable_api_management  = false
enable_redis_cache     = false
```
**Result**: All inference optimizations disabled (cost optimization)

---

## Cost Impact

| Component | Monthly Cost | Enabled By Default |
|-----------|-------------|-------------------|
| HPA (K8s feature) | $0 | ✅ (when AKS enabled) |
| APIM Rate Limiting | $0* | ✅ (when APIM enabled) |
| SLO Alerts | $0-2 | ✅ (when AKS enabled) |
| Redis Standard C1 | ~$15 | ❌ (opt-in) |

*Included in existing APIM Developer_1 SKU cost

---

## Validation Checklist

Before deploying, verify:

- [ ] `enable_redis_cache` flag set in your tfvars file
- [ ] All tfvars files updated (minimal, dev-edge-learning, free-tier, example)
- [ ] Key Vault RBAC permissions in place
- [ ] No duplicate role assignments in cache.tf
- [ ] Outputs.tf includes Redis outputs
- [ ] Monitoring alerts conditional on `enable_aks_deployment`

---

## Known Issues & Resolutions

### Issue 1: Key Vault Access Denied
**Symptom**: Terraform fails creating Redis secrets
**Cause**: RBAC-enabled Key Vault requires role assignment
**Fix**: ✅ Added `azurerm_role_assignment.terraform_kv_secrets_officer` in cache.tf

### Issue 2: APIM Backend URL
**Symptom**: APIM policy references missing backend
**Cause**: Service URL needs AKS FQDN when AKS enabled
**Fix**: ✅ Conditional service URL: `service_url = var.enable_aks_deployment ? "http://${azurerm_kubernetes_cluster.mlops[0].fqdn}" : ""`

### Issue 3: Circular Dependencies
**Symptom**: Terraform dependency cycle
**Fix**: ✅ Added `skip_service_principal_aad_check = true` to role assignment

---

## Next Actions

1. **Choose your profile**:
   - Minimal: No inference optimizations
   - Dev Edge Learning: Full stack (AKS + APIM + alerts)
   - Custom: Mix and match flags

2. **Optional: Enable Redis**:
   ```hcl
   enable_redis_cache = true
   ```

3. **Deploy infrastructure**:
   ```bash
   cd infrastructure
   terraform init
   terraform plan -var-file=terraform.tfvars.dev-edge-learning
   terraform apply
   ```

4. **Deploy HPA** (if AKS enabled):
   ```bash
   kubectl apply -f kubernetes/ml-inference-hpa.yaml
   ```

5. **Update scoring script**:
   - Use enhanced `src/score.py` in your deployments
   - Set environment variables for versioning

6. **Configure health probes**:
   - Use sample `kubernetes/ml-inference-deployment.yaml`
   - Customize for your model

---

## Reference Links

- [Complete Implementation Guide](./09-inference-best-practices.md)
- [Architecture Diagram](./dev-edge-architecture.md)
- [Minimal Deployment](./07-minimal-deployment.md)
- [Edge Learning Deployment](./08-dev-edge-learning.md)
