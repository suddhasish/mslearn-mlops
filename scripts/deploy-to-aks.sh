#!/bin/bash
# Deploy ML model to AKS cluster
# This script builds a Docker image with the model and deploys it to AKS

set -euo pipefail

# Parameters
MODEL_NAME="${1:-diabetes_classification}"
MODEL_VERSION="${2:-latest}"
WORKSPACE_NAME="${3:-mlopsnew-dev-mlw}"
RESOURCE_GROUP="${4:-mlopsnew-dev-rg}"
SUBSCRIPTION_ID="${5:-b2b8a5e6-9a34-494b-ba62-fe9be95bd398}"
AKS_CLUSTER="${6:-mlopsnew-dev-aks}"
ACR_NAME="${7:-mlopsnewdevacr}"
NAMESPACE="${8:-production}"

echo "=========================================="
echo "AKS ML Model Deployment"
echo "=========================================="
echo "Model: $MODEL_NAME:$MODEL_VERSION"
echo "Workspace: $WORKSPACE_NAME"
echo "AKS Cluster: $AKS_CLUSTER"
echo "ACR: $ACR_NAME"
echo "Namespace: $NAMESPACE"
echo "=========================================="

# Step 1: Get ACR login server
echo "Step 1: Getting ACR credentials..."
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
echo "ACR Login Server: $ACR_LOGIN_SERVER"

# Step 2: Login to ACR
echo "Step 2: Logging into ACR..."
az acr login --name $ACR_NAME

# Step 3: Build Docker image
echo "Step 3: Building Docker image..."
IMAGE_TAG="v${MODEL_VERSION}-$(date +%Y%m%d%H%M%S)"
IMAGE_NAME="${ACR_LOGIN_SERVER}/ml-inference:${IMAGE_TAG}"
IMAGE_LATEST="${ACR_LOGIN_SERVER}/ml-inference:latest"

cd "$(dirname "$0")/../src"

# Create a temporary build context with Azure CLI credentials
# Note: Model will be downloaded during Docker build
docker build \
  --build-arg MODEL_NAME="$MODEL_NAME" \
  --build-arg MODEL_VERSION="$MODEL_VERSION" \
  --build-arg WORKSPACE_NAME="$WORKSPACE_NAME" \
  --build-arg RESOURCE_GROUP="$RESOURCE_GROUP" \
  --build-arg SUBSCRIPTION_ID="$SUBSCRIPTION_ID" \
  -t "$IMAGE_NAME" \
  -t "$IMAGE_LATEST" \
  -f Dockerfile .

echo "✅ Image built: $IMAGE_NAME"

# Step 4: Push to ACR
echo "Step 4: Pushing image to ACR..."
docker push "$IMAGE_NAME"
docker push "$IMAGE_LATEST"
echo "✅ Image pushed to ACR"

# Step 5: Get AKS credentials
echo "Step 5: Getting AKS credentials..."
az aks get-credentials \
  --resource-group "$RESOURCE_GROUP" \
  --name "$AKS_CLUSTER" \
  --overwrite-existing
echo "✅ AKS credentials configured"

# Step 6: Create namespace if not exists
echo "Step 6: Creating namespace..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace ready: $NAMESPACE"

# Step 7: Update deployment manifest
echo "Step 7: Preparing deployment manifest..."
cd ../kubernetes

# Create a temporary manifest with updated values
cat ml-inference-deployment.yaml | \
  sed "s|image: .*azurecr.io/ml-inference:.*|image: $IMAGE_NAME|g" | \
  sed "s|value: \"v1\"|value: \"$MODEL_VERSION\"|g" > /tmp/ml-inference-deployment.yaml

echo "Updated manifest:"
cat /tmp/ml-inference-deployment.yaml | grep -A 2 "image:"

# Step 8: Deploy to AKS
echo "Step 8: Deploying to AKS..."
if kubectl get deployment ml-inference -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Deployment exists - performing rolling update..."
  kubectl set image deployment/ml-inference \
    inference="$IMAGE_NAME" \
    -n "$NAMESPACE"
  
  kubectl rollout status deployment/ml-inference -n "$NAMESPACE" --timeout=5m
else
  echo "Creating new deployment..."
  kubectl apply -f /tmp/ml-inference-deployment.yaml -n "$NAMESPACE"
  
  kubectl wait --for=condition=available --timeout=5m \
    deployment/ml-inference -n "$NAMESPACE"
fi

echo "✅ Deployment completed"

# Step 9: Get service endpoint
echo "Step 9: Getting service endpoint..."
echo "Waiting for LoadBalancer to assign external IP..."

for i in {1..30}; do
  EXTERNAL_IP=$(kubectl get service ml-inference -n "$NAMESPACE" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  
  if [ -n "$EXTERNAL_IP" ]; then
    echo "✅ Service URL: http://${EXTERNAL_IP}"
    break
  fi
  
  echo "Waiting for external IP... ($i/30)"
  sleep 10
done

if [ -z "$EXTERNAL_IP" ]; then
  echo "⚠️  Timeout waiting for external IP"
  echo "Service is running but LoadBalancer IP is not yet assigned"
fi

# Step 10: Show deployment status
echo ""
echo "=========================================="
echo "Deployment Status"
echo "=========================================="
kubectl get deployments -n "$NAMESPACE" -l app=ml-inference
echo ""
echo "Pod Status:"
kubectl get pods -n "$NAMESPACE" -l app=ml-inference
echo ""
echo "Service Status:"
kubectl get service ml-inference -n "$NAMESPACE"
echo ""
echo "=========================================="
echo "✅ Deployment completed successfully!"
echo "=========================================="
echo ""
echo "Model: $MODEL_NAME:$MODEL_VERSION"
echo "Image: $IMAGE_NAME"
if [ -n "${EXTERNAL_IP:-}" ]; then
  echo "Endpoint: http://${EXTERNAL_IP}"
  echo ""
  echo "Test the endpoint:"
  echo "  curl http://${EXTERNAL_IP}/health"
  echo "  curl -X POST http://${EXTERNAL_IP}/score -H 'Content-Type: application/json' -d '{\"input_data\": [[1,2,3,4,5,6,7,8]]}'"
fi
echo ""
