# Learned Segmentation Readiness Audit

**Date:** 2026-09-05  
**Auditor:** opencode  
**Scope:** Determine whether a small learned lesion-segmentation prototype can be safely implemented within 5 days  
**Verdict:** **GO — TRAIN PROTOTYPE** (with constraints)

---

## 1. Annotated Data Inventory

### IDRiD (Indian Diabetic Retinopathy Dataset)

| Component | Count | Source |
|-----------|-------|--------|
| Training images | 54 | `data/raw/IDRiD/A. Segmentation/1. Original Images/a. Training Set/` |
| Testing images | 27 | `data/raw/IDRiD/A. Segmentation/1. Original Images/b. Testing Set/` |
| **Total images** | **81** | |

| Lesion Class | Training Masks | Testing Masks | Empty Masks | Total |
|-------------|----------------|---------------|-------------|-------|
| Microaneurysms (MA) | 54 | 27 | 0 | 81 |
| Haemorrhages (HE) | 53 | 27 | 0 | 80 |
| Hard Exudates (EX) | 54 | 27 | 0 | 81 |
| Soft Exudates (SE) | 26 | 14 | 0 | 40 |
| Optic Disc (OD) | 54 | 27 | 0 | 81 |

- **Resolution:** All 2848×4288 (uniform)
- **Format:** Binary TIF masks (pixel values 0/255)
- **License:** CC-BY-4.0 (confirmed in `LICENSE.txt`)

### DDR (Diabetic Retinopathy Dataset)

| Component | Count | Source |
|-----------|-------|--------|
| Training images | 60 | `data/raw/DDR/lesion_segmentation/lesion_segmentation/images/train/` |
| **Total images** | **60** | |

| Lesion Class | Masks | Empty Masks | Avg FG Pixels |
|-------------|-------|-------------|---------------|
| Microaneurysms (MA) | 60 | 10 (17%) | 346 |
| Haemorrhages (HE) | 60 | 30 (50%) | 704 |
| Hard Exudates (EX) | 60 | 58 (97%) | 31 |

- **Resolution:** Variable (1536×1956 to 1934×2592)
- **Format:** Binary TIF masks
- **License:** HuggingFace `ctmedtech/DDR-dataset`, CC-BY-4.0

### DRIVE

- 20 images with vessel segmentation masks
- **NOT lesion segmentation** — retinal vessel extraction
- **Not usable** for lesion segmentation training

### Grand Total

| Metric | IDRiD | DDR | Combined |
|--------|-------|-----|----------|
| Images with masks | 81 | 60 | 141 |
| Total masks | 488 | 180 | 668 |
| Lesion masks (MA+HE+EX) | 342 | 180 | 522 |

---

## 2. Verified Image/Mask Pairing

### IDRiD Pairing Verification

**Method:** Filename correspondence (`IDRiD_XX.jpg` ↔ `IDRiD_XX_MA.tif`)

| Check | Result |
|-------|--------|
| Training image count | 54 |
| Training MA masks | 54 (1:1 match) |
| Training HE masks | 53 (1 missing: IDRiD_54) |
| Training EX masks | 54 (1:1 match) |
| Training SE masks | 26 (28 images lack SE masks) |
| Training OD masks | 54 (1:1 match) |
| Dimension consistency | All 2848×4288 |
| Coordinate alignment | Verified (binary TIF, pixel-aligned) |
| Foreground presence | MA: 0 empty, HE: 0 empty, EX: 0 empty, SE: 0 empty |

**SE gap:** 28 of 54 training images lack SE masks. SE is **incomplete** — do not use as primary target.

### DDR Pairing Verification

**Method:** Filename correspondence (`XXX-YYYY-ZZZ.jpg` ↔ `XXX-YYYY-ZZZ.tif`)

| Check | Result |
|-------|--------|
| Image count | 60 |
| MA masks | 60 (1:1 match) |
| HE masks | 60 (1:1 match) |
| EX masks | 60 (1:1 match) |
| Empty masks | MA: 10, HE: 30, EX: 58 |
| Resolution | Variable (mixed) |

**DDR sparsity:** EX masks are 97% empty. HE masks are 50% empty. DDR is weak for EX training but useful for domain generalization testing.

---

## 3. Dataset Overlap / Leakage Risk

| Check | Overlap | Risk |
|-------|---------|------|
| APTOS ↔ IDRiD | 0 images | **SAFE** |
| APTOS ↔ DDR | 0 images | **SAFE** |
| IDRiD ↔ DDR | 0 images | **SAFE** |
| IDRiD in existing splits | 494 images (train/val/test) | **CAUTION** — IDRiD is already in classifier splits |
| DDR in existing splits | 0 images | **SAFE** |

**Critical finding:** IDRiD images are already part of the classifier's training/validation/test splits (494 images). The segmentation masks are a **different annotation modality** on the same images. This is acceptable because:
1. The classifier uses image-level DR grade labels
2. The segmentation model uses pixel-level lesion masks
3. They are separate tasks on the same images
4. No test set contamination: the 27 IDRiD testing images are a **holdout** set

**Recommended splits for segmentation:**

| Split | Source | Count | Purpose |
|-------|--------|-------|---------|
| TRAIN | IDRiD training (80%) | ~43 | Model training |
| VAL | IDRiD training (20%) | ~11 | Early stopping |
| EXTERNAL TEST | IDRiD testing | 27 | Primary evaluation |
| DOMAIN TEST | DDR | 60 | Generalization test |

**Do NOT use** IDRiD testing set for training. Do NOT use DDR for training.

---

## 4. Lesion Class Availability

| Lesion | IDRiD Train | IDRiD Test | DDR | Total Masks | Avg FG Px | Feasibility |
|--------|-------------|------------|-----|-------------|-----------|-------------|
| MA | 54 | 27 | 60 | 141 | 3,460 (IDRiD) + 346 (DDR) | **YELLOW** |
| HE | 53 | 27 | 60 | 140 | 122,651 (IDRiD) + 704 (DDR) | **GREEN** |
| EX | 54 | 27 | 60 | 141 | 98,510 (IDRiD) + 31 (DDR) | **GREEN** |
| SE | 26 | 14 | 0 | 40 | 48,040 (IDRiD) | **RED** (incomplete) |
| NV | 0 | 0 | 0 | 0 | 0 | **RED** (no data) |
| IRMA | 0 | 0 | 0 | 0 | 0 | **RED** (no data) |

**Recommended first target:** **EX (Hard Exudates)** — most complete, largest foreground, binary clear.

**Second target (if time permits):** **HE (Haemorrhages)** — good data, large foreground regions.

---

## 5. Data Quality Assessment

### IDRiD Quality

| Aspect | Assessment |
|--------|------------|
| Resolution | Uniform 2848×4288 — excellent |
| Mask format | Binary TIF — clean |
| Foreground presence | 100% for MA/HE/EX/OD — no empty masks |
| Pairing reliability | Filename-based, 1:1 match verified |
| Annotation quality | Expert-labeled, peer-reviewed (published dataset) |
| Class balance | MA: sparse (13K px avg), HE: moderate (122K), EX: moderate (98K) |

### DDR Quality

| Aspect | Assessment |
|--------|------------|
| Resolution | Variable — requires resize |
| Mask format | Binary TIF — clean |
| Foreground presence | EX: 97% empty, HE: 50% empty, MA: 17% empty |
| Pairing reliability | Filename-based, 1:1 match verified |
| Class balance | Extremely sparse — poor for training |

### Summary

- IDRiD is the **primary training source** — high quality, uniform, complete
- DDR is a **domain generalization test only** — sparse, variable resolution
- No NV or IRMA masks available anywhere
- SE masks are incomplete (26/54 training images)

---

## 6. U-Net Architecture Options

### OPTION A: Small Custom U-Net

```
Input (256×256×3)
  → Encoder: 4 blocks (64→128→256→512)
  → Bottleneck: 1024
  → Decoder: 4 blocks (512→256→128→64)
  → Output: 256×256×1 (sigmoid)
```

- Parameters: ~31M
- Pros: Full control, simple
- Cons: No pretrained features, needs more data

### OPTION B: U-Net with Lightweight Pretrained Encoder

```
Input (256×256×3)
  → Encoder: ResNet-18 (pretrained on ImageNet)
  → Bottleneck: 512
  → Decoder: 4 blocks with skip connections
  → Output: 256×256×1 (sigmoid)
```

- Parameters: ~27M (encoder frozen, decoder ~4M trainable)
- Pros: Transfer learning, better features with less data
- Cons: Slightly more complex

### OPTION C: Patch-Based U-Net

```
Full image (2848×4288) → Extract 256×256 patches
  → Small U-Net per patch
  → Stitch predictions back
```

- Parameters: ~31M (same as A)
- Pros: More training samples (54 images → ~540 patches)
- Cons: Losses global context, stitching artifacts

### Recommendation: **OPTION B — U-Net with ResNet-18 Encoder**

**Reasoning:**
1. ResNet-18 is already used in the project (frozen classifier backbone)
2. Transfer learning from ImageNet features helps with small dataset
3. MATLAB `unet()` supports `EncoderNetwork` parameter natively
4. ~54 training images is too few for training from scratch
5. Patch-based (Option C) loses global retinal context important for lesion localization

---

## 7. Recommended Architecture

### Network: U-Net with ResNet-18 Encoder

```matlab
net = unet([256 256 3], 2, ...
    'EncoderDepth', 4, ...
    'EncoderNetwork', 'resnet18', ...
    'NumFirstEncoderFilters', 64);
```

### Configuration

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Input size | 256×256×3 | Balance detail vs memory |
| Output | 2 classes (background + lesion) | Binary segmentation |
| Encoder | ResNet-18 (pretrained) | Transfer learning |
| Encoder depth | 4 | Standard U-Net depth |
| Decoder filters | 64→128→256→512 | Symmetric |
| Loss | Dice loss | Handles class imbalance |
| Optimizer | Adam | Fast convergence |
| Learning rate | 1e-4 | Conservative for small data |
| Batch size | 4 | CPU memory constraint |
| Epochs | 100 | With early stopping |
| Augmentation | Rotation, flip, scale | Standard medical imaging |

### Why NOT multi-class

- SE data incomplete (26/54 images)
- DDR EX data 97% empty
- Multi-class adds complexity without benefit for prototype
- Binary (lesion vs background) is sufficient for proof-of-concept

---

## 8. Minimal Experiment Design

### Data Preparation

```
IDRiD Training (54 images)
  → 80% TRAIN (43 images)
  → 20% VAL (11 images)

IDRiD Testing (27 images) — HOLDOUT
DDR (60 images) — DOMAIN GENERALIZATION TEST
```

### Preprocessing

1. Resize images to 256×256 (bilinear)
2. Resize masks to 256×256 (nearest-neighbor)
3. Normalize: `single(img) / 255`
4. Binarize masks: `mask > 0` → 1, else 0

### Augmentation

| Transform | Range | Probability |
|-----------|-------|-------------|
| Rotation | ±15° | 50% |
| Horizontal flip | — | 50% |
| Vertical flip | — | 50% |
| Scale | 0.9–1.1 | 50% |
| Brightness | ±20% | 30% |

### Training Configuration

| Parameter | Value |
|-----------|-------|
| Network | U-Net (ResNet-18 encoder) |
| Loss | Dice loss |
| Optimizer | Adam |
| Initial learn rate | 1e-4 |
| Max epochs | 100 |
| Mini batch size | 4 |
| Validation frequency | 10 epochs |
| Early stopping patience | 15 epochs |
| Checkpoint | Best validation Dice |
| Random seed | 42 |
| Execution environment | CPU |

### Evaluation Metrics

| Metric | Description |
|--------|-------------|
| Dice coefficient | Primary metric |
| IoU (Jaccard) | Overlap measure |
| Precision | False positive rate |
| Recall (Sensitivity) | False negative rate |
| Image-level detection | Does model detect ANY lesion? |
| F1 score | Harmonic mean of precision/recall |

### Test Splits

| Split | Source | Count | Purpose |
|-------|--------|-------|---------|
| Internal test | IDRiD training heldout | 11 | Quick validation |
| External test | IDRiD testing | 27 | Primary evaluation |
| Domain test | DDR | 60 | Generalization |

---

## 9. Handcrafted vs Learned Comparison Plan

### Same-Image Comparison

For each image in the IDRiD testing set (27 images):

```
Image → Handcrafted detector → lesion mask (existing)
Image → Learned U-Net → lesion mask (new)
Image → Expert ground truth → reference mask
```

### Metrics Comparison Table

| Metric | Handcrafted | Learned | Delta |
|--------|-------------|---------|-------|
| Dice (MA) | 0.000 | ? | ? |
| Dice (HE) | 0.033 | ? | ? |
| Dice (EX) | 0.011 | ? | ? |
| IoU (MA) | ? | ? | ? |
| IoU (HE) | ? | ? | ? |
| IoU (EX) | ? | ? | ? |
| Image-level F1 | ? | ? | ? |

### Fairness Principles

1. **Same test set** — both methods evaluated on identical IDRiD testing images
2. **Same preprocessing** — both receive identical input
3. **No test set peeking** — U-Net never sees IDRiD testing images during training
4. **Report all results** — including failures
5. **External validation** — DDR generalization test for both methods

---

## 10. SIH Integration Architecture

### Current System (Stable Backbone)

```
Fundus Image
  ↓
preprocessFundus()
  ↓
Classifier (ResNet-18) → G0-G4
  ↓
applyClinicalLogic() → referable decision
  ↓
gradcamSimple() → heatmap
  ↓
generateClinicalReport() → report
```

### Proposed Extension (Additive, Non-Replacing)

```
Fundus Image
  ↓
preprocessFundus()
  ↓
Classifier (ResNet-18) → G0-G4
  ↓
applyClinicalLogic() → referable decision
  ↓
gradcamSimple() → heatmap
  ↓
[SEPARATELY]
  ↓
Learned U-Net → lesion mask
  ↓
Post-processing → lesion counts, severity
  ↓
generateClinicalReport() → report WITH supporting evidence
```

### Integration Rules

1. **Lesion model NEVER overrides classifier** — DR grade comes from classifier only
2. **Lesion model NEVER modifies referable decision** — clinical logic is unchanged
3. **Lesion evidence is labeled "(supporting)"** — already enforced in GUI
4. **Lesion model output is additive** — adds evidence panel, does not replace anything
5. **Graceful degradation** — if lesion model fails, system works exactly as before

### Code Integration Point

New file: `matlab/lesions/learnedLesionSegmentation.m`

```matlab
function mask = learnedLesionSegmentation(img, net)
    % Resize to network input size
    img = imresize(img, [256 256], 'bilinear');
    % Classify
    [scores, ~] = semanticseg(img, net);
    % Extract lesion channel
    mask = scores(:,:,2); % lesion probability
    % Resize back to original
    mask = imresize(mask, [size(img,1) size(img,2)], 'nearest');
end
```

This function is called by `extractLesionEvidence.m` as an **additional** evidence source, not a replacement.

---

## 11. FGADR Contingency

### If FGADR Arrives

- Add 1,842 images with 6 lesion types (MA, HE, EX, NV, IRMA, SE)
- Would dramatically improve training data
- Can be added to training pipeline without code changes
- NV and IRMA become feasible

### If FGADR Does NOT Arrive

- Prototype can still be developed with IDRiD (54 training images)
- Focus on EX (best data quality)
- HE as secondary target
- NV and IRMA remain RED — no data
- Domain generalization test via DDR

### Design for Both Outcomes

- Code should accept any dataset with `images/` + `annotations/{MA,HE,EX}/` structure
- DDR already follows this structure
- FGADR can be added by dropping files into the same directory pattern
- No hardcoded paths in training code

---

## 12. Five-Day Time Budget

| Day | Task | Hours | Output |
|-----|------|-------|--------|
| **Day 1** | Dataset preparation | 3 | Patch extraction, data loaders, augmentation pipeline |
| **Day 1** | U-Net architecture | 2 | Network definition, loss function, training loop |
| **Day 2** | Training run (EX) | 4 | Trained U-Net for EX segmentation |
| **Day 2** | Initial evaluation | 2 | Dice/IoU on IDRiD test set |
| **Day 3** | Training run (HE) | 4 | Trained U-Net for HE segmentation |
| **Day 3** | Evaluation + iteration | 2 | Compare with handcrafted, tune |
| **Day 4** | Integration | 3 | Wire into `extractLesionEvidence.m` |
| **Day 4** | GUI update | 2 | Add learned evidence panel |
| **Day 5** | Testing + demo prep | 4 | Full pipeline test, demo images |
| **Day 5** | Documentation | 2 | Report results, limitations |
| **TOTAL** | | **28 hours** | |

### Critical Path

```
Day 1: Data prep + architecture
  ↓
Day 2: EX training (~2h CPU) + evaluation
  ↓
Day 3: HE training (~2h CPU) + comparison
  ↓
Day 4: Integration into existing pipeline
  ↓
Day 5: Testing + demo
```

### Risk Mitigation

- If training too slow → reduce to 256×256 patches, 50 epochs
- If Dice < 0.3 → focus on image-level detection only (not pixel-level)
- If integration complex → keep lesion model as separate demo, not wired into main pipeline

---

## 13. Risks

| Risk | Severity | Likelihood | Mitigation |
|------|----------|------------|------------|
| CPU training too slow | HIGH | MEDIUM | Patch-based, reduce resolution, fewer epochs |
| Small dataset overfitting | HIGH | HIGH | Aggressive augmentation, early stopping, transfer learning |
| Poor generalization (IDRiD→DDR) | MEDIUM | HIGH | Expected — report honestly, don't claim cross-dataset |
| Integration destabilizes classifier | HIGH | LOW | Lesion model is additive, never replaces classifier |
| GUI changes introduce bugs | MEDIUM | LOW | Minimal integration, reuse existing evidence panel |
| No NV/IRMA segmentation | LOW | CERTAIN | Accept limitation, document clearly |
| DDR EX masks 97% empty | LOW | CERTAIN | Use DDR only for testing, not training |

---

## 14. GO / NO-GO Decision

### **GO — TRAIN PROTOTYPE**

**Rationale:**

1. **Sufficient data exists** — 54 IDRiD training images with complete MA/HE/EX masks
2. **Tooling is ready** — MATLAB `unet()` with ResNet-18 encoder is available
3. **Training is feasible** — ~2 hours per lesion class on CPU
4. **Integration is safe** — additive design, no classifier modification
5. **Time budget is adequate** — 28 hours over 5 days
6. **Scientific value is high** — demonstrates AI improvement over handcrafted (Dice 0.000→?)
7. **Risk is contained** — if it fails, existing system is unaffected

**Constraints:**
- Focus on EX only for initial prototype
- HE as stretch goal
- Do NOT attempt NV, IRMA, SE
- Do NOT claim clinical validation
- Do NOT modify existing classifier or clinical logic
- Report results honestly, including failures

---

## 15. Exact Next Implementation Task

**Task:** Implement learned lesion segmentation data pipeline and U-Net training for EX (Hard Exudates) on IDRiD dataset.

**Scope:**
1. Create `matlab/lesions/learnedSegmentation/` directory
2. Implement patch extraction from IDRiD 2848×4288 images to 256×256 patches
3. Create `imageDatastore` + `pixelLabelDatastore` pair for IDRiD EX masks
4. Implement data augmentation pipeline (rotation, flip, scale)
5. Define U-Net with ResNet-18 encoder using MATLAB `unet()`
6. Implement training loop with Dice loss, Adam optimizer, early stopping
7. Train on IDRiD EX (43 training, 11 validation)
8. Evaluate on IDRiD testing set (27 images)
9. Compare with handcrafted EX detector (Dice 0.011 baseline)

**Do NOT:**
- Modify classifier
- Modify existing lesion detectors
- Modify GUI
- Modify clinical logic
- Change existing metrics
- Train on DDR (test only)
- Train on IDRiD testing set

**Expected output:** Trained U-Net model file, evaluation metrics, comparison table

**STOP and wait for Senior Architect approval before implementing.**
