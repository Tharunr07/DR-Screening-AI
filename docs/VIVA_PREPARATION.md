# Viva / Q&A Preparation Guide

## How to Use This Document

1. Read each question aloud
2. Answer in 2-3 sentences (like in a viva)
3. Check against the "key points" below each answer
4. Practice until answers feel natural, not rehearsed

---

## SECTION 1: Project Overview

### Q: What is this project?

**Answer:**
An end-to-end automated diabetic retinopathy screening pipeline built in MATLAB. It takes a fundus photograph, assesses image quality, classifies DR severity across 5 grades, determines referable status, and generates a clinical report with explainability. The final model uses transfer learning on a ResNet-18 architecture and achieves 97.7% sensitivity and 85.4% specificity on a held-out test set of 612 images.

**Key points:**
- End-to-end pipeline, not just a model
- 5-grade classification + referable binary
- Transfer learning, not native training
- Specific numbers: 97.7% sens, 85.4% spec, 0.975 AUC

---

### Q: What is diabetic retinopathy and why does it matter?

**Answer:**
Diabetic retinopathy is a complication of diabetes where high blood sugar damages retinal blood vessels. It's a leading cause of blindness in working-age adults. Early detection can prevent 90% of vision loss, but manual screening by ophthalmologists doesn't scale — there are millions of diabetic patients worldwide. Automated screening can bridge this gap.

**Key points:**
- Leading cause of blindness in working-age adults
- Early detection prevents 90% of vision loss
- Manual screening doesn't scale
- Automated screening bridges the gap

---

### Q: What problem does your system solve?

**Answer:**
The screening bottleneck: millions of diabetic patients need annual eye exams, but there aren't enough ophthalmologists. Our system automates the initial screening — it can process images in 1-2 seconds, flagging referable cases for specialist review. This doesn't replace doctors; it prioritizes their time.

**Key points:**
- Screening bottleneck, not diagnosis
- 1-2 seconds per image
- Flags referable cases for specialist review
- Augments, doesn't replace, doctors

---

## SECTION 2: Technical Approach

### Q: Why did you use transfer learning?

**Answer:**
Two reasons. First, our dataset is small — 2,792 training images for a model with 11.5 million parameters. That's a 4,119:1 parameter-to-sample ratio. Native training overfit badly, achieving only 74.7% specificity. Second, ImageNet pretraining provides edge, texture, and shape detectors that transfer well to retinal imaging. The pretrained features gave us a much better starting point than random initialization.

**Key points:**
- Small dataset: 2,792 images, 11.5M params, 4,119:1 ratio
- Native training overfit (74.7% specificity)
- ImageNet features transfer to retinal imaging
- Better initialization than random

---

### Q: Why ResNet-18 specifically?

**Answer:**
ResNet-18 is the smallest ResNet variant — 11.5 million parameters. Larger models like ResNet-50 (25M) or ResNet-101 (44M) would overfit even more with our dataset size. ResNet-18 provides enough capacity for retinal feature extraction while being trainable on CPU in under an hour. It's also well-supported in both PyTorch (for pretrained weights) and MATLAB (for training).

**Key points:**
- Smallest ResNet (11.5M params)
- Larger models would overfit more
- Trainable on CPU in <1 hour
- Good PyTorch + MATLAB support

---

### Q: Why not use a simpler model?

**Answer:**
We started with a simple model — an SVM on handcrafted retinal features. That was our Phase 4 baseline: 75.9% sensitivity, 86.2% specificity. It couldn't capture complex DR patterns because handcrafted features have limited representational power. The classification audit identified this as the bottleneck. Deep learning was the logical next step.

**Key points:**
- We DID start with SVM (75.9% sens, 86.2% spec)
- Handcrafted features have limited power
- Classification audit identified the bottleneck
- Deep learning was evidence-based, not arbitrary

---

### Q: How does your pipeline work end-to-end?

**Answer:**
Six stages. First, image loading and validation. Second, quality assessment — brightness, contrast, blur. Third, preprocessing — resize to 224x224, ImageNet normalization. Fourth, classification — ResNet-18 with transfer learning outputs 5 class probabilities. Fifth, referable decision — sum of grades 2-4 probabilities against a threshold of 0.1951. Sixth, report generation with explainability.

**Key points:**
- 6 stages: load → quality → preprocess → classify → decide → report
- 224x224, ImageNet normalization
- 5 class probabilities
- Threshold 0.1951 (optimized on validation)

---

### Q: What is the referable threshold and how did you choose it?

**Answer:**
The threshold is 0.1951. We sum the probabilities of grades 2, 3, and 4 — anything above this threshold is classified as referable DR. The threshold was optimized on the validation set using best F1 score, then applied once to the test set. We never adjusted the threshold based on test-set performance.

**Key points:**
- Sum of P(grade 2) + P(grade 3) + P(grade 4)
- Optimized on validation (best F1)
- Applied once to test
- Never adjusted based on test results

---

## SECTION 3: Results & Validation

### Q: What are your final results?

**Answer:**
On the held-out 612-image test set: sensitivity 97.7%, specificity 85.4%, AUC 0.975. Bootstrap 95% confidence intervals: sensitivity [0.956, 0.992], specificity [0.816, 0.891], AUC [0.964, 0.984]. Six false negatives, 52 false positives. McNemar test shows statistically significant improvement over both SVM (p < 0.001) and native ResNet (p = 0.000136).

**Key points:**
- Sens 97.7%, Spec 85.4%, AUC 0.975
- Bootstrap CIs reported
- McNemar p < 0.001 vs baselines
- 6 FN, 52 FP

---

### Q: What does sensitivity mean in this context?

**Answer:**
Sensitivity is the proportion of truly referable cases that the model correctly identifies. At 97.7%, we catch 97.7% of patients who actually have referable DR. The 6 missed cases (false negatives) are mostly grade 2 — moderate NPDR that's closer to the decision boundary. For a screening tool, high sensitivity is critical because missing a referable case can lead to blindness.

**Key points:**
- Proportion of truly referable cases caught
- 97.7% = 6 missed out of 265 referable
- Mostly grade 2 (near decision boundary)
- High sensitivity critical for screening

---

### Q: What does specificity mean and why is it important?

**Answer:**
Specificity is the proportion of non-referable cases correctly identified as normal. At 85.4%, we correctly clear 85.4% of healthy patients. The 52 false positives mean 8.5% of healthy patients get flagged for unnecessary specialist referral. This matters because false positives cause anxiety, waste clinic time, and increase healthcare costs. Our specificity meets the predefined target of 85%.

**Key points:**
- Proportion of healthy patients correctly cleared
- 85.4% = 52 false positives out of 347 non-referable
- False positives waste resources and cause anxiety
- Meets predefined 85% target

---

### Q: What is AUC and why does it matter?

**Answer:**
AUC measures the model's ability to distinguish between referable and non-referable cases across all thresholds. An AUC of 0.975 means there's a 97.5% chance the model ranks a random referable case higher than a random non-referable case. It's threshold-independent, so it captures the model's discriminative power regardless of where we set the decision boundary.

**Key points:**
- Probability of correct ranking
- Threshold-independent measure
- 0.975 = excellent discrimination
- Complements sensitivity/specificity

---

### Q: How do you know the test set wasn't contaminated?

**Answer:**
Three safeguards. First, the split was done at the patient level in Phase 1, seed 42 — no patient appears in multiple splits. Second, the test set was frozen immediately and never modified. Third, no optimization was ever performed against test-set metrics. All threshold selection, hyperparameter tuning, and model selection used the validation set only.

**Key points:**
- Patient-level split (no leakage)
- Frozen from Phase 1, never modified
- No optimization against test set
- All tuning on validation only

---

## SECTION 4: Limitations & Honest Assessment

### Q: What are the main limitations?

**Answer:**
Three major limitations. First, domain shift — IDRiD specificity is 59.1% versus APTOS 87.1%, showing the model doesn't generalize well across different imaging protocols. Second, class imbalance — Grade 3 (39 images) and Grade 4 (50) are severely underrepresented, leading to low per-grade sensitivity (17.9% and 38.0%). Third, no external validation — we only tested on two datasets from the same country.

**Key points:**
- Domain shift: IDRiD spec 59.1% vs APTOS 87.1%
- Class imbalance: G3 sens 17.9%, G4 sens 38.0%
- No external validation
- Two datasets, same country

---

### Q: What is domain shift and how does it affect your model?

**Answer:**
Domain shift is when the test data differs from training data in ways the model wasn't trained for. Our model was trained primarily on APTOS images (Indian dataset, specific camera). IDRiD uses different equipment and protocols. Result: sensitivity drops from 98.6% to 91.9%, specificity drops from 87.1% to 59.1%. This is a real limitation — the model would need multi-site training data to generalize clinically.

**Key points:**
- Test data differs from training data
- Different cameras, protocols, populations
- APTOS: 98.6% sens, 87.1% spec
- IDRiD: 91.9% sens, 59.1% spec
- Multi-site data needed for clinical use

---

### Q: Why can't you claim clinical deployment?

**Answer:**
Because we haven't done clinical validation. Our evaluation is retrospective — we tested on curated datasets, not prospective clinical workflows. Clinical deployment requires: prospective studies with diverse populations, regulatory approval (FDA/CE), integration with clinical IT systems, training for clinicians, and long-term monitoring. Our work is a research prototype demonstrating technical feasibility.

**Key points:**
- Retrospective, not prospective
- Curated datasets, not clinical workflows
- Needs: diverse populations, regulatory approval, IT integration
- Research prototype, not clinical tool

---

### Q: What would you do differently?

**Answer:**
Four things. First, multi-site training data — more diverse cameras, populations, and protocols. Second, external validation on completely held-out datasets. Third, calibration training — our ECE is 3.9%, could be better. Fourth, grade-specific oversampling to address class imbalance for rare grades.

**Key points:**
- Multi-site training data
- External validation
- Calibration training (ECE 3.9%)
- Grade-specific oversampling

---

## SECTION 5: Technical Deep Dive

### Q: Explain the overparameterization problem.

**Answer:**
Our model has 11.5 million parameters but only 2,792 training images — a 4,119:1 ratio. With more parameters than data, the model memorizes training examples rather than learning generalizable features. This is why native ResNet achieved 95.3% sensitivity but only 74.7% specificity — it overfit to the training distribution. Transfer learning addresses this by starting with pre-learned features, reducing the effective number of parameters that need to be trained.

**Key points:**
- 11.5M params, 2,792 images, 4,119:1 ratio
- Memorization vs generalization
- Native: 95.3% sens, 74.7% spec (overfit)
- Transfer: better initialization, less overfitting

---

### Q: How does transfer learning work technically?

**Answer:**
We load a ResNet-18 pre-trained on ImageNet (1.2M images, 1000 classes). The early layers learn universal features — edges, textures, colors. These transfer well to retinal imaging because optic discs look like circular edges, vessels look like line textures, and lesions look like texture anomalies. We replace the final fully-connected layer with a 5-class output and fine-tune all layers with a low learning rate (1e-4).

**Key points:**
- ImageNet pretraining (1.2M images)
- Early layers: universal features (edges, textures)
- Transfer to retinal features (discs, vessels, lesions)
- Replace FC layer, fine-tune all layers, LR 1e-4

---

### Q: Why is the specificity CI lower bound (81.6%) below 85%?

**Answer:**
Bootstrap confidence intervals account for sampling variability. With 612 test images, there's uncertainty in the point estimate. The 95% CI lower bound of 81.6% means we can't be 95% confident the true specificity is above 85%. This is a legitimate statistical limitation — to tighten the CI, we'd need more test data. The point estimate (85.4%) meets the target, but the CI shows it's borderline.

**Key points:**
- Sampling variability with 612 images
- 95% CI lower bound: 81.6%
- Point estimate meets target, CI is borderline
- More data needed to tighten CI

---

### Q: What is McNemar's test and why did you use it?

**Answer:**
McNemar's test compares two classifiers on the same dataset to see if their error rates differ significantly. We used it to compare: SVM vs Transfer Learning (p < 0.001), and Native DL vs Transfer Learning (p = 0.000136). Both p-values are well below 0.05, confirming the improvement is statistically significant, not due to chance.

**Key points:**
- Compares two classifiers on same data
- Tests if error rates differ significantly
- SVM vs TL: p < 0.001
- Native DL vs TL: p = 0.000136

---

## SECTION 6: Project Management

### Q: Why did you freeze the model?

**Answer:**
To maintain scientific integrity. If we kept tuning after seeing test results, we'd be overfitting to the test set. By freezing at Phase 8, we ensure the reported metrics reflect genuine generalization. The test set was never modified, never optimized against, and never used for model selection. This makes the progression from SVM to native DL to transfer learning defensible.

**Key points:**
- Scientific integrity
- Prevents test-set overfitting
- Test set never modified or optimized against
- Makes progression defensible

---

### Q: Why did you create separate phases instead of jumping straight to transfer learning?

**Answer:**
Because the scientific story requires evidence at each step. We needed to: (1) establish a baseline to compare against, (2) audit why it failed, (3) test a naive deep learning approach, (4) identify the overparameterization problem, (5) justify transfer learning as the solution. Jumping straight to transfer learning would give us a good result without understanding why it works. The audit phases make the result credible.

**Key points:**
- Evidence at each step
- Baseline → audit → test → identify → justify
- Understanding why, not just what
- Audit makes result credible

---

### Q: How long did each phase take?

**Answer:**
Phase 1-3 (data): ~1 hour. Phase 4 (SVM): ~30 minutes. Phase 5 (explainability): ~30 minutes. Phase 6 (audit): ~20 minutes. Phase 7 (native DL): ~45 minutes training. Phase 8 (transfer learning): ~50 minutes training. Phase 9 (integration): ~1 hour. Total active development: ~4-5 hours, mostly waiting for training.

**Key points:**
- Data pipeline: ~1 hour
- SVM + explainability + audit: ~1.5 hours
- DL training: ~1.5 hours
- Integration: ~1 hour
- Mostly CPU training time

---

## Key Phrases to Remember

Use these exact phrases when answering:

1. **"On the held-out 612-image test set..."** — never say "in general"
2. **"The predefined sensitivity and specificity targets..."** — shows you set criteria before testing
3. **"Transfer learning addressed the overparameterization problem..."** — shows you understand why
4. **"We documented domain shift honestly..."** — shows scientific integrity
5. **"This is a research prototype, not clinical validation..."** — honest scoping
6. **"The test set was frozen from Phase 1..."** — no contamination
7. **"Bootstrap confidence intervals show..."** — statistical rigor
8. **"McNemar test confirms statistically significant improvement..."** — formal comparison

---

## Common Pitfalls to Avoid

| Pitfall | Why It's Bad | Better Response |
|---------|-------------|-----------------|
| "We got 97.7% accuracy" | Accuracy is misleading with imbalanced data | "97.7% sensitivity, 85.4% specificity" |
| "The model is clinically validated" | It's not | "The model achieved predefined targets on the test set" |
| "It works on all fundus images" | Domain shift exists | "It works well on APTOS, less well on IDRiD" |
| "Transfer learning always helps" | Not always | "Transfer learning helped because of our small dataset" |
| "The model is deployment-ready" | It's not | "The model is a research prototype" |
| "We tested extensively" | Vague | "9/9 inference validation tests, 17/17 synthetic tests" |
| "The results are statistically significant" | Cite the test | "McNemar p < 0.001 vs SVM baseline" |
| "We used deep learning because it's better" | Circular | "We used deep learning because the SVM audit identified feature limitations" |

---

## Backup Evidence to Keep Ready

| Evidence | Location |
|----------|----------|
| Final metrics table | `docs/PROJECT_SUMMARY.md` |
| ROC curve | `results/demo/figures/fig2_roc_curve.png` |
| Bootstrap CIs | `docs/PHASE8_TRANSFER_LEARNING.md` |
| Confusion matrix | `results/demo/figures/fig5_confusion_matrix.png` |
| Domain shift | `docs/PHASE8_TRANSFER_LEARNING.md` |
| Inference validation | `results/demo/figures/fig1_model_progression.png` |
| Phase 8 tests | 17/17 PASS |
| Inference tests | 9/9 PASS |
