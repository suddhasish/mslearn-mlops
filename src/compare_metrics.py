#!/usr/bin/env python3
"""
Compare new model metrics (metrics.json) with the best registered model
metric in Azure ML model registry. Writes 'improved.txt' containing
"true" or "false".

Exit codes:
  0 - success (improved.txt written)
  2 - metrics.json not found
  3 - missing Azure workspace identifiers
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any, Optional

from azure.ai.ml import MLClient
from azure.identity import AzureCliCredential, DefaultAzureCredential


def parse_float(value: Any) -> Optional[float]:
    """Try to convert value or JSON-like string into float."""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        s = value.strip().strip('"').strip("'")
        try:
            return float(s)
        except ValueError:
            pass
        try:
            parsed = json.loads(s)
        except Exception:
            parsed = None
        if isinstance(parsed, (int, float)):
            return float(parsed)
        if isinstance(parsed, dict):
            for v in parsed.values():
                try:
                    return float(v)
                except Exception:
                    continue
    return None


def _normalize_tags(raw_tags: Any) -> dict:
    """Return dict of normalized tag keys -> string values."""
    out: dict = {}
    if not raw_tags:
        return out
    if isinstance(raw_tags, dict):
        for k, v in raw_tags.items():
            if k is None:
                continue
            key_norm = str(k).strip().lower()
            val_norm = None if v is None else str(v).strip()
            val_norm = val_norm.strip('"').strip("'") if val_norm else val_norm
            out[key_norm] = val_norm
        return out
    try:
        txt = str(raw_tags)
        parsed = json.loads(txt)
        if isinstance(parsed, dict):
            for k, v in parsed.items():
                if k is None:
                    continue
                key = str(k).strip().lower()
                out[key] = None if v is None else str(v).strip()
            return out
    except Exception:
        pass
    out["value"] = str(raw_tags)
    return out


def _normalize_props(raw_props: Any) -> dict:
    """Normalize properties dict keys to lowercase strings."""
    out: dict = {}
    if not raw_props or not isinstance(raw_props, dict):
        return out
    for k, v in raw_props.items():
        try:
            key_norm = str(k).strip().lower()
        except Exception:
            key_norm = str(k)
        out[key_norm] = v
    return out


def get_best_existing_metric(
    ml_client: MLClient,
    model_name: str,
    metric_key: str,
) -> Optional[float]:
    """Return best numeric metric among registered models (or None)."""
    best: Optional[float] = None

    # Try to call list() with a name filter if supported by SDK.
    try:
        candidates = ml_client.models.list(name=model_name)  # type: ignore
    except TypeError:
        # Older SDK signatures may not accept 'name' arg; fall back to listing all.
        candidates = ml_client.models.list()  # type: ignore

    try:
        for m in candidates:
            try:
                # Each item from list() may be lightweight. Try to get name/version.
                m_name = getattr(m, "name", None)
                m_version = getattr(m, "version", None)

                if not m_name:
                    # Skip entries without names
                    continue

                # If model name doesn't match exactly, skip.
                if str(m_name).strip().lower() != model_name.strip().lower():
                    continue

                # Fetch the full model resource (tags often available only there).
                full = None
                try:
                    if m_version:
                        full = ml_client.models.get(name=m_name, version=m_version)
                    else:
                        # If version missing, try to get latest by name (may raise)
                        full = ml_client.models.get(name=m_name)
                except Exception:
                    # If get fails, continue using the lightweight 'm' object.
                    full = m

                # Inspect tags / properties (prefer tags on full resource).
                raw_tags = getattr(full, "tags", None)
                raw_props = getattr(full, "properties", None)

                # Debug — will show in CI logs; remove once verified.
                print(
                    "DEBUG: model=%s, version=%s, tags=%s, props=%s"
                    % (str(m_name), str(m_version), str(raw_tags), str(raw_props))
                )

                # Normalize tags (keys lowercased, stripped)
                normalized = {}
                if isinstance(raw_tags, dict):
                    for k, v in raw_tags.items():
                        if k is None:
                            continue
                        nk = str(k).strip().lower()
                        nv = None if v is None else str(v).strip().strip('"').strip("'")
                        normalized[nk] = nv

                lookup = metric_key.strip().lower()
                raw_val = normalized.get(lookup)
                if raw_val is None:
                    for alt in (lookup, lookup.replace("-", "_"), "f1", "f1_score"):
                        raw_val = normalized.get(alt)
                        if raw_val is not None:
                            break

                val = parse_float(raw_val)
                if val is not None and (best is None or val > best):
                    best = val
                    # keep checking other versions
                    continue

                # Fallback to properties if present
                pnorm = {}
                if isinstance(raw_props, dict):
                    for k, v in raw_props.items():
                        try:
                            k_norm = str(k).strip().lower()
                        except Exception:
                            k_norm = str(k)
                        pnorm[k_norm] = v

                p_raw = pnorm.get(lookup)
                if p_raw is None:
                    for alt in ("f1", "f1_score"):
                        p_raw = pnorm.get(alt)
                        if p_raw is not None:
                            break
                val = parse_float(p_raw)
                if val is not None and (best is None or val > best):
                    best = val
            except Exception:
                # Skip single model errors; continue scanning others.
                continue
    except Exception as exc:
        print("Warning: failed to list or parse models:", exc)
        return None

    print("DEBUG: Best existing %s: %s" % (metric_key, str(best)))
    return best


def find_metrics_file(model_dir: str) -> Optional[str]:
    """Search common locations for metrics.json."""
    candidates = [
        os.path.join(model_dir, "metrics.json"),
        os.path.join(model_dir, "named-outputs", "model", "metrics.json"),
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare model metrics.")
    parser.add_argument("--model_dir", required=True)
    parser.add_argument("--model_name", required=True)
    parser.add_argument("--primary_metric", default="f1")
    parser.add_argument(
        "--subscription_id",
        default=os.environ.get("AZURE_SUBSCRIPTION_ID"),
    )
    parser.add_argument(
        "--resource_group",
        default=os.environ.get("AZURE_ML_RESOURCE_GROUP"),
    )
    parser.add_argument(
        "--workspace",
        default=os.environ.get("AZURE_ML_WORKSPACE_NAME"),
    )
    args = parser.parse_args()

    metrics_file = find_metrics_file(args.model_dir)
    if not metrics_file:
        with open("improved.txt", "w", encoding="utf8") as fh:
            fh.write("false")
        print("metrics.json not found in expected locations.", file=sys.stderr)
        return 2

    with open(metrics_file, "r", encoding="utf8") as fh:
        metrics = json.load(fh)

    new_val = parse_float(
        metrics.get(args.primary_metric)
        or metrics.get("f1")
        or metrics.get("f1_score")
    )

    print("New model metrics:", metrics)
    print(
        "Primary metric (%s) value: %s"
        % (
            args.primary_metric,
            str(new_val),
        )
    )

    if not (args.subscription_id and args.resource_group and args.workspace):
        print(
            "subscription/resource_group/workspace must be provided",
            file=sys.stderr,
        )
        with open("improved.txt", "w", encoding="utf8") as fh:
            fh.write("false")
        return 3

    try:
        cred = AzureCliCredential()
    except Exception:
        cred = DefaultAzureCredential()

    ml_client = MLClient(
        cred,
        args.subscription_id,
        args.resource_group,
        args.workspace,
    )

    existing_best = get_best_existing_metric(
        ml_client,
        args.model_name,
        args.primary_metric,
    )
    print(
        "Existing best %s for model '%s': %s"
        % (
            args.primary_metric,
            args.model_name,
            str(existing_best),
        )
    )

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
