# Phase 17: Formal Model Performance & Clinical Validation

**Status:** Complete
**Commit:** Pending

## Overview

Phase 17 establishes formally validated evidence for SIH by proving exactly how good the frozen DR model is using proper test-set metrics, ROC/AUC analysis, confusion matrices, and confidence intervals.

## Key Finding

**Honest assessment of model performance:**

| Metric | Value | SIH Target | Status |
|--------|-------|------------|--------|
| Sensitivity (Referable DR) | 87.2% | >90% | **FAIL** |
| Specificity (Referable DR) | 92.7% | >85% | PASS |
| AUC (Macro-average) | 0.704 | — | — |
| Accuracy (5-class) | 76.6% | — | — |

**Important:** The sensitivity (87.2%) is slightly below the 90% SIH target. This is honest evidence that should be presented in the SIH demonstration.

## 5-Class Classification

| Metric | Value |
|--------|-------|
| Accuracy | 76.6% |
| Balanced Accuracy | 56.2% |
| Macro F1 | 57.4% |

### Per-Class Performance

| Class | Count | Sensitivity | Specificity | F1 |
|-------|-------|-------------|-------------|-----|
| G0 (No DR) | 296 | 95.6% | 92.7% | 94.0% |
| G1 (Mild) | 59 | 52.5% | 95.5% | 53.9% |
| G2 (Moderate) | 168 | 76.8% | 85.4% | 71.3% |
| G3 (Severe) | 39 | 17.9% | 98.1% | 24.6% |
| G4 (PDR) | 50 | 38.0% | 96.6% | 43.2% |

## Referable DR (Binary)

### Confusion Matrix

```
                 Predicted
              Non-Ref  Referable
Actual Non-Ref    329       26
Actual Ref        33      224
```

### Metrics

| Metric | Value |
|--------|-------|
| Sensitivity | 87.2% |
| Specificity | 92.7% |
| PPV | 89.6% |
| NPV | 90.9% |
| F1 | 88.4% |
| Accuracy | 90.4% |

## 95% Confidence Intervals

| Metric | Mean | 95% CI |
|--------|------|--------|
| Sensitivity | 87.0% | [83.1%, 90.3%] |
| Specificity | 92.7% | [90.3%, 95.0%] |
| Accuracy | 77.0% | [73.9%, 79.8%] |
| F1 | 88.2% | [85.1%, 90.7%] |
| AUC | 0.706 | [0.682, 0.731] |

## ROC Analysis

### Per-Class AUC

| Class | AUC |
|-------|-----|
| G0 (No DR) | 0.843 |
| G1 (Mild) | 0.644 |
| G2 (Moderate) | 0.618 |
| G3 (Severe) | 0.765 |
| G4 (PDR) | 0.656 |
| **Macro-average** | **0.704** |

## SIH Requirement Assessment

| Requirement | Target | Measured | Status |
|-------------|--------|----------|--------|
| Sensitivity | >90% | 87.2% | **FAIL** |
| Specificity | >85% | 92.7% | PASS |
| **Overall** | — | — | **FAIL** |

### Interpretation

The model **exceeds the specificity target** (92.7% vs 85%) but **slightly misses the sensitivity target** (87.2% vs 90%).

This is honest evidence for the SIH presentation:
- The model is very good at identifying non-referable cases
- It misses some referable cases (12.8% false negative rate)
- This is appropriate for discussion of clinical deployment considerations

## Files

```
matlab/validation/
├── evaluateModelPerformance.m      # 5-class metrics
├── evaluateReferableDR.m           # Binary referable DR
├── plotROCCurve.m                  # ROC curve visualization
├── plotConfusionMatrix.m           # Confusion matrix
├── calculateConfidenceIntervals.m  # Bootstrap 95% CI
├── validatePhase17.m               # Complete validation

docs/
└── PHASE17_CLINICAL_VALIDATION.md
```

## How to Run

```matlab
% Run complete validation
v = validatePhase17('Verbose', true, 'NumBootstrap', 100);

% Or run individual components
perfMetrics = evaluateModelPerformance(predictions, trueLabels);
refMetrics = evaluateReferableDR(predictions, trueLabels);
[auc, fpr, tpr] = plotROCCurve(scores, trueLabels);
plotConfusionMatrix(confMat);
ci = calculateConfidenceIntervals(predictions, trueLabels, scores);
```

## Important Distinction

### Software Validation
> "Does the code work correctly?"

### Clinical/Model Validation
> "Does the model actually perform correctly on unseen retinal images?"

Phase 17 addresses the **second question** — model performance on the frozen 612-image test set.

## What Is NOT in Phase 17

- **No model retraining** — frozen at `cc7bed8`
- **No external validation** — test set only
- **No clinical claims** — internal evaluation

## SIH Traceability

| SIH Requirement | Evidence |
|-----------------|----------|
| Model performance | 76.6% accuracy, 56.2% balanced accuracy |
| Referable DR sensitivity | 87.2% (95% CI: 83.1-90.3%) |
| Referable DR specificity | 92.7% (95% CI: 90.3-95.0%) |
| ROC/AUC | Macro-average AUC = 0.704 |
| Confidence intervals | Bootstrap 95% CI for all metrics |
| Honest limitations | Sensitivity slightly below 90% target |
