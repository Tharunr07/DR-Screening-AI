# Phase 20H System Freeze

## Git State

- **Commit:** `5035e26904372706a6257831d6b27baef93c8119`
- **Message:** Phase 21: Update presentation materials with honest Phase 17 numbers
- **Branch:** master

Note: The freeze commit is post-Phase 20G. All detector fixes, preprocessing correction, Grad-CAM replacement, and validation re-runs are included.

## SHA256 Hashes — Frozen Assets

### Model
```
59AFAFF30CEA618A05BC081A314191BDEEDF2C9B450B804D12A6F3D8E4EBA69C  results\transfer_learning\models\trainedNetTL.mat
```

### Preprocessing
```
03A273CCB461EA5ED47841BBFD59BDCF2029CB9D115724D954D321198CFB460C  matlab\shared\preprocessFundus.m
```

### Explainability
```
975CC55D7D7004B5B1EDA87CFD0F85474239B34732919B0C65B02014EEF757D4  matlab\explainability\gradcamSimple.m
```

### Detectors
```
99C3B4DEF8B9329473E1C8B7A42F55CA0066F176BFF1530C023464948AA11223  matlab\lesions\detectMicroaneurysms.m
DE950912A4B2E5E6BA9DC8A67943C4F12D1468A2FAAA02AE58F19CFA71ECD7AB  matlab\lesions\detectHemorrhages.m
1FECFB0838FE9AE58204706480BB92A084D733DC80FCACE08233647CD6A82857  matlab\lesions\detectExudates.m
1EE4F8C4751BD6F1E6FCB887B8A1298F0E478560175094A92BAD76F399FD8DDE  matlab\lesions\detectNeovascularization.m
FC8A13959C646413F52C32A8AD6C2776578795C638CBFDB16F03DB3E875E9FCD  matlab\lesions\extractLesionEvidence.m
17F8FA09B6CE7C73368C73D0DF12CBF994DCAFD15F436A3D71516961343CA22A  matlab\clinical\applyClinicalLogic.m
```

### Validation/Analysis Scripts
```
6C112D274BDF034338500D79F914C5DE01F270B79510C92EBDEC246F731DBC1C  matlab\validation\classifierForensicAudit.m
03E89FA8B3B1DB0FC6A3A749D5DC0419F6D28F22F0A8396CA28373ADB13EB3BB  matlab\validation\phase20fComparison.m
8BBA5936160C4CC9EE42AEF58F89ADB5D3A0924FB89C6103054CBE2D72CB112D  matlab\validation\phase20gForensic.m
31CA1F2185D3CF66B0BB029B58B765C56025B2892B46B2B0E0C014A84A832E5B  matlab\validation\updateClassifierPredictions.m
CBC1E8EA998DFC6143827586B328F9581B607F056AA9615A3705722AB5B06B3D  matlab\validation\mergeCorrectedPredictions.m
74393550755DBC7AE0917AB70FA09B0818E63D723139C985827F42063A588B69  matlab\validation\runPhase20C1.m
67DCDB1E299C26A381131479C3C8801D6C3E5B0D7AE97DED23D5AE3E3751B668  matlab\validation\runPhase20CSystemComparison.m
D4AFAFCDA5D748A5CE8DDB2AF6470542EAEA51AE02894F9178BA666138AD2E37  matlab\validation\generatePhase20B3Diagnostics.m
```

## What This Freeze Covers

| Component | Status | Hash Verified |
|-----------|--------|---------------|
| trainedNetTL.mat | Frozen since Phase 8 | ✅ |
| preprocessFundus.m | Created Phase 20E | ✅ |
| gradcamSimple.m | Created Phase 20E | ✅ |
| detectMicroaneurysms.m | Rewritten Phase 20B.1 | ✅ |
| detectHemorrhages.m | Rewritten Phase 20B.2 | ✅ |
| detectExudates.m | Rewritten Phase 20B.3 | ✅ |
| detectNeovascularization.m | Rewritten Phase 20B.4 | ✅ |
| extractLesionEvidence.m | Created Phase 20B.5 | ✅ |
| applyClinicalLogic.m | Untouched (Phase 8) | ✅ |
| test.csv / 612-image test set | Frozen since Phase 8 | Not modified |
| tl_predictions.csv | Frozen since Phase 8 | Not modified |

## Freeze Rules

1. No modifications to any file listed above after this freeze point
2. Any future phase that modifies these files must update this document with new hashes
3. The 612-image test set remains inaccessible until retraining is approved
4. The 9 Phase 20F/20G reference images serve as the canonical regression set
