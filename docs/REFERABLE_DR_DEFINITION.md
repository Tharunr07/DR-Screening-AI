# Referable DR — Screening Endpoint Definition (Phase 1)

> **Documentation only.** No classifier is trained in Phase 1. No sensitivity/specificity is claimed. This endpoint is frozen for future evaluation (Phase 2+).

## Grading Taxonomy (Unified 5-class)

All datasets are normalized to the APTOS 2019 convention (Level 0–4):

| Level | Description | ICDR Equivalent |
|-------|-------------|-----------------|
| 0 | No DR | No apparent retinopathy |
| 1 | Mild (non-proliferative) | Mild NPDR |
| 2 | Moderate (non-proliferative) | Moderate NPDR |
| 3 | Severe (non-proliferative) | Severe NPDR |
| 4 | Proliferative DR | PDR |

Stored in manifest:

- `dr_grade` — numeric `0–4` or `NaN` if unavailable
- `dr_grade_original` — verbatim string from source (preserved for provenance)

## Screening Endpoint (Binary)

For the **future DR screening task** the intended endpoint is:

- **Non-referable**: Level `0` + Level `1`
- **Referable**: Level `2` + Level `3` + Level `4`

Formally:

```
referable = (dr_grade >= 2)
threshold = 2
```

Implemented in:

- `datasetConfig.m`: `cfg.referableThreshold = 2`, `cfg.referableGrades = [2,3,4]`, `cfg.nonReferableGrades = [0,1]`
- `data/splits/split_metadata.json`: `referableDefinition: { nonReferable: [0,1], referable: [2,3,4], threshold: 2 }`

### Why this threshold

- Matches common screening programs where **moderate or worse** warrants referral to ophthalmology.
- Mild NPDR (Level 1) alone is typically monitored, not urgently referred, in many guidelines.
- Severe / proliferative disease must always be captured as referable.

### Stable across datasets

Any dataset using a different original scale (e.g., Messidor 0–3 or binary) must be **mapped with an explicit conversion table** documented alongside the mapping. No silent remapping.

## Evaluation Implications (Future, Not Now)

When a classifier is eventually trained (Phase 3+), evaluation will report:

- Primary: **sensitivity / specificity** at the referable threshold (≥2), with confidence intervals.
- Secondary: 5-class accuracy / quadratic-weighted kappa / per-class recall (for grading fidelity).

**Phase 1 makes no such claims.** This document only records the definition.

## Quality Handling

`quality_status = UNKNOWN` for all images in Phase 1. Future quality gating (ungradable exclusion) will be documented separately and will interact with referral: ungradable images are typically referred by policy, but that workflow is out of scope for Phase 1.

## Provenance Note

- APTOS grades are the canonical reference for this taxonomy.
- IDRiD DR grading follows the same 0–4 ICDR convention (with edema grading separate).
- DRIVE has no DR grades — referable definition does not apply (vessel dataset).
- Messidor-2 grades, if available, will need scale mapping recorded in `MESSIDOR2_EXTERNAL_VALIDATION.md`.

## Do NOT Do in Phase 1

- Do not train a classifier.
- Do not calibrate a decision threshold.
- Do not claim sensitivity, specificity, AUROC, or clinical performance.
- Do not derive quality thresholds.

These belong to later phases.
