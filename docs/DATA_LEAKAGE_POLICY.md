# Data Leakage Policy — Phase 1

> Leakage prevention is implemented now; model training comes later. This policy is enforced by `generateSplits.m` and verified by `validatePhase1.m` + `auditDataset.m`.

## Principles

1. **No patient appears in more than one of {train, val, test}.**
2. **External validation is sacred.** Messidor-2 never contributes to training or hyperparameter tuning when designated as external.
3. **No test-set peeking.** All preprocessing parameter choices, thresholds, and model selection must be made using only `train` (and `val` for early stopping). `test` is locked until final reporting.
4. **No feature leakage.** Future preprocessing (CLAHE params, normalization statistics) must be fit on `train` only, then applied to val/test/external.
5. **Document every gap.** If patient IDs are unavailable, state it and mitigate conservatively.

## How Splits Are Created

### Code: `matlab/data/generateSplits.m`

- **Inputs**: `data/processed/manifest.csv` (with `patient_id`, `dr_grade`, `dataset`)
- **Outputs**:
  - `data/processed/manifest.csv` (updated `split` column)
  - `data/splits/train.csv`, `val.csv`, `test.csv`, `external.csv` (each is a filtered view of the manifest)
  - `data/splits/split_metadata.json` (seed, ratios, strategy, leakage check)

### Step-by-step

1. **Isolate external** — rows where `dataset ∈ {Messidor2}` → `split = external` immediately, excluded from all other steps.
2. **Development pool** — `dataset ∉ {Messidor2}` → pooled for train/val/test.
3. **Grouping key**:
   - Where `patient_id ≠ UNKNOWN` — group rows by `patient_id` (all images of one patient move together).
   - Where `patient_id == UNKNOWN` — each image is its own singleton group (conservative; no false grouping).
4. **Stratification** — groups are stratified by `dr_grade` (mode grade per patient) so train/val/test preserve class ratios. Unlabeled groups (`dr_grade = NaN`) are split proportionally at random.
5. **Determinism** — `rng(seed)` where `seed = 42` (from `datasetConfig.m`). Shuffling within each grade uses `randperm` under this seed. Re-running produces identical splits (verified by `validatePhase1`).
6. **Ratios** — default `train 70% / val 15% / test 15%` (configurable via `cfg.splitRatios`).

### Seed Recording

`split_metadata.json` example:

```json
{
  "timestamp": "2026-08-30 12:00:00",
  "seed": 42,
  "ratios": { "train": 0.7, "val": 0.15, "test": 0.15 },
  "strategy": "patient-grouped (known patients grouped, UNKNOWN-patient images as singletons), stratified by grade",
  "nPatientsGrouped": 1204,
  "nSingletonImages": 800,
  "leakageCheck": { "patientLeakage": false, "details": "No patient appears in multiple splits (1204 patients checked)" }
}
```

## Where Patient IDs Come From (and where they don't)

| Dataset | patient_id source | Availability |
|---------|-------------------|--------------|
| APTOS 2019 | `id_code` as pseudo-patient (no true patient list published) | **Unavailable** as true patient — manifest keeps `patient_id = id_code` but audit flags as `UNKNOWN`-equivalent for true linkage; split treats each id_code as its own patient (safe upper bound) |
| IDRiD | Image filename (`IDRiD_001` etc) — nominally one per subject; CSV rarely provides separate patient column | One image per patient; grouping is effectively image-level |
| DRIVE | No patient IDs — 40 images from 40 subjects (one per subject per spec) | `patient_id = UNKNOWN` for all — image-level split is correct by design |
| Messidor-2 | Distribution may provide a pairing CSV with patient/examination IDs if user obtains it; otherwise `UNKNOWN` | If CSV appears, `parseMessidor2Labels` in `buildManifest.m` will populate `patient_id`; audit will then verify no overlap with development pool (there should be none, since external is isolated) |

**Documented limitation** (honest): when `patient_id == UNKNOWN` for an entire dataset, patient-level leakage can only be *conservatively bounded*, not cryptographically proven. The fallback (image-level stratified split) is the correct mitigation and is explicitly flagged in `audit_results.json` under `patientStats`.

## Leakage Checks (Automated)

`generateSplits.m` calls `checkLeakage()`:

- For every `patient_id ≠ UNKNOWN` in the development pool, collects the set of splits that patient appears in.
- **FAIL if any patient appears in >1 split.**
- Also checks that no `patient_id` appears in both `external` and `{train,val,test}`.

`validatePhase1.m` re-runs the same check and reports:

```
[PASS] No patient leakage : No patient appears in multiple splits (1204 patients checked)
```

If leakage is detected, `split_metadata.json` records `patientLeakage: true` and lists offending patients (up to 5 shown in JSON, full list in manifest).

## External Validation Isolation

Messidor-2 rules (non-negotiable until project leadership explicitly re-designates it):

- `buildManifest.m` sets `split = external` for **all** Messidor-2 rows at creation time.
- `generateSplits.m` never overwrites `external` rows.
- `auditDataset.m` reports `bySplit.external` separately.
- No Phase 2+ code may sample from `external` for training or early stopping. If a future experiment needs a Messidor-2 tuning split, that decision must be documented as a **protocol deviation** with provenance updated.

## Test-Set Discipline

- `test` rows must not influence:
  - preprocessing statistics (e.g., mean/std, CLAHE clip limits)
  - quality thresholds
  - model selection or early stopping
  - lesion/mask hyperparameter tuning
- Only `train` (and optionally `val`) may be used for fitting.

## Exclusion Rules

- Corrupt/unreadable images (flagged by `loadImageSafe.m`) remain in the manifest with `status = unreadable/corrupt` but are **excluded** from training. They are counted in audit and may be excluded from splits by filtering `status == OK` before `generateSplits` (current implementation keeps them but they will fail at training load — downstream code should filter). Exclusion is logged, not silently dropped.
- Duplicate basename groups are **not** deduplicated automatically; provenance (`dataset` + `file_path`) keeps them distinct. If exact byte duplicates are found (`file_hash` identical) the audit flags `duplicateHashGroupCount`; the default policy is to keep one and document, not silently drop.

## Reproducibility Contract

- Seed is fixed (`42`) and recorded.
- Manifest is sorted by `(dataset, image_id)` before splitting.
- `randperm` order within each grade is deterministic.
- Re-running `generateSplits.m` with the same manifest produces bit-identical `split` assignments (verified by `validatePhase1` running splits twice).

## What Phase 1 Does NOT Do

- No classifier is trained, so no leakage via learned features yet.
- No preprocessing parameters are estimated.
- No quality status is predicted (stays `UNKNOWN`).

## Audit Trail

- `results/audit_results.json` — per-split counts, patientStats, laterality, annotation availability.
- `data/splits/split_metadata.json` — seed, ratios, strategy, leakageCheck.
- `docs/PHASE1_AUDIT_REPORT.md` — human-readable summary.
- `docs/PHASE1_VALIDATION_REPORT.md` — validation pass/fail per check.
