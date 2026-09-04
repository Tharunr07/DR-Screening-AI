# Dataset Download Guide — Manual Steps (Phase 1)

> All four datasets require **manual** download and agreement to distributor terms. This repo does **not** bundle images or automate credential bypass.

## Summary

| Dataset | Source | Approx Size | License / Access |
|---------|--------|-------------|------------------|
| APTOS 2019 | https://www.kaggle.com/c/aptos2019-blindness-detection | ~700 MB compressed, 3662 train + 1928 test images | Kaggle competition rules — requires free Kaggle account + “Join Competition” |
| IDRiD | https://ieeedataport.org/open-access/indian-diabetic-retinopathy-image-dataset-idrid | ~1 GB | IEEE DataPort — requires sign-in + accept terms |
| DRIVE | https://drive.grand-challenge.org/ | ~100 MB | Challenge terms — requires registration + manual download via Grand Challenge site |
| Messidor-2 | https://www.adcis.net/en/third-party/messidor2/ | ~1.2 GB | ADCIS license form — requires email application |

---

## APTOS 2019

1. Create / log in to https://www.kaggle.com
2. Visit https://www.kaggle.com/c/aptos2019-blindness-detection → click **Join Competition** (accept rules).
3. Go to **Data** tab and download `aptos2019-blindness-detection.zip` (or use Kaggle API if you have credentials):
   ```bash
   kaggle competitions download -c aptos2019-blindness-detection -p ./tmp
   ```
4. Unzip into the expected layout:
   ```
   data/raw/APTOS2019/
     train_images/  (*.png)
     test_images/   (*.png)   # optional, unlabeled — still indexed as test split later but not used for grading
     train.csv      (id_code, diagnosis)
     sample_submission.csv
   ```
5. Verify:
   ```matlab
   cfg = datasetConfig();
   numel(findImageFiles(cfg.aptosRoot))   % expect ~5590 if both train+test present
   ```

---

## IDRiD

1. Visit https://ieeedataport.org/open-access/indian-diabetic-retinopathy-image-dataset-idrid
2. Log in (free) and **Add to Cart → Checkout** to accept terms.
3. Download `IDRiD_dataset.zip` (or segmented ZIPs). Current version is 2.1.
4. Extract preserving structure:
   ```
   data/raw/IDRiD/
     A. Segmentation/
       1. Original Images/
       2. All Segmentation Groundtruths/
          Microaneurysms/  (*_MA.tif)
          Haemorrhages/    (*_HE.tif)
          Hard Exudates/   (*_EX.tif)
          Soft Exudates/   (*_SE.tif)
          Optic Disc/      (*_OD.tif)
     B. Disease Grading/
       1. Original Images/
       2. Groundtruths/
          IDRiD_Disease Grading_Training Labels.csv
          IDRiD_Disease Grading_Testing Labels.csv  (if included)
   ```
   Note: some mirrors flatten names — `buildManifest` + `registerIDRiDAnnotations` scan recursively, so flat layouts still work, but preserving names aids audit clarity.
5. Verify:
   ```matlab
   cfg = datasetConfig();
   registerIDRiDAnnotations(cfg)  % prints fundus vs annotation counts
   ```

---

## DRIVE

1. Visit https://drive.grand-challenge.org/ → click **Download** (requires Grand Challenge account).
2. Download `DRIVE.zip` (or `drive.tar.gz`) containing `training/` and `test/` folders.
3. Extract to:
   ```
   data/raw/DRIVE/
     training/
       images/
       1st_manual/
       2nd_manual/   (optional)
       mask/
     test/
       images/
       1st_manual/
       mask/
   ```
   Keep `.tif` and `.gif` files as delivered — do not convert formats.
4. Verify:
   ```matlab
   cfg = datasetConfig();
   registerDRIVEMasks(cfg)  % expect 20 training + 20 test fundus images
   ```

---

## Messidor-2

1. Visit https://www.adcis.net/en/third-party/messidor2/
2. Fill the **request form** (name, institution, intended use) and submit.
3. ADCIS will email a download link and credentials (may take days).
4. Download `Messidor-2.zip` (or `Base11/` + `Base12/` + ... depending on version).
5. Extract into:
   ```
   data/raw/Messidor2/
     <images directly or in subfolders>  *.tif/*.jpg
     # If a grading spreadsheet is supplied separately, place it here:
     Messidor-2_DatasetInformation.csv  (example name — varies)
   ```
   `buildManifest` will search recursively for any `*.csv/*.xlsx` to harvest DR grades. If none was provided, that is expected — leave `dr_grade = NaN` and see `MESSIDOR2_EXTERNAL_VALIDATION.md`.
6. Verify:
   ```matlab
   cfg = datasetConfig();
   buildManifest(cfg)   % look for Messidor2 rows with split=external
   ```

---

## After Any Download

Re-run Phase 1 pipeline (from MATLAB, project root on path):

```matlab
addpath(genpath('matlab'));
cfg = datasetConfig();              % paths configurable
generateManifest();                 % scans raw → data/processed/manifest.csv
runAudit('checkImageRead', true);   % validates images, writes results/audit_results.json
registerIDRiDAnnotations();         % if IDRiD present
registerDRIVEMasks();               % if DRIVE present
generateSplits();                   % patient-aware, deterministic splits → data/splits/
validatePhase1();                   % end-to-end checks → results/phase1_validation.json
```

Expected artifacts after a successful run:

```
data/processed/manifest.csv/.mat
data/splits/train.csv, val.csv, test.csv, external.csv
data/splits/split_metadata.json
results/audit_results.json/.mat
results/idrid_annotation_registry.csv
results/drive_vessel_registry.csv
results/phase1_validation.json
docs/PHASE1_AUDIT_REPORT.md   (regenerated)
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `DATASET NOT PRESENT — DOWNLOAD REQUIRED` in audit | Dataset folder missing or empty — verify extraction path matches `datasetConfig` roots |
| `Missing files` > 0 | Images referenced in CSV but not on disk — re-extract, check case sensitivity (Linux vs Windows) |
| `Unreadable/corrupt` > 0 | Re-download that file; check disk space; `loadImageSafe` reports path+error in JSON |
| IDRiD `orphan_no_fundus_match` | Normal if segmentation ground truth exists for an image variant not in fundus folder — audit logs it |
| Messidor-2 `dr_grade` all `NaN` | Expected if no CSV was delivered — do not invent labels; see `MESSIDOR2_EXTERNAL_VALIDATION.md` |

## Licensing Reminder

Do not redistribute downloaded images. Keep each dataset’s license file alongside `data/raw/<dataset>/` if provided. Committing raw images to git is prohibited — `data/raw/` is `.gitignore`'d in the recommended `.gitignore` below.
