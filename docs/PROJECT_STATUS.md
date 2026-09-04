# Project Status

**Last updated:** September 2026

## Summary

This project develops an AI-assisted DR screening system from retinal fundus images. The DR classifier has been internally evaluated on the project's development dataset. Handcrafted lesion detectors were externally validated on IDRiD and DDR and failed to generalize. We are transitioning to learned lesion segmentation.

---

## Component Status

### ✅ Validated / Frozen

| Component | Status | Last Verified | Evidence |
|-----------|--------|---------------|----------|
| Fundus preprocessing | Frozen | Phase 20H | SHA256 in `PHASE20H_SYSTEM_FREEZE.md` |
| DR classification (5-class) | Frozen | Phase 8 | Commit `cc7bed8`, 612 test images |
| Referable DR screening | Evaluated | Phase 22 | 91.0% sens / 91.5% spec (internal) |
| Confidence calibration | Evaluated | Phase 22 | ECE = 0.033 |
| Test set | Locked | Phase 8 | No modifications since |

### ⚠️ Implemented but Limited

| Component | Status | Limitation |
|-----------|--------|------------|
| Grad-CAM | Works on most images | Zero-CAM on some G0 images (Phase 21) |
| Clinical report | Generates correctly | Lesion counts marked "experimental" |
| Annotation tool | QA-tested (65/65) | No annotations collected yet |

### ❌ Failed External Validation

| Component | IDRiD Result | DDR Result | Root Cause |
|-----------|-------------|------------|------------|
| MA detection | Dice = 0.000 | 0% detection | Resolution + domain mismatch |
| HE detection | Dice = 0.033 | 50% detection (worse) | Dataset domain generalization failure |
| EX detection | Dice = 0.011 | 0% detection | Dataset domain generalization failure |

### ⏳ Planned / In Progress

| Component | Status | Next Step |
|-----------|--------|-----------|
| FGADR evaluation | Access requested | Awaiting dataset author response |
| Learned lesion segmentation | Planned | Phase 25: U-Net on multi-dataset masks |
| External clinical validation | Future | Phase 27 |
| Simulink deployment | Future | Phase 8 |

---

## Key Frozen Artifacts

| Artifact | Commit | SHA256 |
|----------|--------|--------|
| `trainedNetTL.mat` | `cc7bed8` | `59AFAFF30CEA618A05BC081A314191BDEEDF2C9B450B804D12A6F3D8E4EBA69C` |
| `preprocessFundus.m` | `cc7bed8` | `03A273CCB461EA5ED47841BBFD59BDCF2029CB9D115724D954D321198CFB460C` |
| `gradcamSimple.m` | `cc7bed8` | `975CC55D7D7004B5B1EDA87CFD0F85474239B34732919B0C65B02014EEF757D4` |

System freeze: commit `af312e8` (Phase 20H).

---

## What Has NOT Been Claimed

1. ~~"The lesion detectors are clinically validated"~~ — They are not
2. ~~"MA=24, HE=13 are confirmed lesions"~~ — They are experimental algorithmic outputs
3. ~~"The system is ready for clinical use"~~ — It is a research prototype
4. ~~"Grad-CAM explanations are medically reliable"~~ — Clinically unvalidated
