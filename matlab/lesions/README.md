# matlab/lesions/ — Phase 3: Lesion Candidate Detection

**Status: IMPLEMENTED**

Microaneurysm, hemorrhage, exudate, and neovascularization candidate detection.
See `docs/PHASE3_IMPLEMENTATION_REPORT.md`.

## Modules

| File | Purpose |
|------|---------|
| `detectMicroaneurysms.m` | MA candidate detection (green channel + morphology) |
| `detectHemorrhages.m` | HE candidate detection (dark region + morphology) |
| `detectExudates.m` | EX candidate segmentation (bright + local contrast + OD exclusion) |
| `detectNeovascularization.m` | NV candidate detection (vessel density + tortuosity) |

## Validation

- DRIVE: vessel segmentation metrics
- IDRiD: lesion detection metrics (MA, HE, EX)
- Messidor-2: external observation only
- NV: no ground truth available (research prototype only)

## Threshold Status

All thresholds are PROVISIONAL / THEORETICAL. Not clinically validated.
