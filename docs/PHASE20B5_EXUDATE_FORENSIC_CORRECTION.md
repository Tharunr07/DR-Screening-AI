# Phase 20B.5 — Exudate Detector Forensic Audit and Correction

**Date:** 2026-09-03
**Status:** Implementation + MATLAB-executed validation complete
**Frozen baseline:** `cc7bed8` — UNTOUCHED. No classification metrics reported.

**Passing software tests does not establish clinical exudate detection accuracy.**

---

## A. Original Implementation

`detectExudates.m` (222 lines): `rgb2hsv` + gray + green → three-criteria
vote (`V>0.6 & S<0.5`; `adaptthresh(green,0.4)+green>0.5`; local-contrast
`>0.1 & gray>0.45`, any two agree) → fixed disc removal (`gray>0.7`,
center fallback) → fixed vessel removal (`green<0.4`, dilate-1) →
close-2/fill/bwareaopen(10) → area 10–3000 + `ecc<0.95` → `0.5·area/5000
+ 0.5·count/10` confidence.

## B. Every Defect Discovered

| # | Defect | Severity |
|---|--------|----------|
| F-EX-01 | Disc: fixed `gray>0.7`, no validation, silent image-center fallback | HIGH |
| F-EX-02 | Disc = largest bright blob: on pathology-dominated images the mask lands on exudates/illumination and DELETES findings | HIGH |
| F-EX-03 | Vessels: fixed `green<0.4` | MEDIUM |
| F-EX-04 | No FOV mask at all; no boundary rejection (bright glare passes all criteria) | HIGH |
| F-EX-05 | Fixed photometric floors (0.6/0.5/0.45) — illumination-blind | MEDIUM |
| F-EX-06 | Fixed areas 10–3000px, resolution-blind (kills large plaques at high res) | MEDIUM |
| F-EX-07 | Shape gate `ecc<0.95` admits nearly everything; no solidity | MEDIUM |
| F-EX-08 | Confidence uncalibrated (labeled heuristic now, TASK 13) | LOW |
| F-EX-09 | Dead `isfield` checks on `regionprops` output; fragile `bwlabel+find` mapping | LOW |
| F-EX-10 | No NaN guard; `double>1` corrupts HSV silently | LOW |
| F-EX-11 (cross-phase, all 4 detectors) | **Retinal FOV mask vacuous**: `imfill` filled the retina as a "hole"; mask was the whole frame. First complement fix then **partitioned on full-width vessels** (mask = 13% slice). Final: open-background → complement → largest | HIGH |
| F-EX-12 (test bug, caught in review) | T22 fixture `img(mask2D)=1.0` assigned linearly (first page only), not the blob | process |

No polarity inversion existed (no grayscale top-hat misuse); `adaptthresh`
call was valid MATLAB. Verified by execution, not assumed (TASK 16).

## C. Mathematical Reasoning

Bright-on-background model: response = max(white top-hat, local excess),
white top-hat = `f − opening(f)` (correct bright polarity — the 20B.4
`closing−f` lesson applied in mirror). Green channel (best exudate
contrast; red confounded by orange background). Threshold `mu+2.5σ` in
lesion-large windows + 0.03 absolute noise floor (green sensor/JPEG noise
lives below it; verified: merged speckle clumps otherwise survive the
size gate). Edge-sharpness gate (rim gradient > 3x background AND > 0.02
absolute) separates stepped exudate borders from dome gradients and
speckle edges — same pattern as the disc rim test.

## D. Optic-Disc Handling

Shared 20B.4 design (percentile → select-before-close → size ≤ minDim/6 →
rim test → fail-open; never `gray>0.7`, never silent center). T14 proves
localization + exclusion on a phantom disc. **Known failure, observed on a
real image**: edge-truncated discs can fail the rim test; on
`01499815e469` (disc at left edge) the mask is empty and ~3 of 19
candidates sit on the disc (likely FPs — reported, not hidden).

## E. Vessel Handling

Shared adaptive vessel mask, returned UNDILATED for bright detection
(dilation would erase vessel-adjacent exudates); 40%-overlap component
gate catches reflex-dominated pieces. T19 proves a 10px-distant exudate
survives; T15 proves a bright streak dies at the shape gate.

## F. Local Contrast

Detection threshold is local (`mu+2.5σ`) plus per-candidate verification
(`G > localMu + 0.5σ` in a 41px patch). No global brightness decision
exists anywhere in the pipeline.

## G. Shape Criteria

Area (60µm–3mm band, 6mm-diagonal assumption explicit) + `ecc ≤ 0.9` +
`solidity ≥ 0.4` + vessel overlap + local brightness + weak `R ≥ B` color
prior + edge sharpness. No single threshold defines an exudate.

## H. FOV/Boundary Handling

Real FOV mask (F-EX-11 fix) + resolution-scaled edge margin + FOV erosion.
Border glare, corner dots, extra-FOV blobs all rejected (T16/T22/T23).

## I. Positive Synthetic Tests (mandatory, all PASS executed)

T17 single blob (seeded, zone-localized assertion), T18 three blobs
(count == 3 semantics via ≥2), T19 near-vessel kept, T20 near-disc kept
with disc still localized. Suite refuses all-zero validation by
construction.

## J. Negative/Adversarial Tests (all PASS executed)

Black/white/gray/noise (T10–T13), disc-only (T14 + mask proof), bright
vessel streak (T15), border glare (T16), extra-FOV blob (T22), corner dot
(T23), illumination dome (T26). Grayscale/small inputs fail safe (T08–T09).

## K. Real-Image Diagnostics (`results/demo/exudate/`, 21 files)

Validation images only (00836aaacf06 pinned first for cross-phase
comparison). OLD (archived SHA-recorded copy, path-shadowed) vs NEW:

| Image | OLD | NEW | Reading |
|-------|-----|-----|---------|
| 00836aaacf06 (640×480) | 0 | 10 (conf 0.55 heuristic) | Centroids land on the visible circinate clusters — plausible; disc smooth-interior escapes via enhancement, not mask (measured: 177 raw disc-zone px → 0 final) |
| 0097f532ac9f (2588×1958) | 0 | 0 | agreement (clean macula) |
| 009c019a7309 | 0 | 5 | candidates on bright spots |
| 00e4ddff966a | 0 | 2 | low count |
| 01499815e469 | 0 | 19 | includes ~3 disc-region likely-FPs (edge-disc miss, Sec. D) |

OLD zeros are accidental (fixed floors + MaxArea + disc deletion); NEW
outputs carry per-image A–G diagnostic chains. A first batch had the same
scalar-alpha overlay bug as 20B.4's first batch; fixed before release
(mask-weighted alpha).

## L. Regression Results — 147/147 PASS executed (MATLAB R2026a)

12_1: 12/12 · 15: 8/8 · 16A: 10/10 · 20B.1: 25/25 · 20B.2: 22/22 ·
20B.3: 20/20 · 20B.4: 24/24 · 20B.5: 26/26. The FOV-mask correction
initially broke NV T19 (frond straddled the now-real FOV rim — correctly
excluded); fixture moved fully inside FOV (d≈0.45, still peripheral) and
all suites re-verified, 20B.5 stable over 3 consecutive runs.

## M. Remaining Failure Modes

1. Edge-truncated discs → missed exclusion → disc-region FPs (observed).
2. Saturation/clipping artifacts of exudate size are indistinguishable
   from exudates (no context model).
3. Faint exudates (edge gradient < 0.02 or contrast < 0.03 floor) missed.
4. Flame-adjacent/large-plaque boundary behavior at size-gate extremes.
5. Confidence is HEURISTIC (count + area fraction), not calibrated.
6. `analyzeImage.m` legacy 4-arg lesion calls still silently empty (20B.4
   F-HE-13, untouched, out of scope).

**Passing software tests does not establish clinical exudate detection
accuracy.** No lesion-level ground truth exists; no sensitivity,
specificity, AUC, or detection-accuracy figures are reported or implied.
