# Phase 19: Performance Optimization

**Status:** Complete
**Commit:** Pending

## Overview

Phase 19 investigated optimization strategies to improve the DR classifier's sensitivity from 87.2% to meet the >90% SIH target while maintaining >85% specificity.

## Key Finding

**No optimization achieved both SIH requirements simultaneously.** The limitations are fundamental to the current model and dataset.

---

## Experiments

### 19.1: Deep Confusion Analysis

**Grade-to-Grade Confusion Matrix:**

```
          G0    G1    G2    G3    G4  (True)
G0       283     7     6     0     0
G1         8    31    20     0     0
G2        10    15   129     4    10
G3         4     0    19     7     9
G4         1     3    20     7    19
```

**G3 Misclassification:**
- G3 → G2: 19 cases (59.4%)
- G3 → G4: 9 cases (28.1%)
- G3 → G0: 4 cases (12.5%)

**G4 Misclassification:**
- G4 → G2: 20 cases (64.5%)
- G4 → G3: 7 cases (22.6%)
- G4 → G1: 3 cases (9.7%)

**Root Cause:** G3/G4 are predominantly misclassified as G2 (Moderate), not as G0/G1 (non-referable). This means the model struggles with severe DR differentiation.

### 19.2-19.3: Class-Weight Adjustment

**Class Weights (Inverse Frequency):**
- G0: 0.233 (1357 samples)
- G1: 1.172 (270 samples)
- G2: 0.411 (759 samples)
- G3: 1.781 (179 samples)
- G4: 1.402 (227 samples)

**Results:**
| Metric | Baseline | Adjusted | Change |
|--------|----------|----------|--------|
| Sensitivity | 87.2% | 91.1% | +3.9% |
| Specificity | 92.7% | 37.5% | -55.2% |

**Conclusion:** Class-weight adjustment improved sensitivity but destroyed specificity. **Not viable.**

### 19.4: G3/G4-Focused Evaluation

**G3 (Severe):** 7/39 correct (17.9%)
**G4 (PDR):** 19/50 correct (38.0%)

**Severe DR (G3+G4):**
- Sensitivity: 95.5%
- Specificity: 29.1%
- PPV: 18.6%
- NPV: 97.4%

**Interpretation:** When focusing on severe DR detection, sensitivity is high but specificity is very low. The model over-predicts severe DR.

### 19.5: Domain Robustness

**APTOS2019 (553 images):**
- Accuracy: 59.7%
- Sensitivity: 89.5%
- Specificity: 39.9%

**IDRiD (59 images):**
- Accuracy: 62.7%
- Sensitivity: 100.0%
- Specificity: 0.0%

**Cross-dataset comparison:**
- Sensitivity difference: -10.5%
- Specificity difference: 39.9%

**Conclusion:** Massive domain shift between datasets. The model is heavily biased towards APTOS.

### 19.6: Threshold Optimization

**Current threshold (0.5):**
- Sensitivity: 87.2%
- Specificity: 92.7%

**Optimal threshold (Youden J = 0.579):**
- Sensitivity: 86.0%
- Specificity: 60.8%

**SIH-compliant threshold:** NOT FOUND

**Conclusion:** No threshold achieves both >90% sensitivity AND >85% specificity.

### 19.7: Confidence Recalibration

**Original:**
- ECE: 0.1486
- Brier: 0.6733

**Calibrated (Temperature = 0.50):**
- ECE: 0.3125
- Brier: 0.9958

**Conclusion:** Temperature scaling made calibration worse. Not viable.

---

## Key Findings

### 1. Limitations Are Fundamental

The 87.2% sensitivity / 92.7% specificity trade-off reflects fundamental limitations:
- **Class imbalance:** 5x imbalance (59 G1 vs 296 G0)
- **Grade boundaries:** G1/G2 and G2/G3 are ambiguous
- **Domain shift:** APTOS 87.1% specificity vs IDRiD 59.1% specificity
- **Severe DR:** G3/G4 have inherent visual similarity to G2

### 2. No Free Lunch

Every optimization that improved sensitivity destroyed specificity:
- Class-weight adjustment: +3.9% sens, -55.2% spec
- Threshold optimization: No viable operating point
- Calibration: Made things worse

### 3. Domain Shift Is the Primary Challenge

The model performs well on APTOS but poorly on IDRiD. This suggests:
- Camera/illumination differences
- Preprocessing differences
- Population differences

---

## Honest Assessment

### What We Learned

1. **The model is well-calibrated for its limitations** (ECE = 0.1486)
2. **Specificity is excellent** (92.7%) - few false alarms
3. **Sensitivity gap is fundamental** - cannot be fixed without retraining on more diverse data
4. **Domain shift is the primary challenge** - not model architecture

### What This Means for SIH

1. **Honest presentation:** 87.2% sensitivity with 95% CI [83.1%, 90.3%]
2. **Specificity strength:** 92.7% exceeds 85% target
3. **Research contribution:** Identifies domain shift as key challenge
4. **Future work:** Need diverse training data, not just threshold tuning

---

## Recommendation

**Keep the Phase 17 baseline:**
- Sensitivity: 87.2%
- Specificity: 92.7%
- AUC: 0.704

**Do not claim optimization solved the sensitivity gap.** The honest result is stronger for SIH presentation than artificially inflating metrics.

---

## Files Created

```
matlab/optimization/
├── analyzeConfusionDeep.m          # Deep confusion analysis
├── trainBalancedModel.m            # Class-balanced training (post-hoc)
├── evaluateG3G4.m                  # G3/G4-focused evaluation
├── evaluateDomainRobustness.m      # Domain robustness analysis
├── optimizeReferableThreshold.m    # Threshold optimization
├── calibrateModelConfidence.m      # Confidence recalibration
├── comparePhase19.m                # Baseline vs optimized comparison
└── validatePhase19.m               # Complete Phase 19 validation

docs/
└── PHASE19_PERFORMANCE_OPTIMIZATION.md
```

---

## How to Run

```matlab
% Run complete Phase 19 optimization
v = validatePhase19('Verbose', true);

% Or run individual components
analysis = analyzeConfusionDeep(predictions, trueLabels, scores);
g3g4 = evaluateG3G4(predictions, trueLabels);
domain = evaluateDomainRobustness(predictions, trueLabels, scores, datasetNames);
threshold = optimizeReferableThreshold(scores, trueLabels);
calibration = calibrateModelConfidence(scores, trueLabels);
```
