#!/bin/bash
# Create training data asset in Azure ML workspace using Azure Blob Storage

set -euo pipefail

# Configuration
SUBSCRIPTION_ID="b2b8a5e6-9a34-494b-ba62-fe9be95bd398"
RESOURCE_GROUP="mlopsnew-dev-rg"
WORKSPACE="mlopsnew-dev-mlw"
STORAGE_ACCOUNT="mlopsnewdevst3kxldb"
CONTAINER_NAME=""  # Will be discovered from workspaceblobstore
BLOB_PATH="diabetes"
DATA_NAME="diabetes-dev-folder"
DATA_VERSION="$(date +%Y%m%d%H%M%S)"  # Use timestamp for unique version
LOCAL_DATA_PATH="production/data"

echo "=========================================="
echo "Step 1: Get workspaceblobstore container name"
echo "=========================================="

# Get the actual container name used by workspaceblobstore
echo "Querying Azure ML datastore for container name..."
CONTAINER_NAME=$(az ml datastore show \
  --name workspaceblobstore \
  --workspace-name "$WORKSPACE" \
  --resource-group "$RESOURCE_GROUP" \
  --subscription "$SUBSCRIPTION_ID" \
  --query "container_name" -o tsv)

echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container (from workspaceblobstore): $CONTAINER_NAME"

# Get storage account key
echo "Getting storage account key..."
STORAGE_KEY=$(az storage account keys list \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --subscription "$SUBSCRIPTION_ID" \
  --query "[0].value" -o tsv)

echo "✅ Container name retrieved: $CONTAINER_NAME"
echo ""

echo "=========================================="
echo "Step 2: Upload training data to blob storage"
echo "=========================================="
echo "Current directory: $(pwd)"
echo "Checking if data path exists: $LOCAL_DATA_PATH"

if [ ! -d "$LOCAL_DATA_PATH" ]; then
  echo "❌ Error: Data directory not found at $LOCAL_DATA_PATH"
  echo "Contents of current directory:"
  ls -la
  exit 1
fi

echo "Uploading from: $LOCAL_DATA_PATH"
echo "To: $CONTAINER_NAME/$BLOB_PATH"
echo "Files to upload:"
ls -lh "$LOCAL_DATA_PATH"

# Upload data to blob storage (using account key)
az storage blob upload-batch \
  --account-name "$STORAGE_ACCOUNT" \
  --account-key "$STORAGE_KEY" \
  --destination "$CONTAINER_NAME" \
  --destination-path "$BLOB_PATH" \
  --source "$LOCAL_DATA_PATH" \
  --overwrite \
  --only-show-errors

echo "✅ Data uploaded successfully"
echo ""

echo "=========================================="
echo "Step 3: Create data asset in Azure ML"
echo "=========================================="
echo "Data Asset Name: $DATA_NAME"
echo "Version: $DATA_VERSION"

# Construct the Azure ML datastore path
DATASTORE_PATH="azureml://subscriptions/$SUBSCRIPTION_ID/resourcegroups/$RESOURCE_GROUP/workspaces/$WORKSPACE/datastores/workspaceblobstore/paths/$BLOB_PATH"

# Create data asset pointing to blob storage
az ml data create \
  --name "$DATA_NAME" \
  --version "$DATA_VERSION" \
  --type uri_folder \
  --path "$DATASTORE_PATH" \
  --workspace-name "$WORKSPACE" \
  --resource-group "$RESOURCE_GROUP" \
  --subscription "$SUBSCRIPTION_ID"

echo ""
echo "✅ Data asset created successfully!"
echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "Storage Account: $STORAGE_ACCOUNT"
echo "Container: $CONTAINER_NAME"
echo "Blob Path: $BLOB_PATH"
echo "Data Asset: $DATA_NAME:$DATA_VERSION"
echo ""
echo "You can now reference it in your job YAML as:"
echo "  path: azureml:${DATA_NAME}@latest"
echo "  or"
echo "  path: azureml:${DATA_NAME}:${DATA_VERSION}"
echo ""
echo "View in Azure Portal:"
echo "https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT/containersList"
