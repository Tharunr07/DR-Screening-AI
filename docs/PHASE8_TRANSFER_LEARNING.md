# Phase 8: Transfer Learning DR Classification

**Date:** 2026-09-02
**Status:** COMPLETE — Clinical target ACHIEVED
**Version:** 8.0.0

---

## Objective

Evaluate whether ImageNet-pretrained transfer learning resolves the overparameterization problem identified in the Phase 7 audit, achieving the project's clinical target: **sensitivity > 90% AND specificity > 85%**.

---

## Architecture

Same ResNet-18 backbone, but initialized with **ImageNet-pretrained weights** (converted from PyTorch torchvision via Python bridge).

| Component | Phase 7 (Native) | Phase 8 (Transfer) |
|-----------|-----------------|-------------------|
| Backbone init | Random | ImageNet-pretrained |
| Parameters | 11.5M (random) | 11.5M (pretrained) |
| Classification head | FC 512→128→5 | FC 512→128→5 |
| Epochs | 8 | 8 |
| Batch size | 64 | 32 |
| Learning rate | 1e-3 | 1e-4 |

**Key difference:** Lower learning rate (1e-4 vs 1e-3) preserves pretrained features while fine-tuning.

---

## Three-Way Comparison

### Five-Class Results

| Metric | SVM (A) | Native DL (B) | Transfer Learning (C) |
|--------|---------|---------------|----------------------|
| Accuracy | 0.6324 | 0.6781 | **0.7663** |
| Balanced Accuracy | 0.4607 | 0.3540 | **0.5618** |
| Macro F1 | 0.394 | 0.301 | **0.542** |
| Macro AUC | 0.813 | 0.808 | **0.927** |

### Referable DR Results

| Metric | SVM (A) | Native DL (B) | Transfer Learning (C) |
|--------|---------|---------------|----------------------|
| Sensitivity | 0.759 | 0.953 | **0.977** |
| Specificity | **0.862** | 0.747 | 0.854 |
| AUC | 0.810 | 0.878 | **0.975** |
| Threshold | 0.500 | 0.230 | 0.195 |

### Clinical Target Gate

| Model | Sensitivity | Specificity | Target (sens>0.90, spec>0.85) |
|-------|------------|-------------|-------------------------------|
| SVM Baseline | 0.759 | 0.862 | NOT ACHIEVED |
| Native ResNet-18 | 0.953 | 0.747 | NOT ACHIEVED |
| **Transfer Learning** | **0.977** | **0.854** | **TARGET ACHIEVED** |

---

## Audit Results

### Bootstrap 95% Confidence Intervals (2000 iterations)

| Metric | Point Estimate | 95% CI |
|--------|---------------|--------|
| Sensitivity | 0.9765 | [0.9563, 0.9924] |
| Specificity | 0.8532 | [0.8164, 0.8905] |
| AUC | 0.9746 | [0.9642, 0.9838] |

- Sensitivity CI lower bound (95.6%) is well above 90%
- Specificity CI lower bound (81.6%) is below 85% — borderline
- AUC CI is tightly concentrated around 0.975

### McNemar Statistical Tests

| Comparison | Chi-squared | p-value | Significant? |
|-----------|------------|---------|-------------|
| TL vs SVM | 37.72 | < 0.000001 | Yes |
| TL vs Native DL | 14.56 | 0.000136 | Yes |

Transfer learning is statistically significantly better than both SVM and native DL.

### Domain Shift Analysis

| Dataset | n | Sensitivity | Specificity |
|---------|---|------------|------------|
| APTOS2019 | 553 | 0.986 | 0.871 |
| IDRiD | 59 | 0.919 | 0.591 |

**Finding:** IDRiD specificity (59.1%) is much lower than APTOS (87.1%). This suggests domain shift between the two datasets. The small IDRiD sample (n=59) limits conclusions.

### Failure Analysis

| Error Type | Count | Details |
|-----------|-------|---------|
| False Negatives | 6 | Grade 2: 5, Grade 4: 1 (mean refProb=0.099) |
| False Positives | 52 | Grade 0: 14, Grade 1: 38 |

- **FNs are rare** (6/612 = 1.0%) and have very low confidence (mean refProb=0.099, well below threshold)
- **FPs are mostly grade 1** (Mild NPDR) — a borderline clinical category

### Calibration

| Metric | Value |
|--------|-------|
| Brier score | 0.0892 |
| ECE | 0.0312 |
| MCE | 0.1847 |

Calibration is good (ECE 3.1%).

---

## What Changed from Phase 7

| Factor | Phase 7 | Phase 8 | Impact |
|--------|---------|---------|--------|
| Weight init | Random | ImageNet pretrained | **Major** — pretrained features provide strong representation |
| Learning rate | 1e-3 | 1e-4 | Preserves pretrained features |
| Batch size | 64 | 32 | Smaller batches, more updates per epoch |
| Val accuracy | 67.3% | **79.4%** | +12.1% absolute |
| Referable AUC | 0.878 | **0.975** | +0.097 absolute |

The audit's recommendation was correct: **transfer learning addresses the root cause** (overparameterization + small data) by starting from meaningful pretrained features.

---

## Files Created

### Code (6 files)
| File | Description |
|------|-------------|
| `matlab/transfer/transferLearningConfig.m` | Central config |
| `matlab/transfer/createTransferNetwork.m` | ResNet-18 with ImageNet weights |
| `matlab/transfer/trainTransferDRClassifier.m` | Fine-tuning training loop |
| `matlab/transfer/runPhase8TransferLearning.m` | Orchestrator (A vs B vs C) |
| `matlab/transfer/testTransferLearningPipeline.m` | 17 synthetic tests |
| `matlab/transfer/convert_resnet18_matlab.py` | PyTorch → MATLAB weight converter |

### Results
| File | Description |
|------|-------------|
| `results/transfer_learning/models/trainedNetTL.mat` | Trained TL model |
| `results/transfer_learning/predictions/tl_predictions.csv` | 612 test predictions |
| `results/transfer_learning/phase8_summary.json` | Full results |

---

## Limitations

- **IDRiD domain shift**: Specificity drops to 59.1% on IDRiD — the model may not generalize across datasets
- **Specificity CI**: Lower bound (81.6%) is below 85% — the clinical target is met at point estimate but not with statistical certainty at 95% CI
- **Small IDRiD sample**: Only 59 images — insufficient to draw strong conclusions
- **CPU-only training**: 8 epochs, ~50 min — GPU training could improve further
- **Not clinically validated**: All thresholds are research-only

---

## Conclusion

**Transfer learning achieves the clinical target** (sens=97.7%, spec=85.4%) where both native DL and SVM failed. The improvement is statistically significant (McNemar p < 0.001 vs both baselines).

The Phase 7 audit correctly identified **overparameterization as the root cause**, and transfer learning is the scientifically justified solution. The progression:

```
SVM (sens=75.9%, spec=86.2%)
    ↓
Native ResNet-18 (sens=95.3%, spec=74.7%)
    ↓
Transfer Learning (sens=97.7%, spec=85.4%) ← TARGET ACHIEVED
```
