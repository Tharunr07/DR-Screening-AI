# DR-Screening-AI

**AI-Powered Diabetic Retinopathy Screening Platform**

Research prototype / educational system. NOT a clinical diagnostic device.

---

## Project Status

| Phase | Name | Status |
|-------|------|--------|
| 1 | Dataset Foundation | COMPLETE (PASS 10/10) |
| 1.5 | Real Dataset Acquisition | COMPLETE (7872 images) |
| 2 | Image Quality Assessment + Preprocessing | COMPLETE (7872 assessed, 12/12 tests PASS) |
| 3 | Retinal Structures + Lesion Analysis | COMPLETE (12/12 tests PASS, DRIVE+IDRiD validated) |
| 4 | DR Severity Classification | FUTURE |
| 5 | Explainability (Grad-CAM) | FUTURE |
| 6 | Backend Integration (FastAPI) | FUTURE |
| 7 | Frontend (React) | FUTURE |
| 8 | Simulink System Model | FUTURE |

---

## Datasets

| Dataset | Images | Split Role | Labels |
|---------|--------|------------|--------|
| APTOS 2019 | 5590 | Development (train/val/test) | DR grades available |
| IDRiD | 494 | Development (train/val/test) | DR grades + lesion annotations |
| DRIVE | 40 | Development (train/val/test) | Vessel annotations |
| Messidor-2 | 1748 | External validation only | Labels must be verified |

**Total**: 7872 manifest rows

**Splits** (seed 42, patient-level, no leakage):
- Train: 4286
- Validation: 918
- Test: 920
- External (Messidor-2): 1748

---

## System Workflow

```
Retinal Fundus Image
        |
        v
Image Quality Assessment (Phase 2)  <-- CURRENT
        |
        v
Preprocessing / Enhancement (Phase 2)
        |
        v
Retinal Structure Analysis (Phase 3)
        |
        v
Lesion Analysis (Phase 3)
        |
        v
DR Severity Classification (Phase 4)
        |
        v
Confidence / Risk Assessment (Phase 4)
        |
        v
Explainability - Grad-CAM (Phase 5)
        |
        v
Doctor Review (Phase 7)
        |
        v
Report (Phase 7)
        |
        v
Database / Screening History (Phase 6)
```

---

## Technology Stack

- **MATLAB R2026a** — Image Processing, Computer Vision, Deep Learning, Statistics & ML Toolboxes
- **Python/FastAPI** — Backend API (Phase 6)
- **React** — Frontend UI (Phase 7)
- **Simulink** — System simulation (Phase 8)
- **Database** — Screening history (Phase 6)

---

## Team

### Member A — THARUN BALAJI

**Primary**: AI / Data / MATLAB / Simulink

- Dataset management, cleaning, documentation
- Image Quality Assessment
- Image preprocessing
- Deep learning, model training, validation, evaluation
- Grad-CAM / Explainable AI
- MATLAB implementation
- Simulink implementation
- AI inference pipeline

**Backup**: FastAPI integration, API I/O, database, basic frontend

### Member B — THARUN

**Primary**: Backend / Database / AI Integration

- FastAPI, authentication, patient APIs, screening APIs
- Database design and management
- AI model integration
- Image/file handling, result storage
- Report generation
- Backend testing

**Backup**: React/API integration, frontend debugging, basic AI pipeline

### Member C — NARENDRA N

**Primary**: Frontend / UI/UX

- React, UI/UX design
- Landing page, login, dashboard
- Patient management, image upload
- Screening interface, result page
- Grad-CAM visualization
- Doctor review UI, reports UI
- Charts, responsive design
- Frontend testing

**Backup**: AI/ML workflow, dataset structure, basic MATLAB, backend API

All three members share: development, testing, documentation, integration, debugging, research, presentation, demonstration.

---

## Quick Start

### Phase 1 (Dataset Foundation)

```matlab
addpath(genpath('matlab'));
cfg = datasetConfig();
generateManifest();
runAudit();
generateSplits();
validatePhase1();
```

### Phase 2 (Quality Assessment)

```matlab
addpath(genpath('matlab'));
cfg = qualityConfig();
stats = runQualityAssessment('maxImages', 100, 'verbose', true);
generateQualityReport();
```

### Phase 3 (Structure + Lesion Analysis)

```matlab
addpath(genpath('matlab'));
% Run synthetic tests (12/12 should pass)
res = testPhase3Pipeline('verbose', true);

% Batch analysis on DRIVE (vessel validation)
stats = runPhase3Analysis('datasets', 'DRIVE', 'maxImages', 40, 'verbose', true);

% Batch analysis on IDRiD (lesion validation)
stats = runPhase3Analysis('datasets', 'IDRiD', 'maxImages', 494, 'verbose', true);

% Full batch analysis
stats = runPhase3Analysis('verbose', true);
```

---

## Structure

```
DR_Screening/
  data/
    raw/                    # Manual download per docs/DATASET_DOWNLOAD_GUIDE.md
    processed/              # manifest.csv, manifest_with_quality.csv
    splits/                 # train/val/test/external + split_metadata.json
  matlab/
    data/                   # Phase 1: dataset management (12 functions)
    quality/                # Phase 2: quality assessment + enhancement (17 files)
    preprocessing/          # Phase 2+: enhancement consolidated into quality/
    segmentation/           # Phase 3+: retinal structure analysis
    lesions/                # Phase 3+: lesion detection
    grading/                # Phase 4+: DR severity classification
    explainability/         # Phase 5+: Grad-CAM
    reporting/              # Phase 7+: report generation
    evaluation/             # Phase 4+: model evaluation
  models/                   # Trained models (not committed)
  results/
    quality/                # Phase 2 outputs (quality_results.csv, examples, etc.)
    phase3/                 # Phase 3 outputs (structure_results.csv, phase3_metrics.json)
    audit_results.json      # Phase 1 audit
    phase1_validation.json  # Phase 1 validation
  docs/                     # Documentation
```

---

## Documentation

| Document | Description |
|----------|-------------|
| `docs/PHASE1_IMPLEMENTATION_REPORT.md` | Phase 1 full implementation report |
| `docs/PHASE1_VALIDATION_REPORT.md` | Phase 1 validation evidence |
| `docs/PHASE1_5_REAL_DATASET_VERIFICATION.md` | Real dataset acquisition report |
| `docs/PHASE2_QUALITY_ASSESSMENT.md` | Phase 2 quality pipeline documentation |
| `docs/PHASE2_QUALITY_VALIDATION.md` | Phase 2 test results |
| `docs/PHASE3_IMPLEMENTATION_REPORT.md` | Phase 3 structure + lesion pipeline documentation |
| `docs/PHASE3_VALIDATION_REPORT.md` | Phase 3 test results and real data metrics |
| `docs/DATASET_PROVENANCE.md` | Dataset origin and licensing |
| `docs/DATA_LEAKAGE_POLICY.md` | Leakage prevention policy |
| `docs/MESSIDOR2_EXTERNAL_VALIDATION.md` | Messidor-2 isolation policy |
| `docs/MANIFEST_SCHEMA.md` | Manifest column definitions |
| `docs/DATASET_DOWNLOAD_GUIDE.md` | How to download datasets |
| `docs/REFERABLE_DR_DEFINITION.md` | DR grading definitions |

---

## Research Prototype Disclaimer

This is a research prototype and educational system. It is NOT:

- A clinical diagnostic device
- Cleared by any regulatory authority
- Validated for clinical use
- A replacement for expert ophthalmologists

All quality thresholds are THEORETICAL / INITIAL and NOT clinically validated.
All DR classification thresholds (when implemented) will require clinical validation before any clinical use.

---

## Git Safety

- Raw retinal datasets are NOT committed (`data/raw/` excluded by `.gitignore`)
- Patient images are NOT committed
- Kaggle credentials, API tokens, passwords are NOT committed
- Generated artifacts (results/, data/processed/) are regenerable
