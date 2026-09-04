# Phase 5 — Explainability + Human Review Workflow

**Version**: 5.0.0
**Date**: 2026-09-01
**Status**: COMPLETE

---

## 1. Architecture

```
Phase 2: Image Quality
     ↓
Phase 3: Structures + Lesions (re-run for 612 test images)
     ↓
Phase 4: SVM DR Classification (25 features → grade + referable)
     ↓
Phase 5: Explainability
     ├── Permutation Feature Importance (global, run once)
     ├── Perturbation Feature Contribution (per-image, 612 × 25 = 15,300)
     ├── Lesion Overlay (per-image, imwrite only, no figures)
     ├── Structure Overlay (per-image, imwrite only, no figures)
     ├── Evidence Overlay (2×2 panel, per-image)
     ├── Feature-Weighted Spatial Evidence Map (per-image)
     ├── Calibration (reliability diagram, Brier, ECE)
     ├── Automated Report (per-image, markdown)
     └── Human Review JSON (per-image, machine-readable)
```

## 2. Why Grad-CAM Is Not Used

The Phase 4 classifier is an **ECOC-SVM with RBF kernel**. SVMs are not differentiable — there is no gradient to backpropagate through the model to produce class-specific activation maps. Grad-CAM requires:
1. A differentiable model (CNN, transformer)
2. Gradient of the target class output with respect to intermediate feature maps
3. Spatial feature maps from convolutional layers

The ECOC-SVM operates on a **25-dimensional feature vector** derived from Phase 2+3 aggregate statistics. There are no spatial feature maps. Therefore:

**Grad-CAM cannot be applied to the current SVM architecture.**

If Grad-CAM is required by the original project specification, it would require training a separate CNN on the fundus images — this is outside the scope of Phase 5 and would be a separate explainability baseline.

## 3. Implemented Methods

### 3.1 Permutation Feature Importance (Global)

**Method**: For each of 25 features, shuffle that feature across all test samples and measure the drop in referable AUC.

**Results** (Top 5):

| Rank | Feature | AUC Drop |
|------|---------|----------|
| 1 | fov_radius | 0.0995 |
| 2 | retinal_area_fraction | 0.0370 |
| 3 | ex_confidence | 0.0347 |
| 4 | od_radius | 0.0332 |
| 5 | vessel_density | 0.0303 |

**Interpretation**: The SVM relies most heavily on FOV geometry (fov_radius, retinal_area_fraction) and structural features (ex_confidence, od_radius, vessel_density) for referable DR classification. Lesion counts (ma_count, he_count) have smaller but non-zero importance.

**Output**: `results/explainability/feature_importance.csv`, `feature_importance.json`

### 3.2 Perturbation Feature Contribution (Per-Image)

**Method**: For each test image and each feature, replace that feature with the training-set median and measure the change in P(referable). Positive contribution = feature supported the prediction.

**Results**: 15,300 contribution rows (612 images × 25 features)

**Output**: `results/explainability/feature_contributions.csv`

### 3.3 Lesion Evidence Overlays

**Method**: Overlay detected lesion candidates on the fundus image using semi-transparent colored masks:
- Microaneurysms: Red
- Hemorrhages: Magenta
- Exudates: Yellow

**Note**: Phase 3 does not persist binary lesion masks to disk. Overlays are generated from aggregate statistics (count, area) using deterministic synthetic spatial placement within the FOV.

**Output**: `results/explainability/images/{image_id}_overlay.png`

### 3.4 Structure Overlays

**Method**: Annotate anatomical structures on the fundus image:
- FOV boundary: White ring
- Optic disc: Green circle
- Fovea: Blue crosshair

**Output**: `results/explainability/images/{image_id}_structure.png`

### 3.5 Feature-Weighted Spatial Evidence Map

**Method**: Construct a spatial heatmap from lesion masks weighted by their perturbation contributions. This is **NOT Grad-CAM** — it is a feature-weighted evidence map.

**Output**: `results/explainability/images/{image_id}_heatmap.png`

### 3.6 Calibration

**Method**: Bin predicted probabilities into 10 equal-width bins and compare mean predicted probability with observed frequency.

**Results**:

| Metric | Value | Interpretation |
|--------|-------|----------------|
| Brier Score | 0.2621 | Moderate calibration |
| ECE | 0.1258 | 12.6% average calibration error |
| MCE | 0.2037 | 20.4% worst-bin calibration error |
| AUC | 0.7741 | Good discrimination |

**Note**: Discrimination (AUC) and calibration (Brier/ECE) are different properties. The SVM has reasonable discrimination but imperfect calibration.

**Output**: `results/explainability/calibration.json`, `calibration_bins.csv`, `calibration_diagram.png`

### 3.7 Automated Report

**Method**: Generate ophthalmologist-oriented research report including:
- Image metadata and quality
- Model prediction (DR grade, referable status, confidence)
- Structural evidence (OD, fovea, vessels)
- Lesion evidence (MA, HE, EX, NV)
- Top feature contributions
- Calibration metrics
- Review workflow status

**Disclaimer**: All reports state "RESEARCH PROTOTYPE — NOT clinically validated"

**Output**: `results/explainability/reports/{image_id}.md`

### 3.8 Human Review JSON

**Method**: Machine-readable review record with all classification, evidence, and explanation data. Reviewer fields initially empty.

**Output**: `results/explainability/review/{image_id}.json`

## 4. Test Results

### 4.1 Synthetic Tests: 12/12 PASS

| # | Test | Status |
|---|------|--------|
| 1 | Valid normal image overlay | PASS |
| 2 | Missing image handling | PASS |
| 3 | Empty lesion mask | PASS |
| 4 | MA-only mask | PASS |
| 5 | HE-only mask | PASS |
| 6 | EX-only mask | PASS |
| 7 | NV-only mask | PASS |
| 8 | Optic disc overlay | PASS |
| 9 | Fovea overlay | PASS |
| 10 | Contribution calculation | PASS |
| 11 | Heatmap generation | PASS |
| 12 | Malformed input handling | PASS |

### 4.2 Real Test-Set Execution

| Metric | Value |
|--------|-------|
| Total test images | 612 |
| Successfully processed | 581 (95.0%) |
| Failed (image dimension issues) | 31 (5.0%) |
| Phase 3 re-run time | 312.3s (0.51 s/image) |
| Feature importance time | 1.1s |
| Feature contribution time | 51.1s |
| Per-image output time | 595.3s (0.97 s/image) |
| **Total time** | **959.8s (16.0 min)** |

### 4.3 Output Counts

| Output Type | Count |
|-------------|-------|
| Lesion overlays | 612 |
| Structure overlays | 612 |
| Evidence panels | 581 |
| Heatmaps | 581 |
| Reports | 581 |
| Review JSONs | 581 |
| Feature importance | 1 (global) |
| Feature contributions | 15,300 rows |
| Calibration data | 1 (global) |

## 5. Known Limitations

1. **31 images failed** due to odd dimensions in the 2×2 evidence panel. These images still have lesion overlays, structure overlays, and all text outputs.
2. **Lesion masks are synthetic** — Phase 3 does not persist binary masks to disk. Overlays use aggregate statistics with deterministic spatial placement.
3. **Calibration is moderate** — ECE=0.1258 indicates the SVM probabilities are not perfectly calibrated. Platt scaling could improve this.
4. **NV detection has no ground truth** — all NV evidence is research-prototype only.
5. **No CNN explainability baseline** — Grad-CAM not applicable to SVM.

## 6. Phase 1–4 Preservation Confirmation

- Phase 4 metrics unchanged: accuracy=0.6324, macroAUC=0.8095, referableAUC=0.7741
- Feature ordering preserved: 25 features match `buildClassificationFeatures.m`
- Data splits preserved: seed=42, patient-level, 70/15/15
- No dataset modifications
- No model retraining beyond deterministic re-creation

## 7. Disclaimers

- RESEARCH PROTOTYPE — NOT clinically validated
- All thresholds PROVISIONAL/THEORETICAL
- Screening decisions require qualified ophthalmologist review
- Phase 3 lesion detections are CANDIDATES, not confirmed diagnoses
- Feature contributions are perturbation-based, NOT causal
- Spatial evidence maps are NOT Grad-CAM
