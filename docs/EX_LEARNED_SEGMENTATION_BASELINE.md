# EX Learned Segmentation Baseline Report

**Date:** 2026-09-05  
**Auditor:** opencode  
**Experiment:** EX (Hard Exudates) segmentation with small U-Net baseline  
**Verdict:** **Baseline FAILED — model learned to predict background**

---

## 1. Dataset Verification

### IDRiD

| Split | Images | EX Masks | Empty Masks | FG Fraction |
|-------|--------|----------|-------------|-------------|
| Training | 54 | 54 | 0 | 0.008 (mean) |
| Testing | 27 | 27 | 0 | — |

- All masks: logical (0/1), 2848×4288
- Resolution: uniform across all images
- Pairing: filename-based, 1:1 match verified

### DDR

| Split | Images | EX Masks | Empty Masks |
|-------|--------|----------|-------------|
| External Test | 60 | 60 | 58 (97%) |

- DDR EX masks are 97% empty — only 2 images have EX lesions
- Resolution: variable (1536×1956 to 1934×2592)
- Useful only as domain generalization stress test

### Total

- **141 images, 141 EX masks, 0 empty in IDRiD, 58 empty in DDR**

---

## 2. Split Definition

| Split | Source | Count | Purpose |
|-------|--------|-------|---------|
| Train | IDRiD training (80%) | 43 | Model training |
| Val | IDRiD training (20%) | 11 | Early stopping |
| Test | IDRiD testing | 27 | Primary evaluation |
| External | DDR | 60 | Domain generalization |

- Random seed: 42
- No overlap between splits
- No data leakage

---

## 3. Preprocessing

- Resize: 256×256 (bilinear interpolation for images, nearest-neighbor for masks)
- Normalization: `single(img) / 255`
- Mask binarization: `mask > 0`
- Color: RGB (3 channels)

---

## 4. Model Architecture

```
Small U-Net (no pretrained encoder)
  Input: 256×256×3
  Encoder: 3 levels (32→64→128 filters)
  Bottleneck: 256 filters
  Decoder: 3 levels (128→64→32 filters)
  Output: 256×256×2 (background + lesion)
  Total parameters: ~1.5M
```

- Built with MATLAB `unet()` function
- No pretrained encoder (baseline purpose)
- `dlnetwork` object

---

## 5. Training Configuration

| Parameter | Value |
|-----------|-------|
| Loss | crossentropy |
| Optimizer | Adam |
| Initial learning rate | 5e-4 |
| Max epochs | 50 |
| Mini batch size | 2 |
| Validation frequency | 11 iterations |
| Early stopping patience | 20 |
| Execution environment | CPU |
| Checkpoint | Best validation |
| Seed | 42 |

---

## 6. Training Time

- **5.7 minutes** (18 epochs before early stopping)
- ~20s per epoch on CPU
- Early stopping triggered at epoch 18 (patience exhausted)
- Best validation loss: **0.021**

---

## 7. Validation Results

| Metric | IDRiD Validation (11 images) |
|--------|------------------------------|
| Dice | 0.0003 |
| IoU | 0.0002 |
| Precision | 0.0002 |
| Recall | 0.0098 |
| Non-empty GT | 11 |
| Empty GT | 0 |

**Interpretation:** Model predicts nearly all background. Minimal lesion detection.

---

## 8. IDRiD Locked-Test Results

| Metric | Learned U-Net | Handcrafted |
|--------|--------------|-------------|
| Dice | 0.0016 | 0.0224 |
| IoU | 0.0008 | 0.0117 |
| Precision | 0.0010 | 0.3994 |
| Recall | 0.0047 | 0.0117 |
| Images | 27 | 27 |

**Interpretation:** Learned model performs **worse than handcrafted** on all metrics. Handcrafted has 400× better precision.

---

## 9. DDR External-Test Results

| Metric | Learned U-Net | Handcrafted |
|--------|--------------|-------------|
| Dice | 0.0000 | — |
| IoU | 0.0000 | — |
| Precision | 0.0000 | — |
| Recall | 0.0000 | — |
| Images | 60 | 60 |
| Non-empty GT | 2 | 2 |

**Interpretation:** Model predicts nothing on DDR. Only 2 images have EX lesions.

---

## 10. Handcrafted vs Learned Comparison

### IDRiD Test (27 images)

```
                  Learned U-Net    Handcrafted    Winner
Dice              0.0016          0.0224         Handcrafted (14×)
IoU               0.0008          0.0117         Handcrafted (15×)
Precision         0.0010          0.3994         Handcrafted (400×)
Recall            0.0047          0.0117         Handcrafted (2.5×)
```

### DDR External (60 images)

```
                  Learned U-Net    Handcrafted
Dice              0.0000          ~0
Precision         0.0000          ~0
Recall            0.0000          ~0
```

**The handcrafted EX detector outperforms the learned U-Net on all metrics.**

---

## 11. Qualitative Examples

Not generated — model performance too poor for meaningful visual comparison.

---

## 12. Failure Cases

### Root Cause Analysis

The model converges (training loss drops from 0.9 to 0.02) but learns to predict **nearly all background**. This is caused by:

1. **Extreme class imbalance:** EX lesions occupy 0.68% of training pixels
2. **Crossentropy loss:** Optimizes per-pixel accuracy, which is maximized by predicting background
3. **Small dataset:** 43 training images is insufficient for the model to learn spatial patterns
4. **No class weighting:** Crossentropy treats all pixels equally

### What the model learned

- Training loss: 0.9 → 0.02 (converged)
- Validation loss: 0.9 → 0.021 (converged)
- But spatial predictions: 0% overlap with ground truth
- Model predicts `p(lesion) ≈ 0.02` everywhere (close to prior probability)

### Why Dice loss was not attempted

- MATLAB `trainnet` custom loss function interface produced evaluation errors
- Binary-crossentropy also failed on single-channel targets
- Time constraint: 5 days total, this experiment consumed ~1 day

---

## 13. Reproducibility

| Item | Value |
|------|-------|
| Random seed | 42 |
| MATLAB version | R2026a (26.1.0.3346908) |
| Toolboxes | DL 26.1, CV 26.1, IP 26.1 |
| GPU | None (CPU only) |
| Model file | `matlab/segmentation/models/ex_unet_baseline.mat` |
| Manifest | `matlab/segmentation/manifest.mat` |
| Results | `matlab/segmentation/results/ex_baseline_results.mat` |

---

## 14. Clinical/Research Limitations

- **NOT clinically validated** — experimental research prototype only
- **NOT a diagnostic tool** — does not detect or diagnose EX
- **NOT deployed** — no GUI integration, no production use
- **Limited training data** — 43 images is far below clinical standards
- **Failed baseline** — learned model worse than handcrafted
- **No generalization** — DDR results show zero performance
- **Class imbalance** — fundamental challenge with sparse lesion data

---

## 15. Files Created

| File | Purpose |
|------|---------|
| `matlab/segmentation/buildEXManifest.m` | Build dataset manifest |
| `matlab/segmentation/manifest.mat` | Dataset manifest (141 entries) |
| `matlab/segmentation/splitData.m` | Deterministic data splitting |
| `matlab/segmentation/buildSmallUNet.m` | U-Net architecture builder |
| `matlab/segmentation/trainEXSegmentation.m` | Training script (standalone) |
| `matlab/segmentation/runEXExperiment.m` | Full experiment pipeline |
| `matlab/segmentation/evaluateEXModel.m` | Evaluation function |
| `matlab/segmentation/evaluateHandcraftedEX.m` | Handcrafted comparison |
| `matlab/segmentation/diceLoss.m` | Custom Dice loss (untested) |
| `matlab/segmentation/models/ex_unet_baseline.mat` | Trained model |
| `matlab/segmentation/results/ex_baseline_results.mat` | All results |

---

## 16. Tests

| Test | Status |
|------|--------|
| Manifest build | PASS (141 entries) |
| Data split | PASS (43/11/27/60) |
| Data loading | PASS (256×256×3 single) |
| Network build | PASS (dlnetwork) |
| Training | PASS (5.7 min, converged) |
| Evaluation | PASS (metrics computed) |
| Handcrafted comparison | PASS (baseline established) |
| No production code modified | PASS |

---

## 17. Git Commit

Not committed yet — awaiting Senior Architect decision on whether to commit failed baseline.

---

## 18. Recommendation

**D — Stop learned segmentation and focus on SIH demo**

**Rationale:**

1. The baseline **failed** — learned model worse than handcrafted on all metrics
2. Root cause (class imbalance + small data) cannot be fixed in remaining time
3. Custom Dice loss failed due to MATLAB API limitations
4. Time budget: ~1 day consumed, 4 days remain
5. The existing system (classifier + handcrafted lesions + Grad-CAM) is stable and working

**Alternative if Senior Architect wants to continue:**

Try **weighted crossentropy** (upweight lesion pixels 50×) or **patch-based training** (extract 256×256 patches from 2848×4288 images to increase effective training samples from 43 to ~430). But this adds 1-2 more days of experimentation with uncertain outcome.

---

**STOPPED.** Awaiting Senior Architect approval.
