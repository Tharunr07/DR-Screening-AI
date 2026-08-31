# DR Screening — Phase 1: Dataset Foundation

> MATLAB-based automated diabetic retinopathy screening research prototype. **Phase 1 only.**

## What Phase 1 Does

- Configurable project structure under `DR_Screening/`
- Robust image discovery & safe loading (`loadImageSafe`, `findImageFiles`)
- Unified, provenance-preserving manifest (`buildManifest` → `data/processed/manifest.csv`)
- Machine + human audit (`auditDataset` / `runAudit` → `results/audit_results.json` + `docs/PHASE1_AUDIT_REPORT.md`)
- IDRiD lesion annotation registry & DRIVE vessel-mask registry
- Reproducible, leakage-aware splits (`generateSplits` → `data/splits/` + `split_metadata.json`)
- External-validation isolation for Messidor-2
- End-to-end validation (`validatePhase1`)

## What Phase 1 Does NOT Do (Scope Boundary)

See top-level `docs/DATA_LEAKAGE_POLICY.md` and spec section 16 — no CLAHE, no denoising, no quality classifier, no OD/fovea detectors, no vessel/lesion models, no CNN, no Grad-CAM, no Simulink, no clinical sensitivity/specificity claims.

## Quick Start (MATLAB)

```matlab
% From DR_Screening/ as working directory
addpath(genpath('matlab'));

cfg = datasetConfig();              % paths configurable — see matlab/data/datasetConfig.m

% 1) Build manifest (scans data/raw/... ; handles missing datasets gracefully)
generateManifest();                 % -> data/processed/manifest.csv/.mat

% 2) Audit (reports counts, formats, missing/unreadable, annotation maps)
runAudit('checkImageRead', true, 'computeHash', false);

% 3) Annotation registries
registerIDRiDAnnotations();
registerDRIVEMasks();

% 4) Splits (patient-grouped, deterministic, Messidor-2 isolated)
generateSplits();

% 5) Validate
validatePhase1();
```

If datasets are not yet downloaded, the pipeline still runs and reports `DATASET NOT PRESENT — DOWNLOAD REQUIRED` per `docs/DATASET_DOWNLOAD_GUIDE.md`.

## Project Structure

```
DR_Screening/
  data/
    raw/  {APTOS2019, IDRiD, DRIVE, Messidor2}  # .gitignored — manual download
    processed/  manifest.csv/.mat
    splits/     train.csv, val.csv, test.csv, external.csv + split_metadata.json
  matlab/
    data/            datasetConfig, findImageFiles, loadImageSafe, buildManifest, auditDataset, generateSplits, registries, validatePhase1
    quality/         (Phase 2 placeholder)
    preprocessing/   (Phase 2+ placeholder)
    segmentation/    (Phase 3 placeholder)
    lesions/         (Phase 3 placeholder)
    grading/         (Phase 3 placeholder)
    explainability/  (Phase 4 placeholder)
    reporting/       (Phase 4 placeholder)
    evaluation/      (Phase 4 placeholder)
  models/            (future)
  results/           audit_results.json, *_registry.csv, phase1_validation.json
  docs/              provenance, leakage policy, Messidor-2 doc, audit report, etc.
```

## Key Documents

- `docs/DATASET_PROVENANCE.md` — source, role, layout per dataset
- `docs/MANIFEST_SCHEMA.md` — column spec for `manifest.csv`
- `docs/DATA_LEAKAGE_POLICY.md` — patient grouping, external isolation, seed
- `docs/MESSIDOR2_EXTERNAL_VALIDATION.md` — honest label accounting for Messidor-2
- `docs/REFERABLE_DR_DEFINITION.md` — `0+1 → non-referable, 2+3+4 → referable` (threshold 2)
- `docs/DATASET_DOWNLOAD_GUIDE.md` — manual download steps + verification
- `docs/PHASE1_AUDIT_REPORT.md` — generated human-readable audit (after `runAudit`)
- `docs/PHASE1_VALIDATION_REPORT.md` — validation pass/fail (after `validatePhase1`)

## Dataset Roles (Provenance Preserved)

| Dataset | Intended Role |
|---------|---------------|
| APTOS 2019 | DR grading development |
| IDRiD | DR grading + lesion analysis |
| DRIVE | Vessel segmentation |
| Messidor-2 | External validation (isolated) |

## Manifest

Unified table with `UNKNOWN` / `NaN` where metadata genuinely unavailable. See `docs/MANIFEST_SCHEMA.md`.

## Splits & Leakage

- Seed `42`, ratios `70/15/15`, stratified by `dr_grade`, grouped by `patient_id` where available.
- Messidor-2 rows are always `split = external`.
- `validatePhase1` verifies: parse, manifest generation, unreadable handling, counts consistent, annotation mapping, split reproducibility, no patient leakage, raw not modified.

## Implementation Status (Phase 1)

- `IMPLEMENTED` — loader, manifest, audit, splits, registries
- `NOT PRESENT` until datasets are downloaded — infrastructure reports this honestly rather than fabricating counts
- No clinical claims

## Next Step (Phase 2)

After Phase 1 is `PASS` on `validatePhase1`:

1. Download datasets per `docs/DATASET_DOWNLOAD_GUIDE.md`
2. Re-run `generateManifest → runAudit → generateSplits → validatePhase1` to get validated counts
3. Phase 2: image-quality algorithms (separate spec — do not start prematurely)
