# Phase 20B.3 — Formal Grad-CAM GUI Integration

**Date:** 2026-09-03
**Status:** Implementation + MATLAB-executed validation complete (20/20 PASS)
**Frozen baseline:** `cc7bed8` — UNTOUCHED

---

## A. Original Defect

**`matlab/demo/drScreeningGUIv2.m:632` (before fix):**
```matlab
% Grad-CAM (placeholder)
gradcam = struct('cam', rand(224, 224));
```

The clinical-report path fabricated a 224×224 uniform-noise matrix and passed
it downstream as if it were a model attention map.

## B. Why Random Heatmaps Are Unacceptable

A heatmap presented beside a medical prediction is read as *where the model
looked*. Uniform noise:

1. carries zero information about the model, yet borrows its authority;
2. is non-reproducible across runs (different noise each click), so two
   identical screenings "disagree" about model attention;
3. can coincide with real lesions by chance, manufacturing false trust, or
   miss them, manufacturing false doubt;
4. violates the most basic explainability requirement: the explanation must
   be a deterministic function of (model, input, target class).

The only safe failure mode is an explicit **"Grad-CAM unavailable"** message.

## C. Pre-Fix Audit Findings (reported before changing anything)

**`gradcamSimple.m`:**
1. **Missing ReLU (Phase 20A defect A8).** Min-max normalization without
   `max(cam,0)` let negative (counter-evidence) values rescale the map.
2. **FC-weight projection ignored ReLU gating** in the head
   (`W3·W2·W1`), making channel weights an approximation of the true
   gradient, not the gradient itself.
3. No sanity checks (NaN/Inf, invalid class, grayscale, empty maps).

**`gradcam.m`:** non-functional. `forwardWithActivations` calls
`extractdata` before `activations`/`predict`, detaching the graph, so both
the primary `dlgradient` and the fallback differentiate constants. Left
untouched; not used.

**`drScreeningGUIv2.m`:** `rand(224,224)` placeholder; no Show Heatmap
action at all; Export/Reset buttons overlapped at identical pixel positions
(pre-existing minor layout bug, fixed incidentally when placing the new
Heatmap button).

**Network (frozen, from `createTransferNetwork.m`):** ResNet-18 backbone,
`pool5` (GAP, 512-d) → `fc_dr_1` (512) → ReLU → `fc_dr_2` (128) → ReLU →
`fc_dr_output` (5 logits) → softmax → `categorical(0:4)`. Classes:
MATLAB index 1..5 ↔ DR grade 0..4.

## D. Grad-CAM Mathematical Formulation (as implemented)

Standard Grad-CAM (Selvaraju et al., 2017) for target class `c`:

```
alpha_k^c = (1/Z) · Σ_i Σ_j ∂y^c / ∂A_ij^k
L^c       = ReLU( Σ_k alpha_k^c · A^k )
```

`y^c` = pre-softmax logit, `A^k` = k-th feature map, `Z = H·W`.

**Exact closed-form gradients.** The head is a short affine+ReLU chain over
a GAP vector, so with ReLU masks `m1, m2` recorded on the forward pass:

```
p   = GAP(F)                        512×1
h1  = ReLU(W1·p + b1),  m1 = (W1·p+b1) > 0
h2  = ReLU(W2·h1 + b2), m2 = (W2·h1+b2) > 0
y   = W3·h2 + b3                    (logits)
∂y^c/∂h2 = W3(c,:) ⊙ m2
∂y^c/∂h1 = (∂y^c/∂h2 · W2) ⊙ m1
∂y^c/∂p  = ∂y^c/∂h1 · W1
alpha_k  = (∂y^c/∂p_k) / Z
```

Dropout is inactive at inference; `activations()` runs deterministically.
No approximation, no autodiff graph, no randomness.

## E. Selected Target Layer

**`res5b_branch2b`** — last convolutional block of ResNet-18, 7×7×512.
Deepest spatial features before global pooling; standard Grad-CAM choice
(maximizes semantic specificity while retaining spatial layout).
Verified at runtime: 512 channels expected, error otherwise.
Configurable via `'LayerName'` without code changes.

## F. Class-Specific Calculation

- Default `'TargetClass', 0` → predicted class (`double(classify(...))`,
  MATLAB index 1..5).
- GUI passes the explicit predicted index on every call; the report path
  stores `targetGrade = index − 1` alongside the map.
- Out-of-range targets (except 0) throw; validated by T18.
- T15 proves class-specificity: at least one pair of the 5 class CAMs
  differs on a real fundus image.

## G. Preprocessing

Byte-identical to `runScreening` in all three call sites (screening,
heatmap figure, report path):

```
resize  -> imresize(img, [224 224], 'bicubic')
scale   -> double / 255
channel -> (x − mn) / sd, mn=[0.485 0.456 0.406], sd=[0.229 0.224 0.225]
```

No augmentation at inference. The Phase 20A training/inference
normalization question was **not** silently changed; whatever the frozen
classifier expects is what Grad-CAM receives, since both share the input.

## H. ReLU

`cam = max(cam, 0)` applied to the weighted combination **before** any
normalization (fixes A8). Only positive evidence for the target class
survives. All-zero output (no positive evidence, e.g. blank image) is
returned honestly as zeros, not rescaled noise.

## I. Normalization

Post-ReLU `cam / max(cam)`; constant maps stay zero. Final clamp to [0,1].
Display resize (`imresize` to original-image size for overlay) happens after
normalization, so display scaling cannot alter map values.

## J. Overlay Methodology

Figure with three panels: original fundus | raw CAM (`jet`, [0,1],
colorbar) | overlay (`AlphaData` 0.4 on original). Legend shows predicted
grade and top-class probability. A figure-level annotation carries the
disclaimer: *"Grad-CAM: model attention visualization. Attention map is an
AI explanation aid and is not a lesion segmentation or clinical diagnosis."*
The map is never called a "lesion map". No sharpening/amplification is
applied; the 7×7 → full-size upsampling is intentionally left smooth.

## K. Determinism Test

T13: two consecutive calls on the same preprocessed input agree to
`max|Δ| < 1e-9`. Executed result: **PASS** on MATLAB R2026a against the
frozen model. No RNG exists in `gradcamSimple.m` or the GUI Grad-CAM path
(T02/T03 grep-verified).

## L. Validation Results (executed, not claimed)

`matlab/validation/validatePhase20B3.m` — **20/20 PASS** on MATLAB R2026a,
2026-09-03, against frozen `trainedNetTL.mat`:

| # | Test | Result |
|---|------|--------|
| T01–T06 | helper exists; no rand in helper/GUI; GUI calls helper with explicit class; fail-safe + disclaimer present | PASS |
| T07 | frozen model loads | PASS |
| T08–T10 | valid RGB CAM; grayscale replicated; dims match input | PASS |
| T11–T12 | finite in [0,1]; non-negative for all 5 classes | PASS |
| T13–T15 | determinism; default = predicted class; class-specific | PASS |
| T16–T18 | blank image finite; NaN image throws; bad class throws | PASS |
| T19–T20 | non-constant on real image; overlay resize correct | PASS |

CSV + `.mat` saved to `results/phase20b3_validation/`.

## M. Diagnostic Outputs

`matlab/validation/generatePhase20B3Diagnostics.m` → `results/demo/gradcam/`
(21 files, fixed deterministic names, validation-split images only — never
`test.csv`):

- `gradcam_before_after.png` — uniform-noise placeholder vs genuine G2 CAM
  (spatially coherent focus, verified visually).
- Per image (5×): `_orig`, `_raw` (pre-normalization ReLU CAM), `_norm`,
  `_overlay` (grade + probability legend, "attention aid, not a diagnosis").
- All 5 validation images predicted G2 by the frozen classifier (model
  behavior reported as-is; no claim made about correctness).

## N. Remaining Limitations

1. **Coarse resolution.** 7×7 source grid cannot localize small lesions
   (e.g. individual microaneurysms); absence of focus ≠ absence of disease.
2. **Attention ≠ causation.** High-attention regions are where the model is
   sensitive, not certified pathology.
3. **Low-confidence maps still render.** A G2-at-28.7% map is shown with its
   probability, but users may overweight any visualization.
4. **`gradcam.m` remains broken** (untouched, unused); future workers must
   not resurrect it without fixing the detached-graph bug.
5. **No clinical validation** of Grad-CAM as lesion localization (see O).

## O. Explicit Non-Validation Statement

**Grad-CAM here is NOT clinically validated lesion localization.** The test
suite verifies algorithmic integrity (determinism, class-specificity,
correct math, honest failure) — not medical meaning. No
sensitivity/specificity/AUC is reported in this phase; the Phase 8/17
classification baseline is unchanged and untouched.

---

## Files Modified

| File | Change |
|------|--------|
| `matlab/explainability/gradcamSimple.m` | Exact head gradients with ReLU masks; ReLU-before-normalization; input/layer/class/NaN checks; `LayerName` option; interface `[cam,predClass,scores]` preserved |
| `matlab/demo/drScreeningGUIv2.m` | Removed `rand(224,224)`; genuine Grad-CAM in report path (fail-safe `[]`); new Show Heatmap action (original/CAM/overlay + class + disclaimer); fixed Export/Reset button overlap |
| `matlab/clinical/report/validateClinicalReport.m` | One-line fixture: `rand(224,224)` → deterministic `mat2gray(peaks(224))` (test data only, never displayed) |

## Files Created

| File | Purpose |
|------|---------|
| `matlab/validation/validatePhase20B3.m` | 20-test suite (20/20 PASS executed) |
| `matlab/validation/generatePhase20B3Diagnostics.m` | Before/after + 5-image diagnostic generator |
| `docs/PHASE20B3_GRADCAM_GUI_FIX.md` | This document |
| `results/demo/gradcam/` (21 files) | Executed diagnostic outputs |
| `results/phase20b3_validation/` | Executed validation logs |
