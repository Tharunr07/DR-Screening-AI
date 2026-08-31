# 🩺 DR-Screening-AI

## AI-Powered Diabetic Retinopathy Screening Platform

DR-Screening-AI is an AI-assisted diabetic retinopathy screening platform for retinal fundus image quality assessment, preprocessing, deep-learning classification, explainable AI, doctor review, and screening reports.

**Technology:** MATLAB • Simulink • Deep Learning • Computer Vision • Explainable AI • FastAPI • React • Database

> ⚠️ Educational/research prototype only. AI output is not a standalone medical diagnosis.

## 🎯 Project Objective

The system will accept a retinal fundus image, validate image quality, preprocess it, run an AI model, predict diabetic retinopathy severity, provide confidence and screening risk, generate Grad-CAM/explainability output, store the result, allow doctor review, and generate a report.

## 🏗️ System Architecture

```text
Doctor/User
    ↓
React Web Application
    ↓ REST API
FastAPI Backend
    ├── Authentication
    ├── Patient APIs
    ├── Screening APIs
    ├── AI Integration
    └── Report APIs
    ↓                 ↓
AI / MATLAB       Database
    ↓
Simulink
```

## 🌐 Web Application Structure

```text
frontend/
├── Landing Page
├── Login
├── Dashboard
├── Patient Management
├── New Screening
├── Image Upload
├── Screening Result
├── Explainable AI
├── Doctor Review
├── Screening History
└── Reports
```

## 🔄 Complete Screening Flow

```text
Doctor Login
    ↓
Dashboard
    ↓
Select/Create Patient
    ↓
Start Screening
    ↓
Upload Fundus Image
    ↓
Image Quality Check
    ├── Poor → Upload Again
    └── Good
         ↓
     Preprocessing
         ↓
     AI Analysis
         ↓
   DR Classification
         ↓
 Prediction + Confidence + Risk
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

## 📷 Image Quality Assessment

The image-quality module can evaluate blur/sharpness, brightness, contrast, exposure, retina visibility, field of view, and artifacts before AI inference.

```text
Fundus Image → Quality Analysis
                    ↓
              ┌─────┴─────┐
              ↓           ↓
            Good         Poor
              ↓           ↓
          Continue     Re-upload
```

## 🧠 AI / MATLAB Workflow

```text
Retinal Image
     ↓
Quality Check
     ↓
Preprocessing
     ↓
Resize / Crop / Enhancement / Normalization
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

Candidate models include ResNet, EfficientNet, DenseNet, or another suitable pretrained CNN. The final model must be selected using independent test performance, generalization, inference time, model size, and explainability.

## 👁️ DR Classification

When supported by the selected dataset, five classes can be used:

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

The values above are examples only; actual values must come from the trained model.

## 🔥 Explainable AI / Grad-CAM

```text
Fundus Image → AI Model → Prediction → Grad-CAM → Heatmap Overlay
```

The heatmap explains model behavior and must not be presented as definitive clinical lesion localization.

## 📊 Model Evaluation

Evaluate the final model on an independent test set using:

- Accuracy
- Precision
- Recall
- F1-Score
- Sensitivity
- Specificity
- ROC-AUC
- Confusion Matrix

No performance values should be fabricated; final numbers must come from experiments.

## ⚡ Backend API Structure

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

## 🗄️ Database Structure

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

## 👨‍⚕️ Doctor Review Workflow

```text
AI Prediction
     ↓
Doctor Review
     ↓
Confirm / Modify
     ↓
Doctor Notes
     ↓
Final Result
     ↓
Generate Report
```

The UI must distinguish the AI prediction from the doctor's final assessment.

# 👥 Three-Member Team

The project uses flexible responsibilities. Primary ownership means coordination, not restriction. Any member can switch modules when required.

## 👨‍💻 Member 1 — Tharun Balaji

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

**Backup:** FastAPI integration, API input/output, database understanding, and basic frontend integration.

## 👨‍💻 Member 2 — Tharun

### Primary: Backend / Database / AI Integration

- FastAPI setup
- Authentication and authorization
- Patient APIs
- Screening APIs
- Database design and integration
- AI model integration
- Image/file handling
- Result storage
- Report generation
- Backend testing

**Backup:** React/API integration, frontend debugging, AI pipeline understanding, and MATLAB input/output understanding.

## 👨‍💻 Member 3 — Narendran

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

**Backup:** AI/ML workflow, dataset structure, basic MATLAB workflow, and backend API integration.

## ⚖️ Equal Contribution & Work Switching

All members contribute to development, testing, documentation, integration, debugging, research, presentation, and demo.

```text
Current Member
      ↓
Commit Changes
      ↓
Push to GitHub
      ↓
Document Status
      ↓
Another Member Pulls Latest Code
      ↓
Continues Development
```

No critical module should be understood by only one member.

## 🔗 AI → Backend → Frontend Integration

The AI module should return a documented structure such as:

```json
{
  "prediction": "Moderate DR",
  "confidence": 0.942,
  "risk_level": "Medium",
  "heatmap_reference": "heatmap/SCR001.png"
}
```

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
NARENDRAN
React / UI
        ↓
Doctor Screening Result
```

## 🧩 GitHub Repository Structure

```text
DR-Screening-AI/
├── frontend/
├── backend/
├── ai-matlab/
├── simulink/
├── sample-data/
├── docs/
├── .gitignore
└── README.md
```

### Suggested Branches

```text
main
  ↓
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

### GitHub Development Workflow

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

## 📦 Dataset Management

The complete retinal dataset should normally stay outside GitHub unless its license permits redistribution.

```text
ai-matlab/
└── dataset/          ← local only / ignored by Git
    ├── train/
    ├── validation/
    └── test/
```

GitHub should contain the dataset source, download instructions, folder structure, class definitions, split information, and preprocessing requirements. Only permitted sample data should be committed.

## 🔐 Security

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

Use `.env` locally and `.env.example` for required variables.

## 🧪 Testing Strategy

```text
AI:
Image → Preprocessing → Model → Prediction → Grad-CAM

Backend:
API Request → Validation → AI Service → Database → Response

Frontend:
Upload → API Call → Loading → Result → Visualization

Full System:
Login → Patient → Upload → AI → Prediction → Heatmap
→ Database → Doctor Review → Report
```

## 📅 Development Phases

### Phase 1 — Setup
GitHub → Repository → Folder Structure → Development Environment

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

Grad-CAM • Image Quality • Risk Assessment • Doctor Review • Reports • Simulink

### Phase 5 — Testing

Unit → Integration → System → Performance → Final Demo

## 🚀 Final End Result

```text
Doctor
  ↓
Login
  ↓
Dashboard
  ↓
Patient Profile
  ↓
New Screening
  ↓
Upload Fundus Image
  ↓
Image Quality Check
  ↓
AI Processing
  ↓
DR Stage + Confidence + Risk + Grad-CAM
  ↓
Doctor Review
  ↓
Final Result
  ↓
Generate Report
  ↓
Screening History
```

## 🏆 Final Project Output

- 🌐 React Web Application
- 🧠 AI Diabetic Retinopathy Detection
- 🔬 MATLAB Image Processing
- ⚙️ Simulink System Simulation
- 🔥 Explainable AI / Grad-CAM
- ⚡ FastAPI Backend
- 🗄️ Database
- 👨‍⚕️ Doctor Review
- 📄 Screening Report

## 👥 Team Contribution Summary

| Work Area | Tharun Balaji | Tharun | Narendran |
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

**Primary responsibility means coordination only. Any member can contribute to or take over another module.**

## 🎯 Project Success Criteria

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

## 📜 Disclaimer

This project is developed for educational, research, and prototype purposes. The AI output supports a screening workflow and should not be treated as a standalone medical diagnosis. Clinical decisions must be made by qualified healthcare professionals using appropriate clinical evaluation.
