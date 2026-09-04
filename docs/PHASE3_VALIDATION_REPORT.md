# Phase 3 — Validation Report

**Date**: 2026-08-31
**Test Suite**: `testPhase3Pipeline.m` (12 synthetic cases)
**Real Data**: DRIVE (40 images), IDRiD (494 images)

---

## 1. Synthetic Test Results

| # | Test Case | Status | Notes |
|---|-----------|--------|-------|
| 1 | Normal RGB fundus | PASS | OD detected, vessel area > 0 |
| 2 | Low-quality blurred | PASS | Structure completes, OD may miss |
| 3 | Grayscale input | PASS | Converts to grayscale, OD detected |
| 4 | RGB input | PASS | Normal processing path |
| 5 | Missing image | PASS | Returns UNREADABLE, no crash |
| 6 | Corrupted image | PASS | Returns UNREADABLE with full field contract |
| 7 | No retinal field (black) | PASS | FOV detection returns POOR, pipeline continues |
| 8 | Optic disc detection | PASS | OD detected on bright disc image |
| 9 | Vessel segmentation | PASS | Vessel area fraction > 0, structure COMPLETED |
| 10 | Lesion candidates | PASS | Lesion candidates detected on dark spot image |
| 11 | Small image (64×64) | PASS | Resized, no crash |
| 12 | Overexposed image | PASS | Structure completes |

**Result**: 12/12 PASS

---

## 2. Real Data: DRIVE (Vessel Validation)

| Metric | Value |
|--------|-------|
| Images processed | 40/40 |
| Total runtime | 17.8s |
| Per-image runtime | 0.445s |
| Structure completed | 40/40 (100%) |
| Lesion completed | 40/40 (100%) |
| Vessel area fraction (mean) | 0.145 |
| Vessel area fraction (median) | 0.140 |
| Vessel density (mean) | 0.099 |
| OD detected | 40/40 (100%) |
| Fovea detected | 40/40 (100%) |

**Note**: Vessel area fraction of ~14% is consistent with retinal vasculature occupying 10-20% of the retinal area. Full Dice/sensitivity validation against DRIVE manual annotations is deferred to a future iteration.

---

## 3. Real Data: IDRiD (Lesion Validation)

| Metric | Value |
|--------|-------|
| Images processed | 494/494 |
| Total runtime | 183.0s |
| Per-image runtime | 0.370s |
| Structure completed | 494/494 (100%) |
| Lesion completed | 494/494 (100%) |
| OD detected | 480/494 (97.2%) |
| Fovea detected | 480/494 (97.2%) |
| MA candidates (total) | 26,475 |
| MA candidates (mean/img) | 53.6 |
| HE candidates (total) | 5,656 |
| HE candidates (mean/img) | 11.4 |
| EX candidates (total) | 520 |
| EX candidates (mean/img) | 1.1 |
| NV candidates | 0 |

**Note**: High MA/HE counts reflect raw candidate detection (not clinically confirmed lesions). These outputs are intended as features for Phase 4 classifier input, not as standalone diagnostic counts. Full lesion-level validation against IDRiD annotations is deferred.

---

## 4. Pass/Fail Criteria

| Criterion | Target | Actual | Status |
|-----------|--------|--------|--------|
| Synthetic tests | 12/12 | 12/12 | PASS |
| DRIVE processing | 40/40 | 40/40 | PASS |
| IDRiD processing | 494/494 | 494/494 | PASS |
| No crashes on edge cases | 0 | 0 | PASS |
| Field contract (all fields present) | All | All | PASS |
| Per-image runtime < 2s | < 2s | 0.4s | PASS |

---

## 5. Known Issues / Future Work

1. **Vessel Dice/sensitivity not computed** — requires pixel-level comparison against DRIVE manual masks
2. **Lesion precision/recall not computed** — requires pixel-level comparison against IDRiD annotations
3. **OD detection misses** — 14/494 IDRiD images missed (2.8%); may be edge cases with unusual OD appearance
4. **All thresholds are PROVISIONAL** — not clinically validated
5. **NV detection has no ground truth** — research prototype evidence module
