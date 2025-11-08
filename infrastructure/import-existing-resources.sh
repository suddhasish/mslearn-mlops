#!/bin/bash
# Import existing Azure resources into Terraform state
# This script checks for existing resources and imports them if not already in state

set -e

PROJECT_NAME="${1:-mlops}"
ENVIRONMENT="${2:-dev}"
SUBSCRIPTION_ID="${3}"

if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "Error: SUBSCRIPTION_ID is required"
  echo "Usage: $0 <project_name> <environment> <subscription_id>"
  exit 1
fi

RG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-rg"
RESOURCE_PREFIX="${PROJECT_NAME}-${ENVIRONMENT}"

echo "=========================================="
echo "Importing existing resources for:"
echo "  Project: $PROJECT_NAME"
echo "  Environment: $ENVIRONMENT"
echo "  Resource Group: $RG_NAME"
echo "=========================================="

# Function to import resource if it exists and not in state
import_if_exists() {
  local resource_type=$1
  local terraform_address=$2
  local azure_id=$3
  
  # Check if already in state
  if terraform state show "$terraform_address" &>/dev/null; then
    echo "✓ $terraform_address already in state, skipping"
    return 0
  fi
  
  # Check if resource exists in Azure
  if az resource show --ids "$azure_id" &>/dev/null; then
    echo "→ Importing $terraform_address..."
    if terraform import "$terraform_address" "$azure_id" 2>&1 | grep -v "Import successful\|Importing from ID"; then
      echo "✓ Successfully imported $terraform_address"
    fi
  else
    echo "- $terraform_address does not exist in Azure, skipping"
  fi
}

echo ""
echo "1. Importing Resource Group..."
import_if_exists \
  "azurerm_resource_group" \
  "azurerm_resource_group.mlops" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME"

echo ""
echo "2. Importing Networking Resources..."
import_if_exists \
  "azurerm_virtual_network" \
  "azurerm_virtual_network.mlops" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/virtualNetworks/${RESOURCE_PREFIX}-vnet"

import_if_exists \
  "azurerm_network_security_group" \
  "azurerm_network_security_group.ml_nsg" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/networkSecurityGroups/${RESOURCE_PREFIX}-ml-nsg"

import_if_exists \
  "azurerm_network_security_group" \
  "azurerm_network_security_group.aks_nsg" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/networkSecurityGroups/${RESOURCE_PREFIX}-aks-nsg"

echo ""
echo "3. Importing Monitoring Resources..."
import_if_exists \
  "azurerm_log_analytics_workspace" \
  "azurerm_log_analytics_workspace.mlops" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.OperationalInsights/workspaces/${RESOURCE_PREFIX}-law"

import_if_exists \
  "azurerm_application_insights" \
  "azurerm_application_insights.mlops" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Insights/components/${RESOURCE_PREFIX}-ai"

import_if_exists \
  "azurerm_monitor_action_group" \
  "azurerm_monitor_action_group.mlops_alerts" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Insights/actionGroups/${RESOURCE_PREFIX}-action-group"

echo ""
echo "4. Importing Identity Resources..."
import_if_exists \
  "azurerm_user_assigned_identity" \
  "azurerm_user_assigned_identity.ml_workspace" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${RESOURCE_PREFIX}-ml-identity"

echo ""
echo "5. Importing Front Door & Traffic Manager..."
import_if_exists \
  "azurerm_cdn_frontdoor_profile" \
  "azurerm_cdn_frontdoor_profile.mlops" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Cdn/profiles/${RESOURCE_PREFIX}-fd"

import_if_exists \
  "azurerm_traffic_manager_profile" \
  "azurerm_traffic_manager_profile.mlops" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Network/trafficManagerProfiles/${RESOURCE_PREFIX}-tm"

echo ""
echo "6. Importing DevOps Integration Resources..."
import_if_exists \
  "azurerm_data_factory" \
  "azurerm_data_factory.devops_analytics[0]" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.DataFactory/factories/${RESOURCE_PREFIX}-df-devops"

import_if_exists \
  "azurerm_eventgrid_topic" \
  "azurerm_eventgrid_topic.mlops_events[0]" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.EventGrid/topics/${RESOURCE_PREFIX}-events"

import_if_exists \
  "azurerm_stream_analytics_job" \
  "azurerm_stream_analytics_job.model_performance[0]" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.StreamAnalytics/streamingJobs/${RESOURCE_PREFIX}-stream-analytics"

echo ""
echo "7. Importing Cost Management Resources..."
import_if_exists \
  "azurerm_data_factory" \
  "azurerm_data_factory.cost_analytics[0]" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.DataFactory/factories/${RESOURCE_PREFIX}-df-cost"

import_if_exists \
  "azurerm_automation_account" \
  "azurerm_automation_account.cost_optimization[0]" \
  "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Automation/automationAccounts/${RESOURCE_PREFIX}-automation"

echo ""
echo "=========================================="
echo "Import process completed!"
echo "=========================================="
echo ""
echo "Note: Function App quota error cannot be resolved by import."
echo "Recommendation: Disable DevOps integration or request App Service quota increase."
