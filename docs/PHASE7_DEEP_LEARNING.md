# Phase 7: Deep Learning DR Classification

**Date:** 2026-09-01
**Status:** COMPLETE — NOT clinically validated
**Version:** 7.0.0

---

## Objective

Build and evaluate a deep learning classifier for DR severity grading, compare with the Phase 4/6 SVM baseline, and explore hybrid DL + clinical features. All three models are evaluated on the same untouched 612-image test set.

---

## Architecture

**ResNet-18** (untrained, from-scratch) with custom classification head:

| Layer | Output | Parameters |
|-------|--------|------------|
| ResNet-18 backbone | 512-d | 11.1M |
| FC 512 + ReLU + Dropout(0.5) | 512 | 262K |
| FC 128 + ReLU + Dropout(0.3) | 128 | 65K |
| FC 5 + Softmax | 5 | 645 |
| **Total** | | **~11.5M** |

**Training config:**
- Optimizer: Adam
- Max epochs: 8
- Batch size: 64
- Learning rate: 1e-3 (→ 1e-4 at epoch 5)
- L2 regularization: 1e-4
- Image size: 224×224 (ResNet-18 input)
- Augmentation: horizontal flip, rotation ±10°, translation ±10px, scale [0.9, 1.1]
- Quality gating: exclude UNGRADABLE from training (2792/2852 train images)
- Class weights: inverse frequency (β=0.999)

---

## Three-Way Comparison

### Five-Class Results

| Metric | SVM Baseline (A) | Deep Learning (B) | Hybrid (C) |
|--------|------------------|-------------------|------------|
| Accuracy | 0.6324 | **0.6781** | — |
| Balanced Accuracy | **0.4607** | 0.3540 | — |
| Macro F1 | **0.3940** | 0.3012 | — |
| Macro AUC | 0.8130 | 0.8078 | — |
| Per-class AUC (0–4) | — | 0.960 / 0.766 / 0.816 / 0.773 / 0.725 | — |

### Referable DR Results

| Metric | SVM Baseline (A) | Deep Learning (B) | Hybrid (C) |
|--------|------------------|-------------------|------------|
| Sensitivity | 0.7588 | **0.9533** | 0.7626 |
| Specificity | 0.8620 | 0.7465 | **0.8620** |
| Precision | 0.765 | 0.652 | 0.765 |
| F1 | 0.762 | 0.775 | 0.764 |
| AUC | 0.8104 | **0.8784** | 0.8123 |
| Threshold | 0.500 | 0.230 | 0.500 |

### Clinical Target Gate

| Model | Sensitivity | Specificity | Target (sens>0.90, spec>0.85) |
|-------|------------|-------------|-------------------------------|
| SVM Baseline | 0.759 | 0.862 | NOT ACHIEVED |
| Deep Learning | **0.953** | 0.746 | NOT ACHIEVED |
| Hybrid | 0.763 | 0.862 | NOT ACHIEVED |

---

## Key Findings

1. **DL achieved highest referable sensitivity (95.3%)** — nearly eliminating missed referable cases
2. **DL referable AUC (0.878) is the best** across all models
3. **Trade-off**: DL's specificity (74.6%) is lower than SVM (86.2%)
4. **Hybrid does not improve** over the SVM baseline — DL scores add little to clinical features for this referable task
5. **Five-class balanced accuracy dropped** (0.35 vs 0.46) — DL struggles with severely imbalanced minority classes (Level 3: 39 test images, Level 4: 50)
6. **Per-class AUC shows** Level 0 (No DR) is well-separated (0.96) while Level 4 (PDR) is weakest (0.73)

---

## Files Created

### Code (8 files)
| File | Description |
|------|-------------|
| `matlab/deeplearning/deepLearningConfig.m` | Central config |
| `matlab/deeplearning/prepareDeepLearningData.m` | Data preparation, quality gating, class weights |
| `matlab/deeplearning/createDRNetwork.m` | ResNet-18 + custom head |
| `matlab/deeplearning/trainDeepDRClassifier.m` | Training loop |
| `matlab/deeplearning/selectReferableThreshold.m` | Threshold selection on validation |
| `matlab/deeplearning/evaluateDeepLearning.m` | Full evaluation pipeline |
| `matlab/deeplearning/runPhase7DeepLearning.m` | Orchestrator (A vs B vs C) |
| `matlab/deeplearning/testDeepLearningPipeline.m` | 15 synthetic tests |

### Results
| File | Description |
|------|-------------|
| `results/deep_learning/models/trainedNet.mat` | Trained ResNet-18 (42.6 MB) |
| `results/deep_learning/models/hybridNet.mat` | Hybrid SVM model |
| `results/deep_learning/predictions/dl_predictions.csv` | 612 test predictions |
| `results/deep_learning/phase7_summary.json` | Full results |

---

## Test Results

**15/15 synthetic tests PASS** — config, network creation, forward inference, class weights, threshold selection, metrics, NaN handling, preprocessing, augmentation, referable logic, ordinal metrics, save/load, reproducibility, leakage guard, config completeness.

---

## Limitations

- **Untrained ResNet-18**: Random initialization (no ImageNet pretraining available)
- **CPU-only training**: ~45 min for 8 epochs; GPU would enable more epochs and larger batches
- **Small dataset**: 2792 training images for 11.5M parameters — significant overfitting risk
- **Class imbalance**: Level 3 (39 test) and Level 4 (50) severely underrepresented
- **Threshold trade-off**: No single threshold achieves both sens>0.90 and spec>0.85
- **Not clinically validated**: All thresholds and metrics are research-only

---

## Conclusion

The deep learning model achieves **highest sensitivity (95.3%) and AUC (0.878)** for referable DR detection, representing a meaningful improvement over the SVM baseline. However, it does not meet the combined clinical target (sens>0.90 + spec>0.85) due to reduced specificity. The hybrid approach does not improve performance.

**Recommendation:** To reach clinical targets, consider:
1. ImageNet pretraining (transfer learning)
2. Larger training datasets
3. GPU training with more epochs
4. Advanced architectures (EfficientNet, Vision Transformer)
5. Oversampling or synthetic augmentation for minority classes
