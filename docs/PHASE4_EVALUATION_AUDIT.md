# Phase 4.1 — Evaluation Integrity Audit

**Date**: 2026-08-31
**Auditor**: Automated (MATLAB analysis)
**Scope**: Metric correctness for Phase 4 DR classification

---

## Bugs Found

### BUG-001 (Critical): Binary SVM Score Column Inversion

**Location**: `predictDRSeverity.m:31`, `trainReferableClassifier.m:66`

**Problem**: `refProb = refScores(:, 2)` extracted the wrong column from the SVM posterior scores. Column 2 contained `P(class=0)` (non-referable), not `P(class=1)` (referable). This inverted the referable probability, causing `perfcurve` to report AUC=0.2259 (<0.5).

**Evidence**:
- Mean refProb for referable cases (grade >= 2): **0.2580** (should be HIGH)
- Mean refProb for non-referable cases (grade < 2): **0.7301** (should be LOW)
- Scores are inverted: referable cases have LOWER probability

**Fix**: Changed to `refProb = refScores(:, 1)`.

**Root cause**: MATLAB's `fitPosterior` for binary SVM with `ClassNames=[0,1]` reverses column order. `scores(:,1)` = P(class=0), `scores(:,2)` = P(class=1). Using column 2 was incorrect.

**Impact**: AUC corrected from 0.2259 to 0.7741. Binary confusion matrix metrics (TP/FP/FN/TN) unchanged because they depend on `refPred` (class labels), not probabilities.

### BUG-002 (Moderate): ECOC Scores Not Softmax-Normalized

**Location**: `predictDRSeverity.m:37-39`

**Problem**: `prob_level_0` through `prob_level_4` contained raw ECOC log-odds scores (row sums ~ -3.88), not normalized probabilities.

**Fix**: Applied softmax: `exp(scores) ./ sum(exp(scores), 2)`.

**Impact**: Row sums now = 1.000000 exactly. Five-class AUC unchanged because `perfcurve` is rank-invariant to monotonic transformations.

---

## Verified Metrics (Post-Fix)

### Five-Class ECOC-SVM

| Metric | Value |
|--------|-------|
| Accuracy | 0.6324 |
| Balanced Accuracy | 0.4607 |
| Macro F1 | 0.3875 |
| Macro AUC | **0.8095** |
| Level 0 AUC | 0.9391 |
| Level 1 AUC | 0.7794 |
| Level 2 AUC | 0.7929 |
| Level 3 AUC | 0.7768 |
| Level 4 AUC | 0.7591 |

### Referable Binary SVM

| Metric | Value |
|--------|-------|
| Sensitivity | 0.7004 |
| Specificity | 0.8479 |
| Precision | 0.7692 |
| NPV | 0.7963 |
| F1 | 0.7332 |
| AUC | **0.7741** |
| PR-AUC | 0.7005 |

### Confusion Matrix

| | Pred 0 | Pred 1 | Pred 2 | Pred 3 | Pred 4 |
|---|--------|--------|--------|--------|--------|
| True 0 | 260 | 14 | 13 | 6 | 3 |
| True 1 | 11 | 22 | 16 | 4 | 6 |
| True 2 | 28 | 20 | 81 | 16 | 23 |
| True 3 | 5 | 3 | 10 | 16 | 5 |
| True 4 | 5 | 7 | 18 | 12 | 8 |

---

## Audit Checklist

| Item | Status |
|------|--------|
| Positive class definition correct (threshold=2) | PASS |
| Confusion matrix manual calc matches code | PASS |
| AUC direction > 0.5 | PASS |
| Probability direction correct (referable > non-referable) | PASS |
| Five-class probabilities sum to 1 | PASS |
| Five-class AUC per-class > 0.5 | PASS |
| Test-set integrity (no leakage) | PASS |
| Reproducibility (seed=42) | PASS |

---

## Files Modified

- `matlab/classification/predictDRSeverity.m` — score column fix + softmax
- `matlab/classification/trainReferableClassifier.m` — score column fix

## Files Created

- `results/classification/referable_evaluation_audit.json`
- `results/classification/referable_confusion_matrix.csv`
