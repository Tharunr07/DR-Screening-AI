# Phase 2 — Image Quality Assessment + Adaptive Enhancement

> **Project**: MATLAB-based Automated Diabetic Retinopathy Screening Research Prototype
> **Phase**: 2 — Image Quality Assessment + Preprocessing
> **Date**: 2026-08-31
> **Status**: IMPLEMENTED — full 7872-image assessment complete
> **MATLAB**: R2026a, Image Processing Toolbox, Computer Vision Toolbox, Statistics & ML Toolbox
> **Working directory**: `C:\dev\SIH\DR_Screening`

**This is a research prototype. Quality thresholds are THEORETICAL / INITIAL and NOT clinically validated.**

---

## A. Scope

Phase 2 implements the image quality assessment pipeline that sits between raw fundus images and downstream DR classification (Phase 4). It determines whether each image is suitable for automated analysis.

### In scope

- 7 quality metrics: Focus, Illumination, FOV, Glare, Vignetting, Contrast, Retinal Visibility
- Rule-based classification: GOOD / BORDERLINE / UNGRADABLE
- Adaptive enhancement for BORDERLINE images (CLAHE, illumination normalization, denoising)
- Batch processing of all 7872 manifest images
- Calibration analysis on TRAIN split (no data leakage)
- Structured recapture feedback for UNGRADABLE images

### Out of scope (Phase 3+)

- DR classification, lesion detection, microaneurysm/hemorrhage/exudate detection
- Grad-CAM, explainability, clinical performance metrics
- Simulink system modeling

---

## B. Architecture

```
Fundus Image
    |
    v
loadImageSafe (Phase 1)
    |
    v
estimateRetinalMask (Otsu + morphology)
    |
    +---> assessFocus (Laplacian, Tenengrad, Brenner, edge density)
    +---> assessIllumination (mean, std, uniformity, dark/saturated fractions)
    +---> assessFOV (area fraction, diameter, completeness, truncation)
    +---> assessGlare (saturated region detection inside retina)
    +---> assessVignetting (radial center-vs-periphery falloff)
    +---> assessContrast (std, RMS, entropy, local contrast)
    +---> assessRetinalArea (visible/obscured fraction)
    |
    v
classifyQuality (rule-based GOOD/BORDERLINE/UNGRADABLE)
    |
    +---> GOOD: pass through to downstream
    +---> BORDERLINE: enhanceBorderlineImage -> reassess
    +---> UNGRADABLE: structured recapture recommendation
```

---

## C. Files Created

All files in `matlab/quality/`:

| File | Purpose |
|------|---------|
| `qualityConfig.m` | Central thresholds (THEORETICAL / INITIAL), paths, enhancement parameters |
| `estimateRetinalMask.m` | Otsu + morphology retinal field estimator (shared by all metrics) |
| `assessFocus.m` | Laplacian variance, Tenengrad, Brenner gradient, edge density |
| `assessIllumination.m` | Mean, std, uniformity, dark/saturated fractions inside retina |
| `assessFOV.m` | Area fraction, diameter, completeness, truncation detection |
| `assessGlare.m` | Saturated region detection with noise filtering |
| `assessVignetting.m` | Radial illumination falloff (center vs periphery) |
| `assessContrast.m` | Std, RMS, entropy, percentile spread, local contrast |
| `assessRetinalArea.m` | Visible/obscured fraction inside retinal mask |
| `assessImageQuality.m` | Per-image orchestrator (calls all 7 metrics + classify) |
| `classifyQuality.m` | Rule-based GOOD/BORDERLINE/UNGRADABLE decision |
| `enhanceBorderlineImage.m` | Adaptive CLAHE, illumination normalization, denoising |
| `runQualityAssessment.m` | Batch orchestrator (7872 images), writes CSV/JSON/MAT |
| `calibrateQualityThresholds.m` | Percentile analysis on TRAIN split only |
| `generateQualityReport.m` | Markdown report generator |
| `testQualityPipeline.m` | 12 synthetic test cases |

---

## D. Quality Metrics

### D.1 Focus / Sharpness

**Method**: Variance of Laplacian, Tenengrad (mean Sobel gradient magnitude squared), Brenner gradient, Canny edge density — all computed inside retinal mask.

**Thresholds** (THEORETICAL, from literature typical ranges):

| Metric | GOOD | BORDERLINE | UNGRADABLE |
|--------|------|------------|------------|
| Laplacian variance | >= 30 | >= 10 | < 10 |
| Tenengrad | >= 500 | >= 150 | < 150 |
| Edge density | >= 0.0005 | >= 0.0002 | < 0.0002 |

**Observed distribution** (TRAIN split, 4286 images):
- Laplacian: median 93.8, p25 64.6, p75 123.3
- Tenengrad: median 1873, p25 1286, p75 2574

### D.2 Illumination

**Method**: Mean intensity, std, uniformity (std/mean), dark pixel fraction (<30), saturated pixel fraction (>250) — all inside retinal mask.

**Thresholds** (THEORETICAL):

| Metric | GOOD | BORDERLINE | UNGRADABLE |
|--------|------|------------|------------|
| Mean intensity | 55-185 | outside range | < 30 or > 220 |
| Dark fraction | <= 0.22 | <= 0.35 | > 0.35 |
| Saturated fraction | <= 0.025 | <= 0.06 | > 0.06 |
| Uniformity (std/mean) | <= 0.38 | <= 0.55 | > 0.55 |

**Observed**: median mean 91.3, p10 62.5, p90 112.6

### D.3 Field of View

**Method**: Retinal mask area fraction, equivalent diameter, border completeness (perimeter vs ideal ellipse), truncation detection (border touch fraction).

**Thresholds** (THEORETICAL):

| Metric | GOOD | BORDERLINE | UNGRADABLE |
|--------|------|------------|------------|
| Area fraction | >= 0.18 | >= 0.10 | < 0.10 |
| Completeness | >= 0.65 | >= 0.45 | < 0.45 |
| Truncation | < 50% border touch | - | > 50% |

**Observed**: median areaFraction 0.79, p25 0.74, p75 0.90

### D.4 Glare

**Method**: Saturated pixels (>250) inside retinal mask, connected component analysis, noise filtering (remove <0.02% specks).

**Thresholds** (THEORETICAL):

| Metric | GOOD | BORDERLINE | UNGRADABLE |
|--------|------|------------|------------|
| Fraction | <= 0.04 | <= 0.08 | > 0.08 |
| Largest region fraction | <= 0.03 | <= 0.06 | > 0.06 |

**Observed**: median fraction 0.011, p90 0.025

### D.5 Vignetting

**Method**: Radial illumination profile from mask centroid, center vs outermost ring intensity ratio.

**Thresholds** (THEORETICAL):

| Metric | GOOD | BORDERLINE | UNGRADABLE |
|--------|------|------------|------------|
| Score (center-periphery)/center | <= 0.35 | <= 0.55 | > 0.55 |

**Observed**: median 0.16, p90 0.33

### D.6 Contrast

**Method**: Std, RMS contrast (std/mean), Shannon entropy, percentile spread (p95-p5), local contrast (16x16 block std).

**Thresholds** (THEORETICAL):

| Metric | GOOD | BORDERLINE | UNGRADABLE |
|--------|------|------------|------------|
| Std | >= 14 | >= 8 | < 8 |
| RMS | >= 0.10 | >= 0.06 | < 0.06 |
| Entropy | >= 0.6 | >= 0.3 | < 0.3 |

**Observed**: median std 17.6, p25 14.3, p75 22.1; median entropy 5.90

### D.7 Retinal Visibility

**Method**: Retinal area fraction, visible fraction (not dark/saturated), obscured fraction.

**Thresholds** (THEORETICAL):

| Metric | GOOD | BORDERLINE | UNGRADABLE |
|--------|------|------------|------------|
| Area fraction | >= 0.28 | >= 0.16 | < 0.16 |
| Visible fraction | >= 0.78 | >= 0.60 | < 0.60 |

**Observed**: median visibleFraction 0.987, p5 0.966

---

## E. Classification Logic

```
ANY metric == UNGRADABLE  =>  UNGRADABLE
ALL metrics == GOOD       =>  GOOD
1-4 metrics == BORDERLINE =>  BORDERLINE
>4 metrics == BORDERLINE  =>  UNGRADABLE (multiple failures)
```

**Overall quality score**: Weighted sum of per-metric scores (GOOD=85, BORDERLINE=55, UNGRADABLE=20) normalized to 0-100.

Weights: focus 0.22, illumination 0.18, FOV 0.18, glare 0.12, vignetting 0.08, contrast 0.12, retinal 0.10.

---

## F. Enhancement (BORDERLINE only)

Applied operations (adaptive, based on which metrics are borderline):

1. **CLAHE** (Contrast Limited Adaptive Histogram Equalization) — for LOW_CONTRAST / BORDERLINE_CONTRAST
   - ClipLimit: 2.0, NumTiles: [8 8], Distribution: rayleigh
   - Applied on L channel in Lab color space

2. **Illumination normalization** — for NONUNIFORM_ILLUMINATION / SEVERE_DARK / VIGNETTING
   - Large Gaussian background estimation (sigma=30)
   - V_norm = V / (bg + 0.1) * mean(bg)

3. **Denoising** (median filter 3x3) — for BORDERLINE_FOCUS with GOOD contrast (suggests noise)

After enhancement, quality is reassessed. If the enhanced image is worse, the original is kept.

---

## G. Performance Optimization

Images are resized to max 256px for metric computation (original kept for enhancement). This reduces per-image time from ~1.5s to ~0.12s while preserving metric fidelity for quality decisions.

**Benchmark** (7872 images):
- Total time: 920s (15.3 min)
- Average: 0.117s/image
- Processing size: typically 192x256

---

## H. Results Summary

### Overall (7872 images)

| Status | Count | Percentage |
|--------|-------|------------|
| GOOD | 1348 | 17.1% |
| BORDERLINE | 6192 | 78.7% |
| UNGRADABLE | 332 | 4.2% |

### Per-Dataset

| Dataset | Total | GOOD | GOOD% | BORDERLINE | UNGRADABLE |
|---------|-------|------|-------|------------|------------|
| APTOS2019 | 5590 | 459 | 8.2% | 5018 | 113 |
| DRIVE | 40 | 17 | 42.5% | 11 | 12 |
| IDRiD | 494 | 0 | 0.0% | 468 | 26 |
| Messidor2 | 1748 | 872 | 49.9% | 695 | 181 |

### Top Quality Reasons

| Reason | Count |
|--------|-------|
| BORDERLINE_FOV | 5448 |
| BORDERLINE_CONTRAST | 2053 |
| OK | 1348 |
| BORDERLINE_ILLUMINATION | 568 |
| BORDERLINE_VIGNETTING | 500 |
| BORDERLINE_FOCUS | 244 |
| BORDERLINE_GLARE | 237 |
| EXCESSIVE_GLARE | 234 |

### Enhancement (BORDERLINE subset)

Tested on 20 BORDERLINE images: 3/20 improved (score increased). Enhancement is conservative by design — it does not force improvement.

---

## I. Threshold Provenance

All thresholds are explicitly classified:

| Threshold | Source | Status |
|-----------|--------|--------|
| Focus (Laplacian, Tenengrad) | Literature typical ranges for fundus imaging | THEORETICAL |
| Illumination (mean, dark/sat fractions) | Literature + robust statistics on pilot data | THEORETICAL |
| FOV (area fraction, completeness) | Geometric reasoning on circular FOV | THEORETICAL |
| Glare (saturation fraction) | Literature on specular artifact detection | THEORETICAL |
| Vignetting (radial falloff) | Literature on lens shading correction | THEORETICAL |
| Contrast (std, RMS, entropy) | Statistics on pilot data | THEORETICAL |
| Retinal visibility | Derived from FOV + illumination | THEORETICAL |
| Decision (maxBorderlineMetrics) | Conservative research prototype choice | PROVISIONAL |
| Enhancement (CLAHE, illum norm) | Standard image processing operations | THEORETICAL |

**No clinical validation has been performed.** QUALITY LABELS are NOT AVAILABLE — no human ground truth for quality assessment. Thresholds will be re-evaluated when clinical quality labels become available.

---

## J. Data Leakage Prevention

- Calibration (`calibrateQualityThresholds.m`) uses TRAIN split only (4286 images)
- Messidor2 (1748 images) is observed but never used for threshold tuning
- Enhancement parameters are fixed in `qualityConfig.m`, not tuned on test data
- No test/validation labels are used in quality decisions

---

## K. Output Contract

### quality_results.csv

Standard output interface for downstream modules (Phase 3+ DR classifier):

| Column | Type | Description |
|--------|------|-------------|
| image_id | string | Unique image identifier |
| dataset | string | Dataset name (APTOS2019, IDRiD, DRIVE, Messidor2) |
| file_path | string | Relative path to image |
| split | string | train/val/test/external |
| quality_status | string | GOOD/BORDERLINE/UNGRADABLE |
| overall_quality_score | double | 0-100 weighted quality score |
| quality_reasons | string | Semicolon-separated reasons |
| failed_metrics | string | UNGRADABLE metrics |
| borderline_metrics | string | BORDERLINE metrics |
| recapture_code | string | Machine-readable recapture recommendation |
| recapture_human | string | Human-readable recapture message |
| focus_laplacian | double | Raw Laplacian variance |
| focus_tenengrad | double | Raw Tenengrad value |
| focus_edgeDensity | double | Raw edge density |
| focus_status | string | GOOD/BORDERLINE/UNGRADABLE |
| illum_mean | double | Mean intensity inside retina |
| illum_darkFraction | double | Fraction of dark pixels |
| illum_satFraction | double | Fraction of saturated pixels |
| illum_uniformity | double | std/mean ratio |
| illum_status | string | GOOD/BORDERLINE/UNGRADABLE |
| fov_areaFraction | double | Retinal area / image area |
| fov_diameter | double | Equivalent diameter (pixels) |
| fov_completeness | double | Border completeness |
| fov_truncated | logical | Whether FOV touches border |
| fov_status | string | GOOD/BORDERLINE/UNGRADABLE |
| glare_fraction | double | Saturated fraction inside retina |
| glare_regionCount | int | Number of glare regions |
| glare_status | string | GOOD/BORDERLINE/UNGRADABLE |
| vignetting_score | double | Center-periphery ratio |
| vignetting_status | string | GOOD/BORDERLINE/UNGRADABLE |
| contrast_std | double | Std intensity inside retina |
| contrast_rms | double | RMS contrast |
| contrast_entropy | double | Shannon entropy (bits) |
| contrast_status | string | GOOD/BORDERLINE/UNGRADABLE |
| retinal_areaFraction | double | Retinal area fraction |
| retinal_visibleFraction | double | Usable retina / total retina |
| retinal_status | string | GOOD/BORDERLINE/UNGRADABLE |
| enhanced | logical | Whether enhancement was attempted |
| enhancement_applied | string | Operations applied |
| enhancement_improved | logical | Whether score improved |
| before_score | double | Score before enhancement |
| after_score | double | Score after enhancement |

### manifest_with_quality.csv

Extended manifest with quality columns appended (generated by `runQualityAssessment`):
- `quality_status` — GOOD/BORDERLINE/UNGRADABLE/UNKNOWN
- `quality_score` — 0-100 or NaN
- `quality_reasons` — semicolon-separated reasons

---

## L. Recapture Recommendations

For UNGRADABLE images, the system generates structured feedback:

| recapture_code | recapture_human |
|----------------|-----------------|
| RECAPTURE_BLUR | Image is too blurred. Hold the phone/camera steady and recapture. |
| RECAPTURE_INSUFFICIENT_FOV | Insufficient retinal field visible. Reposition the camera and recapture. |
| RECAPTURE_EXCESSIVE_GLARE | Excessive glare detected. Adjust illumination and recapture. |
| RECAPTURE_SEVERE_UNDEREXPOSURE | Image is severely underexposed/dark. Increase illumination and recapture. |
| RECAPTURE_SEVERE_OVEREXPOSURE | Image is severely overexposed/bright. Reduce illumination and recapture. |
| RECAPTURE_SEVERE_VIGNETTING | Severe vignetting detected. Check camera alignment and recapture. |
| RECAPTURE_LOW_CONTRAST | Image has insufficient contrast. Adjust camera settings and recapture. |
| RECAPTURE_MULTIPLE_QUALITY_FAILURES | Multiple quality issues detected. Recapture is recommended. |
| RECAPTURE_UNREADABLE | Image could not be read. Ensure the file is a valid fundus photograph and recapture. |

---

## M. Known Limitations

1. **Thresholds are THEORETICAL** — not clinically validated, no ROC/AUC computation possible without quality labels
2. **Retinal mask estimation** may fail on severely degraded images (fallback to whole image)
3. **Glare vs optic disc** distinction is heuristic (optic disc is bright but typically <250, while glare is >250)
4. **FOV truncation** detection uses border touch fraction, which may be conservative for images with natural retinal boundary near border
5. **Enhancement is conservative** — only 3/20 test images improved; designed to not make things worse rather than guarantee improvement
6. **Processing at 256px** reduces computation time but may miss very fine artifacts visible only at full resolution
7. **No clinical ground truth** for quality — the system cannot validate whether GOOD images are truly clinically usable

---

## N. Remaining Research Questions

1. What are the clinically appropriate quality thresholds for each metric?
2. What is the optimal balance between sensitivity (catching truly bad images) and specificity (not rejecting usable images)?
3. Should enhancement be more aggressive, or is conservative enhancement appropriate for a screening prototype?
4. How do quality metrics correlate with downstream DR classification performance?
5. Would a learned quality classifier (trained on human quality labels) outperform rule-based thresholds?

---

## O. Exact Next Step

Phase 2 is COMPLETE. The quality pipeline is implemented, tested (12/12 synthetic cases), and has produced results on all 7872 images.

**Next phase**: Phase 3 — Retinal Structures + Lesion Analysis

Phase 3 will consume the `quality_status` and `quality_score` columns from this output contract to ensure only suitable images proceed to structure/lesion analysis.
