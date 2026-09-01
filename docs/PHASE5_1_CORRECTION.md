# Phase 5.1 — Explainability Correction + Robustness Fix

## Summary

Phase 5.1 corrects two confirmed bugs in Phase 5 and adds mask persistence infrastructure.

## Bugs Fixed

### BUG-001: Odd-Dimension Panel Failure
- **Before**: 31/612 images failed during evidence-panel generation
- **Root cause**: 2×2 panel construction failed when image height or width was odd
- **Fix**: Padding-based dimension normalization before panel construction
- **Result**: 0/612 failures

### BUG-002: Synthetic Lesion Placement
- **Before**: Lesion overlays used `rng(42)` and `rand()` to generate random circles
- **Root cause**: Phase 3 binary masks were not persisted to disk
- **Fix**:
  1. Created `persistPhase3Masks.m` to save real binary masks as MAT files
  2. Created `loadPhase3Masks.m` to load persisted masks
  3. Re-ran Phase 3 for 920 test images (all persisted, 0 failed)
  4. Rewrote `generateLesionOverlay.m`, `generateAttentionMap.m`, `generateEvidenceOverlay.m` to load real masks from disk
- **Result**: All overlays use real Phase 3 detected masks

## Architecture

### Mask Persistence
```
results/phase3/mase3_masks/<dataset>/<dataset>_<imageId>.mat
```

Each MAT file contains:
- `maMask` — binary microaneurysm mask
- `heMask` — binary hemorrhage mask
- `exMask` — binary exudate mask
- `vesselMask` — binary vessel mask
- `fovMask` — binary FOV mask
- `imgHeight`, `imgWidth` — source dimensions

### Per-Artifact Failure Decoupling
Each artifact is now generated independently:
1. Lesion overlay
2. Structure overlay
3. Evidence panel
4. Heatmap
5. Report
6. Human review JSON

A failure in one artifact does not suppress other artifacts.

### Evidence Provenance
Human review JSON includes:
- `lesion_mask_source: REAL_PHASE3_MASK`
- `lesion_localization_status: REAL_PHASE3_MASK`
- `mask_validation_status: VALIDATED`

## Test Results

### Synthetic Tests: 15/15 PASS
1. Even dimensions — PASS
2. Odd height — PASS
3. Odd width — PASS
4. Odd both — PASS
5. Real binary mask — PASS
6. Empty mask — PASS
7. Mismatched dimensions — PASS
8. Missing mask — PASS
9. MA overlay only — PASS
10. HE overlay only — PASS
11. EX overlay only — PASS
12. NV unavailable — PASS
13. No synthetic placement — PASS
14. Independent failure handling — PASS
15. Provenance fields — PASS

### Real Test Set: 612/612 SUCCESS
- Lesion overlay: 612 success, 0 failed, 0 unavailable
- Structure overlay: 612 success, 0 failed
- Evidence panel: 612 success, 0 failed
- Heatmap: 612 success, 0 failed, 0 unavailable
- Report: 612 success, 0 failed
- Review JSON: 612 success, 0 failed

## Phase 4 Preservation

| Metric | Before | After | Status |
|--------|--------|-------|--------|
| Accuracy | 0.6324 | 0.6324 | ✓ UNCHANGED |
| Balanced Accuracy | 0.4607 | 0.4607 | ✓ UNCHANGED |
| Macro AUC | 0.8095 | 0.8095 | ✓ UNCHANGED |
| Referable AUC | 0.7741 | 0.7741 | ✓ UNCHANGED |
| Sensitivity | 0.7004 | 0.7004 | ✓ UNCHANGED |
| Specificity | 0.8479 | 0.8479 | ✓ UNCHANGED |

## Files Created

- `matlab/structures/persistPhase3Masks.m` — Save real Phase 3 masks
- `matlab/structures/loadPhase3Masks.m` — Load persisted masks
- `matlab/structures/persistPhase3TestMasks.m` — Re-run Phase 3 for test set with mask persistence
- `docs/PHASE5_1_CORRECTION.md` — This document

## Files Modified

- `matlab/explainability/generateLesionOverlay.m` — Real masks, returns status
- `matlab/explainability/generateAttentionMap.m` — Real masks, returns status
- `matlab/explainability/generateEvidenceOverlay.m` — Real masks, padding-based
- `matlab/explainability/generateHumanReviewReport.m` — Provenance fields
- `matlab/explainability/runPhase5Explainability.m` — Decoupled failures, no Phase 3 re-run
- `matlab/explainability/testExplainabilityPipeline.m` — 15 tests

## Limitations

1. **NV has no binary mask** — Neovascularization is a flag, not a spatial mask. Heatmaps return UNAVAILABLE when only NV is present.
2. **Calibration unchanged** — Brier=0.2621, ECE=0.1258. Not addressed in this phase.
3. **Clinical targets not met** — Sensitivity=70.04% (target >90%), Specificity=84.79% (target >85%).

## Git Commit

- Commit: `pending`
- Pushed: `pending`
