# Phase 23: Clinical Ground-Truth & Evaluation Framework

## Executive Summary

Phase 23 mapped the current annotation landscape, defined clinical evaluation metrics, and identified critical gaps that must be filled before clinical deployment. The central finding:

> **We have 4,075 grade-labeled images but only 81 images with lesion masks (1.0% of total). The current evaluation proves software correctness, not clinical correctness.**

---

## 1. Current Annotation Landscape

### Dataset Composition

| Dataset | Total Images | With DR Grade | With Lesion Masks | With Vessel Masks |
|---------|-------------|---------------|-------------------|-------------------|
| APTOS2019 | 5,590 | 3,662 (65.5%) | **0 (0.0%)** | 0 |
| IDRiD | 494 | 413 (83.6%) | **81 (16.4%)** | 0 |
| DRIVE | 40 | 0 | 0 | 40 (100%) |
| Messidor-2 | 1,748 | 0 | 0 | 0 |
| **Total** | **7,872** | **4,075** | **81** | **40** |

### Grade Distribution

| Grade | APTOS2019 | IDRiD | Total |
|-------|-----------|-------|-------|
| G0 (No DR) | 1,805 | 168 | 1,973 |
| G1 (Mild NPDR) | 370 | 23 | 393 |
| G2 (Moderate NPDR) | 999 | 122 | 1,121 |
| G3 (Severe NPDR) | 193 | 66 | 259 |
| G4 (PDR) | 295 | 34 | 329 |

**G1 is severely underrepresented** — only 4.8% of IDRiD training data is G1.

### Lesion Annotation Coverage

**IDRiD provides lesion masks for 81 images** (54 training + 27 testing):

| Lesion Type | Available | Coverage |
|-------------|-----------|----------|
| MA (Microaneurysms) | 81 | 100% of segmentation set |
| HE (Hemorrhages) | 80 | 98.8% |
| EX (Hard Exudates) | 81 | 100% |
| SE (Soft Exudates) | 40 | **49.4%** |
| OD (Optic Disc) | 81 | 100% |

**Critical gap:** SE masks exist for only 40 of 81 images. Soft exudates (cotton wool spots) are clinically important markers of retinal ischemia.

### Quality Annotations

| Status | Count | Percentage |
|--------|-------|------------|
| GOOD | 1,348 | 17.1% |
| BORDERLINE | 6,192 | 78.7% |
| UNGRADABLE | 332 | 4.2% |

**All quality scores are algorithmic** — no clinician-verified quality labels exist.

---

## 2. Clinical Evaluation Metrics

### Five-Class Performance

| Grade | Sensitivity | Specificity | PPV | NPV | F1 |
|-------|------------|------------|-----|-----|-----|
| G0 | 96.6% | 94.3% | 94.1% | 96.7% | 95.3% |
| G1 | 49.2% | 97.3% | 65.9% | 94.7% | 56.3% |
| G2 | 82.7% | 85.6% | 68.5% | 92.9% | 74.9% |
| G3 | 25.6% | 97.6% | 41.7% | 95.1% | 31.7% |
| G4 | 44.9% | 97.5% | 61.1% | 95.3% | 51.8% |

### Binary Referable (G2-G4 vs G0-G1)

| Metric | Value |
|--------|-------|
| Sensitivity | 91.0% (233/256) |
| Specificity | 91.5% (325/355) |
| PPV | 88.6% |
| NPV | 93.4% |
| F1 | 89.8% |
| False negatives | 23 (missed referable cases) |
| False positives | 30 (unnecessary referrals) |

### Confidence-Stratified Performance

| Confidence Range | Images | Accuracy | Ref Sens | Ref Spec |
|-----------------|--------|----------|----------|----------|
| [0.00, 0.50) | 75 | 34.7% | 82.5% | 55.6% |
| [0.50, 0.70) | 97 | 53.6% | 86.8% | 51.7% |
| [0.70, 0.80) | 57 | 77.2% | 92.7% | 68.8% |
| [0.80, 0.90) | 52 | 78.8% | 100.0% | 88.9% |
| [0.90, 1.00) | 330 | 97.9% | 98.2% | 99.6% |

---

## 3. Ground Truth Assessment

### What We Have

| Annotation Type | Count | Source | Quality |
|----------------|-------|--------|---------|
| DR grade labels | 4,075 | APTOS + IDRiD | Single-grader, protocol unknown |
| Lesion masks | 81 | IDRiD segmentation | Single-grader, partially complete |
| Vessel masks | 40 | DRIVE | Manual segmentation |
| Image quality | 7,872 | Algorithmic | NOT clinician-verified |

### What We Need (Clinical Grade)

| Requirement | Current State | Target |
|-------------|---------------|--------|
| Multi-reader DR grades | Single-grader only | 2-3 ophthalmologists, 200-500 images |
| Expert-verified lesion masks | 81 IDRiD images (1.0%) | 200-500 verified masks |
| Clinician-verified quality | Algorithmic only | Clinician quality grading |
| Difficult-case annotations | None | Expert-labeled ambiguous cases |
| External validation annotations | Messidor-2 available but unlabeled | 2+ external datasets with annotations |

---

## 4. Gap Analysis

### What Current Evaluation Can Prove

- Software behaves correctly (147/147 regression tests)
- Preprocessing is consistent (19/20 files, canonical pipeline)
- Lesion detectors follow programmed rules
- Classifier outputs probabilities (calibrated to ECE 0.033)
- Confidence routing works (92.9% accuracy at ≥0.70)

### What Current Evaluation Cannot Prove

- **Detected lesions are medically correct** — no expert-verified ground truth for APTOS images; IDRiD masks cover only 1.3% of training data
- **DR grades are accurate** — single-grader labels only; no inter-observer analysis; APTOS annotation protocol unknown
- **Image quality gate is clinically valid** — algorithmic scores, not clinician-verified
- **System generalizes** — no external validation with new annotations
- **Performance is acceptable for clinical use** — no clinical validation study; no comparison to expert performance

### Priority Gaps (Ranked by Clinical Risk)

| Priority | Gap | Impact |
|----------|-----|--------|
| HIGH | No multi-reader annotations | Cannot measure inter-observer variability |
| HIGH | No expert-verified lesion masks for APTOS | Lesion evidence is unvalidated |
| HIGH | No external validation | Generalizability unknown |
| MEDIUM | Quality gate not clinician-verified | May reject good images or accept bad ones |
| MEDIUM | No difficult-case annotations | Cannot set realistic performance bounds |
| LOW | No multi-center training data | Single-center bias possible |

---

## 5. Clinical Evaluation Framework

### Stage 1: Annotation Quality Assurance

- Recruit 2-3 board-certified ophthalmologists
- Independent annotation of 200-500 images
- Measure inter-observer agreement (Cohen kappa, Fleiss kappa)
- Establish consensus protocol for disagreements
- **Result:** Verified ground-truth set

### Stage 2: Lesion Mask Validation

- Expert verification of IDRiD masks (sample audit)
- New expert annotations for APTOS images (subset)
- Quantify detector accuracy against verified masks
- **Result:** Lesion detection performance metrics

### Stage 3: External Validation

- Messidor-2: 1,748 images (already available, external isolation)
- Additional datasets: DDR, DeepDR, EyePACS (if obtainable)
- Multi-camera testing (if possible)
- **Result:** Generalizability metrics

### Stage 4: Clinical Workflow Simulation

- Simulate review routing with clinician feedback
- Measure time-to-decision
- Assess false-negative impact (missed referable cases)
- Assess false-positive impact (unnecessary referrals)
- **Result:** Workflow integration metrics

### Stage 5: Comparison to Expert Performance

- Compare AI sensitivity/specificity to individual experts
- Identify cases where AI outperforms or underperforms experts
- **Result:** Relative performance assessment

---

## 6. Implications for Next Phases

### Phase 24: Dataset/Annotation Expansion

The evidence shows that the single most impactful next step is:

1. **Multi-reader annotation** of a 200-500 image subset
2. **Expert verification** of existing IDRiD masks
3. **New lesion annotations** for APTOS images (at least a subset)

Without this, any classifier improvements (Phase 25+) would be optimizing against unreliable labels.

### Phase 25: DR Classifier V2

Only justified AFTER Phase 24 establishes reliable ground truth. Key improvements:
- Class-aware loss (G1/G3/G4 weighting)
- Better augmentation
- Higher-resolution input
- Ordinal classification
- Independent validation set

### Phase 26: G2/G3/G4 Separation

The current confusion pattern (G1/G3/G4 → G2) is partly a data problem (G2 has 3× more samples than G3). Addressable through:
- Balanced sampling
- Oversampling G1/G3/G4
- Synthetic augmentation

### Phase 27: External Validation

Requires labeled external data. Messidor-2 has no DR grade labels in our current copy. Options:
- Use Messidor-2 original labels (if obtainable)
- New annotations for Messidor-2
- Additional datasets (DDR, DeepDR)

---

## Outputs

```
docs/PHASE23_CLINICAL_FRAMEWORK.md
results/phase23_clinical_framework/
    annotation_coverage.csv
    per_class_clinical_metrics.csv
    binary_referable_metrics.csv
    gap_analysis.csv
    grade_distribution.csv
```

## Disclaimers

> **Passing clinical metrics does not establish clinical validity.**

- All metrics apply to the validation set only
- Single-grader labels may contain systematic errors
- Lesion masks cover only 1% of total images
- External validation is required before deployment
- Clinical validation study is required before clinical use
