# Dashboard Exposure - Quick Reference

## TL;DR

**Development (Current):**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Access: http://localhost:3000
```

**Production (Industry Standard):**
```bash
# 1. Run workflow to setup NGINX Ingress
gh workflow run setup-ingress.yml --field use_ip_access=true

# 2. Access via LoadBalancer IP (no domain needed)
# Grafana: http://<LOADBALANCER_IP>
# Prometheus: http://<LOADBALANCER_IP>:9090
```

---

## Comparison: Development vs Production

| Feature | Port-Forward (Dev) | NGINX Ingress (Prod) | Azure App Gateway (Enterprise) |
|---------|-------------------|---------------------|-------------------------------|
| **Cost** | Free | ~$30/month | ~$200/month |
| **Setup Time** | 1 command | 5 minutes | 15 minutes |
| **Team Access** | ❌ Single user | ✅ Entire team | ✅ Entire team |
| **Authentication** | ❌ Manual login | ✅ Azure AD SSO | ✅ Azure AD SSO |
| **SSL/HTTPS** | ❌ No | ✅ Yes (Let's Encrypt) | ✅ Yes |
| **High Availability** | ❌ No | ✅ Yes | ✅ Yes |
| **DDoS Protection** | ❌ No | ⚠️ Basic | ✅ Advanced |
| **WAF** | ❌ No | ❌ No | ✅ Yes |
| **Maintenance** | ❌ Manual | ⚠️ Self-managed | ✅ Fully managed |

---

## Industry Standard Approaches

### 1. Startups & Small Teams
**Approach**: NGINX Ingress + OAuth2 Proxy
- Cost-effective (~$30/month)
- Self-managed but simple
- **Your current implementation** ✅

### 2. Mid-Size Companies
**Approach**: Azure Application Gateway + Azure AD
- Fully managed (~$200/month)
- Built-in WAF and DDoS protection
- Better for compliance requirements

### 3. Enterprise & Regulated Industries
**Approach**: Private Link + VPN-only access
- No public internet exposure
- Maximum security
- Common in finance, healthcare, government

### 4. Modern SaaS Companies
**Approach**: Azure Managed Grafana
- Zero ops overhead (~$50-200/month)
- Automatic updates and scaling
- Direct Azure Monitor integration

---

## What's Included in Your Setup

✅ **NGINX Ingress Controller** - Industry-standard ingress
✅ **Cert-Manager** - Automatic SSL certificates
✅ **OAuth2 Proxy** - Azure AD authentication
✅ **Rate Limiting** - DDoS protection
✅ **Security Headers** - XSS, clickjacking protection
✅ **Network Policies** - Pod-to-pod security

---

## Quick Setup (3 Steps)

### Step 1: Run Ingress Setup Workflow
```bash
# Via GitHub UI: Actions → Setup Ingress & Dashboard Exposure → Run workflow
# Or via CLI:
gh workflow run setup-ingress.yml --field use_ip_access=true
```

### Step 2: Get LoadBalancer IP
```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Note the EXTERNAL-IP
```

### Step 3: Access Dashboards
```bash
# Grafana
http://<EXTERNAL-IP>

# Prometheus  
http://<EXTERNAL-IP>:9090
```

**That's it!** No DNS, no Azure AD configuration needed for basic access.

---

## Adding Authentication (Optional)

To add Azure AD SSO:

### 1. Create Azure AD App Registration
```bash
az ad app create \
  --display-name "MLOps Monitoring" \
  --web-redirect-uris "https://grafana.yourdomain.com/oauth2/callback"
```

### 2. Create GitHub Secret
```bash
gh secret set AZURE_AD_CLIENT_ID
gh secret set AZURE_AD_CLIENT_SECRET
```

### 3. Enable OAuth2 in Workflow
Edit `.github/workflows/setup-ingress.yml`:
```yaml
setup-oauth2:
  if: true  # Change from false to true
```

### 4. Re-run Workflow
```bash
gh workflow run setup-ingress.yml
```

---

## Real-World Examples

### Example 1: Airbnb
- **Approach**: Custom Grafana on Kubernetes
- **Auth**: Internal OAuth2 provider
- **Access**: Ingress with internal DNS
- **Similar to**: Your NGINX Ingress setup

### Example 2: Uber
- **Approach**: Multiple Grafana instances
- **Auth**: SSO with MFA
- **Access**: VPN-only (no public internet)
- **Different from**: Your setup (they don't expose publicly)

### Example 3: Stripe
- **Approach**: Managed Grafana Cloud
- **Auth**: SAML with Okta
- **Access**: Public with strong auth
- **Similar to**: Azure Managed Grafana option

### Example 4: Netflix
- **Approach**: Custom monitoring platform (Atlas)
- **Auth**: Internal auth system
- **Access**: Internal network only
- **Different from**: Your setup (fully custom)

---

## Cost Analysis

### Your Current Setup (NGINX Ingress)
```
Azure LoadBalancer:     $18/month
Domain name (.com):     $12/month (optional)
SSL Certificate:        $0 (Let's Encrypt)
NGINX Ingress:          $0 (self-hosted)
OAuth2 Proxy:           $0 (self-hosted)
────────────────────────────────────
Total:                  ~$30/month
```

### Alternative: Azure Managed Grafana
```
Grafana Essentials:     $50/month
Data retention:         $20/month
User seats (5):         $50/month
────────────────────────────────────
Total:                  ~$120/month
```

### Alternative: Azure App Gateway
```
Gateway v2:             $125/month
Data processing:        $8/GB (~$50)
WAF:                    $60/month
────────────────────────────────────
Total:                  ~$235/month
```

**Recommendation**: Start with NGINX Ingress ($30/month)

---

## Troubleshooting

### Can't Access Dashboard
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resources
kubectl get ingress -n monitoring

# Check service
kubectl get svc -n ingress-nginx
```

### LoadBalancer Stuck in "Pending"
```bash
# Check Azure Load Balancer
az network lb list --resource-group mlopsnew-dev-rg

# Check AKS service principal permissions
az aks show --resource-group mlopsnew-dev-rg --name mlopsnew-dev-aks --query servicePrincipalProfile
```

### SSL Certificate Not Issuing
```bash
# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate status
kubectl describe certificate -n monitoring grafana-tls
```

---

## Security Checklist

- [ ] LoadBalancer external IP obtained
- [ ] NGINX Ingress controller running
- [ ] Rate limiting enabled (10 req/s per IP)
- [ ] Security headers configured
- [ ] OAuth2 Proxy deployed (if using Azure AD)
- [ ] Network policies applied
- [ ] SSL/TLS certificates issued (if using domain)
- [ ] Audit logging enabled
- [ ] Backup strategy defined

---

## Migration Path

### Phase 1: Development (Current)
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

### Phase 2: Basic Production (This Setup)
```bash
gh workflow run setup-ingress.yml
# Access via: http://<EXTERNAL-IP>
```

### Phase 3: Secured Production
```bash
# Add Azure AD authentication
# Enable SSL with custom domain
# Configure network policies
```

### Phase 4: Enterprise (Future)
```bash
# Migrate to Azure Managed Grafana OR
# Migrate to Azure Application Gateway
# Add WAF and advanced DDoS protection
```

---

## Next Steps

1. ✅ **Now**: Use port-forward for development
2. ⏭️ **Next**: Run setup-ingress workflow for team access
3. 🔒 **Later**: Add Azure AD authentication
4. 🏢 **Future**: Consider Azure Managed Grafana if ops overhead becomes high

**See**: `DASHBOARD_EXPOSURE_GUIDE.md` for detailed instructions
