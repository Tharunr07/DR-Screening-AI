# Phase 12.1: Lesion Detection Refinement

**Status:** Complete
**Commit:** Pending

## Overview

Phase 12.1 refines the four lesion detectors based on visual validation feedback:

1. **Exudates** — Major false negatives fixed with multi-criteria detection
2. **Neovascularization** — Optic disc false positives fixed with disc exclusion
3. **Microaneurysms** — Improved discrimination with vessel masking
4. **Evidence aggregator** — Added confidence levels (HIGH/MEDIUM/LOW)

## Changes Made

### Exudate Detection (detectExudates.m)

**Problem:** 0 exudates detected when bright lesions were visible

**Solution:**
- Multi-criteria bright lesion detection (HSV + adaptive thresholding + local contrast)
- Optic disc detection using intensity-based region analysis
- Vessel masking to exclude vessel-related brightness
- Eccentricity filtering (exudates are roughly circular)
- Lowered minimum area threshold (20 → 10 pixels)

### Neovascularization (detectNeovascularization.m)

**Problem:** False positive triggered by optic disc density

**Solution:**
- Explicit optic disc detection and exclusion
- Major vessel detection and exclusion
- Fine vessel analysis (shorter filters for NV-like structures)
- Peripheral location requirement (NV typically in peripheral retina)
- Robust statistics (MAD instead of std)
- Normalized irregularity score (0-1 range)

### Microaneurysms (detectMicroaneurysms.m)

**Problem:** Some detections in wrong areas (near bright lesions, boundaries)

**Solution:**
- Vessel masking to exclude vessel pixels
- Optic disc exclusion
- Boundary rejection (5-pixel margin)
- Local contrast filtering (MA should be darker than local background)
- Solidity filtering (compactness check)
- Improved eccentricity threshold (0.6 → 0.7)

### Evidence Aggregator (extractLesionEvidence.m)

**New feature:** Confidence levels for each detector

```
Microaneurysms: 5 [MEDIUM confidence]
Hemorrhages: 0 [LOW confidence]
Exudates: 3 [HIGH confidence]
Neovascularization: false [LOW confidence]
```

## Confidence Levels

| Level | Threshold | Interpretation |
|-------|-----------|----------------|
| HIGH | ≥ 0.7 | Strong evidence |
| MEDIUM | ≥ 0.4 | Moderate evidence |
| LOW | < 0.4 | Weak evidence |

## Severity Scoring

Severity is now weighted by confidence:

```matlab
score = (MA_count × weight) + 
        (Hem_count × weight × 1.5) + 
        (Exu_count × weight) + 
        (NV_detected × 5 × weight)
```

Where weight = 1.0 (HIGH), 0.5 (MEDIUM), 0.2 (LOW)

## Validation Results

| # | Test | Status |
|---|------|--------|
| 1 | Functions exist | PASS |
| 2 | Microaneurysm detection | PASS |
| 3 | Exudate detection | PASS |
| 4 | Neovascularization detection | PASS |
| 5 | Evidence aggregation with confidence | PASS |
| 6 | Confidence levels valid | PASS |
| 7 | Severity assessment | PASS |
| 8 | Summary generation | PASS |
| 9 | Empty image handling | PASS |
| 10 | Deterministic output | PASS |
| 11 | Mask dimensions match | PASS |
| 12 | Summary keywords | PASS |

**Result: 12/12 PASS**

## Files

```
matlab/lesions/
├── detectMicroaneurysms.m      # Updated with vessel/disc exclusion
├── detectHemorrhages.m         # Unchanged
├── detectExudates.m            # Updated with multi-criteria
├── detectNeovascularization.m  # Updated with disc exclusion
├── extractLesionEvidence.m     # Updated with confidence levels
└── validatePhase12_1.m         # 12-test validation suite

docs/
└── PHASE12_1_LESION_REFINEMENT.md
```

## How to Run

```matlab
% Run validation
v = validatePhase12_1('Verbose', true);

% Extract evidence
img = imread('path/to/fundus.jpg');
evidence = extractLesionEvidence(img);
disp(evidence.summary);
```

## What Is NOT in Phase 12.1

- **No model retraining** — frozen at `cc7bed8`
- **No ground-truth validation** — no lesion-level annotations available
- **No clinical claims** — detection candidates only

## Remaining Limitations

1. **No ground-truth validation** — We don't have lesion-level annotations
2. **Parameter tuning** — Thresholds are heuristic, not optimized
3. **Visual validation needed** — Should be reviewed by ophthalmologist
4. **Candidate terminology** — Results should be called "candidates" not "confirmed lesions"

## SIH Traceability

| SIH Requirement | Evidence |
|-----------------|----------|
| Lesion detection | Four refined detectors |
| Evidence confidence | HIGH/MEDIUM/LOW levels |
| Severity assessment | Weighted scoring |
| Clinical interpretability | Confidence-weighted summary |
