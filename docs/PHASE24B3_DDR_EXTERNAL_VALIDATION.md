# Phase 24B.3: DDR External Lesion Validation

## Summary

**The detectors fail on DDR too.** The IDRiD failure is not dataset-specific — the handcrafted detectors do not generalize beyond their APTOS training domain.

| Detector | IDRiD Dice | DDR Dice | DDR Image-Level | Verdict |
|----------|-----------|----------|-----------------|---------|
| **MA** | 0.000 | NaN (0/0) | 0/50 (0.0%) | **NOT SUPPORTED** |
| **HE** | 0.033 | NaN* | 15/30 (50.0%) | **NOT SUPPORTED** |
| **EX** | 0.011 | NaN (0/0) | 0/2 (0.0%) | **NOT SUPPORTED** |

*HE Dice is NaN because many images have zero TP AND zero FN, giving 0/0.

---

## 1. DDR Dataset

- **Source:** DDR (Diabetic Retinopathy Detection), Chinese Academy of Sciences
- **License:** CC BY 4.0
- **Subset:** 60 training images from Hugging Face (`ctmedtech/DDR-dataset`)
- **Resolutions:** 1956×1934 to 3264×2448 (between APTOS and IDRiD)
- **Masks:** uint8 with values {0, 255}, one per lesion type (MA, HE, EX)
- **Sparsity:** MA: 17/20 have lesions; HE: 8/20; EX: 0/20 (very sparse)

---

## 2. Results

### 2.1 MA Detector

```
DDR: 0/50 images detected (0.0%)
IDRiD: 0/54 images detected (0.0%)
```

**The MA detector finds ZERO microaneurysms on both IDRiD and DDR.** This is not a resolution or dataset issue — the detector's morphological pipeline fundamentally does not produce MA candidates on any non-APTOS dataset.

### 2.2 HE Detector

```
DDR: 15/30 images with lesions detected (50.0%), recall=0.029
IDRiD: 43/53 images with lesions detected (81.1%), recall=0.020
```

The HE detector works on both datasets but **better on IDRiD than DDR**, contradicting the resolution hypothesis. IDRiD is higher resolution (4288×2848) than DDR (1956–3264). If resolution were the dominant factor, DDR should perform better.

### 2.3 EX Detector

```
DDR: 0/2 images with lesions detected (0.0%)
IDRiD: 8/54 images with lesions detected (14.8%)
```

EX detection is near-zero on both datasets.

---

## 3. Resolution Dependence Analysis

### Hypothesis tested
> "If performance improves on DDR (lower resolution than IDRiD), resolution scaling is the dominant problem."

### Result
**Hypothesis rejected.** DDR performance is equal to or worse than IDRiD:

| Metric | IDRiD (4288×2848) | DDR (1956–3264) | Better on... |
|--------|-------------------|-----------------|--------------|
| MA detection | 0% | 0% | Neither |
| HE detection | 81% | 50% | IDRiD |
| EX detection | 15% | 0% | IDRiD |

### Implication
The failure is **not primarily resolution-dependent**. It's a **dataset domain generalization failure** — the detectors were calibrated for APTOS characteristics (specific camera, specific preprocessing, specific lesion appearance) and do not generalize to other datasets.

---

## 4. What This Means

### The detectors are APTOS-specific, not resolution-specific

The handcrafted morphological pipeline was implicitly tuned (through the APTOS validation process) for:
- APTOS camera characteristics
- APTOS image preprocessing
- APTOS lesion appearance
- APTOS resolution (~640×480)

It does not generalize to:
- IDRiD (different camera, different resolution, different population)
- DDR (different camera, different resolution, different population)

### Resolution adaptation alone won't fix this

Even if we scale the morphological parameters proportionally to image resolution, the detectors may still fail because the underlying assumptions (dark-red MA in red channel, bright EX in green channel) may not hold across different camera systems.

### The correct path forward is learned segmentation

Replace handcrafted morphology with U-Net or similar trained on multi-dataset lesion masks. This would:
1. Learn dataset-invariant lesion features
2. Handle varying resolutions naturally
3. Be trainable on FGADR (1,842 images with 6 lesion types)

---

## 5. Outputs

```
docs/PHASE24B3_DDR_EXTERNAL_VALIDATION.md
results/phase24b3_ddr/
    image_level_results.csv
    summary_metrics.csv
matlab/validation/validatePhase24B3_DDR.m
```
