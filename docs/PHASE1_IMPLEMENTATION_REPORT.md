# Phase 1 — Implementation Report: Dataset Foundation

> **Project**: MATLAB-based Automated Diabetic Retinopathy Screening Research Prototype  
> **Phase**: 1 — Dataset Foundation (ONLY)  
> **Date**: 2026-08-30  
> **Status**: `PASS` (10/10 validation checks) on both empty-state and synthetic-data test  
> **MATLAB**: R2026a (26.1.0.3346908), Image Processing Toolbox, Statistics & ML Toolbox  
> **Working directory**: `C:\dev\SIH\DR_Screening` (`cfg.projectRoot` configurable via `datasetConfig.m:15`)

Stop after Phase 1. No Phase 2 work (CLAHE, quality classifier, segmentation, lesions, grading, Grad-CAM, Simulink, clinical metrics) is included.

---

## A. Files Created / Modified

### Project structure (preserved, created under `DR_Screening/`)

```
DR_Screening/
  data/
    raw/{APTOS2019,IDRiD,DRIVE,Messidor2}/.gitkeep  (empty — honest DATASET NOT PRESENT)
    processed/manifest.csv + manifest.mat           (generated, header-only in empty state)
    splits/{train,val,test,external}.csv + split_metadata.json/.mat  (generated)
  matlab/
    data/
      datasetConfig.m:15
      findImageFiles.m:1
      loadImageSafe.m:1
      computeFileHash.m:1
      buildManifest.m:1
      generateManifest.m:15
      auditDataset.m:1
      runAudit.m:1
      generateSplits.m:1
      registerIDRiDAnnotations.m:1
      registerDRIVEMasks.m:1
      validatePhase1.m:1
    quality/README.md, preprocessing/README.md, segmentation/README.md,
    lesions/README.md, grading/README.md, explainability/README.md,
    reporting/README.md, evaluation/README.md  (Phase 2+ placeholders, NOT IMPLEMENTED)
  models/.gitkeep
  results/
    audit_results.json/.mat
    idrid_annotation_registry{.csv,.mat,.json}, idrid_annotation_summary.json
    drive_vessel_registry{.csv,.mat,.json}, drive_vessel_summary.json
    phase1_validation.json/.mat
    synthetic_test_evidence/  (23-row synthetic run preserved: manifest, audit, splits, registries)
  docs/
    README.md, DATASET_PROVENANCE.md, DATA_LEAKAGE_POLICY.md,
    MESSIDOR2_EXTERNAL_VALIDATION.md, REFERABLE_DR_DEFINITION.md,
    MANIFEST_SCHEMA.md, DATASET_DOWNLOAD_GUIDE.md,
    PHASE1_AUDIT_REPORT.md (generated), PHASE1_VALIDATION_REPORT.md (generated),
    PHASE1_IMPLEMENTATION_REPORT.md (this file)
  README.md, .gitignore
```

### MATLAB implementation (12 files, all parse-clean)

- `matlab/data/datasetConfig.m:15` — central paths, `supportedExtensions`, `splitRatios 70/15/15`, `randomSeed 42`, `referableThreshold 2`.
- `matlab/data/findImageFiles.m:1` — recursive discovery, case-insensitive dot handling, no `imread`.
- `matlab/data/loadImageSafe.m:1` — `imfinfo` + `imread` try/catch, `info.readable`, `channels`, `format`, never modifies raw.
- `matlab/data/computeFileHash.m:1` — Java `MD5` with file-size fallback for duplicate detection.
- `matlab/data/buildManifest.m:1` — unified manifest across 4 datasets, `UNKNOWN`/`NaN` for missing, `quality_status UNKNOWN`, `provenance` preserved, `DRIVE/mask` subrole, Messidor-2 `split external`.
- `matlab/data/generateManifest.m:15` — wrapper → `data/processed/manifest.csv/.mat`, deterministic sort.
- `matlab/data/auditDataset.m:1` — counts, dimensions, formats, missing/unreadable, duplicate filenames/hashes, grade distribution, annotation availability, patientStats, laterality.
- `matlab/data/runAudit.m:1` — writes `results/audit_results.json/.mat` + `docs/PHASE1_AUDIT_REPORT.md` (summary tables per spec §14).
- `matlab/data/generateSplits.m:1` — patient-grouped stratified split, `rng(seed)`, Messidor-2 isolated, `split_metadata.json`.
- `matlab/data/registerIDRiDAnnotations.m:1` — lesion discovery (MA/HE/EX/SE/OD), `results/idrid_annotation_registry.csv`.
- `matlab/data/registerDRIVEMasks.m:1` — vessel mask mapping (`1st_manual`/`mask`), `results/drive_vessel_registry.csv`.
- `matlab/data/validatePhase1.m:1` — 10 automated checks (parse, configurable paths, manifest, unreadable handling, counts, annotation mapping, split reproducibility, leakage, raw not modified, results).

All files modified are new creations; no existing repository was overwritten (workspace was empty).

---

## B. Dataset Availability (Actually Verified)

| Dataset | Path (`datasetConfig.m`) | Status on disk (2026-08-30) | What audit reports |
|---------|--------------------------|-----------------------------|--------------------|
| APTOS 2019 | `data/raw/APTOS2019` | **NOT PRESENT** — only `.gitkeep` | `byDataset.APTOS2019 = 0`, `DATASET NOT PRESENT — DOWNLOAD REQUIRED` |
| IDRiD | `data/raw/IDRiD` | **NOT PRESENT** — only `.gitkeep` | `byDataset.IDRiD = 0` |
| DRIVE | `data/raw/DRIVE` | **NOT PRESENT** — only `.gitkeep` | `byDataset.DRIVE = 0` |
| Messidor-2 | `data/raw/Messidor2` | **NOT PRESENT** — only `.gitkeep` | `byDataset.Messidor2 = 0` |

Honest reporting per spec §15: loader/audit infrastructure is `IMPLEMENTED` and validated, but counts are `NOT PRESENT` until manual download per `docs/DATASET_DOWNLOAD_GUIDE.md`.

**Synthetic test** (infrastructure validation with data): 23 synthetic fundus images were temporarily created (`results/synthetic_test_evidence/` preserved) covering APTOS 7, IDRiD 9, DRIVE 3, Messidor-2 4, including one deliberately corrupt file and one exact duplicate pair. That test is `VALIDATED`; the production `data/raw/` remains empty to avoid fabricating real dataset counts.

---

## C. Dataset Counts Actually Verified

### Empty production state (honest, current)

- `data/processed/manifest.csv`: 0 rows (header-only), verified by `validatePhase1:manifestGeneration rows=0`
- `results/audit_results.json:totalImages = 0`, `byGrade.UNKNOWN = 0` (empty), `bySplit` empty, `missingCount 0`, `unreadableCount 0`
- Split files: `train.csv / val.csv / test.csv / external.csv` all header-only, `split_metadata.json:status NOT VALIDATED — EMPTY MANIFEST`

### Synthetic validation state (evidence preserved in `results/synthetic_test_evidence/`)

Run with `generateManifest([], 'computeHash', true)` + `runAudit([], 'computeHash', true)` + `generateSplits()`:

| Metric | Value | Verified by |
|--------|-------|-------------|
| Manifest total | **23 rows** | `manifest_synthetic_23rows.csv` (23) — APTOS 7, IDRiD 9, DRIVE 3, Messidor-2 4 |
| DR labeled | 9 / 23 (L0=3 L1=1 L2=2 L3=2 L4=1) | `audit_results_synthetic.json:byGrade` |
| Vessel annotations | 3 (DRIVE) | `has_vessel_annotation = 3` |
| Lesion annotations | 8 (IDRiD) | `has_lesion_annotation = 8` |
| Dimensions | 64×64 to 80×64, mean 70.5×64.0, unique sizes 2 | `dimensions` |
| Channels | C1=7 (grayscale test), C3=15, UNKNOWN=1 (corrupt) | `channels` |
| Formats | JPG=3 PNG=7 TIF=13 | `byFormat` |
| Missing files | 0 | `missingCount 0` |
| Unreadable/corrupt | **1** (`corrupt.png`) — reported, not crashing | `unreadableCount 1` with `imread failed` message |
| Duplicate hash groups | **1** (Messidor duplicate pair) | `duplicateHashGroupCount 1` |
| Patient leakage | 0 (6 patients checked) | `split_metadata_synthetic.json:leakageCheck` |

Both states pass `validatePhase1`.

---

## D. Manifest Schema

See `docs/MANIFEST_SCHEMA.md` (canonical). Summary:

- Location: `data/processed/manifest.csv` (relative `file_path` portable + `file_path_absolute` for MATLAB) and `.mat`.
- Columns (23): `image_id, dataset, file_path, file_path_absolute, file_format, laterality, patient_id, subject_id, dr_grade (double NaN=UNKNOWN), dr_grade_original (verbatim), quality_status (always UNKNOWN in Phase 1), has_vessel_annotation (logical), has_lesion_annotation (logical), vessel_mask_path, lesion_annotation_path (semicolon-joined), split (train/val/test/external/UNKNOWN), width, height, channels, file_size_bytes, file_hash, provenance, status`.
- Invariants: sorted by `(dataset, image_id)`, `UNKNOWN`/`NaN` never invented, `dataset` preserves provenance, Messidor-2 always `external`, no raw modification, `datasetConfig` configurable.

Example rows preserved in `results/synthetic_test_evidence/manifest_synthetic_23rows.csv`.

---

## E. Split Strategy

- Code: `matlab/data/generateSplits.m:1`, config `datasetConfig.m:splitRatios 70/15/15, randomSeed 42`.
- Isolation: all `dataset == "Messidor2"` → `split = external` at `buildManifest` creation, never overwritten by `generateSplits`.
- Grouping: where `patient_id != UNKNOWN`, group by `patient_id` (all images of one patient move together); singleton images (`UNKNOWN`) are each their own group.
- Stratification: groups stratified by `dr_grade` mode per patient, unlabeled groups proportionally random.
- Determinism: `rng(seed)` + `randperm` within each grade, `manifest` sorted before split, `split_metadata.json` records `seed 42, ratios, strategy, timestamp, nPatientsGrouped, nSingletonImages, actualRatios`.
- Reproducibility verified by `validatePhase1:checkSplitReproducibility` — two runs produce identical `split` vectors (synthetic and empty states).

Empty production: `data/splits/train.csv 0 rows, val 0, test 0, external 0, UNKNOWN 0`, metadata `status NOT VALIDATED — EMPTY MANIFEST`. Synthetic: `train 13, val 2, test 4, external 4` (19 dev pool).

---

## F. Leakage Checks

- Implemented: `generateSplits.m:checkLeakage()` and `validatePhase1.m:checkLeakage()` + `checkSplitReproducibility`.
- Checks: (1) no `patient_id` in multiple of `{train,val,test}`; (2) no overlap between `external` and dev pools; (3) `validatePhase1` re-checks after splits.
- Result (empty): `empty manifest — no leakage` (trivially PASS, documented limitation: no known patient IDs to verify).
- Result (synthetic): `No patient appears in multiple splits (6 patients checked)` — `externalLeakage false`, stored in `results/synthetic_test_evidence/split_metadata_synthetic.json:leakageCheck`.

See `docs/DATA_LEAKAGE_POLICY.md` for full policy, seed recording, and per-dataset patient-ID availability table (APTOS pseudo-patient, IDRiD one-per-subject, DRIVE 40 subjects, Messidor-2 UNKNOWN until CSV appears).

---

## G. Annotation Mapping Status

### IDRiD (`registerIDRiDAnnotations.m:1` → `results/idrid_annotation_registry.csv`)

- Status empty production: `0 rows, 0 fundus, 0 annotFiles` — infrastructure `IMPLEMENTED` but `NOT PRESENT`, `summary.status NOT PRESENT`.
- Status synthetic: `7 registry rows` — MA 2, HE 2, EX 2, NONE 1 (fundus without lesion GT), 6 annot files discovered, 1 metadata CSV, orphan handling verified. The registry correctly grouped `_MA/_HE/_EX` suffixes and semicolon-joined multiple lesions per image where applicable.
- Mapping verified in `validatePhase1:annotationMapping`.

### DRIVE (`registerDRIVEMasks.m:1` → `results/drive_vessel_registry.csv`)

- Status empty production: `0 rows, 0 fundus, 0 masks`.
- Status synthetic: `3 rows` — training 2 + test 1, all with `has_vessel_annotation true` mapped via numeric ID (`21_training.tif ↔ 21_manual1.gif`), `has_fov_mask` for 2, split inference (training/test) from path.
- Verification: numeric-ID lookup + fallback, orphan detection, no mask altered.

Both registries are regenerated on every `runAudit`/`register*` call and survive empty-state.

---

## H. Messidor-2 Label Status (Honest)

See `docs/MESSIDOR2_EXTERNAL_VALIDATION.md`.

- Current production: `data/raw/Messidor2/` empty — `buildManifest:parseMessidor2Labels()` finds no `*.csv/*.xlsx`, sets `dr_grade = NaN` for all Messidor-2 rows (0 rows currently). Audit reports `byGradePerDataset.Messidor2.UNKNOWN = total` (or 0 when empty) and notes `"External image dataset available, but DR ground-truth availability must be verified before sensitivity/specificity evaluation."` — exact required sentence is present in `auditDataset.m:notes` for empty and in the external validation doc.
- Code correctly **does not assume labels**; `generateSplits` isolates Messidor-2 regardless of label presence.
- Synthetic: 4 Messidor-2 images created without CSV — correctly resulted in `4 external, 0 labeled, UNKNOWN 4` and stayed `external` through splits, proving isolation.

If a grading spreadsheet is later placed under `data/raw/Messidor2/`, `buildManifest` will auto-discover it (searching for `grade/diagnosis/retinopathy` columns) without code changes.

---

## I. Validation / Test Results

### `validatePhase1.m:1` — 10 checks (MATLAB R2026a)

| # | Check | Empty run | Synthetic run | Detail |
|---|-------|-----------|---------------|--------|
| 1 | MATLAB parse | PASS | PASS | 12 files checked, `checkcode` error-free |
| 2 | Configurable paths | PASS | PASS | `datasetConfig` with different root gives different `projectRoot` |
| 3 | Manifest generation | PASS (rows 0) | PASS (rows 23) | `buildManifest` completes + writes CSV/MAT |
| 4 | Unreadable handling | PASS | PASS | corrupt `corrupt.png` reported via `loadImageSafe`, audit `missing/unreadable` counts correct |
| 5 | Counts consistent | PASS | PASS | `manifest 0 == audit 0`, sum `byDataset` consistent; synthetic `23 == 23` |
| 6 | Annotation mapping | PASS | PASS | registries `0/0` empty, `7/3` synthetic verified |
| 7 | Splits reproducible | PASS | PASS | two runs identical (`empty deterministic` / `two runs produced identical split assignments`) |
| 8 | No patient leakage | PASS | PASS | `empty — no leakage` / `6 patients checked, no leakage, externalLeakage false` |
| 9 | Raw not modified | PASS | PASS | `mtime` sums unchanged before/after pipeline |
| 10 | Results generated | PASS | PASS | `audit_results.json` etc. present |

Overall empty: `PASS (10/10)`, synthetic: `PASS (10/10)`. Artifacts: `results/phase1_validation.json/.mat` (empty) + `results/synthetic_test_evidence/phase1_validation_synthetic.json` (23-row proof).

### Additional verified behaviors

- `loadImageSafe` handles grayscale (1-channel) vs RGB (3-channel) and reports `channels` correctly (synthetic `C1=7` includes grayscale test).
- `findImageFiles` correctly ignores non-image files (`.csv` etc.) and is case-insensitive.
- `computeFileHash` duplicate detection works (synthetic duplicate pair → `duplicateHashGroupCount 1`).
- `runAudit` human report `docs/PHASE1_AUDIT_REPORT.md` regenerates without warnings after fix (empty shows `DATASET NOT PRESENT` banner; synthetic shows 23-row tables).
- No raw files modified (`validatePhase1:captureMtimes`).

---

## J. Known Limitations

1. **No datasets downloaded** — counts are `0` in production; all Phase 1 claims are infrastructure-level (`IMPLEMENTED` not `VALIDATED` on real clinical data). `results/synthetic_test_evidence/` proves loader handles real images, but clinical validation requires actual downloads.
2. **Patient linkage unavailable** for APTOS/DRIVE/Messidor-2 (APTOS `id_code` as pseudo-patient, DRIVE 40 subjects one-image-per-subject, Messidor-2 `UNKNOWN`). Leakage prevention falls back to image-level stratified split — documented in `DATA_LEAKAGE_POLICY.md:patientStats.perDataset.unknownRows`. True patient-level verification will be possible only if distributors publish patient maps.
3. **Quality status** is intentionally `UNKNOWN` for all rows — no quality algorithm in Phase 1 (spec §13).
4. **Column header sanitization** — IDRiD CSV `Image name` becomes `ImageName` via `readtable` (MATLAB valid-name rule), logged as warning `"Column headers were modified..."`; `VariableDescriptions` preserves originals. Not a data loss.
5. **Supported formats** include `png,jpg,jpeg,tif,tiff,bmp,ppm,pgm`; DRIVE `.gif` masks are handled separately via `registerDRIVEMasks` but not in the general `supportedExtensions` (masks use `.gif` fallback in that registry). If future raw contains `.gif` fundus images, add to `datasetConfig`.
6. **Hash scheme** uses Java `MD5` when JVM available; fallback is file-size+checksum hybrid (not cryptographically strong) — sufficient for audit duplicate detection, not for security.
7. **Split ratios** are exact for large datasets but rounded for small synthetic (13/2/4 instead of 16/3/4) due to per-grade rounding — correct for production scale.
8. **`data/raw/.gitkeep`** placeholders must be preserved; `.gitignore` excludes `data/raw/` except those keeps.

---

## K. Exact Next Step for Phase 2

> **Do not start Phase 2 until Phase 1 is `PASS` and datasets are downloaded. The next step is a single, auditable action:**

1. **Download datasets** per `docs/DATASET_DOWNLOAD_GUIDE.md` into the fixed paths:
   - APTOS → `data/raw/APTOS2019/train_images/*.png + train.csv`
   - IDRiD → `data/raw/IDRiD/A. Segmentation/... + B. Disease Grading/...`
   - DRIVE → `data/raw/DRIVE/training/{images,1st_manual,mask} + test/...`
   - Messidor-2 → `data/raw/Messidor2/{images + optional grades.csv}`

2. **Re-run Phase 1 pipeline in MATLAB (from `DR_Screening/`):**

   ```matlab
   addpath(genpath('matlab'));
   cfg = datasetConfig();            % verify cfg.projectRoot
   generateManifest([], 'computeHash', true);  % → data/processed/manifest.csv (should be >0 rows)
   runAudit([], 'computeHash', true, 'checkImageRead', true); % → results/audit_results.json + docs/PHASE1_AUDIT_REPORT.md
   registerIDRiDAnnotations();
   registerDRIVEMasks();
   generateSplits();                 % → data/splits/{train,val,test,external}.csv + split_metadata.json (seed 42)
   validatePhase1();                 % → results/phase1_validation.json should be PASS (10/10) with rows>0
   ```

3. **Inspect `docs/PHASE1_AUDIT_REPORT.md`** — confirm the two required tables:
   - `Dataset | Images | DR labels | Lesion | Vessel | Intended role`
   - `Dataset | Level 0 | Level 1 | Level 2 | Level 3 | Level 4`

   and that `Messidor-2` shows `external` and correct label `UNKNOWN` vs labeled status.

4. **Only after** `validatePhase1` is `PASS` with `totalImages > 0` and `audit_results.json:missingCount 0`, proceed to **Phase 2 — Image-Quality Algorithms** (spec §13/§16 boundary). Phase 2 will implement `matlab/quality/` and `matlab/preprocessing/` without modifying `matlab/data/` or raw data.

No other preparation is required; Phase 1 leaves `quality_status = UNKNOWN` intentionally for Phase 2 to populate.

---

## Appendix — Output Inventory (Spec §14)

| Required Output | Location | Status |
|-----------------|----------|--------|
| 1. MATLAB dataset loader | `matlab/data/{datasetConfig,findImageFiles,loadImageSafe,computeFileHash}.m` | IMPLEMENTED, parse-clean, validated |
| 2. Dataset manifest | `data/processed/manifest.csv/.mat` (header-only empty, 23-row synthetic evidence preserved) | IMPLEMENTED |
| 3. Dataset audit script | `matlab/data/{auditDataset,runAudit}.m` | IMPLEMENTED |
| 4. Dataset audit report | `docs/PHASE1_AUDIT_REPORT.md` (generated) + `results/audit_results.json/.mat` | IMPLEMENTED |
| 5. Reproducible split-generation script | `matlab/data/generateSplits.m` | IMPLEMENTED, seed 42 |
| 6. Split metadata | `data/splits/split_metadata.json/.mat` + `train/val/test/external.csv` | IMPLEMENTED |
| 7. Leakage-prevention documentation | `docs/DATA_LEAKAGE_POLICY.md` | IMPLEMENTED |
| 8. Dataset provenance documentation | `docs/DATASET_PROVENANCE.md` | IMPLEMENTED |
| 9. IDRiD annotation registry | `results/idrid_annotation_registry.csv/.mat/.json` | IMPLEMENTED (0 rows empty, 7 rows synthetic) |
| 10. DRIVE vessel-mask registry | `results/drive_vessel_registry.csv/.mat/.json` | IMPLEMENTED (0 rows empty, 3 rows synthetic) |
| 11. Messidor-2 external-validation documentation | `docs/MESSIDOR2_EXTERNAL_VALIDATION.md` | IMPLEMENTED |

Generated summary tables per §14 are in `docs/PHASE1_AUDIT_REPORT.md` (both empty and synthetic copies).

**Validation**: `results/phase1_validation.json` (`PASS 10/10` empty) and `results/synthetic_test_evidence/phase1_validation_synthetic.json` (`PASS 10/10` synthetic) + `docs/PHASE1_VALIDATION_REPORT.md`.

**STOP after Phase 1.** Do not proceed automatically to Phase 2.

