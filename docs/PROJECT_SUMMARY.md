# DR Screening AI — Project Summary

## Overview

An end-to-end MATLAB pipeline for automated diabetic retinopathy (DR) screening, progressing from data ingestion through handcrafted-feature classification to deep learning with transfer learning. The project demonstrates a rigorous, evidence-based approach with phased development, auditing, and statistical validation.

## Clinical Target

> **Sensitivity > 90% AND Specificity > 85%** for referable DR detection

**Target achieved** by the transfer-learning model (Phase 8).

## Phase-by-Phase Progression

### Phase 1–3: Data Foundation & Feature Engineering

- **Phase 1:** Dataset ingestion (APTOS2019, IDRiD, DRIVE, Messidor-2), manifest creation (7872 images), patient-level train/val/test splits (70/15/15)
- **Phase 2:** Image quality assessment — 7 metrics, 3 quality states (GOOD/BORDERLINE/UNGRADABLE)
- **Phase 3:** Retinal structure analysis — 12 modules, vessel/lesion/optic disc segmentation, 25-feature clinical vector

### Phase 4: SVM Classification Baseline

- **5-class ECOC-SVM** + binary referable SVM
- **Test results:** accuracy=0.632, sens=0.759, spec=0.862, AUC=0.810
- **Limitation:** Handcrafted features cannot capture complex DR patterns

### Phase 5–5.1: Explainability

- Grad-CAM attention maps, lesion overlays, evidence bars
- Real Phase 3 masks (not synthetic) with provenance tracking
- 612/612 images successfully explained

### Phase 6: Classification Audit

- Identified handcrafted-feature bottleneck
- Best achievable AUC: 0.843 on validation
- Clinical target NOT achievable with SVM approach
- **Recommendation:** Deep learning features needed

### Phase 7: Native ResNet-18

- Untrained ResNet-18 (random initialization)
- **Test results:** sens=0.953, spec=0.747, AUC=0.878
- **Problem:** Overparameterized (11.5M params / 2,792 images = 4,119:1)
- Specificity too low for clinical target

### Phase 7 Audit

- Root cause: overparameterization + small data
- Statistical comparison: McNemar p < 0.001 vs SVM
- **Recommendation:** Transfer learning (ImageNet pretraining)

### Phase 8: Transfer Learning ✅

- ImageNet-pretrained ResNet-18 (converted from PyTorch)
- **Test results: sens=0.977, spec=0.854, AUC=0.975**
- **Clinical target ACHIEVED**
- McNemar p < 0.001 vs both baselines
- Bootstrap 95% CIs: Sens [0.956, 0.992], Spec [0.816, 0.891], AUC [0.964, 0.984]

## Final Results

| Model | Sensitivity | Specificity | AUC | Target |
|-------|------------|------------|-----|--------|
| SVM Baseline | 75.9% | 86.2% | 0.810 | ❌ |
| Native ResNet-18 | 95.3% | 74.7% | 0.878 | ❌ |
| **Transfer Learning** | **97.7%** | **85.4%** | **0.975** | **✅** |

## Key Metrics (Transfer Learning)

| Metric | Value | 95% CI |
|--------|-------|--------|
| Five-class accuracy | 0.766 | — |
| Balanced accuracy | 0.562 | — |
| Macro F1 | 0.542 | — |
| Macro AUC | 0.927 | — |
| Referable sensitivity | 0.977 | [0.956, 0.992] |
| Referable specificity | 0.854 | [0.816, 0.891] |
| Referable AUC | 0.975 | [0.964, 0.984] |
| False negatives | 6 (1.0%) | — |
| False positives | 52 (8.5%) | — |

## Limitations

1. **Domain shift:** IDRiD specificity (59.1%) much lower than APTOS (87.1%)
2. **Specificity CI lower bound:** 81.6% is below 85% — borderline at 95% CI
3. **Small dataset:** 2,792 training images for 11.5M parameters
4. **No external validation:** Only tested on APTOS2019 + IDRiD
5. **No clinical validation:** All metrics are research-only
6. **Class imbalance:** Grade 3 (39 test images) and Grade 4 (50) severely underrepresented

## Claims

### Supported

> The transfer-learning model achieved the predefined sensitivity (>90%) and specificity (>85%) targets on the held-out 612-image test set.

> Transfer learning substantially improved both sensitivity and AUC compared with the handcrafted-feature SVM and native (randomly-initialized) ResNet-18.

### NOT Supported

> ~~The model is clinically validated.~~
> ~~The model achieves >90% sensitivity and >85% specificity in all clinical settings.~~
> ~~The model generalizes across all DR grading populations.~~

## File Structure

```
DR_Screening/
├── data/
│   ├── processed/manifest.csv          # 7872-row dataset manifest
│   └── splits/{train,val,test}.csv     # Patient-level splits
├── matlab/
│   ├── data/                           # Phase 1: data ingestion
│   ├── quality/                        # Phase 2: quality assessment
│   ├── structures/                     # Phase 3: retinal structures
│   ├── classification/                 # Phase 4-6: SVM + audit
│   ├── deeplearning/                   # Phase 7: native ResNet-18
│   └── transfer/                       # Phase 8: transfer learning
├── results/
│   ├── quality/                        # Phase 2 outputs
│   ├── phase3/                         # Phase 3 outputs + masks
│   ├── classification/                 # Phase 4-6 outputs
│   ├── deep_learning/                  # Phase 7 outputs
│   └── transfer_learning/              # Phase 8 outputs
├── docs/
│   ├── PHASE7_DEEP_LEARNING.md
│   ├── PHASE7_AUDIT.md
│   ├── PHASE8_TRANSFER_LEARNING.md
│   ├── REPRODUCIBILITY.md
│   └── PROJECT_SUMMARY.md              # This file
└── README.md
```

## Reproducibility

See `docs/REPRODUCIBILITY.md` for complete reproduction instructions, including:
- MATLAB version and toolboxes
- Random seeds
- Training configuration
- Dataset splits
- Model artifacts
- Expected results
