# matlab/ — Phase 1 Implementation

## matlab/data/ (IMPLEMENTED — Phase 1)

| File | Role |
|------|------|
| `datasetConfig.m` | Central paths, formats, seed, referable threshold |
| `findImageFiles.m` | Recursive image discovery |
| `loadImageSafe.m` | Safe `imread` + `imfinfo` without crashing |
| `computeFileHash.m` | Duplicate hash (Java MD5 + fallback) |
| `buildManifest.m` | Unified manifest across 4 datasets |
| `generateManifest.m` | Script wrapper → `data/processed/manifest.csv/.mat` |
| `auditDataset.m` | Audit engine (counts, formats, missing, etc.) |
| `runAudit.m` | Runner → `results/audit_results.json` + `docs/PHASE1_AUDIT_REPORT.md` |
| `generateSplits.m` | Leakage-aware deterministic splits → `data/splits/` |
| `registerIDRiDAnnotations.m` | IDRiD lesion registry → `results/idrid_*.csv/.json` |
| `registerDRIVEMasks.m` | DRIVE vessel registry → `results/drive_*.csv/.json` |
| `validatePhase1.m` | End-to-end validation → `results/phase1_validation.json` |

## Placeholders (NOT IMPLEMENTED — Later Phases)

- `matlab/quality/` — image-quality classifier (Phase 2)
- `matlab/preprocessing/` — CLAHE, illumination, denoising (Phase 2+)
- `matlab/segmentation/` — vessel segmentation model (Phase 3)
- `matlab/lesions/` — MA/HE/EX detectors (Phase 3)
- `matlab/grading/` — DR classifier (Phase 3)
- `matlab/explainability/` — Grad-CAM (Phase 4)
- `matlab/reporting/` — clinical reports (Phase 4)
- `matlab/evaluation/` — calibration, metrics (Phase 4)

Do not implement those in Phase 1. Each folder contains a `README.md` marking scope.

## Path Setup

```matlab
addpath(genpath(fullfile(pwd,'matlab')));
cfg = datasetConfig();
```

All raw paths are configurable via `cfg` — no hard-coded absolutes.
