#!/usr/bin/env python3
"""
Data Drift Detection Script
Compares production inference data against baseline (training) data
Uses statistical tests: KS test, PSI, Chi-Square
"""

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import Dict, Any, Tuple

import numpy as np
import pandas as pd
from scipy import stats

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def load_data(data_path: str) -> pd.DataFrame:
    """Load data from CSV file or directory of CSV files"""
    path = Path(data_path)
    
    if path.is_file():
        logger.info(f"Loading data from file: {path}")
        return pd.read_csv(path)
    elif path.is_dir():
        logger.info(f"Loading data from directory: {path}")
        csv_files = list(path.glob("*.csv"))
        if not csv_files:
            raise ValueError(f"No CSV files found in {path}")
        
        dfs = []
        for csv_file in csv_files:
            df = pd.read_csv(csv_file)
            dfs.append(df)
        
        combined_df = pd.concat(dfs, ignore_index=True)
        logger.info(f"Loaded {len(dfs)} files with {len(combined_df)} total rows")
        return combined_df
    else:
        raise ValueError(f"Invalid path: {data_path}")


def detect_drift_ks_test(
    baseline_data: pd.DataFrame,
    production_data: pd.DataFrame,
    continuous_features: list,
    threshold: float = 0.05
) -> Dict[str, Dict[str, Any]]:
    """
    Detect drift using Kolmogorov-Smirnov test for continuous features
    
    Args:
        baseline_data: Reference dataset (training data)
        production_data: Current production data
        continuous_features: List of continuous feature names
        threshold: P-value threshold (default: 0.05)
    
    Returns:
        Dictionary with drift results per feature
    """
    results = {}
    
    for feature in continuous_features:
        if feature not in baseline_data.columns or feature not in production_data.columns:
            logger.warning(f"Feature {feature} not found in both datasets, skipping")
            continue
        
        baseline_values = baseline_data[feature].dropna()
        production_values = production_data[feature].dropna()
        
        if len(baseline_values) == 0 or len(production_values) == 0:
            logger.warning(f"Feature {feature} has no valid values, skipping")
            continue
        
        # Kolmogorov-Smirnov test
        ks_stat, p_value = stats.ks_2samp(baseline_values, production_values)
        
        drift_detected = p_value < threshold
        
        baseline_mean = float(baseline_values.mean())
        production_mean = float(production_values.mean())
        
        mean_shift_percent = 0.0
        if baseline_mean != 0:
            mean_shift_percent = ((production_mean - baseline_mean) / baseline_mean) * 100
        
        results[feature] = {
            'test': 'KS-test',
            'drift_detected': drift_detected,
            'p_value': float(p_value),
            'ks_statistic': float(ks_stat),
            'baseline_mean': baseline_mean,
            'production_mean': production_mean,
            'mean_shift_percent': mean_shift_percent,
            'baseline_std': float(baseline_values.std()),
            'production_std': float(production_values.std()),
            'baseline_samples': len(baseline_values),
            'production_samples': len(production_values)
        }
        
        logger.info(
            f"{feature}: KS={ks_stat:.4f}, p-value={p_value:.4f}, "
            f"mean_shift={mean_shift_percent:.2f}%, drift={drift_detected}"
        )
    
    return results


def calculate_psi(
    baseline_data: pd.DataFrame,
    production_data: pd.DataFrame,
    feature: str,
    bins: int = 10
) -> float:
    """
    Calculate Population Stability Index (PSI) for a feature
    
    PSI < 0.1: No significant drift
    PSI 0.1-0.25: Moderate drift
    PSI > 0.25: Significant drift - retraining recommended
    
    Args:
        baseline_data: Reference dataset
        production_data: Current production data
        feature: Feature name
        bins: Number of bins for histogram
    
    Returns:
        PSI value
    """
    baseline_values = baseline_data[feature].dropna()
    production_values = production_data[feature].dropna()
    
    # Create bins based on baseline distribution
    baseline_counts, bin_edges = np.histogram(baseline_values, bins=bins)
    production_counts, _ = np.histogram(production_values, bins=bin_edges)
    
    # Normalize to percentages (add small epsilon to avoid log(0))
    epsilon = 1e-10
    baseline_pct = (baseline_counts / len(baseline_values)) + epsilon
    production_pct = (production_counts / len(production_values)) + epsilon
    
    # Calculate PSI
    psi = np.sum((production_pct - baseline_pct) * np.log(production_pct / baseline_pct))
    
    return float(psi)


def detect_drift_psi(
    baseline_data: pd.DataFrame,
    production_data: pd.DataFrame,
    features: list,
    bins: int = 10
) -> Dict[str, Dict[str, Any]]:
    """
    Detect drift using Population Stability Index (PSI)
    
    Args:
        baseline_data: Reference dataset
        production_data: Current production data
        features: List of feature names
        bins: Number of bins for histogram
    
    Returns:
        Dictionary with PSI results per feature
    """
    results = {}
    
    for feature in features:
        if feature not in baseline_data.columns or feature not in production_data.columns:
            continue
        
        try:
            psi = calculate_psi(baseline_data, production_data, feature, bins)
            
            # PSI thresholds
            if psi < 0.1:
                drift_level = "no_drift"
            elif psi < 0.25:
                drift_level = "moderate_drift"
            else:
                drift_level = "significant_drift"
            
            results[feature] = {
                'test': 'PSI',
                'psi_value': psi,
                'drift_level': drift_level,
                'drift_detected': psi > 0.25
            }
            
            logger.info(f"{feature}: PSI={psi:.4f}, level={drift_level}")
        
        except Exception as e:
            logger.error(f"Error calculating PSI for {feature}: {e}")
            continue
    
    return results


def should_retrain(
    ks_results: Dict[str, Dict[str, Any]],
    psi_results: Dict[str, Dict[str, Any]],
    min_drifted_features: int = 3,
    high_drift_threshold: float = 15.0
) -> Tuple[bool, str]:
    """
    Decision logic for triggering retraining
    
    Retrain if:
    - 3+ features show significant drift (p-value < 0.05 AND |mean_shift| > 15%)
    - OR any feature has PSI > 0.25 (significant drift)
    
    Args:
        ks_results: Results from KS test
        psi_results: Results from PSI test
        min_drifted_features: Minimum number of features with high drift
        high_drift_threshold: Percentage threshold for high drift
    
    Returns:
        (should_retrain, reason)
    """
    # Count features with significant drift
    high_drift_features = [
        feature for feature, info in ks_results.items()
        if info['drift_detected'] and abs(info['mean_shift_percent']) > high_drift_threshold
    ]
    
    # Check PSI significant drift
    psi_significant = [
        feature for feature, info in psi_results.items()
        if info['drift_detected']
    ]
    
    if len(high_drift_features) >= min_drifted_features:
        reason = (
            f"High drift detected in {len(high_drift_features)} features: "
            f"{', '.join(high_drift_features)}"
        )
        return True, reason
    
    if len(psi_significant) > 0:
        reason = (
            f"Significant PSI drift in {len(psi_significant)} features: "
            f"{', '.join(psi_significant)}"
        )
        return True, reason
    
    return False, "No significant drift detected"


def generate_drift_report(
    ks_results: Dict[str, Dict[str, Any]],
    psi_results: Dict[str, Dict[str, Any]],
    should_retrain_flag: bool,
    retrain_reason: str,
    baseline_samples: int,
    production_samples: int
) -> Dict[str, Any]:
    """Generate comprehensive drift detection report"""
    
    # Summary statistics
    total_features = len(ks_results)
    drifted_features = sum(1 for r in ks_results.values() if r['drift_detected'])
    
    report = {
        'timestamp': pd.Timestamp.now().isoformat(),
        'summary': {
            'total_features_analyzed': total_features,
            'features_with_drift': drifted_features,
            'drift_percentage': (drifted_features / total_features * 100) if total_features > 0 else 0,
            'should_retrain': should_retrain_flag,
            'retrain_reason': retrain_reason,
            'baseline_samples': baseline_samples,
            'production_samples': production_samples
        },
        'ks_test_results': ks_results,
        'psi_results': psi_results,
        'recommendations': []
    }
    
    # Add recommendations
    if should_retrain_flag:
        report['recommendations'].append("🚨 RETRAIN MODEL - Significant drift detected")
    else:
        report['recommendations'].append("✅ No retraining needed - Model is stable")
    
    if drifted_features > 0:
        report['recommendations'].append(
            f"📊 Monitor {drifted_features} features showing drift"
        )
    
    return report


def main():
    parser = argparse.ArgumentParser(description='Detect data drift between baseline and production data')
    parser.add_argument('--baseline', required=True, help='Path to baseline data (training data)')
    parser.add_argument('--production', required=True, help='Path to production data')
    parser.add_argument('--output', default='drift_report.json', help='Output JSON report file')
    parser.add_argument('--features', nargs='+', help='Specific features to analyze (default: all numeric)')
    parser.add_argument('--threshold', type=float, default=0.05, help='P-value threshold for KS test')
    parser.add_argument('--bins', type=int, default=10, help='Number of bins for PSI calculation')
    
    args = parser.parse_args()
    
    logger.info("=" * 60)
    logger.info("DATA DRIFT DETECTION")
    logger.info("=" * 60)
    
    # Load data
    try:
        baseline_df = load_data(args.baseline)
        production_df = load_data(args.production)
    except Exception as e:
        logger.error(f"Error loading data: {e}")
        sys.exit(1)
    
    logger.info(f"Baseline data: {len(baseline_df)} samples")
    logger.info(f"Production data: {len(production_df)} samples")
    
    # Determine features to analyze
    if args.features:
        features = args.features
    else:
        # Use all numeric columns (common to both datasets)
        baseline_numeric = set(baseline_df.select_dtypes(include=[np.number]).columns)
        production_numeric = set(production_df.select_dtypes(include=[np.number]).columns)
        features = list(baseline_numeric.intersection(production_numeric))
        
        # Exclude timestamp/ID columns
        features = [f for f in features if not f.lower() in ['id', 'timestamp', 'index']]
    
    logger.info(f"Analyzing {len(features)} features: {features}")
    
    # Run KS test for continuous features
    logger.info("\n" + "=" * 60)
    logger.info("KOLMOGOROV-SMIRNOV TEST")
    logger.info("=" * 60)
    ks_results = detect_drift_ks_test(baseline_df, production_df, features, args.threshold)
    
    # Run PSI test
    logger.info("\n" + "=" * 60)
    logger.info("POPULATION STABILITY INDEX (PSI)")
    logger.info("=" * 60)
    psi_results = detect_drift_psi(baseline_df, production_df, features, args.bins)
    
    # Determine if retraining is needed
    logger.info("\n" + "=" * 60)
    logger.info("RETRAINING DECISION")
    logger.info("=" * 60)
    should_retrain_flag, retrain_reason = should_retrain(ks_results, psi_results)
    logger.info(f"Should Retrain: {should_retrain_flag}")
    logger.info(f"Reason: {retrain_reason}")
    
    # Generate report
    report = generate_drift_report(
        ks_results,
        psi_results,
        should_retrain_flag,
        retrain_reason,
        len(baseline_df),
        len(production_df)
    )
    
    # Save report
    output_path = Path(args.output)
    with open(output_path, 'w') as f:
        json.dump(report, f, indent=2)
    
    logger.info(f"\n✅ Drift report saved to: {output_path}")
    
    # Print summary
    logger.info("\n" + "=" * 60)
    logger.info("SUMMARY")
    logger.info("=" * 60)
    logger.info(f"Total Features: {report['summary']['total_features_analyzed']}")
    logger.info(f"Features with Drift: {report['summary']['features_with_drift']}")
    logger.info(f"Drift Percentage: {report['summary']['drift_percentage']:.1f}%")
    logger.info(f"Recommendation: {report['recommendations'][0]}")
    
    # Exit with code 1 if retraining needed (for CI/CD automation)
    if should_retrain_flag:
        logger.warning("⚠️ Retraining recommended!")
        sys.exit(1)
    else:
        logger.info("✅ Model is stable - no retraining needed")
        sys.exit(0)


if __name__ == '__main__':
    main()
