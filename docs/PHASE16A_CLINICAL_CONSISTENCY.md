# Phase 16A: Clinical Consistency & Quality Gating

**Status:** Complete
**Commit:** Pending

## Overview

Phase 16A fixes clinical logic inconsistencies identified in the production GUI:

1. **Quality gating** — POOR images are now rejected with recapture guidance
2. **Referable consistency** — Only G2+ is referable (per SIH definition)
3. **Lesion-classifier consistency** — Inconsistencies are flagged as warnings
4. **Confidence classification** — LOW/MEDIUM/HIGH instead of raw percentage

## Clinical Logic Rules

### Rule 1: Quality Gating

```
Quality = POOR → REJECT
  Status: UNGRADABLE
  Action: Recapture with improved illumination, focus, field of view
  No clinical classification performed
```

### Rule 2: Referable Consistency (SIH Definition)

```
G0 → NON-REFERABLE
G1 → NON-REFERABLE
G2 → REFERABLE
G3 → REFERABLE
G4 → REFERABLE
```

**Note:** This replaces the previous probability-based threshold (0.1951) with a grade-based rule.

### Rule 3: Lesion-Classifier Consistency

| Condition | Consistency | Warning |
|-----------|-------------|---------|
| G0 with >5 MA, >2 Hem, >3 Exu, or NV | MINOR/MAJOR | "Grade X but Y lesions detected" |
| G3/G4 with no lesions | MINOR | "Grade X but no lesion evidence" |
| G0/G1 with >10 total lesions | MINOR | "Grade X but Y total lesions" |

### Rule 4: Confidence Classification

| Max Probability | Level |
|-----------------|-------|
| ≥ 0.7 | HIGH |
| ≥ 0.4 | MEDIUM |
| < 0.4 | LOW |

## Files

```
matlab/clinical/
├── applyClinicalLogic.m        # Clinical decision engine
├── validatePhase16A.m          # 10-test validation suite

matlab/demo/
├── drScreeningGUIv2.m          # Updated with clinical logic
└── runDRScreening.m            # Updated with clinical logic

docs/
└── PHASE16A_CLINICAL_CONSISTENCY.md
```

## Validation Results

| # | Test | Status |
|---|------|--------|
| 1 | Clinical logic function exists | PASS |
| 2 | Poor quality image rejected | PASS |
| 3 | Good quality image graded | PASS |
| 4 | G0 is non-referable | PASS |
| 5 | G2 is referable | PASS |
| 6 | Confidence level classification | PASS |
| 7 | Lesion-classifier consistency (consistent) | PASS |
| 8 | Lesion-classifier inconsistency detected | PASS |
| 9 | API works with clinical logic | PASS |
| 10 | Recommendation generation | PASS |

**Result: 10/10 PASS**

## How It Works

### Before Phase 16A

```
Grade 0 + Referable: YES + 43 MA + Severe evidence
```

### After Phase 16A

```
Grade 0 → Referable: NO
Confidence: 25% (LOW)
Consistency: MAJOR_INCONSISTENCY
Warning: "Grade 0 but 43 microaneurysms detected"
Recommendation: "Routine follow-up. Note: AI result is inconsistent..."
```

### Poor Quality Image

```
Status: UNGRADABLE
Recommendation: "Image quality insufficient. Please recapture..."
No clinical classification performed
```

## How to Run

```matlab
% Run validation
v = validatePhase16A('Verbose', true);

% Launch GUI
drScreeningGUIv2();

% Run API
result = runDRScreening('path/to/fundus.jpg');
```

## What Is NOT in Phase 16A

- **No model retraining** — frozen at `cc7bed8`
- **No test-set re-evaluation** — using existing results
- **No clinical claims** — internal evaluation only

## SIH Traceability

| SIH Requirement | Evidence |
|-----------------|----------|
| Image quality gating | POOR → RECAPTURE |
| Consistent referable decision | G2+ only |
| Clinical interpretability | Consistency warnings |
| Honest confidence | LOW/MED/HIGH classification |
| Recommendation generation | Context-aware recommendations |
