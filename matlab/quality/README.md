# matlab/quality/ — Phase 2: Image Quality Assessment + Adaptive Enhancement

**Status: IMPLEMENTED**

7872 images assessed. 12/12 synthetic tests PASS. See `docs/PHASE2_QUALITY_ASSESSMENT.md`.

## Modules

| File | Purpose |
|------|---------|
| `qualityConfig.m` | Central thresholds (THEORETICAL), paths, enhancement params |
| `estimateRetinalMask.m` | Otsu + morphology retinal field estimator |
| `assessFocus.m` | Laplacian, Tenengrad, Brenner, edge density |
| `assessIllumination.m` | Mean, std, uniformity, dark/saturated fractions |
| `assessFOV.m` | Area fraction, diameter, completeness, truncation |
| `assessGlare.m` | Saturated region detection inside retina |
| `assessVignetting.m` | Radial center-vs-periphery falloff |
| `assessContrast.m` | Std, RMS, entropy, local contrast |
| `assessRetinalArea.m` | Visible/obscured fraction |
| `assessImageQuality.m` | Per-image orchestrator |
| `classifyQuality.m` | Rule-based GOOD/BORDERLINE/UNGRADABLE |
| `enhanceBorderlineImage.m` | Adaptive CLAHE, illumination normalization, denoising |
| `runQualityAssessment.m` | Batch orchestrator (7872 images) |
| `calibrateQualityThresholds.m` | Percentile analysis on TRAIN split |
| `generateQualityReport.m` | Markdown report generator |
| `testQualityPipeline.m` | 12 synthetic test cases |

## Quick Start

```matlab
addpath(genpath('matlab'));
cfg = qualityConfig();
stats = runQualityAssessment('maxImages', 100, 'verbose', true);
generateQualityReport();
```

## Output Contract

`quality_results.csv` provides the standard interface for downstream modules (Phase 3+ DR classifier).
Columns: image_id, dataset, split, quality_status, overall_quality_score, all raw metrics, enhancement flags.
See `docs/PHASE2_QUALITY_ASSESSMENT.md` section K for full schema.

## Threshold Status

All thresholds are THEORETICAL / INITIAL. Not clinically validated. QUALITY LABELS = NOT AVAILABLE.
See `quality_thresholds.json` and `calibration_report.json`.
