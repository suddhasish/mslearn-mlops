# Data Drift Detection - Process Flow & Mind Map

## 🧠 High-Level Mind Map

```
                                    DATA DRIFT DETECTION SYSTEM
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    │                         │                         │
              ┌─────▼─────┐           ┌──────▼──────┐          ┌───────▼────────┐
              │  DATA     │           │  DETECTION  │          │  AUTOMATION    │
              │ COLLECTION│           │   ENGINE    │          │  & RESPONSE    │
              └─────┬─────┘           └──────┬──────┘          └───────┬────────┘
                    │                        │                         │
        ┌───────────┼───────────┐    ┌──────┼──────┐         ┌────────┼────────┐
        │           │           │    │      │      │         │        │        │
    ┌───▼───┐  ┌───▼───┐  ┌───▼─┐  │  ┌───▼───┐  │    ┌────▼────┐  │   ┌────▼────┐
    │Baseline│  │Prod   │  │Log  │  │  │Tests  │  │    │Retrain  │  │   │Monitor  │
    │Dataset │  │Data   │  │Files│  │  │KS/PSI │  │    │Trigger  │  │   │Metrics  │
    └────────┘  └───────┘  └─────┘  │  └───────┘  │    └─────────┘  │   └─────────┘
                                     │             │                 │
                                ┌────▼────┐   ┌───▼────┐       ┌────▼────┐
                                │Analysis │   │Report  │       │Alerts   │
                                │Logic    │   │Generate│       │Email    │
                                └─────────┘   └────────┘       └─────────┘
```

## 📊 Detailed Process Flow

### Phase 1: Data Collection & Storage

```
START: Production Model Serving
    │
    ├─► Inference Request arrives at /score endpoint
    │   │
    │   ├─► Parse request → Extract features (8 features for diabetes)
    │   │   │
    │   │   └─► Features: [Pregnancies, Glucose, BloodPressure, SkinThickness,
    │                       Insulin, BMI, DiabetesPedigreeFunction, Age]
    │   │
    │   ├─► Model Prediction (score.py:run())
    │   │   │
    │   │   └─► Return prediction to client
    │   │
    │   └─► [IF ENABLE_DRIFT_LOGGING=true]
    │       │
    │       ├─► Call _log_production_data()
    │       │   │
    │       │   ├─► Create DataFrame with feature names
    │       │   ├─► Add timestamp (UTC)
    │       │   ├─► Add request_id
    │       │   ├─► Add prediction result
    │       │   │
    │       │   └─► Append to daily CSV file
    │       │       Path: /tmp/production-inference-data/inference_YYYY-MM-DD.csv
    │       │       Format: Pregnancies,Glucose,...,timestamp,request_id,prediction
    │       │
    │       └─► Continue serving (non-blocking)
    │
    └─► Repeat for each inference request

Daily Files Accumulate:
    /tmp/production-inference-data/
        ├─ inference_2025-11-19.csv  (Monday)
        ├─ inference_2025-11-20.csv  (Tuesday)
        ├─ inference_2025-11-21.csv  (Wednesday)
        ├─ inference_2025-11-22.csv  (Thursday)
        ├─ inference_2025-11-23.csv  (Friday)
        ├─ inference_2025-11-24.csv  (Saturday)
        └─ inference_2025-11-25.csv  (Sunday)
```

### Phase 2: Weekly Drift Detection (GitHub Actions)

```
TRIGGER: Every Sunday at 00:00 UTC (cron: '0 0 * * 0')
    │
    ├─► Job 1: detect-drift
    │   │
    │   ├─► Step 1: Checkout code
    │   │   └─► Clone repository with drift detection scripts
    │   │
    │   ├─► Step 2: Setup Python 3.11
    │   │   └─► Install dependencies: scipy, pandas, numpy
    │   │
    │   ├─► Step 3: Azure Login
    │   │   └─► Authenticate with AZURE_CREDENTIALS secret
    │   │
    │   ├─► Step 4: Download Baseline Data
    │   │   │
    │   │   ├─► Try: az ml data download
    │   │   │   └─► Download diabetes-baseline dataset (training data)
    │   │   │       Source: Azure ML Datastore
    │   │   │       Destination: ./data/baseline/
    │   │   │
    │   │   └─► Fallback: Use local production/data/diabetes-prod.csv
    │   │
    │   ├─► Step 5: Download Production Data (Last 7 Days)
    │   │   │
    │   │   ├─► Calculate date range: [today-7days ... today]
    │   │   │
    │   │   ├─► Try: az storage blob download-batch
    │   │   │   └─► From: production-inference-data container
    │   │   │       Pattern: *.csv
    │   │   │       Destination: ./data/production/
    │   │   │
    │   │   ├─► Fallback: Use sample data for testing
    │   │   │
    │   │   └─► Count files downloaded
    │   │       Example: "📊 Downloaded 7 production data files"
    │   │
    │   ├─► Step 6: Run Drift Detection Script
    │   │   │
    │   │   └─► Execute: python scripts/detect_drift.py
    │   │       │         --baseline ./data/baseline
    │   │       │         --production ./data/production
    │   │       │         --output drift_report.json
    │   │       │         --threshold 0.05
    │   │       │
    │   │       ├─► Load baseline data (DataFrame)
    │   │       ├─► Load production data (DataFrame, concatenate all CSVs)
    │   │       ├─► Identify numeric features to analyze
    │   │       │
    │   │       ├─── RUN STATISTICAL TESTS ───┐
    │   │       │                              │
    │   │       │   ┌────────────────────────────────────────┐
    │   │       │   │ For each feature (8 features):         │
    │   │       │   │                                         │
    │   │       │   │ TEST 1: Kolmogorov-Smirnov Test       │
    │   │       │   │ ─────────────────────────────────      │
    │   │       │   │ • Compare distributions                │
    │   │       │   │ • Baseline: training_data[feature]     │
    │   │       │   │ • Production: prod_data[feature]       │
    │   │       │   │ • Run: ks_stat, p_value =              │
    │   │       │   │        stats.ks_2samp(baseline, prod)  │
    │   │       │   │                                         │
    │   │       │   │ • Calculate mean shift:                │
    │   │       │   │   shift% = (prod_mean - base_mean)     │
    │   │       │   │            / base_mean * 100           │
    │   │       │   │                                         │
    │   │       │   │ • Drift detected if:                   │
    │   │       │   │   p_value < 0.05 (threshold)           │
    │   │       │   │                                         │
    │   │       │   │ Example Result (Glucose):              │
    │   │       │   │   - KS statistic: 0.0823               │
    │   │       │   │   - p-value: 0.001                     │
    │   │       │   │   - mean_shift: +18.5%                 │
    │   │       │   │   - drift_detected: TRUE ✓             │
    │   │       │   │                                         │
    │   │       │   ├──────────────────────────────────────  │
    │   │       │   │                                         │
    │   │       │   │ TEST 2: Population Stability Index    │
    │   │       │   │ ────────────────────────────────────  │
    │   │       │   │ • Bin data into histogram (10 bins)   │
    │   │       │   │ • Baseline distribution → %            │
    │   │       │   │ • Production distribution → %          │
    │   │       │   │                                         │
    │   │       │   │ • Calculate PSI:                       │
    │   │       │   │   PSI = Σ (prod% - base%) *           │
    │   │       │   │         log(prod% / base%)            │
    │   │       │   │                                         │
    │   │       │   │ • Interpretation:                      │
    │   │       │   │   PSI < 0.1:  No drift ✓              │
    │   │       │   │   PSI 0.1-0.25: Moderate drift ⚠      │
    │   │       │   │   PSI > 0.25: SIGNIFICANT DRIFT 🚨    │
    │   │       │   │                                         │
    │   │       │   │ Example Result (Glucose):              │
    │   │       │   │   - PSI: 0.32                          │
    │   │       │   │   - drift_level: significant_drift     │
    │   │       │   │   - drift_detected: TRUE 🚨            │
    │   │       │   │                                         │
    │   │       │   └────────────────────────────────────────┘
    │   │       │
    │   │       ├─── RETRAINING DECISION LOGIC ───┐
    │   │       │                                   │
    │   │       │   Condition 1: High Drift Features
    │   │       │   ─────────────────────────────
    │   │       │   • Count features with:
    │   │       │     - drift_detected = True (p < 0.05)
    │   │       │     - |mean_shift| > 15%
    │   │       │   
    │   │       │   • Example:
    │   │       │     - Glucose: drift=True, shift=+18.5% ✓
    │   │       │     - BMI: drift=True, shift=-16.2% ✓
    │   │       │     - Age: drift=True, shift=+12.1% ✗ (< 15%)
    │   │       │   
    │   │       │   • High drift features: 2
    │   │       │   • Threshold: 3 features
    │   │       │   • Decision: NO (only 2 < 3)
    │   │       │   
    │   │       │   Condition 2: PSI Significant Drift
    │   │       │   ──────────────────────────────────
    │   │       │   • Check any feature with PSI > 0.25
    │   │       │   
    │   │       │   • Example:
    │   │       │     - Glucose: PSI=0.32 (> 0.25) 🚨
    │   │       │   
    │   │       │   • Decision: YES (PSI threshold exceeded)
    │   │       │   
    │   │       │   FINAL DECISION: RETRAIN = TRUE
    │   │       │   Reason: "Significant PSI drift in 1 features: Glucose"
    │   │       │
    │   │       ├─► Generate drift_report.json
    │   │       │   {
    │   │       │     "timestamp": "2025-11-26T00:00:00",
    │   │       │     "summary": {
    │   │       │       "total_features_analyzed": 8,
    │   │       │       "features_with_drift": 2,
    │   │       │       "drift_percentage": 25.0,
    │   │       │       "should_retrain": true,
    │   │       │       "retrain_reason": "Significant PSI drift...",
    │   │       │       "baseline_samples": 768,
    │   │       │       "production_samples": 1543
    │   │       │     },
    │   │       │     "ks_test_results": { ... },
    │   │       │     "psi_results": { ... },
    │   │       │     "recommendations": [...]
    │   │       │   }
    │   │       │
    │   │       ├─► Exit with code:
    │   │       │   • 0: No drift (should_retrain=false)
    │   │       │   • 1: Drift detected (should_retrain=true)
    │   │       │
    │   │       └─► Set output variables:
    │   │           • retrain=true/false
    │   │           • drift_detected=true/false
    │   │
    │   ├─► Step 7: Upload Drift Report Artifact
    │   │   └─► Save drift_report.json for 90 days
    │   │       Available for download from GitHub Actions
    │   │
    │   ├─► Step 8: Parse Drift Report
    │   │   └─► Extract metrics using jq:
    │   │       • total_features
    │   │       • drifted_features
    │   │       • drift_percentage
    │   │       • retrain_reason
    │   │
    │   ├─► Step 9: Create GitHub Summary
    │   │   └─► Add to $GITHUB_STEP_SUMMARY:
    │   │       ┌────────────────────────────────────┐
    │   │       │ 📊 Data Drift Detection Report     │
    │   │       │                                     │
    │   │       │ Environment: dev                   │
    │   │       │ Date: 2025-11-26                   │
    │   │       │                                     │
    │   │       │ Total Features: 8                  │
    │   │       │ Features with Drift: 2             │
    │   │       │ Drift Percentage: 25.0%            │
    │   │       │ Should Retrain: true               │
    │   │       │                                     │
    │   │       │ 🚨 Retraining Recommended          │
    │   │       │ Reason: Significant PSI drift...   │
    │   │       └────────────────────────────────────┘
    │   │
    │   └─► Step 10: Post to Azure Monitor
    │       │
    │       ├─► Get Application Insights Key
    │       │   └─► az monitor app-insights component show
    │       │
    │       └─► POST to Application Insights API
    │           └─► Custom Event: "DataDriftCheck"
    │               Properties:
    │               • environment: "dev"
    │               • total_features: 8
    │               • drifted_features: 2
    │               • drift_percentage: 25.0
    │               • should_retrain: true
    │               • reason: "Significant PSI drift..."
    │
    └─► Job 2: trigger-retraining
        │
        ├─► Condition: needs.detect-drift.outputs.should_retrain == 'true'
        │
        ├─► IF TRUE:
        │   │
        │   ├─► Step 1: Trigger Training Workflow
        │   │   └─► gh workflow run ml-training-integrated.yml
        │   │       --field environment=dev
        │   │       --field triggered_by=drift_detection
        │   │
        │   └─► Step 2: Notify Team
        │       └─► Update GitHub Summary:
        │           "🔄 Model Retraining Triggered"
        │
        └─► IF FALSE:
            └─► Skip retraining (model is stable)
```

## 🔄 Statistical Tests Detailed Breakdown

### Kolmogorov-Smirnov (KS) Test

```
INPUT:
  Baseline: [125, 140, 135, 130, 145, ...] (training Glucose values)
  Production: [160, 155, 165, 150, 170, ...] (recent Glucose values)

PROCESS:
  1. Sort both distributions
  2. Calculate cumulative distribution functions (CDF)
  3. Find maximum distance between CDFs
  4. Calculate p-value (probability of observing this by chance)

  Baseline CDF:     Production CDF:
     1.0 ┤              1.0 ┤        
         │    ╱───          │      ╱───
    0.5  ├  ╱              ├    ╱
         │╱                 │  ╱
     0.0 ┴───────          ┴╱────────
         100  150  200      100  150  200
         
         Maximum distance (D) = 0.0823
         
  5. Statistical test:
     H0: Both distributions are the same
     H1: Distributions are different
     
     If p-value < 0.05 → Reject H0 → Drift detected

OUTPUT:
  {
    "feature": "Glucose",
    "ks_statistic": 0.0823,
    "p_value": 0.001,           ← Significant!
    "drift_detected": true,
    "baseline_mean": 130.5,
    "production_mean": 154.6,
    "mean_shift_percent": +18.5%
  }
```

### Population Stability Index (PSI)

```
INPUT:
  Baseline: [125, 140, 135, 130, 145, ...] 
  Production: [160, 155, 165, 150, 170, ...]

PROCESS:
  1. Create 10 bins based on baseline distribution
  
     Bins: [100-110, 110-120, 120-130, 130-140, 140-150, ...]
  
  2. Calculate percentage in each bin
  
     Baseline:                Production:
     Bin       Count  %        Bin       Count  %
     100-110   5      2.5%     100-110   2      1.0%
     110-120   15     7.5%     110-120   10     5.0%
     120-130   40     20.0%    120-130   30     15.0%
     130-140   50     25.0%    130-140   35     17.5%
     140-150   45     22.5%    140-150   40     20.0%
     150-160   30     15.0%    150-160   50     25.0%  ← Shift!
     160-170   10     5.0%     160-170   25     12.5%  ← Shift!
     170-180   3      1.5%     170-180   6      3.0%
     180-190   1      0.5%     180-190   1      0.5%
     190-200   1      0.5%     190-200   1      0.5%
  
  3. Calculate PSI for each bin
  
     PSI_bin = (prod% - base%) × ln(prod% / base%)
     
     Example (bin 150-160):
       PSI = (25.0 - 15.0) × ln(25.0 / 15.0)
       PSI = 10.0 × 0.511
       PSI = 5.11
  
  4. Sum all bins
  
     Total PSI = Σ PSI_bin = 0.32

  5. Interpret
  
     PSI = 0.32 > 0.25 → SIGNIFICANT DRIFT 🚨

OUTPUT:
  {
    "feature": "Glucose",
    "psi_value": 0.32,
    "drift_level": "significant_drift",
    "drift_detected": true
  }
```

## 🎯 Decision Tree: Should We Retrain?

```
                        START: Drift Detection Complete
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
            ┌───────▼────────┐              ┌──────▼──────┐
            │ Check Condition 1│              │Check Condition 2│
            │   High Drift     │              │  PSI Drift      │
            └───────┬──────────┘              └──────┬──────────┘
                    │                                │
        ┌───────────▼───────────┐        ┌──────────▼──────────┐
        │ Count features with:  │        │Any feature with:    │
        │ • p-value < 0.05     │        │ • PSI > 0.25?       │
        │ • |shift| > 15%      │        │                     │
        └───────────┬───────────┘        └──────────┬──────────┘
                    │                                │
        ┌───────────▼───────────┐        ┌──────────▼──────────┐
        │ Count >= 3 features?  │        │   YES or NO?        │
        └───────────┬───────────┘        └──────────┬──────────┘
                    │                                │
            ┌───────┴───────┐              ┌─────────┴─────────┐
            │               │              │                   │
         ┌──▼──┐        ┌──▼──┐        ┌──▼──┐            ┌──▼──┐
         │ YES │        │ NO  │        │ YES │            │ NO  │
         └──┬──┘        └──┬──┘        └──┬──┘            └──┬──┘
            │              │              │                  │
            │              └──────┬───────┘                  │
            │                     │                          │
            └─────────┬───────────┘                          │
                      │                                      │
              ┌───────▼───────┐                    ┌─────────▼─────────┐
              │  RETRAIN=TRUE │                    │  RETRAIN=FALSE    │
              │               │                    │                   │
              │ Trigger:      │                    │ Action:           │
              │ ml-training-  │                    │ - Log metrics     │
              │ integrated.yml│                    │ - Continue        │
              │               │                    │   monitoring      │
              └───────┬───────┘                    └─────────┬─────────┘
                      │                                      │
              ┌───────▼───────┐                    ┌─────────▼─────────┐
              │Post to Azure  │                    │Post to Azure      │
              │Monitor:       │                    │Monitor:           │
              │should_retrain │                    │should_retrain     │
              │= true 🚨      │                    │= false ✅         │
              └───────────────┘                    └───────────────────┘

EXAMPLES:

Example 1: Retrain due to multiple features
  Glucose:  drift=✓, shift=+18.5%  ← High drift
  BMI:      drift=✓, shift=-16.2%  ← High drift  
  Age:      drift=✓, shift=+15.1%  ← High drift
  Result: 3 features → RETRAIN ✓

Example 2: Retrain due to PSI
  Glucose: PSI=0.32 (> 0.25)  ← Significant
  Result: PSI threshold exceeded → RETRAIN ✓

Example 3: No retrain
  All features: PSI < 0.25
  Only 2 features with |shift| > 15%
  Result: Thresholds not met → NO RETRAIN ✗
```

## 📈 Monitoring & Alerting Flow

```
Azure Monitor Integration
    │
    ├─► Application Insights
    │   │
    │   ├─► Custom Events Table
    │   │   └─► Event: "DataDriftCheck"
    │   │       • timestamp
    │   │       • environment
    │   │       • total_features: 8
    │   │       • drifted_features: 2
    │   │       • drift_percentage: 25.0
    │   │       • should_retrain: true
    │   │
    │   └─► Queryable with KQL:
    │       customEvents
    │       | where name == "DataDriftCheck"
    │       | project timestamp, 
    │                 customDimensions.drift_percentage,
    │                 customDimensions.should_retrain
    │       | order by timestamp desc
    │
    ├─► Log Analytics Workspace
    │   └─► Drift history for trend analysis
    │
    └─► Azure Monitor Alerts (Optional)
        └─► Alert Rule:
            • Condition: drift_percentage > 30%
            • Action: Email ml-team@company.com
            • Frequency: Check every run
```

## 🚀 Retraining Workflow Trigger

```
Drift Detected (should_retrain=true)
    │
    └─► GitHub Actions: trigger-retraining job
        │
        ├─► Execute: gh workflow run ml-training-integrated.yml
        │   │
        │   ├─► Parameters:
        │   │   • environment: dev
        │   │   • triggered_by: drift_detection
        │   │
        │   └─► ML Training Pipeline Starts:
        │       │
        │       ├─► Download latest production data
        │       ├─► Combine with existing training data
        │       ├─► Retrain model with new data
        │       ├─► Evaluate performance vs baseline
        │       ├─► Register new model version
        │       └─► Deploy to staging for testing
        │
        └─► Notification:
            • GitHub Summary updated
            • Azure Monitor event logged
            • Optional: Slack/Email notification
```

## 📊 Data Flow Summary

```
[Production Inference]
         ↓
    score.py logs
         ↓
[Daily CSV Files] (/tmp/production-inference-data/)
         ↓
    (Weekly: Sunday 00:00 UTC)
         ↓
[GitHub Actions: drift-detection.yml]
         ↓
    ┌─────────────────────────────────┐
    │ Download baseline (training)    │
    │ Download production (7 days)    │
    └────────────┬────────────────────┘
                 ↓
    ┌─────────────────────────────────┐
    │ scripts/detect_drift.py         │
    │ • Load & compare data           │
    │ • Run KS test (8 features)      │
    │ • Calculate PSI (8 features)    │
    │ • Make retrain decision         │
    └────────────┬────────────────────┘
                 ↓
    ┌─────────────────────────────────┐
    │ drift_report.json               │
    │ • Summary metrics               │
    │ • Per-feature results           │
    │ • Retrain recommendation        │
    └────────────┬────────────────────┘
                 ↓
         ┌───────┴───────┐
         │               │
    ┌────▼────┐    ┌────▼────┐
    │ Azure   │    │ Trigger │
    │ Monitor │    │ Retrain │
    └─────────┘    └────┬────┘
                        ↓
             [ml-training-integrated.yml]
                        ↓
                [New Model Version]
```

## 🎓 Key Concepts Summary

### Statistical Tests

1. **Kolmogorov-Smirnov (KS) Test**
   - **Purpose**: Compare two continuous distributions
   - **Metric**: KS statistic (max distance between CDFs)
   - **Threshold**: p-value < 0.05
   - **Interpretation**: Are the distributions significantly different?

2. **Population Stability Index (PSI)**
   - **Purpose**: Measure distribution shift magnitude
   - **Metric**: Weighted sum of bin percentage differences
   - **Thresholds**: 
     - < 0.1: No drift
     - 0.1-0.25: Moderate drift
     - \> 0.25: Significant drift
   - **Interpretation**: How much has the distribution shifted?

### Retraining Triggers

1. **Trigger 1: Multiple High-Drift Features**
   - 3+ features with p-value < 0.05 AND |mean_shift| > 15%
   - Indicates widespread data change

2. **Trigger 2: Significant PSI Drift**
   - Any feature with PSI > 0.25
   - Indicates substantial distribution shift

### Benefits

- ✅ **Automated**: No manual intervention needed
- ✅ **Cost-effective**: ~$2/month, runs on GitHub Actions
- ✅ **Fast Detection**: Weekly checks catch drift within 7 days
- ✅ **Auditable**: All metrics logged to Azure Monitor
- ✅ **Preventive**: Retrains before model degrades
- ✅ **Azure ML v2 Compatible**: No deprecated SDK dependencies

---

This mind map covers the complete flow from production inference to automated retraining!
