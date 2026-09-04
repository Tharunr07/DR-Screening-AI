# Phase 20B.2 — Neovascularization Detector Correction

**Date:** 2026-09-03
**Status:** Implementation Complete
**Frozen baseline:** `cc7bed8` — UNTOUCHED

---

## 1. Original Defects (from Phase 20A Audit)

### A4 — CRITICAL: Inverted Vessel Extraction

**Original code (lines 53-58):**
```matlab
for a = 1:numel(angles)
    se = strel('line', 7, angles(a));
    response = imopen(greenChannel, se);
    fineVesselResponse = max(fineVesselResponse, response);
end
```

**Numerical trace:** `imopen(greenChannel, se)` computes `(green ⊖ se) ⊕ se`, which is the local maximum of the green channel over the SE footprint. Since vessels are DARK (low values), the opening REMOVES them and outputs the brighter background. The result:
- `fineVesselResponse` = maximum of background estimates across orientations = the retinal background
- `threshold = graythresh(fineVesselResponse)` = Otsu threshold of background = meaningless
- `fineVesselMask = response > threshold * 0.7` = selects bright background pixels

**Net effect:** The "fine vessel mask" is actually a BACKGROUND mask. All downstream analysis operates on inverted data.

### A5 — HIGH: 48-Pixel Block Upscaling

**Original code (line 140):**
```matlab
evidenceMask = imresize(highDensityRegions, [rows, cols]) > 0.5;
```

`highDensityRegions` is a `numBlocksR × numBlocksC` logical matrix (typically ~5×5). `imresize` with nearest-neighbor creates massive rectangular regions. Each 48×48 block becomes a ~45×45 pixel rectangle in the output — anatomically implausible for NV, which appears as fine, irregular vascular networks.

### B7 — MEDIUM: Trivially Satisfied Fallback

**Original code (lines 95-98):**
```matlab
if madDensity > 0
    thresholdDensity = medianDensity + 3 * madDensity;
else
    thresholdDensity = medianDensity + 0.1;
end
```

When `madDensity = 0` (all blocks have identical density), the threshold becomes `medianDensity + 0.1`. For a fundus image with low overall vessel density, this is easily exceeded, causing false positives.

---

## 2. Corrected Algorithm

### 2.1 Vessel Extraction: Black-Hat Morphology

**Operation:**
```matlab
seBH = strel('disk', 3);
vesselResponse = imopen(greenCh, seBH) - greenCh;
```

**Mathematical justification:** Black-hat = `opening(f) - f` produces positive values where the image is DARKER than the local background. Vessels are dark in the green channel, so black-hat correctly enhances them. This is the same principle used in the Phase 20B.1 MA detector fix.

**Channel choice:** Green channel provides the highest vessel-to-background contrast in retinal imaging (standard in the literature).

### 2.2 Adaptive Thresholding

**Operation:**
```matlab
winSz = max(15, round(fundusRadius / 3));
localMu = imboxfilt(vesselResponse, 'NeighborhoodSize', [winSz winSz]);
localVar = imboxfilt(vesselResponse.^2, 'NeighborhoodSize', [winSz winSz]) - localMu.^2;
localSig = sqrt(max(localVar, 0));
vesselThreshold = localMu + 1.5 * localSig;
```

**Rationale:** k=1.5 (lower than MA detector's k=2.5) because:
- Vessels are continuous structures with consistent contrast, not isolated spots
- We want to capture the full vessel network, not just the strongest responses
- The directional morphological opening (next step) provides additional noise suppression

### 2.3 Directional Morphological Opening

**Operation:**
```matlab
seLen = max(5, round(fundusRadius * 0.04));
vesselOriented = false(rows, cols);
for ang = 0:30:150
    vesselOriented = vesselOriented | imopen(vesselMask, strel('line', seLen, ang));
end
vesselMask = vesselMask & vesselOriented;
```

**Rationale:** Line structuring elements at 6 orientations (0°, 30°, 60°, 90°, 120°, 150°) select elongated structures. The `vesselMask & vesselOriented` intersection ensures that only elongated dark features (vessels) remain, while circular dark spots (noise, MAs) are removed.

**SE length:** `fundusRadius * 0.04` — scales with image resolution. At 512px fundus diameter, this is ~10 pixels; at 1024px, ~20 pixels.

### 2.4 Major vs. Fine Vessel Separation

**Major vessels:**
```matlab
for ang = 0:30:150
    majorMask = majorMask | imopen(vesselMask, strel('line', seLen * 3, ang));
end
majorMask = imdilate(majorMask, strel('disk', 2));
```

Uses SE 3× longer than fine vessel detection. Major vessels (arteries/veins) are thicker and span larger distances. The 2-pixel dilation ensures complete exclusion.

**Fine vessels:**
```matlab
fineMask = vesselMask & ~majorMask;
```

All vessels minus major vessels. These include normal capillaries AND potential NV. The subsequent NV criteria distinguish between them.

### 2.5 NV-Specific Criteria (Multi-Criteria Decision)

The corrected algorithm evaluates each fine-vessel cluster against five criteria:

| Criterion | Threshold | Justification |
|-----------|-----------|---------------|
| **(a) Cluster area** | `minClusterArea` to `maxClusterArea` | NV clusters are larger than noise but smaller than the retina |
| **(b) Local density** | `> median + 3*MAD` (adaptive) | Abnormally high fine-vessel concentration |
| **(c) Irregularity** | `> 0.2` | NV boundaries are irregular (path length / convex hull perimeter) |
| **(d) Location** | Peripheral (`normDist > 0.3`) or peripapillary (`< 2 disc radii`) | NV typically occurs in peripheral retina or near disc |
| **(e) Major-vessel overlap** | `< 30%` | Reject regions that are mostly normal vessels |

**All five criteria must be satisfied** for NV detection. This multi-criteria approach prevents:
- Normal capillaries (low density, regular, central) from being flagged
- Major vessel bifurcations (high major-vessel overlap) from being flagged
- Noise clusters (small, low irregularity) from being flagged

### 2.6 Spatial Mapping (No Block Upscaling)

**Before:** 48×48 blocks → `imresize` → giant rectangles
**After:** Connected-component analysis on fine-vessel mask → individual cluster regions

Each NV candidate is a connected component of fine vessels. The mask preserves the actual shape of the vessel cluster, not a rectangular approximation. Oversized components (>15% of image area) are rejected.

### 2.7 Optic Disc Exclusion

**Before:** Fixed `gray > 0.65` threshold, fallback at image center
**After:** Adaptive 95th percentile of retinal brightness, conservative fallback at `(0.55*cols, 0.45*rows)` with small radius (`min(rows,cols)/16`)

The disc is the brightest large structure in the fundus. The 95th percentile adapts to different image exposures. The fallback is deliberately conservative (small, off-center) to avoid falsely labeling the fovea as disc.

### 2.8 Irregularity Metric

**Operation:**
```matlab
boundaryPixels = getBoundaryPixels(clusterMask);
irregularity = computeIrregularity(boundaryPixels);
```

Where `computeIrregularity` computes `pathLength / convexHullPerimeter`.

- A perfect circle has irregularity ≈ 1.0
- A smooth ellipse has irregularity ≈ 1.0-1.2
- An irregular, tortuous NV network has irregularity > 1.2
- Threshold of 0.2 is applied after normalization to [0,1] range

---

## 3. What Was NOT Changed

- **Interface:** Same input/output signature (preserved for `extractLesionEvidence.m` compatibility)
- **Frozen model:** `trainedNetTL.mat` — UNTOUCHED
- **Frozen test set:** 612 images — UNTOUCHED
- **Frozen predictions:** `tl_predictions.csv` — UNTOUCHED
- **Other detectors:** MA, HE, EX detectors — UNTOUCHED
- **Classifier integration:** Detector operates independently

---

## 4. Limitations

1. **No ground truth validation:** NV detection is validated through synthetic tests only. Clinical sensitivity/specificity cannot be claimed without expert-annotated NV ground truth.

2. **Heuristic parameters:** k=1.5 (vessel threshold), k=3*MAD (density threshold), 0.2 (irregularity), 0.3 (location fraction) are reasonable defaults but not optimized against clinical data.

3. **No tortuosity measurement:** The irregularity metric measures boundary roughness, not vessel tortuosity (curvature along the vessel centerline). True NV tortuosity requires skeletonization and curvature computation.

4. **No temporal information:** Single-image analysis cannot use temporal change detection.

5. **Single-scale detection:** The algorithm detects NV at one spatial scale. Multi-scale analysis could improve sensitivity.

6. **No disc neovascularization (NVD) distinction:** The algorithm detects NV generally but does not specifically distinguish NVD (on disc) from NVE (elsewhere). The disc exclusion may miss NVD.

---

## 5. False Positive Mechanisms Removed

| Mechanism | Before | After |
|-----------|--------|-------|
| Inverted vessel extraction | Detected background as vessels | Correctly detects dark vessels |
| Block upscaling | Giant rectangular NV regions | Individual connected components |
| Trivial fallback threshold | `median + 0.1` always triggers | Adaptive `median + 3*MAD` |
| Fixed disc threshold | `gray > 0.65` fails on dark images | Adaptive 95th percentile |
| No major-vessel rejection | Major vessels counted as NV | 30% overlap threshold |
| No location criterion | Central regions flagged | Peripheral/peripapillary required |
| No irregularity criterion | Any density spike flagged | Boundary roughness required |

---

## 6. Validation

**Test suite:** `matlab/validation/validatePhase20B2.m`

**Tests (22 total):**
- T01-T06: Structural correctness
- T07-T10: Input handling (uint8, double, grayscale, small)
- T11-T12: Anatomical constraints (FOV, disc exclusion)
- T13-T18: False positive prevention (blank, uniform, noise, normal vessels, giant rectangles)
- T19: True positive detection (NV-like cluster)
- T20: Deterministic output
- T21-T22: Diagnostic mode (outputs, visualization)

---

## 7. Files Modified

| File | Change |
|------|--------|
| `matlab/lesions/detectNeovascularization.m` | Complete rewrite of detection algorithm |

## 8. Files Created

| File | Purpose |
|------|---------|
| `matlab/validation/validatePhase20B2.m` | Validation test suite |
| `docs/PHASE20B2_NV_FIX.md` | This document |

---

## 9. Remaining Failure Modes

1. **Very fine NV** (< 20 pixels total area): May be below minimum cluster threshold
2. **NV near major vessels**: May be rejected by 30% overlap criterion
3. **NVD (on-disc NV)**: May be excluded by disc mask
4. **Low-contrast NV**: May not exceed density threshold
5. **Unusual pigmentation**: May affect green channel distribution
6. **Very poor image quality**: May reduce vessel detection sensitivity

---

## 10. Confirmation

- [x] `cc7bed8` commit hash — UNTOUCHED
- [x] `trainedNetTL.mat` — UNTOUCHED
- [x] `tl_predictions.csv` — UNTOUCHED
- [x] 612-image test set — UNTOUCHED
- [x] `detectMicroaneurysms.m` — NOT MODIFIED (Phase 20B.1)
- [x] `detectHemorrhages.m` — NOT MODIFIED
- [x] `detectExudates.m` — NOT MODIFIED
- [x] `gradcamSimple.m` — NOT MODIFIED
- [x] `drScreeningGUIv2.m` — NOT MODIFIED

---

## 11. Recommendation

**Proceed to Phase 20B.3 (Grad-CAM integration in GUI).**

The NV detector correction addresses all three defects (A4, A5, B7) with technically justified operations:
- Correct polarity (black-hat for dark vessels)
- Proper vessel/NV separation (major vs. fine)
- Multi-criteria NV decision (density + irregularity + location + no major overlap)
- No block upscaling (connected-component analysis)
- Adaptive thresholds throughout

The natural next step is to integrate the existing `gradcamSimple.m` into the GUI, replacing the `rand(224,224)` placeholder (defect A6).

**A PASSING TEST SUITE DOES NOT PROVE THAT NV DETECTION IS CLINICALLY CORRECT.** The objective is to eliminate known algorithmic defects and make the output anatomically plausible and scientifically defensible.

---

## 12. CORRECTION ADDENDUM (2026-09-03, found by executed validation in Phase 20B.4)

This document as originally written contained errors, and its validation
suite had never been executed in MATLAB. Executed validation exposed:

1. **Wrong morphology definition** ("black-hat = opening − original"):
   correct is **closing − original**. The vessel response was identically
   zero.
2. **Invalid `imboxfilt` syntax** (see 20B.1 addendum): vacuous passes.
3. **`estimateFundusRadius` called `rgb2gray` on a 2-D mask → always threw
   → the NV detector could never return anything.** The 20B.2 suite's
   "passes" were vacuous; only a positive-detection test (T19) catches
   this class of failure.
4. Follow-on fixes from executed debugging: blot carve-out; disc
   plausibility + rim-sharpness + select-before-close; 12-orientation
   vessel opening; fragment bridging with original-pixel masks; 6x major
   SE; background-only fixed-window density baseline; peripapillary gated
   on located discs; arcade-proximity gate; ≥2-junction branching gate
   (surveyed frond: 28 junctions).
5. T19 fixture rebuilt as a seeded two-tier sea-fan frond with a
   frond-zone localization assertion; suite verified stable over 6
   consecutive executed runs.

Current status: suite **22/22 PASS executed** (MATLAB R2026a), full
regression green. See `docs/PHASE20B4_HEMORRHAGE_CORRECTION.md`,
Appendix X, for the complete account.
