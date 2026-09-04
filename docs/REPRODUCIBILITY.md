# Reproducibility Guide

**Last updated:** September 2026

How to reproduce the evaluation results in this repository.

---

## Prerequisites

- **MATLAB R2026a** with:
  - Image Processing Toolbox
  - Computer Vision Toolbox
  - Deep Learning Toolbox
  - Statistics and Machine Learning Toolbox
- **Python 3.14+** (for annotation tool and dataset utilities)
- **Git** (for version control)

---

## Repository Setup

```bash
git clone https://github.com/<your-org>/DR_Screening.git
cd DR_Screening
```

---

## Dataset Setup

### APTOS 2019

Download from [Kaggle](https://www.kaggle.com/c/aptos2019-blindness-detection):

```bash
# Place images in:
data/raw/APTOS2019/train_images/
data/raw/APTOS2019/test_images/
```

### IDRiD

Download from [Kaggle](https://www.kaggle.com/datasets/google-brain/p diabetic-retinopathy-detection):

```bash
# Place in:
data/raw/IDRiD/
```

### DDR

Download from [Hugging Face](https://huggingface.co/datasets/ctmedtech/DDR-dataset):

```bash
# Or use the download utility:
python matlab/validation/download_ddr.py
```

### DRIVE

Download from [STARE](http://www.isi.uu.nl/Research/Databases/DRIVE/):

```bash
# Place in:
data/raw/DRIVE/
```

---

## Verify Frozen Model Integrity

```matlab
addpath(genpath('matlab'));
load('results/transfer_learning/models/trainedNetTL.mat');

% Verify SHA256 hashes match docs/PHASE20H_SYSTEM_FREEZE.md
% trainedNetTL.mat: 59AFAFF30CEA618A05BC081A314191BDEEDF2C9B450B804D12A6F3D8E4EBA69C
% preprocessFundus.m: 03A273CCB461EA5ED47841BBFD59BDCF2029CB9D115724D954D321198CFB460C
% gradcamSimple.m: 975CC55D7D7004B5B1EDA87CFD0F85474239B34732919B0C65B02014EEF757D4
```

---

## Run IDRiD Lesion Validation (Phase 24B.1)

```matlab
addpath(genpath('matlab'));

% Run unmodified detectors on IDRiD images against expert masks
validatePhase24B1();

% Results written to:
%   results/phase24b1_idrid/summary_metrics.csv
%   results/phase24b1_idrid/bootstrap_ci.csv
%   results/phase24b1_idrid/worst_cases.csv
%   results/phase24b1_idrid/image_level_results.csv
```

**Expected results:** MA Dice = 0.000, HE Dice = 0.033, EX Dice = 0.011

---

## Run DDR External Validation (Phase 24B.3)

```matlab
addpath(genpath('matlab'));

% Run unmodified detectors on DDR images against expert masks
validatePhase24B3_DDR();

% Results written to:
%   results/phase24b3_ddr/summary_metrics.csv
%   results/phase24b3_ddr/image_level_results.csv
```

**Expected results:** MA 0% detection, HE 50% detection, EX 0% detection

---

## Run Forensic Alignment Verification (Phase 24B.2)

```matlab
addpath(genpath('matlab'));

% Verify image/mask pairing, coordinate alignment, Dice implementation
phase24b2_forensic();

% Run MA detector diagnostic mode
phase24b2_ma_diagnostic();

% Trace MA candidate loss through pipeline
phase24b2_ma_pipeline();
```

---

## Run Classifier Evaluation

```matlab
addpath(genpath('matlab'));

% Run classification pipeline on frozen test set
runPhase4Classification('verbose', true);
```

---

## Run Annotation Tool

```bash
cd matlab/annotation
pip install -r requirements.txt  # if applicable
python app.py

# Opens at http://localhost:5000
# Run QA tests:
python ../validation/phase24a_qa_test.py
```

---

## Key Commits

| Commit | Description |
|--------|-------------|
| `cc7bed8` | Frozen model (Phase 8) |
| `af312e8` | System freeze (Phase 20H) |
| `059a6e4` | Phase 22 (calibration) |
| `1c71d72` | Phase 23 (clinical framework) |
| `fd5754b` | Phase 24 (ground truth protocol) |
| `b0e734a` | Phase 24A (annotation tool) |
| `2384361` | Phase 24A.1 (QA audit) |
| `e707825` | Phase 24B (dataset validation) |
| `e698e9f` | Phase 24B.1-2 (IDRiD validation + forensic) |
| `c6f0b7a` | Phase 24B.3 (DDR external validation) |
