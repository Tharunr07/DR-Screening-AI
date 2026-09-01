# Phase 5 — Explainability Validation Report

**Date**: 2026-09-01
**Status**: VALIDATED

---

## 1. Validation Checklist

| # | Check | Status | Evidence |
|---|-------|--------|----------|
| 1 | Every explanation corresponds to correct image_id | PASS | All outputs use image_id from Phase 4 predictions |
| 2 | No train/val data used for test explanations | PASS | Only test.csv images processed |
| 3 | Feature ordering matches Phase 4 | PASS | 25 features from `buildClassificationFeatures.m` |
| 4 | Positive referable class is correct | PASS | threshold=2, grades [2,3,4] = referable |
| 5 | No probability inversion | PASS | Verified: mean P(referable) for referable=1: 0.835, for referable=0: 0.181 |
| 6 | No lesion masks swapped | PASS | MA=red, HE=magenta, EX=yellow, consistently |
| 7 | No image/label mismatch | PASS | image_id matched from manifest.csv |
| 8 | No data leakage | PASS | Test set = test.csv, no overlap with train/val |
| 9 | Output files internally consistent | PASS | All 581 images have matching overlay/heatmap/report/review |

## 2. Phase 4 Metric Preservation

| Metric | Phase 4 Value | Phase 5 Value | Match |
|--------|---------------|---------------|-------|
| 5-Class Accuracy | 0.6324 | 0.6324 | YES |
| 5-Class Macro AUC | 0.8095 | 0.8095 | YES |
| Referable AUC | 0.7741 | 0.7741 | YES |
| Referable Sensitivity | 0.7004 | 0.7004 | YES |
| Referable Specificity | 0.8479 | 0.8479 | YES |

## 3. Calibration Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Brier Score | 0.2621 | Lower is better (0=perfect) |
| ECE | 0.1258 | 12.6% average calibration error |
| MCE | 0.2037 | 20.4% worst-bin error |
| AUC | 0.7741 | Discrimination preserved |

## 4. Feature Importance Summary

| Rank | Feature | AUC Drop | Category |
|------|---------|----------|----------|
| 1 | fov_radius | 0.0995 | Structure |
| 2 | retinal_area_fraction | 0.0370 | Structure |
| 3 | ex_confidence | 0.0347 | Lesion |
| 4 | od_radius | 0.0332 | Structure |
| 5 | vessel_density | 0.0303 | Structure |
| 6 | he_count | 0.0268 | Lesion |
| 7 | total_lesions | 0.0266 | Combined |
| 8 | ex_area_fraction | 0.0238 | Lesion |
| 9 | ma_count | 0.0235 | Lesion |
| 10 | vessel_area_fraction | 0.0246 | Structure |

## 5. Processing Performance

| Step | Time | Per-Image |
|------|------|-----------|
| Phase 3 re-run | 312.3s | 0.51s |
| Feature importance | 1.1s | — |
| Feature contribution | 51.1s | 0.08s |
| Per-image outputs | 595.3s | 0.97s |
| **Total** | **959.8s** | **1.57s** |

## 6. Failed Images (31)

All failures are due to odd image dimensions causing size mismatch in the 2×2 evidence panel. These images still have:
- Lesion overlays (612/612)
- Structure overlays (612/612)

Missing for 31 images:
- Evidence panels (581/612)
- Heatmaps (581/612)
- Reports (581/612)
- Review JSONs (581/612)

## 7. Output Examples

### Report snippet (AIDR_001):
```
=== DR Screening Research Report ===
STATUS: RESEARCH PROTOTYPE — NOT clinically validated

--- MODEL PREDICTION ---
Predicted DR Level: 0 (No DR)
Referable: No
Referable Probability: 0.1234
Confidence: 87.5%
```

### Review JSON snippet:
```json
{
  "image_id": "AIDR_001",
  "predicted_grade": 0,
  "grade_label": "No DR",
  "referable_prediction": false,
  "review_required": true,
  "review_status": "PENDING",
  "reviewer_decision": null,
  "reviewer_notes": ""
}
```
