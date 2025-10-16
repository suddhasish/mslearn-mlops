#!/usr/bin/env python3
"""
Compare new model metrics (metrics.json) with best registered model metric.

Writes 'improved.txt' containing "true" or "false".
Uses AzureCliCredential (works after `az login` in GitHub Actions).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Optional

from azure.ai.ml import MLClient
from azure.identity import AzureCliCredential


def parse_float(value: object) -> Optional[float]:
    """Try to convert value to float; return None on failure."""
    try:
        if value is None:
            return None
        return float(value)
    except Exception:
        return None


def get_best_existing_metric(
    ml_client: MLClient, model_name: str, metric_key: str
) -> Optional[float]:
    """Return the best numeric metric (or None) among registered models."""
    best = None
    try:
        for m in ml_client.models.list():  # type: ignore
            try:
                if getattr(m, "name", None) != model_name:
                    continue
                tags = getattr(m, "tags", {}) or {}
                if metric_key in tags:
                    val = parse_float(tags.get(metric_key))
                    if val is not None and (best is None or val > best):
                        best = val
                        continue
                props = getattr(m, "properties", None) or {}
                if metric_key in props:
                    val = parse_float(props.get(metric_key))
                    if val is not None and (best is None or val > best):
                        best = val
                        continue
            except Exception:
                # Skip entries that cause unexpected parsing errors.
                continue
    except Exception:
        # If listing fails, return None to be conservative.
        return None
    return best


def main() -> int:
    """Command-line entrypoint."""
    parser = argparse.ArgumentParser(description="Compare model metrics.")
    parser.add_argument("--model_dir", required=True, help="Downloaded model folder")
    parser.add_argument("--model_name", required=True, help="Registered model name")
    parser.add_argument(
        "--primary_metric", default="f1", help="Primary metric key to compare"
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
    args = parser.parse_args()

    metrics_path = os.path.join(args.model_dir, "metrics.json")
    if not os.path.exists(metrics_path):
        with open("improved.txt", "w") as fh:
            fh.write("false")
        print("metrics.json not found at:", metrics_path, file=sys.stderr)
        return 2

    with open(metrics_path, "r", encoding="utf8") as fh:
        metrics = json.load(fh)

    new_val = parse_float(
        metrics.get(args.primary_metric)
        or metrics.get("f1")
        or metrics.get("f1_score")
    )

    print("New model metrics:", metrics)
    print("Primary metric (%s) value: %s", args.primary_metric, str(new_val))

    if not (args.subscription_id and args.resource_group and args.workspace):
        print(
            "subscription/resource_group/workspace must be provided",
            file=sys.stderr,
        )
        with open("improved.txt", "w") as fh:
            fh.write("false")
        return 3

    cred = AzureCliCredential()
    ml_client = MLClient(cred, args.subscription_id, args.resource_group, args.workspace)

    existing_best = get_best_existing_metric(ml_client, args.model_name, args.primary_metric)
    print(
        "Existing best %s for model '%s': %s",
        args.primary_metric,
        args.model_name,
        str(existing_best),
    )

    improved = False
    if existing_best is None:
        improved = True
    elif new_val is None:
        improved = False
    else:
        improved = new_val > existing_best

    with open("improved.txt", "w", encoding="utf8") as fh:
        fh.write("true" if improved else "false")

    print("IMPROVED:", improved)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
