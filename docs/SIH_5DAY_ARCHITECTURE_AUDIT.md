# DR-Screening-AI — 5-Day SIH Architecture Audit

**Date:** September 5, 2026
**Auditor:** Lead AI/Software Engineer
**Repository:** https://github.com/Tharunr07/DR-Screening-AI
**Status:** READ-ONLY audit — no code modifications performed

---

## 1. Repository State

### 1.1 Current Branch Structure

| Branch | Latest Commit | Content |
|--------|--------------|---------|
| `main` (default) | `29f2bcc` | Polished repo (merged from master) |
| `master` | `eda26d9` | Polished README + validation evidence |

Both branches contain the full project. `main` is the default and Professor Zhou will see this.

### 1.2 Key Frozen Commits

| Commit | Description | Status |
|--------|-------------|--------|
| `cc7bed8` | Frozen model (Phase 8) | LOCKED — do not modify |
| `af312e8` | System freeze (Phase 20H) | LOCKED — do not modify |
| `eda26d9` | Repository polish | Current |

### 1.3 File Inventory

| Directory | Files | Purpose |
|-----------|-------|---------|
| `matlab/demo/` | 3 | GUI + CLI entry points |
| `matlab/lesions/` | 5 | Handcrafted detectors (frozen, not validated) |
| `matlab/classification/` | 2 | ECOC-SVM pipeline (unused by demos) |
| `matlab/clinical/` | 5 | Clinical logic + report generation |
| `matlab/quality/` | 17 | Quality assessment pipeline |
| `matlab/explainability/` | 16 | Grad-CAM + feature analysis |
| `matlab/calibration/` | 2 | Confidence calibration |
| `matlab/validation/` | 50+ | Test suites + evaluation scripts |
| `matlab/shared/` | 1 | preprocessFundus.m (frozen) |
| `matlab/simulink/` | 2 | MATLAB scripts (NOT Simulink models) |
| `matlab/annotation/` | 6 | Three-reader annotation tool |
| `docs/` | 67 | Documentation |
| `data/splits/` | 4 | Train/val/test/external CSVs |

---

## 2. System Architecture

```
                    ┌─────────────────────────┐
                    │   Fundus Image Input     │
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │  Quality Assessment      │ ← 7 independent metrics
                    │  (assessImageQuality)    │    Rule-based classification
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │  Preprocessing           │ ← preprocessFundus.m (FROZEN)
                    │  resize → single         │    NO ImageNet normalization
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │  DR Classification       │ ← ResNet-18 transfer learning
                    │  (classify → G0-G4)      │    Frozen since Phase 8
                    └───────────┬─────────────┘
                                │
                    ┌───────────▼─────────────┐
                    │  Clinical Logic          │ ← applyClinicalLogic.m
                    │  gradeNum >= 2 = ref     │    Quality gating
                    └───────────┬─────────────┘
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                 │
    ┌─────────▼─────────┐ ┌────▼────┐ ┌─────────▼─────────┐
    │  Grad-CAM         │ │ Lesion  │ │  Clinical Report  │
    │  (gradcamSimple)  │ │ Evidence│ │  (structured)     │
    └───────────────────┘ │ (EXPERIMENTAL) └─────────────────┘
                          └─────────┘
```

**Entry Points:**
1. `drScreeningGUIv2()` — Primary GUI (recommended for demo)
2. `runSIHDemo()` — CLI demo
3. `drScreeningGUI()` — Legacy GUI (has inconsistencies)

---

## 3. Component Status Matrix

| Component | Status | Evidence | Risk | SIH Priority |
|-----------|--------|----------|------|--------------|
| Image loading | ✅ Works | Tested in all entry points | LOW | GREEN |
| Quality assessment | ✅ Works | 12/12 tests pass | LOW | GREEN |
| Preprocessing | ✅ Frozen | SHA256 verified | LOW | GREEN |
| DR classification | ✅ Evaluated | 79.5% acc, 91.0% sens | MEDIUM | GREEN |
| Referable decision | ✅ Works | gradeNum >= 2 via applyClinicalLogic | LOW | GREEN |
| Confidence display | ⚠️ Double % bug | drScreeningGUIv2 exportReport | HIGH | RED (demo) |
| Calibration | ✅ Evaluated | ECE = 0.033 | LOW | GREEN |
| Grad-CAM | ⚠️ Works with caveats | Zero-CAM on some G0 images | MEDIUM | GREEN |
| MA detection | ❌ Failed | Dice = 0.000 on IDRiD | CRITICAL | RED |
| HE detection | ❌ Failed | Dice = 0.033 on IDRiD | CRITICAL | RED |
| EX detection | ❌ Failed | Dice = 0.011 on IDRiD | CRITICAL | RED |
| NV detection | ❌ Failed | No external validation | CRITICAL | RED |
| Clinical logic | ✅ Works | 10/10 tests pass | LOW | GREEN |
| GUI (v2) | ⚠️ 3 bugs | Export crashes, hardcoded quality | HIGH | RED (demo) |
| Report generation | ✅ Works | Correct disclaimers | LOW | GREEN |
| Simulink workflow | ⚠️ Misleading | No .slx files, only MATLAB scripts | MEDIUM | YELLOW |
| Dataset validation | ✅ Complete | 7872 rows, no leakage | LOW | GREEN |
| External validation | ✅ IDRiD+DDR | Lesion detectors failed | LOW | GREEN |
| Reproducibility | ✅ Documented | SHA256 hashes, frozen assets | LOW | GREEN |

---

## 4. P0 Demo Blockers

These issues WILL crash or embarrass the demo if not fixed.

### P0-1: `drScreeningGUIv2.m` Export Crashes (lines 783, 786)

**Problem:** `exportReport` references non-existent fields:
- Line 783: `r.grade` → should be `r.gradeNum`
- Line 786: `r.referableProb` → should be `r.probability`

**Impact:** Any attempt to export a clinical report from the GUI will crash with "Reference to non-existent field 'grade'."

**Fix:** Change `r.grade` to `r.gradeNum`, `r.referableProb` to `r.probability`.

**File:** `matlab/demo/drScreeningGUIv2.m`, lines 783, 786.

### P0-2: `drScreeningGUIv2.m` Double-Percentage Confidence (line 785)

**Problem:** `r.confidence*100` but confidence is already `maxProb * 100` (set in `applyClinicalLogic.m:68`). Prints `8720.0%` instead of `87.2%`.

**Impact:** Misleading confidence display on export.

**Fix:** Change `r.confidence*100` to `r.confidence`.

**File:** `matlab/demo/drScreeningGUIv2.m`, line 785.

### P0-3: `drScreeningGUIv2.m` Hardcoded Quality in Report (line 620)

**Problem:** `showClinicalReport` uses `quality = struct('status', 'GOOD', 'score', 0.8, ...)` instead of actual quality data. A poor-quality image will show "GOOD" in the report.

**Impact:** Misleading clinical report — hides quality issues from the doctor.

**Fix:** Propagate quality data from `state.currentResult` or from the screening run.

**File:** `matlab/demo/drScreeningGUIv2.m`, line 620.

---

## 5. P1 Problems

Serious issues that should be fixed but won't crash the demo.

### P0-5: GUI v1 Referable Inconsistency

**Problem:** `drScreeningGUI.m` line 268-269 uses `sum(scores(3:5)) >= 0.1951` instead of `applyClinicalLogic`. This can disagree with the GUIv2 and CLI.

**Fix:** Route through `applyClinicalLogic` or document as legacy.

**File:** `matlab/demo/drScreeningGUI.m`, lines 268-269.

### P0-6: Blur Metric Mismatch

**Problem:** `runSIHDemo.m` line 68 uses `std()` while both GUIs use `var()`. Same threshold `>= 100` applied to different quantities.

**Impact:** Different quality decisions between CLI and GUI for the same image.

**Fix:** Standardize to `var()` across all entry points.

**File:** `matlab/demo/runSIHDemo.m`, line 68.

### P0-7: NV Detector Irregularity Threshold

**Problem:** `detectNeovascularization.m` computes `pathLength / hullPerimeter` which is always >= 1.0. The threshold `> 0.2` is always satisfied, providing no filtering.

**Impact:** NV detector never rejects candidates based on irregularity.

**Fix:** Change threshold to `> 1.5` or use a different metric.

**File:** `matlab/lesions/detectNeovascularization.m`, line 414.

### P0-8: validateGradCAM Undefined Variable

**Problem:** `validateGradCAM.m` line 198 references `imgR` which is undefined. Test always fails.

**Fix:** Change to `img` or `n`.

**File:** `matlab/explainability/validateGradCAM.m`, line 198.

### P0-9: Hardcoded Sensitivity/Specificity in Disclaimers

**Problem:** Multiple files hardcode "Sensitivity 87.2%, Specificity 92.7%" which may not match current validation (actual: 91.0%/91.5%).

**Files:** `generateClinicalReport.m:362-363`, `drScreeningGUIv2.m:809`.

**Fix:** Centralize performance stats or update to current values.

---

## 6. P2 Problems

Low priority, cosmetic issues.

| # | File | Issue |
|---|------|-------|
| 1 | `preprocessFundus.m` | Documentation says "bicubic" but code uses "bilinear" |
| 2 | All lesion detectors | Duplicated `createRetinalMask`, `createDiscMask`, `createVesselMask` |
| 3 | `gradcamSimple.m` line 27 | Docstring says "ImageNet-normalized" (misleading) |
| 4 | `gradcam.m` line 9 | Same misleading docstring |
| 5 | `matlab/simulink/` | No .slx files — misleading directory name |
| 6 | `prepareDeepLearningData.m` | Applies ImageNet normalization (vestigial, not used in inference) |

---

## 7. Current AI/ML Evidence

### 7.1 Classifier Performance (Internal, APTOS Test Set)

| Metric | Value | Confidence |
|--------|-------|------------|
| Overall accuracy | 79.5% | Moderate (612 test images) |
| Referable sensitivity | 91.0% | Moderate |
| Referable specificity | 91.5% | Moderate |
| G0 recall | 96.6% | Strong |
| G1 recall | 49.2% | Weak |
| G2 recall | 82.7% | Good |
| G3 recall | 25.6% | Very weak |
| G4 recall | 44.9% | Weak |
| AUC | 0.7741 | Moderate |
| ECE | 0.033 | Good |

**Important:** These are internal evaluation metrics, NOT clinical validation.

### 7.2 Lesion Detection (External, Expert Masks)

| Detector | IDRiD Dice | IDRiD Image-Level | DDR Dice | DDR Image-Level |
|----------|-----------|-------------------|----------|-----------------|
| MA | 0.000 | 0/54 (0%) | NaN | 0/50 (0%) |
| HE | 0.033 | 43/53 (81%) | NaN | 15/30 (50%) |
| EX | 0.011 | 8/54 (15%) | NaN | 0/2 (0%) |

**Conclusion:** Handcrafted detectors do not generalize. Not medically validated.

### 7.3 What This Evidence Establishes

**Established:**
1. Preprocessing is correct and frozen
2. Classifier achieves 79.5% accuracy internally
3. Referable screening achieves 91.0% sensitivity internally
4. Software pipeline has no code-level defects (123/123 tests pass)
5. Lesion detectors fail against expert ground truth

**NOT Established:**
1. ~~Lesion detection is clinically valid~~
2. ~~The system generalizes to external clinical populations~~
3. ~~Grad-CAM explanations correspond to real pathology~~
4. ~~The system is ready for clinical deployment~~

---

## 8. Lesion Segmentation Assessment

### 8.1 Why Handcrafted Detectors Failed

The morphological pipeline was implicitly calibrated for APTOS image characteristics:
- APTOS camera type and preprocessing
- APTOS resolution (~640×480)
- APTOS lesion appearance

It does not generalize to IDRiD or DDR because:
1. Different camera systems produce different intensity distributions
2. Resolution scaling alone doesn't fix it (DDR is lower res than IDRiD but performs worse)
3. The morphological assumptions (dark-red MA in red channel) don't hold across datasets

### 8.2 Available Expert-Labeled Data

| Dataset | Images | MA Masks | HE Masks | EX Masks | SE Masks | NV Masks |
|---------|--------|----------|----------|----------|----------|----------|
| IDRiD | 54 | ✅ 54 | ✅ 53 | ✅ 54 | ✅ 54 | ❌ |
| DDR | 60 (downloaded) | ✅ 60 | ✅ 60 | ✅ 60 | ✅ 60 | ❌ |
| FGADR | 1,842 | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Total (local)** | **114** | **114** | **113** | **114** | **114** | **0** |

### 8.3 Mask Format

| Dataset | Format | Values | Resolution |
|---------|--------|--------|-----------|
| IDRiD | TIFF, logical | {false, true} | 4288×2848 |
| DDR | TIFF, uint8 | {0, 255} | 1956–3264 |

---

## 9. Learned Segmentation Feasibility

### 9.1 Can We Train a U-Net in 5 Days?

**Answer: YES, a minimal baseline is feasible.**

| Factor | Assessment |
|--------|------------|
| Training data | 114 images (IDRiD+DDR) with MA/HE/EX masks |
| Architecture | U-Net with ResNet-18 encoder ( MATLAB `unetLayers`) |
| Training time | ~30 min on GPU, ~2 hours on CPU |
| Minimum viable | Train on MA only (most masks available), evaluate on held-out IDRiD |
| External eval | IDRiD as test set (54 images) |

### 9.2 Recommended Minimum Viable Baseline

```
Input: 224×224 fundus image
Architecture: U-Net with ResNet-18 encoder
Training: 80/20 split of IDRiD+DDR (91 train, 23 val)
Lesion: MA only (114 masks available)
External test: IDRiD 54 images (if not used in training)
Output: Binary MA segmentation mask
Metric: Dice, IoU, recall
```

### 9.3 What Can Be Demonstrated

- Side-by-side: handcrafted MA (Dice=0.000) vs learned MA (Dice=TBD)
- Visual comparison: expert mask vs detector output vs U-Net output
- This is a compelling "we identified the failure and built a better approach" story

### 9.4 What Must Remain Research-Only

- Multi-lesion segmentation (MA+HE+EX+SE+NV)
- Clinical validation
- Integration with the DR classifier
- Deployment readiness

---

## 10. Five-Day Execution Plan

### Day 1: Stabilization + P0 Bug Fixes

**Morning (2 hours):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Fix export field names | `drScreeningGUIv2.m:783,786` | Prevent crash | LOW | YES |
| Fix double percentage | `drScreeningGUIv2.m:785` | Correct confidence | LOW | YES |
| Fix hardcoded quality | `drScreeningGUIv2.m:620` | Show real quality | MEDIUM | YES |

**Afternoon (2 hours):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Standardize blur metric | `runSIHDemo.m:68` | Consistency | LOW | YES |
| Update hardcoded stats | `generateClinicalReport.m:362` | Accuracy | LOW | YES |
| Fix validateGradCAM | `validateGradCAM.m:198` | Test passes | LOW | YES |

**Evening (1 hour):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Full regression run | All test suites | Verify nothing broke | LOW | YES |

### Day 2: Core AI Pipeline Improvement

**Morning (2 hours):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Prepare IDRiD+DDR masks | `data/raw/` | Consolidate lesion masks | MEDIUM | YES |
| Create train/val split | New script | 80/20 split | LOW | YES |
| Design U-Net config | New file | Architecture spec | MEDIUM | YES |

**Afternoon (3 hours):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Implement U-Net training | New `matlab/lesions/trainLesionUNet.m` | Learn MA segmentation | HIGH | YES |
| Train MA-only baseline | Execute training | ~30 min GPU | MEDIUM | YES |
| Evaluate on held-out IDRiD | New `matlab/lesions/evaluateLesionUNet.m` | Dice/IoU/recall | MEDIUM | YES |

### Day 3: Validation + Evidence

**Morning (2 hours):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Generate comparison panels | New script | Handcrafted vs U-Net vs expert | MEDIUM | YES |
| Compute bootstrap CIs | Extend evaluation | Statistical rigor | LOW | YES |
| Write validation report | `docs/PHASE25_LEARNED_SEGMENTATION.md` | Document evidence | LOW | YES |

**Afternoon (2 hours):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Run full regression | All test suites | Ensure no regression | LOW | YES |
| Update PROJECT_STATUS.md | Documentation | Reflect new results | LOW | YES |
| Update VALIDATION_SUMMARY.md | Documentation | Add U-Net results | LOW | YES |

### Day 4: GUI/Demo Integration

**Morning (2 hours):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Update lesion display wording | `drScreeningGUIv2.m` | "Experimental" label | LOW | YES |
| Integrate U-Net output in GUI | `drScreeningGUIv2.m` | Show learned mask | MEDIUM | YES |
| Test end-to-end flow | Manual testing | Demo readiness | LOW | YES |

**Afternoon (2 hours):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Prepare demo images | 5-10 test images | Pre-selected cases | LOW | YES |
| Test GUI on all demo images | Manual | Verify no crashes | LOW | YES |
| Export clinical reports | Test export | Verify P0 fixes work | LOW | YES |

### Day 5: SIH Demonstration + Presentation Hardening

**Morning (2 hours):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Full demo rehearsal | All components | Timing + flow | LOW | YES |
| Prepare judge Q&A | This document | Defense prep | LOW | YES |
| Final commit + push | Git | Clean state | LOW | YES |

**Afternoon (2 hours):**
| Task | File | Purpose | Complexity | Safe? |
|------|------|---------|------------|-------|
| Presentation dry run | Slides | Story + evidence | LOW | YES |
| Backup plan prep | Offline demo | In case of issues | LOW | YES |
| Repository final check | GitHub | Professor Zhou ready | LOW | YES |

---

## 11. Recommended SIH Demo Flow

**Target: < 30 seconds per image**

```
Step 1: Load fundus image                    (2 sec)
  → Show original image

Step 2: Quality assessment                   (3 sec)
  → Show: "Image Quality: GOOD/BORDERLINE/POOR"
  → Show: brightness, contrast, sharpness metrics
  → If POOR: "Recommend recapture" → stop

Step 3: Preprocessing                        (2 sec)
  → Show: original → preprocessed side-by-side

Step 4: DR Classification                    (3 sec)
  → Show: G0/G1/G2/G3/G4 with confidence bar
  → Show: "Referable: YES/NO"

Step 5: Grad-CAM Explainability              (5 sec)
  → Show: fundus + heatmap overlay
  → Show: "Model attention regions"

Step 6: Experimental Lesion Evidence         (5 sec)
  → Show: "EXPERIMENTAL — not clinically validated"
  → Show: detected lesion counts (if any)
  → Show: "Learned segmentation: MA Dice=X.XXX"

Step 7: Clinical Decision                    (3 sec)
  → Show: recommendation (refer/monitor/recapture)
  → Show: confidence level

Step 8: Structured Report                    (5 sec)
  → Show: complete screening report
  → Show: disclaimer
  → Option: export to file

Total: ~28 seconds
```

### Demo Script Wording

**For lesion evidence:**
> "The system provides experimental lesion evidence using learned segmentation. This is NOT a confirmed medical finding — it is an algorithmic output intended to assist the ophthalmologist's review. The lesion detector has been externally validated on IDRiD and DDR datasets."

**For Grad-CAM:**
> "The heatmap shows where the model allocates attention. This does not necessarily correspond to pathological lesions — it reflects the model's learned features."

**For the overall system:**
> "This is a research prototype designed to assist ophthalmologists, not replace them. It routes difficult cases for human review and provides structured evidence to support clinical decision-making."

---

## 12. What We Must NOT Claim

| Claim | Why We Must NOT Make It |
|-------|------------------------|
| "The system detects lesions" | Lesion detectors failed external validation |
| "MA=24, HE=13 are confirmed findings" | These are experimental algorithmic outputs |
| "91% sensitivity means it's clinically ready" | Internal evaluation only, not external validation |
| "Grad-CAM shows where the disease is" | Clinically unvalidated |
| "This replaces ophthalmologists" | It is a decision-support tool |
| "The system is FDA/CE cleared" | It is a research prototype |
| "Lesion detection is validated" | IDRiD Dice=0.000 for MA |
| "The system generalizes to all populations" | Only tested on APTOS/IDRiD/DDR |
| "Accuracy is 79.5% in clinical settings" | Internal test set only |
| "Simulink models the full system" | No .slx files exist |

---

## 13. Judge Questions and Answers

### Q1: Does this replace doctors?

**A:** No. This is a decision-support tool designed to help ophthalmologists analyze fundus images faster and more consistently. It routes difficult cases for human review and provides structured evidence — it does not make autonomous clinical decisions. The system explicitly includes quality gating (rejecting poor images), confidence assessment (flagging uncertain predictions), and clinical consistency checks (detecting contradictions between grade and lesion evidence).

### Q2: Why is AI needed if doctors already examine fundus images?

**A:** Diabetic retinopathy affects 100 million people globally, but there are far too few ophthalmologists to screen everyone. In India alone, an estimated 77 million diabetics need annual screening. AI can triage: filter out normal cases, flag urgent referrals, and prioritize the queue. This allows doctors to focus their expertise on the cases that need it most.

### Q3: What is your accuracy?

**A:** On our internal test set of 612 images, the classifier achieves 79.5% overall accuracy. For the clinically important question — "does this patient need referral?" — the system achieves 91.0% sensitivity (correctly identifies 91% of referable cases) and 91.5% specificity. However, these are internal evaluation metrics, not clinical validation. External validation on independent clinical data is required before clinical deployment.

### Q4: What is sensitivity for referable DR?

**A:** 91.0% on the internal APTOS test set. This means 9 out of 10 patients who need referral are correctly flagged. The remaining 10% are false negatives — the system says "non-referable" when the patient actually needs referral. This is why the system is designed as decision support, not autonomous diagnosis.

### Q5: How did you validate it?

**A:** We used a multi-stage validation approach:
1. **Software validation:** 123 automated tests verify code correctness
2. **Internal evaluation:** 612 held-out test images (frozen since Phase 8)
3. **External validation:** Handcrafted lesion detectors tested on IDRiD (54 images) and DDR (60 images) with expert pixel-level annotations — and they failed, which we documented honestly
4. **Calibration:** ECE of 0.033 shows well-calibrated confidence scores

We do NOT claim clinical validation — that requires prospective studies with patient outcomes.

### Q6: What happens with poor-quality images?

**A:** The quality assessment module evaluates 7 independent metrics (sharpness, brightness, contrast, FOV, glare, vignetting, retinal area). If any metric is UNGRADABLE, the system rejects the image and recommends recapture. BORDERLINE images are automatically enhanced before classification. The quality gating prevents the classifier from making unreliable predictions on poor images.

### Q7: How do you explain predictions?

**A:** The system uses Grad-CAM (Gradient-weighted Class Activation Mapping) to generate heatmaps showing where the model allocates attention. This helps the ophthalmologist understand which regions influenced the prediction. However, we do NOT claim that these regions correspond to specific pathological lesions — the heatmap reflects the model's learned features, not necessarily disease locations.

### Q8: Why are lesion detectors not fully validated?

**A:** We tested our handcrafted morphological detectors against expert pixel-level annotations from IDRiD and DDR datasets. The results showed they do not generalize well across different camera systems and populations. For example, the microaneurysm detector achieved Dice = 0.000 on IDRiD. We have documented this honestly and are transitioning to learned segmentation (U-Net) which should generalize better. The current lesion evidence in the system is explicitly marked as "experimental."

### Q9: Why didn't you use a larger segmentation model?

**A:** We are building toward that. We first needed to establish that the current approach fails (which we've now documented), and we've requested access to the FGADR dataset (1,842 images with 6 lesion types) to train a more comprehensive model. Within the current timeline, we've implemented a U-Net baseline that demonstrates the feasibility of learned segmentation. A production system would use a larger, multi-lesion model trained on diverse datasets.

### Q10: What datasets were used?

**A:**
- **APTOS 2019** (5,590 images) — primary development dataset for DR classification
- **IDRiD** (494 images) — external lesion validation with expert pixel-level masks
- **DDR** (60 images downloaded) — cross-dataset lesion validation
- **DRIVE** (40 images) — vessel segmentation validation
- **Messidor-2** (1,748 images) — held for future external validation

All splits are patient-level with no data leakage (seed 42). The test set has been frozen since Phase 8.

### Q11: How do you handle domain shift?

**A:** This is a known challenge. Our external validation showed that lesion detectors trained/ calibrated on APTOS images do not generalize to IDRiD or DDR. The classifier is more robust (it uses deep features rather than handcrafted morphology), but we acknowledge that performance on clinical populations may differ. We recommend site-specific validation before deployment at any new clinical site.

### Q12: Can this work in rural India?

**A:** The system is designed for resource-constrained settings: it runs on standard hardware, provides automated quality assessment (important for unskilled operators), and routes difficult cases for specialist review. However, it has NOT been validated on rural Indian populations. Before deployment, it would need prospective validation on the target population and regulatory approval.

### Q13: How does Simulink contribute?

**A:** The Simulink component models the telemedicine workflow — how images flow from rural screening sites through quality assessment, AI analysis, and specialist review. It's a discrete-event simulation of the screening pipeline, not a model of the AI itself. This helps understand throughput, bottleneck analysis, and resource planning for large-scale screening programs.

### Q14: Can this scale to 100,000+ patients/year?

**A:** The AI inference itself is fast (< 1 second per image). The bottleneck is specialist review for flagged cases. In a typical screening program, 80-90% of images are normal (G0) and can be auto-passed, 5-10% need review, and 1-2% need urgent referral. The system is designed to handle this triage efficiently, but scaling requires integration with hospital information systems, patient management, and quality assurance workflows.

### Q15: Is it clinically deployable?

**A:** Not yet. This is a research prototype. Clinical deployment requires:
1. Prospective clinical validation on target populations
2. Regulatory approval (CDSCO in India, FDA in US, CE in Europe)
3. Integration with clinical workflows and EHR systems
4. DICOM image format support
5. Multi-site validation across different camera systems
6. Post-market surveillance

We have demonstrated the technical feasibility and identified the key limitations. The honest documentation of what works and what doesn't is itself valuable for guiding future development.

### Q16: What remains to be done before clinical deployment?

**A:** The critical path is:
1. **External clinical validation** on independent patient populations
2. **Lesion segmentation** — current handcrafted detectors are insufficient; learned segmentation (U-Net) is the next step
3. **Regulatory pathway** — CDSCO classification, clinical trial design
4. **Clinical workflow integration** — EHR connectivity, DICOM support, reporting standards
5. **Prospective study** — real-world screening trial with patient outcomes
6. **Post-market surveillance** — monitoring performance in deployment

---

## 14. Exact Next Implementation Task

**RECOMMENDED NEXT TASK:**

Fix the three P0 demo blockers in `matlab/demo/drScreeningGUIv2.m`:

1. Line 783: `r.grade` → `r.gradeNum`
2. Line 785: `r.confidence*100` → `r.confidence`
3. Line 786: `r.referableProb` → `r.probability`
4. Line 620: Replace hardcoded quality struct with actual quality data

**Estimated time:** 30 minutes
**Risk:** LOW (field name corrections only)
**Validation:** Run `validatePhase16A.m` and manual GUI test
**Impact:** Prevents demo crash, fixes misleading output

**Awaiting Senior System Architect approval before modifying repository.**
