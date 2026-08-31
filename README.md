# 🩺 DR-Screening-AI

## AI-Powered Diabetic Retinopathy Screening Platform

DR-Screening-AI is an AI-assisted diabetic retinopathy screening platform that analyzes retinal fundus images, checks image quality, predicts diabetic retinopathy severity, provides explainable AI visualizations, and presents results through a web application.

**Technology:** MATLAB • Simulink • Deep Learning • Computer Vision • Explainable AI • FastAPI • React • Database

> ⚠️ Educational/research prototype only. AI results must not be treated as a standalone medical diagnosis.

---

# 🎯 1. PROJECT OBJECTIVE

The system will:

1. Accept a retinal fundus image.
2. Validate image quality.
3. Preprocess the image.
4. Run a deep-learning model.
5. Classify diabetic retinopathy severity.
6. Generate prediction confidence.
7. Determine a screening risk level.
8. Generate Grad-CAM/explainability output.
9. Store screening information.
10. Display results in a web application.
11. Allow doctor/reviewer validation.
12. Generate a screening report.

---

# 🏗️ 2. COMPLETE SYSTEM ARCHITECTURE

```text
                         👤 USER / DOCTOR
                                │
                                ▼
                    ┌─────────────────────┐
                    │    REACT WEBSITE    │
                    │ Login / Dashboard   │
                    │ Patients / Upload   │
                    │ Screening / Results │
                    │ Review / Reports    │
                    └──────────┬──────────┘
                               │ REST API
                               ▼
                    ┌─────────────────────┐
                    │       FASTAPI       │
                    │ Authentication      │
                    │ Patient APIs        │
                    │ Screening APIs      │
                    │ AI Integration      │
                    │ Report APIs         │
                    └───────┬───────┬─────┘
                            │       │
                            ▼       ▼
                  ┌────────────┐ ┌────────────┐
                  │ AI / MATLAB│ │  DATABASE  │
                  │ Quality    │ │ Users      │
                  │ Processing │ │ Patients   │
                  │ Deep Learn │ │ Screenings │
                  │ Grad-CAM   │ │ Reports    │
                  └─────┬──────┘ └────────────┘
                        │
                        ▼
                 ┌──────────────┐
                 │   SIMULINK   │
                 │ System Model │
                 └──────────────┘
```

---

# 📱 3. WEB APPLICATION STRUCTURE

```text
DR-Screening-AI
│
├── 🌐 frontend/
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
├── ⚡ backend/
│   ├── Authentication
│   ├── User Management
│   ├── Patient APIs
│   ├── Screening APIs
│   ├── AI Integration
│   ├── Database
│   └── Report Generation
│
├── 🧠 ai-matlab/
│   ├── dataset
│   ├── preprocessing
│   ├── models
│   ├── explainability
│   ├── evaluation
│   ├── scripts
│   └── tests
│
├── ⚙️ simulink/
│   └── screening_system.slx
│
├── 📚 docs/
│   ├── architecture
│   ├── flowcharts
│   ├── api
│   ├── dataset
│   └── reports
│
└── .gitignore
```

---

# 🔄 4. COMPLETE SCREENING FLOW

```text
Doctor Login
     ↓
Dashboard
     ↓
Select / Create Patient
     ↓
Start New Screening
     ↓
Upload Fundus Image
     ↓
Image Quality Check
     │
     ├── Poor → Upload Again
     │
     └── Good
          ↓
      Preprocessing
          ↓
      AI Analysis
          ↓
    DR Classification
          ↓
 ┌────────┼──────────┐
 ▼        ▼          ▼
Stage  Confidence   Risk
 └────────┼──────────┘
          ↓
       Grad-CAM
          ↓
  Explainable Result
          ↓
    Store Screening
          ↓
    Doctor Review
          ↓
   Confirm / Modify
          ↓
    Final Result
          ↓
   Generate Report
          ↓
 Screening History
```

---

# 📷 5. IMAGE QUALITY CHECK

The system should check:

- Blur/sharpness
- Brightness
- Contrast
- Exposure
- Retina visibility
- Field of view
- Image artifacts

```text
Fundus Image
     ↓
Quality Analysis
     ↓
 ┌───┴────────┐
 ▼            ▼
Good         Poor
 │            │
 ▼            ▼
Continue    Re-upload
```

---

# 🔬 6. AI / MATLAB WORKFLOW

```text
Retinal Image
     ↓
Image Quality Check
     ↓
Preprocessing
     ↓
Resize / Crop / Enhancement
     ↓
Normalization
     ↓
Deep Learning Model
     ↓
DR Classification
     ↓
Prediction + Confidence
     ↓
Risk Assessment
     ↓
Grad-CAM
     ↓
Explainable Result
     ↓
Model Evaluation
```

Candidate deep-learning architectures can include **ResNet, EfficientNet, DenseNet, or another suitable pretrained CNN**. The final model should be selected using independent validation/test performance, generalization, inference time, model size, and explainability.

---

# 👁️ 7. DR CLASSIFICATION

When supported by the selected dataset, the system can use five classes:

```text
No DR
Mild DR
Moderate DR
Severe DR
Proliferative DR
```

Example output format:

```text
Prediction : Moderate DR
Confidence : 94.2%
Risk Level : Medium
```

The above values are examples only; actual values must come from the trained model.

---

# 🔥 8. EXPLAINABLE AI / GRAD-CAM

```text
Fundus Image
     ↓
AI Model
     ↓
Prediction
     ↓
Grad-CAM
     ↓
Activation Map
     ↓
Heatmap Overlay
```

The heatmap explains model behavior and should not be presented as definitive clinical lesion localization.

---

# 📊 9. MODEL EVALUATION

Evaluate the final model on an independent test set using:

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
     ↓
AI Model
     ↓
Predictions
     ↓
Metrics
     ↓
Performance Report
```

No performance values should be fabricated; final numbers must come from experiments.

---

# ⚡ 10. BACKEND WORKFLOW

```text
React
  ↓ HTTP Request
FastAPI
  ↓
Validation
  ↓
AI Service ───── Database
  ↓                 ↑
Prediction ─────────┘
  ↓
API Response
  ↓
React Result Page
```

### Main API structure

```text
/api
├── /auth
│   ├── POST /login
│   └── POST /logout
├── /patients
│   ├── POST /
│   ├── GET /
│   ├── GET /{id}
│   ├── PUT /{id}
│   └── DELETE /{id}
├── /screening
│   ├── POST /analyze
│   ├── GET /{id}
│   └── GET /patient/{id}
└── /reports
    ├── GET /{id}
    └── POST /generate
```

---

# 🗄️ 11. DATABASE STRUCTURE

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

---

# 👨‍⚕️ 12. DOCTOR REVIEW

```text
AI Prediction
     ↓
Doctor Review
     ↓
 ┌───┴────┐
 ▼        ▼
Confirm  Modify
 └───┬────┘
     ↓
Doctor Notes
     ↓
Final Result
     ↓
Generate Report
```

The application must clearly distinguish the **AI prediction** from the **doctor's final assessment**.

---

# 👥 13. THREE-MEMBER TEAM

The project uses a flexible responsibility model. Primary ownership means coordination, not restriction. Every member can switch modules when required.

## 👨‍💻 MEMBER A — THARUN BALAJI

### Primary: AI / Data / MATLAB / Simulink

- Dataset management and documentation
- Data cleaning and organization
- Image quality assessment
- Image preprocessing
- Deep-learning model development
- Model training and validation
- Model evaluation
- Grad-CAM / Explainable AI
- MATLAB implementation
- Simulink implementation
- AI inference pipeline

**Backup:** FastAPI integration, API input/output, database understanding, basic frontend integration.

## 👨‍💻 MEMBER B — THARUN

### Primary: Backend / Database / AI Integration

- FastAPI setup
- Authentication and authorization
- Patient APIs
- Screening APIs
- Database design/integration
- AI model integration
- Image/file handling
- Result storage
- Report generation
- Backend testing

**Backup:** React/API integration, frontend debugging, AI pipeline understanding, MATLAB input/output understanding.

## 👨‍💻 MEMBER C — NARENDRAN G

### Primary: Frontend / UI / UX

- React application
- UI/UX design
- Landing page
- Login
- Dashboard
- Patient management
- Image upload
- Screening interface
- Result page
- Grad-CAM visualization
- Doctor review UI
- Reports UI
- Charts/data visualization
- Responsive design
- Frontend testing

**Backup:** AI/ML workflow, dataset structure, basic MATLAB workflow, backend API integration.

---

# ⚖️ 14. EQUAL CONTRIBUTION & WORK SWITCHING

All members contribute to:

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

Work can be transferred at any time:

```text
Current Member
      ↓
Commit Changes
      ↓
Push to GitHub
      ↓
Document Current Status
      ↓
Another Member Pulls Latest Code
      ↓
Continues the Work
```

Every major module must have enough documentation for another member to continue it.

---

# 🔗 15. AI → BACKEND → FRONTEND INTEGRATION

The AI module should return a documented structure such as:

```json
{
  "prediction": "Moderate DR",
  "confidence": 0.942,
  "risk_level": "Medium",
  "heatmap_reference": "heatmap/SCR001.png"
}
```

Integration flow:

```text
THARUN BALAJI
AI / MATLAB / Simulink
        ↓
   AI Output Contract
        ↓
THARUN
FastAPI / Database
        ↓
    REST API
        ↓
NARENDRA N
React / UI
        ↓
Doctor Screening Result
```

---

# 🧩 16. GITHUB REPOSITORY STRUCTURE

```text
DR-Screening-AI/
│
├── frontend/
├── backend/
├── ai-matlab/
├── simulink/
├── sample-data/
├── docs/
├── .gitignore
└── README.md
```

### Suggested branches

```text
main
  │
develop
  ├── feature/ai
  ├── feature/backend
  ├── feature/frontend
  ├── feature/preprocessing
  ├── feature/gradcam
  ├── feature/screening-api
  ├── feature/database
  └── feature/dashboard
```

### Development workflow

```text
Create Feature
      ↓
Create Branch
      ↓
Develop
      ↓
Test
      ↓
Commit
      ↓
Push
      ↓
Pull Request
      ↓
Code Review
      ↓
Merge → develop
      ↓
Integration Testing
      ↓
Merge → main
```

---

# 📦 17. DATASET MANAGEMENT

The complete retinal dataset should normally stay outside GitHub unless its license permits redistribution.

```text
ai-matlab/
└── dataset/          ← local only / ignored by Git
    ├── train/
    ├── validation/
    └── test/
```

GitHub should contain:

- Dataset source
- Download instructions
- Folder structure
- Class definitions
- Train/validation/test split information
- Preprocessing requirements

Only permitted small sample data should be committed.

---

# 🔐 18. SECURITY

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

Use `.env` locally and provide `.env.example` for required variables.

---

# 🧪 19. TESTING STRATEGY

### AI

```text
Image → Preprocessing → Model → Prediction → Grad-CAM
```

### Backend

```text
API Request → Validation → AI Service → Database → Response
```

### Frontend

```text
Upload → API Call → Loading → Result → Visualization
```

### Full System

```text
Login → Patient → Upload → AI → Prediction → Heatmap
→ Database → Doctor Review → Report
```

---

# 📅 20. DEVELOPMENT PHASES

### Phase 1 — Setup

```text
GitHub → Repository → Folder Structure → Development Environment
```

### Phase 2 — Parallel Development

```text
AI/ML       Backend       Frontend
Dataset     API           UI
Model       DB            Dashboard
MATLAB      Auth          Screening
```

### Phase 3 — Integration

```text
Frontend ↔ FastAPI ↔ AI Model ↔ Database
```

### Phase 4 — Advanced Features

```text
Grad-CAM • Image Quality • Risk Assessment • Doctor Review • Reports • Simulink
```

### Phase 5 — Testing

```text
Unit → Integration → System → Performance → Final Demo
```

---

# 🚀 21. FINAL END RESULT

```text
              👨‍⚕️ DOCTOR
                  ↓
                LOGIN
                  ↓
              DASHBOARD
                  ↓
            PATIENT PROFILE
                  ↓
            NEW SCREENING
                  ↓
          UPLOAD FUNDUS IMAGE
                  ↓
          IMAGE QUALITY CHECK
                  ↓
             AI PROCESSING
                  ↓
        ┌─────────────────────┐
        │      AI RESULT      │
        │ DR Stage            │
        │ Confidence          │
        │ Risk Level          │
        │ Original Image      │
        │ Grad-CAM Heatmap    │
        └──────────┬──────────┘
                   ↓
             DOCTOR REVIEW
                   ↓
             FINAL RESULT
                   ↓
            GENERATE REPORT
                   ↓
          SCREENING HISTORY
```

---

# 🏆 22. FINAL PROJECT OUTPUT

The completed platform combines:

```text
🌐 React Web Application
🧠 AI Diabetic Retinopathy Detection
🔬 MATLAB Image Processing
⚙️ Simulink System Simulation
🔥 Explainable AI / Grad-CAM
⚡ FastAPI Backend
🗄️ Database
👨‍⚕️ Doctor Review
📄 Screening Report
```

---

# 👥 23. TEAM CONTRIBUTION SUMMARY

| Work Area | Tharun Balaji | Tharun | Narendra N |
|---|---|---|---|
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

**Important:** Primary responsibility means coordination. Any member can contribute to or take over another module.

---

# 🎯 24. PROJECT SUCCESS CRITERIA

```text
✅ Login works
        ↓
✅ Patient can be created/selected
        ↓
✅ Fundus image can be uploaded
        ↓
✅ Image quality is checked
        ↓
✅ AI processes the image
        ↓
✅ DR stage is predicted
        ↓
✅ Confidence is generated
        ↓
✅ Explainability visualization is generated
        ↓
✅ Result is stored
        ↓
✅ Doctor can review the result
        ↓
✅ Report can be generated
        ↓
✅ Screening history is available
```

---

# 📜 DISCLAIMER

This project is developed for educational, research, and prototype purposes. The AI output supports a screening workflow and should not be treated as a standalone medical diagnosis. Clinical decisions must be made by qualified healthcare professionals using appropriate clinical evaluation.
