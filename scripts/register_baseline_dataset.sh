#!/bin/bash
# Register baseline dataset in Azure ML for drift detection
# This should be run once after initial model training

set -euo pipefail

# Configuration
SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-b2b8a5e6-9a34-494b-ba62-fe9be95bd398}"
RESOURCE_GROUP="${RESOURCE_GROUP:-mlopsnew-dev-rg}"
WORKSPACE="${WORKSPACE:-mlopsnew-dev-mlw}"
STORAGE_ACCOUNT="${STORAGE_ACCOUNT:-mlopsnewdevst3kxldb}"
DATA_PATH="${DATA_PATH:-production/data/diabetes-prod.csv}"
DATASET_NAME="${DATASET_NAME:-diabetes-baseline}"
DESCRIPTION="Baseline dataset for drift detection (training data reference)"

echo "=========================================="
echo "Register Baseline Dataset for Drift Detection"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Subscription: $SUBSCRIPTION_ID"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Workspace: $WORKSPACE"
echo "  Data Path: $DATA_PATH"
echo "  Dataset Name: $DATASET_NAME"
echo ""

# Check if dataset file exists
if [ ! -f "$DATA_PATH" ]; then
    echo "❌ Error: Data file not found: $DATA_PATH"
    exit 1
fi

echo "✅ Data file found: $DATA_PATH"

# Login to Azure (if not already logged in)
echo ""
echo "Checking Azure login..."
if ! az account show &>/dev/null; then
    echo "Not logged in. Please run: az login"
    exit 1
fi

echo "✅ Azure login verified"

# Set subscription
echo ""
echo "Setting subscription..."
az account set --subscription "$SUBSCRIPTION_ID"
echo "✅ Subscription set"

# Get datastore info
echo ""
echo "Getting default datastore..."
DATASTORE_NAME=$(az ml datastore show \
    --name workspaceblobstore \
    --workspace-name "$WORKSPACE" \
    --resource-group "$RESOURCE_GROUP" \
    --query name -o tsv)

echo "✅ Using datastore: $DATASTORE_NAME"

# Get container name
CONTAINER_NAME=$(az ml datastore show \
    --name workspaceblobstore \
    --workspace-name "$WORKSPACE" \
    --resource-group "$RESOURCE_GROUP" \
    --query container_name -o tsv)

echo "✅ Container: $CONTAINER_NAME"

# Upload data to blob storage
BLOB_PATH="drift-baseline/$(basename $DATA_PATH)"

echo ""
echo "Uploading baseline data to blob storage..."
az storage blob upload \
    --account-name "$STORAGE_ACCOUNT" \
    --container-name "$CONTAINER_NAME" \
    --file "$DATA_PATH" \
    --name "$BLOB_PATH" \
    --auth-mode login \
    --overwrite

echo "✅ Data uploaded to: $BLOB_PATH"

# Create dataset YAML definition
YAML_FILE="/tmp/baseline-dataset.yml"
cat > "$YAML_FILE" << EOF
\$schema: https://azuremlschemas.azureedge.net/latest/data.schema.json
name: $DATASET_NAME
description: $DESCRIPTION
version: 1
type: uri_file
path: azureml://datastores/$DATASTORE_NAME/paths/$BLOB_PATH
tags:
  purpose: drift-detection
  dataset_type: baseline
  created_by: automation
EOF

echo ""
echo "Created dataset YAML:"
cat "$YAML_FILE"

# Register dataset
echo ""
echo "Registering dataset in Azure ML..."
az ml data create \
    --file "$YAML_FILE" \
    --workspace-name "$WORKSPACE" \
    --resource-group "$RESOURCE_GROUP"

echo ""
echo "✅ Dataset registered successfully!"
echo ""
echo "Dataset Details:"
az ml data show \
    --name "$DATASET_NAME" \
    --version 1 \
    --workspace-name "$WORKSPACE" \
    --resource-group "$RESOURCE_GROUP"

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Setup drift monitor:"
echo "   python scripts/setup_drift_monitor.py \\"
echo "     --subscription-id $SUBSCRIPTION_ID \\"
echo "     --resource-group $RESOURCE_GROUP \\"
echo "     --workspace $WORKSPACE \\"
echo "     --baseline-dataset $DATASET_NAME"
echo ""
echo "2. Enable production data logging in score.py:"
echo "   kubectl set env deployment/ml-inference \\"
echo "     ENABLE_DRIFT_LOGGING=true \\"
echo "     -n production"
echo ""
echo "3. Run weekly drift detection:"
echo "   gh workflow run drift-detection.yml"
echo ""
