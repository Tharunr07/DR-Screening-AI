# 🩺 DR-Screening-AI

## AI-Powered Diabetic Retinopathy Screening Platform

DR-Screening-AI is an AI-assisted diabetic retinopathy screening platform designed to analyze retinal fundus images, assess image quality, predict diabetic retinopathy severity, provide explainable AI visualizations, and present results through a web application.

The project combines **MATLAB, Simulink, Deep Learning, Computer Vision, Explainable AI, FastAPI, React, and Database Management** into one integrated screening workflow.

> ⚠️ **Disclaimer:** This project is intended for educational, research, and prototype purposes. It is not a replacement for professional medical diagnosis or clinical judgment.

---

# 🎯 1. Project Objective

The system is designed to:

1. Accept a retinal fundus image.
2. Check whether the image is suitable for analysis.
3. Preprocess the retinal image.
4. Analyze the image using an AI/deep-learning model.
5. Classify diabetic retinopathy severity.
6. Generate prediction confidence.
7. Estimate a screening risk level.
8. Generate an explainable AI visualization.
9. Store screening information.
10. Display results through a web application.
11. Allow doctor/reviewer validation of the AI result.
12. Generate a screening report.

---

# 🏗️ 2. COMPLETE SYSTEM ARCHITECTURE

```text
                         👤 USER / DOCTOR
                                │
                                ▼
                    ┌─────────────────────┐
                    │    REACT WEBSITE    │
                    │                     │
                    │ Login               │
                    │ Dashboard           │
                    │ Patient Management  │
                    │ Image Upload        │
                    │ Screening           │
                    │ Results             │
                    │ Reports             │
                    └──────────┬──────────┘
                               │
                               │ REST API
                               ▼
                    ┌─────────────────────┐
                    │      FASTAPI        │
                    │      BACKEND        │
                    │                     │
                    │ Authentication      │
                    │ Patient APIs        │
                    │ Screening APIs      │
                    │ AI Integration      │
                    │ Report APIs         │
                    └───────┬───────┬─────┘
                            │       │
                  ┌─────────┘       └─────────┐
                  ▼                           ▼
        ┌──────────────────┐        ┌──────────────────┐
        │   AI / MATLAB    │        │    DATABASE      │
        │                  │        │                  │
        │ Quality Check    │        │ Users            │
        │ Preprocessing    │        │ Patients         │
        │ Deep Learning    │        │ Screenings       │
        │ Classification   │        │ Predictions      │
        │ Grad-CAM         │        │ Reports          │
        │ Evaluation       │        └──────────────────┘
        └────────┬─────────┘
                 │
                 ▼
        ┌──────────────────┐
        │     SIMULINK     │
        │ System Simulation│
        └──────────────────┘
```

---

# 📱 3. APPLICATION STRUCTURE

```text
DR-Screening-AI
│
├── 🌐 Frontend
│   ├── Landing Page
│   ├── Login
│   ├── Dashboard
│   ├── Patient Management
│   ├── New Screening
│   ├── Image Upload
│   ├── Screening Result
│   ├── Explainable AI
│   ├── Doctor Review
│   ├── Screening History
│   └── Reports
│
├── ⚡ Backend
│   ├── Authentication
│   ├── User Management
│   ├── Patient Management
│   ├── Screening API
│   ├── AI Integration
│   ├── Database Management
│   └── Report Generation
│
├── 🧠 AI / MATLAB
│   ├── Dataset
│   ├── Image Quality Assessment
│   ├── Preprocessing
│   ├── Deep Learning
│   ├── DR Classification
│   ├── Grad-CAM
│   └── Model Evaluation
│
└── ⚙️ Simulink
    ├── Image Input
    ├── Preprocessing
    ├── AI Inference
    ├── Risk Assessment
    └── Output
```

---

# 🖥️ 4. WEB APPLICATION PAGES

## 4.1 Landing Page

```text
Home
├── Hero Section
├── Problem
├── Solution
├── How It Works
├── AI Technology
├── Benefits
├── About Project
└── Contact
```

## 4.2 Login

```text
Login
 │
 ├── Email / Username
 ├── Password
 └── Login
       │
       ▼
    Dashboard
```

## 4.3 Dashboard

The dashboard displays:

- Total patients
- Total screenings
- High-risk cases
- Pending reviews
- Screening trends
- DR-stage distribution
- Risk distribution
- Recent screenings

## 4.4 Patient Management

```text
Patients
   │
   ├── Add Patient
   ├── Search Patient
   ├── Patient List
   └── Patient Profile
          ├── Patient Information
          ├── Screening History
          ├── Previous Results
          └── Reports
```

## 4.5 New Screening

```text
Select Patient
      ↓
Upload Fundus Image
      ↓
Preview Image
      ↓
Image Quality Check
      ↓
Preprocessing
      ↓
AI Analysis
      ↓
DR Prediction
      ↓
Explainable AI
      ↓
Risk Assessment
      ↓
Final Result
```

---

# 📷 5. IMAGE QUALITY CHECK

Before AI classification, the system should assess whether the retinal image is usable.

Possible checks:

- Blur / sharpness
- Brightness
- Contrast
- Exposure
- Retina visibility
- Field of view
- Artifacts

```text
                    IMAGE
                      │
                      ▼
               Quality Analysis
                      │
             ┌────────┴────────┐
             │                 │
          QUALITY OK        QUALITY BAD
             │                 │
             ▼                 ▼
      Continue Processing   Upload Again
```

---

# 🧠 6. AI / MATLAB WORKFLOW

```text
                 RETINAL IMAGE
                       │
                       ▼
               Image Quality Check
                       │
              ┌────────┴────────┐
              │                 │
           Poor Image       Good Image
              │                 │
              ▼                 ▼
         Reject Image      Preprocessing
                                │
                                ▼
                         Image Enhancement
                                │
                                ▼
                            Normalization
                                │
                                ▼
                       Deep Learning Model
                                │
                                ▼
                       DR Classification
                                │
                     ┌──────────┼──────────┐
                     ▼          ▼          ▼
                   Stage   Confidence    Risk
                     │          │          │
                     └──────────┼──────────┘
                                │
                                ▼
                           Grad-CAM
                                │
                                ▼
                      Explainable Result
                                │
                                ▼
                         Model Evaluation
```

---

# 🔬 7. IMAGE PREPROCESSING

The preprocessing pipeline may include:

```text
Original Image
      │
      ▼
Resize
      │
      ▼
Retina Region Detection / Cropping
      │
      ▼
Noise Reduction
      │
      ▼
Contrast Enhancement
      │
      ▼
Normalization
      │
      ▼
Processed Image
```

The exact preprocessing pipeline will be finalized after validating its effect on model performance.

---

# 🤖 8. AI MODEL

The AI component will use deep learning / transfer learning for diabetic retinopathy classification.

Candidate architectures may include:

- ResNet
- EfficientNet
- DenseNet
- Other suitable pretrained CNN architectures

The final model should be chosen based on validation performance, generalization, inference time, model size, explainability, and available hardware.

---

# 👁️ 9. DR CLASSIFICATION

A five-stage classification can be used when supported by the selected dataset and problem definition:

```text
                 AI CLASSIFIER
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
        No DR       Mild DR    Moderate DR
                                  │
                           ┌──────┴──────┐
                           ▼             ▼
                       Severe DR    Proliferative DR
```

Example output:

```text
Prediction: Moderate DR
Confidence: 94.2%
Risk: Medium
```

> The values above are examples only. Actual confidence and performance values must come from the trained model and independent test data.

---

# 🔥 10. EXPLAINABLE AI

Grad-CAM or another validated explainability technique can be used to visualize image regions that contributed to the model prediction.

```text
Fundus Image
     │
     ▼
 AI Model
     │
     ▼
Prediction
     │
     ▼
 Grad-CAM
     │
     ▼
Activation Map
     │
     ▼
Heatmap Overlay
```

The heatmap is a model-behavior explanation and should not be treated as definitive clinical lesion localization.

---

# 📊 11. MODEL EVALUATION

The trained model must be evaluated on an independent test set.

Metrics:

- Accuracy
- Precision
- Recall
- F1-Score
- Sensitivity
- Specificity
- ROC-AUC
- Confusion Matrix

```text
Test Dataset
     │
     ▼
AI Model
     │
     ▼
Predictions
     │
     ├── Accuracy
     ├── Precision
     ├── Recall
     ├── F1-Score
     ├── Sensitivity
     ├── Specificity
     └── ROC-AUC
              │
              ▼
       Performance Report
```

---

# ⚡ 12. BACKEND WORKFLOW

```text
                   React
                     │
                     │ HTTP Request
                     ▼
                  FastAPI
                     │
          ┌──────────┼──────────┐
          │          │          │
          ▼          ▼          ▼
      Validation    AI       Database
          │        Service       │
          │          │           │
          │          ▼           │
          │      Prediction      │
          │          │           │
          └──────────┼───────────┘
                     │
                     ▼
                API Response
                     │
                     ▼
                   React
```

---

# 🔌 13. MAIN API STRUCTURE

```text
/api
│
├── /auth
│   ├── POST /login
│   └── POST /logout
│
├── /patients
│   ├── POST /
│   ├── GET /
│   ├── GET /{id}
│   ├── PUT /{id}
│   └── DELETE /{id}
│
├── /screening
│   ├── POST /analyze
│   ├── GET /{id}
│   └── GET /patient/{id}
│
└── /reports
    ├── GET /{id}
    └── POST /generate
```

The API contract will be finalized before frontend/backend integration.

---

# 🗄️ 14. DATABASE STRUCTURE

Possible entities:

```text
Users
├── user_id
├── name
├── email
├── password_hash
└── role

Patients
├── patient_id
├── name
├── age
├── gender
└── created_at

Screenings
├── screening_id
├── patient_id
├── image_reference
├── prediction
├── confidence
├── risk_level
├── doctor_status
└── created_at

Reports
├── report_id
├── screening_id
├── doctor_notes
├── report_reference
└── created_at
```

Only necessary information should be collected and stored, and sensitive real patient data must not be committed to GitHub.

---

# 👨‍⚕️ 15. DOCTOR REVIEW WORKFLOW

```text
              AI Prediction
                    │
                    ▼
             Doctor Review
                    │
           ┌────────┴────────┐
           │                 │
        Confirm            Modify
           │                 │
           └────────┬────────┘
                    ▼
              Doctor Notes
                    │
                    ▼
             Save Final Result
                    │
                    ▼
              Generate Report
```

The application should clearly distinguish between the AI prediction and the doctor's final recorded assessment.

---

# 📄 16. FINAL RESULT SCREEN

```text
┌──────────────────────────────────────────┐
│          SCREENING RESULT                │
├──────────────────────────────────────────┤
│ Patient: Patient ID / Name              │
│ Date: DD-MM-YYYY                         │
│                                          │
│ Prediction: Moderate DR                  │
│ Confidence: 94.2%                        │
│ Risk Level: Medium                       │
│                                          │
│ ┌──────────────┐  ┌───────────────────┐ │
│ │ Original     │  │ Grad-CAM          │ │
│ │ Fundus Image │  │ Explanation       │ │
│ └──────────────┘  └───────────────────┘ │
│                                          │
│ AI Findings / Explanation                │
│                                          │
│ Doctor Review                            │
│ ┌──────────────────────────────────────┐ │
│ │ Notes...                             │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ [Confirm] [Modify] [Generate Report]     │
└──────────────────────────────────────────┘
```

---

# 👥 17. THREE-MEMBER TEAM STRUCTURE

The project uses a **flexible 3-member responsibility model**. Each member has a primary area, but nobody is permanently restricted to one module.

```text
                    PROJECT
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
     AI / DATA      BACKEND        FRONTEND
        │              │              │
        └──────────────┼──────────────┘
                       │
                       ▼
                  INTEGRATION
                       │
                       ▼
                  FINAL SYSTEM
```

---

# 👨‍💻 18. MEMBER A — THSRUN BALAJI

### Primary: AI / Data / MATLAB / Simulink

Responsibilities:

- Dataset management
- Data cleaning and organization
- Dataset documentation
- Image quality assessment
- Image preprocessing
- Deep learning model development
- Model training and validation
- Model evaluation
- Grad-CAM / Explainable AI
- MATLAB implementation
- Simulink implementation
- AI inference pipeline

### Backup Responsibilities

- FastAPI integration
- API input/output understanding
- Database understanding
- Basic frontend integration

---

# 👨‍💻 19. MEMBER B — THARUN

### Primary: Backend / Database / AI Integration

Responsibilities:

- FastAPI setup and development
- Authentication and authorization
- Patient APIs
- Screening APIs
- Database design and integration
- AI model integration
- Image/file handling
- Result storage
- Report generation
- Backend testing

### Backup Responsibilities

- React and API integration
- Frontend debugging
- Basic AI pipeline understanding
- MATLAB input/output understanding

---

# 👨‍💻 20. MEMBER C — NARENDRA N

### Primary: Frontend / UI / UX

Responsibilities:

- React application development
- UI/UX design
- Landing page
- Login page
- Dashboard
- Patient management
- Image upload
- Screening interface
- Result page
- Grad-CAM visualization
- Doctor review UI
- Reports UI
- Charts and data visualization
- Responsive design
- Frontend testing

### Backup Responsibilities

- AI/ML workflow understanding
- Dataset structure understanding
- Basic MATLAB workflow
- Backend API integration

---

# ⚖️ 21. EQUAL CONTRIBUTION MODEL

All three members contribute to:

```text
Development
Testing
Documentation
Integration
Debugging
Research
Presentation
Demo
```

Primary responsibility means **coordination**, not ownership or restriction.

```text
Thsrun Balaji → AI primary + Backend backup
Tharun        → Backend primary + Frontend backup
NArendran     → Frontend primary + AI backup
```

Any member can work on another area whenever required.

---

# 🔄 22. WORK SWITCHING SYSTEM

When a member needs to switch to another module:

```text
Current Task
     │
     ▼
Commit Current Work
     │
     ▼
Push to GitHub
     │
     ▼
Update Documentation
     │
     ▼
Another Member Pulls Latest Code
     │
     ▼
Understands Current Status
     │
     ▼
Continues Development
```

Every critical module should contain enough documentation for another member to continue development without depending on the original developer.

---

# 🧩 23. CROSS-TRAINING REQUIREMENT

Every member should understand the basic operation of all major modules.

### AI / ML Knowledge

- Dataset structure
- Input/output image format
- Model input
- Model output
- Prediction format
- Basic inference process

### Backend Knowledge

- API endpoints
- Request/response format
- Database basics
- AI service integration

### Frontend Knowledge

- React structure
- Components
- API calls
- Result rendering
- Screening workflow

---

# 🔗 24. INTEGRATION CONTRACT

The AI-to-backend output should follow a documented structure.

Example:

```json
{
  "prediction": "Moderate DR",
  "confidence": 0.942,
  "risk_level": "Medium",
  "heatmap_reference": "heatmap/SCR001.png"
}
```

The final schema will be agreed by all three members before integration.

---

# 🔗 25. COMPLETE END-TO-END WORKFLOW

```text
                         👨‍⚕️ DOCTOR
                             │
                             ▼
                       Login to System
                             │
                             ▼
                          Dashboard
                             │
                             ▼
                       Select Patient
                             │
                             ▼
                     Start New Screening
                             │
                             ▼
                      Upload Fundus Image
                             │
                             ▼
                       Image Validation
                             │
                       ┌─────┴─────┐
                       │           │
                    Invalid       Valid
                       │           │
                       ▼           ▼
                 Upload Again   Preprocessing
                                    │
                                    ▼
                               AI Analysis
                                    │
                                    ▼
                              DR Prediction
                                    │
                       ┌────────────┼────────────┐
                       │            │            │
                       ▼            ▼            ▼
                     Stage      Confidence      Risk
                       │            │            │
                       └────────────┼────────────┘
                                    │
                                    ▼
                               Grad-CAM
                                    │
                                    ▼
                           Explainable Result
                                    │
                                    ▼
                              Store Result
                                    │
                                    ▼
                            Doctor Review
                                    │
                         ┌──────────┴──────────┐
                         │                     │
                      Confirm                Modify
                         │                     │
                         └──────────┬──────────┘
                                    ▼
                              Final Result
                                    │
                                    ▼
                              Generate Report
                                    │
                                    ▼
                           Screening History
```

---

# 🧩 26. GITHUB REPOSITORY STRUCTURE

```text
DR-Screening-AI/
│
├── frontend/
│   ├── public/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── layouts/
│   │   ├── services/
│   │   ├── hooks/
│   │   └── utils/
│   ├── package.json
│   └── README.md
│
├── backend/
│   ├── app/
│   │   ├── routes/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   ├── database/
│   │   └── main.py
│   ├── tests/
│   ├── requirements.txt
│   └── README.md
│
├── ai-matlab/
│   ├── preprocessing/
│   ├── models/
│   ├── explainability/
│   ├── evaluation/
│   ├── scripts/
│   ├── tests/
│   └── README.md
│
├── simulink/
│   ├── screening_system.slx
│   └── README.md
│
├── sample-data/
│   └── README.md
│
├── docs/
│   ├── architecture/
│   ├── flowcharts/
│   ├── api/
│   ├── research/
│   ├── dataset/
│   └── reports/
│
├── .gitignore
└── README.md
```

---

# 🌿 27. GITHUB BRANCHING STRATEGY

```text
                         main
                          │
                          ▼
                       develop
                          │
             ┌────────────┼────────────┐
             │            │            │
             ▼            ▼            ▼
       Thsrun Balaji    Tharun      NArendran
          AI/ML        Backend       Frontend
             │            │            │
             └────────────┼────────────┘
                          ▼
                     Integration
                          │
                          ▼
                         main
```

Suggested feature branches:

```text
feature/ai
feature/backend
feature/frontend
feature/image-preprocessing
feature/cnn-model
feature/gradcam
feature/authentication
feature/screening-api
feature/database
feature/dashboard
feature/screening-ui
feature/report-ui
```

---

# 🔀 28. GITHUB DEVELOPMENT WORKFLOW

```text
Create Feature
      │
      ▼
Create Branch
      │
      ▼
Develop
      │
      ▼
Test Locally
      │
      ▼
Git Commit
      │
      ▼
Git Push
      │
      ▼
Pull Request
      │
      ▼
Code Review
      │
      ▼
Merge → develop
      │
      ▼
Integration Testing
      │
      ▼
Merge → main
```

---

# 📦 29. DATASET MANAGEMENT

The complete retinal dataset should normally remain outside the GitHub repository.

Recommended setup:

```text
Thsrun Balaji
│
├── Full Dataset
├── Training Set
├── Validation Set
└── Test Set
```

GitHub should contain dataset documentation and only small sample files when licensing permits.

```text
sample-data/
└── README.md
```

Dataset documentation should include:

- Dataset source
- Download instructions
- Folder structure
- Class definitions
- Train/validation/test split
- Preprocessing requirements

---

# 🔐 30. SECURITY

Never commit:

```text
❌ API keys
❌ Database passwords
❌ JWT secrets
❌ Cloud credentials
❌ .env files
❌ Private patient data
❌ Sensitive medical images
```

Use `.env` for local secrets and `.env.example` for documenting required variables.

---

# 🧪 31. TESTING STRATEGY

## AI Testing

```text
Input Image
     ↓
Preprocessing
     ↓
Model
     ↓
Prediction
     ↓
Grad-CAM
```

## Backend Testing

```text
API Request
     ↓
Validation
     ↓
AI Service
     ↓
Database
     ↓
API Response
```

## Frontend Testing

```text
User
 ↓
Upload Image
 ↓
API Call
 ↓
Loading State
 ↓
Result
 ↓
Visualization
```

## Full System Testing

```text
Login
 ↓
Patient
 ↓
Upload Image
 ↓
AI Analysis
 ↓
Prediction
 ↓
Heatmap
 ↓
Database
 ↓
Doctor Review
 ↓
Report
```

---

# 📅 32. DEVELOPMENT PHASES

## Phase 1 — Project Setup

```text
GitHub
 ↓
Repository
 ↓
Folder Structure
 ↓
Development Environment
```

## Phase 2 — Parallel Development

```text
AI/ML        Backend        Frontend
 │              │              │
 ▼              ▼              ▼
Dataset       API            UI
Model         DB             Dashboard
MATLAB        Auth           Screening
```

## Phase 3 — Integration

```text
Frontend
    ↕
FastAPI
    ↕
AI Model
    ↕
Database
```

## Phase 4 — Advanced Features

```text
Grad-CAM
Image Quality
Risk Assessment
Doctor Review
Reports
Simulink
```

## Phase 5 — Testing

```text
Unit Tests
    ↓
Integration Tests
    ↓
System Tests
    ↓
Performance Tests
    ↓
Final Demo
```

---

# 🚀 33. FINAL END RESULT

The completed system should provide:

```text
              👨‍⚕️ DOCTOR
                  │
                  ▼
                LOGIN
                  │
                  ▼
              DASHBOARD
                  │
                  ▼
            PATIENT PROFILE
                  │
                  ▼
            NEW SCREENING
                  │
                  ▼
          UPLOAD FUNDUS IMAGE
                  │
                  ▼
          IMAGE QUALITY CHECK
                  │
                  ▼
             AI PROCESSING
                  │
                  ▼
        ┌─────────────────────┐
        │      AI RESULT      │
        │                     │
        │ DR Stage            │
        │ Confidence          │
        │ Risk Level          │
        │                     │
        │ Original Image      │
        │ Grad-CAM Heatmap    │
        └──────────┬──────────┘
                   │
                   ▼
             DOCTOR REVIEW
                   │
                   ▼
             FINAL RESULT
                   │
                   ▼
            GENERATE REPORT
                   │
                   ▼
          SCREENING HISTORY
```

---

# 🏆 34. FINAL PROJECT OUTPUT

The completed platform will combine:

```text
┌────────────────────────────────────────────┐
│       DR-SCREENING-AI PLATFORM            │
├────────────────────────────────────────────┤
│                                            │
│ 🌐 React Web Application                  │
│ 🧠 AI Diabetic Retinopathy Detection      │
│ 🔬 MATLAB Image Processing                │
│ ⚙️ Simulink System Simulation              │
│ 🔥 Explainable AI / Grad-CAM               │
│ ⚡ FastAPI Backend                         │
│ 🗄️ Database                               │
│ 👨‍⚕️ Doctor Review                          │
│ 📄 Screening Report                        │
│                                            │
└────────────────────────────────────────────┘
```

---

# 👥 35. TEAM CONTRIBUTION SUMMARY

| Work Area | Thsrun Balaji | Tharun | NArendran |
|---|---:|---:|---:|
| Dataset | ⭐ Primary | Support | Support |
| Image Processing | ⭐ Primary | Support | Support |
| AI / Deep Learning | ⭐ Primary | Support | Support |
| MATLAB | ⭐ Primary | Support | Support |
| Simulink | ⭐ Primary | Support | Support |
| FastAPI | Support | ⭐ Primary | Support |
| Database | Support | ⭐ Primary | Support |
| AI Integration | Support | ⭐ Primary | Support |
| React | Support | Support | ⭐ Primary |
| UI/UX | Support | Support | ⭐ Primary |
| Dashboard | Support | Support | ⭐ Primary |
| Testing | ⭐ | ⭐ | ⭐ |
| Integration | ⭐ | ⭐ | ⭐ |
| Documentation | ⭐ | ⭐ | ⭐ |
| Presentation | ⭐ | ⭐ | ⭐ |

> ⭐ **Primary** means the member coordinates the area. It does not prevent other members from contributing or taking over the work.

---

# 🤝 36. TEAM WORKING PRINCIPLE

### Equal Contribution

All three members contribute to development, testing, research, documentation, integration, debugging, and presentation.

### Flexible Responsibilities

Any member can switch to another work area when required.

### Shared Knowledge

No critical part of the system should be understood by only one person.

### GitHub First

Important code changes should be committed and pushed to GitHub so the work can be transferred between members.

### Documentation First

Every major module should include setup, usage, testing, and handover instructions.

---

# 🎯 37. PROJECT SUCCESS CRITERIA

```text
✅ User can login
        ↓
✅ User can create/select patient
        ↓
✅ User can upload fundus image
        ↓
✅ System validates image
        ↓
✅ AI processes image
        ↓
✅ DR stage is predicted
        ↓
✅ Confidence is generated
        ↓
✅ Explainability visualization is generated
        ↓
✅ Result is stored
        ↓
✅ Doctor can review result
        ↓
✅ Report can be generated
        ↓
✅ Screening history is available
```

---

# 📜 38. DISCLAIMER

This project is developed for educational, research, and prototype purposes.

The AI output is intended to support a screening workflow and should not be treated as a standalone medical diagnosis.

Clinical decisions must be made by qualified healthcare professionals using appropriate clinical evaluation.
