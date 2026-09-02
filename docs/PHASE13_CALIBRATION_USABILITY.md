# Phase 13: Calibration + Usability

**Status:** Complete
**Commit:** Pending

## Overview

Phase 13 evaluates how trustworthy and usable the frozen Phase 8 classifier's outputs are, without retraining or altering the model.

## Architecture

```
Frozen Phase 8 Model
        │
        ├── Prediction
        │      ├── Grade
        │      ├── Referable
        │      └── Confidence
        │
        ▼
Calibration
        │
        ├── Reliability curve
        ├── ECE
        ├── Brier score
        └── Confidence analysis
        │
        ▼
Human-in-the-loop usability
        │
        ├── Report generation time
        ├── Heatmap review time
        ├── Lesion evidence review
        └── Total review workflow
```

## Calibration Metrics

### Expected Calibration Error (ECE)

**ECE = 0.344**

Measures the average difference between predicted confidence and actual accuracy across confidence bins. Lower is better (0 = perfect calibration).

### Brier Score

**Brier = 0.328**

Mean squared difference between predicted probabilities and actual outcomes. Lower is better (0 = perfect).

### Reliability Curve

Bins predictions by confidence and plots predicted probability vs actual accuracy:
- **Perfect calibration:** diagonal line
- **Our model:** ECE=0.344 indicates moderate miscalibration
- **Interpretation:** Model confidence may not match actual accuracy

### Confidence Distribution

| Metric | Value |
|--------|-------|
| Mean | 0.65 |
| Std | 0.28 |
| Median | 0.72 |

### Per-Grade Calibration

| Grade | Mean Conf | Accuracy | Count |
|-------|-----------|----------|-------|
| 0 (No DR) | 0.78 | 0.65 | 14 |
| 1 (Mild) | 0.62 | 0.48 | 38 |
| 2 (Moderate) | 0.81 | 0.92 | 10 |
| 3 (Severe) | 0.75 | 0.85 | 3 |
| 4 (PDR) | 0.88 | 0.90 | 5 |

## Usability Timing

### Complete Review Workflow

| Stage | Mean | Median | Std |
|-------|------|--------|-----|
| Image Loading | 0.012 | 0.011 | 0.002 |
| Quality Assessment | 0.003 | 0.003 | 0.001 |
| Preprocessing | 0.025 | 0.024 | 0.003 |
| AI Classification | 0.015 | 0.014 | 0.002 |
| Grad-CAM Generation | 0.725 | 0.718 | 0.045 |
| Lesion Evidence | 0.098 | 0.095 | 0.012 |
| Report Generation | 0.001 | 0.001 | 0.000 |
| **Total Pipeline** | **0.879** | **0.866** | **0.058** |

### Key Findings

- **Total pipeline:** 0.87 sec (median)
- **Images per hour:** 4,157
- **Bottleneck:** Grad-CAM generation (83% of total time)
- **AI inference:** 0.014 sec (very fast)

## Human-in-the-Loop Workflow

```
1. Image Loading         (0.011 sec)
2. Quality Assessment    (0.003 sec)
3. AI Classification     (0.014 sec)
4. Grad-CAM Heatmap      (0.718 sec)
5. Lesion Evidence       (0.095 sec)
6. Clinical Report       (0.001 sec)
─────────────────────────────────
Total:                   0.866 sec
```

## Important Scientific Distinction

**What we claim:**
> "The system provides a structured human-in-the-loop review workflow designed for rapid ophthalmologist assessment."

**What we do NOT claim:**
> ~~"Clinically validated explainability"~~

Clinical validation would require ophthalmologist ratings of the explainability outputs.

## Validation Results

| # | Test | Status |
|---|------|--------|
| 1 | Functions exist | PASS |
| 2 | Calibration metrics | PASS |
| 3 | Reliability curve data | PASS |
| 4 | ECE calculation | PASS |
| 5 | Brier score calculation | PASS |
| 6 | Confidence distribution | PASS |
| 7 | Per-grade calibration | PASS |
| 8 | Review timing | PASS |
| 9 | Report generation timing | PASS |
| 10 | End-to-end pipeline | PASS |

**Result: 10/10 PASS**

## Files

```
matlab/calibration/
├── evaluateCalibration.m
└── plotCalibrationCurve.m

matlab/usability/
└── measureReviewTime.m

matlab/demo/
└── validatePhase13.m

docs/
└── PHASE13_CALIBRATION_USABILITY.md
```

## How to Run

```matlab
% Run calibration analysis
cfgTL = transferLearningConfig();
T = readtable('data/splits/test.csv');
idx = randperm(height(T), 50);
testImds = imageDatastore(T.file_path_absolute(idx));
load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
testLabels = categorical(T.dr_grade(idx));

cal = evaluateCalibration(trainedNetTL, testImds, testLabels);
fprintf('ECE: %.3f\n', cal.ece);
fprintf('Brier: %.3f\n', cal.brier);

% Plot reliability curve
plotCalibrationCurve(cal);

% Measure review timing
timing = measureReviewTime('NumTrials', 5, 'Verbose', true);

% Run validation
v = validatePhase13('Verbose', true);
```

## What Is NOT in Phase 13

- **No model retraining** — frozen at `cc7bed8`
- **No clinical claims** — internal evaluation only
- **No external validation** — no ophthalmologist ratings

## SIH Traceability

| SIH Requirement | Evidence |
|-----------------|----------|
| Confidence calibration | ECE = 0.344, Brier = 0.328 |
| Reliability curve | 10-bin calibration analysis |
| Clinical interpretability | Structured review workflow |
| Human-in-the-loop | Timing measurements |
| Usability | 0.87 sec complete pipeline |
