#!/usr/bin/env bash
# Usage:
#   ./create_eventgrid_subscription.sh <subscription-id> <resource-group> <workspace-name> <function-endpoint-url> <event-sub-name>
#
# Example:
# ./create_eventgrid_subscription.sh <sub> <rg> <workspace> "https://<function-app>.azurewebsites.net/api/deploy_trigger?code=<key>" SendModelRegisteredToFunction

set -euo pipefail

if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <subscription-id> <resource-group> <workspace-name> <function-endpoint-url> <event-sub-name>"
  exit 2
fi

SUBSCRIPTION_ID="$1"
RESOURCE_GROUP="$2"
WORKSPACE="$3"
ENDPOINT_URL="$4"
SUB_NAME="$5"

RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.MachineLearningServices/workspaces/${WORKSPACE}"

# Adjust included-event-types to the event type(s) your workspace emits for model registration.
# You may need to inspect events from your workspace; a safe catch-all is ArtifactCreated.
az eventgrid event-subscription create \
  --resource-id "${RESOURCE_ID}" \
  --name "${SUB_NAME}" \
  --endpoint "${ENDPOINT_URL}" \
  --included-event-types Microsoft.MachineLearningServices.ArtifactCreated Microsoft.MachineLearningServices.ModelRegistered || true

echo "Event subscription created (or already exists)."
