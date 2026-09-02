# DR-Screening-AI — Presentation Materials

## 1. Live Demo Flow (2-5 minutes)

### Setup (before demo)
```matlab
addpath(genpath('matlab'));
drScreeningGUI();
```

### Script

**[0:00-0:30] Introduction**
> "This is DR-Screening-AI, an end-to-end pipeline for automated diabetic retinopathy screening. It takes a fundus image, assesses quality, classifies DR severity, and generates a clinical report."

**[0:30-1:00] Load Model**
- Click "Load Model"
- > "The model is a transfer-learning ResNet-18, pre-trained on ImageNet and fine-tuned on 2,792 retinal images."

**[1:00-1:30] Upload Image**
- Click "Upload Fundus Image"
- Select `0151781fe50b.png` (Grade 0 - No DR)
- > "Quality assessment runs automatically — brightness, contrast, blur. This image is GOOD quality."

**[1:30-2:00] Run Screening**
- Click "Run DR Screening"
- > "The model classifies DR grade and referable status. Grade 0, non-referable, 78% confidence."

**[2:00-2:30] Show Probabilities**
- Point to bar chart
- > "Output shows probability distribution across all 5 grades. The model is confident this is no DR."

**[2:30-3:00] Show Heatmap**
- Click "Show Heatmap"
- > "Gradient-based attention shows where the model focuses — primarily the optic disc and vascular regions."

**[3:00-3:30] Show Report**
- Click "Show Report"
- > "Clinical report with grade, referable status, confidence, and disclaimer. Ready for ophthalmologist review."

**[3:30-4:00] Test Another Image**
- Upload `02685f13cefd.png` (Grade 4 - PDR)
- Run screening
- > "Grade 4 Proliferative DR detected, referable, with high confidence."

**[4:00-4:30] Error Handling**
- Try uploading a non-image file
- > "Graceful error handling — invalid inputs are caught and reported."

**[4:30-5:00] Conclusion**
- > "Complete pipeline: Detect → Analyze → Classify → Explain → Review. All on the frozen model with 97.7% sensitivity and 85.4% specificity."

---

## 2. Judge Q&A

### Q: What makes this different from just training a CNN?

**A:** We didn't just train a CNN. We built an evidence-based pipeline:
1. Started with interpretable handcrafted features (SVM baseline)
2. Audited its limitations (classification audit identified the bottleneck)
3. Tested native deep learning (overparameterized, low specificity)
4. Introduced transfer learning (ImageNet pretraining solved the small-data problem)
5. Preserved explainability and provenance throughout

The progression is defensible because the test set was frozen from Phase 1.

### Q: Why did transfer learning beat native ResNet?

**A:** Two reasons:
1. **Small dataset**: 2,792 training images for 11.5M parameters (4,119:1 ratio). Native ResNet overfit.
2. **ImageNet features**: Edge, texture, and shape detectors from natural images transfer well to retinal imaging. The pretrained features provided a better starting point than random initialization.

Result: specificity improved from 74.7% to 85.4% (+10.7%) while maintaining 97.7% sensitivity.

### Q: What about the IDRiD domain shift?

**A:** We documented it honestly:
- APTOS: sens=98.6%, spec=87.1%
- IDRiD: sens=91.9%, spec=59.1%

This is a real limitation. The model was trained primarily on Indian population data (APTOS). IDRiD (Indian dataset but different camera/protocol) shows lower specificity. External validation on diverse populations is needed before clinical deployment.

### Q: Is this clinically validated?

**A:** No. We state clearly: "The transfer-learning model achieved the predefined sensitivity (>90%) and specificity (>85%) targets on the held-out 612-image test set." This is a research prototype. Clinical validation requires prospective studies with diverse patient populations, which is beyond our current scope.

### Q: How do you handle class imbalance?

**A:** Three approaches:
1. **Class weights** in loss function (inverse frequency)
2. **Referable binary threshold** optimized on validation set
3. **Reporting balanced metrics** (not just accuracy)

Grade 3 (39 images) and Grade 4 (50) are severely underrepresented. Per-grade sensitivity reflects this: Grade 3 = 17.9%, Grade 4 = 38.0%.

### Q: What's the inference time?

**A:** ~1-2 seconds per image on CPU. Quality assessment + preprocessing + classification + report generation.

### Q: How do you ensure reproducibility?

**A:**
- Seed 42 for all random operations
- Frozen test set (612 images, never modified)
- Exact configuration documented in `REPRODUCIBILITY.md`
- Pretrained weights converted from PyTorch with fixed mapping
- All artifacts versioned with timestamps

### Q: What would you do differently?

**A:**
1. More diverse training data (multiple populations, cameras)
2. External validation on held-out datasets
3. Calibration training (ECE was 3.9%, could be better)
4. Grade-specific oversampling for rare classes

---

## 3. Transfer Learning Explanation

### Why Transfer Learning Works

```
ImageNet (1.2M images, 1000 classes)
    ↓
Pre-trained feature extractors:
  - Edge detectors (early layers)
  - Texture patterns (middle layers)
  - Complex shapes (late layers)
    ↓
Fine-tuned on retinal images:
  - Optic disc → edge features
  - Vessel patterns → texture features
  - Lesions → shape features
    ↓
Better initialization than random
    ↓
Faster convergence, better generalization
```

### Key Insight

Native ResNet started from random weights. With only 2,792 training images, it couldn't learn meaningful features from scratch. Transfer learning leverages features already learned from 1.2M ImageNet images, providing a much better starting point.

---

## 4. Domain-Shift Limitation

### What Happened

| Metric | APTOS | IDRiD | Gap |
|--------|-------|-------|-----|
| Sensitivity | 98.6% | 91.9% | -6.7% |
| Specificity | 87.1% | 59.1% | -28.0% |

### Why

1. **Different cameras**: APTOS used佳能, IDRiD used different equipment
2. **Different protocols**: Image acquisition, lighting, field of view
3. **Training imbalance**: APTOS dominates training set (2792 vs 494 images)
4. **Population differences**:虽 both Indian, subtle demographic variations

### How We Address It

- Documented honestly in Phase 8 audit
- Bootstrap CIs reported (specificity lower bound: 81.6%)
- Claim limited to "held-out test set" not "general population"
- Future work: multi-site training data

### What We Don't Do

- Don't claim the model generalizes to all populations
- Don't hide the IDRiD results
- Don't upgrade the claim to "clinical validation"

---

## 5. Key Talking Points

1. **"We started with interpretable features"** — not just "we trained a CNN"
2. **"The test set was frozen from Phase 1"** — no peeking
3. **"Transfer learning solved the small-data problem"** — 4,119:1 ratio
4. **"We documented domain shift honestly"** — IDRiD results are public
5. **"This is a research prototype, not clinical validation"** — honest scoping
6. **"Explainability is built in"** — not an afterthought
7. **"The pipeline is complete"** — Detect → Analyze → Classify → Explain → Review
