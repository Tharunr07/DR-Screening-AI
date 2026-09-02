# Phase 12: Lesion-Level Evidence

**Status:** Complete
**Commit:** Pending

## Overview

Phase 12 adds an independent lesion evidence layer that makes the screening result more clinically interpretable, without modifying the frozen Phase 8 classifier.

## Architecture

```
Fundus Image
    │
    ├── Microaneurysm Detection
    │       (morphological top-hat + threshold)
    │
    ├── Hemorrhage Detection
    │       (HSV color segmentation)
    │
    ├── Exudate Detection
    │       (bright region segmentation)
    │
    ├── Neovascularization Detection
    │       (vessel density analysis)
    │
    └── Frozen Phase 8 Classifier
             │
             ▼
       DR Grade + Referable
             │
             ▼
       Evidence Fusion
             │
             ▼
       Clinical Explanation
```

## Detectors

### Microaneurysms

- **Method:** Morphological top-hat on red channel
- **Characteristics:** Small, dark-red, round lesions
- **Parameters:** MinRadius=1, MaxRadius=3, MinArea=10, MaxArea=40
- **Filters:** Eccentricity < 0.6 (circular)
- **Output:** count, mask, locations, areas, confidence

### Hemorrhages

- **Method:** HSV color segmentation
- **Characteristics:** Dark/red patches, larger than microaneurysms
- **Criteria:** Red hue (0-0.1 or 0.9-1.0), low value (<0.4), moderate saturation (>0.2)
- **Parameters:** MinArea=50, MaxArea=2000
- **Output:** count, mask, locations, areas, totalArea, confidence

### Exudates

- **Method:** Bright region segmentation with optic disc removal
- **Characteristics:** Bright, yellow-white lesions
- **Criteria:** High value (>0.7), low saturation (<0.4)
- **Parameters:** MinArea=20, MaxArea=3000
- **Output:** count, mask, locations, areas, totalArea, confidence

### Neovascularization

- **Method:** Vessel density and irregularity analysis
- **Characteristics:** Abnormal new vessel growth
- **Analysis:** Block-wise vessel density, irregularity scoring
- **Criteria:** High density (>2 std above mean) AND irregularity > 0.3
- **Output:** detected, mask, density, irregularity, confidence

## Evidence Aggregation

`extractLesionEvidence.m` combines all detectors:

```matlab
evidence = extractLesionEvidence(img);

% Output structure:
evidence.microaneurysms.count
evidence.hemorrhages.count
evidence.exudates.count
evidence.neovascularization.detected
evidence.totalLesions
evidence.severity        % none/mild/moderate/severe
evidence.summary         % Text summary
```

## Validation Results

| # | Test | Status |
|---|------|--------|
| 1 | Functions exist | PASS |
| 2 | Microaneurysm detection | PASS |
| 3 | Hemorrhage detection | PASS |
| 4 | Exudate detection | PASS |
| 5 | Neovascularization detection | PASS |
| 6 | Evidence aggregation | PASS |
| 7 | Empty image handling | PASS |
| 8 | Deterministic output | PASS |
| 9 | Mask dimensions | PASS |
| 10 | End-to-end pipeline | PASS |

**Result: 10/10 PASS**

## GUI Integration

The "Lesions" button in `drScreeningGUI.m` now displays lesion evidence:

1. Runs all four detectors
2. Shows individual lesion masks overlaid on fundus
3. Displays summary with severity and counts

## Files

```
matlab/lesions/
├── detectMicroaneurysms.m
├── detectHemorrhages.m
├── detectExudates.m
├── detectNeovascularization.m
├── extractLesionEvidence.m
└── validateLesionEvidence.m

matlab/demo/
└── drScreeningGUI.m       # Updated with lesion evidence button

docs/
└── PHASE12_LESION_EVIDENCE.md
```

## How to Run

```matlab
% Extract lesion evidence
img = imread('path/to/fundus.jpg');
evidence = extractLesionEvidence(img);
disp(evidence.summary);

% Run validation
v = validateLesionEvidence('Verbose', true);

% Launch GUI
drScreeningGUI();
```

## Important Limitations

1. **Not clinically validated** — These are detection candidates, not confirmed lesions
2. **No ground truth comparison** — We don't have lesion-level annotations for validation
3. **Parameter tuning** — Thresholds are heuristic, not optimized on clinical data
4. **Research prototype** — Evidence is for demonstration, not diagnosis

## What Is NOT in Phase 12

- **No model retraining** — frozen at `cc7bed8`
- **No clinical claims** — detection candidates only
- **No external validation** — no lesion-level annotations available

## SIH Traceability

| SIH Requirement | Evidence |
|-----------------|----------|
| Microaneurysms | Detection with count + mask |
| Hemorrhages | Detection with count + mask |
| Exudates | Detection with count + mask |
| Neovascularization | Detection with mask |
| Clinical interpretability | Evidence fusion + summary |
| Retinal structures | Combined with Phase 3 outputs |
