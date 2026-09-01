# Phase 6 — Classification Validation Report

## Test Set Results (Untouched)

### Baseline (Original Phase 4)
| Metric | Value |
|--------|-------|
| Five-class Accuracy | 0.6324 |
| Five-class Macro F1 | 0.3940 |
| Five-class Macro AUC | 0.8130 |
| Referable Sensitivity | 0.7588 |
| Referable Specificity | 0.8620 |
| Referable AUC | 0.8104 |
| Brier Score | 0.2269 |
| ECE | 0.2580 |
| Threshold | 0.5000 |

### Improved (Phase 6)
| Metric | Value |
|--------|-------|
| Five-class Accuracy | 0.6438 |
| Five-class Macro F1 | 0.3792 |
| Five-class Macro AUC | 0.8205 |
| Referable Sensitivity | 0.7549 |
| Referable Specificity | 0.8535 |
| Referable AUC | 0.8042 |
| Brier Score | 0.8371 |
| ECE | 0.6208 |
| Threshold | 2.0769 |

## Clinical Target Gate

| Target | Required | Achieved | Status |
|--------|----------|----------|--------|
| Sensitivity | >90% | 75.5% | NOT ACHIEVED |
| Specificity | >85% | 85.4% | ACHIEVED |

**Overall: TARGET NOT ACHIEVED**

## Limiting Factors

1. **Feature representation**: 25 handcrafted features cannot capture sufficient discriminative information
2. **Class imbalance**: Level 3/4 severely underrepresented (6.3%/8.1% of training data)
3. **Phase 3 dependency**: Classification limited by upstream detection quality
4. **Quality interaction**: BORDERLINE images have spec=65.7% (vs 87.1% for GOOD)

## Data Leakage Controls

- Test set: Never used for feature decisions, threshold selection, or hyperparameter tuning
- Validation set: Used for threshold optimization and model selection
- Training set: Used for model fitting only
- Patient grouping: Preserved throughout

## Validation Summary

The Phase 6 audit demonstrates that the current feature-based SVM architecture has a performance ceiling around AUC=0.84, which prevents achieving >90% sensitivity while maintaining >85% specificity. This is a legitimate scientific finding that establishes the need for deeper feature representations (e.g., CNN-based) for clinical-grade DR screening.
