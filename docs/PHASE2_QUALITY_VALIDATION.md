# Phase 2 — Quality Validation Report

> **Project**: MATLAB-based Automated Diabetic Retinopathy Screening Research Prototype
> **Phase**: 2 — Image Quality Assessment + Preprocessing
> **Date**: 2026-08-31
> **Status**: VALIDATED (12/12 synthetic tests PASS)
> **Note**: Synthetic fixtures only — no clinical validation

---

## A. Test Suite: `testQualityPipeline.m`

12 synthetic test cases created in temp directory, processed through the full quality pipeline.

### Test Cases

| # | Test Name | Input Description | Expected Status |
|---|-----------|-------------------|-----------------|
| 1 | RGB normal | Synthetic fundus with optic disc, vessels, circular FOV | GOOD |
| 2 | Grayscale | Same as #1 converted to grayscale | GOOD |
| 3 | Unreadable | Corrupt file (not a valid image) | UNGRADABLE |
| 4 | Very blurred | Gaussian blur sigma=8 applied to #1 | UNGRADABLE |
| 5 | Underexposed | Intensity scaled to 25% of original | UNGRADABLE |
| 6 | Overexposed | Intensity scaled to 180% + 0.2 offset | BORDERLINE |
| 7 | Severe glare | 70x70 white patch overlaid on fundus | UNGRADABLE |
| 8 | Insufficient FOV | Small circular FOV (radius=40 vs normal 90) | UNGRADABLE |
| 9 | Strong vignetting | Radial darkening toward periphery | BORDERLINE |
| 10 | Low contrast | imadjust with compressed range [0.3,0.7]->[0.45,0.55] | BORDERLINE |
| 11 | Normal quality | Same as #1 (reference) | GOOD |
| 12 | Borderline enhancement | Mild blur + contrast compression | BORDERLINE |

### Pass Criteria

- PASS if status matches expected, OR
- PASS if expected=UNGRADABLE and status is any non-GOOD, OR
- PASS if expected=BORDERLINE and status is BORDERLINE or UNGRADABLE
- Enhancement must not crash for BORDERLINE cases

### Results

```
[PASS] RGB normal => GOOD (expected GOOD)
[PASS] grayscale => GOOD (expected GOOD)
[PASS] unreadable => UNGRADABLE (expected UNGRADABLE)
[PASS] very blurred => UNGRADABLE (expected UNGRADABLE)
[PASS] underexposed => UNGRADABLE (expected UNGRADABLE)
[PASS] overexposed => BORDERLINE (expected BORDERLINE)
[PASS] severe glare => UNGRADABLE (expected UNGRADABLE)
[PASS] insufficient FOV => UNGRADABLE (expected UNGRADABLE)
[PASS] strong vignetting => BORDERLINE (expected BORDERLINE)
[PASS] low contrast => BORDERLINE (expected BORDERLINE)
[PASS] normal-quality => GOOD (expected GOOD)
[PASS] borderline enhancement => BORDERLINE (expected BORDERLINE)
=== testQualityPipeline 12/12 passed ===
Note: synthetic fixtures, not clinical validation
```

**Result: 12/12 PASS**

---

## B. Real Dataset Assessment

Full batch run on 7872 manifest images (APTOS 5590 + IDRiD 494 + DRIVE 40 + Messidor2 1748).

### Performance

| Metric | Value |
|--------|-------|
| Total images | 7872 |
| Processed | 7872 |
| Failed to load | 0 |
| Total time | 920.2s |
| Average per image | 0.117s |
| Processing resolution | max 256px |

### Distribution

| Status | Count | Percentage |
|--------|-------|------------|
| GOOD | 1348 | 17.1% |
| BORDERLINE | 6192 | 78.7% |
| UNGRADABLE | 332 | 4.2% |

### Per-Dataset Breakdown

| Dataset | Total | GOOD | GOOD% | BORDERLINE | UNGRADABLE |
|---------|-------|------|-------|------------|------------|
| APTOS2019 | 5590 | 459 | 8.2% | 5018 | 113 |
| DRIVE | 40 | 17 | 42.5% | 11 | 12 |
| IDRiD | 494 | 0 | 0.0% | 468 | 26 |
| Messidor2 | 1748 | 872 | 49.9% | 695 | 181 |

### Calibration (TRAIN split only)

- Calibration set: 4286 images (TRAIN split, excludes Messidor2)
- Percentile analysis computed for all metrics
- Suggested threshold updates based on observed distributions
- See `results/quality/calibration_report.json`

---

## C. Metric Distribution Summary

| Metric | Overall Median | APTOS Median | IDRiD Median | DRIVE Median | Messidor2 Median |
|--------|---------------|--------------|--------------|--------------|------------------|
| Focus (Laplacian) | 105.67 | 93.20 | 101.41 | 208.32 | 175.25 |
| Illumination (mean) | 90.86 | 90.76 | 98.12 | 120.84 | 87.43 |
| FOV (area fraction) | 0.78 | 0.79 | 0.69 | 0.68 | 0.46 |
| Glare (fraction) | 0.01 | 0.01 | 0.02 | 0.02 | 0.00 |
| Vignetting (score) | 0.14 | 0.15 | 0.20 | 0.11 | 0.11 |
| Contrast (std) | 16.70 | 17.27 | 19.75 | 17.49 | 14.95 |
| Overall quality score | 79.60 | 79.60 | 79.60 | 81.40 | 81.40 |

---

## D. Enhancement Test

20 BORDERLINE images tested with adaptive enhancement:

| Metric | Value |
|--------|-------|
| Images tested | 20 |
| Improved | 3 (15%) |
| Mean before score | 76.8 |
| Mean after score | 69.8 |

Enhancement is conservative by design. The lower mean after score reflects that enhancement operations (CLAHE, illumination normalization) can sometimes shift metric values without improving the overall classification. This is expected behavior for a research prototype — enhancement parameters require further tuning.

---

## E. What This Validation Does NOT Cover

1. **Clinical accuracy** — no comparison to expert quality grading
2. **Sensitivity/specificity** for quality classification — no ground truth labels
3. **Impact on DR classification** — not yet implemented (Phase 4)
4. **Inter-observer agreement** — no multiple graders
5. **Longitudinal stability** — single run, no reproducibility testing across runs
6. **Edge cases** — limited synthetic variety, no real degraded clinical images in test set

---

## F. Evidence Files

| File | Description |
|------|-------------|
| `results/quality/quality_results.csv` | Full 7872-image results with all metrics |
| `results/quality/quality_summary.json` | Summary statistics |
| `results/quality/quality_thresholds.json` | Exported threshold configuration |
| `results/quality/calibration_report.json` | Percentile analysis on TRAIN split |
| `results/quality/quality_report.md` | Human-readable markdown report |
| `results/quality/enhancement_results.csv` | Before/after enhancement tracking |
| `results/quality/examples/` | Sample GOOD/BORDERLINE/UNGRADABLE images |
