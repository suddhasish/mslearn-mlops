# File: src/register_local.py
# Register a local model directory with Azure ML Model Registry.
# Auth: uses AzureCliCredential (after `az login`).
from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Optional

from azure.ai.ml import MLClient
from azure.ai.ml.entities import Model
from azure.identity import AzureCliCredential


def parse_float(value: object) -> Optional[float]:
    """Safely parse a float from an object."""
    try:
        if value is None:
            return None
        return float(value)
    except Exception:
        return None


def load_metrics(metrics_path: str) -> dict:
    """Load metrics.json if present, otherwise return empty dict."""
    if not os.path.exists(metrics_path):
        return {}
    with open(metrics_path, "r", encoding="utf8") as fh:
        return json.load(fh)


def main() -> int:
    """Command-line entrypoint for register_local."""
    parser = argparse.ArgumentParser(
        description="Register local model directory."
    )
    parser.add_argument(
        "--model_dir",
        required=True,
        help="Local folder containing model files",
    )
    parser.add_argument(
        "--model_name",
        required=True,
        help="Model registry name",
    )
    parser.add_argument(
        "--primary_metric",
        default="f1",
        help="Primary metric key",
    )
    parser.add_argument(
        "--subscription_id",
        default=os.environ.get("AZURE_SUBSCRIPTION_ID"),
        help="Azure subscription id",
    )
    parser.add_argument(
        "--resource_group",
        default=os.environ.get("AZURE_ML_RESOURCE_GROUP"),
        help="Azure ML resource group",
    )
    parser.add_argument(
        "--workspace",
        default=os.environ.get("AZURE_ML_WORKSPACE_NAME"),
        help="Azure ML workspace name",
    )
    parser.add_argument(
        "--force", 
        action="store_true", 
        help="Force registration"
    )
    args = parser.parse_args()

    if not os.path.isdir(args.model_dir):
        print("model_dir not found: %s" % args.model_dir, file=sys.stderr)
        return 2

    metrics = load_metrics(os.path.join(args.model_dir, "metrics.json"))
    tag_metrics = {k: str(v) for k, v in metrics.items() if v is not None}

    mlfpath = os.path.join(args.model_dir, "mlflow_run_id.txt")
    if os.path.exists(mlfpath):
        try:
            tag_metrics["mlflow_run_id"] = (
                open(mlfpath, "r", encoding="utf8").read().strip()
            )
        except Exception:
            # non-fatal: skip mlflow id if reading fails
            pass

    if not (
        args.subscription_id and args.resource_group and args.workspace
    ):
        print("subscription/resource_group/workspace missing", file=sys.stderr)
        return 3

    cred = AzureCliCredential()
    ml_client = MLClient(
        cred, args.subscription_id, args.resource_group, args.workspace
    )

    model_asset = Model(
        name=args.model_name,
        path=args.model_dir,
        type="custom_model",
        description=(
            "Registered from CI (primary_metric=" + args.primary_metric + ")"
        ),
        tags=tag_metrics,
    )

    try:
        created = ml_client.models.create_or_update(model_asset)
    except Exception as exc:
        print("Model registration failed: %s" % str(exc), file=sys.stderr)
        return 4

    print("Model registered: %s" % getattr(created, "name", created))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
