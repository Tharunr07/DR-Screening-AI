# Phase 24B.2: Forensic Alignment + Visual Failure Analysis

## Summary

| Check | Result |
|-------|--------|
| Image/mask pairing | **CORRECT** — 161/161 pairs, 100% size match |
| Mask data type | **CORRECT** — logical (0/1), non-zero pixels exist |
| Coordinate alignment | **CORRECT** — masks align with fundus (visual panels verified) |
| Dice implementation | **CORRECT** — verified against 4 known-answer tests |
| MA zero-detection root cause | **FOUND** — resolution scaling mismatch in morphological pipeline |

**The evaluation pipeline is correct. The detectors fail because of a resolution-dependent parameter mismatch, not because of an integration bug.**

---

## 1. Evaluation Pipeline Verification

### 1.1 File Pairing

All 161 image-mask pairs (54 MA + 53 HE + 54 EX) have matching dimensions. No coordinate misalignment.

### 1.2 Mask Interpretation

IDRiD masks are `logical` type with values `{false, true}` (i.e., 0/1). Not uint8 with 0/255. The `imread` → `logical()` conversion in the evaluation script handles this correctly.

### 1.3 Coordinate Alignment

Visual panels generated for 5 images × 3 lesion types confirm masks align with fundus features. No spatial offset.

### 1.4 Dice Verification

| Test | Expected | Got | Status |
|------|----------|-----|--------|
| Perfect match | 1.000 | 1.000 | PASS |
| No overlap | 0.000 | 0.000 | PASS |
| Partial overlap | 0.1205 | 0.1205 | PASS |
| 50% overlap | 0.5149 | 0.5149 | PASS |

(Note: Phase 24B.1 flagged test 4 as "error" because my expected value was wrong — I computed 2500 overlap instead of 2600. The implementation is correct.)

---

## 2. MA Zero-Detection Root Cause

### The pipeline trace

```
Step                          Candidates    Lost
─────────────────────────────────────────────────
After anatomical exclusion     193,319       —
After edge margin (5px)        192,990      329
After FOV erosion              192,990        0
After morph cleanup            10,657     182,333   ← 90% lost HERE
After bwareaopen(min=380)          0      10,657   ← ALL remaining lost HERE
```

### Root cause: resolution scaling mismatch

At IDRiD resolution (4288×2848):
- `mmPerPixel = 6.0 / sqrt(4288² + 2848²) = 0.0012 mm/px`
- `minDiamPx = round(0.025 / 0.0012 / 2) = 11 px → radius`
- `minAreaCalc = round(π × 11²) = 380 pixels`

But the detector's `strel('disk', 3)` (radius 3) produces fragmented pixel-level responses, not cohesive 22px-diameter blobs. The morphological opening (`imopen(disk, 1)`) then removes these tiny responses, and `bwareaopen(min=380)` eliminates everything that survives.

### Why this doesn't happen at APTOS resolution

APTOS images are ~640×480:
- `mmPerPixel = 6.0 / sqrt(640² + 480²) = 0.0075 mm/px`
- `minDiamPx = round(0.025 / 0.0075 / 2) = 2 px → radius`
- `minAreaCalc = round(π × 2²) = 13 pixels`

At APTOS resolution, `strel('disk', 3)` covers a larger physical area relative to lesions, and the minimum area threshold (13 px) is low enough that fragmented responses survive.

### The HE detector works because...

The hemorrhage detector uses different morphology (likely larger structuring elements or different thresholding), which produces larger candidate regions that survive the size filter at IDRiD resolution. This explains why HE achieves 81% image-level detection while MA achieves 0%.

---

## 3. Diagnostic Visual Panels

Generated in `results/phase24b2_forensic/`:
- `align_IDRiD_XX_YY.png` — Coordinate alignment verification (fundus + mask overlay)
- `diag_IDRiD_XX_YY.png` — 6-panel diagnostic (fundus/expert/detector/overlay/FP/FN)
- `ma_diag_IDRiD_XX.png` — MA detector internal state (retinal/disc/vessel masks, dark response, threshold, candidates)
- `ma_pipeline_IDRiD_XX.png` — Step-by-step candidate loss visualization

---

## 4. Implications

### The failure is fixable

This is **not** a fundamental inability to detect MAs. It's a **parameter scaling problem**: the morphological structuring elements and size thresholds were calibrated for APTOS resolution (~640×480) and don't generalize to IDRiD resolution (4288×2848).

### The fix requires resolution-adaptive parameters

The structuring element radius, morphological cleanup kernel, and minimum area threshold should all scale with image resolution. The current implementation has resolution-aware size filtering (Step 9) but fixed morphological parameters (Steps 4, 8).

### But we should NOT fix this yet

Per the directive: "Do not delete the current detectors. Do not immediately tune them. Freeze them as the audited baseline."

The correct next step is to test on FGADR to confirm whether:
1. The failure is resolution-dependent (FGADR images may be different resolution)
2. The HE detector's relative success generalizes
3. The EX detector's poor performance is also resolution-dependent

---

## 5. Outputs

```
docs/PHASE24B2_FORENSIC_ALIGNMENT.md
results/phase24b2_forensic/
    file_pairing.csv
    align_IDRiD_XX_YY.png
    diag_IDRiD_XX_YY.png
    ma_diag_IDRiD_XX.png
matlab/validation/phase24b2_forensic.m
matlab/validation/phase24b2_ma_diagnostic.m
matlab/validation/phase24b2_ma_pipeline.m
```
