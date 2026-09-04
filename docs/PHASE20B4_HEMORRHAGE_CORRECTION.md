# Phase 20B.4 — Hemorrhage Detector Forensic Correction

**Date:** 2026-09-03
**Status:** Implementation + MATLAB-executed validation complete
**Frozen baseline:** `cc7bed8` — UNTOUCHED. No new sensitivity/specificity/AUC.

---

## A. Original Defects

Assigned: **B4** (no vessel/disc masking), **B5** (no boundary rejection).
Forensic trace (13 points, `detectHemorrhages.m`, 115 lines) found more:

| # | Defect | Lines | Severity |
|---|--------|-------|----------|
| F-HE-01 | No vessel interaction of any kind (B4) | whole file | HIGH |
| F-HE-02 | No disc interaction of any kind (B4) | whole file | MEDIUM |
| F-HE-03 | No FOV/boundary handling (B5) | whole file | HIGH |
| F-HE-04 | Fixed global thresholds (`V<0.4`, `S>0.2`) | 61-67 | HIGH |
| F-HE-05 | Hue test meaningless on dark pixels (hue unstable at low V; black has hue 0 = "red") | 61-70 | HIGH |
| F-HE-06 | No shape filtering (eccentricity/solidity) | 81 | MEDIUM |
| F-HE-07 | Fixed pixel areas 50/2000, resolution-blind | 29,78,85 | MEDIUM |
| F-HE-08 | Uncalibrated confidence (`count/5 + area/10000`) | 102 | LOW |
| F-HE-09 | `double` input >1 silently corrupts `rgb2hsv` | 42-46 | LOW |
| F-HE-10 | Grayscale input silently returns empty | 49 | LOW |
| F-HE-11 | Mask-label mapping fragile (`bwlabel` + `find`) | 95-99 | LOW |
| F-HE-12 | `MaxArea`+closing kills merged vessel trees AND large blots alike | 73-85 | MEDIUM |
| F-HE-13 (latent, out of scope) | `structures/analyzeImage.m:121` calls `detectHemorrhages(img,fov,vessels,cfg)` — a 4-positional convention no current detector accepts; silently yields empty evidence | — | noted |

## B. Original Algorithm

`rgb2hsv` → `red = (H<0.1|H>0.9) & V<0.4 & S>0.2` → close/open disk-3 →
`bwareaopen(50)` → keep area ≤ 2000 → `count/5 + totalArea/10000` confidence.

## C. Failure Mechanisms

1. **Vessel tree admitted, then accidentally removed.** Dark-red vessels pass
   the color test (F-HE-01). Thin vessels die in `imopen(disk-3)`; the merged
   remainder dies at `MaxArea=2000` (F-HE-12). Net effect on 5 real images:
   **OLD count = 0,0,0,0,0** — systematic under-detection by accident, not
   by design. Medium dark-red artifacts (50-2000px) WOULD fire it.
2. **Hue noise at low value** (F-HE-05): any near-black pixel has hue ≈ 0 and
   passes the "red" test; only the saturation gate accidentally saves the
   FOV background.
3. **No anatomy anywhere** (F-HE-01/02/03): border crescents, peripapillary
   pigment, and vessel segments in the 50-2000px band all qualify.
4. **Resolution blindness** (F-HE-07): 50-2000px means different anatomy at
   640px vs 2588px.

## D. Corrected Algorithm

Same architecture proven in 20B.1, rescaled for hemorrhage morphology:

1. Convert (uint8/uint16/double normalized); reject grayscale/degenerate.
2. Adaptive retinal FOV mask (largest dark-background component).
3. Adaptive disc mask: 95th-percentile brightness → select-first on
   unmerged components → solidity/size plausibility → rim-sharpness test →
   fail-open (Sec. F).
4. Adaptive vessel mask: green 10th-percentile + 6-orientation line opening
   + blot carve-out (Sec. E); exclusion dilates by 1px only + 40% overlap
   gate (flame-HE adjacency is a documented miss).
5. Enhancement: `max(blackHat_disk, backgroundSubtraction)` on GREEN —
   black-hat covers small spots, box-mean subtraction covers large uniform
   blots (rim-only black-hat responses), all scales resolution-derived.
6. Threshold `localMu + 2.0·localStd` in a window ~2x the background scale
   (a lesion must not dominate its own statistics window).
7. Exclusions (FOV, disc, vessels), resolution-scaled edge margin + FOV
   erosion (Sec. G).
8. close disk-2 → fill holes (solidify blot rims) → open disk-1.
9. Resolution-aware area gates from the 60µm-1.5mm clinical band over an
   assumed 6mm fundus diagonal (Sec. H, assumption explicit).
10. Five region gates: area, shape (`ecc ≤ 0.95`, `sol ≥ 0.35` — lenient,
    vessels handled by overlap), vessel overlap ≤ 40%, local darkness
    (`G < mu − 0.5σ`), weak red prior (`mean R ≥ mean G`, rejects black
    dust, deliberately mild).
11. Output preserves the `extractLesionEvidence` interface
    (`count/mask/locations/areas/totalArea/confidence`) + `Diagnostic`
    masks/labels. Confidence = count + FOV-area-fraction blend.
12. Any error → empty evidence (fail-safe, never garbage).

## E. Vessel Masking Methodology

Green-channel 10th percentile within FOV (adaptive, no `green < 0.4`),
directional line opening (6 angles) intersected with the raw mask, then:

- **Blot carve-out (shared fix, also applied to MA/NV):** directional
  opening keeps ANY feature containing a line segment, including round
  blots. Components with `area ≥ 25 & solidity > 0.8 & ecc < 0.6` are
  carved out — they are lesion candidates, not vessels. Thin vessels
  (`ecc ≈ 1`) are unaffected.
- Exclusion uses 1px dilation (restrained: hemorrhages may abut vessels)
  plus a 40%-overlap component gate.

## F. Disc Masking Methodology

95th-percentile retinal brightness → de-speckle (open disk-2, NO closing:
closing merges disc with bright center/exudates) → largest component →
close+fill winner only → three acceptance tests, else fail-open (empty
mask, visible in diagnostics):

1. **Size plausibility:** radius ≤ minDim/6 (real disc ≈ minDim/14 from
   1.5mm vs ~10-11mm in a 45° photo; margin documented).
2. **Rim sharpness:** mean gradient on the candidate rim must exceed 3x
   the median retinal gradient (discs have pallor edges; illumination
   gradients do not).
3. Fallback (no bright region): small off-center disk, documented.

Shared fix applied identically to the MA and NV detectors. Known miss:
edge-truncated or very low-contrast discs can fail the rim test
(observed on `0097f532ac9f`: illumination patch correctly rejected,
true edge disc missed) — peripapillary FPs are the residual risk.

## G. Boundary Handling

Edge margin `max(3, round(minDim·5/224))` + FOV erosion (~half margin).
Kills border crescents, vignetting responses, corner dots (T16/T21 PASS).

## H. Threshold Methodology

No fixed photometric thresholds remain. `k = 2.0` per-pixel (permissive;
specificity carried by size/shape/anatomy gates). The 0.008 absolute floor
prevents collapse in uniform regions. Physical-size gates derive from
image diagonal with the 6mm assumption stated in-code; user `MinArea` /
`MaxArea` overrides preserved.

## I. Synthetic/Adversarial Validation — 24/24 PASS (executed MATLAB R2026a)

`matlab/validation/validatePhase20B4.m`: structure (T01-T05), inputs
uint8/double/gray/small (T06-T09), 11 adversarial synthetics —
black/white/gray/noise/vessels/disc/border/corner-dot all zero,
hemorrhage-like blob detected (T10-T17) — determinism (T18), gate-level
proofs vessel/disc/boundary (T19-T21), diagnostics (T22), GUI +
`extractLesionEvidence` compatibility (T23-T24). Logs:
`results/phase20b4_validation/`.

## J. Real-Image Diagnostics — `results/demo/hemorrhage/` (21 files)

Validation-split images, never `test.csv`. OLD (archived pre-fix copy via
path shadowing) vs NEW:

| Image | Size | OLD | NEW | Note |
|-------|------|-----|-----|------|
| 00836aaacf06 | 640×480 | 0 | 0 (conf 0.00) | agreement on exudate-only image; mechanisms differ (see C) |
| 0097f532ac9f | 2588×1958 | 0 | 1 (conf 0.09 LOW) | NEW chain: 250k raw px (vessel tree) → 177k vessel px excluded → 1 candidate; disc fail-open documented above |
| 009c019a7309 | 640×480 | 0 | 0 | agreement |
| 00e4ddff966a | 2416×1736 | 0 | 0 | agreement |
| 01499815e469 | 640×480 | 0 | 0 | agreement |

Per image: `_orig`, `_old`, `_new`, `_panels` (A-original, B-raw,
C-vessels, D-disc, E-final, F-centroids). Honest reading: OLD's zeros are
accidental (F-HE-12); NEW's zeros come from gates firing (verified in
diagnostics); the single NEW candidate is LOW confidence and NOT claimed
as a true hemorrhage. A first diagnostic batch had an overlay-alpha
visualization bug (scalar alpha tinted whole frame); caught on review,
fixed (`AlphaData = mask·0.45`), regenerated.

## K. Regression Results — 121/121 PASS (all executed, MATLAB R2026a)

| Suite | Result |
|-------|--------|
| validatePhase12_1 | 12/12 |
| validatePhase15 | 8/8 |
| validatePhase16A | 10/10 |
| validatePhase20B1 | 25/25 |
| validatePhase20B2 | 22/22 (6 consecutive clean runs after stability work) |
| validatePhase20B3 | 20/20 |
| validatePhase20B4 | 24/24 |

## L. Remaining Limitations

1. Flame hemorrhages hugging vessels: 1px dilation + 40% overlap gate
   will remove many — documented miss.
2. Edge-truncated / low-contrast discs may fail the rim test → no disc
   exclusion → peripapillary FP risk.
3. Giant (>1.5mm) hemorrhages exceed the size gate.
4. Isolated intra-retinal black dots are indistinguishable from small
   blots (color prior is weak by design).
5. Exudate detector untouched — still pre-forensic (candidate: 20B.5).
6. `gradcam.m` still broken/unused; `analyzeImage.m` legacy 4-arg lesion
   calls still silently yield empty (F-HE-13).

## M. Explicit Non-Validation Statement

**Clinical lesion-level hemorrhage accuracy has NOT been established.**
No expert-annotated hemorrhage ground truth was used; no
sensitivity/specificity is reported. Synthetic + anatomical-plausibility
tests verify the algorithm is defensible, not that it is correct.

---

## Appendix X — Cross-Phase Corrections Found by EXECUTED Validation

Phase 20B.4 is the first phase whose suites were executed in MATLAB during
development (20B.3 was executed post-hoc: 20/20). Execution exposed defects
in 20B.1/20B.2 code that static review missed. All fixed, all suites
re-executed green. Full honesty requires recording them:

| # | Defect | Impact | Fix |
|---|--------|--------|-----|
| X-01 | `imboxfilt(X,'NeighborhoodSize',[..])` is invalid MATLAB (positional window required). Present in MA, NV, HE detectors | **Every detector call threw → try/catch → always-empty evidence.** All "passing" 20B.1/20B.2 assertions were vacuous until this fix | positional windows in all 3 files |
| X-02 | "Black-hat = opening − original" is mathematically wrong (always ≤ 0 → zeros). Correct: **closing − original** | All black-hat terms contributed exactly 0.0 everywhere (measured). 20B.1 detections came solely from its background-subtraction term; NV vessel extraction was entirely dead | `imclose` in all 3 files + doc corrections below |
| X-03 | `estimateFundusRadius` called `rgb2gray` on a 2-D mask → always threw | **NV detector could never return anything** (root cause behind X-blindness) | direct logical sampling |
| X-04 | Disc detector hallucinated giant masks over diffuse brightness (no size/edge validation) | Lesions near brightness peaks wrongly excluded in all 3 detectors | plausibility gate (≤ minDim/6) + rim-sharpness test + select-before-close |
| X-05 | Vessel directional opening swallows round blots (any line segment survives) | Blots labeled vessels → excluded from candidacy | compact-component carve-out in all 3 detectors |
| X-06 | NV density in bbox-adaptive windows (small-denominator inflation) + baseline including candidates | Decision statistic marginal/blind | fixed measurement windows + background-only baseline |
| X-07 | NV major opening (3x) ate frond pieces; assumed disc location handed free passes; smooth arc fragments FPed at high confidence | T17 flaky FP (conf 0.77 observed) | 6x major SE; peripapillary requires located disc; arcade-proximity gate; ≥2-junction branching gate (surveyed: frond 28 junctions) |
| X-08 | MA size cap rejected digitized 125µm MAs; T24 phantom modeled a 190µm lesion | T24 failure | +1px discretization margin (documented); phantom corrected to <3px (~110µm, inside spec) |
| X-09 | NV T19/T17 fixtures caused suite flakiness (unseeded draws; frond overlapping arcade; dots-model) | 20B.2 suite 21-22/22 across runs | seeded two-tier sea-fan frond + frond-zone assertion; 6/6 clean runs |

Correction addenda were appended to `docs/PHASE20B1_MICROANEURYSM_FIX.md`
and `docs/PHASE20B2_NV_FIX.md` (their "black-hat = opening − f" statements
and unexecuted-validation claims). The lesson is structural and is now
project policy: **no phase closes without MATLAB-executed suites, and at
least one positive-detection test must prove the detector CAN fire**
(vacuous all-negative suites hid X-01/X-03 completely).
