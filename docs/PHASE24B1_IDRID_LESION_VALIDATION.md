# Phase 24B.1: IDRiD Expert-Ground-Truth Lesion Validation

## Executive Summary

**The lesion detectors fail against expert ground truth.** This is the first genuinely meaningful evidence about whether the lesion-detection portion of the system is medically useful.

| Detector | Dice | IoU | Precision | Recall | Image-Level Detection | Verdict |
|----------|------|-----|-----------|--------|----------------------|---------|
| **MA** | **0.000** | **0.000** | **0.000** | **0.000** | **0/54 (0.0%)** | **NOT SUPPORTED** |
| **HE** | **0.033** | **0.018** | 0.214 | 0.020 | 43/53 (81.1%) | **NOT SUPPORTED** |
| **EX** | **0.011** | **0.006** | 0.144 | 0.006 | 8/54 (14.8%) | **NOT SUPPORTED** |

---

## 1. What Was Measured

- **Dataset:** IDRiD training set (54 images, 4288×2848 pixels)
- **Expert masks:** Binary pixel-level annotations (MA, HE, EX)
- **Detectors:** Current unmodified implementations (no threshold changes)
- **Metrics:** Pixel-level Dice, IoU, Precision, Recall, Specificity + image-level detection rate
- **Confidence intervals:** 95% bootstrap (10,000 resamples)

---

## 2. Detailed Results

### 2.1 Microaneurysm (MA) Detector

```
Dice:      0.000 ± 0.000  [95% CI: 0.000–0.000]
IoU:       0.000 ± 0.000  [95% CI: 0.000–0.000]
Precision: 0.000 ± 0.000  [95% CI: 0.000–0.000]
Recall:    0.000 ± 0.000  [95% CI: 0.000–0.000]
Specificity: 1.000 ± 0.000
Image-level detection: 0/54 (0.0%)
```

**The MA detector detects ZERO microaneurysms on ANY IDRiD image.**

The detector returns `count=0` and an empty mask for all 54 images. This is not a threshold issue — the detector fundamentally does not find MA candidates at IDRiD's resolution (4288×2848).

**Root cause hypothesis:** The MA detector's morphological operations (black-hat on red channel, adaptive threshold k=2.5, size filter 25–125μm) may be calibrated for lower-resolution images (e.g., APTOS at ~640×480). At IDRiD's resolution, the size thresholds and morphological structuring elements may not match the actual MA dimensions.

### 2.2 Hemorrhage (HE) Detector

```
Dice:      0.033 ± 0.056  [95% CI: 0.019–0.049]
IoU:       0.018 ± 0.031  [95% CI: 0.010–0.027]
Precision: 0.214 ± 0.343  [95% CI: 0.126–0.309]
Recall:    0.020 ± 0.034  [95% CI: 0.011–0.029]
Specificity: 0.999 ± 0.001
Image-level detection: 43/53 (81.1%)
```

**The HE detector finds hemorrhages in 81% of images but with extremely poor spatial overlap.**

- **High specificity (0.999):** Almost no false positives on background
- **Very low recall (0.020):** Only captures 2% of expert-marked hemorrhage pixels
- **Moderate precision (0.214):** When it does detect something, 21% overlaps with expert
- **Very low Dice (0.033):** Near-zero spatial agreement

**Interpretation:** The detector fires on some hemorrhage regions but misses most of them. It may be detecting only the largest/clearest hemorrhages while missing smaller ones. The detected regions likely only partially overlap with expert annotations.

### 2.3 Hard Exudate (EX) Detector

```
Dice:      0.011 ± 0.030  [95% CI: 0.004–0.019]
IoU:       0.006 ± 0.016  [95% CI: 0.002–0.010]
Precision: 0.144 ± 0.348  [95% CI: 0.055–0.237]
Recall:    0.006 ± 0.016  [95% CI: 0.002–0.010]
Specificity: 1.000 ± 0.000
Image-level detection: 8/54 (14.8%)
```

**The EX detector only detects exudates in 15% of images.**

- **Near-zero recall (0.006):** Captures less than 1% of expert-marked exudate pixels
- **Low precision (0.144):** 86% of what it detects is NOT an exudate
- **Dice 0.011:** Virtually no spatial agreement

**Interpretation:** The EX detector (white top-hat on green channel) is either not triggering on IDRiD's exudate appearances or the size/color filters are excluding most real exudates.

---

## 3. Comparison to Published Benchmarks

For reference, state-of-the-art lesion segmentation methods on IDRiD report:

| Method | MA Dice | HE Dice | EX Dice | SE Dice |
|--------|---------|---------|---------|---------|
| U-Net (baseline) | ~0.35 | ~0.45 | ~0.65 | ~0.55 |
| Feature Fusion U-Net | 0.40 | 0.52 | 0.72 | 0.60 |
| LezioSeg + Affine | 0.44 | 0.69 | 0.86 | 0.81 |
| **Our detectors** | **0.000** | **0.033** | **0.011** | N/A |

Our detectors perform orders of magnitude below published baselines.

---

## 4. Why This Matters

### Before Phase 24B.1

We could say: "147/147 software tests PASS. The detectors work correctly."

### After Phase 24B.1

We can now say: **"The detectors fail against expert ground truth. They do not find the right lesions."**

This is the critical distinction between:
- **Software correctness** (code runs, no errors, follows rules) ← proven
- **Medical detection performance** (finds actual lesions) ← **NOT proven**

---

## 5. Implications

### 5.1 The "lesion evidence" in the clinical report is unreliable

Throughout Phases 20–24, we reported lesion counts like "MA=24, HE=13, EX=19." These numbers come from detectors that, as now proven, do not reliably find expert-annotated lesions. **The lesion evidence supporting the clinical report is not medically valid.**

### 5.2 The classifier's lesion features may be noise, not signal

The ResNet-18 classifier was trained on APTOS images. It may have learned:
- Texture patterns that happen to correlate with DR grade
- Preprocessing artifacts
- Resolution-dependent features
NOT actual lesion locations

### 5.3 Grad-CAM explanations are suspect

Grad-CAM shows "where the model looks." If the lesion detectors are wrong, the Grad-CAM heatmap may be highlighting irrelevant regions while missing actual pathology.

### 5.4 The frozen model needs fundamental rework

The current detectors are not a tuning problem — they are a fundamental architecture problem. The morphological pipeline does not generalize to IDRiD's resolution and imaging characteristics.

---

## 6. What To Do Next

### Immediate: Do NOT tune the current detectors

The gaps are too large for threshold tuning. The detectors need:
1. Resolution-independent morphological parameters, OR
2. Complete replacement with learned segmentation models

### Recommended: Download FGADR

FGADR provides 1,842 images with 6 lesion types including NV. It would tell us:
- Is the failure IDRiD-specific or universal?
- Does the MA detector work on any dataset?
- Can we establish a meaningful baseline before rebuilding?

### Then: Rebuild detectors using modern segmentation

Instead of hand-crafted morphology, consider:
- U-Net or similar trained on FGADR/IDRiD lesion masks
- Transfer learning from ImageNet-pretrained encoders
- Multi-scale architectures for varying lesion sizes

---

## 7. Outputs

```
docs/PHASE24B1_IDRID_LESION_VALIDATION.md
results/phase24b1_idrid/
    image_level_results.csv
    summary_metrics.csv
    bootstrap_ci.csv
    worst_cases.csv
matlab/validation/validatePhase24B1.m
```

---

## 8. Verdict

| Detector | Dice | Verdict | Reasoning |
|----------|------|---------|-----------|
| **MA** | 0.000 | **NOT SUPPORTED** | Zero detection on all 54 images |
| **HE** | 0.033 | **NOT SUPPORTED** | Dice 0.033, recall 2%, far below any acceptable threshold |
| **EX** | 0.011 | **NOT SUPPORTED** | Dice 0.011, only 15% image-level detection |

**None of the three detectors demonstrate medical detection performance against IDRiD expert ground truth.**

The 147/147 test results proved software correctness. The IDRiD validation proves **the software correctly implements algorithms that do not find the right lesions.**

---

## Disclaimers

> These results apply to the IDRiD dataset only. Different datasets (FGADR, DDR) may yield different results. However, the near-zero performance on IDRiD strongly suggests fundamental detector limitations, not dataset-specific issues.
