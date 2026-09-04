# Phase 24B: Public Ground-Truth Validation — Dataset Compatibility Matrix

## 1. Objective

Use existing expert-labelled public datasets to answer:

> **"Are our MA/HE/EX/NV detectors actually detecting real lesions?"**

This replaces the need for immediate ophthalmologist recruitment with a computationally achievable validation step using datasets that already provide expert annotations.

---

## 2. Dataset Compatibility Matrix

### 2.1 Datasets Already in Project

| Dataset | Images | DR Grades | MA | HE | EX | SE | NV | IRMA | Vessels | License | Status |
|---------|--------|-----------|-----|-----|-----|-----|-----|------|---------|---------|--------|
| **APTOS2019** | 5,590 | ✅ 3,662 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | Kaggle TOS | ✅ Downloaded |
| **IDRiD** | 1,113 | ✅ 516 | ✅ 81 | ✅ 80 | ✅ 81 | ✅ 40 | ❌ | ❌ | ❌ | CC-BY-4.0 | ✅ Downloaded |
| **DRIVE** | 40 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ 20 | Challenge | ✅ Downloaded |
| **Messidor-2** | 1,748 | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ADCIS | ✅ Downloaded |

### 2.2 Public Datasets NOT Yet in Project

| Dataset | Images | DR Grades | MA | HE | EX | SE | NV | IRMA | License | Access |
|---------|--------|-----------|-----|-----|-----|-----|-----|------|---------|--------|
| **FGADR** | 2,842 | ✅ 2,842 | ✅ 1,842 | ✅ 1,842 | ✅ 1,842 | ✅ 1,842 | ✅ 1,842 | ✅ 1,842 | Research agreement | Email registration |
| **DDR** | ~10,000 | ✅ ~10,000 | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | CC-BY-4.0 / MIT | Google Drive / Baidu |
| **e-ophtha** | 413 | ❌ | ✅ 148 | ❌ | ✅ 47 | ❌ | ❌ | ❌ | ADCIS (research) | ADCIS website |
| **DIARETDB1** | 89 | ❌ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | Research use | Request form |

---

## 3. Per-Detector Validation Recommendations

### 3.1 Microaneurysm (MA) Detector

| Dataset | MA Annotations | Images | Recommended? | Reason |
|---------|---------------|--------|-------------|--------|
| **IDRiD** | ✅ Binary masks | 81 | **PRIMARY** | Already downloaded, CC-BY-4.0, pixel-level |
| **FGADR** | ✅ Binary masks | 1,842 | **BEST** | Largest MA dataset, 3-ologist annotation |
| **DDR** | ✅ Binary masks | ~10,000 | Good | Large scale, CC-BY-4.0, but must download |
| **e-ophtha** | ✅ Binary masks | 148 | Good | MA-specific, well-cited in literature |

**Recommendation:** Start with **IDRiD** (already available), then **FGADR** (largest, most reliable).

### 3.2 Hemorrhage (HE) Detector

| Dataset | HE Annotations | Images | Recommended? | Reason |
|---------|---------------|--------|-------------|--------|
| **IDRiD** | ✅ Binary masks | 80 | **PRIMARY** | Already downloaded, CC-BY-4.0 |
| **FGADR** | ✅ Binary masks | 1,842 | **BEST** | Largest HE dataset |
| **DDR** | ✅ Binary masks | ~10,000 | Good | Large scale |
| **DIARETDB1** | ✅ Binary masks | 89 | Supplementary | Small but independent |

**Recommendation:** **IDRiD** first, then **FGADR**.

### 3.3 Hard Exudate (EX) Detector

| Dataset | EX Annotations | Images | Recommended? | Reason |
|---------|---------------|--------|-------------|--------|
| **IDRiD** | ✅ Binary masks | 81 | **PRIMARY** | Already downloaded, CC-BY-4.0 |
| **FGADR** | ✅ Binary masks | 1,842 | **BEST** | Largest EX dataset |
| **DDR** | ✅ Binary masks | ~10,000 | Good | Large scale |
| **e-ophtha** | ✅ Binary masks | 47 | Good | EX-specific, well-cited |
| **DIARETDB1** | ✅ Binary masks | 89 | Supplementary | Independent source |

**Recommendation:** **IDRiD** first, then **FGADR** and **e-ophtha**.

### 3.4 Neovascularization (NV) Detector

| Dataset | NV Annotations | Images | Recommended? | Reason |
|---------|---------------|--------|-------------|--------|
| **FGADR** | ✅ Binary masks | 1,842 | **ONLY OPTION** | Only dataset with NV pixel masks |
| **IDRiD** | ❌ | — | No | No NV annotations |
| **DDR** | ❌ | — | No | No NV annotations |

**Recommendation:** **FGADR** is the ONLY publicly available dataset with NV pixel-level annotations. Must download.

### 3.5 DR Grade Validation

| Dataset | Grades | Graders | Images | Recommended? |
|---------|--------|---------|--------|-------------|
| **APTOS2019** | 0-4 | Single | 3,662 | ✅ Already available |
| **IDRiD** | 0-4 | Single | 516 | ✅ Already available |
| **FGADR** | 0-4 | **3 ophthalmologists** | 2,842 | **BEST** — multi-reader |
| **DDR** | 0-4 | Single | ~10,000 | Good for scale |

**Recommendation:** **FGADR** for high-quality multi-reader validation. **APTOS** for scale.

---

## 4. Dataset Quality Assessment

### 4.1 Annotation Quality Comparison

| Dataset | Annotation Method | Inter-observer | Pixel-level | Resolution |
|---------|------------------|---------------|-------------|------------|
| IDRiD | Single expert | Unknown | ✅ Binary TIF | 4288×2848 |
| FGADR | 3 ophthalmologists + 1 verifier | Measured | ✅ Binary masks | Various |
| DDR | Expert annotation | Unknown | ✅ Binary masks | ~3216×2136 |
| e-ophtha | 2 ophthalmologists | Measured | ✅ Binary masks | 1440×960 to 2544×1696 |
| DIARETDB1 | 4 graders | Measured | ✅ Soft masks | 1500×1152 |

### 4.2 License Comparison

| Dataset | License | Commercial Use? | Can Publish? | Restrictions |
|---------|---------|----------------|-------------|--------------|
| IDRiD | CC-BY-4.0 | ✅ Yes | ✅ Yes | Attribution required |
| FGADR | Research agreement | ❌ Research only | ✅ Yes | Email registration, no redistribution |
| DDR | CC-BY-4.0 / MIT | ✅ Yes | ✅ Yes | Attribution required |
| e-ophtha | ADCIS (research) | ❌ Research only | ✅ Yes | ADCIS terms |
| DIARETDB1 | Research use | ❌ Research only | ✅ Yes | Citation required |

---

## 5. Recommended Validation Plan

### Phase 1: Use Already-Downloaded Data (No new downloads)

```
IDRiD (81 images with lesion masks)
     ↓
Run our MA/HE/EX detectors on all 81 images
     ↓
Compare detector output vs expert masks
     ↓
Compute: Dice, IoU, Precision, Recall, F1
     ↓
Result: "Our MA detector: Dice=X on IDRiD expert masks"
```

**This can be done TODAY with zero new data acquisition.**

### Phase 2: Download FGADR (Best quality, NV coverage)

```
FGADR Seg-set (1,842 images, 6 lesion types)
     ↓
Run all detectors on FGADR
     ↓
Compute per-lesion metrics
     ↓
Result: "Our detectors: MA=X, HE=X, EX=X, NV=X on FGADR"
```

### Phase 3: Download DDR (Scale + generalizability)

```
DDR (~10,000 images, different population/cameras)
     ↓
Run all detectors on DDR
     ↓
Result: "Our detectors generalize to DDR: MA=X, HE=X, EX=X"
```

---

## 6. Priority Ranking

| Priority | Dataset | Action | Timeline |
|----------|---------|--------|----------|
| **1** | **IDRiD** | Use immediately (already downloaded) | **NOW** |
| **2** | **FGADR** | Download and use (best quality, only NV source) | After IDRiD |
| **3** | **DDR** | Download and use (scale, generalizability) | After FGADR |
| **4** | **e-ophtha** | Use for EX/MA supplementary validation | Optional |
| **5** | **DIARETDB1** | Use for independent cross-validation | Optional |

---

## 7. What This Gives Us

After Phase 24B, we will be able to say:

```
"MA detector:  Dice = 0.XX on IDRiD (81 expert masks)
                Dice = 0.XX on FGADR (1,842 expert masks)"

"HE detector:  Dice = 0.XX on IDRiD (80 expert masks)
                Dice = 0.XX on FGADR (1,842 expert masks)"

"EX detector:  Dice = 0.XX on IDRiD (81 expert masks)
                Dice = 0.XX on FGADR (1,842 expert masks)"

"NV detector:  Dice = 0.XX on FGADR (1,842 expert masks)"

"DR grading:   Accuracy = 0.XX on FGADR (2,842 images, 3-ologist labels)"
```

Instead of:

```
"147/147 software tests pass" ← proves software works, not that lesions are correct
```

This is the **single most valuable next step** for the project.

---

## 8. What We Still Cannot Claim

Even after Phase 24B:

- ❌ "Clinically validated" — requires prospective ophthalmologist evaluation
- ❌ "Hospital-ready" — requires regulatory, workflow, monitoring validation
- ❌ "Generalizable to all cameras" — DDR covers some variation, not all
- ❌ "Better than experts" — requires head-to-head comparison study

But we WILL be able to say:

- ✅ "Our detectors find real lesions with Dice=X against expert masks"
- ✅ "Our classifier achieves accuracy=X against multi-reader labels"
- ✅ "Our system generalizes to external datasets (DDR, FGADR)"
- ✅ "We know exactly where each detector succeeds and fails"

---

## Outputs

```
docs/PHASE24B_PUBLIC_GROUND_TRUTH_VALIDATION.md
```

## Next Steps

1. **Immediate:** Run existing detectors on IDRiD lesion masks (already downloaded)
2. **This week:** Download FGADR (email registration required)
3. **Next:** Run detectors on FGADR Seg-set
4. **Then:** Download DDR for scale validation
5. **Then:** Build per-detector performance report with confidence intervals
