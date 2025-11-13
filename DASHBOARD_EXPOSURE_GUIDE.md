# Industry-Standard Dashboard Exposure Setup

This guide shows how to securely expose Grafana and Prometheus dashboards for production use, following industry best practices.

## Current Setup (Development Only)

**Port-Forward (NOT for production):**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

**Issues:**
- ❌ Only accessible from your local machine
- ❌ Requires manual port-forward command
- ❌ Not secure for team access
- ❌ No authentication integration
- ❌ Not suitable for on-call engineers

---

## Production-Ready Options

### Option 1: NGINX Ingress + Azure AD (Recommended for Azure)

**What You Get:**
- ✅ HTTPS with SSL certificates
- ✅ Custom domain names (grafana.yourdomain.com)
- ✅ Azure AD authentication (SSO)
- ✅ Role-based access control
- ✅ Accessible 24/7 for your team
- ✅ Rate limiting and DDoS protection

**Architecture:**
```
Internet
    │
    ├─► Azure Front Door (optional)
    │
    ├─► NGINX Ingress Controller
        │
        ├─► OAuth2 Proxy (Azure AD auth)
        │
        ├─► Grafana (port 80)
        └─► Prometheus (port 9090)
```

**Implementation:** See `kubernetes/ingress-grafana.yaml`

---

### Option 2: Azure Application Gateway (Enterprise)

**What You Get:**
- ✅ Fully managed Azure service
- ✅ WAF (Web Application Firewall)
- ✅ Auto-scaling
- ✅ Azure AD integration
- ✅ DDoS protection
- ✅ Azure Monitor integration

**Cost:** ~$125/month + data processing

**Best for:** Enterprise setups with compliance requirements

---

### Option 3: Private Endpoints + VPN (Maximum Security)

**What You Get:**
- ✅ No public internet exposure
- ✅ Accessible only via VPN
- ✅ Perfect for regulated industries
- ✅ Azure Private Link integration

**Best for:** Financial, healthcare, government sectors

---

### Option 4: Azure Static Web Apps + API Proxy

**What You Get:**
- ✅ Serverless dashboard hosting
- ✅ Azure AD authentication
- ✅ CDN distribution
- ✅ Low cost (~$10/month)

**Best for:** Small teams, cost-conscious setups

---

## Recommended Setup for Your Project

I've implemented **Option 1** (NGINX Ingress + Azure AD) as it's the most common in industry for AKS deployments.

### What's Included

1. ✅ **NGINX Ingress Controller** - Routes traffic to services
2. ✅ **Cert-Manager** - Automatic SSL certificates (Let's Encrypt)
3. ✅ **OAuth2 Proxy** - Azure AD authentication
4. ✅ **Ingress Resources** - Route definitions for Grafana/Prometheus
5. ✅ **Network Policies** - Restrict access to monitoring namespace

### File Structure

```
kubernetes/
├── ingress/
│   ├── nginx-ingress-controller.yaml    # NGINX controller deployment
│   ├── cert-manager.yaml                # SSL certificate automation
│   ├── oauth2-proxy.yaml                # Azure AD authentication
│   ├── grafana-ingress.yaml             # Grafana ingress route
│   ├── prometheus-ingress.yaml          # Prometheus ingress route
│   └── network-policies.yaml            # Security policies
└── ...
```

---

## Setup Instructions

### Step 1: Prerequisites

1. **Custom Domain** (or use Azure-provided DNS):
   ```bash
   # Get your AKS cluster's public IP
   kubectl get service -n ingress-nginx ingress-nginx-controller
   
   # Create DNS A records:
   # grafana.yourdomain.com -> <EXTERNAL_IP>
   # prometheus.yourdomain.com -> <EXTERNAL_IP>
   ```

2. **Azure AD App Registration**:
   ```bash
   # Run the setup script
   bash scripts/setup-azure-ad-auth.sh
   
   # This creates:
   # - Azure AD App Registration
   # - Client Secret
   # - Redirect URIs
   # - Required permissions
   ```

### Step 2: Install NGINX Ingress Controller

```bash
# Option A: Via Workflow
gh workflow run setup-ingress.yml

# Option B: Manual
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
```

### Step 3: Install Cert-Manager (SSL)

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### Step 4: Deploy OAuth2 Proxy (Azure AD)

```bash
# Update with your Azure AD details
kubectl create secret generic oauth2-proxy \
  --namespace monitoring \
  --from-literal=client-id='<YOUR_AZURE_AD_CLIENT_ID>' \
  --from-literal=client-secret='<YOUR_AZURE_AD_CLIENT_SECRET>' \
  --from-literal=cookie-secret='<RANDOM_32_CHAR_STRING>'

# Deploy OAuth2 Proxy
kubectl apply -f kubernetes/ingress/oauth2-proxy.yaml
```

### Step 5: Apply Ingress Resources

```bash
# Apply Grafana ingress
kubectl apply -f kubernetes/ingress/grafana-ingress.yaml

# Apply Prometheus ingress
kubectl apply -f kubernetes/ingress/prometheus-ingress.yaml
```

### Step 6: Verify Setup

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check certificates
kubectl get certificate -n monitoring

# Check ingress resources
kubectl get ingress -n monitoring
```

---

## Access Your Dashboards

After setup completes:

### Grafana
- **URL**: https://grafana.yourdomain.com
- **Auth**: Azure AD SSO (automatic)
- **Fallback**: Username: admin, Password: (from secrets)

### Prometheus
- **URL**: https://prometheus.yourdomain.com
- **Auth**: Azure AD SSO (automatic)
- **Note**: Read-only access for non-admins

### AlertManager
- **URL**: https://alerts.yourdomain.com
- **Auth**: Azure AD SSO (automatic)

---

## Security Features

### 1. Authentication
- **Azure AD Integration**: Users log in with company credentials
- **OAuth2 Proxy**: Validates tokens before allowing access
- **Session Management**: Automatic timeout after inactivity

### 2. Authorization
- **RBAC**: Role-based access control via Azure AD groups
- **Read-Only Access**: Default for viewers
- **Admin Access**: Only for designated admins

### 3. Network Security
- **TLS/SSL**: All traffic encrypted (Let's Encrypt)
- **Network Policies**: Restrict pod-to-pod communication
- **IP Whitelisting**: Optional - restrict to corporate IPs

### 4. Audit Logging
- **Access Logs**: NGINX logs all access
- **Authentication Logs**: OAuth2 proxy logs auth attempts
- **Azure AD Logs**: Sign-in activity in Azure Portal

---

## Cost Breakdown

| Component | Cost (Monthly) | Notes |
|-----------|----------------|-------|
| NGINX Ingress | $0 | Runs on existing AKS nodes |
| Cert-Manager | $0 | Open source |
| Let's Encrypt SSL | $0 | Free certificates |
| Domain Name | $12 | .com domain |
| Azure Load Balancer | $18 | Public IP + rules |
| **Total** | **~$30** | Minimal additional cost |

**Alternative (Azure App Gateway):**
- Base: $125/month
- Data Processing: $8/GB
- WAF: +$60/month
- **Total: ~$200-300/month**

---

## Comparison: Industry Practices

### Startups / Small Teams
✅ **NGINX Ingress + OAuth2**
- Cost-effective (~$30/month)
- Easy to set up
- Scales well
- **Your current setup**

### Mid-Size Companies
✅ **Azure Application Gateway**
- Managed service
- Built-in WAF
- Better for compliance

### Enterprise / Regulated
✅ **Private Link + VPN**
- No public exposure
- Maximum security
- Higher complexity

---

## Alternative: Azure Managed Grafana

Azure offers **fully managed Grafana** as a service:

### Pros:
- ✅ Zero maintenance
- ✅ Built-in Azure AD integration
- ✅ Automatic updates
- ✅ HA and backup
- ✅ Direct Azure Monitor integration

### Cons:
- ❌ Cost: $50-200/month
- ❌ Less customization
- ❌ Vendor lock-in

### Setup:
```bash
# Create Azure Managed Grafana
az grafana create \
  --name mlopsnew-grafana \
  --resource-group mlopsnew-dev-rg

# Connect to Prometheus in AKS
az grafana data-source create \
  --name prometheus \
  --type prometheus \
  --url http://prometheus-kube-prometheus-prometheus.monitoring:9090
```

**Recommended for:** Teams that want zero ops overhead

---

## Disaster Recovery

### Backup Dashboards
```bash
# Export all Grafana dashboards
kubectl exec -n monitoring deployment/prometheus-grafana -- \
  grafana-cli admin data-migration export \
  --output-dir=/tmp/backup

# Copy to local
kubectl cp monitoring/<pod-name>:/tmp/backup ./grafana-backup
```

### Restore Dashboards
```bash
# Import dashboards
kubectl exec -n monitoring deployment/prometheus-grafana -- \
  grafana-cli admin data-migration import \
  --input-dir=/tmp/backup
```

---

## Monitoring the Monitors

Yes, you should monitor your monitoring stack!

### Health Checks
```bash
# Prometheus health
curl https://prometheus.yourdomain.com/-/healthy

# Grafana health
curl https://grafana.yourdomain.com/api/health
```

### Alerts for Monitoring Stack
```yaml
# Add to kubernetes/ml-inference-alerts.yaml
- alert: GrafanaDown
  expr: up{job="prometheus-grafana"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Grafana is down"

- alert: PrometheusDown
  expr: up{job="prometheus"} == 0
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "Prometheus is down"
```

---

## Team Access Management

### Add Users via Azure AD

1. **Create Azure AD Group**:
   ```bash
   az ad group create \
     --display-name "MLOps-Monitoring-Viewers" \
     --mail-nickname "mlops-viewers"
   ```

2. **Add Users to Group**:
   ```bash
   az ad group member add \
     --group "MLOps-Monitoring-Viewers" \
     --member-id <user-object-id>
   ```

3. **Configure OAuth2 Proxy**:
   ```yaml
   # In oauth2-proxy config
   azure-groups:
     - "MLOps-Monitoring-Viewers"
     - "MLOps-Monitoring-Admins"
   ```

### Grafana Roles

- **Viewer**: Read-only dashboard access
- **Editor**: Can create/modify dashboards
- **Admin**: Full access including user management

Map to Azure AD groups in Grafana settings.

---

## Troubleshooting

### Can't Access Dashboard

**Check Ingress:**
```bash
kubectl describe ingress -n monitoring grafana-ingress
```

**Check DNS:**
```bash
nslookup grafana.yourdomain.com
```

**Check SSL Certificate:**
```bash
kubectl describe certificate -n monitoring grafana-tls
```

### Authentication Failing

**Check OAuth2 Proxy Logs:**
```bash
kubectl logs -n monitoring -l app=oauth2-proxy
```

**Verify Azure AD Config:**
```bash
az ad app show --id <client-id>
```

### SSL Certificate Not Issuing

**Check Cert-Manager:**
```bash
kubectl logs -n cert-manager deployment/cert-manager
kubectl describe certificate -n monitoring grafana-tls
```

---

## Next Steps

1. **Run Setup Workflow**: Deploy NGINX Ingress + OAuth2 Proxy
2. **Configure DNS**: Point your domain to the load balancer IP
3. **Set Up Azure AD**: Create app registration for SSO
4. **Test Access**: Verify dashboards are accessible via HTTPS
5. **Add Team Members**: Grant access via Azure AD groups
6. **Set Up Alerts**: Configure AlertManager notifications

**For Enterprise Security:** Consider Azure Application Gateway with WAF

**For Maximum Simplicity:** Consider Azure Managed Grafana

**Current Setup:** Best balance of cost, security, and control
