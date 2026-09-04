# DR-Screening-AI

**AI-Assisted Diabetic Retinopathy Screening — Research Prototype**

> **Status (September 2026):** The DR classifier has been internally evaluated on the project's development dataset. Handcrafted lesion detectors were externally validated on IDRiD and DDR and failed to generalize. We are transitioning to learned lesion segmentation. FGADR dataset access has been requested.

> **This is NOT a clinical diagnostic device.** It is a research prototype developed for educational purposes. All thresholds are experimentally derived and have not been clinically validated.

---

## Current Component Status

| Component | Status | Evidence |
|-----------|--------|----------|
| Fundus preprocessing | ✅ Validated | `docs/PHASE20H_SYSTEM_FREEZE.md` |
| DR classification (5-class) | ✅ Frozen / internally evaluated | 79.5% accuracy, 91.0% referable sensitivity |
| Referable DR screening | ✅ Evaluated | 91.0% sensitivity / 91.5% specificity |
| Confidence calibration | ✅ Evaluated | ECE = 0.033 |
| Grad-CAM explainability | ⚠️ Implemented | Limitations documented (`docs/PHASE21_ERROR_ANALYSIS.md`) |
| MA detection | ❌ External validation failed | 0/54 on IDRiD, 0/50 on DDR |
| HE detection | ❌ External validation failed | Dice = 0.033 on IDRiD |
| EX detection | ❌ External validation failed | Dice = 0.011 on IDRiD |
| Clinical report with lesion counts | ⚠️ Experimental | Marked "not clinically validated" in output |
| FGADR external validation | ⏳ Access requested | Awaiting response from dataset authors |
| Learned lesion segmentation | ⏳ Planned | Next development stage |
| External clinical validation | ⏳ Future work | — |

---

## Research Summary

### Problem

Diabetic retinopathy (DR) affects 100 million people globally. Early screening can prevent vision loss, but manual grading is time-consuming and requires trained ophthalmologists. This project explores whether deep learning can assist in DR screening from fundus images.

### Approach

1. **Preprocessing:** Fundus normalization, background removal, quality assessment
2. **Classification:** ResNet-18 transfer learning for 5-class DR grading (G0–G4)
3. **Lesion detection:** Handcrafted morphological detectors for MA, HE, EX, NV
4. **Explainability:** Grad-CAM for model attention visualization

### What we validated

| Experiment | Dataset | Result |
|------------|---------|--------|
| Classifier accuracy | APTOS (internal test set, 612 images) | 79.5% |
| Referable DR sensitivity | APTOS (internal test set) | 91.0% |
| Referable DR specificity | APTOS (internal test set) | 91.5% |
| Classifier generalization | Frozen model, no retraining since Phase 8 | Locked |
| Preprocessing correctness | SHA256-verified frozen assets | Confirmed |

### What failed

| Experiment | Dataset | Result |
|------------|---------|--------|
| MA detection | IDRiD (54 images, expert masks) | Dice = 0.000 |
| HE detection | IDRiD (53 images, expert masks) | Dice = 0.033 |
| EX detection | IDRiD (54 images, expert masks) | Dice = 0.011 |
| MA detection | DDR (60 images, expert masks) | 0% detection |
| HE detection | DDR (60 images, expert masks) | 50% detection (worse than IDRiD) |
| EX detection | DDR (60 images, expert masks) | 0% detection |

**Conclusion:** The handcrafted morphological detectors do not generalize beyond their APTOS training domain. Resolution adaptation alone does not fix the problem — the failure is dataset-domain generalization, not resolution scaling.

### Why this matters

The lesion detectors produce outputs (e.g., "MA=24, HE=13") that have been presented as supporting evidence. These counts are **not clinically validated** and should not be interpreted as confirmed medical findings. The clinical report output now includes an explicit disclaimer.

### What we plan to do

1. **Phase 24B.4–5:** Complete FGADR evaluation when access is granted
2. **Phase 25:** Replace handcrafted detectors with U-Net learned segmentation trained on multi-dataset expert masks
3. **Phase 26:** Integrate validated lesion evidence with the DR classifier
4. **Phase 27:** External clinical validation

---

## Repository Structure

```
DR_Screening/
├── README.md                          ← This file
├── docs/
│   ├── PROJECT_STATUS.md              ← Unified status document
│   ├── VALIDATION_SUMMARY.md          ← Evidence summary
│   ├── ARCHITECTURE.md                ← System architecture
│   ├── LIMITATIONS.md                 ← Known limitations
│   ├── DATASETS.md                    ← Dataset inventory
│   ├── REPRODUCIBILITY.md             ← How to reproduce results
│   │
│   │  ── Validation evidence ──
│   ├── PHASE20H_SYSTEM_FREEZE.md      ← Frozen model hashes
│   ├── PHASE21_ERROR_ANALYSIS.md      ← Error analysis
│   ├── PHASE22_CALIBRATION.md         ← Calibration results
│   ├── PHASE24B1_IDRID_LESION_VALIDATION.md  ← IDRiD lesion failure
│   ├── PHASE24B2_FORENSIC_ALIGNMENT.md       ← Forensic verification
│   ├── PHASE24B3_DDR_EXTERNAL_VALIDATION.md  ← DDR external failure
│   │
│   │  ── Earlier phases (detailed) ──
│   ├── PHASE1_*.md through PHASE19_*.md
│   └── ...
│
├── matlab/
│   ├── lesions/                       ← Handcrafted detectors (frozen, not validated)
│   ├── classification/                ← ResNet-18 classifier
│   ├── explainability/                ← Grad-CAM
│   ├── validation/                    ← Evaluation scripts
│   ├── annotation/                    ← Three-reader annotation tool
│   ├── clinical/                      ← Clinical report generator
│   ├── shared/                        ← Preprocessing, utilities
│   └── ...
│
├── data/
│   ├── raw/                           ← Excluded from git (.gitignore)
│   │   ├── APTOS2019/
│   │   ├── IDRiD/
│   │   ├── DDR/
│   │   └── Messidor2/
│   └── processed/                     ← Manifests, splits
│
├── results/                           ← Excluded from git (regenerable)
│   ├── transfer_learning/             ← Frozen model
│   ├── phase22_calibration/
│   ├── phase24b1_idrid/
│   ├── phase24b3_ddr/
│   └── ...
│
└── models/                            ← Trained models (excluded from git)
```

---

## Key Documents

**For a quick understanding:**
1. `docs/PROJECT_STATUS.md` — What works, what doesn't, what's planned
2. `docs/VALIDATION_SUMMARY.md` — All validation results in one place
3. `docs/LIMITATIONS.md` — What this system cannot do

**For validation evidence:**
4. `docs/PHASE20H_SYSTEM_FREEZE.md` — Frozen model SHA256 hashes
5. `docs/PHASE24B1_IDRID_LESION_VALIDATION.md` — Why lesion detectors fail
6. `docs/PHASE24B3_DDR_EXTERNAL_VALIDATION.md` — Cross-dataset failure confirmation

**For reproducibility:**
7. `docs/REPRODUCIBILITY.md` — How to run the evaluation pipeline
8. `matlab/validation/` — All evaluation scripts

---

## Datasets

| Dataset | Images | Role | Lesion Masks | Status |
|---------|--------|------|-------------|--------|
| APTOS 2019 | 5,590 | Development (train/val/test) | No | ✅ Used |
| IDRiD | 494 | Development + lesion validation | Yes (MA, HE, EX, SE) | ✅ Used for external eval |
| DDR | ~10,000 | External lesion validation | Yes (MA, HE, EX, SE) | ✅ 60 images downloaded |
| DRIVE | 40 | Vessel segmentation | Yes (vessels) | ✅ Used |
| Messidor-2 | 1,748 | External validation (grading) | No | ⏳ Pending label verification |
| FGADR | 1,842 | Multi-dataset training + eval | Yes (MA, HE, EX, SE, IRMA, NV) | ⏳ Access requested |

**Split policy:** Patient-level, no leakage, seed 42. Test set frozen since Phase 8 (commit `cc7bed8`).

---

## Quick Start

### Prerequisites

- MATLAB R2026a with Image Processing, Computer Vision, Deep Learning Toolboxes
- Python 3.14+ (for annotation tool and dataset utilities)

### Run the evaluation

```matlab
% Add all code to path
addpath(genpath('matlab'));

% Verify frozen model integrity
% (should match hashes in docs/PHASE20H_SYSTEM_FREEZE.md)
load('results/transfer_learning/models/trainedNetTL.mat');

% Run IDRiD lesion validation
validatePhase24B1();

% Run DDR external validation
validatePhase24B3_DDR();
```

### Run the annotation tool (for future clinical validation)

```bash
cd matlab/annotation
python app.py
# Opens at http://localhost:5000
```

---

## Technology

- **MATLAB R2026a** — Image processing, deep learning, evaluation
- **Python 3.14** — Annotation tool, dataset utilities
- **ResNet-18** — Transfer learning for DR classification
- **Grad-CAM** — Model attention visualization
- **Flask** — Annotation tool backend

---

## Team

| Member | Role | Primary |
|--------|------|---------|
| THARUN BALAJI | AI / MATLAB / Deep Learning | Classifier, preprocessing, validation |
| THARUN | Backend / Database / Integration | FastAPI, database, API |
| NARENDRA N | Frontend / UI/UX | React, visualization |

All members share: development, testing, documentation, research.

---

## Disclaimer

This is a research prototype and educational system. It is NOT:
- A clinical diagnostic device
- Cleared by any regulatory authority
- Validated for clinical use
- A replacement for expert ophthalmologists

Lesion detection outputs are experimental algorithmic results, not confirmed medical findings. The DR classifier has been internally evaluated but not externally validated on independent clinical data.

---

## License

Research use only. See `docs/DATASET_PROVENANCE.md` for dataset licensing.
