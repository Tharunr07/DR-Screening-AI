# Phase 5 — Explainability Design Document

**Version**: 5.0.0
**Date**: 2026-08-31
**Status**: DESIGN — NOT IMPLEMENTED

---

## 1. Problem Statement

Phase 4 classifies DR severity using an ECOC-SVM with 25 features from Phase 2+3. The classifier achieves:
- 5-class Macro AUC: 0.8095
- Referable AUC: 0.7741
- Sensitivity: 70.04%, Specificity: 84.79%

Phase 5 must provide **model-appropriate explainability** — the SVM is not differentiable, so Grad-CAM cannot be directly applied. Instead, we use:

1. **Permutation feature importance** — which features the SVM relies on most
2. **Per-image feature contribution** — which features drove each specific prediction
3. **Lesion-level evidence overlays** — binary masks from Phase 3 overlaid on fundus images
4. **Feature-based attention heatmaps** — spatial heatmaps derived from feature contributions
5. **Confidence calibration** — reliability diagrams, Brier score, ECE
6. **Automated clinical report** — ophthalmologist-facing text report
7. **Human-review workflow** — structured output for expert verification

---

## 2. Architecture

```
Phase 2: Image Quality
     ↓
Phase 3: Structures + Lesions (binary masks, counts, areas, confidences)
     ↓
Phase 4: SVM DR Classification (25 features → grade + referable)
     ↓
Phase 5: Explainability
     ├── 5.1 Feature Importance (global)
     │   └── computeFeatureImportance.m  — permutation importance across test set
     │
     ├── 5.2 Feature Contribution (per-image)
     │   └── computeFeatureContribution.m — perturbation-based local explanation
     │
     ├── 5.3 Evidence Overlay (per-image)
     │   ├── generateLesionOverlay.m      — MA/HE/EX/NV masks on fundus
     │   ├── generateStructureOverlay.m   — OD/fovea/vessel annotations
     │   └── generateEvidenceOverlay.m    — combined clinical evidence image
     │
     ├── 5.4 Attention Heatmap (per-image)
     │   └── generateAttentionMap.m       — feature-weighted spatial heatmap
     │
     ├── 5.5 Calibration (global)
     │   └── computeCalibration.m         — reliability diagram, Brier, ECE
     │
     ├── 5.6 Report Generation (per-image)
     │   ├── generateReport.m             — automated ophthalmologist report
     │   └── generateHumanReviewReport.m  — structured human-review output
     │
     ├── 5.7 Pipeline
     │   └── runPhase5Explainability.m    — orchestrator
     │
     └── 5.8 Tests
         └── testExplainabilityPipeline.m — 12 synthetic tests
```

---

## 3. Module Specifications

### 5.1 `computeFeatureImportance.m` (Global — Run Once)

**Purpose**: Measure how much each of the 25 features contributes to SVM performance across the test set.

**Method**: Permutation importance
1. Compute baseline AUC on test set (already done: 0.7741 referable, 0.8095 five-class)
2. For each feature j = 1:25:
   a. Shuffle feature j across all test samples (breaks correlation with label)
   b. Re-predict using SVM with shuffled feature
   c. Compute new AUC
   d. Importance(j) = baseline_AUC - shuffled_AUC
3. Rank features by importance

**Input**: trained SVM models, test features, test labels
**Output**: `results/explainability/feature_importance.csv` (25 rows: feature_name, importance, rank)

**Why not SHAP**: SHAP requires model retraining or kernel approximation. Permutation importance is model-agnostic, deterministic, and requires no retraining.

### 5.2 `computeFeatureContribution.m` (Per-Image)

**Purpose**: For each test image, show which features pushed the prediction toward or away from the predicted class.

**Method**: Perturbation-based local explanation
1. For image i with features x_i and predicted class c:
2. For each feature j:
   a. Replace x_i(j) with the training median (simulates "feature absent")
   b. Re-predict
   c. contribution(j) = P(class=c | x_i) - P(class=c | x_i with feature j replaced)
3. Positive contribution = feature supported prediction
4. Negative contribution = feature contradicted prediction

**Input**: trained SVM models, single image features, training medians
**Output**: struct with feature_names, contributions, predicted_class, base_probability

**Also saves**: `results/explainability/feature_contributions.csv` for all test images

### 5.3 `generateLesionOverlay.m` (Per-Image)

**Purpose**: Overlay detected lesion binary masks on the fundus image.

**Method**:
1. Load original fundus image (resize to match processing resolution)
2. Create RGB overlay:
   - MA candidates: Red semi-transparent mask
   - HE candidates: Magenta semi-transparent mask
   - EX candidates: Yellow semi-transparent mask
   - NV candidates: Cyan semi-transparent mask
3. Blend with original image (alpha = 0.4)
4. Add lesion count annotations

**Input**: original image path, Phase 3 result struct (with detail_ma, detail_he, detail_ex, detail_nv)
**Output**: saved PNG image

### 5.4 `generateStructureOverlay.m` (Per-Image)

**Purpose**: Annotate anatomical structures on the fundus image.

**Method**:
1. Load original fundus image
2. Draw:
   - Optic disc: Green circle (center + radius)
   - Fovea: Blue crosshair (center)
   - Vessels: Green contour overlay (from vessel_mask)
   - FOV boundary: White dashed circle
3. Add labels

**Input**: original image path, Phase 3 result struct
**Output**: saved PNG image

### 5.5 `generateEvidenceOverlay.m` (Per-Image — Combined)

**Purpose**: Create a single combined clinical evidence image.

**Method**:
1. Create 2×2 panel figure:
   - Top-left: Original fundus image
   - Top-right: Lesion overlay (5.3)
   - Bottom-left: Structure overlay (5.4)
   - Bottom-right: Attention heatmap (5.6)
2. Add header with image_id, DR grade, referable status, confidence
3. Save as single PNG

**Input**: all per-image results
**Output**: `results/explainability/overlays/{image_id}_evidence.png`

### 5.6 `generateAttentionMap.m` (Per-Image)

**Purpose**: Generate a spatial heatmap showing which regions of the image contributed most to the classification.

**Method** (feature-weighted spatial attention):
1. From Phase 3, we have spatial masks:
   - MA mask (from detail_ma.candidate_mask)
   - HE mask (from detail_he.candidate_mask)
   - EX mask (from detail_ex.exudate_mask)
   - Vessel mask (from detail_vessels.vessel_mask)
2. From 5.2, we have feature contributions:
   - contribution for ma_count, ma_area, ma_confidence
   - contribution for he_count, he_area, he_confidence
   - contribution for ex_count, ex_area, ex_confidence
   - contribution for vessel_area_fraction, vessel_density
3. Compute attention map:
   ```
   attention = (w_ma * MA_mask) + (w_he * HE_mask) + (w_ex * EX_mask) + (w_vessel * vessel_mask)
   ```
   where weights = sum of contributions for that lesion type's features
4. Normalize to [0, 1], apply colormap (jet/hot), overlay on fundus

**Input**: Phase 3 result struct, feature contributions from 5.2
**Output**: saved PNG heatmap overlay

### 5.7 `computeCalibration.m` (Global)

**Purpose**: Assess whether predicted probabilities match observed frequencies.

**Method**:
1. Bin test predictions into 10 equal-width probability bins [0,0.1), [0.1,0.2), ..., [0.9,1.0]
2. For each bin:
   - mean_predicted_probability
   - observed_frequency (fraction of true positives)
3. Compute:
   - **Brier score**: mean((predicted - actual)^2)
   - **Expected Calibration Error (ECE)**: sum(|bin_size| * |mean_predicted - observed|)
   - **Maximum Calibration Error (MCE)**: max(|mean_predicted - observed|)
4. Generate reliability diagram plot (predicted vs observed)

**Input**: predicted probabilities, true labels
**Output**: `results/explainability/calibration_results.json`, reliability diagram PNG

### 5.8 `generateReport.m` (Per-Image)

**Purpose**: Generate automated ophthalmologist-facing text report.

**Output format**:
```
=== DR Screening Report ===
Image: {image_id}
Dataset: {dataset}
Quality: {quality_status} (score: {quality_score})

--- Classification ---
DR Grade: {predicted_grade} ({grade_label})
Referable: {referable_status}
Confidence: {confidence_score:.1%}

--- Evidence Summary ---
Microaneurysms: {ma_count} candidates (area: {ma_area}px, confidence: {ma_conf:.2f})
Hemorrhages: {he_count} candidates (area: {he_area}px, confidence: {he_conf:.2f})
Exudates: {ex_count} candidates (area: {ex_area}px, confidence: {ex_conf:.2f})
Neovascularization: {nv_status} (score: {nv_score:.2f})

--- Structures ---
Optic Disc: {od_status} (confidence: {od_conf:.2f})
Fovea: {fovea_status} (confidence: {fovea_conf:.2f})
Vessel Density: {vessel_density:.3f}

--- Top Contributing Features ---
1. {feature_name}: {contribution:+.3f}
2. {feature_name}: {contribution:+.3f}
3. {feature_name}: {contribution:+.3f}

--- Calibration ---
Reliability: {calibration_status}
Brier Score: {brier_score:.4f}

--- Disclaimer ---
This is a research prototype output. NOT clinically validated.
All thresholds are PROVISIONAL/THEORETICAL.
Screening decisions require qualified ophthalmologist review.
```

**Input**: all per-image results + global calibration
**Output**: `results/explainability/reports/{image_id}_report.txt`

### 5.9 `generateHumanReviewReport.m` (Per-Image)

**Purpose**: Generate structured output for expert human review workflow.

**Output format** (JSON):
```json
{
  "image_id": "...",
  "review_status": "PENDING",
  "classification": {
    "predicted_grade": 2,
    "grade_label": "Moderate NPDR",
    "referable": true,
    "confidence": 0.87
  },
  "evidence": {
    "ma_count": 5,
    "he_count": 2,
    "ex_count": 3,
    "nv_present": false
  },
  "quality": {
    "status": "GOOD",
    "score": 85.2
  },
  "top_features": [
    {"name": "ma_count", "contribution": 0.15},
    {"name": "he_area", "contribution": 0.12},
    {"name": "ex_count", "contribution": 0.08}
  ],
  "overlay_path": "results/explainability/overlays/{image_id}_evidence.png",
  "report_path": "results/explainability/reports/{image_id}_report.txt",
  "clinician_notes": "",
  "clinician_grade": null,
  "review_timestamp": null
}
```

**Input**: all per-image results
**Output**: `results/explainability/reviews/{image_id}_review.json`

---

## 4. Data Flow

```
manifest.csv (7872 images)
     ↓
data/splits/test.csv (920 rows, 612 labeled with DR grades)
     ↓
results/quality/quality_results.csv (7872 rows)
     ↓
results/phase3/structure_results.csv (6084 rows with Phase 3 features)
     ↓
results/classification/classification_predictions.csv (612 test images)
     ↓
Phase 5 Explainability:
     ├── results/explainability/feature_importance.csv (global, run once)
     ├── results/explainability/feature_contributions.csv (per-image, 612 rows)
     ├── results/explainability/calibration_results.json (global)
     ├── results/explainability/calibration_diagram.png (global)
     ├── results/explainability/overlays/{image_id}_evidence.png (per-image, 612 files)
     ├── results/explainability/reports/{image_id}_report.txt (per-image, 612 files)
     ├── results/explainability/reviews/{image_id}_review.json (per-image, 612 files)
     └── results/explainability/phase5_metrics.json (pipeline stats)
```

---

## 5. Test Suite

### testExplainabilityPipeline.m — 12 Synthetic Tests

| # | Test | Expected |
|---|------|----------|
| 1 | Feature importance sums to ≥ 0 | PASS (importance ≥ 0 for all features) |
| 2 | Feature importance has 25 entries | PASS (one per feature) |
| 3 | Feature contributions sum ≈ 0 (baseline effect) | PASS (within tolerance) |
| 4 | Lesion overlay produces valid image | PASS (non-empty, correct dimensions) |
| 5 | Structure overlay produces valid image | PASS (non-empty, correct dimensions) |
| 6 | Evidence overlay produces valid image | PASS (2×2 panel, correct dimensions) |
| 7 | Attention map values in [0, 1] | PASS (normalized) |
| 8 | Calibration bins sum to test set size | PASS (no images lost) |
| 9 | Brier score in [0, 1] | PASS (proper scoring rule) |
| 10 | ECE in [0, 1] | PASS (calibration error bounded) |
| 11 | Report contains required sections | PASS (all sections present) |
| 12 | Human review JSON has required fields | PASS (all fields present) |

---

## 6. Strict Boundaries

### In Scope (Phase 5)
- Model-appropriate SVM explainability (permutation importance, perturbation contributions)
- Lesion-level evidence overlays using Phase 3 binary masks
- Structure annotation overlays
- Feature-based attention heatmaps (not Grad-CAM)
- Confidence calibration metrics and diagrams
- Automated clinical reports
- Human-review workflow output

### NOT in Scope (Phase 5)
- Grad-CAM (SVM is not differentiable — would be false application)
- CNN explainability baseline (separate future phase if needed)
- Clinical validation (research prototype only)
- Real-time inference
- Deployment/API
- DR classification model changes

### Disclaimers (Mandatory in All Outputs)
- "Research prototype output — NOT clinically validated"
- "All thresholds PROVISIONAL/THEORETICAL"
- "Screening decisions require qualified ophthalmologist review"
- "Phase 3 lesion detections are CANDIDATES, not confirmed diagnoses"

---

## 7. Files to Create

| File | Lines (est.) | Purpose |
|------|-------------|---------|
| `matlab/explainability/explainabilityConfig.m` | 80 | Central config |
| `matlab/explainability/computeFeatureImportance.m` | 120 | Permutation importance |
| `matlab/explainability/computeFeatureContribution.m` | 150 | Per-image contributions |
| `matlab/explainability/generateLesionOverlay.m` | 130 | Lesion mask overlay |
| `matlab/explainability/generateStructureOverlay.m` | 110 | Structure annotations |
| `matlab/explainability/generateEvidenceOverlay.m` | 160 | Combined 2×2 panel |
| `matlab/explainability/generateAttentionMap.m` | 140 | Feature-weighted heatmap |
| `matlab/explainability/computeCalibration.m` | 100 | Reliability diagram + metrics |
| `matlab/explainability/generateReport.m` | 120 | Text report |
| `matlab/explainability/generateHumanReviewReport.m` | 100 | JSON review output |
| `matlab/explainability/runPhase5Explainability.m` | 200 | Pipeline orchestrator |
| `matlab/explainability/testExplainabilityPipeline.m` | 250 | 12 synthetic tests |
| `matlab/explainability/README.md` | 100 | Documentation |
| `docs/PHASE5_EXPLAINABILITY.md` | 200 | Implementation report |

**Total**: ~13 files, ~1860 lines

---

## 8. Execution Order

1. Create `explainabilityConfig.m`
2. Create `computeFeatureImportance.m` + test
3. Create `computeFeatureContribution.m` + test
4. Create `generateLesionOverlay.m` + test
5. Create `generateStructureOverlay.m` + test
6. Create `generateEvidenceOverlay.m` + test
7. Create `generateAttentionMap.m` + test
8. Create `computeCalibration.m` + test
9. Create `generateReport.m` + test
10. Create `generateHumanReviewReport.m` + test
11. Create `runPhase5Explainability.m` (orchestrator)
12. Create `testExplainabilityPipeline.m` (12 synthetic tests)
13. Run full pipeline on test set (612 images)
14. Create `docs/PHASE5_EXPLAINABILITY.md`
15. Commit and push

---

## 9. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| SVM perturbation too slow (612 × 25 features × 2 models) | High | Batch predictions, cache intermediate results |
| Lesion masks not saved to disk (only in struct detail fields) | Medium | Re-run Phase 3 analysis for test images to get masks |
| Figure generation requires display | Medium | Use `invisible` figure handle in MATLAB |
| Memory for 612 overlay images | Low | Process in batches of 50 |

---

## 10. Open Questions

1. **Lesion mask availability**: Phase 3 `analyzeImage.m` stores masks in `result.detail_ma.candidate_mask` etc., but these are NOT saved to `structure_results.csv` (only aggregate stats). Options:
   - a) Re-run Phase 3 analysis for 612 test images to get masks (slow but complete)
   - b) Use aggregate stats only for overlay (no spatial masks, just counts/areas)
   - c) Modify Phase 3 to save masks to disk (requires re-running full pipeline)

   **Recommendation**: Option (a) — re-run Phase 3 for test images only. 612 images × ~0.4s/image = ~4 minutes.

2. **Grad-CAM inclusion**: Should Phase 5 include a placeholder CNN + Grad-CAM as a "separate explainability baseline" per the user's suggestion, or skip entirely?

   **Recommendation**: Skip for now. Add in Phase 6 if needed for comparison.
