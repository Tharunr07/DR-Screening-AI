# 🩺 DRISHTI-AI — Features Adapted from Reference DR Repository

## Purpose

This document records the **application and workflow features selected from the reference repository `gnarendran352-hash/DR`** for possible adaptation into DRISHTI-AI.

The project already has a separately developed and tested DR AI model. Therefore, **the reference repository's AI model, training pipeline, dataset, model weights, and model architecture are NOT being adopted**.

Only relevant non-AI application/workflow ideas are selected.

---

## ✅ Selected Features

### 1. 🎯 Retinal Image Capture Guidance / Alignment

Provide an on-screen guide during retinal image capture so the operator can better position the camera/eye before taking the image.

**Workflow:**

```text
Open Camera
    ↓
Show Retinal Alignment Guide
    ↓
Position Eye / Camera
    ↓
Capture Image
    ↓
Quality Check
```

---

### 2. 🔍 Image Quality Assessment

Check the captured retinal image before sending it to the tested DR AI model.

Possible quality checks:

- Blur / sharpness
- Brightness
- Contrast
- Exposure
- Retina visibility
- Field of view
- Image artifacts

**Workflow:**

```text
Fundus Image
     ↓
Quality Assessment
     ↓
 ┌──────┴──────┐
 ↓             ↓
Good         Poor
 ↓             ↓
Continue    Retake Image
```

---

### 3. 🔄 Retake Guidance for Poor-Quality Images

If the quality gate rejects the image, the application should clearly explain that another image is required rather than passing a poor image to the AI model.

```text
Image
 ↓
Quality Check
 ↓
Poor
 ↓
Show Reason
 ↓
Retake / Upload Again
```

---

### 4. ✨ Image Enhancement

Apply appropriate enhancement to suitable borderline/low-quality images before AI inference, without changing the already-tested AI model itself.

Possible processing can include:

- Contrast enhancement
- CLAHE where appropriate
- Denoising where appropriate
- Normalization required by the existing AI pipeline

```text
Fundus Image
     ↓
Quality Check
     ↓
Borderline Image?
     ↓
Enhancement
     ↓
Re-check / Continue
     ↓
Existing Tested AI
```

---

### 5. 🩺 Referable / Non-Referable Status

Add a screening decision layer after the existing DR prediction to indicate whether the case should be referred for further ophthalmic evaluation.

This must use an appropriately defined and validated clinical decision rule; thresholds should not be copied blindly from the reference repository.

```text
Existing AI DR Result
        ↓
Referable Decision Layer
        ↓
 ┌──────────────┐
 ↓              ↓
Referable   Non-Referable
```

---

### 6. 📄 AI Screening Report

Generate a structured screening report containing the AI screening information and doctor review information.

Suggested contents:

- Patient identifier
- Screening date/time
- Fundus image reference
- DR prediction
- AI confidence
- Risk level
- Referable status
- Explainability output reference
- Doctor assessment
- Doctor notes
- Model version

---

### 7. 👤 Patient Portal / Patient View

Provide a patient-facing view for accessing relevant screening information.

Possible functions:

- Patient ID
- Latest DR result
- View report
- Screening history
- Doctor recommendation
- Follow-up information
- Appointment information

---

### 8. 📜 Screening History

Store and display previous screening records for a patient.

```text
Patient
  ↓
Screening History
  ├── Date
  ├── DR Result
  ├── Confidence
  ├── Risk
  ├── Referable Status
  ├── Doctor Assessment
  └── Report
```

---

### 9. 👨‍⚕️ Doctor Recommendation

Allow the doctor to add a recommendation after reviewing the AI screening result.

```text
AI Screening
     ↓
Doctor Review
     ↓
Doctor Recommendation
     ↓
Patient Record
```

---

### 10. 📅 Appointment / Follow-Up

Provide appointment and follow-up information associated with the screening record.

```text
Screening Result
      ↓
Doctor Recommendation
      ↓
Follow-Up Required?
      ↓
Appointment / Follow-Up
```

---

### 11. 🔥 Grad-CAM Visualization

Use Grad-CAM if it is not already provided by the existing tested AI pipeline.

```text
Fundus Image
     ↓
Existing AI Model
     ↓
Prediction
     ↓
Grad-CAM
     ↓
Heatmap Overlay
```

The heatmap is an explainability aid and must not be presented as definitive clinical lesion localization.

---

### 12. 📍 Lesion Pinpointing

If supported by the existing AI pipeline and suitable validated data, provide visual indication of suspicious retinal regions.

This feature should be treated separately from Grad-CAM if it is intended to represent actual lesion localization.

**Do not claim clinical lesion detection unless the underlying model and validation support that claim.**

---

### 13. 💬 AI Explanation

Show a concise explanation section alongside the AI result, including the prediction, confidence and explainability visualization.

```text
AI Prediction
     ↓
Confidence
     ↓
Explainability Visualization
     ↓
AI Screening Explanation
```

The explanation should clearly distinguish AI output from the doctor's final assessment.

---

### 14. 📊 AI Confidence Display

Display the confidence produced by the existing tested AI model alongside the prediction.

```text
Prediction: Moderate DR
Confidence: <model output>
```

Confidence values must come from the actual model and should not be fabricated.

---

# ❌ Features NOT Taken from the Reference Repository

The following remain part of the existing DRISHTI-AI implementation and are **not copied from the reference repository**:

- DR AI model
- AI model architecture
- AI training code
- AI training pipeline
- Reference repository model weights
- Reference repository dataset
- Reference repository AI evaluation results
- Reference repository preprocessing assumptions when they conflict with the existing tested AI pipeline

The existing tested AI remains the primary DR prediction system.

---

# 🔄 Combined DRISHTI-AI Workflow

```text
Retinal Image Capture
        ↓
Capture Alignment Guidance
        ↓
Image Quality Assessment
        ↓
 ┌───────────────┐
 ↓               ↓
Poor            Good / Usable
 ↓               ↓
Retake           Enhancement if needed
                  ↓
             Existing Tested AI
                  ↓
             DR Prediction
                  ↓
       Prediction + Confidence
                  ↓
          Referable Decision
                  ↓
             Risk Assessment
                  ↓
          Grad-CAM / Explanation
                  ↓
            Screening Result
                  ↓
             Doctor Review
                  ↓
        Doctor Recommendation
                  ↓
          Final Screening Record
                  ↓
          Report + History
                  ↓
       Appointment / Follow-Up
```

---

# 🎯 Implementation Principle

The reference repository is being used only as a source of **relevant application/workflow ideas**.

```text
Reference Repository
        ↓
Select Relevant Features
        ↓
Understand Dependencies
        ↓
Adapt to DRISHTI-AI
        ↓
Integrate with Existing Tested AI
```

The project should not become a copy of the reference repository. The implementation must remain aligned with the official problem statement and the existing DRISHTI-AI architecture.

---

## Priority

### High Priority

1. Retinal image capture guidance
2. Image quality assessment
3. Poor-image retake guidance
4. Image enhancement
5. Referable / non-referable status
6. AI screening report
7. Screening history
8. Doctor recommendation
9. Appointment / follow-up

### Conditional / Existing-AI Dependent

10. Grad-CAM
11. Lesion pinpointing
12. AI explanation
13. Confidence display

These should only be added when they are not already available in the existing tested AI/application pipeline.
