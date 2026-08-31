# matlab/structures/ — Phase 3: Retinal Structure Analysis

**Status: IMPLEMENTED**

Retinal FOV, optic disc, fovea localization, and vessel segmentation.
See `docs/PHASE3_IMPLEMENTATION_REPORT.md`.

## Modules

| File | Purpose |
|------|---------|
| `phase3Config.m` | Central thresholds (PROVISIONAL), paths, parameters |
| `detectRetinalFOV.m` | Retinal field segmentation (Otsu + morphology) |
| `detectOpticDisc.m` | Optic disc localization (brightness + geometry) |
| `detectFovea.m` | Fovea localization (anatomical + dark pit search) |
| `segmentVessels.m` | Vessel segmentation (matched filter + Hessian) |
| `analyzeImage.m` | Per-image orchestrator (structure + lesion pipeline) |
| `runPhase3Analysis.m` | Batch pipeline for all manifest images |
| `testPhase3Pipeline.m` | 12 automated synthetic tests |

## Quick Start

```matlab
addpath(genpath('matlab'));
cfg = phase3Config();
stats = runPhase3Analysis('maxImages', 100, 'verbose', true);
```

## Output Contract

`structure_results.csv` provides Phase 4-ready features.
See `docs/PHASE3_IMPLEMENTATION_REPORT.md` for full schema.

## Threshold Status

All thresholds are PROVISIONAL / THEORETICAL. Not clinically validated.
