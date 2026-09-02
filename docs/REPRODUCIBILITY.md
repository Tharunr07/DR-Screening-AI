# Reproducibility Guide

## Environment

| Component | Version |
|-----------|---------|
| MATLAB | R2026a (26.1.0.3346908) Update 5 |
| OS | Windows 11 (win64) |
| Deep Learning Toolbox | 26.1 |
| Python | 3.x (for weight conversion) |
| PyTorch | 2.13.0+cpu (for weight extraction) |
| torchvision | 0.28.0+cpu |

## Random Seed

All random number generators are seeded with `42`:
- MATLAB `rng(42)` in config functions
- Python `torch.manual_seed(42)` (implicit in weight extraction)

## Dataset Splits

- **Source:** `data/splits/train.csv`, `val.csv`, `test.csv`
- **Split method:** 70/15/15 patient-level split (Phase 1)
- **Seed:** 42
- **Leakage prevention:** Patient-level (no patient appears in multiple splits)
- **Manifest:** `data/processed/manifest.csv` (7872 rows)
- **Labeled images:** APTOS2019 (3662) + IDRiD (494)
- **After quality gating:** Train=2792, Val=611, Test=612

## Training Configuration

```matlab
cfg.seed = 42;
cfg.image.size = [224 224];
cfg.network.architecture = 'resnet18';
cfg.network.pretrained = true;  % ImageNet weights
cfg.training.maxEpochs = 8;
cfg.training.miniBatchSize = 32;
cfg.training.initialLearnRate = 1e-4;
cfg.training.learnRateSchedule = 'piecewise';
cfg.training.learnRateDropPeriod = 5;
cfg.training.learnRateDropFactor = 0.1;
cfg.training.l2Regularization = 1e-4;
cfg.augmentation.flipHorizontal = true;
cfg.augmentation.rotationRange = [-10 10];
cfg.augmentation.translationRange = [-10 10];
cfg.augmentation.scaleRange = [0.9 1.1];
cfg.quality.includeBorderline = true;
cfg.quality.includeUngradable = false;
cfg.imbalance.beta = 0.999;
```

## Pretrained Weights

- **Source:** PyTorch torchvision `ResNet18_Weights.IMAGENET1K_V1`
- **Conversion:** `matlab/transfer/convert_resnet18_matlab.py`
- **Format:** MATLAB .mat file with layer-name-mapped weights
- **Location:** `tempdir/resnet18_matlab/resnet18_matlab_weights.mat`
- **Note:** Weights are converted at runtime; not stored in repo

## Test Threshold

- **Selected on validation set** using best F1 score
- **Threshold:** 0.1951
- **Method:** Sweep all validation referable probabilities, compute F1 at each, select maximum

## Model Artifacts

| File | Size | Description |
|------|------|-------------|
| `results/transfer_learning/models/trainedNetTL.mat` | 40.9 MB | Trained transfer-learning model |
| `results/transfer_learning/predictions/tl_predictions.csv` | — | 612 test predictions |
| `results/transfer_learning/phase8_summary.json` | — | Full results summary |
| `results/transfer_learning/figures/roc_curve_data.csv` | — | ROC curve points |

## How to Reproduce

1. Ensure MATLAB R2026a with Deep Learning Toolbox is installed
2. Ensure Python 3.x with PyTorch and torchvision are installed
3. Run the weight conversion:
   ```bash
   python matlab/transfer/convert_resnet18_matlab.py
   ```
4. Run the pipeline:
   ```matlab
   addpath(genpath('matlab'));
   cd('DR_Screening');
   phase8 = runPhase8TransferLearning();
   ```
5. Results will be saved to `results/transfer_learning/`

## Expected Results

| Metric | Value |
|--------|-------|
| Five-class accuracy | 0.7663 |
| Balanced accuracy | 0.5618 |
| Macro F1 | 0.5423 |
| Macro AUC | 0.9266 |
| Referable sensitivity | 0.9767 |
| Referable specificity | 0.8535 |
| Referable AUC | 0.9746 |
| Selected threshold | 0.1951 |

## What Is Locked

- **612-image test set** — never modified after Phase 1 split
- **Splits** — frozen at `data/splits/`
- **All Phase 1–7 outputs** — never modified
- **Model** — saved as `trainedNetTL.mat`
- **Threshold** — selected on validation, applied to test once

## What Is NOT Locked

- Training could produce slightly different weights due to non-deterministic GPU operations (if GPU is available)
- CPU training is deterministic for the given seed and batch ordering
