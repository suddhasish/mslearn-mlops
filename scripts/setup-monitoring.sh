#!/bin/bash
# Setup Prometheus and Grafana for ML Inference Monitoring

set -euo pipefail

echo "🔧 Setting up Prometheus + Grafana monitoring stack..."

# Add Helm repos
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install kube-prometheus-stack (Prometheus + Grafana + AlertManager)
echo "Installing Prometheus Operator stack..."
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.ruleSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi \
  --set grafana.enabled=true \
  --set grafana.adminPassword='Admin123!' \
  --set alertmanager.enabled=true \
  --wait --timeout=10m

echo "✅ Prometheus Operator installed"

# Wait for pods to be ready
echo "Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

# Apply ServiceMonitor
echo "Applying ServiceMonitor for ML inference..."
kubectl apply -f kubernetes/ml-inference-servicemonitor.yaml

# Apply Alert Rules
echo "Applying Prometheus alert rules..."
kubectl apply -f kubernetes/ml-inference-alerts.yaml

echo ""
echo "✅ Monitoring stack setup complete!"
echo ""
echo "📊 Access Grafana:"
echo "   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "   Then open: http://localhost:3000"
echo "   Username: admin"
echo "   Password: Admin123!"
echo ""
echo "📈 Access Prometheus:"
echo "   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "   Then open: http://localhost:9090"
echo ""
echo "🔔 Access AlertManager:"
echo "   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093"
echo "   Then open: http://localhost:9093"
echo ""
echo "🔍 Verify metrics collection:"
echo "   kubectl get servicemonitor -n production"
echo "   kubectl get prometheusrule -n production"
echo ""
echo "📊 Example Prometheus queries:"
echo "   - Request rate: rate(model_predictions_total[5m])"
echo "   - Latency P95: histogram_quantile(0.95, rate(model_prediction_duration_seconds_bucket[5m]))"
echo "   - Error rate: rate(model_errors_total[5m]) / rate(model_predictions_total[5m])"
echo ""
