# Phase 24: Clinical Ground-Truth Protocol

## 1. Overview

Phase 24 establishes the clinical ground-truth dataset required before any model retraining (Phase 25) or external validation (Phase 27). It defines the annotation protocol, not the annotation software.

### Objectives

1. Create a **multi-reader annotated dataset** of 1,000 fundus images with DR grades
2. Create **expert-verified lesion masks** for 500 of those images
3. Measure **inter-observer agreement** among 3 ophthalmologists
4. Establish **adjudicated reference labels** for all annotated images
5. Define **data splits** that prevent leakage between development and evaluation

### Scope

| Component | Count | Readers | Purpose |
|-----------|-------|---------|---------|
| DR grading cohort | 1,000 images | 3 ophthalmologists | Five-class DR grade ground truth |
| Lesion annotation cohort | 500 images | 3 ophthalmologists | Pixel-level lesion masks |

### What Phase 24 Is NOT

- Phase 24 does NOT modify the frozen classifier
- Phase 24 does NOT tune any model parameters
- Phase 24 does NOT replace the existing validation set
- Phase 24 creates an INDEPENDENT evaluation resource

---

## 2. Dataset Inventory & Licensing

### Available Datasets

| Dataset | License | DR Grades | Lesion Masks | Can Annotate? | Can Publish? |
|---------|---------|-----------|-------------|---------------|--------------|
| APTOS2019 | Kaggle TOS | Yes (0-4) | No | Yes | Yes (no redistribution) |
| IDRiD | CC-BY-4.0 | Yes (0-4) | Yes (MA/HE/EX/SE/OD) | Yes | Yes (attribution required) |
| DRIVE | Challenge terms | No | Vessel masks only | Yes | Yes (with citation) |
| Messidor-2 | ADCIS license | **No labels** | No | External only | Yes (with compliance) |
| DDR | Not obtained | Unknown | Unknown | N/A | N/A |
| DeepDR | Not obtained | Unknown | Unknown | N/A | N/A |
| EyePACS | Not obtained | Unknown | Unknown | N/A | N/A |

### Licensing Requirements

**APTOS2019 (Kaggle TOS):**
- No image redistribution
- Must accept Kaggle competition rules
- Results can be published
- Images must not be committed to git

**IDRiD (CC-BY-4.0):**
- Attribution: Porwal, Pachade, Kokare
- Must retain copyright notice
- Must indicate modifications if any
- No additional downstream restrictions

### Recommendation

Use **APTOS2019 as the primary source** (3,662 labeled images available) and **IDRiD for lesion mask verification** (81 images with existing masks). This maximizes available images while respecting licenses.

---

## 3. Sampling Strategy

### 3.1 DR Grading Cohort (1,000 images)

**Stratified sampling** from APTOS2019 + IDRiD, excluding images already in existing val/test splits.

| Grade | Target | Percentage | Rationale |
|-------|--------|------------|-----------|
| G0 | 200 | 20% | Balanced representation |
| G1 | 200 | 20% | Enriched from 9.6% to 20% (currently underrepresented) |
| G2 | 250 | 25% | Largest confusion group; needs more data |
| G3 | 150 | 15% | Enriched from 6.3% to 15% (currently underrepresented) |
| G4 | 200 | 20% | Enriched from 8.1% to 20% (currently underrepresented) |

**Total: 1,000 images**

### 3.2 Lesion Annotation Cohort (500 images)

**Enriched for pathology** — pathological grades are overrepresented.

| Grade | Target | Percentage | Rationale |
|-------|--------|------------|-----------|
| G0 | 50 | 10% | Controls only |
| G1 | 100 | 20% | Lesion-rich cases |
| G2 | 150 | 30% | Most confusion group |
| G3 | 100 | 20% | Severe pathology |
| G4 | 100 | 20% | Proliferative cases |

**Total: 500 images**

### 3.3 Sampling Exclusions

The following images are EXCLUDED from sampling:
- All images in existing `val.csv` (612 images)
- All images in existing `test.csv` (612 images)
- All images in existing `train.csv` (4,286 images)
- All Messidor-2 images (external-only)

This ensures the Phase 24 cohort is **completely independent** of all existing model development.

### 3.4 Cohort Composition

Based on sampling run (seed=42):

| Source | Grading Cohort | Lesion Cohort |
|--------|---------------|---------------|
| APTOS2019 | 895 (89.5%) | ~445 |
| IDRiD | 105 (10.5%) | ~55 |

### 3.5 Sampling Files

```
results/phase24_clinical_ground_truth/
    phase24_cohort.csv              # 1,000 images for DR grading
    phase24_lesion_cohort.csv       # 500 images for lesion masks
    phase24_sampling_report.txt     # Detailed sampling report
```

---

## 4. Annotation Protocols

### 4.1 DR Grading Protocol (All 1,000 Images)

**Task:** Assign a DR grade (0-4) to each fundus image.

**Instructions to Readers:**

```
For each fundus image, assign ONE of the following grades:

G0 - No diabetic retinopathy
    No visible DR lesions (no microaneurysms, hemorrhages, exudates,
    or neovascularization attributable to DR).

G1 - Mild non-proliferative diabetic retinopathy (NPDR)
    At least one microaneurysm, but no other lesions.
    No hemorrhages, hard exudates, cotton wool spots, or IRMA.

G2 - Moderate NPDR
    More than just microaneurysms.
    May include: hemorrhages, cotton wool spots, hard exudates,
    venous beading, IRMA.
    BUT: fewer than the features of severe NPDR.

G3 - Severe NPDR
    Any of the following (4-2-1 rule):
    - Hemorrhages in 4 quadrants
    - Venous beading in 2+ quadrants
    - IRMA in 1+ quadrants
    (But NO neovascularization)

G4 - Proliferative diabetic retinopathy (PDR)
    Neovascularization AND/OR vitreous/preretinal hemorrhage.
```

**Additional fields per image:**

| Field | Type | Description |
|-------|------|-------------|
| `dr_grade` | Integer 0-4 | Primary DR grade |
| `referable` | Boolean | G2-G4 = referable |
| `reader_confidence` | 1-5 | 1=very uncertain, 5=very confident |
| `image_quality` | 1-5 | 1=uninterpretable, 5=excellent |
| `notes` | Free text | Optional: rationale, ambiguity notes |

### 4.2 Lesion Annotation Protocol (500 Images)

**Task:** Draw pixel-level segmentation masks for 4 lesion types.

**Lesion Types:**

| Lesion | Abbreviation | Description | Color |
|--------|-------------|-------------|-------|
| Microaneurysms | MA | Small red dots (<125μm), round or oval | Red |
| Hemorrhages | HE | Larger red blotches, flame-shaped or dot-blot | Blue |
| Hard Exudates | EX | Bright yellow/white deposits with sharp margins | Green |
| Neovascularization | NV | Abnormal new vessel growth, fine networks | Yellow |

**Instructions to Readers:**

```
For each image, create binary masks (255 = lesion, 0 = background) for:
1. Microaneurysms (MA): Small red dots, typically <125μm diameter.
   May appear as single dots or clusters.
2. Hemorrhages (HE): Larger red lesions. Flame-shaped (along nerve fibers)
   or dot-blot (deeper). Generally >125μm.
3. Hard Exudates (EX): Bright yellow/white deposits with sharp, well-defined
   margins. Often arranged in circinate patterns around leaking vessels.
4. Neovascularization (NV): Fine, irregular vessel networks. Often near
   the disc or elsewhere on the retina. May appear as fronds or fans.

Additional fields per image:
- image_quality: 1-5 scale
- notes: Optional notes on difficult cases
```

**Quality Requirements:**
- Masks must be drawn on the ORIGINAL resolution image
- Binary masks (uint8, values 0 and 255)
- Saved as PNG files with matching filenames
- One mask file per lesion type per image

### 4.3 Annotation Schema

**DR Grading CSV:**

```csv
image_id,reader_id,dr_grade,referable,reader_confidence,image_quality,notes,timestamp
APTOS_train_001,R1,2,true,4,5,,2026-09-15T10:30:00Z
APTOS_train_001,R2,2,true,5,5,,2026-09-15T10:32:00Z
APTOS_train_001,R3,3,true,3,4,possible NV near disc,2026-09-15T10:35:00Z
```

**Lesion Mask CSV:**

```csv
image_id,reader_id,lesion_type,mask_path,area_pixels,centroid_x,centroid_y,timestamp
APTOS_train_002,R1,MA,masks/R1/APTOS_train_002_MA.png,1234,456,789,2026-09-15T11:00:00Z
```

**Consensus CSV:**

```csv
image_id,dr_grade_consensus,referable_consensus,agreement_level,n_readers,disagreement_flag,adjudicator,timestamp
APTOS_train_001,2,true,partial,3,YES,Dr_Smith,2026-09-20T14:00:00Z
```

---

## 5. Three-Reader Workflow

### 5.1 Reader Requirements

- **Minimum 3 board-certified ophthalmologists** per image
- **Independent annotation** — readers must NOT discuss cases with each other
- **Blind annotation** — readers see ONLY the fundus image, no patient info, no other readers' grades
- **Training round** — each reader completes 20 practice cases before starting

### 5.2 Annotation Workflow

```
Phase 1: Independent Annotation
    Reader 1 ──► Grade 1,000 images + lesion masks (500)
    Reader 2 ──► Grade 1,000 images + lesion masks (500)
    Reader 3 ──► Grade 1,000 images + lesion masks (500)

Phase 2: Agreement Analysis
    Calculate inter-reader agreement (Cohen kappa, Fleiss kappa)
    Identify discordant cases (where readers disagree)

Phase 3: Adjudication
    Discordant cases → Senior ophthalmologist reviews
    Creates consensus/adjudicated reference label
    Documents disagreement rationale

Phase 4: Final Dataset
    Adjudicated labels → locked reference standard
    Split into development / validation / locked_test
```

### 5.3 Adjudication Rules

**Agreement Levels:**

| Level | Definition | Action |
|-------|-----------|--------|
| **Full agreement** | All 3 readers assign same grade | Use majority grade as reference |
| **Partial agreement** | 2 of 3 readers agree | Use majority grade; flag for review |
| **Disagreement** | All 3 readers differ | Adjudicator decides; document rationale |

**Adjudication Process:**
1. Adjudicator is a senior ophthalmologist (not one of the 3 readers)
2. Adjudicator sees: the fundus image + all 3 readers' grades + confidence scores
3. Adjudicator assigns final grade + rationale
4. All adjudication decisions are logged with timestamps

**Lesion Mask Adjudication:**
1. For each lesion type, compare masks across 3 readers
2. Compute Dice coefficient between each pair of readers
3. Create consensus mask: pixel is "lesion" if ≥2 of 3 readers marked it
4. Discordant regions → adjudicator reviews

### 5.4 Inter-Reader Agreement Metrics

| Metric | What It Measures | Target |
|--------|-----------------|--------|
| Cohen's kappa (pairwise) | Agreement between 2 readers | κ ≥ 0.6 (substantial) |
| Fleiss' kappa (overall) | Agreement among 3 readers | κ ≥ 0.6 (substantial) |
| Percentage agreement | Raw agreement rate | ≥ 80% |
| Disagreement rate | Cases needing adjudication | ≤ 20% |
| Dice coefficient (lesions) | Mask overlap between readers | ≥ 0.7 |

**If κ < 0.4 (fair):** Re-train readers, review protocol, consider adding a 4th reader.

---

## 6. Data Splits & Locking

### 6.1 Split Allocation

The 1,000-image cohort is split BEFORE annotation begins:

| Split | Count | Percentage | Purpose |
|-------|-------|------------|---------|
| **Development** | 500 | 50% | Model training and development |
| **Validation** | 250 | 25% | Hyperparameter tuning, early stopping |
| **Locked Test** | 250 | 25% | Final evaluation — NEVER tuned against |

### 6.2 Split Assignment

- Random assignment with seed=42 (deterministic)
- Stratified by DR grade (same proportions as cohort)
- **Locked Test split is sealed** — no one involved in model development may access it until final evaluation

### 6.3 Data Locking Protocol

```
LOCKED TEST SET PROCEDURE:

1. Generate split assignment (seed=42)
2. Write locked_test IDs to: results/phase24_clinical_ground_truth/LOCKED_TEST_IDS.txt
3. Compute SHA256 hash of the file
4. Record hash in: results/phase24_clinical_ground_truth/LOCKED_TEST_HASH.txt
5. Store original images in: data/phase24_locked_test/
6. NO ONE accesses locked_test during Phase 25-26 development
7. Locked test evaluation happens ONLY at the end of Phase 26
```

### 6.4 Leakage Prevention

- Phase 24 cohort excludes ALL images in existing train/val/test splits
- Phase 24 annotations are NEVER used for model tuning
- Locked test IDs are hashed and sealed
- Any code that touches locked_test must be reviewed and approved

---

## 7. Image Quality Assessment

### 7.1 Quality Grading

Each reader also rates image quality:

| Score | Label | Description |
|-------|-------|-------------|
| 5 | Excellent | Sharp focus, good illumination, full FOV, no artifacts |
| 4 | Good | Minor issues but fully interpretable |
| 3 | Adequate | Some quality issues, still interpretable |
| 2 | Poor | Significant quality issues, partially interpretable |
| 1 | Uninterpretable | Cannot reliably grade DR |

### 7.2 Quality Thresholds

- **Minimum for inclusion:** Average reader quality score ≥ 2.5
- **Flag for review:** Any reader assigns score 1
- **Quality disagreement:** If scores differ by ≥2 points, adjudicate

### 7.3 Quality Annotations Feed Into

- Calibration of the existing algorithmic quality gate
- Understanding which images the model struggles with
- Setting realistic performance expectations by quality tier

---

## 8. Acceptance Criteria for Phase 24

Phase 24 is COMPLETE when ALL of the following are true:

### 8.1 Annotation Quality

| Criterion | Threshold | Status |
|-----------|-----------|--------|
| DR grading completed | 1,000 images × 3 readers | Pending |
| Lesion masks completed | 500 images × 3 readers | Pending |
| Inter-reader kappa (DR grade) | κ ≥ 0.6 | Pending |
| Disagreement rate (DR grade) | ≤ 20% | Pending |
| Adjudication completed | All discordant cases | Pending |
| Dice coefficient (lesion masks) | ≥ 0.7 between readers | Pending |

### 8.2 Data Integrity

| Criterion | Threshold | Status |
|-----------|-----------|--------|
| No overlap with existing val/test | 0 images | ✅ Verified |
| Split assignment sealed | Hash recorded | Pending |
| Locked test access controlled | No access during dev | Pending |
| Annotation schema consistent | All fields populated | Pending |

### 8.3 Documentation

| Criterion | Description | Status |
|-----------|-------------|--------|
| Protocol document | This document | ✅ Complete |
| Sampling report | Generated by cohort script | ✅ Complete |
| Reader instructions | Grading + lesion protocols | ✅ Complete |
| Adjudication log | All decisions recorded | Pending |
| Final dataset documentation | Once annotation complete | Pending |

---

## 9. Audit Trail

Every annotation action is logged:

```json
{
  "action": "annotation",
  "image_id": "APTOS_train_001",
  "reader_id": "R1",
  "task": "dr_grading",
  "value": 2,
  "confidence": 4,
  "timestamp": "2026-09-15T10:30:00Z",
  "duration_seconds": 45,
  "session_id": "S001"
}
```

This enables:
- Tracking reader performance over time
- Identifying fatigue effects
- Quality assurance
- Reproducibility

---

## 10. De-identification & Privacy

### 10.1 Data Handling

- All images are de-identified by design (no patient names, IDs, or dates in images)
- Image filenames use anonymous identifiers
- No patient metadata is stored alongside annotations
- Compliance with institutional data governance policies

### 10.2 Storage

- All annotation data stored locally (no cloud upload without approval)
- Access restricted to authorized research personnel
- Backup according to institutional IT policies

### 10.3 Publication

- No individual patient data will be published
- Only aggregate statistics and de-identified examples
- Proper attribution to dataset creators (APTOS, IDRiD)

---

## 11. Version Control

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-09-04 | Initial protocol |

### Dataset Versioning

Once annotation is complete, the dataset will be versioned:

```
phase24_ground_truth/
    v1.0/
        phase24_cohort.csv
        phase24_lesion_cohort.csv
        annotations/
            grading/
                R1_grading.csv
                R2_grading.csv
                R3_grading.csv
            lesions/
                R1/
                R2/
                R3/
        consensus/
            grading_consensus.csv
            lesion_consensus/
        locked_test/
            LOCKED_TEST_IDS.txt
            LOCKED_TEST_HASH.txt
```

---

## 12. Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Low inter-reader agreement | Labels unreliable | Re-train readers, add 4th reader, revise protocol |
| Reader fatigue | Quality degrades | Limit to 100 images/session, require breaks |
| Annotation tool issues | Delay | Have backup manual annotation plan |
| Insufficient G1/G3 images | Stratification fails | Expand search to additional datasets |
| Licensing restrictions | Cannot publish | Clarify license terms before starting |
| Adjudicator bias | Reference labels biased | Use blinded adjudication, document rationale |

---

## Outputs

```
docs/PHASE24_CLINICAL_GROUND_TRUTH_PROTOCOL.md
matlab/validation/phase24_cohort_sampling.py
results/phase24_clinical_ground_truth/
    phase24_cohort.csv
    phase24_lesion_cohort.csv
    phase24_sampling_report.txt
```

## Next Steps

1. **Implement annotation tool** (Phase 24 tooling — separate from this protocol)
2. **Recruit 3 ophthalmologists** (requires institutional contacts)
3. **Run training round** (20 practice cases per reader)
4. **Execute annotation** (Phase 24A: grading, Phase 24B: lesions)
5. **Compute inter-reader agreement** (post-annotation analysis)
6. **Adjudicate disagreements** (senior ophthalmologist review)
7. **Seal locked test set** (hash + isolate)
8. **Proceed to Phase 25** (classifier V2 retraining, if ground truth is reliable)
