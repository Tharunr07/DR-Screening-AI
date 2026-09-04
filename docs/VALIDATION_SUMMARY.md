# Validation Summary

**Last updated:** September 2026

All validation results in one place. For detailed evidence, see the linked documents.

---

## 1. Classifier Performance

### Internal evaluation (APTOS test set, 612 images, frozen since Phase 8)

| Metric | Value |
|--------|-------|
| Overall accuracy | 79.5% |
| Referable DR sensitivity | 91.0% |
| Referable DR specificity | 91.5% |
| AUC | 0.7741 |

### Per-class recall

| Grade | Recall | Notes |
|-------|--------|-------|
| G0 (No DR) | 96.6% | Strong |
| G1 (Mild) | 49.2% | Weak — often confused with G2 |
| G2 (Moderate) | 82.7% | Good |
| G3 (Severe) | 25.6% | Very weak — confused with G2 |
| G4 (Proliferative) | 44.9% | Weak |

### Calibration

| Metric | Raw | After Temperature Scaling |
|--------|-----|--------------------------|
| ECE | 0.033 | 0.023 |
| MCE | 0.707 | — |
| Brier score | 0.269 | — |
| NLL | 0.236 | — |

**Decision:** Calibration not beneficial (marginal improvement, isotonic unusable). See `PHASE22_CALIBRATION.md`.

### Review routing (≥0.70 confidence threshold)

| Metric | Value |
|--------|-------|
| Accuracy at threshold | 92.9% |
| False negatives | 4 |
| False positives | 8 |

---

## 2. Lesion Detection Performance

### IDRiD external validation (54 images, expert pixel-level masks)

| Detector | Dice | IoU | Precision | Recall | Image-Level Detection |
|----------|------|-----|-----------|--------|----------------------|
| MA | 0.000 | 0.000 | 0.000 | 0.000 | 0/54 (0%) |
| HE | 0.033 | 0.018 | 0.214 | 0.020 | 43/53 (81%) |
| EX | 0.011 | 0.006 | 0.144 | 0.006 | 8/54 (15%) |

**Verdict:** NOT SUPPORTED for all three detectors.

See `PHASE24B1_IDRID_LESION_VALIDATION.md`.

### DDR external validation (60 images, expert pixel-level masks)

| Detector | Image-Level Detection | Recall |
|----------|----------------------|--------|
| MA | 0/50 (0%) | 0.000 |
| HE | 15/30 (50%) | 0.029 |
| EX | 0/2 (0%) | 0.000 |

**Verdict:** NOT SUPPORTED. DDR performance equal or worse than IDRiD.

See `PHASE24B3_DDR_EXTERNAL_VALIDATION.md`.

### Resolution dependence analysis

| Dataset | Resolution | MA Detection | HE Detection | EX Detection |
|---------|-----------|-------------|-------------|-------------|
| APTOS | ~640×480 | Unknown* | Unknown* | Unknown* |
| DDR | 1956–3264 | 0% | 50% | 0% |
| IDRiD | 4288×2848 | 0% | 81% | 15% |

*APTOS has no pixel-level lesion masks, so detection cannot be measured.

**Conclusion:** Failure is NOT primarily resolution-dependent. It's dataset domain generalization.

### Forensic verification

- 161/161 image-mask pairs verified (100% size match)
- Coordinate alignment confirmed (visual panels)
- Dice implementation verified (4 known-answer tests)
- MA zero-detection root cause identified: resolution scaling mismatch in morphological pipeline

See `PHASE24B2_FORENSIC_ALIGNMENT.md`.

---

## 3. Software Testing

| Phase | Tests | Result |
|-------|-------|--------|
| Phase 1 (Dataset) | 10 | 10/10 PASS |
| Phase 2 (Quality) | 12 | 12/12 PASS |
| Phase 3 (Structures + Lesions) | 12 | 12/12 PASS |
| Phase 4 (Classification) | 12 | 12/12 PASS |
| Phase 5 (Explainability) | 12 | 12/12 PASS |
| Phase 20H (System freeze) | SHA256 | All hashes match |
| Phase 24A (Annotation tool) | 65 | 65/65 PASS |

**Total software tests:** 123/123 PASS

**Important:** Software tests verify code correctness, NOT medical validity. The 123 passing tests do not mean the lesion detectors find real lesions.

---

## 4. What This Evidence Establishes

### Established ✅

1. The preprocessing pipeline is correct and frozen
2. The classifier achieves 79.5% accuracy on the internal test set
3. Referable DR screening achieves 91.0% sensitivity internally
4. The software pipeline has no code-level defects (123/123 tests pass)
5. The lesion detectors fail against expert ground truth on IDRiD and DDR

### NOT Established ❌

1. ~~Lesion detection is clinically valid~~ — It is not
2. ~~The system generalizes to external clinical populations~~ — Untested
3. ~~Grad-CAM explanations correspond to real pathology~~ — Untested
4. ~~The system is ready for clinical deployment~~ — It is a research prototype
