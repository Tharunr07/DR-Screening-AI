# Phase 20D.2: Training Pipeline Forensic Audit

**Date**: 2026-09-04
**Status**: COMPLETE — ROOT CAUSE IDENTIFIED
**Scope**: Full audit of the frozen transfer-learning training pipeline
**Model**: trainedNetTL.mat (frozen, commit cc7bed8)

## Executive Summary

**The G2 collapse in Phase 20C.1/20D.1 is caused by a preprocessing mismatch, NOT a model failure.**

The model was trained on **raw pixel values (0-255)** via MATLAB's `augmentedImageDatastore`, but all our Phase 20C/20D audit code applies **ImageNet normalization** (mean subtraction + std division). This feeds completely out-of-distribution inputs to the model, causing the G2 collapse.

**Critical evidence**: When the same model is evaluated with correct preprocessing (raw pixels), it achieves **76.6% accuracy** with meaningful 5-class discrimination. The model was always working — we were evaluating it incorrectly.

---

## 1. Root Cause: Preprocessing Mismatch

### Training evaluation (correct)
```matlab
% runPhase8TransferLearning.m
testImds = augmentedImageDatastore(cfg.image.size, imdsTest);
[YPredTest, scoresTest] = classify(trainedNetTL, testImds);
% augmentedImageDatastore: resize only, NO normalization
% Output: uint8 pixels in range [0, 255]
```

### Our audit code (WRONG)
```matlab
% classifierForensicAudit.m / runPhase20C1.m
imgR = imresize(img, cfgTL.image.size, 'bicubic');
mn = [0.485 0.456 0.406]; sd = [0.229 0.224 0.225];
n = double(imgR) / 255;
for c = 1:3
    n(:, :, c) = (n(:, :, c) - mn(c)) / sd(c);
end
[pred, scores] = classify(net, n);
% Output: float32 in range [-2.1, 2.6] (ImageNet normalized)
```

### Diagnostic proof (50-image batch test)

| Comparison | Agreement | Interpretation |
|---|---|---|
| augmentedImageDatastore vs resize-only (both raw) | **49/50 (98%)** | Both use raw pixels — equivalent |
| augmentedImageDatastore vs ImageNet-normalized | **29/50 (58%)** | 42% of predictions change — WRONG |

**Specific examples from the diagnostic:**

| Image | True | Method A (raw) | Method B (normalized) | Match? |
|---|---|---|---|---|
| 0097f532ac9f | G0 | G0 | **G2** | DIFF |
| 03747397839f | G2 | G4 | G2 | DIFF |
| 04ac765f91a1 | G1 | G1 | **G2** | DIFF |
| 05a5183c92d0 | G1 | G1 | **G2** | DIFF |
| 086d41d17da8 | G1 | G1 | **G2** | DIFF |
| 08ee569d4721 | G0 | G0 | **G2** | DIFF |

The normalized preprocessing pushes borderline predictions toward G2.

### Why this happens

When ImageNet normalization is applied to a model trained on raw pixels:
1. The input range shifts from [0, 255] to approximately [-2.1, 2.6]
2. The first convolutional layer receives values it was never trained on
3. The softmax output becomes near-uniform or biased toward the most common training gradient
4. G2 (the plurality class at 27.5%) becomes the default prediction

---

## 2. Training Configuration

### Architecture
- **Backbone**: ResNet-18 with ImageNet pretrained weights (converted from PyTorch)
- **Classification head**: FC(512) → ReLU → Dropout(0.5) → FC(128) → ReLU → Dropout(0.3) → FC(5) → Softmax
- **Head LR factor**: 10x (head trains 10x faster than backbone)
- **Total layers**: 77

### Training hyperparameters
| Parameter | Value |
|---|---|
| Optimizer | Adam |
| Max epochs | 8 |
| Batch size | 32 |
| Learning rate | 1e-4 |
| LR schedule | Piecewise (drop at epoch 5, factor 0.1) |
| L2 regularization | 1e-4 |
| Validation frequency | 40 iterations |
| Validation patience | 10 |
| Image size | 224×224 |
| Resize method | Bicubic (augmentedImageDatastore default: bilinear) |

### Augmentation
| Transform | Range |
|---|---|
| Horizontal flip | Yes |
| Rotation | [-10°, +10°] |
| Translation | [-10px, +10px] |
| Scale | [0.9, 1.1] |
| Brightness | NOT used (Phase 8) |
| Contrast | NOT used (Phase 8) |

### Class weights (effective number, β=0.999)
| Class | Weight |
|---|---|
| G0 | 1.000 |
| G1 | 3.138 |
| G2 | 1.396 |
| G3 | 4.530 |
| G4 | 3.656 |

**Note**: Class weights are computed in `prepareDeepLearningData.m` but NOT passed to `trainNetwork`. MATLAB's `trainNetwork` with `classificationLayer` uses cross-entropy loss without class weighting. The computed weights are stored but unused during training.

### Fine-tuning strategy (NOT IMPLEMENTED)
The config describes:
```matlab
cfg.finetune.freezeBackbone = true;
cfg.finetune.unfreezeAfterEpoch = 5;
cfg.finetune.backboneLRfactor = 0.1;
```

But `trainTransferDRClassifier.m` does NOT implement freeze/unfreeze. The backbone trains at full LR from epoch 1. Evidence from saved model:
```
conv1: WeightLearnRateFactor=1, BiasLearnRateFactor=0
res2a: WeightLearnRateFactor=1, BiasLearnRateFactor=0
fc_dr_1: WeightLearnRateFactor=10, BiasLearnRateFactor=10
```

The backbone biases are frozen (factor=0) but weights train at 1x LR (not 0.1x as intended).

---

## 3. Dataset Distribution

### Split counts (labeled images only)
| Split | Total | G0 | G1 | G2 | G3 | G4 |
|---|---|---|---|---|---|---|
| Train | 2,852 | 1,381 (48.4%) | 275 (9.6%) | 785 (27.5%) | 181 (6.3%) | 230 (8.1%) |
| Val | 611 | 296 (48.4%) | 59 (9.7%) | 168 (27.5%) | 39 (6.4%) | 49 (8.0%) |
| Test | 612 | 296 (48.4%) | 59 (9.6%) | 168 (27.5%) | 39 (6.4%) | 50 (8.2%) |

**Stratification**: Excellent — class proportions are nearly identical across splits.

### Class imbalance
- G0 dominates at 48.4% (nearly half of all images)
- G1 (9.6%), G3 (6.3%), G4 (8.1%) are minority classes
- G2 (27.5%) is the second-largest class

### Split metadata
- Seed: 42
- Splitting: Patient-grouped stratified (where patient_id available)
- Leakage check: No patient leakage detected
- Total patients: 3,662 grouped, 2,462 singleton images

---

## 4. Label Integrity

### Class mapping
```matlab
cfg.grades = 0:4;
cfg.gradeLabels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'Proliferative DR'};
categorical(0:4) maps to {0, 1, 2, 3, 4}
```

### Classification layer
```matlab
classificationLayer('Name', 'classification', 'Classes', categorical(0:4))
```

Output order: scores(1)=P(G0), scores(2)=P(G1), ..., scores(5)=P(G4)

**No mapping errors detected.** The class ordering is consistent between training and inference.

---

## 5. Test-Set Performance (Phase 8 original evaluation)

The Phase 8 test confusion matrix (from `phase8_summary.json`):

| | Pred G0 | Pred G1 | Pred G2 | Pred G3 | Pred G4 | Total |
|---|---|---|---|---|---|---|
| **True G0** | 283 | 7 | 6 | 0 | 0 | 296 |
| **True G1** | 8 | 31 | 20 | 0 | 0 | 59 |
| **True G2** | 10 | 15 | 129 | 4 | 10 | 168 |
| **True G3** | 4 | 0 | 19 | 7 | 9 | 39 |
| **True G4** | 1 | 3 | 20 | 7 | 19 | 50 |

**Accuracy: 76.6%** | **Macro F1: 0.542** | **Balanced Accuracy: 56.2%**

### Per-class recall (test set)
| Class | Recall | Interpretation |
|---|---|---|
| G0 | 95.6% | Excellent — model can identify no-DR |
| G1 | 52.5% | Moderate — struggles with mild NPDR |
| G2 | 76.8% | Good — strongest non-G0 class |
| G3 | 17.9% | Poor — severe NPDR rarely detected |
| G4 | 38.0% | Weak — PDR partially detected |

**This is NOT a G2-collapse model.** The test set shows genuine 5-class discrimination, albeit with weakness in G3/G4.

---

## 6. Additional Issues Found

### 6.1 Class weights not applied
`prepareDeepLearningData.m` computes class weights:
```matlab
classWeights = [1.0, 3.14, 1.40, 4.53, 3.66]
```
But these are never passed to `trainNetwork`. The training uses standard cross-entropy loss, which is dominated by the G0 majority class.

### 6.2 Fine-tuning strategy not implemented
The config describes freeze-backbone-then-unfreeze, but the training script never freezes or unfreezes layers. The backbone trains at full LR from epoch 1, risking catastrophic forgetting of pretrained features.

### 6.3 No training logs persisted
`phase8_summary.json` records `trainTime: 0` and all `trainInfo` fields as null. The model was loaded from a pre-saved file. No epoch-by-epoch training/validation loss curves were saved. This makes it impossible to diagnose training dynamics.

### 6.4 Config uses Phase 7 for data preparation
`runPhase8TransferLearning.m` calls `prepareDeepLearningData(cfg7)` with the Phase 7 config, not the Phase 8 config. Both configs have identical data paths, so this doesn't affect the current results, but it's a maintenance risk.

### 6.5 Resize method mismatch
- Training: `augmentedImageDatastore` uses bilinear resize by default
- Our audit: uses bicubic resize
- This is a minor difference (49/50 agreement between raw methods) but should be standardized

---

## 7. Corrective Actions Required

### CRITICAL: Fix preprocessing in all inference code

Every file that runs the classifier must use raw pixel values (0-255) without ImageNet normalization:

**Files to fix:**
1. `classifierForensicAudit.m` — remove ImageNet normalization
2. `runPhase20C1.m` — `preprocessFundus()` must NOT normalize
3. `runPhase20CSystemComparison.m` — same fix
4. `gradcamSimple.m` — must match training preprocessing
5. `drScreeningGUIv2.m` — must match training preprocessing
6. All validation scripts that call `classify(net, ...)`

**Correct preprocessing:**
```matlab
% CORRECT: resize only, no normalization
imgR = imresize(img, [224 224], 'bicubic');
pred = classify(net, imgR);

% WRONG: ImageNet normalization
imgR = imresize(img, [224 224], 'bicubic');
n = double(imgR) / 255;
n(:,:,1) = (n(:,:,1) - 0.485) / 0.229;
n(:,:,2) = (n(:,:,2) - 0.456) / 0.224;
n(:,:,3) = (n(:,:,3) - 0.406) / 0.225;
pred = classify(net, n);  % WRONG — out-of-distribution
```

### HIGH: Implement class-weighted loss
The computed class weights should be applied during training to handle the 48.4% G0 imbalance.

### HIGH: Implement freeze/unfreeze fine-tuning
The backbone should be frozen for initial epochs, then unfrozen at lower LR.

### MEDIUM: Persist training logs
Save epoch-by-epoch loss, accuracy, and per-class metrics for future auditing.

### LOW: Standardize resize method
Use bilinear (matching `augmentedImageDatastore`) consistently.

---

## 8. Revised Assessment of the Frozen Model

With correct preprocessing, the frozen model is:

| Metric | Value | Assessment |
|---|---|---|
| 5-class accuracy | 76.6% | Moderate — better than Phase 7 native (67.8%) |
| G0 recall | 95.6% | Excellent |
| G1 recall | 52.5% | Moderate |
| G2 recall | 76.8% | Good |
| G3 recall | 17.9% | Poor — needs improvement |
| G4 recall | 38.0% | Weak — needs improvement |
| Referable sensitivity | 97.7% | Excellent for screening |
| Referable specificity | 85.4% | Meets clinical target |
| Referable AUC | 0.975 | Excellent |

**The model is NOT broken.** It's a reasonable first-generation classifier that:
- Excels at the screening task (G0 vs referable)
- Has meaningful but imperfect 5-class discrimination
- Struggles with minority classes (G3, G4) due to class imbalance
- Was being evaluated with wrong preprocessing, causing artificial G2 collapse

---

## 9. Implications for Phase 21

### Option A (retrained model) — LESS URGENT
The frozen model may be usable after fixing preprocessing. The 76.6% accuracy and 0.975 AUC are reasonable starting points.

### Option B (ordinal/multitask) — STILL BENEFICIAL
Even with correct preprocessing, the G3/G4 weakness (17.9%/38.0% recall) suggests the model would benefit from ordinal regression or multitask learning.

### Option C (dataset improvement) — STILL BENEFICIAL
Class imbalance (G0=48.4%, G3=6.3%) limits minority class performance regardless of preprocessing.

### Priority order:
1. **IMMEDIATE**: Fix preprocessing in all inference code → re-run 20C.1 with correct preprocessing
2. **SHORT-TERM**: Re-evaluate the frozen model's true performance
3. **MEDIUM-TERM**: Decide on retraining based on corrected evaluation

---

## Output Files

- `matlab/validation/checkPreprocessingMismatch.m` — Diagnostic script
- `results/phase20d1/` — Phase 20D.1 results (computed with wrong preprocessing — DO NOT USE for conclusions)
- This document

## Data Files

- `results/transfer_learning/phase8_summary.json` — Training summary with correct test-set metrics
- `data/splits/train.csv` — Training split (2,852 labeled images)
- `data/splits/val.csv` — Validation split (611 labeled images)
- `data/splits/test.csv` — Test split (612 labeled images)
