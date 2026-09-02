# Phase 14: Final SIH Validation

**Status:** Complete
**Date:** 2026-09-02
**All validations:** PASS

---

## 1. Problem Statement

Rural India has a major diabetic retinopathy (DR) screening capacity gap. Ophthalmologists are concentrated in urban centers, leaving rural populations without access to timely screening. This project implements an AI-assisted DR screening system designed for deployment in resource-constrained healthcare settings.

## 2. System Architecture

```
             DR-SCREENING-AI
                    │
        ┌───────────┴───────────┐
        │                       │
   IMAGE PIPELINE          TELEMEDICINE
        │                       │
 Quality Assessment       Simulink Model
        │                       │
 Retinal Analysis         100K+ Patients
        │                       │
 Lesion Evidence          Capacity Planning
        │
 Frozen TL ResNet-18
        │
 ┌──────┴──────┐
 │             │
Grade 0–4   Referable
 │
 ├── Grad-CAM
 ├── Lesions
 ├── Confidence
 └── Report
        │
        ▼
   HUMAN REVIEW
```

## 3. Dataset

| Property | Value |
|----------|-------|
| Total images | 7,872 |
| Labeled images | 4,156 |
| Datasets | APTOS 2019 (3,662), IDRiD (494) |
| DR grades | 0 (No DR), 1 (Mild), 2 (Moderate), 3 (Severe), 4 (PDR) |
| Quality gating | 60 images removed (blur/brightness) |
| Final labeled | 4,096 |

## 4. Data Splitting

| Split | Count | Method |
|-------|-------|--------|
| Train | 2,792 | 70% patient-level |
| Validation | 611 | 15% patient-level |
| Test | 612 | 15% patient-level (FROZEN) |

- **Patient-level splitting** prevents leakage
- **Stratified** to maintain class distribution
- **Test set frozen** at commit `cc7bed8`

## 5. Image Quality Assessment

| Metric | Threshold | Purpose |
|--------|-----------|---------|
| Brightness | 40–220 | Reject over/under-exposed |
| Contrast (std) | > 20 | Reject low-contrast |
| Laplacian variance | > 100 | Reject blurry |

**Quality gating removed 60 images** from training set.

## 6. Retinal Analysis

### Retinal Structure Detection

| Structure | Method | Status |
|-----------|--------|--------|
| Optic disc | Intensity + circular Hough | ✅ |
| Blood vessels | Frangi filtering + threshold | ✅ |
| Fovea | Geometric (relative to optic disc) | ✅ |
| Microaneurysms | Morphological top-hat | ✅ |
| Hemorrhages | HSV color segmentation | ✅ |
| Exudates | Bright region detection | ✅ |
| Neovascularization | Vessel density analysis | ✅ |

## 7. DR Classification

### Baseline Comparison

| Model | Sensitivity | Specificity | AUC |
|-------|-------------|-------------|-----|
| SVM (Phase 4) | 75.9% | 86.2% | 0.810 |
| Native ResNet-18 (Phase 7) | 95.3% | 74.7% | 0.878 |
| Transfer Learning (Phase 8) | **97.7%** | **85.4%** | **0.975** |

### Phase 8 Transfer Learning (FROZEN)

| Metric | Value |
|--------|-------|
| Sensitivity | 97.7% (221/226) |
| Specificity | 85.4% (332/386) |
| AUC | 0.975 |
| Referable threshold | 0.1951 |
| Commit | `cc7bed8` |

### Per-Dataset Performance

| Dataset | Sensitivity | Specificity |
|---------|-------------|-------------|
| APTOS 2019 | 98.6% | 87.1% |
| IDRiD | 91.9% | 59.1% |

**Domain shift noted:** IDRiD specificity substantially lower than APTOS.

## 8. Transfer Learning

| Component | Value |
|-----------|-------|
| Architecture | ResNet-18 |
| Pretrained | ImageNet |
| Fine-tuning | FC layer only |
| Optimizer | Adam |
| Learning rate | 1e-4 |
| Epochs | 10 |
| Regularization | Dropout 0.5, L2 1e-4 |
| Class balancing | Inverse frequency |

**Why transfer learning:** Overparameterization in native DL (Phase 7) caused poor generalization. Transfer learning leverages ImageNet features, improving generalization.

## 9. Explainability

### Grad-CAM (Phase 11 — Formal)

| Property | Value |
|----------|-------|
| Method | Class activation mapping via FC weight projection |
| Feature layer | res5b_branch2b |
| Normalization | Min-max to [0,1] |
| Validation | 9/9 tests PASS |

### Evidence Package

| Component | Commit | Validation |
|-----------|--------|------------|
| Grad-CAM | `414ffda` | 9/9 PASS |
| Lesion evidence | `7016f44` | 10/10 PASS |
| Calibration | `3858cdc` | 10/10 PASS |

## 10. Lesion Evidence

### Detectors

| Detector | Method | Parameters |
|----------|--------|------------|
| Microaneurysms | Morphological top-hat | MinArea=10, MaxArea=40 |
| Hemorrhages | HSV color segmentation | MinArea=50, MaxArea=2000 |
| Exudates | Bright region detection | MinArea=20, MaxArea=3000 |
| Neovascularization | Vessel density analysis | Density threshold=2σ |

### Evidence Aggregation

```matlab
evidence = extractLesionEvidence(img);
evidence.severity  % 'none', 'mild', 'moderate', 'severe'
evidence.summary   % Text summary
```

**Limitation:** Detection candidates only, not independently clinically validated.

## 11. Calibration

| Metric | Value | Interpretation |
|--------|-------|----------------|
| ECE | 0.344 | **Moderate miscalibration** |
| Brier | 0.328 | Room for improvement |
| Confidence mean | 0.65 | — |
| Confidence std | 0.28 | — |

**Honest assessment:** Calibration is imperfect. Confidence estimates require further calibration before clinical deployment.

## 12. Inference Performance

| Metric | Value |
|--------|-------|
| Model loading | 1.2 sec |
| Image preprocessing | 0.025 sec |
| AI inference | 0.014 sec |
| Grad-CAM | 0.718 sec |
| Lesion evidence | 0.095 sec |
| **Total pipeline** | **0.87 sec** |
| **Throughput** | **4,157 images/hour** |

## 13. Human-in-the-Loop Workflow

```
1. Image Loading         (0.011 sec)
2. Quality Assessment    (0.003 sec)
3. AI Classification     (0.014 sec)
4. Grad-CAM Heatmap      (0.718 sec)
5. Lesion Evidence       (0.095 sec)
6. Clinical Report       (0.001 sec)
─────────────────────────────────
Total:                   0.87 sec
```

**Claim:** "The system provides a structured human-in-the-loop review workflow designed for rapid ophthalmologist assessment."

**Not claimed:** "Clinically validated explainability" (requires ophthalmologist ratings).

## 14. Simulink Telemedicine Simulation

### Resource Scenarios

| Config | Stations | AI | Doctor | Patients/Year |
|--------|----------|-----|--------|---------------|
| Minimal | 1 | 1 | 1 | 100,000+ |
| Standard | 3 | 2 | 2 | 100,000+ |
| High | 5 | 3 | 3 | 100,000+ |

### Key Findings

| Finding | Value |
|---------|-------|
| AI utilization | 0.1–0.2% (never bottleneck) |
| Doctor utilization | 68.3% (Minimal config) |
| Bandwidth impact | 1 Mbps: +90.6 sec; 100 Mbps: +0.9 sec |
| Target capacity | 100,000 patients/year achievable |

**Doctor review is the principal constraint**, not AI throughput.

## 15. Final Validation Results

### All Validation Suites

| Suite | Tests | Result | Commit |
|-------|-------|--------|--------|
| Phase 9: Inference | 9/9 | PASS | `b73604e` |
| Phase 11: Grad-CAM | 9/9 | PASS | `414ffda` |
| Phase 12: Lesion Evidence | 10/10 | PASS | `7016f44` |
| Phase 13: Calibration | 10/10 | PASS | `3858cdc` |
| **Total** | **38/38** | **ALL PASS** | — |

### API Failure Handling

| Test Case | Result |
|-----------|--------|
| Valid image | ✅ Returns prediction + evidence |
| Missing image | ✅ Graceful failure, success=0 |
| Corrupt image | ✅ Graceful failure, success=0 |

## 16. Limitations

### Scientific Limitations

1. **External clinical validation not performed** — No ophthalmologist ratings of AI outputs
2. **Domain shift exists** — IDRiD specificity (59.1%) substantially lower than APTOS (87.1%)
3. **Calibration is imperfect** — ECE = 0.344 indicates moderate miscalibration
4. **Lesion detectors are evidence modules** — Not independently clinically validated diagnostic tools
5. **Regulatory approval not obtained** — Research prototype only

### Technical Limitations

1. **MATLAB dependency** — Requires Deep Learning Toolbox
2. **Single GPU** — No multi-GPU distribution
3. **Fixed input size** — 224×224 only
4. **No real-time streaming** — Batch processing only

### Claimed vs Not Claimed

| Claimed | Not Claimed |
|---------|-------------|
| Sensitivity 97.7% on 612-image test set | Clinically validated system |
| Specificity 85.4% on 612-image test set | Production-ready deployment |
| Structured review workflow | Regulatory approval |
| 100K+ patients/year capacity | External generalizability |
| Transfer learning addresses overparameterization | Perfect calibration |

## 17. Reproducibility

### Frozen Commits

| Phase | Commit | Description |
|-------|--------|-------------|
| 7 Audit | `d7a648d` | Root cause analysis |
| 8 Model | `cc7bed8` | Transfer learning (FROZEN) |
| 9 System | `b73604e` | GUI + API |
| 10 Simulink | `5d47874` | Telemedicine |
| 11 Grad-CAM | `414ffda` | Formal explainability |
| 12 Lesions | `7016f44` | Lesion evidence |
| 13 Calibration | `3858cdc` | Calibration + usability |

### Environment

| Component | Version |
|-----------|---------|
| MATLAB | R2026a |
| Deep Learning Toolbox | v26.1 |
| Python | 3.13.5 |
| PyTorch | 2.13.0 |
| torchvision | 0.28.0 |
| GPU | NVIDIA CUDA |

### Reproduction Commands

```matlab
cd('C:\dev\SIH\DR_Screening');
addpath(genpath('matlab'));

% Run all validations
v9 = validateInference('Verbose', true);       % 9/9
v11 = validateGradCAM('Verbose', true);        % 9/9
v12 = validateLesionEvidence('Verbose', true); % 10/10
v13 = validatePhase13('Verbose', true);        % 10/10

% Launch GUI
drScreeningGUI();

% Run API
result = runDRScreening('path/to/fundus.jpg');

% Telemedicine simulation
runTelemedicineSimulation();
```

## 18. SIH Requirement → Implementation Mapping

| SIH Requirement | Implementation | Evidence |
|-----------------|----------------|----------|
| Image quality assessment | Quality gating (brightness, contrast, blur) | Phase 1–3, validation |
| DR grading 0–4 | Transfer-learning ResNet-18 classifier | Phase 8 (`cc7bed8`) |
| >90% sensitivity | 97.7% (221/226) | Phase 8 test set |
| >85% specificity | 85.4% (332/386) | Phase 8 test set |
| Explainability | Formal Grad-CAM (FC weight projection) | Phase 11 (`414ffda`), 9/9 |
| Lesion evidence | Four lesion modules (MA, Hem, Exu, NV) | Phase 12 (`7016f44`), 10/10 |
| Confidence calibration | ECE, Brier, reliability curve | Phase 13 (`3858cdc`), 10/10 |
| Human-in-the-loop | Review workflow (0.87 sec pipeline) | Phase 13 |
| 100K+ patients/year | Simulink discrete-event simulation | Phase 10 (`5d47874`) |
| Resource allocation | Station/doctor/bandwidth scenarios | Phase 10 |
| End-to-end system | MATLAB API + interactive GUI | Phase 9 (`b73604e`) |
| Referable detection | Threshold optimization (0.1951) | Phase 8 |
| Retinal structures | Optic disc, vessels, fovea | Phase 3 |
| Multi-dataset | APTOS + IDRiD | Phase 2 |
| Error analysis | FN/FP analysis, domain shift | Consolidation (`7217aae`) |

## 19. Final Conclusion

This project implements a complete AI-assisted DR screening system covering:

1. **Data pipeline** — Quality gating, retinal analysis, multi-dataset support
2. **Classification** — Transfer-learning ResNet-18 achieving 97.7% sensitivity, 85.4% specificity
3. **Explainability** — Formal Grad-CAM with class-specific activation maps
4. **Lesion evidence** — Four-module system for microaneurysms, hemorrhages, exudates, neovascularization
5. **Calibration** — Confidence analysis with ECE and Brier score
6. **Deployment** — Simulink telemedicine model showing 100K+ patients/year capacity
7. **Human interface** — Interactive GUI with structured review workflow

### Key Achievements

- **Exceeded clinical targets:** Sensitivity >90% and specificity >85%
- **Comprehensive validation:** 38/38 tests pass across all phases
- **Honest limitations:** Domain shift, imperfect calibration, no clinical validation
- **Reproducible:** Frozen commits, documented environment, validation scripts

### Path to Clinical Deployment

1. **External validation** with ophthalmologist ratings
2. **Calibration refinement** to reduce ECE from 0.344
3. **Regulatory approval** (CDSCO India, FDA USA)
4. **Prospective clinical trial** in rural healthcare settings

---

**This is a research prototype, not a clinical tool. All results are on held-out test sets. External clinical validation has not been performed.**
