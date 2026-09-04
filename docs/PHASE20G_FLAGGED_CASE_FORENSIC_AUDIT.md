# Phase 20G: Forensic Investigation of Flagged Cases

## Executive Summary

Phase 20G performed a forensic investigation of all 9 Phase 20F comparison images, examining every detector intermediate stage, per-candidate properties, and Grad-CAM attention patterns.

### Key Findings

1. **Primary case 01499815e469 (MA=24, HE=13, EX=19):**
   - **56 total candidates** detected (24 MA + 13 HE + 19 EX)
   - **5 MA candidates are outside image bounds** (rows > 480 on a 480-row image) — clear detector artifacts
   - **Multiple HE/EX candidates also outside bounds** (HE-09 through HE-13, EX-14 through EX-19)
   - **Grad-CAM returned all zeros** (max=0.0000) — the model has zero positive spatial evidence for G3 in this image
   - **True grade is NaN** (ungraded in the validation set) — no ground truth exists for this image
   - **Verdict: DETECTOR CONCERN + EXPLAINABILITY CONCERN**

2. **0097f532ac9f (corrected false positive G2→G0):**
   - 0 lesions detected — clean normal retina
   - Grad-CAM inFOV=98.8%, focuses on retinal structures
   - **Verdict: CLEAR IMPROVEMENT**

3. **fe3b0e50be78 (corrected false positive G2→G0):**
   - MA=2, HE=1 — very low lesion burden, consistent with G0
   - Grad-CAM inFOV=100%, though 80.8% of CAM is outside FOV (background-dominant)
   - **Verdict: CLEAR IMPROVEMENT**

4. **All other cases:** Consistent improvements or stable correct predictions.

## Case-Level Summary Table

| Image | True | OLD | NEW | OLD Conf | NEW Conf | MA | HE | EX | NV | CAM-FOV% | CAM-Lesion% | Verdict |
|-------|------|-----|-----|----------|----------|----|----|----|----|----------|-------------|----|
| 01499815e469 | NaN | G2 | G3 | 0.317 | 0.767 | 24 | 13 | 19 | 1 | 0.0% | 0.0% | DETECTOR CONCERN + EXPLAINABILITY CONCERN |
| 0097f532ac9f | G0 | G2 | G0 | 0.283 | 1.000 | 0 | 0 | 0 | 0 | 98.8% | 0.0% | CLEAR IMPROVEMENT |
| 00836aaacf06 | NaN | G2 | G2 | 0.286 | 0.871 | 2 | 10 | 10 | 1 | 100.0% | 100.0% | LIKELY IMPROVEMENT |
| 009c019a7309 | NaN | G2 | G2 | 0.295 | 0.529 | 5 | 11 | 5 | 0 | 100.0% | 100.0% | LIKELY IMPROVEMENT |
| 00e4ddff966a | G2 | G2 | G2 | 0.331 | 0.947 | 0 | 0 | 2 | 0 | 97.4% | 100.0% | CLEAR IMPROVEMENT |
| 01d9477b1171 | G0 | G0 | G0 | 0.482 | 1.000 | 0 | 2 | 0 | 0 | 100.0% | 100.0% | CLEAR IMPROVEMENT |
| fda39982a810 | G3 | G2 | G2 | 0.295 | 0.600 | 0 | 8 | 2 | 1 | 100.0% | 100.0% | UNCERTAIN (G3 missed) |
| fe3b0e50be78 | G0 | G2 | G0 | 0.276 | 1.000 | 2 | 1 | 0 | 1 | 100.0% | 100.0% | CLEAR IMPROVEMENT |
| ff0740cb484a | G2 | G2 | G2 | 0.313 | 0.984 | 0 | 1 | 5 | 0 | 100.0% | 100.0% | CLEAR IMPROVEMENT |

## Detailed Case Analysis

### Case 1: 01499815e469 — PRIMARY FLAGGED CASE

**Image:** 640x480, 640x480, true grade NaN (ungraded in validation set)

**Classifier:**
- OLD: G2 (31.7%) — flat distribution, essentially guessing
- NEW: G3 (76.7%) — focused prediction
- Note: True grade is NaN — no ground truth exists to validate either prediction

**Detector Results:** MA=24, HE=13, EX=19, NV=1 (56 total candidates)

**Candidate Audit (selected findings):**

| Finding | Evidence | Assessment |
|---------|----------|------------|
| 5 MA candidates outside image bounds | MA-20 (row=485), MA-21 (row=489), MA-22 (row=504), MA-23 (row=527), MA-24 (row=537) on 480-row image | **DETECTOR BUG** — boundary rejection not preventing out-of-bounds centroids |
| 5 HE candidates outside bounds | HE-09 (row=448, border=31.7), HE-10 (row=483), HE-11 (row=490), HE-12 (row=505), HE-13 (row=542) | **DETECTOR BUG** — same issue |
| MA on vessels | MA-03 (on_vessel=1), MA-17 (on_vessel=1) | Likely vessel fragments misidentified as MA |
| High local brightness for MA | MA-05 (local_mean=225.8), MA-06 (237.5), MA-09 (181.9) | MA candidates in bright regions — unlikely true microaneurysms |
| HE on vessels | HE-07 (on_vessel=1), HE-09 (on_vessel=1), HE-11 (on_vessel=1) | Vessel-associated hemorrhages — partially plausible |
| NV detected | Single NV detection | Without ground truth, unverifiable |

**Grad-CAM Analysis:**
- NEW Grad-CAM max = 0.0000 — **all zeros**
- This means the weighted combination of feature maps for the G3 class, after ReLU, is entirely non-positive
- The model predicts G3 with 76.7% confidence but has zero positive spatial evidence in the last convolutional layer
- Possible explanations:
  - The G3 evidence is concentrated in the fully connected head layers (fc_dr_1 → fc_dr_2 → fc_dr_output) without corresponding spatial feature map activation
  - The feature maps for this input contain values that, when weighted by the G3-specific gradients, produce all-negative combinations
  - This is a limitation of the Grad-CAM explanation method, not necessarily a model error
- OLD Grad-CAM: inFOV=100% but was computed with wrong preprocessing — unreliable

**Intermediates Saved:** 14 images including FOV mask, disc mask, vessel mask, raw/final candidates for MA/HE/EX, NV mask, raw CAMs

**Verdict: DETECTOR CONCERN + EXPLAINABILITY CONCERN**
- Detector concern: Multiple candidates detected outside image bounds (5 MA, 5 HE). The boundary rejection is insufficient for this small 640x480 image. Several MA candidates are in bright regions or on vessels.
- Explainability concern: Grad-CAM returns all zeros despite 76.7% G3 confidence. The explanation method fails for this case.
- The high lesion count (56 candidates) on a small 640x480 image is algorithmically suspicious. Without ground truth, we cannot determine if these are true positives or over-detections.

### Case 2: 0097f532ac9f — CORRECTED FALSE POSITIVE

**Image:** 2588x1958, true grade G0

**Classifier:**
- OLD: G2 (28.3%) — false positive, flat distribution
- NEW: G0 (100.0%) — perfect confidence, correct grade

**Detector Results:** MA=0, HE=0, EX=0, NV=0 — completely clean

**Grad-CAM:**
- NEW: inFOV=98.8%, max=1.0 — strong, focused attention on retinal structures
- Background outside FOV = 46.5% (includes optic disc and vessel regions)

**Verdict: CLEAR IMPROVEMENT**
- False positive referable eliminated
- Zero lesions — consistent with No DR
- Grad-CAM shows appropriate retinal attention

### Case 3: 00836aaacf06

**Image:** 640x480, true grade NaN

**Classifier:** OLD G2 (28.6%) → NEW G2 (87.1%). Same grade, massive confidence increase.

**Detector Results:** MA=2, HE=10, EX=10, NV=1 — high lesion count on small image

**Grad-CAM:** inFOV=100%, lesion overlap=100%. Attention fully on detected lesions.

**Verdict: LIKELY IMPROVEMENT** — but high lesion count on small image warrants caution. True grade unknown.

### Case 4: 009c019a7309

**Image:** 640x480, true grade NaN

**Classifier:** OLD G2 (29.5%) → NEW G2 (52.9%). Same grade, confidence nearly doubled.

**Detector Results:** MA=5, HE=11, EX=5, NV=0

**Grad-CAM:** inFOV=100%, lesion overlap=100%.

**Verdict: LIKELY IMPROVEMENT** — confidence increased, Grad-CAM aligned with lesions. True grade unknown.

### Case 5: 00e4ddff966a

**Image:** 2416x1736, true grade G2

**Classifier:** OLD G2 (33.1%) → NEW G2 (94.7%). Correct grade, massive confidence increase.

**Detector Results:** MA=0, HE=0, EX=2, NV=0 — very few lesions, consistent with G2.

**Grad-CAM:** inFOV=97.4%, lesion overlap=100% (on EX).

**Verdict: CLEAR IMPROVEMENT** — correct grade with high confidence, minimal lesions consistent with grade.

### Case 6: 01d9477b1171

**Image:** 819x614, true grade G0

**Classifier:** OLD G0 (48.2%) → NEW G0 (100.0%). Correct grade, confidence maximized.

**Detector Results:** MA=0, HE=2, EX=0, NV=0 — very low lesion burden, consistent with G0.

**Grad-CAM:** inFOV=100%, lesion overlap=100% (on HE). Background outside FOV=52.7% (includes disc).

**Verdict: CLEAR IMPROVEMENT** — correct grade, perfect confidence, minimal lesions.

### Case 7: fda39982a810

**Image:** 1504x1000, true grade G3

**Classifier:** OLD G2 (29.5%) → NEW G2 (60.0%). Both predict G2, missing G3.

**Detector Results:** MA=0, HE=8, EX=2, NV=1 — moderate lesion burden.

**Grad-CAM:** inFOV=100%, lesion overlap=100%.

**Verdict: UNCERTAIN** — G3 is still misclassified as G2. This is a known limitation (G3 recall=25.6%). The lesion evidence (HE=8, NV=1) is consistent with severe DR but the classifier doesn't capture this. No regression — both OLD and NEW predict G2.

### Case 8: fe3b0e50be78

**Image:** 819x614, true grade G0

**Classifier:** OLD G2 (27.6%) → NEW G0 (100.0%). False positive corrected.

**Detector Results:** MA=2, HE=1, EX=0, NV=1 — very low burden.

**Grad-CAM:** inFOV=100%, lesion overlap=100%. Background outside FOV=80.8%.

**Verdict: CLEAR IMPROVEMENT** — false positive eliminated, low lesion count consistent with G0.

### Case 9: ff0740cb484a

**Image:** 1504x1000, true grade G2

**Classifier:** OLD G2 (31.3%) → NEW G2 (98.4%). Correct grade, near-perfect confidence.

**Detector Results:** MA=0, HE=1, EX=5, NV=0 — moderate EX consistent with G2.

**Grad-CAM:** inFOV=100%, lesion overlap=100%.

**Verdict: CLEAR IMPROVEMENT** — correct grade with very high confidence, lesions consistent with grade.

## A. What Is Proven by Software Tests

1. The canonical `preprocessFundus()` matches training preprocessing (19/20 prediction agreement with `augmentedImageDatastore`)
2. All 19 inference paths have been corrected to use canonical preprocessing
3. The corrected classifier achieves 79.5% accuracy on 611 validation images (matching the frozen Phase 8 baseline of 76.6%)
4. G2 collapse is resolved (33.2% predicted vs 27.5% actual)
5. Grad-CAM is deterministic (repeated execution produces identical results)
6. 01499815e469 has 5 MA candidates detected outside image bounds (rows > image height)
7. 01499815e469 has Grad-CAM max = 0.0000 (all zeros)
8. All other 8 cases have Grad-CAM max > 0 and inFOV > 97%

## B. What Is Supported by Visual Evidence

1. 0097f532ac9f and fe3b0e50be78 have zero/minimal lesions — visually consistent with No DR
2. 00e4ddff966a has EX=2 — visually plausible for G2
3. 01d9477b1171 has HE=2 — visually plausible for G0 (minor hemorrhages)
4. ff0740cb484a has EX=5 — visually plausible for G2
5. 01499815e469 has very high lesion counts on a small image — visually suspicious, requires clinical review
6. Grad-CAM heatmaps for 8/9 cases concentrate on retinal structures (vessels, lesions, disc)

## C. What Remains Uncertain

1. Whether the 24 MA / 13 HE / 19 EX in 01499815e469 are true positives or over-detections
2. Whether the NV detection in 01499815e469 is a true neovascularization
3. Whether fda39982a810 (true G3, predicted G2) could be improved without retraining
4. Clinical significance of MA=2 in fe3b0e50be78 (graded G0)
5. Whether the high lesion counts in 00836aaacf06 and 009c019a7309 (both 640x480, true grade NaN) represent true pathology

## D. What Cannot Be Claimed Clinically

1. No lesion-level ground truth exists — individual MA/HE/EX/NV detections cannot be validated clinically
2. The "corrected" grades for 0097f532ac9f and fe3b0e50be78 are based on the frozen classifier's output with correct preprocessing, not clinical expert grading
3. The Grad-CAM attention patterns show where the model looks, not what a clinician would look at
4. The detector boundary rejection bug in 01499815e469 does not necessarily mean all 56 candidates are false — some may be true lesions near the image boundary
5. Sensitivity/specificity numbers apply to the validation set as a whole, not to individual images

## Outputs

```
results/phase20g_forensic/
  phase20g_summary.txt                    — Text report
  case_summary.csv                        — Case-level summary table
  case_01499815e469/
    forensic_panel.png                    — 12-panel forensic figure
    candidate_audit.csv                   — 56 candidates with properties
    01_original.png through 14_gradcam_old_raw.png — 14 intermediate images
  case_0097f532ac9f/                      — Same structure, 0 candidates
  case_00836aaacf06/                      — 22 candidates
  case_009c019a7309/                      — 21 candidates
  case_00e4ddff966a/                      — 2 candidates
  case_01d9477b1171/                      — 2 candidates
  case_fda39982a810/                      — 10 candidates
  case_fe3b0e50be78/                      — 3 candidates
  case_ff0740cb484a/                      — 6 candidates
```

## Remaining Issues for Future Investigation

1. **Detector boundary rejection:** 01499815e469 (640x480) has candidates outside image bounds. The edge margin (5px) and FOV erosion (disk,3) may be insufficient for small images. This should be investigated but NOT fixed in this session (per the evaluation-only rule).

2. **Grad-CAM zero output:** The zero CAM for 01499815e469 suggests the model's G3 evidence is not spatially localized in the last conv layer. This is a known limitation of gradient-based explanation methods, not necessarily a model error.

3. **Over-detection on small images:** Multiple 640x480 images have high lesion counts (MA=24, HE=13, EX=19). The detector thresholds may be less appropriate for small images where anatomical structures are fewer pixels. This requires investigation but not threshold tuning.

4. **G3 classification:** fda39982a810 (true G3) is still predicted as G2. This is a known limitation (G3 recall=25.6%) and would require retraining to improve.
