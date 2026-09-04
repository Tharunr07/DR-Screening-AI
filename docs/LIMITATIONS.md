# Limitations

**Last updated:** September 2026

This document honestly describes what the system cannot do. A researcher reviewing this repository should read this file to understand the project's scope.

---

## 1. Lesion Detection Does Not Generalize

The handcrafted morphological detectors (MA, HE, EX) were evaluated on two external datasets with expert pixel-level annotations:

- **IDRiD:** MA Dice = 0.000, HE Dice = 0.033, EX Dice = 0.011
- **DDR:** MA 0% detection, HE 50% detection (worse than IDRiD), EX 0% detection

**Root cause:** The detectors' morphological parameters were implicitly calibrated for APTOS images and do not generalize to other camera systems, populations, or imaging protocols.

**Impact:** Lesion counts (e.g., "MA=24, HE=13") should NOT be interpreted as confirmed medical findings. They are experimental algorithmic outputs.

**Planned mitigation:** Phase 25 — Replace with U-Net learned segmentation trained on multi-dataset expert masks.

---

## 2. Classifier Not Externally Validated

The 79.5% accuracy and 91.0% referable sensitivity are measured on the project's internal APTOS test set (612 images). This test set:

- Comes from the same dataset as training data (APTOS 2019)
- Has not been independently verified by external clinicians
- Does not represent the full diversity of clinical fundus images

**Impact:** Performance on clinical populations may differ significantly.

**Planned mitigation:** Phase 27 — External validation on independent clinical data.

---

## 3. Grad-CAM Explanations Not Clinically Validated

Grad-CAM shows where the model attends, but we have NOT established that:

- Attention regions correspond to pathological lesions
- Explanations are clinically meaningful to ophthalmologists
- The explanations are consistent across similar cases

**Known limitation:** Some G0 images produce zero-response Grad-CAM, generating blank heatmaps.

---

## 4. No Pixel-Level Lesion Ground Truth for APTOS

APTOS (our training dataset) provides image-level DR grades only, not pixel-level lesion annotations. This means:

- We cannot measure whether the classifier "looks at the right lesions"
- The lesion detectors were never trained on verified lesion locations
- Grad-CAM explanations cannot be validated against lesion ground truth

---

## 5. Small External Validation Set

- IDRiD lesion validation: 54 images (limited statistical power)
- DDR lesion validation: 60 images (subset of full dataset)
- Messidor-2: 1,748 images but labels not yet verified

Larger external validation is needed for robust conclusions.

---

## 6. Single-Model Architecture

The system uses a single ResNet-18 model. It does not:

- Ensemble multiple models
- Use attention mechanisms
- Incorporate lesion detection as a joint training signal
- Leverage multi-task learning

---

## 7. No Clinical Workflow Integration

This is a standalone research prototype. It does not:

- Interface with Electronic Health Records (EHR)
- Support DICOM image formats
- Handle patient scheduling or follow-up
- Meet regulatory requirements (FDA, CE, etc.)

---

## Summary

| What | Status |
|------|--------|
| Software correctness | ✅ Verified (123/123 tests pass) |
| Classifier internal evaluation | ✅ 79.5% accuracy |
| Lesion detection | ❌ Failed external validation |
| External clinical validation | ❌ Not performed |
| Clinical deployment readiness | ❌ Research prototype only |
