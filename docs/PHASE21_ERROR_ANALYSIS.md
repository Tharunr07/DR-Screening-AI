# Phase 21: Error Analysis & Improvement Decision

## Executive Summary

Phase 21 analyzed all 611 validation images to identify remaining weaknesses and make evidence-based improvement decisions.

### Key Findings

| Grade | True Cases | Accuracy | Main Failure Mode |
|-------|-----------|----------|-------------------|
| G0 | 296 | **96.6%** | Excellent — minimal errors |
| G1 | 59 | **49.2%** | 40.7% misclassified as G2 |
| G2 | 168 | **82.7%** | Good — G2 collapse resolved |
| G3 | 39 | **25.6%** | **48.7% misclassified as G2** |
| G4 | 49 | **44.9%** | **38.8% misclassified as G2** |

**Overall: 79.5% accuracy, 91.0% referable sensitivity, 91.5% referable specificity**

---

## 1. Confusion Matrix Analysis

```
         Pred G0  Pred G1  Pred G2  Pred G3  Pred G4
True G0:   286       5        2        3        0     (296 total)
True G1:     5      29       24        0        1     (59 total)
True G2:     9       9      139        6        5     (168 total)
True G3:     2       0       19       10        8     (39 total)
True G4:     2       1       19        5       22     (49 total)
```

**Pattern:** The dominant error is **confusion between adjacent grades**, particularly:
- G3 and G4 being predicted as G2 (the most common grade in the dataset)
- G1 being predicted as G2 or G0

This is a **class imbalance artifact** — G2 has 168 cases (27.5% of dataset) and the model has learned to default to G2 when uncertain.

---

## 2. G3 Failure Analysis (25.6% accuracy)

**39 true G3 cases:**
- 19 predicted as G2 (48.7%) — **dominant error**
- 8 predicted as G4 (20.5%)
- 2 predicted as G0 (5.1%)
- 10 correctly predicted as G3 (25.6%)

**Key observations:**
- G3 cases have **low mean confidence** (0.549 ± 0.176) — the model is uncertain
- Most G3 misclassifications have HE=1-11, EX=0-10 — **moderate lesion burden that overlaps with G2**
- 2 high-confidence wrong: `d868acdccb5b` (0.973 → G2), `6b128e648646` (0.956 → G2)
- G3 vs G2 distinction may require **NV detection or specific lesion patterns** that the current model cannot capture

**Is this fixable without retraining?** Partially — the model's uncertainty is genuine. The lesion evidence alone doesn't reliably distinguish G3 from G2.

---

## 3. G4 Failure Analysis (44.9% accuracy)

**49 true G4 cases:**
- 19 predicted as G2 (38.8%) — **dominant error**
- 5 predicted as G3 (10.2%)
- 2 predicted as G0 (4.1%)
- 22 correctly predicted as G4 (44.9%)

**Key observations:**
- G4 cases have moderate mean confidence (0.607 ± 0.138)
- Some G4 cases have very high lesion counts (MA=13, HE=13, EX=13 for `4abca30b676b`)
- G4 is being confused with G2 at similar rates to G3 — the model struggles with the G2/G3/G4 boundary

---

## 4. Confidence Calibration

| Confidence Range | Images | Accuracy | Assessment |
|-----------------|--------|----------|------------|
| 0.9 – 1.0 | 330 | **97.9%** | Excellent |
| 0.7 – 0.9 | 109 | **78.0%** | Good |
| 0.5 – 0.7 | 97 | **53.6%** | Moderate |
| 0.3 – 0.5 | 74 | **33.8%** | Poor |
| 0.0 – 0.3 | 1 | 100.0% | — |

**Conclusion:** The model is **well-calibrated above 0.7 confidence** but poorly calibrated below 0.5. When the model is confident (>0.9), it is almost always correct.

---

## 5. High-Confidence Wrong Predictions

**31 images** with confidence > 0.7 but wrong grade:

| Error Type | Count | Example |
|-----------|-------|---------|
| G3 → G2 | 3 | `d868acdccb5b` (0.973), `6b128e648646` (0.956) |
| G1 → G2 | 3 | `6c6efb6b1358` (0.967), `9782c0489eca` (0.879) |
| G1 → G0 | 2 | `5548a7961a3e` (0.965), `545df1bbcd61` (0.870) |
| G4 → G2 | 2 | `d10ef306996b` (0.922), `4abca30b676b` (0.865) |
| G2 → G0 | 1 | `367c7049929c` (0.928) |

**These are the model's most confident errors** — they represent systematic confusion at the grade boundaries, not random mistakes.

---

## 6. Quality vs Errors

| Quality | Images | Accuracy | Mean Confidence |
|---------|--------|----------|-----------------|
| POOR | 52 | **92.3%** | 0.921 |
| BORDERLINE | 559 | **78.4%** | 0.813 |
| GOOD | 0 | — | — |

**Surprising finding:** POOR quality images have HIGHER accuracy than BORDERLINE. This is because:
- POOR quality images are mostly G0 (36/52) — the model handles G0 well regardless of quality
- BORDERLINE images span all grades including G3/G4 — where the model struggles
- **Quality is not the dominant source of errors**

---

## 7. Lesion Evidence Analysis

| Grade | Mean Lesions | Median | Max |
|-------|-------------|--------|-----|
| G0 | 3.0 | 2 | 25 |
| G1 | 3.8 | 3 | 31 |
| G2 | 6.5 | 5 | 34 |
| G3 | 7.0 | 5 | 20 |
| G4 | 6.8 | 6 | 38 |

**Key finding:** Lesion counts **do not reliably differentiate G3 from G2** (mean 7.0 vs 6.5). The overlap is substantial.

- 13 images with lesions (>0) predicted as G0 — **false negatives**
- 0 images with 0 lesions predicted as referable — **no zero-lesion false positives**

---

## 8. Decision Matrix

Based on the error analysis, the remaining weaknesses are:

| Weakness | Severity | Root Cause | Fixable Without Retraining? |
|----------|----------|------------|---------------------------|
| G3 confusion with G2 | **High** | 48.7% of G3 → G2; model can't distinguish G3 from G2 with current features | No — requires retraining or additional features |
| G4 confusion with G2 | **High** | 38.8% of G4 → G2; same class boundary issue | No — requires retraining |
| G1 confusion | **Medium** | 40.7% of G1 → G2; class imbalance | Partially — could use post-hoc calibration |
| Low confidence calibration | **Low** | Below 0.5 confidence, accuracy is ~34% | Partially — could use calibration layer |
| Grad-CAM zero for 01499815e469 | **Low** | Layer-level limitation | No — would need architecture change |

---

## 9. Improvement Recommendations

### Option A: Keep the Frozen Model

**Justification:**
- Overall accuracy (79.5%) and referable metrics (91.0% sens, 91.5% spec) are clinically acceptable for a screening tool
- The model is well-calibrated when confident (>0.9 → 97.9% accuracy)
- G0 performance is excellent (96.6%)
- The preprocessing bug fix already improved metrics materially

**Acceptable if:**
- The goal is a referable DR screening tool (binary: referable vs non-referable)
- G3/G4 sub-classification is not critical for the use case
- Clinical validation is the next priority

### Option B: Retrain with More G3/G4 Samples

**Justification:**
- G3 (25.6%) and G4 (44.9%) accuracy are unacceptable for fine-grained classification
- The confusion matrix shows systematic G2/G3/G4 confusion
- More G3/G4 training samples could help the model learn the boundary features

**Required if:**
- Fine-grained DR grading is essential
- The 612-image test set must show improved G3/G4 metrics

### Option C: Post-Hoc Calibration + Threshold Tuning

**Justification:**
- The model is well-calibrated above 0.7 — could use confidence-based routing
- Images with confidence < 0.5 could be flagged for manual review
- No retraining needed — just better use of existing model

**Recommended as a quick win regardless of A or B.**

---

## 10. Final Recommendation

**Primary: Option A (Keep the Frozen Model) + Option C (Post-Hoc Calibration)**

The evidence supports keeping the frozen model because:

1. **Referable performance is strong** — 91.0% sensitivity, 91.5% specificity
2. **High-confidence predictions are excellent** — 97.9% accuracy above 0.9 confidence
3. **G0 is excellent** — 96.6% accuracy
4. **G2 collapse is resolved** — 82.7% accuracy
5. **No regressions** from preprocessing correction

The G3/G4 weakness is a **known limitation** of the frozen model that would require retraining to fix. This should be documented as a project limitation, not a defect.

**Post-hoc calibration** (confidence-based routing) is the highest-value immediate improvement that doesn't require retraining.

---

## Outputs

```
results/phase21_error_analysis/
    confusion_matrix.csv
    per_class_metrics.csv
    high_confidence_wrong.csv    (31 images)
    low_confidence_correct.csv   (26 images)
    g3_true_cases.csv            (39 images)
    g4_true_cases.csv            (49 images)
    quality_breakdown.csv
```

## Disclaimers

> **Passing software tests does not establish clinical validity.**

- All accuracy numbers apply to the validation set only, not to clinical populations
- Lesion counts are algorithmic outputs, not clinical diagnoses
- G3/G4 confusion may not be clinically significant depending on the use case
- The frozen model has not been validated against the 612-image test set in this phase
- Retraining recommendations are based on software metrics, not clinical outcomes
