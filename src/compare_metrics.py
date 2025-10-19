# File: src/compare_metrics.py
# Compare new model metrics (metrics.json) with best registered model metric.
# Writes 'improved.txt' containing "true" or "false".
from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Optional

from azure.ai.ml import MLClient
from azure.identity import AzureCliCredential


def parse_float(value) -> Optional[float]:
    """Safely convert strings or JSON-like values to float."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        s = value.strip().strip('"').strip("'")
        try:
            return float(s)
        except ValueError:
            # handle JSON-like values e.g. '{"f1": "0.83"}'
            import json
            try:
                parsed = json.loads(s)
                if isinstance(parsed, (int, float)):
                    return float(parsed)
                if isinstance(parsed, dict):
                    # if tag is like {"f1": "0.83"}
                    for v in parsed.values():
                        try:
                            return float(v)
                        except Exception:
                            continue
            except Exception:
                return None
    return None


def get_best_existing_metric(
    ml_client: MLClient, model_name: str, metric_key: str
) -> Optional[float]:
    """Return the best numeric metric (or None) among registered models."""
    best = None
    try:
        for m in ml_client.models.list():  # type: ignore
            try:
                # Ensure we only check the correct 
                #model name (case-insensitive)
                if str(getattr(m, "name", "")).lower() != model_name.lower():
                    continue

                tags = getattr(m, "tags", {}) or {}
                raw_val = tags.get(metric_key)

                # Debug (optional)
                print(
                    "DEBUG: model=%s, version=%s, %s=%s"
                    % (
                        m.name,
                        getattr(m, "version", "NA"),
                        metric_key,
                        raw_val,
                    )
                )

                val = parse_float(raw_val)
                if val is not None and (best is None or val > best):
                    best = val
                    continue

                # fallback to model properties (rarely used)
                props = getattr(m, "properties", {}) or {}
                raw_val = props.get(metric_key)
                val = parse_float(raw_val)
                if val is not None and (best is None or val > best):
                    best = val
            except Exception:
                continue
    except Exception as e:
        print(f"Warning: failed to list or parse models: {e}")
        return None

    print(f"Best existing {metric_key}: {best}")
    return best


def main() -> int:
    """Command-line entrypoint."""
    parser = argparse.ArgumentParser(description="Compare model metrics.")
    parser.add_argument(
        "--model_dir", required=True, help="Downloaded model folder"
    )
    parser.add_argument(
        "--model_name", required=True, help="Registered model name"
    )
    parser.add_argument(
        "--primary_metric",
        default="f1",
        help="Primary metric key to compare",
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
    print(
        "Primary metric (%s) value: %s"
        % (args.primary_metric, str(new_val))
    )

    if not (
        args.subscription_id and args.resource_group and args.workspace
    ):
        print(
            "subscription/resource_group/workspace must be provided",
            file=sys.stderr,
        )
        with open("improved.txt", "w") as fh:
            fh.write("false")
        return 3

    cred = AzureCliCredential()
    ml_client = MLClient(
        cred, args.subscription_id, args.resource_group, args.workspace
    )

    existing_best = get_best_existing_metric(
        ml_client, args.model_name, args.primary_metric
    )
    print(
        "Existing best %s for model '%s': %s"
        % (args.primary_metric, args.model_name, str(existing_best))
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
