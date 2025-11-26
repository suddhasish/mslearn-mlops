#!/usr/bin/env python3
"""
Setup Azure ML Data Drift Monitor (Azure ML SDK v2 / CLI v2 compatible)
Creates data drift monitoring using Azure ML CLI v2 and model monitoring features
"""

import argparse
import logging
import json
import subprocess
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def run_command(command: list, check=True) -> tuple:
    """Run shell command and return output"""
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=check
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout, e.stderr


def setup_drift_monitor(
    subscription_id: str,
    resource_group: str,
    workspace_name: str,
    baseline_dataset_name: str = 'diabetes-baseline',
    target_dataset_name: str = 'diabetes-production',
    compute_target: str = 'cpu-cluster',
    drift_threshold: float = 0.3,
    alert_email: str = None
):
    """
    Setup Azure ML Data Drift Monitor using CLI v2
    
    Note: Azure ML SDK v2 doesn't have built-in DataDriftDetector like v1.
    This creates a monitoring schedule using Azure ML CLI v2 and model monitoring.
    
    Args:
        subscription_id: Azure subscription ID
        resource_group: Resource group name
        workspace_name: Azure ML workspace name
        baseline_dataset_name: Name of registered baseline dataset
        target_dataset_name: Name of registered production dataset
        compute_target: Compute cluster for drift detection
        drift_threshold: Drift magnitude threshold (0.0-1.0)
        alert_email: Email for drift alerts (configured via Azure Monitor)
    """
    
    logger.info("=" * 60)
    logger.info("Azure ML Drift Monitor Setup (CLI v2)")
    logger.info("=" * 60)
    
    # Set Azure subscription
    logger.info(f"\nSetting subscription: {subscription_id}")
    returncode, stdout, stderr = run_command([
        'az', 'account', 'set',
        '--subscription', subscription_id
    ])
    
    if returncode != 0:
        logger.error(f"Failed to set subscription: {stderr}")
        return False
    
    logger.info("✅ Subscription set")
    
    # Check if baseline dataset exists
    logger.info(f"\nChecking baseline dataset: {baseline_dataset_name}")
    returncode, stdout, stderr = run_command([
        'az', 'ml', 'data', 'show',
        '--name', baseline_dataset_name,
        '--workspace-name', workspace_name,
        '--resource-group', resource_group
    ], check=False)
    
    if returncode != 0:
        logger.error(f"❌ Baseline dataset not found")
        logger.info(f"\nPlease register baseline dataset first:")
        logger.info(f"  bash scripts/register_baseline_dataset.sh")
        return False
    
    logger.info("✅ Baseline dataset found")
    
    # Check if target dataset exists (optional)
    logger.info(f"\nChecking target dataset: {target_dataset_name}")
    returncode, stdout, stderr = run_command([
        'az', 'ml', 'data', 'show',
        '--name', target_dataset_name,
        '--workspace-name', workspace_name,
        '--resource-group', resource_group
    ], check=False)
    
    if returncode != 0:
        logger.warning(f"⚠️ Target dataset not found - will be created from production data")
    else:
        logger.info("✅ Target dataset found")
    
    # Create drift monitoring schedule YAML
    monitor_config = {
        "$schema": "https://azuremlschemas.azureedge.net/latest/schedule.schema.json",
        "name": "diabetes-drift-monitor-schedule",
        "display_name": "Diabetes Model Drift Monitoring",
        "description": "Weekly drift detection for diabetes prediction model",
        "trigger": {
            "type": "recurrence",
            "frequency": "week",
            "interval": 1,
            "schedule": {
                "week_days": ["sunday"],
                "hours": [0],
                "minutes": [0]
            }
        },
        "create_job": {
            "type": "command",
            "code": "./scripts",
            "command": f"python detect_drift.py --baseline {baseline_dataset_name} --production {target_dataset_name} --output drift_report.json --threshold {drift_threshold}",
            "environment": "azureml:AzureML-sklearn-1.0-ubuntu20.04-py38-cpu:1",
            "compute": compute_target,
            "inputs": {
                "baseline_data": {
                    "type": "uri_file",
                    "path": f"azureml:{baseline_dataset_name}:1"
                }
            }
        }
    }
    
    # Save schedule YAML
    schedule_file = Path("/tmp/drift_monitor_schedule.yml")
    logger.info(f"\nCreating monitoring schedule configuration...")
    with open(schedule_file, 'w') as f:
        import yaml
        yaml.dump(monitor_config, f, default_flow_style=False)
    
    logger.info(f"✅ Schedule configuration created: {schedule_file}")
    
    # Note about Azure ML v2 approach
    logger.info("\n" + "=" * 60)
    logger.info("IMPORTANT: Azure ML SDK v2 Approach")
    logger.info("=" * 60)
    logger.info("""
Azure ML SDK v2 doesn't have DataDriftDetector like v1.
Instead, use one of these approaches:

1. **GitHub Actions Workflow (Recommended)**
   - Already created: .github/workflows/drift-detection.yml
   - Runs weekly, fully automated
   - No Azure ML compute costs during idle time
   
2. **Azure ML Schedule (Manual Setup)**
   - Create schedule YAML (generated above)
   - Deploy with: az ml schedule create -f <yaml_file>
   - Runs on Azure ML compute
   
3. **Model Monitoring (For deployed models)**
   - Use Azure ML's model monitoring feature
   - Requires model deployment to managed endpoint
   - Built-in drift detection dashboard

**RECOMMENDED ACTION:**
Use the GitHub Actions workflow which is already configured
and doesn't require Azure ML v1 SDK dependencies.
""")
    
    # Print configuration summary
    logger.info("\n" + "=" * 60)
    logger.info("CONFIGURATION SUMMARY")
    logger.info("=" * 60)
    logger.info(f"Workspace: {workspace_name}")
    logger.info(f"Resource Group: {resource_group}")
    logger.info(f"Baseline Dataset: {baseline_dataset_name}")
    logger.info(f"Target Dataset: {target_dataset_name}")
    logger.info(f"Drift Threshold: {drift_threshold}")
    logger.info(f"Compute Target: {compute_target}")
    if alert_email:
        logger.info(f"Alert Email: {alert_email} (configure via Azure Monitor)")
    logger.info("=" * 60)
    
    logger.info("\n✅ Configuration complete!")
    logger.info("\nNext steps:")
    logger.info("1. Use GitHub Actions workflow (recommended):")
    logger.info("   gh workflow run drift-detection.yml -f environment=dev")
    logger.info("")
    logger.info("2. OR create Azure ML schedule:")
    logger.info(f"   az ml schedule create -f {schedule_file} \\")
    logger.info(f"     --workspace-name {workspace_name} \\")
    logger.info(f"     --resource-group {resource_group}")
    logger.info("")
    logger.info("3. Enable production data logging:")
    logger.info("   kubectl set env deployment/ml-inference ENABLE_DRIFT_LOGGING=true")
    logger.info("")
    logger.info("4. Configure alerts in Azure Monitor for drift events")
    
    return True


def main():
    parser = argparse.ArgumentParser(
        description='Setup Azure ML Data Drift Monitor (CLI v2 compatible)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Setup drift monitoring configuration
  python setup_drift_monitor.py \\
    --subscription-id b2b8a5e6-9a34-494b-ba62-fe9be95bd398 \\
    --resource-group mlopsnew-dev-rg \\
    --workspace mlopsnew-dev-mlw \\
    --baseline-dataset diabetes-baseline \\
    --alert-email ml-team@company.com

Note: This script is compatible with Azure ML CLI v2.
For automated drift detection, use the GitHub Actions workflow:
  gh workflow run drift-detection.yml -f environment=dev
        """
    )
    parser.add_argument('--subscription-id', required=True, help='Azure subscription ID')
    parser.add_argument('--resource-group', required=True, help='Resource group name')
    parser.add_argument('--workspace', required=True, help='Azure ML workspace name')
    parser.add_argument('--baseline-dataset', default='diabetes-baseline', help='Baseline dataset name')
    parser.add_argument('--target-dataset', default='diabetes-production', help='Target dataset name')
    parser.add_argument('--compute-target', default='cpu-cluster', help='Compute cluster name')
    parser.add_argument('--drift-threshold', type=float, default=0.3, help='Drift threshold (0.0-1.0)')
    parser.add_argument('--alert-email', help='Email for drift alerts (configured via Azure Monitor)')
    
    args = parser.parse_args()
    
    success = setup_drift_monitor(
        subscription_id=args.subscription_id,
        resource_group=args.resource_group,
        workspace_name=args.workspace,
        baseline_dataset_name=args.baseline_dataset,
        target_dataset_name=args.target_dataset,
        compute_target=args.compute_target,
        drift_threshold=args.drift_threshold,
        alert_email=args.alert_email
    )
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
