# Phase 4 — DR Severity Classification

## Module Overview

This module implements diabetic retinopathy (DR) severity classification using features from Phase 2 (quality) and Phase 3 (structure + lesion).

## Classification Outputs

1. **Five-class DR grade** (0-4) with probability distribution
2. **Binary referable DR** (Level 2+)
3. **Confidence scores** for each prediction

## How to Run

```matlab
addpath(genpath('matlab'));

% Run synthetic tests (12/12 should pass)
res = testClassificationPipeline('verbose', true);

% Run full pipeline
stats = runPhase4Classification('verbose', true);
```

## Prerequisites

- Phase 2: `results/quality/quality_results.csv`
- Phase 3: `results/phase3/structure_results.csv`
- Splits: `data/splits/train.csv`, `val.csv`, `test.csv`
- Manifest: `data/processed/manifest.csv`

## Features (25 total)

| # | Feature | Source |
|---|---------|--------|
| 1 | quality_score | Phase 2 |
| 2 | retinal_area_fraction | Phase 3 |
| 3 | fov_radius | Phase 3 |
| 4 | od_detected | Phase 3 |
| 5 | od_radius | Phase 3 |
| 6 | od_confidence | Phase 3 |
| 7 | fovea_detected | Phase 3 |
| 8 | fovea_confidence | Phase 3 |
| 9 | vessel_area_fraction | Phase 3 |
| 10 | vessel_density | Phase 3 |
| 11 | ma_count | Phase 3 |
| 12 | ma_area | Phase 3 |
| 13 | ma_confidence | Phase 3 |
| 14 | he_count | Phase 3 |
| 15 | he_area | Phase 3 |
| 16 | he_confidence | Phase 3 |
| 17 | ex_count | Phase 3 |
| 18 | ex_area | Phase 3 |
| 19 | ex_area_fraction | Phase 3 |
| 20 | ex_confidence | Phase 3 |
| 21 | nv_present | Phase 3 |
| 22 | nv_score | Phase 3 |
| 23 | nv_confidence | Phase 3 |
| 24 | total_lesions | Combined |
| 25 | total_lesion_area | Combined |

## Research Prototype Disclaimer

This is a research prototype. NOT a clinical diagnostic device.
All thresholds are PROVISIONAL / THEORETICAL. NOT clinically validated.
