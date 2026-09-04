# Messidor-2 — External Validation Documentation (Phase 1)

> **Role**: External validation dataset. Isolated from all development training/tuning.

## Designation

Per `docs/DATASET_PROVENANCE.md`, Messidor-2 is the **external validation** cohort. This decision is enforced in code:

- `datasetConfig.m`: `cfg.externalDatasets = {'Messidor2'}`
- `buildManifest.m`: every Messidor-2 row → `split = external` at creation
- `generateSplits.m`: never reassigns `external` rows to train/val/test
- `auditDataset.m`: reports `bySplit.external` separately and checks for patient overlap

Downgrading Messidor-2 to development would require an explicit protocol change and provenance update.

## Source & Licensing

- **Official distributor**: ADCIS — https://www.adcis.net/en/third-party/messidor2/
- Messidor-2 consists of **1748 fundus images** (874 examinations, 2 eyes per examination) in the public descriptions. Actual count is whatever is delivered and discovered under `data/raw/Messidor2/`.
- Access requires agreeing to ADCIS terms and downloading a protected archive. The archive does **not** automatically include a grading CSV in all distributions — some deliveries include a separate pairing/grading file that must be requested or paired via clinical metadata.

## Ground-Truth Availability — Truthful Status

> **Do not assume Messidor-2 contains ground-truth DR labels unless they are actually available from the official source/metadata we obtain.**

### What Phase 1 does

- `buildManifest.m:parseMessidor2Labels()` searches `data/raw/Messidor2/` for any `*.csv`, `*.xlsx`, `*.xls` containing DR grades.
- It attempts to match columns named like `image`, `diagnosis`, `grade`, `retinopathy`, `adjudicated`, etc.
- If no file is found, or the file contains no grade column, **no labels are fabricated**. `dr_grade` remains `NaN`, `dr_grade_original` remains `''`.

### Outcome table

| Scenario | `dr_grade` in manifest | What to do |
|----------|------------------------|------------|
| No metadata file found | `NaN` for all Messidor-2 rows | Record status: `"External image dataset available, but DR ground-truth availability must be verified before sensitivity/specificity evaluation."` — do not compute DR metrics. |
| Metadata file found with DR grades | Populated per image | Record file path, column names, grading scale (Messidor/Messidor-2 uses its own 0–4/0–3 scales depending on source), and any adjudication notes. Proceed to external evaluation only after verifying scale mapping to APTOS 0–4 taxonomy. |
| Metadata file found without DR grades (e.g., only patient/eye/dilation info) | `NaN` | Same as no-file case — do not pretend labels exist. |

### Current repository status (Phase 1, no download yet)

- `data/raw/Messidor2/` contains only `.gitkeep` — **DATASET NOT PRESENT — DOWNLOAD REQUIRED** (audit will report this).
- No metadata CSV is present, so `dr_grade` will be `UNKNOWN` for Messidor-2.
- No sensitivity/specificity is computed or claimed in Phase 1.

### Exact sentence to use when labels are unavailable

> "External image dataset available, but DR ground-truth availability must be verified before sensitivity/specificity evaluation."

This sentence appears verbatim in `results/audit_results.json` notes when `byGradePerDataset.Messidor2.UNKNOWN == byGradePerDataset.Messidor2.total`.

## Isolation Policy

- Messidor-2 images **must not** be sampled into `data/splits/train.csv`, `val.csv`, or `test.csv`.
- They live in `data/splits/external.csv` only.
- No Phase 2+ hyperparameter tuning, preprocessing fitting, or quality threshold calibration may use Messidor-2.
- Overlap check: `generateSplits:checkLeakage()` verifies that no `patient_id` appears in both external and development splits (when IDs are available). Any overlap is flagged as `externalLeakage: true`.

## Handling Multiple Messidor-2 Scales

If a grading file is later obtained, document:

- Source filename (e.g., `Messidor-2_DatasetInformation.xlsx`)
- Column(s) used for DR grade (e.g., `Adjudicated DR grade`)
- Scale definition (e.g., Messidor 0 = no DR, 1 = mild, ... or merged referable schema)
- Mapping to APTOS 0–4 and to referable/non-referable endpoint (see `REFERABLE_DR_DEFINITION.md`):
  - `Non-referable: 0 + 1`
  - `Referable: 2 + 3 + 4`

Do not silently remap scales; record the mapping table in `docs/MESSIDOR2_EXTERNAL_VALIDATION.md` as an addendum when data arrives.

## Audit & Validation Hooks

- `results/audit_results.json:byGradePerDataset.Messidor2` — shows labeled vs UNKNOWN.
- `results/audit_results.json:bySplit.external` — count of external images.
- `validatePhase1.m:checkLeakage` — verifies external isolation.
- Human report: `docs/PHASE1_AUDIT_REPORT.md` includes a Messidor-2 row in both summary tables.

## Manual Steps Required (User Action)

1. Apply for Messidor-2 via ADCIS (form at https://www.adcis.net/en/third-party/messidor2/).
2. Extract archive into `data/raw/Messidor2/` preserving subfolder structure.
3. If a grading/pairing spreadsheet is provided separately, place it alongside images (e.g., `data/raw/Messidor2/Messidor-2 grades.csv`).
4. Re-run:
   ```matlab
   cfg = datasetConfig();
   generateManifest();     % will auto-discover the new CSV
   runAudit();             % will populate Messidor2 grade distribution
   generateSplits();       % remains external
   ```
5. Inspect `results/audit_results.json` to confirm whether `dr_grade` is now populated for Messidor2. If not, the status sentence above still applies.

## Quality Status for Messidor-2

`quality_status = UNKNOWN` for all Messidor-2 images in Phase 1 (no quality algorithm yet). Do not infer quality from image appearance.

## Summary

Messidor-2 is implemented as a **strictly isolated external image pool** with **honest label accounting**. Phase 1 proves the plumbing works even when the dataset is absent; when it arrives, label truth is discovered rather than invented.
