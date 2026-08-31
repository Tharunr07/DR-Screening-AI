# 🧠 DR-Screening-AI — Technologies, Models & Final Workflow

This document defines the recommended technology stack, AI/ML models, tools, and end-to-end implementation workflow for the **DR-Screening-AI** project.

> ⚠️ This is an educational/research prototype. Model outputs are not a standalone medical diagnosis.

---

# 1. Technology Stack Overview

| Layer | Recommended Technology | Purpose |
|---|---|---|
| Frontend | React + Vite | Web application UI |
| Language | JavaScript / TypeScript | Frontend development |
| Styling | Tailwind CSS | Responsive UI |
| Charts | Recharts | Dashboard analytics |
| Backend | Python + FastAPI | REST API and AI integration |
| AI/ML | Python | Model development and inference |
| Deep Learning | PyTorch or TensorFlow | Retinal image classification |
| Computer Vision | OpenCV + Pillow | Image processing |
| ML Utilities | NumPy + Pandas + scikit-learn | Data processing/evaluation |
| Explainable AI | Grad-CAM | Model explanation/heatmap |
| MATLAB | MATLAB + Deep Learning Toolbox + Image Processing Toolbox | Image processing/model experimentation |
| Simulation | Simulink | Screening pipeline simulation |
| Database | PostgreSQL | Users, patients, screenings, reports |
| File Storage | Local/object storage | Fundus images and generated reports |
| API Testing | Postman | Backend/API testing |
| Version Control | Git + GitHub | Collaboration and versioning |
| Environment | Python virtual environment / Conda | Dependency isolation |
| Deployment | Docker (optional) | Reproducible deployment |

---

# 2. Feature → Technology → Model Mapping

| Feature | Technology | Recommended Method / Model | Main Owner |
|---|---|---|---|
| User Login | React + FastAPI + PostgreSQL | JWT/session authentication | Tharun |
| Dashboard | React + Recharts | Statistical aggregation | Narendran |
| Patient Management | React + FastAPI + PostgreSQL | CRUD | Tharun |
| Fundus Image Upload | React + FastAPI | Multipart file upload + validation | Narendran + Tharun |
| Image Quality Assessment | Python/OpenCV or MATLAB | Sharpness, brightness, contrast, exposure and field-of-view checks | Tharun Balaji |
| Image Preprocessing | OpenCV / MATLAB | Resize, crop, enhancement, normalization | Tharun Balaji |
| DR Classification | PyTorch/TensorFlow/MATLAB | Transfer learning CNN: EfficientNet / ResNet / DenseNet | Tharun Balaji |
| DR Severity | AI classifier | Five-class DR classification when supported by dataset | Tharun Balaji |
| Confidence | Model output + calibration | Softmax probability; calibration if required | Tharun Balaji |
| Risk Level | Python/FastAPI | Transparent rule layer based on validated prediction/confidence policy | Tharun Balaji + Tharun |
| Explainable AI | PyTorch/TensorFlow | Grad-CAM / Grad-CAM++ | Tharun Balaji |
| Result API | FastAPI + Pydantic | Validated JSON response | Tharun |
| Result Storage | PostgreSQL | Screening record | Tharun |
| Grad-CAM Display | React | Image overlay viewer | Narendran |
| Doctor Review | React + FastAPI | Human review workflow | Narendran + Tharun |
| Report Generation | Python/FastAPI | PDF report generation | Tharun |
| MATLAB Pipeline | MATLAB | Image Processing + Deep Learning Toolbox | Tharun Balaji |
| Simulink Pipeline | Simulink | Block-based screening/inference workflow | Tharun Balaji |
| Model Evaluation | Python/scikit-learn + MATLAB | Accuracy, Precision, Recall, F1, Sensitivity, Specificity, ROC-AUC, confusion matrix | Tharun Balaji |
| API Testing | Postman / pytest | Unit and integration tests | Tharun |
| Frontend Testing | React testing tools | Component/workflow tests | Narendran |
| Collaboration | Git/GitHub | Feature branches + Pull Requests | All members |

---

# 3. AI Model Selection Strategy

## 3.1 Candidate Models

Start with transfer-learning models rather than building a CNN entirely from scratch.

### Recommended candidates

1. **EfficientNet** — strong accuracy/parameter efficiency candidate.
2. **ResNet** — reliable baseline and easy to benchmark.
3. **DenseNet** — useful candidate for medical-image classification.

The team should train at least a baseline and compare candidates using the same data split and evaluation protocol.

## 3.2 Final Model Selection

The final model must be selected from measured experiments, not a predetermined accuracy target.

Selection criteria:

```text
Validation/Test Performance
        ↓
Generalization
        ↓
Class-wise Recall
        ↓
F1 / ROC-AUC
        ↓
Inference Time
        ↓
Model Size
        ↓
Explainability Quality
        ↓
Final Model
```

Do not claim 94–97% accuracy unless the independent test results actually demonstrate it.

---

# 4. Image Quality Assessment

The quality module should run before classification.

```text
Fundus Image
     ↓
Sharpness / Blur
     ↓
Brightness / Exposure
     ↓
Contrast
     ↓
Retina Visibility
     ↓
Field of View
     ↓
Artifact Check
     ↓
 ┌───────────────┐
 │ Quality Score │
 └───────┬───────┘
         ↓
   ┌─────┴─────┐
   ↓           ↓
Accept       Reject
   ↓           ↓
AI Pipeline  Re-upload
```

Possible implementation:

- OpenCV for automated image statistics.
- MATLAB Image Processing Toolbox for experimentation/validation.
- A learned quality model may be added later if the dataset supports it.

---

# 5. Image Preprocessing

Recommended pipeline:

```text
Original Fundus Image
        ↓
Image Validation
        ↓
Crop / Retina Region
        ↓
Resize
        ↓
Noise Reduction (if required)
        ↓
Contrast Enhancement (if validated)
        ↓
Normalization
        ↓
Model Input
```

Every preprocessing step must be validated experimentally because aggressive enhancement can remove or distort clinically relevant information.

---

# 6. DR Classification Workflow

When the selected dataset provides five severity classes:

```text
                         Fundus Image
                              ↓
                         Preprocessing
                              ↓
                       Deep Learning CNN
                              ↓
                   ┌──────────┴──────────┐
                   ↓                     ↓
              DR Prediction          Confidence
                   ↓                     ↓
             Five Classes          Probability
                   └──────────┬──────────┘
                              ↓
                       Risk Assessment
                              ↓
                           Grad-CAM
                              ↓
                       Final Screening
```

Classes:

```text
0 → No DR
1 → Mild DR
2 → Moderate DR
3 → Severe DR
4 → Proliferative DR
```

The exact class mapping must match the chosen dataset's official labels.

---

# 7. Explainable AI Model

Use **Grad-CAM** for CNN-based models where the architecture supports it.

```text
Image
  ↓
CNN
  ↓
Predicted Class
  ↓
Grad-CAM
  ↓
Activation Map
  ↓
Resize Heatmap
  ↓
Overlay on Fundus Image
  ↓
Display to Reviewer
```

Purpose:

- Show image regions associated with the model prediction.
- Help reviewers understand model behavior.
- Support debugging and model validation.

The heatmap is an explanation of model behavior, not proof of a clinical lesion.

---

# 8. Risk Assessment

Risk should be implemented as a **transparent screening policy**, not as an invented AI score.

Example architecture:

```text
DR Prediction
      +
Validated Confidence / Quality Information
      ↓
Risk Policy
      ↓
Low / Medium / High
```

The final risk thresholds must be defined and documented by the team after reviewing the project requirements and validation results.

---

# 9. MATLAB Technology Usage

MATLAB should be used for the engineering/AI portion requested by the project.

Recommended toolboxes:

- MATLAB
- Deep Learning Toolbox
- Image Processing Toolbox
- Statistics and Machine Learning Toolbox (if required)
- Computer Vision Toolbox (if required)

MATLAB workflow:

```text
Dataset
   ↓
Image Datastore
   ↓
Preprocessing
   ↓
Augmentation
   ↓
Transfer Learning
   ↓
Training
   ↓
Validation
   ↓
Testing
   ↓
Metrics
   ↓
Grad-CAM / Explainability
```

---

# 10. Simulink Technology Usage

Simulink demonstrates the block-level screening pipeline.

```text
┌───────────────┐
│ Image Source  │
└───────┬───────┘
        ↓
┌───────────────┐
│ Preprocessing │
└───────┬───────┘
        ↓
┌───────────────┐
│ AI Inference  │
└───────┬───────┘
        ↓
┌───────────────┐
│ Classification│
└───────┬───────┘
        ↓
┌───────────────┐
│ Risk / Output │
└───────────────┘
```

Simulink should represent the validated processing/inference design rather than being treated as a separate medical diagnostic system.

---

# 11. Backend Technology

Recommended backend stack:

```text
Python
  ↓
FastAPI
  ↓
Pydantic
  ↓
AI Service
  ↓
PostgreSQL
```

Suggested backend modules:

```text
backend/
└── app/
    ├── main.py
    ├── routes/
    │   ├── auth.py
    │   ├── patients.py
    │   ├── screening.py
    │   └── reports.py
    ├── schemas/
    ├── models/
    ├── services/
    │   ├── ai_service.py
    │   ├── image_service.py
    │   └── report_service.py
    └── database/
```

---

# 12. Frontend Technology

Recommended frontend:

```text
React + Vite
     ↓
TypeScript / JavaScript
     ↓
Tailwind CSS
     ↓
Recharts
     ↓
REST API
```

Main pages:

```text
Landing
 ↓
Login
 ↓
Dashboard
 ↓
Patients
 ↓
New Screening
 ↓
Upload Image
 ↓
Processing
 ↓
Result
 ↓
Grad-CAM
 ↓
Doctor Review
 ↓
Report
```

---

# 13. Database Technology

Recommended: **PostgreSQL**.

Core tables:

```text
users
patients
screenings
reports
```

Relationships:

```text
User
  ↓
Patient
  ↓
Screening
  ↓
Report
```

Fundus images should preferably be stored in controlled file/object storage with references stored in the database rather than placing large binary images directly into ordinary relational rows.

---

# 14. Final End-to-End Technology Workflow

This is the **final integrated workflow** for the project.

```text
                         👨‍⚕️ DOCTOR / USER
                                  │
                                  ▼
                       React + Tailwind CSS
                                  │
                                  │ REST API
                                  ▼
                         Python + FastAPI
                                  │
             ┌────────────────────┼────────────────────┐
             │                    │                    │
             ▼                    ▼                    ▼
        PostgreSQL            AI Service          File Storage
             │                    │                    │
             │                    ▼                    │
             │             Image Quality               │
             │             OpenCV / MATLAB             │
             │                    │                    │
             │                    ▼                    │
             │             Preprocessing               │
             │          OpenCV / MATLAB                │
             │                    │                    │
             │                    ▼                    │
             │          Deep Learning Model            │
             │      PyTorch / TensorFlow / MATLAB     │
             │                    │                    │
             │                    ▼                    │
             │           DR Classification             │
             │                    │                    │
             │                    ├── Prediction       │
             │                    ├── Confidence       │
             │                    └── Risk             │
             │                    │                    │
             │                    ▼                    │
             │              Grad-CAM                  │
             │                    │                    │
             │                    ▼                    │
             │            Explainable Result           │
             │                    │                    │
             └────────────────────┼────────────────────┘
                                  ▼
                          Doctor Review UI
                                  │
                         ┌────────┴────────┐
                         ▼                 ▼
                      Confirm           Modify
                         │                 │
                         └────────┬────────┘
                                  ▼
                           Final Screening
                                  │
                                  ▼
                           Report Generation
                                  │
                                  ▼
                           Screening History
```

---

# 15. MATLAB + Simulink + Web Integration

The project has two related paths:

### Research/Model Development Path

```text
Dataset
  ↓
MATLAB / Python
  ↓
Preprocessing
  ↓
Model Training
  ↓
Evaluation
  ↓
Grad-CAM
  ↓
Validated Model
```

### Application Path

```text
React
  ↓
FastAPI
  ↓
AI Inference Service
  ↓
Validated Model
  ↓
Prediction
  ↓
Database
  ↓
React Result
```

### Simulation Path

```text
Validated Processing Design
          ↓
       Simulink
          ↓
Block-Level Screening Pipeline
          ↓
Simulation / Demonstration
```

---

# 16. Team Technology Responsibilities

## Tharun Balaji — AI / MATLAB / Simulink

```text
Dataset
  ↓
Preprocessing
  ↓
Image Quality
  ↓
Deep Learning
  ↓
Model Evaluation
  ↓
Grad-CAM
  ↓
MATLAB
  ↓
Simulink
  ↓
AI Inference Contract
```

## Tharun — Backend / Database / Integration

```text
FastAPI
  ↓
Authentication
  ↓
Patient APIs
  ↓
Screening APIs
  ↓
AI Integration
  ↓
PostgreSQL
  ↓
Reports
```

## Narendran — Frontend / UI / UX

```text
React
  ↓
Landing Page
  ↓
Login
  ↓
Dashboard
  ↓
Patients
  ↓
Upload
  ↓
Screening Result
  ↓
Grad-CAM Viewer
  ↓
Doctor Review
  ↓
Reports
```

All three members participate in testing, integration, documentation, debugging, research, and presentation.

---

# 17. Final AI Output Contract

The AI service should return a stable structure for backend integration.

```json
{
  "prediction": "Moderate DR",
  "class_id": 2,
  "confidence": 0.942,
  "risk_level": "Medium",
  "heatmap_reference": "heatmap/SCR001.png",
  "model_version": "dr-model-v1"
}
```

The example values are illustrative only. Production values must be generated by the actual model.

---

# 18. Development Order

```text
1. Dataset Setup
       ↓
2. Dataset Analysis
       ↓
3. Image Quality Module
       ↓
4. Preprocessing
       ↓
5. Baseline Model
       ↓
6. Candidate Model Comparison
       ↓
7. Final Model
       ↓
8. Test Evaluation
       ↓
9. Grad-CAM
       ↓
10. MATLAB Implementation
       ↓
11. Simulink Implementation
       ↓
12. FastAPI AI Integration
       ↓
13. PostgreSQL Integration
       ↓
14. React Integration
       ↓
15. Doctor Review
       ↓
16. Reports
       ↓
17. Full-System Testing
       ↓
18. Final Demo
```

---

# 19. GitHub Rules for This Project

```text
✅ Source code → GitHub
✅ Documentation → GitHub
✅ MATLAB scripts → GitHub
✅ Simulink model → GitHub
✅ API schemas → GitHub
✅ Dataset instructions → GitHub

❌ Large/private dataset → Do not commit
❌ Patient-identifiable data → Do not commit
❌ API keys → Do not commit
❌ Passwords/secrets → Do not commit
❌ .env → Do not commit
```

---

# 20. Final Technology Summary

```text
                 DR-SCREENING-AI
                         │
       ┌─────────────────┼─────────────────┐
       │                 │                 │
       ▼                 ▼                 ▼
    FRONTEND          BACKEND             AI
    React             FastAPI          Python/MATLAB
    Vite              PostgreSQL       PyTorch/TensorFlow
    Tailwind          Pydantic         OpenCV
    Recharts          REST API         Grad-CAM
       │                 │                 │
       └─────────────────┼─────────────────┘
                         │
                         ▼
                     SIMULINK
                         │
                         ▼
                 FINAL WEB PLATFORM
```

**Final result:** a web-based diabetic retinopathy screening prototype where the frontend handles the user experience, FastAPI handles application and AI integration, the AI/MATLAB pipeline performs image analysis and classification, Grad-CAM provides explainability, PostgreSQL stores screening metadata, and Simulink demonstrates the engineering workflow.
