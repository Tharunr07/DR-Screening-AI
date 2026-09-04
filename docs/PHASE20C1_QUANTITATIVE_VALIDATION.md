# Phase 20C.1: Full Quantitative Validation (611 Labeled Images)

**Date**: 2026-09-04
**Status**: COMPLETE
**Scope**: All 611 labeled validation images (APTOS + IDRiD)

## Summary

All 611 labeled validation images processed through the corrected lesion pipeline
(MA/HE/EX/NV detectors + Grad-CAM + clinical logic + frozen classifier).
This is the first full quantitative assessment of the corrected system.

## Classifier Accuracy (Frozen Model — Do Not Modify)

| Metric | Value |
|--------|-------|
| Grade match | 47.0% (287/611) |
| Referable match | 62.0% (379/611) |

### Per-Grade Breakdown

| Grade | n | Grade Accuracy | Referable Accuracy |
|-------|-----|----------------|-------------------|
| G0 | 296 | 42.9% | 49.7% |
| G1 | 59 | 0.0% | 5.1% |
| G2 | 168 | 94.6% | 88.7% |
| G3 | 39 | 0.0% | 89.7% |
| G4 | 49 | 2.0% | 91.8% |

### Grade Confusion Matrix

```
Pred->  G0    G1    G2    G3    G4
Act G0:  127     0   169     0     0
Act G1:    2     0    57     0     0
Act G2:    8     0   159     0     1
Act G3:    3     0    35     0     1
Act G4:    1     0    47     0     1
```

**Key finding**: The classifier has a strong G2 bias. G1, G3, G4 are almost always
predicted as G2. Only G0 vs G2 shows meaningful discrimination. This is inherent
to the frozen model from Phase 8 training — not a pipeline bug.

## Lesion Detection Results

| Lesion | Median | Mean | P90 | P95 | P99 | Max | Prevalence | Density P95 |
|--------|--------|------|-----|-----|-----|-----|-----------|-------------|
| MA | 0 | 0.40 | 1 | 2 | 10 | 15 | 14.2% (87/611) | 4.0/Mpx |
| HE | 2 | 2.86 | 6 | 8 | 13.4 | 20 | 81.7% (499/611) | 4.9/Mpx |
| EX | 0 | 1.26 | 4 | 6 | 12.4 | 23 | 40.9% (250/611) | 2.7/Mpx |
| NV | — | — | — | — | — | — | 6.7% (41/611) | — |

**Total lesions**: median=3, mean=4.59, P95=15, P99=24, max=38

### Notes on Detection Patterns
- HE is the most prevalent lesion type (81.7%), consistent with fundus photography characteristics
- MA prevalence is low (14.2%) — may indicate under-detection or the specific APTOS/IDRiD populations
- NV detection (6.7%) is plausible for a screening dataset
- The wide range of outliers (max 38 total lesions) warrants forensic review

## Quality Gate Analysis

| Category | Count | Percentage |
|----------|-------|-----------|
| GOOD | 0 | 0.0% |
| BORDERLINE | 559 | 91.5% |
| POOR | 52 | 8.5% |

### Rejection Reasons
- Brightness < 40: 41 (6.7%)
- Brightness > 220: 0 (0.0%)
- Contrast < 20: 17 (2.8%)
- **Sharpness < 100: 611 (100.0%)**

**Critical issue**: The sharpness metric (`var(Laplacian(conv))`) is consistently
below 100 for ALL 611 images. This means the sharpness gate never rejects — it
always falls through to BORDERLINE or POOR based on other criteria. The threshold
needs investigation: either the metric scale is wrong, or the threshold should be
recalibrated to the actual distribution of this metric.

## Outlier Detection

16 images flagged as outliers (any lesion count > P99 threshold):

| # | Image | Grade | Size | MA | HE | EX | NV | Total |
|---|-------|-------|------|----|----|----|----|----|
| 1 | 0b64a0a06f9a | G0 | 819×614 | 12 | 5 | 1 | 1 | 19 |
| 2 | 2c2aa057afc5 | G2 | 1504×1000 | 0 | 15 | 3 | 0 | 18 |
| 3 | 3a122851e526 | G2 | 640×480 | 6 | 5 | 13 | 0 | 24 |
| 4 | 3c42512c81e0 | G0 | 1050×1050 | 15 | 1 | 0 | 1 | 17 |
| 5 | 4189d4e631ec | G2 | 2416×1736 | 0 | 15 | 3 | 0 | 18 |
| 6 | 4abca30b676b | G4 | 2416×1736 | 0 | 13 | 13 | 0 | 26 |
| 7 | 4b618537d52f | G3 | 2416×1736 | 0 | 15 | 4 | 0 | 19 |
| 8 | 54cab3596214 | G2 | 1050×1050 | 0 | 14 | 19 | 1 | 34 |
| 9 | 5dd2e26fc244 | G4 | 1050×1050 | 0 | 20 | 0 | 0 | 20 |
| 10 | 96793edb1003 | G0 | 819×614 | 10 | 5 | 10 | 0 | 25 |
| 11 | 9a4f370d341b | G2 | 2416×1736 | 0 | 7 | 15 | 0 | 22 |
| 12 | b9fe7da14a32 | G0 | 819×614 | 11 | 1 | 2 | 0 | 14 |
| 13 | be7bc89f5fec | G2 | 640×480 | 13 | 11 | 2 | 1 | 27 |
| 14 | c4a8f2fcf6e8 | G1 | 2416×1736 | 0 | 13 | 18 | 0 | 31 |
| 15 | c90c6b94cf40 | G0 | 819×614 | 11 | 5 | 4 | 0 | 20 |
| 16 | cd93a472e5cd | G4 | 1050×1050 | 1 | 14 | 23 | 0 | 38 |

## Image Size Distribution

| Range | Count | Percentage |
|-------|-------|-----------|
| ≤800px | 3 | 0.5% |
| 801–1500px | 185 | 30.3% |
| 1501–3000px | 259 | 42.4% |
| >3000px | 164 | 26.8% |

## Bugs Fixed During This Phase

1. **Sharpness metric vectorization**: `var(conv2(gray, lap, 'same'))` returns a
   row vector (per-column variance), not a scalar. Fixed with `var(convResult(:))`.
2. **Quality analysis field name mismatch**: `sizeBuckets` struct has fields like
   `small_640` but lookup code generated `medium_640`. Fixed with correct field names.

## Output Files

- `results/phase20c1/phase20c1_merged.csv` — All 611 rows
- `results/phase20c1/batch{1,2,3,4a,4b}/` — Individual batch results
- `results/phase20c1/batch*/forensic_panels/` — Per-batch outlier panels
- `results/phase20c1/batch*/summary_*.png` — Per-batch summary figures

## Known Limitations

1. **Classifier is frozen** — G2 bias is inherent to Phase 8 training
2. **No lesion ground truth** — detection counts cannot be validated against pixel-level annotations
3. **Sharpness gate is non-functional** — threshold < 100 always true; needs recalibration
4. **NV detector sensitivity unknown** — 6.7% detection rate plausible but unvalidated

## Next Steps

1. **Forensic review of 16 outliers** — visual inspection to assess over/under-detection
2. **Sharpness threshold recalibration** — compute actual distribution, set percentile-based threshold
3. **Per-lesion-type grade correlation** — do higher lesion counts correlate with higher DR grades?
4. **Discrimination analysis** — can lesion counts separate G0 from G2 despite classifier confusion?
