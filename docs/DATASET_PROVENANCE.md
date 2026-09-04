# Dataset Provenance — Phase 1

> **Scope**: Phase 1 — Dataset Foundation only. No training, no enhancement, no clinical claims.

## Purpose

Preserve **dataset provenance** (origin, role, and intended use) so experiments never blindly merge datasets with distinct clinical or technical roles.

## Datasets

| # | Dataset | Official Source | Primary Role in This Project | Allowed Use | External? |
|---|---------|----------------|------------------------------|-------------|-----------|
| 1 | **APTOS 2019 Blindness Detection** | https://www.kaggle.com/c/aptos2019-blindness-detection | DR severity classification, five-class grading (0–4) | Development (train/val/test) | No |
| 2 | **IDRiD — Indian Diabetic Retinopathy Image Dataset** | https://ieeedataport.org/open-access/indian-diabetic-retinopathy-image-dataset-idrid | DR grading + lesion analysis (MA/HE/EX/SE/OD) | Development (train/val/test) | No |
| 3 | **DRIVE** | https://drive.grand-challenge.org/ | Retinal vessel segmentation — FOV + 1st/2nd manual masks | Development (segmentation subset) | No |
| 4 | **Messidor-2** | https://www.adcis.net/en/third-party/messidor2/ | External validation — isolated from all tuning | **External only** | **Yes** |

### Provenance is encoded in manifest

Every row in `data/processed/manifest.csv` carries:

```
dataset ∈ {APTOS2019, IDRiD, DRIVE, Messidor2}
provenance = dataset (or dataset/subrole, e.g., DRIVE/mask)
file_path, file_path_absolute  (portable + absolute)
```

No merging obscures origin. Downstream code must filter by `dataset` explicitly.

## Dataset-Specific Provenance Rules

### APTOS 2019
- **Expected raw layout** (after manual download & unzip):
  ```
  data/raw/APTOS2019/
    train_images/*.png  (3662 images, 2019 train split)
    test_images/*.png   (1928 images, Kaggle test — unlabeled)
    train.csv           (id_code, diagnosis 0–4)
    sample_submission.csv
  ```
- **Labels**: 5-class `diagnosis` mapped to `dr_grade` (0–4). Original label preserved in `dr_grade_original`.
- **Patient linkage**: Kaggle does not publish patient IDs; `patient_id` remains `UNKNOWN` unless future metadata appears. Documented as limitation — split falls back to stratified image-level (see leakage policy).
- **Laterality**: not provided; `laterality = UNKNOWN`.

### IDRiD
- **Expected raw layout** (v2.1):
  ```
  data/raw/IDRiD/
    A. Segmentation/
      1. Original Images/  idrid_*.jpg
      2. All Segmentation Groundtruths/
         MA/, HE/, EX/, SE/, OD/
    B. Disease Grading/
      1. Original Images/
      2. Groundtruths/  *.csv  (Image name, Retinopathy grade, Risk of macular edema)
  ```
- **Lesion annotations**: discovered recursively by `registerIDRiDAnnotations.m`; mapping recorded in `results/idrid_annotation_registry.csv`. Lesion types: MA (microaneurysms), HE (hemorrhages), EX (hard exudates), SE (soft exudates), OD (optic disc). Additional anatomical annotations, if present, are captured as `UNKNOWN` type rather than discarded.
- **Labels**: DR grade + diabetic macular edema grade where CSV available.
- **Patient linkage**: Typically one image per patient; `patient_id` derived from image_id unless explicit CSV provides it.
- Verification: `registerIDRiDAnnotations` counts orphan annotations (mask without fundus) and reports in JSON.

### DRIVE
- **Expected raw layout** (grand-challenge download):
  ```
  data/raw/DRIVE/
    training/
      images/      21_training.tif (20 train + 1 appears as 21? actually 20)
      1st_manual/  21_manual1.gif
      2nd_manual/  21_manual2.gif
      mask/        21_training_mask.gif
    test/
      images/      21_test.tif (20)
      1st_manual/  (* test masks exist but use differs)
      mask/
  ```
- **Ground truth**: vessel masks are authoritative for segmentation; optic disc/fovea masks not assumed. `has_vessel_annotation = true` for any fundus image with a discoverable 1st manual path.
- **Mapping**: `registerDRIVEMasks.m` creates `results/drive_vessel_registry.csv` with `image_id ↔ mask_1st_manual_path` verified by numeric ID.
- **Do not alter masks** in Phase 1.

### Messidor-2
- **Expected raw layout** (after ADCIS delivery):
  ```
  data/raw/Messidor2/
    messidor-2/  *.tif  (1748 images, 874 examinations)
    messidor-2.csv  (if provided by distributor — not guaranteed)
  ```
- **Label policy** (strict): **Do not assume labels exist.** Messidor-2 images are distributed; grading may require separate pairing file or manual adjudication. The official ADCIS page does **not** bundle a public CSV. `parseMessidor2Labels` in `buildManifest.m` searches for any `*.csv/*.xlsx` under `data/raw/Messidor2/` but leaves `dr_grade = NaN` and documents `UNKNOWN` if none found.
- **External isolation**: all Messidor-2 rows receive `split = external` at manifest build time; `generateSplits.m` never reassigns them to train/val/test. See `MESSIDOR2_EXTERNAL_VALIDATION.md`.

## Provenance Validation

- `buildManifest.m` logs `DATASET NOT PRESENT — DOWNLOAD REQUIRED` per dataset root missing.
- `auditDataset.m` reports `byDataset` counts and `byGradePerDataset` to surface label provenance.
- `results/audit_results.json` contains `byDataset`, `annotationAvailabilityPerDataset`, `patientStats.perDataset`.

## Download & Licensing Provenance

All four datasets require **manual** agreement to terms (Kaggle TOS, IEEE DataPort, DRIVE challenge rules, ADCIS license). This repository **does not** bundle images or bypass authentication. Provenance of each download must be recorded by the user in `data/raw/<dataset>/README_DOWNLOAD.txt` (not auto-generated).

## Status Labels

- `IMPLEMENTED` — code exists and handles present/missing data
- `VALIDATED` — code executed on real data and counts verified (Phase 1 validation artifact)
- `NOT PRESENT` — dataset directory missing or empty
- `UNKNOWN` — metadata field genuinely unavailable (not fabricated)

## References

- APTOS 2019 competition page (Kaggle) — 5-class grading taxonomy.
- Porwal et al., IDRiD: Indian Diabetic Retinopathy Image Dataset (IEEE DataPort).
- Staal et al., DRIVE: Digital Retinal Images for Vessel Extraction (TMI 2004).
- Decencière et al., Messidor database and Messidor-2 extension (ADCIS).
