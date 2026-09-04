# Phase 20A — Lesion Detection & Explainability Forensic Audit

**Date**: 2026-09-02
**Frozen Model Commit**: `cc7bed8`
**Frozen Baseline**: 87.2% sensitivity, 92.7% specificity, 0.704 AUC, 76.6% accuracy

---

## 1. Executive Summary

This audit inspects every line of code in the lesion detection pipeline, Grad-CAM implementation, clinical logic, and GUI visualization. It identifies **16 defects** across 4 severity levels. The core CNN classifier is **NOT** the primary problem. The supporting pipeline — lesion detectors, explainability, and clinical integration — has fundamental algorithmic errors that produce clinically unreliable outputs.

**Key findings:**
- Microaneurysm detector: wrong polarity + double-strict threshold = near-zero detections
- Neovascularization detector: inverted morphological operation = huge false-positive masks
- Hemorrhage detector: no vessel/disc masking = false positives at anatomical structures
- Grad-CAM in production GUI: **random noise** (placeholder never replaced)
- Formal Grad-CAM: **100% non-functional** (computation graph broken)
- Clinical consistency check: warning-only, never influences clinical decisions
- Export function: references non-existent fields (would crash)

---

## 2. Complete Pipeline Trace with Code Evidence

### 2.1 Image Loading
- **GUI**: `drScreeningGUIv2.m:295-318` — `imread(fullPath)` → `state.currentImage` (uint8 RGB)
- **API**: `runDRScreening.m:77-85` — `imread` + RGB/min-size validation

### 2.2 Quality Assessment
- **GUI display**: `drScreeningGUIv2.m:320-373` — 3-metric additive (brightness [40,220], contrast ≥20, blurVar ≥100)
- **GUI screening**: `drScreeningGUIv2.m:392-422` — same 3-metric (duplicated code)
- **API**: `runDRScreening.m:92-114` — 2-metric multiplicative (brightness/contrast only, no sharpness)

### 2.3 Preprocessing
- **GUI**: `drScreeningGUIv2.m:425-431` — `imresize(img, [224 224], 'bicubic')` + ImageNet normalization
- **API**: `runDRScreening.m:135-141` — identical preprocessing

### 2.4 Model Inference
- **GUI**: `drScreeningGUIv2.m:434` — `[pred, scores] = classify(state.trainedNet, n)`
- **API**: `runDRScreening.m:148` — identical

### 2.5 Grade Mapping
- **GUI**: `drScreeningGUIv2.m:435` — `gradeNum = double(pred) - 1`
- **Class order**: `categorical(0:4)` = {0,1,2,3,4} — **VERIFIED CORRECT**
- **Scores**: `scores(1)=P(G0), scores(2)=P(G1), ..., scores(5)=P(G4)` — **VERIFIED CORRECT**

### 2.6 Lesion Evidence
- **GUI**: `drScreeningGUIv2.m:438` — `evidence = extractLesionEvidence(state.currentImage)` (runs on ORIGINAL image)
- **extractLesionEvidence.m:39-42** — calls all 4 detectors with `img` only

### 2.7 Clinical Logic
- **GUI**: `drScreeningGUIv2.m:441` — `applyClinicalLogic(gradeNum, scores, evidence, quality)`
- **Quality gating**: `applyClinicalLogic.m:24` — `if strcmp(quality.status, 'POOR') → UNGRADABLE`
- **Referable**: `applyClinicalLogic.m:47` — `result.referable = gradeNum >= 2`
- **Consistency**: `applyClinicalLogic.m:71` — warning only, never modifies grade

### 2.8 Grad-CAM
- **GUI report**: `drScreeningGUIv2.m:632` — `gradcam = struct('cam', rand(224, 224))` — **RANDOM NOISE**
- **v1 GUI heatmap**: `gradcamSimple.m` — FC weight projection (only functional implementation)

### 2.9 Report + Export
- **Report**: `generateClinicalReport.m` — receives random Grad-CAM, claims "Attention map generated"
- **Export**: `drScreeningGUIv2.m:694` — `r.grade` (doesn't exist, should be `r.gradeNum`)
- **Export**: `drScreeningGUIv2.m:697` — `r.referableProb` (doesn't exist in result struct)

---

## 3. Complete Defect List

### CATEGORY A: BUGS (Correctness Errors)

---

#### DEFECT A1: MA Detector — Top-Hat Polarity Inversion
- **File**: `detectMicroaneurysms.m:59-60`
- **Code**: `tophatImg = imtophat(redChannel, strel('disk', 3));`
- **Problem**: `imtophat(f, se)` computes `f - opening(f)`, which extracts **bright** features from the local background. Microaneurysms are **dark-red** spots in the red channel (they absorb red light). The top-hat is looking for the wrong intensity polarity.
- **Clinical reason**: MAs appear as dark-red, round lesions (documented in line 6 of the file itself: "Microaneurysms appear as small, dark-red, round lesions"). But the algorithm enhances bright spots.
- **Example failure**: A dark MA on a bright background produces a NEGATIVE top-hat response (background is brighter than the MA). The threshold at line 64 selects positive responses, which correspond to bright artifacts, not dark MAs.
- **Proposed correction**: Use `imtophat(max(redChannel) - redChannel, se)` (invert first), or use `imclose(redChannel, se) - redChannel` (closing highlights dark features).
- **Expected effect**: MA count will increase from ~0 to clinically plausible numbers on grade 2+ images.
- **Risk**: May increase false positives if bright artifacts are present. Must validate on images with known MAs.

---

#### DEFECT A2: MA Detector — Double-Strict Threshold
- **File**: `detectMicroaneurysms.m:63-64`
- **Code**: `threshold = graythresh(tophatImg); candidates = tophatImg > threshold * 2.0;`
- **Problem**: `graythresh` computes Otsu's optimal threshold. Multiplying by 2.0 raises the threshold to potentially exceed the maximum top-hat response value, producing zero candidates. Even without the polarity issue (A1), the 2x multiplier is mathematically unjustified — Otsu already finds the optimal split.
- **Clinical reason**: MAs produce subtle top-hat responses. A 2x Otsu threshold eliminates all but the most extreme bright spots (which are likely artifacts, not MAs).
- **Example failure**: If `graythresh` returns 0.02 (typical for subtle top-hat), the threshold becomes 0.04. If max top-hat is 0.03, zero candidates survive.
- **Proposed correction**: Use `threshold` directly (remove `* 2.0`), or use a fractional multiplier like `0.5` for sensitivity.
- **Expected effect**: More candidates will pass initial thresholding.
- **Risk**: May increase false positives. Must combine with region filtering to maintain specificity.

---

#### DEFECT A3: MA Detector — Local Contrast Filter Contradicts Top-Hat Polarity
- **File**: `detectMicroaneurysms.m:128-133`
- **Code**: `if candidateVal > localMean + localStd; localContrastMask(i) = false;`
- **Problem**: The comment on line 128-129 says "Candidate should be darker than local background (in red channel, MA appears as dark spot)". This filter rejects candidates **brighter** than local mean+std. But the top-hat at line 60 selects **bright** features. These two operations work at cross-purposes: the top-hat finds bright spots, then this filter removes the bright ones.
- **Clinical reason**: The filter correctly identifies that MAs are dark. But the top-hat selects bright spots. The result: top-hat finds bright spots → local contrast filter removes bright spots → zero detections.
- **Example failure**: Any candidate that passes the top-hat (bright) will be rejected by the local contrast check (rejects bright).
- **Proposed correction**: After fixing polarity (A1), change the filter to `candidateVal < localMean - localStd` (reject candidates that are too bright, i.e., not dark enough to be MAs).
- **Expected effect**: After A1+A2+A3 fixes, the three operations will be consistent: enhance dark spots → threshold → keep dark spots.
- **Risk**: Low — this aligns the filter with the stated intent.

---

#### DEFECT A4: NV Detector — Inverted Morphological Operation
- **File**: `detectNeovascularization.m:56`
- **Code**: `response = imopen(greenChannel, se);`
- **Problem**: `imopen(greenChannel, strel('line',7,angle))` removes narrow dark structures (vessels) and retains the bright background. The `fineVesselResponse` (line 57: `max(fineVesselResponse, response)`) is a vessel-free background image. Thresholding this at line 62 selects bright background pixels, not vessels.
- **Clinical reason**: NV consists of fine, abnormal new vessels. These are dark in the green channel (like normal vessels). The matched filter should ENHANCE dark vessels, not remove them.
- **Example failure**: The background image has high values everywhere. Thresholding produces a mask covering most of the retina. Block density analysis (lines 77-87) finds "high density" everywhere. The NV mask covers 50-90% of the retina.
- **Proposed correction**: Use `imtophat(greenChannel, se)` (= greenChannel - imopen(greenChannel, se)) to enhance dark vessels, OR negate the image first: `imopen(max(greenChannel) - greenChannel, se)`.
- **Expected effect**: NV mask will be localized to actual fine-vessel regions, not cover the entire retina.
- **Risk**: May miss NV if thresholds need retuning after polarity fix. Must validate on known PDR images.

---

#### DEFECT A5: NV Detector — Block Upscaling Creates Huge Regions
- **File**: `detectNeovascularization.m:140`
- **Code**: `evidenceMask = imresize(highDensityRegions, [rows, cols]) > 0.5;`
- **Problem**: `highDensityRegions` is a block-level binary map (blockSize=48, lines 71-87). A single "true" block (48x48 pixels) gets upscaled to a 48x48 rectangle in the full-resolution mask. Multiple adjacent true blocks merge into a huge region. Combined with A4 (inverted polarity), most blocks are "true", producing a mask covering most of the retina.
- **Clinical reason**: NV typically appears as localized fronds or networks of fine vessels, not diffuse rectangular regions. The block-level analysis loses spatial precision.
- **Example failure**: A 48x48 block classified as "NV" becomes a solid rectangle covering that retinal region, even if only a few NV vessels exist within it.
- **Proposed correction**: After fixing A4, apply morphological cleanup (opening to remove isolated blocks, closing to merge adjacent ones) and size filtering on the upscaled mask.
- **Expected effect**: NV regions will be more spatially precise and clinically plausible.
- **Risk**: Low — this is a refinement after the fundamental polarity fix.

---

#### DEFECT A6: Grad-CAM in Production GUI is Random Noise
- **File**: `drScreeningGUIv2.m:632`
- **Code**: `gradcam = struct('cam', rand(224, 224));`
- **Problem**: The production GUI generates a random 224x224 matrix and passes it as the Grad-CAM heatmap. The comment says `% Grad-CAM (placeholder)` — this was never replaced with a real implementation.
- **Clinical reason**: Clinicians viewing the report see "Attention map generated" but the underlying data is random. This is misleading and undermines trust in the system.
- **Example failure**: Every clinical report shows a different random heatmap that has no relationship to the image or prediction.
- **Proposed correction**: Call `gradcamSimple(state.trainedNet, imgNorm)` and pass the real CAM to the report.
- **Expected effect**: Heatmaps will correspond to actual model attention.
- **Risk**: Low — `gradcamSimple` is already implemented and used in v1 GUI.

---

#### DEFECT A7: Formal Grad-CAM is 100% Non-Functional
- **File**: `gradcam.m:97-108, 110-132`
- **Code**: `forwardWithActivations` uses `extractdata(dlImg)` which breaks the dlarray computation graph. `dlgradient(targetScore, acts)` cannot trace through `extractdata`. Fallback differentiates a constant scalar → all-zero gradients.
- **Problem**: The `gradcam.m` function has never produced a meaningful result. Its `forwardWithActivations` helper severs the automatic differentiation tape. The fallback computes `dlgradient(constant, dlImg)` which is always zero.
- **Clinical reason**: If anyone calls `gradcam()` instead of `gradcamSimple()`, they get a blank/zero heatmap.
- **Example failure**: Any call to `gradcam.m` produces a uniformly zero or random heatmap.
- **Proposed correction**: Rewrite using proper `dlarray` forward pass without `extractdata`, or deprecate `gradcam.m` and standardize on `gradcamSimple`.
- **Expected effect**: Formal Grad-CAM will produce meaningful heatmaps (if rewritten).
- **Risk**: Medium — requires careful implementation of automatic differentiation.

---

#### DEFECT A8: Grad-CAM Missing ReLU
- **File**: `gradcamSimple.m:43-49`
- **Code**: `cam = (cam - camMin) / (camMax - camMin);` — no `max(cam, 0)` before normalization
- **Problem**: True Grad-CAM applies ReLU (`max(cam, 0)`) before normalization to remove negative class evidence. Without ReLU, negative activations from irrelevant classes contaminate the heatmap.
- **Clinical reason**: Negative activations highlight regions that actively CONTRADICT the predicted class. Displaying these as "attention" is misleading.
- **Example failure**: A region with strong negative activation for G4 (PDR) appears as a hot spot in the G0 (No DR) heatmap, suggesting the model "looked" at that region for No DR, when it actually found evidence against No DR.
- **Proposed correction**: Add `cam = max(cam, 0);` before line 43.
- **Expected effect**: Heatmaps will only show positive class evidence.
- **Risk**: Low — standard Grad-CAM practice.

---

### CATEGORY B: SCIENTIFICALLY WEAK HEURISTICS

---

#### DEFECT B1: MA Detector — Vessel Mask Threshold is Hard-Coded
- **File**: `detectMicroaneurysms.m:177`
- **Code**: `vesselMask = greenChannel < 0.4;`
- **Problem**: The threshold 0.4 is hard-coded and does not adapt to image illumination. A dark image may have all pixels below 0.4 (entire image masked), while a bright image may have no pixels below 0.4 (no vessels masked).
- **Clinical reason**: Vessel darkness varies with camera exposure, gain, and illumination. A fixed threshold cannot handle the range of fundus image qualities.
- **Example failure**: On a dark fundus image, the entire image is classified as "vessels" and all candidates are removed.
- **Proposed correction**: Use adaptive thresholding (e.g., `adaptthresh` on green channel) or percentile-based threshold (e.g., `prctile(greenChannel, 10)`).
- **Expected effect**: Vessel masking will be more robust to illumination variations.
- **Risk**: Medium — adaptive thresholds may be less predictable.

---

#### DEFECT B2: Optic Disc Detection Uses Fixed Brightness Threshold
- **File**: `detectMicroaneurysms.m:202`, `detectExudates.m:160`, `detectNeovascularization.m:178`
- **Code**: `brightThresh = gray > 0.7` (MA/EX), `gray > 0.65` (NV)
- **Problem**: The optic disc brightness threshold is hard-coded. On dark images, the disc may be below 0.7 (not detected). On bright images, non-disc bright regions may exceed 0.7 (false disc detection).
- **Clinical reason**: The optic disc is the brightest large circular region, but its absolute brightness varies with illumination. A fixed threshold cannot handle this.
- **Example failure**: On a dark image, the disc is below 0.7 → no disc detected → fallback places disc at image center with fixed radius → incorrect masking of foveal region.
- **Proposed correction**: Use relative brightness (e.g., top 5% of bright pixels) or circular Hough transform for disc detection.
- **Expected effect**: Disc detection will be more robust to illumination variations.
- **Risk**: Medium — circular Hough transform is more complex but more reliable.

---

#### DEFECT B3: Optic Disc Fallback Places Disc at Image Center
- **File**: `detectMicroaneurysms.m:222-226`, `detectExudates.m:186-190`, `detectNeovascularization.m:202-207`
- **Code**: `centerR = round(rows / 2); centerC = round(cols / 2); discRadius = round(min(rows, cols) / 8);`
- **Problem**: When disc detection fails (no bright region found), the fallback assumes the disc is at the image center. In many fundus images, the disc is NOT at the center (it's typically nasal to center). This incorrectly masks the foveal region.
- **Clinical reason**: The fovea (center of vision) is typically at the image center in macula-centered fundus photos. Masking the center removes the most clinically important region.
- **Example failure**: A macula-centered image with no detected disc → fallback masks the fovea → true macular exudates are removed from detection.
- **Proposed correction**: If disc detection fails, skip disc masking entirely (accept false positives near disc rather than risk missing macular lesions). Or use a smaller fallback radius.
- **Expected effect**: Macular lesions will not be incorrectly masked.
- **Risk**: Low — skipping disc masking when detection fails is safer than incorrect masking.

---

#### DEFECT B4: HE Detector — No Vessel or Disc Masking
- **File**: `detectHemorrhages.m` — entire file
- **Problem**: The hemorrhage detector does not exclude vessels or the optic disc. Hemorrhages near or overlapping with vessels can produce false positives. Hemorrhages near the disc can be confused with disc margins.
- **Clinical reason**: Hemorrhages are clinically distinct from vessels (different shape, color, location). But the HSV color segmentation (`hue < 0.1 | hue > 0.9, val < 0.4, sat > 0.2`) can match vessel segments that happen to be dark-red.
- **Example failure**: A large vessel segment with dark-red coloration passes HSV thresholds → detected as "hemorrhage".
- **Proposed correction**: Add vessel masking (similar to MA detector) and disc masking before region filtering.
- **Expected effect**: False positives at vessels and disc will decrease.
- **Risk**: Low — standard practice in retinal lesion detection.

---

#### DEFECT B5: HE Detector — No Boundary Rejection
- **File**: `detectHemorrhages.m` — entire file
- **Problem**: Unlike the MA detector (which has 5-pixel boundary rejection at lines 71-75), the HE detector has no boundary rejection. Candidates at the image edge may be artifacts from image cropping or illumination fall-off.
- **Clinical reason**: Fundus images often have dark edges due to limited field of view. These dark edges can match HSV hemorrhage criteria.
- **Example failure**: Dark pixels at the image edge match `val < 0.4` and `hue < 0.1` → detected as "hemorrhage".
- **Proposed correction**: Add boundary rejection (5-10 pixel margin).
- **Expected effect**: Edge artifacts will be rejected.
- **Risk**: Low — standard practice.

---

#### DEFECT B6: EX Detector — Eccentricity Threshold Too Lenient
- **File**: `detectExudates.m:115`
- **Code**: `eccMask = ecc < 0.95;`
- **Problem**: An eccentricity of 0.95 corresponds to a highly elongated ellipse (aspect ratio ~3:1). Exudates are typically round or oval (eccentricity < 0.8). A threshold of 0.95 allows nearly any shape, including vessel segments.
- **Clinical reason**: Hard exudates are typically round or oval deposits. Elongated bright structures are more likely vessel segments or image artifacts.
- **Example failure**: A bright vessel segment with eccentricity 0.9 passes the filter → detected as "exudate".
- **Proposed correction**: Reduce threshold to 0.8-0.85 (consistent with MA detector's 0.7).
- **Expected effect**: False positives from elongated structures will decrease.
- **Risk**: Low — may reject some genuine elongated exudate clusters.

---

#### DEFECT B7: NV Detector — Density Threshold May Be Trivially Satisfied
- **File**: `detectNeovascularization.m:95-98`
- **Code**: `if madDensity > 0; thresholdDensity = medianDensity + 3 * madDensity; else; thresholdDensity = medianDensity + 0.1; end`
- **Problem**: When `madDensity == 0` (all blocks have identical density), the fallback threshold is `medianDensity + 0.1`. If `medianDensity` is high (e.g., 0.8 due to A4's inverted polarity), the threshold is 0.9, and blocks with density > 0.9 are marked as "high density". But since most blocks have density near 1.0, many will pass.
- **Clinical reason**: The fallback threshold assumes low density is normal. But with inverted polarity, high density is the norm.
- **Example failure**: All blocks have density ~0.95. `madDensity = 0`. Threshold = 0.9 + 0.1 = 1.0. Blocks with density > 1.0 = none. But if any block has density 1.0 (which is common), it passes.
- **Proposed correction**: After fixing A4, re-evaluate whether this fallback is needed.
- **Expected effect**: After A4 fix, density values will be meaningful.
- **Risk**: Low — depends on A4 fix.

---

### CATEGORY C: GENUINE LIMITATIONS

---

#### DEFECT C1: Class Weights Never Applied to Training
- **File**: `trainTransferDRClassifier.m:1` (accepts `classWeights`), never uses it
- **Problem**: Class weights [1.0, 3.14, 1.40, 4.53, 3.656] are computed but never passed to the loss function. The model trains with unweighted cross-entropy, resulting in poor sensitivity for rare classes (G3=17.9%, G4=38.0%).
- **Clinical reason**: Grade 3 (Severe NPDR) and Grade 4 (PDR) are the most clinically urgent but least represented. Without weighting, the model biases toward the majority class (G0).
- **Impact**: G3 sensitivity 17.9%, G4 sensitivity 38.0% — these are the classes that matter most clinically.
- **Note**: Fixing this requires retraining, which is outside the current frozen model scope. Documented for future work.

---

#### DEFECT C2: Training/Inference Normalization Mismatch (Suspected)
- **File**: `prepareDeepLearningData.m:152-168` (defines `preprocessImage` but never calls it)
- **Problem**: `augmentedImageDatastore(cfg.image.size, imdsTrain)` is called without `'Normalization'` parameter. MATLAB's default is no normalization. If images were trained on un-normalized [0,1] values but inference applies ImageNet normalization, there is a distribution shift.
- **Clinical reason**: A distribution shift between training and inference degrades model accuracy unpredictably.
- **Impact**: Unknown — may or may not be significant. Requires empirical verification.
- **Note**: Fixing this requires retraining. Documented for future work.

---

#### DEFECT C3: Conv Bias Replaced with Ones
- **File**: `createTransferNetwork.m:41`
- **Code**: `'Bias', ones(1, 1, layer.NumFilters)`
- **Problem**: PyTorch conv biases are discarded and replaced with all-ones. The BN layer absorbs most of this error, but it's technically incorrect weight transfer.
- **Impact**: Minor — BN compensation makes this nearly invisible in practice.
- **Note**: Low priority fix. Documented for completeness.

---

### CATEGORY D: FUTURE RESEARCH REQUIREMENTS

---

#### DEFECT D1: No Retinal Field-of-View Masking
- **Problem**: None of the detectors apply a retinal field-of-view (FOV) mask. Fundus images have a circular FOV with black corners. Lesions cannot exist in the black corners, but detectors may find artifacts there.
- **Impact**: False positives in corner regions.
- **Note**: Requires FOV detection algorithm (circular Hough transform or intensity-based).

---

#### DEFECT D2: No Illumination Normalization Before Detection
- **Problem**: Lesion detectors work on raw RGB values without illumination correction. Uneven illumination (common in fundus photography) affects all threshold-based detection.
- **Impact**: Detectors may miss lesions in dark regions or find false positives in bright regions.
- **Note**: Requires CLAHE or similar illumination normalization.

---

#### DEFECT D3: No Scale-Dependent Thresholds
- **Problem**: Lesion size thresholds (e.g., MA: 5-50 pixels, HE: 50-2000 pixels) are in pixel units, not anatomical units. Fundus images vary widely in resolution (474px to 4288px). A 5-pixel MA in a 4288px image is much smaller (in anatomical terms) than a 5-pixel MA in a 474px image.
- **Impact**: Size filtering is inconsistent across image resolutions.
- **Note**: Requires scale estimation (e.g., based on disc diameter) or adaptive thresholds.

---

#### DEFECT D4: No Patient-Level Context
- **Problem**: Each image is analyzed independently. DR progression is temporal — comparing with prior images would improve accuracy.
- **Impact**: Single-timepoint analysis misses progression patterns.
- **Note**: Requires longitudinal dataset and temporal modeling.

---

## 4. Severity Ranking

| # | Defect | Severity | Category | Files Affected |
|---|--------|----------|----------|----------------|
| A1 | MA polarity inversion | **CRITICAL** | Bug | `detectMicroaneurysms.m:59-60` |
| A2 | MA double-strict threshold | **CRITICAL** | Bug | `detectMicroaneurysms.m:63-64` |
| A4 | NV inverted morphological operation | **CRITICAL** | Bug | `detectNeovascularization.m:56` |
| A6 | Grad-CAM random noise in GUI | **CRITICAL** | Bug | `drScreeningGUIv2.m:632` |
| A7 | Formal Grad-CAM non-functional | **HIGH** | Bug | `gradcam.m:97-108, 110-132` |
| A3 | MA local contrast contradicts polarity | **HIGH** | Bug | `detectMicroaneurysms.m:128-133` |
| A5 | NV block upscaling creates huge regions | **HIGH** | Bug | `detectNeovascularization.m:140` |
| A8 | Grad-CAM missing ReLU | **HIGH** | Bug | `gradcamSimple.m:43-49` |
| B4 | HE no vessel/disc masking | **MEDIUM** | Weak heuristic | `detectHemorrhages.m` (entire) |
| B5 | HE no boundary rejection | **MEDIUM** | Weak heuristic | `detectHemorrhages.m` (entire) |
| B1 | Vessel mask hard-coded threshold | **MEDIUM** | Weak heuristic | `detectMicroaneurysms.m:177` |
| B2 | Optic disc fixed brightness threshold | **MEDIUM** | Weak heuristic | 3 detector files |
| B3 | Disc fallback at image center | **MEDIUM** | Weak heuristic | 3 detector files |
| B6 | EX eccentricity threshold too lenient | **MEDIUM** | Weak heuristic | `detectExudates.m:115` |
| B7 | NV density threshold trivially satisfied | **MEDIUM** | Weak heuristic | `detectNeovascularization.m:95-98` |
| C1 | Class weights never applied | **LOW** | Limitation | `trainTransferDRClassifier.m` |
| C2 | Training/inference normalization mismatch | **LOW** | Limitation | `prepareDeepLearningData.m` |
| C3 | Conv bias replaced with ones | **LOW** | Limitation | `createTransferNetwork.m:41` |
| D1 | No FOV masking | **LOW** | Future work | All detectors |
| D2 | No illumination normalization | **LOW** | Future work | All detectors |
| D3 | No scale-dependent thresholds | **LOW** | Future work | All detectors |
| D4 | No patient-level context | **LOW** | Future work | System-wide |

---

## 5. Defects by Affected File

### `detectMicroaneurysms.m`
| Line(s) | Defect | Severity |
|---------|--------|----------|
| 59-60 | A1: Top-hat polarity inversion | CRITICAL |
| 63-64 | A2: Double-strict threshold (Otsu * 2.0) | CRITICAL |
| 128-133 | A3: Local contrast contradicts polarity | HIGH |
| 177 | B1: Hard-coded vessel threshold | MEDIUM |
| 202 | B2: Fixed disc brightness threshold | MEDIUM |
| 222-226 | B3: Disc fallback at image center | MEDIUM |

### `detectNeovascularization.m`
| Line(s) | Defect | Severity |
|---------|--------|----------|
| 56 | A4: Inverted morphological operation | CRITICAL |
| 140 | A5: Block upscaling creates huge regions | HIGH |
| 95-98 | B7: Density threshold trivially satisfied | MEDIUM |
| 178 | B2: Fixed disc brightness threshold | MEDIUM |
| 202-207 | B3: Disc fallback at image center | MEDIUM |

### `detectHemorrhages.m`
| Line(s) | Defect | Severity |
|---------|--------|----------|
| entire file | B4: No vessel/disc masking | MEDIUM |
| entire file | B5: No boundary rejection | MEDIUM |

### `detectExudates.m`
| Line(s) | Defect | Severity |
|---------|--------|----------|
| 115 | B6: Eccentricity threshold too lenient | MEDIUM |
| 160 | B2: Fixed disc brightness threshold | MEDIUM |
| 186-190 | B3: Disc fallback at image center | MEDIUM |

### `drScreeningGUIv2.m`
| Line(s) | Defect | Severity |
|---------|--------|----------|
| 632 | A6: Grad-CAM random noise | CRITICAL |

### `gradcamSimple.m`
| Line(s) | Defect | Severity |
|---------|--------|----------|
| 43-49 | A8: Missing ReLU | HIGH |

### `gradcam.m`
| Line(s) | Defect | Severity |
|---------|--------|----------|
| 97-108 | A7: Broken computation graph | HIGH |
| 110-132 | A7: Fallback differentiates constant | HIGH |

---

## 6. Phase 20B Implementation Plan

### Priority 1: Fix Critical Bugs (No Retraining Required)

**Phase 20B.1 — MA Detector Fix**
1. Fix polarity: `imtophat(max(redChannel) - redChannel, se)` or `imclose(redChannel, se) - redChannel`
2. Remove `* 2.0` threshold multiplier
3. Fix local contrast filter polarity to match
4. Validate on grade 2+ images

**Phase 20B.2 — NV Detector Fix**
1. Fix polarity: `imtophat(greenChannel, se)` or negate before `imopen`
2. Add morphological cleanup after block upscaling
3. Add size filtering on final NV mask
4. Validate on known PDR images

**Phase 20B.3 — Grad-CAM Integration**
1. Replace `rand(224,224)` with `gradcamSimple()` call in `drScreeningGUIv2.m`
2. Add ReLU to `gradcamSimple.m`
3. Fix spatial alignment (resize CAM to original image dimensions)
4. Visual validation on test images

### Priority 2: Fix High-Severity Bugs

**Phase 20B.4 — HE Detector Improvements**
1. Add vessel masking (reuse MA's `detectVesselsForMA` or similar)
2. Add disc masking
3. Add boundary rejection

**Phase 20B.5 — EX Detector Refinement**
1. Reduce eccentricity threshold from 0.95 to 0.85

### Priority 3: Fix Medium-Severity Heuristics

**Phase 20B.6 — Adaptive Thresholds**
1. Replace hard-coded vessel threshold with adaptive method
2. Replace hard-coded disc brightness threshold with relative method
3. Fix disc fallback to skip masking instead of center placement

### Phase 20B Validation Strategy
- Run detectors on representative images from each grade (G0-G4)
- Visual inspection of masks and overlays
- Quantitative comparison of lesion counts before/after fixes
- Ensure no regression on frozen model inference (model unchanged)
- Create diagnostic visualization for each detector stage

---

## 7. Frozen Model Confirmation

**The frozen Phase 8 transfer-learning model (`cc7bed8`) and its test-set results (87.2% sensitivity, 92.7% specificity, 0.704 AUC, 76.6% accuracy) remain UNTOUCHED by this audit.**

This audit:
- Does NOT modify `trainedNetTL.mat`
- Does NOT modify `tl_predictions.csv`
- Does NOT modify any training code
- Does NOT modify the test set
- Does NOT retrain the model
- Only inspects and proposes fixes to supporting pipeline code (detectors, Grad-CAM, clinical logic)

---

## 8. Diagnostic Script

See `matlab/validation/runPhase20ADiagnostics.m` for the reproducible diagnostic script that visualizes every stage of the pipeline on representative images.
