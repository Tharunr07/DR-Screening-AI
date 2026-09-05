# SIH Presentation Pack

**Status:** PRODUCTION CODE FROZEN — presentation preparation only
**Last updated:** 2026-09-05
**Do NOT modify any production files from this document**

---

## TABLE OF CONTENTS

1. Slide Deck (10 slides)
2. Architecture Diagram
3. 7-Minute Speaking Script
4. Live Demo Script (with timestamps)
5. Judge Q&A (30 questions)
6. Metrics Reference Card
7. Limitations Statement
8. Failure Recovery Guide

---

## 1. SLIDE DECK

### SLIDE 1 — TITLE

**Title:** AI-Assisted Diabetic Retinopathy Screening for Underserved Communities

**Subtitle:** Decision Support for Ophthalmologists via Retinal Fundus Analysis

**Visual:** Fundus image (G0) fading into system architecture silhouette

**Bullets:**
- 422 million diabetics worldwide; 45% risk of DR
- 50% of cases undiagnosed in rural India
- Ophthalmologist shortage limits screening access

**Presenter:** "Diabetic retinopathy is the leading cause of preventable blindness. But most patients in underserved areas never see an ophthalmologist. We built a system to help change that."

---

### SLIDE 2 — THE PROBLEM

**Title:** The Screening Gap

**Visual:** Bar chart — DR prevalence vs. ophthalmologist availability (India)

**Bullets:**
- 101 million diabetics in India (IDF 2021)
- Only ~20,000 ophthalmologists for 1.4 billion people
- DR screening requires specialist interpretation of retinal images
- Manual screening is time-intensive and subjective
- Missed referral → preventable blindness

**Presenter:** "The bottleneck is not image acquisition. It is specialist interpretation. Our system provides AI-assisted triage to help prioritize which patients need urgent review."

---

### SLIDE 3 — SYSTEM ARCHITECTURE

**Title:** End-to-End Screening Pipeline

**Visual:** Architecture diagram (see Section 2 below)

**Bullets:**
- Image Quality Assessment → Preprocessing → AI Classification → Clinical Decision → Explainability → Report
- 7-stage pipeline with clear input/output at each stage
- Doctor remains in the loop at every decision point

**Presenter:** "The system is not a black box. Each stage produces auditable outputs. The quality gate filters unusable images. The classifier provides a grade and confidence. Grad-CAM visualizes attention. The clinical logic routes uncertain cases for human review."

---

### SLIDE 4 — AI PIPELINE

**Title:** Transfer Learning for DR Classification

**Visual:** ResNet-18 diagram with fine-tuning strategy

**Bullets:**
- ResNet-18 (pretrained on ImageNet)
- Fine-tuned on 3,662 retinal images (APTOS + IDRiD)
- 5-class output: G0 (No DR) → G4 (Proliferative)
- Referable threshold: Grade ≥ 2 (Moderate, Severe, Proliferative)
- Class-weighted loss to handle imbalance (G1 = 4.8%, G3 = 3.3%)

**Presenter:** "We use transfer learning because native deep learning and SVM both failed on this dataset. The pretrained backbone provides meaningful feature extraction. Class weighting addresses the severe imbalance — G3 cases represent only 3.3% of our data."

---

### SLIDE 5 — RESULTS

**Title:** Internal Evaluation Results

**Visual:** ROC curve (`fig2_roc_curve.png`) + confusion matrix (`fig5_confusion_matrix.png`)

**Bullets:**
- **91.0% referable sensitivity** — correctly identifies 91% of patients needing referral
- **91.5% referable specificity** — correctly clears 91.5% of non-referable patients
- **79.5% overall accuracy** (5-class)
- **AUC = 0.7741**
- **ECE = 0.033** (well-calibrated)

**Fine print:** Internal retrospective evaluation — frozen 612-image APTOS test set. Not clinical validation.

**Presenter:** "On our frozen internal test set, the system achieves 91% sensitivity for referable DR. That means 9 out of 10 patients who need referral are correctly flagged. I want to be transparent: these are retrospective internal evaluation results, not clinical validation."

---

### SLIDE 6 — EXPLAINABILITY + HUMAN-IN-THE-LOOP

**Title:** Transparent AI with Doctor Oversight

**Visual:** Grad-CAM overlay example (`gradcam_G2_Moderate_00e4ddff966a.png`)

**Bullets:**
- Grad-CAM visualizes model attention (where the network looks)
- Supporting lesion evidence labeled as experimental
- Consistency warnings flag classifier-evidence disagreement
- Confidence-stratified routing: uncertain cases → doctor review
- **The doctor remains in the loop**

**Presenter:** "Grad-CAM is not a lesion segmentation. It shows where the model allocates attention. The doctor reviews the AI's evidence and makes the final clinical decision. The AI reduces workload; it does not replace the specialist."

---

### SLIDE 7 — TELEMEDICINE / SCALABILITY

**Title:** Scaling to Rural India

**Visual:** Telemedicine workflow diagram + simulation results

**Bullets:**
- 100,000 patients/year target
- Pipeline: Image acquisition → Cloud transmission → AI screening → Doctor review
- AI inference: ~26ms per image (CPU)
- Bandwidth: <2s at 50 Mbps; ~14s at 5 Mbps
- Bottleneck: doctor review time (2 min/case), not AI processing

**Presenter:** "Our telemedicine simulation shows that with 4 acquisition stations, 2 AI workers, and 4 doctors, we can screen 100,000 patients per year. The bottleneck is specialist review time, not AI throughput."

---

### SLIDE 8 — VALIDATION + LIMITATIONS

**Title:** What We Tested and What We Did Not

**Visual:** Table of established vs. not established

**What is established:**
- Software correctness (73/73 regression tests pass)
- Internal classifier performance (91.0%/91.5%)
- Quality gating works
- Grad-CAM produces deterministic attention maps
- Telemedicine simulation models throughput

**What is NOT established:**
- Clinical validation (requires prospective multi-center trials)
- Lesion detector performance (failed external validation)
- Generalization to all camera systems and populations
- Regulatory clearance

**Presenter:** "We also tested our handcrafted lesion detectors on independent datasets — IDRiD and DDR. They did not generalize. Rather than hide this, we documented it and froze that research line. That is scientific honesty."

---

### SLIDE 9 — LIVE DEMO

**Title:** Live Demonstration

**Visual:** Screen projection of `drScreeningGUIv2.m`

**Demo images:**
1. Normal patient → G0 → Non-referable
2. Referable patient → G2 → Referable → Doctor review
3. Ungradable image → Recapture

**Presenter:** "Let me show you the system in action."

**(See Live Demo Script in Section 4)**

---

### SLIDE 10 — FUTURE ROADMAP

**Title:** Next Steps

**Visual:** Timeline

**Bullets:**
1. Multi-reader annotation (eliminate single-grader bias)
2. External validation on diverse clinical datasets
3. Learned lesion segmentation (U-Net with larger annotated datasets)
4. Prospective clinical trials
5. Regulatory pathway (CDSCO/CE)

**Presenter:** "This is a research prototype. The next steps are multi-center clinical validation and multi-reader ground truth annotation. We have identified the failure modes and documented them honestly. That is how good research progresses."

---

## 2. ARCHITECTURE DIAGRAM

```
                    ┌─────────────────────────────────┐
                    │     FUNDUS IMAGE INPUT           │
                    │   (retinal photograph)           │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │    IMAGE QUALITY ASSESSMENT      │
                    │  ┌──────────┬──────────┬───────┐ │
                    │  │Brightness│Contrast  │Sharpness│ │
                    │  │  (40-220)│ (std≥20) │(Lap≥100)│ │
                    │  └──────────┴──────────┴───────┘ │
                    │                                   │
                    │  GOOD ─────────────────────────── │
                    │  BORDERLINE ──────────────────── │
                    │  POOR → RECAPTURE RECOMMENDED    │
                    └──────────────┬──────────────────┘
                                   │ (GOOD/BORDERLINE)
                    ┌──────────────▼──────────────────┐
                    │      PREPROCESSING               │
                    │  imresize(224×224, bilinear)     │
                    │  single()                        │
                    │  (canonical: no normalization)    │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │    DR CLASSIFICATION             │
                    │  ResNet-18 (transfer learning)   │
                    │  ┌─────┬─────┬─────┬─────┬─────┐│
                    │  │ G0  │ G1  │ G2  │ G3  │ G4  ││
                    │  │No DR│Mild │Mod  │Sev  │PDR  ││
                    │  └─────┴─────┴─────┴─────┴─────┘│
                    │  5-class softmax probabilities    │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │    CLINICAL DECISION LOGIC       │
                    │  ┌─────────────────────────────┐ │
                    │  │ Referable if grade ≥ 2       │ │
                    │  │ (Moderate/Severe/Proliferative)│ │
                    │  └─────────────────────────────┘ │
                    │  ┌─────────────────────────────┐ │
                    │  │ Confidence level:            │ │
                    │  │ HIGH ≥0.70                   │ │
                    │  │ MODERATE 0.50-0.70           │ │
                    │  │ LOW <0.50                    │ │
                    │  └─────────────────────────────┘ │
                    └───────┬───────────────┬──────────┘
                            │               │
                 ┌──────────▼─────┐  ┌──────▼──────────┐
                 │  NON-REFERABLE │  │   REFERABLE      │
                 │  → Routine     │  │   → Doctor review│
                 │    follow-up   │  │   → Priority     │
                 └────────────────┘  │     routing      │
                                     └──────────────────┘
                            │
                    ┌───────▼──────────────────────────┐
                    │    EXPLAINABILITY                 │
                    │  ┌──────────────────────────────┐ │
                    │  │ Grad-CAM attention heatmap    │ │
                    │  │ (last conv layer: res5b)      │ │
                    │  └──────────────────────────────┘ │
                    │  ┌──────────────────────────────┐ │
                    │  │ Supporting lesion evidence    │ │
                    │  │ (experimental, not validated) │ │
                    │  └──────────────────────────────┘ │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │    STRUCTURED REPORT             │
                    │  Grade, confidence, evidence,    │
                    │  recommendation, disclaimer      │
                    │  → Export to file                │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │    HUMAN-IN-THE-LOOP             │
                    │  Doctor reviews AI evidence      │
                    │  Final clinical interpretation   │
                    │  Diagnosis and treatment          │
                    └─────────────────────────────────┘
```

---

## 3. SEVEN-MINUTE SPEAKING SCRIPT

### 0:00–0:40 — Problem (40s)

"Diabetic retinopathy is the leading cause of preventable blindness among working-age adults. There are 422 million diabetics worldwide, and 45% will develop DR during their lifetime. In rural India, most cases go undiagnosed because retinal screening requires a specialist, and there simply aren't enough ophthalmologists.

The bottleneck is not image acquisition — fundus cameras are increasingly available. The bottleneck is specialist interpretation. Our project addresses this gap."

### 0:40–1:20 — Solution (40s)

"We built an end-to-end AI-assisted screening workflow with seven stages.

First, image quality assessment — the system checks brightness, contrast, sharpness, and field of view. If the image is unusable, it recommends recapture rather than forcing a classification.

Second, preprocessing — the image is resized to the model's input format.

Third, AI classification — a ResNet-18 neural network, fine-tuned via transfer learning, predicts one of five DR grades: no DR, mild, moderate, severe, or proliferative.

Fourth, clinical decision logic — grades two and above are flagged as referable, meaning the patient should see an ophthalmologist.

Fifth, explainability — Grad-CAM visualizes where the model is looking.

Sixth, supporting lesion evidence — experimental algorithmic outputs, clearly labeled as not clinically validated.

Seventh, a structured clinical report with a clear disclaimer.

At every stage, the doctor remains in the loop."

### 1:20–2:20 — Normal Patient (60s)

"Let me show you a normal case.

[Upload 06586082a24d.png]

The image passes quality assessment — brightness, contrast, and sharpness are all within normal range. The classifier predicts Grade 0, meaning no diabetic retinopathy. The confidence is high. The patient is marked non-referable.

Let me show you the Grad-CAM.

[Show heatmap]

The model attends to the retinal vasculature and optic disc. This is the model's attention — not a clinical diagnosis. The doctor can review this visualization to understand the AI's reasoning.

Here is the structured report.

[Show report]

The report includes the grade, confidence, recommendation, and a clear disclaimer that this is an AI-assisted screening result, not a definitive diagnosis."

### 2:20–3:40 — Referable Patient (80s)

"Now let me show you a referable case.

[Upload 03ff7d159f10.png]

The image passes quality assessment. The classifier predicts Grade 2 — moderate non-proliferative diabetic retinopathy. This is above our referable threshold, so the system flags the patient for ophthalmologist review.

The confidence is moderate. The supporting lesion evidence shows some microaneurysms and hemorrhages. These are experimental algorithmic outputs — not confirmed clinical findings. But they provide the doctor with additional context.

Let me show you the Grad-CAM.

[Show heatmap]

The model's attention is distributed across the retinal area. The doctor reviews this evidence and makes the final clinical decision.

Here is the report. It includes a clear recommendation: refer to ophthalmologist for clinical evaluation."

### 3:40–4:20 — Ungradable Image (40s)

"This is one of the most important safety mechanisms.

[Upload 026dcd9af143.png]

The image fails quality assessment. The contrast is too low, the sharpness is borderline. Rather than forcing a classification from an unusable image, the system recommends recapture.

This is critical for clinical safety. A system that blindly classifies every image — regardless of quality — would produce unreliable results for poor-quality inputs. Our system explicitly refuses to make a prediction when the image is not sufficiently usable."

### 4:20–5:00 — Human in the Loop (40s)

"The system is designed as decision support, not autonomous diagnosis.

The AI handles screening, prioritization, quality assessment, evidence visualization, and referral suggestion.

The doctor handles final interpretation, difficult case review, diagnosis, and treatment decisions.

This is not a replacement for ophthalmologists. It is a tool to help them work more efficiently. The doctor remains in the loop."

### 5:00–5:40 — Results (40s)

"On our frozen 612-image internal APTOS test evaluation, the system achieved:

- 91.0% referable sensitivity — correctly identifies 91% of patients needing referral
- 91.5% referable specificity — correctly clears 91.5% of non-referable patients
- 79.5% overall accuracy across five DR grades
- AUC of 0.7741

I want to be transparent: these are retrospective internal evaluation results, not clinical validation. Clinical validation requires prospective multi-center trials, which are beyond our current scope."

### 5:40–6:20 — Limitations + Future (40s)

"We also tested our lesion detectors on independent datasets — IDRiD and DDR. The handcrafted detectors did not generalize sufficiently. Rather than hide this, we documented it honestly and paused that research line.

The model is weakest on Grade 3 and Grade 4 cases, which are severely underrepresented in our training data — G3 is only 3.3% of the dataset.

Our next steps are multi-reader annotation, external clinical validation, and learned lesion segmentation using larger expert-annotated datasets.

This is a research prototype. We have identified the failure modes and documented them honestly. That is how good research progresses."

### 6:20–7:00 — Close (40s)

"Let me summarize what we built:

An AI-assisted retinal screening workflow that assesses image quality, classifies DR severity, provides explainable evidence, routes uncertain cases for human review, and generates structured reports.

The system is designed to help ophthalmologists, not replace them. The doctor remains in the loop.

Thank you. I'm happy to take questions."

---

## 4. LIVE DEMO SCRIPT

**Total time: 5 minutes 30 seconds**

### Pre-demo checklist (before judges arrive)

```
1. MATLAB R2026a open
2. addpath(genpath('matlab'))
3. Verify trainedNetTL.mat exists: dir('results/transfer_learning/models/trainedNetTL.mat')
4. Verify 4 demo images exist:
   dir('data/raw/APTOS2019/train_images/06586082a24d.png')
   dir('data/raw/APTOS2019/train_images/03ff7d159f10.png')
   dir('data/raw/APTOS2019/train_images/026dcd9af143.png')
5. Type: >> drScreeningGUIv2
6. Click "Load Model" — verify green status: "Model loaded"
7. Close GUI — reopen fresh for demo
```

### Demo sequence

| Time | Action | Narration |
|------|--------|-----------|
| 0:00 | Click "Load Model" | "The system loads a ResNet-18 neural network, fine-tuned on 3,662 retinal images." |
| 0:10 | Click "Upload Fundus Image" → select `06586082a24d.png` | "This is a normal retinal photograph." |
| 0:15 | Point to quality panel | "The image passes quality assessment — brightness, contrast, and sharpness are all acceptable." |
| 0:20 | Click "Run DR Screening" | "The classifier predicts Grade 0 — no diabetic retinopathy." |
| 0:25 | Point to grade, referable, confidence | "The patient is non-referable. Confidence is high." |
| 0:30 | Click "Show Heatmap" | "Grad-CAM shows where the model is looking. It attends to the retinal vasculature." |
| 0:45 | Close heatmap | "This is an explanation aid, not a clinical diagnosis." |
| 0:50 | Click "Report" | "The structured report includes the grade, recommendation, and a clear disclaimer." |
| 1:00 | Close report | "Let me show you a second case." |
| 1:05 | Click "Upload" → select `03ff7d159f10.png` | "This patient has moderate non-proliferative diabetic retinopathy." |
| 1:15 | Click "Run DR Screening" | "Grade 2 — this is above our referable threshold. The patient needs ophthalmologist review." |
| 1:20 | Point to referable status, risk level | "The system flags this as referable. The risk level is moderate." |
| 1:25 | Point to lesion evidence | "Supporting evidence shows microaneurysms and hemorrhages. These are experimental algorithmic outputs — not confirmed findings." |
| 1:35 | Click "Show Heatmap" | "The model's attention is distributed across the retinal area." |
| 1:50 | Close heatmap | "The doctor reviews this evidence and makes the final decision." |
| 1:55 | Click "Report" | "The report recommends referral to an ophthalmologist." |
| 2:05 | Close report | "Now let me show you the quality safety mechanism." |
| 2:10 | Click "Upload" → select `026dcd9af143.png` | "This is a real fundus photograph with poor contrast." |
| 2:20 | Point to quality panel | "The image fails quality assessment. The system recommends recapture." |
| 2:30 | Click "Run DR Screening" | "The system blocks classification — image quality insufficient." |
| 2:35 | Narrate | "This is critical: the system does not force a prediction from unusable images." |
| 2:45 | Point to history panel | "All three screenings are logged in the history." |
| 2:50 | Narrate | "The system is designed as decision support. The doctor remains in the loop." |
| 3:00 | **End GUI demo** | Transition to slides for results, limitations, future |

### What to say if something goes wrong

| Issue | Say |
|-------|-----|
| Grad-CAM is zero | "The heatmap is all-zero — the model has no strong spatial attention for this class. This is the honest output." |
| Quality shows BORDERLINE for a good image | "The quality gate is conservative — it flags borderline cases for human review." |
| Export fails | "The export encountered a file system error. The on-screen report is sufficient for demonstration." |
| MATLAB warning appears | Ignore it. Warnings do not affect functionality. |
| Classifier takes >3s | "First-run inference includes model loading. Subsequent inferences are ~26 milliseconds." |

---

## 5. JUDGE Q&A (30 QUESTIONS)

### Accuracy & Performance

**Q1: What is the accuracy of your system?**
A: On our frozen 612-image internal APTOS test evaluation, the system achieves 79.5% overall accuracy across five DR grades. For the clinically critical question — does this patient need referral? — we achieve 91.0% sensitivity and 91.5% specificity. These are retrospective internal evaluation results, not clinical validation.
Evidence: `VALIDATION_SUMMARY.md`

**Q2: How does your sensitivity compare to published results?**
A: Our 91.0% referable sensitivity is competitive with published APTOS challenge winners. However, direct comparison is difficult because different studies use different test sets, different definitions of "referable," and different evaluation protocols. Our results are on a frozen internal test set.
Evidence: `PHASE18_BENCHMARK_COMPARISON.md`

**Q3: What is the AUC?**
A: 0.7741 for referable DR detection.
Evidence: `VALIDATION_SUMMARY.md`

**Q4: Is the model well-calibrated?**
A: The raw expected calibration error is 0.033, which is good. We investigated temperature scaling and isotonic regression; the improvement was marginal (ECE 0.033 → 0.023) and not worth the complexity.
Evidence: `PHASE22_CALIBRATION.md`

**Q5: What is the inference time?**
A: Approximately 26 milliseconds per image on CPU. The bottleneck in a clinical workflow is doctor review time, not AI processing.
Evidence: Phase 9 benchmark

### Datasets & Training

**Q6: What datasets did you use?**
A: We trained on APTOS 2019 (3,662 images) and IDRiD (494 images for classification). We externally tested lesion detectors on IDRiD (81 images with pixel-level masks) and DDR (60 images). DRIVE was used as a vessel segmentation reference.
Evidence: `VALIDATION_SUMMARY.md`

**Q7: How did you handle class imbalance?**
A: Three strategies: (1) class-weighted loss with exponential moving average (beta=0.999), (2) quality gating to remove ungradable images, and (3) confidence-stratified routing to flag uncertain cases for human review. G1 and G3 remain weak due to severe underrepresentation (4.8% and 3.3% of training data).
Evidence: `transferLearningConfig.m`

**Q8: Why did you use transfer learning instead of training from scratch?**
A: We tried native deep learning (ResNet-18 from random initialization) and SVM with handcrafted features. Both failed. Transfer learning from ImageNet pretrained weights provides meaningful feature extraction for medical images, even though ImageNet is natural images.
Evidence: `PHASE8_TRANSFER_LEARNING.md`

**Q9: How many images are in the test set?**
A: 612 frozen test images. The test set has been locked since Phase 8.
Evidence: `test.csv`

**Q10: Is the test set representative?**
A: The test set is drawn from APTOS 2019, which is a real clinical dataset from India. However, it is a single-center dataset. Generalization to other camera systems and populations requires external validation, which we have not yet performed.
Evidence: `LIMITATIONS.md`

### Lesion Detection

**Q11: Does the system detect lesions?**
A: The system provides experimental supporting lesion evidence using handcrafted morphological detectors. These detectors were externally validated on IDRiD and DDR and did not generalize — MA Dice = 0.000, HE Dice = 0.033, EX Dice = 0.011. The lesion evidence is explicitly labeled as experimental and not clinically validated.
Evidence: `PHASE24B1_IDRID_LESION_VALIDATION.md`

**Q12: Why did the lesion detectors fail?**
A: Domain generalization failure. The detectors were designed for APTOS images but IDRiD and DDR use different cameras, different populations, and different imaging protocols. The handcrafted morphological features do not transfer across domains. We also attempted learned segmentation (U-Net), but with only 43 training images and CPU constraints, the model collapsed to background prediction.
Evidence: `PHASE24B3_DDR_VALIDATION.md`, `EX_LEARNED_SEGMENTATION_BASELINE.md`

**Q13: Why didn't you fix the lesion detectors before the presentation?**
A: We identified the root cause — domain shift, insufficient training data, and class imbalance — and determined that attempting repairs 5 days before evaluation would be high-risk and low-reward. We chose to document the failure honestly and present it as a known limitation with a clear future research direction. This demonstrates scientific maturity.
Evidence: `EX_LEARNED_SEGMENTATION_BASELINE.md`

**Q14: Are the lesion counts in the report real findings?**
A: No. The lesion counts (e.g., "MA=24, HE=13") are experimental algorithmic outputs from handcrafted detectors. They are not clinically confirmed findings. The system labels them as "supporting evidence" and includes a disclaimer that lesion detection is experimental.

### Explainability

**Q15: How does Grad-CAM work?**
A: Grad-CAM computes the spatial attention of the last convolutional layer (res5b_branch2b, 7×7×512 feature maps) using exact gradient analysis. It produces a heatmap showing which spatial regions positively contributed to the predicted class logit. It does not prove clinical relevance.
Evidence: `gradcamSimple.m`

**Q16: Does Grad-CAM show where the disease is?**
A: Not necessarily. Grad-CAM shows where the model allocates attention for its prediction. This can include clinically relevant regions (lesions) but also clinically irrelevant regions (optic disc, image artifacts). The heatmap is an explanation aid, not a diagnostic tool.
Evidence: `gradcamSimple.m` header

**Q17: What happens if the heatmap is zero?**
A: If no spatial region positively contributes to the predicted class, the heatmap is all-zeros. This is the honest output — not an error. It occurs in approximately 15% of cases, primarily G0 images where the model's attention is diffuse.

### Clinical Safety

**Q18: Is this system clinically validated?**
A: No. Our results are internal retrospective evaluation on a frozen test set. Clinical validation requires prospective multi-center trials with diverse patient populations, which is beyond our current scope. The system is a research prototype.
Evidence: All documentation

**Q19: Can this system replace ophthalmologists?**
A: Absolutely not. The system is designed as decision support. It screens and prioritizes patients, but the doctor makes the final clinical interpretation, diagnosis, and treatment decisions. The doctor remains in the loop.
Evidence: `applyClinicalLogic.m`

**Q20: What happens when the system is uncertain?**
A: Cases with confidence below 0.70 are flagged for mandatory doctor review. The system routes uncertain cases to the ophthalmologist rather than making autonomous decisions. This is a core safety mechanism.
Evidence: `transferLearningConfig.m`

**Q21: What is the false negative rate?**
A: For referable DR, the false negative rate is 9.0% (1 - 0.910). That means 9% of referable cases are missed. This is why the system is designed as screening triage, not autonomous diagnosis — the ophthalmologist provides the safety net.
Evidence: `VALIDATION_SUMMARY.md`

**Q22: What is the quality gate for?**
A: The quality gate checks brightness, contrast, sharpness, and field of view. If the image is ungradable, the system recommends recapture rather than forcing a classification from unusable input. This prevents unreliable predictions from poor-quality images.
Evidence: `testQualityPipeline`

### Scalability & Deployment

**Q23: Can this scale to 100,000 patients per year?**
A: Our telemedicine simulation models this scenario. With 4 acquisition stations, 2 AI workers, and 4 ophthalmologists, the system handles ~400 patients/day (~100K/year). The bottleneck is doctor review time, not AI processing.
Evidence: `runTelemedicineSimulation.m`

**Q24: What about bandwidth in rural India?**
A: At 5 Mbps, image transmission takes ~14 seconds. At 50 Mbps, <2 seconds. The simulation tests five bandwidth scenarios. Even at low bandwidth, the system is viable because the bottleneck is doctor review, not data transmission.
Evidence: `runTelemedicineSimulation.m`

**Q25: What infrastructure is required?**
A: A fundus camera, a computer with MATLAB and Deep Learning Toolbox, and internet connectivity. The AI runs on CPU — no GPU required. The system could be deployed as a cloud service or on-premises.
Evidence: `transferLearningConfig.m`

### Limitations & Future Work

**Q26: What are the main limitations?**
A: (1) Internal evaluation only — not clinically validated. (2) G3/G4 recall is weak due to class imbalance. (3) Lesion detectors failed external validation. (4) Domain shift across camera systems. (5) Single-grader ground truth (no inter-observer analysis). (6) Research prototype, not for clinical deployment.

**Q27: Why is G3 recall so low?**
A: G3 (severe NPDR) has only 39 cases in our test set — 3.3% of the data. The model frequently confuses G3→G2. This is a direct consequence of class imbalance. Multi-reader annotation of larger datasets would help.
Evidence: `VALIDATION_SUMMARY.md`

**Q28: What is the future roadmap?**
A: (1) Multi-reader annotation to eliminate single-grader bias. (2) External validation on diverse clinical datasets. (3) Learned lesion segmentation with larger annotated datasets. (4) Prospective clinical trials. (5) Regulatory pathway (CDSCO/CE).
Evidence: `PHASE23_CLINICAL_FRAMEWORK.md`

**Q29: What did you learn from the failed segmentation experiment?**
A: We attempted a U-Net baseline for exudate segmentation. With 43 training images and CPU constraints, the model collapsed to background prediction — Dice = 0.0016. The root cause was extreme class imbalance (0.68% lesion pixels) and insufficient data. We documented this as an honest negative result and identified multi-reader annotation and larger datasets as prerequisites for learned segmentation.
Evidence: `EX_LEARNED_SEGMENTATION_BASELINE.md`

**Q30: Why should we believe this system works if the lesion detectors failed?**
A: The DR classifier itself works well — 91.0% sensitivity, 91.5% specificity. The lesion detectors are a separate subsystem that failed external validation. We chose to present the classifier's honest performance and document the lesion detector failure rather than hide it. The system's value is in the end-to-end workflow: quality gating, classification, explainability, and human-in-the-loop routing — not in the experimental lesion evidence.

---

## 6. METRICS REFERENCE CARD

**Print this card and keep it at the podium during Q&A.**

```
┌─────────────────────────────────────────────────────────┐
│  DR-SCREENING-AI — APPROVED METRICS                     │
│  Internal APTOS test set, 612 frozen images              │
├─────────────────────────────────────────────────────────┤
│  Referable DR sensitivity:     91.0%                    │
│  Referable DR specificity:     91.5%                    │
│  Overall accuracy (5-class):   79.5%                    │
│  AUC:                          0.7741                   │
│  ECE (raw):                    0.033                    │
│  Inference time:               ~26ms (CPU)              │
├─────────────────────────────────────────────────────────┤
│  PER-CLASS RECALL                                       │
│  G0 (No DR):        96.6%  (strong)                     │
│  G1 (Mild):         49.2%  (weak — confused with G2)    │
│  G2 (Moderate):     82.7%  (good)                       │
│  G3 (Severe):       25.6%  (very weak — confused w/G2) │
│  G4 (Proliferative): 44.9% (weak)                       │
├─────────────────────────────────────────────────────────┤
│  LESION DETECTORS (IDRiD, external)                     │
│  MA Dice:  0.000   FAILED                               │
│  HE Dice:  0.033   FAILED                               │
│  EX Dice:  0.011   FAILED                               │
├─────────────────────────────────────────────────────────┤
│  STATUS: Research prototype. Internal evaluation only.  │
│  NOT clinically validated. NOT for clinical deployment. │
└─────────────────────────────────────────────────────────┘
```

---

## 7. LIMITATIONS STATEMENT

**Read this verbatim during the presentation (Slide 8):**

"We tested our system on a frozen internal test set of 612 images from the APTOS dataset. The referable sensitivity is 91.0% and specificity is 91.5%. These are retrospective internal evaluation results, not clinical validation.

We also tested our lesion detectors on independent datasets — IDRiD and DDR — and they did not generalize. Rather than hide this, we documented it honestly.

The model is weakest on Grade 3 and Grade 4 cases, which are severely underrepresented in our training data. This is a known limitation.

The system is a research prototype. Clinical validation requires prospective multi-center trials with diverse patient populations."

---

## 8. FAILURE RECOVERY GUIDE

| Scenario | What to do | What to say |
|----------|-----------|-------------|
| MATLAB crashes | Restart MATLAB, re-run `addpath(genpath('matlab'))`, reopen GUI | "MATLAB encountered a runtime error. Let me restart." |
| Model file missing | Verify path: `dir('results/transfer_learning/models/trainedNetTL.mat')` | "The model file is not found at the expected path." |
| Image not found | Use backup image from same directory | "Let me use an alternative image." |
| Grad-CAM is zero | Do not retry — this is the honest output | "The heatmap is all-zero. The model's attention is diffuse for this class." |
| Export fails | Skip export — on-screen report is sufficient | "The file export encountered an error. The on-screen report demonstrates the output." |
| Quality gate blocks GOOD image | Narrate the safety mechanism | "This demonstrates the quality gate. It is conservative by design." |
| Classifier takes >5s | Wait — first-run includes model loading | "First inference includes model initialization. Subsequent inferences are ~26ms." |
| Judge asks about failed detectors | Use honest framing | "We externally validated them and found they don't generalize. We documented this and paused that research line." |
| Judge asks about clinical validation | Do not overclaim | "These are internal evaluation results. Clinical validation requires prospective trials." |
| Screen resolution breaks GUI | Use pre-generated screenshots | "Let me show you the architecture via slides." |

---

## FINAL CHECKLIST BEFORE SIH

```
□ Production code frozen (commit 354bd27)
□ trainedNetTL.mat verified on disk
□ 4 demo images verified on disk
□ drScreeningGUIv2 opens and loads model
□ All 3 demo patients work end-to-end
□ Grad-CAM works on all 3 patients
□ Export works on writable path
□ Export fails safely on unwritable path
□ Regression tests: 73/73 PASS
□ Presentation slides ready
□ Speaking script rehearsed (7 min)
□ Demo script rehearsed (5.5 min)
□ Judge Q&A answers memorized (top 10)
□ Metrics reference card printed
□ Backup USB with project + slides
□ Screen resolution tested on projector
□ MATLAB warnings suppressed or acknowledged
□ Limitations statement rehearsed
□ "Failed segmentation" story rehearsed
```
