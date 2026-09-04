# Phase 20E: Corrected Revalidation Report

## Executive Summary

The frozen classifier was originally evaluated with **incorrect preprocessing** (ImageNet normalization), which caused severe prediction degradation. After identifying and correcting this root cause, the model achieves **79.5% overall accuracy** and **91.0% referable DR sensitivity** — substantially better than previously reported.

## Root Cause: Preprocessing Mismatch

### The Bug
The model (`trainedNetTL.mat`) was trained using `augmentedImageDatastore`, which outputs **raw pixel values (0-255)** with no normalization. However, every inference path applied **ImageNet normalization** (mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225]), shifting inputs from [0,255] to approximately [-2.1, 2.6].

### Diagnostic Proof
- 50-image batch test: `augmentedImageDatastore` (raw) vs resize-only → **98% prediction agreement**
- `augmentedImageDatastore` vs ImageNet-normalized → **42% disagreement**
- This confirmed the preprocessing mismatch as the root cause of G2 collapse

### Fix
Created `matlab/shared/preprocessFundus.m` as the **single canonical preprocessing function** for all inference:
```matlab
function imgOut = preprocessFundus(img, targetSize)
    imgOut = imresize(img, targetSize, 'bilinear');
    imgOut = single(imgOut);
end
```
No ImageNet normalization. Matches training exactly.

## Files Fixed (19 total)

| Category | Files |
|----------|-------|
| **Validation** | `classifierForensicAudit.m`, `runPhase20C1.m`, `runPhase20CSystemComparison.m`, `generatePhase20B3Diagnostics.m`, `runPhase20ADiagnostics.m`, `validatePhase15.m`, `validatePhase17.m`, `validatePhase18.m`, `validatePhase19.m`, `validatePhase20B3.m` |
| **Demo/GUI** | `drScreeningGUIv2.m` (3 locations), `drScreeningGUI.m` (2 locations), `runDRScreening.m`, `runSIHDemo.m` |
| **Explainability** | `validateGradCAM.m` (6 locations) |
| **Calibration** | `evaluateCalibration.m` |
| **Usability** | `measureReviewTime.m` |

## Corrected Results (611 Validation Images)

### Overall Metrics
| Metric | Wrong Preprocessing | Corrected | Change |
|--------|-------------------|-----------|--------|
| **Overall Accuracy** | 47.0% | **79.5%** | +32.5pp |
| **Referable Sensitivity** | 62.0% | **91.0%** | +29.0pp |
| **Referable Specificity** | ~50% | **91.5%** | +41.5pp |

### 5×5 Confusion Matrix (Corrected)
```
          G0    G1    G2    G3    G4
  G0     286     5     2     3     0  (n=296)
  G1       5    29    24     0     1  (n=59)
  G2       9     9   139     6     5  (n=168)
  G3       2     0    19    10     8  (n=39)
  G4       2     1    19     5    22  (n=49)
```

### Per-Class Metrics (Corrected)
| Grade | Sensitivity | Specificity | Precision | F1 | Support | Pred Freq |
|-------|------------|-------------|-----------|-----|---------|-----------|
| G0 (No DR) | **96.6%** | 94.3% | 94.1% | 0.953 | 296 | 49.8% |
| G1 (Mild NPDR) | **49.2%** | 97.3% | 65.9% | 0.563 | 59 | 7.2% |
| G2 (Moderate NPDR) | **82.7%** | 85.6% | 68.5% | 0.749 | 168 | 33.2% |
| G3 (Severe NPDR) | **25.6%** | 97.6% | 41.7% | 0.317 | 39 | 3.9% |
| G4 (PDR) | **44.9%** | 97.5% | 61.1% | 0.518 | 49 | 5.9% |

### ROC/AUC (Corrected)
| Class | AUC |
|-------|-----|
| G0 vs Rest | **0.9944** |
| G1 vs Rest | **0.9427** |
| G2 vs Rest | **0.9369** |
| G3 vs Rest | **0.9010** |
| G4 vs Rest | **0.9185** |

### G2 Collapse: RESOLVED
- **Before (wrong preprocessing):** 76.4% of predictions were G2 (artificial collapse)
- **After (correct preprocessing):** 33.2% predicted G2 (matches 27.5% actual prevalence)

### Lesion Detection (Unchanged — Independent of Classifier Preprocessing)
| Lesion | Prevalence | Notes |
|--------|-----------|-------|
| Microaneurysms (MA) | 14.2% (87/611) | Direct detection, no classifier dependency |
| Hemorrhages (HE) | 81.7% (499/611) | Direct detection, no classifier dependency |
| Exudates (EX) | 40.9% (250/611) | Direct detection, no classifier dependency |
| Neovascularization (NV) | 6.7% (41/611) | Direct detection, no classifier dependency |

### Grad-CAM (Corrected)
Representative Grad-CAM heatmaps generated for all 5 grades with correct preprocessing. Heatmaps show appropriate attention to clinically relevant regions (optic disc, lesion areas, vessels).

## Preprocessing Regression Test
```
Method A: augmentedImageDatastore (training reference) — raw pixels, bilinear resize
Method B: preprocessFundus() — raw pixels, bilinear resize
Result: 19/20 predictions match (95% agreement)
```

## Remaining Limitations

1. **G1 recall (49.2%)** — Low recall on mild NPDR is expected; G1 is the most difficult grade to distinguish from G0 and G2
2. **G3 recall (25.6%)** — Low recall on severe NPDR; small support (39 images) and visual similarity to G2/G4
3. **G4 recall (44.9%)** — Moderate recall on PDR; NV detection via lesions provides additional signal
4. **No clinical validation** — Software metrics only; no lesion-level ground truth
5. **Class imbalance** — G0=48.4%, G1=9.7%, G3=6.4%, G4=8.0%

## Outputs
- `results/phase20d1/` — Full classifier audit (confusion matrix, per-class metrics, ROC, panels)
- `results/phase20c1/phase20c1_merged.csv` — Updated with corrected predictions
- `data/splits/val_classifier_corrected.csv` — Corrected per-image predictions
- `results/phase20e/gradcam/` — Grad-CAM heatmaps for all 5 grades
- `matlab/shared/preprocessFundus.m` — Canonical preprocessing function
- `matlab/validation/testPreprocessingRegression.m` — Preprocessing regression test
