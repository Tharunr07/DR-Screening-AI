# Phase 6 — DR Classification Audit & Improvement

## Summary

Phase 6 conducted a comprehensive audit of the Phase 4 DR classifier and attempted evidence-based improvements. The audit reveals that the current feature-based SVM architecture has a fundamental performance ceiling that prevents achieving the clinical target (>90% sensitivity, >85% specificity).

## Clinical Target

| Metric | Target | Baseline | Best Achievable | Status |
|--------|--------|----------|-----------------|--------|
| Sensitivity | >90% | 70.04% | 83.6% (val) | NOT ACHIEVED |
| Specificity | >85% | 84.79% | 85.1% (val) | NOT ACHIEVED |

## Audit Findings

### 1. Feature Audit
- **25 features** from Phase 2/3
- **64 NaN values** in od_radius (feature 5)
- **1 zero-variance feature**, 1 near-zero-variance
- Top class separation: nv_score (24.02), nv_confidence (24.02) — likely noisy
- Top correlation with label: od_radius (-0.317), ex_count (0.236)

### 2. Class Imbalance
| Level | Train | Val | Test | Weight |
|-------|-------|-----|------|--------|
| 0 | 1381 (48.4%) | 296 | 296 | 0.413 |
| 1 | 275 (9.6%) | 59 | 59 | 2.074 |
| 2 | 785 (27.5%) | 168 | 168 | 0.727 |
| 3 | 181 (6.3%) | 39 | 39 | 3.151 |
| 4 | 230 (8.1%) | 49 | 50 | 2.480 |

- Effective N = 3 (severe imbalance)
- Level 3 (17.9% sensitivity) and Level 4 (10.2%) severely underperform

### 3. Feature Scaling
- Z-score standardization: AUC = 0.8433 (better than internal standardization)
- Robust scaling: AUC = 0.8167

### 4. Hyperparameter Search
- Best validation AUC: 0.8433 (C=1.0, gamma=auto)
- No configuration achieved both sens>0.90 and spec>0.85

### 5. Threshold Analysis
- Best F1 threshold: 1.1923 → sens=0.836, spec=0.851
- No threshold simultaneously achieves sens≥0.90 AND spec≥0.85
- The operating point that achieves sens=0.90 gives spec≈0.0 (useless)

### 6. Calibration
- Raw: Brier=0.2050, ECE=0.2395
- Platt scaling: Made calibration worse
- Isotonic regression: Failed to converge

### 7. Five-Class Performance
| Level | Sensitivity | Specificity | F1 |
|-------|-------------|-------------|-----|
| 0 | 83.1% | — | — |
| 1 | 42.4% | — | — |
| 2 | 51.2% | — | — |
| 3 | 17.9% | — | — |
| 4 | 10.2% | — | — |

### 8. Ordinal Analysis
- MAE: 0.707 grades
- Exact accuracy: 60.4%
- ±1 accuracy: 78.6%
- **Severe under-grading: 21.9%** (actual ≥2, predicted ≤1)
- Severe over-grading: 10.1%

### 9. Quality Interaction
| Quality | N | Sensitivity | Specificity |
|---------|---|-------------|-------------|
| GOOD | 537 | 83.5% | 87.1% |
| BORDERLINE | 68 | 81.8% | 65.7% |
| UNGRADABLE | 6 | 100% | 100% |

- Borderline images have much worse specificity (65.7% vs 87.1%)
- Borderline FN rate: 18.2%

### 10. Phase 3 Feature Dependency
- Top features by correlation: od_radius (-0.317), ex_count (0.236)
- nv_present has NaN correlation (likely all zeros in training)
- Phase 3 detection quality directly limits classification

## Improvement Attempts

### Attempt 1: Z-score + Class-Balanced Weighting
- Result: Worse performance (AUC dropped to 0.50)
- Cause: fitPosterior convergence issues with external scaling

### Attempt 2: Improved Class Weights + Threshold Optimization
- Result: sens=0.755, spec=0.854 (similar to baseline)
- Finding: The feature representation is the bottleneck, not the weights

## Key Conclusion

**The fundamental limitation is the feature representation, not the classifier.**

The 25 handcrafted features from Phase 2/3 cannot capture the discriminative information needed for >90% sensitivity. The audit shows:
1. The best achievable AUC is 0.8433 (validation)
2. No threshold achieves both sens>0.90 and spec>0.85
3. Level 3/4 sensitivity is critically low (17.9%/10.2%)
4. 21.9% of referable cases are severely under-graded

## Recommendations for Future Work

1. **Deep learning features**: CNN-based features would capture spatial patterns that handcrafted features miss
2. **Larger dataset**: More Level 3/4 samples would help minority class learning
3. **Ensemble methods**: Combining multiple feature representations
4. **Ordinal regression**: Exploiting the ordinal structure of DR grades
5. **Quality-aware training**: Special handling for BORDERLINE images

## Files Created

- `matlab/classification/classificationAudit.m` — Comprehensive audit function
- `matlab/classification/improveDRClassifier.m` — Improvement attempt
- `docs/PHASE6_CLASSIFICATION_AUDIT.md` — This document

## Files Modified

- None (Phase 4 baseline preserved)

## Reproducibility

```matlab
addpath(genpath('matlab'));
audit = classificationAudit();           % Run full audit
[improved, comparison] = improveDRClassifier();  % Run improvement
```
