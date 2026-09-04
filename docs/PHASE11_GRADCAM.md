# Phase 11: Formal Grad-CAM Explainability

**Status:** Complete
**Commit:** Pending

## Overview

Phase 11 implements formal Grad-CAM (Gradient-weighted Class Activation Mapping) for the frozen Phase 8 model, replacing the previous gradient-magnitude heatmap with a class-specific explainability method.

## Mathematical Formulation

### Grad-CAM Algorithm

Given:
- Feature maps `F` from final conv layer (`res5b_branch2b`): 7×7×512
- FC weights: `W1` (512×512), `W2` (128×512), `W3` (5×128)
- Target class `c`

Steps:
1. **Forward pass:** Extract feature maps `F` from `res5b_branch2b`
2. **Gradient computation:** `grad = W3(c,:) × W2 × W1` (1×512)
3. **Weighted combination:** `L_c = Σ_k(grad_k × F_k)`
4. **Min-max normalization:** `L_c ∈ [0, 1]`
5. **Resize:** Upsample to input image dimensions

### Key Differences from Gradient-Magnitude

| Aspect | Gradient-Magnitude | Grad-CAM |
|--------|-------------------|----------|
| Class specificity | None | Class-specific |
| Theoretical basis | Edge detection | Class-discriminative regions |
| FC layer usage | None | Full FC weight projection |
| Output range | [0, 1] | [0, 1] |
| Deterministic | Yes | Yes |

## Implementation

### Function: `gradcamSimple.m`

```matlab
[cam, predClass, scores] = gradcamSimple(net, img)
[cam, predClass, scores] = gradcamSimple(net, img, 'TargetClass', 3)
```

**Inputs:**
- `net` — Trained DAGNetwork (frozen Phase 8)
- `img` — Preprocessed image (224×224×3, ImageNet-normalized)

**Outputs:**
- `cam` — Class activation map (224×224, values in [0,1])
- `predClass` — Predicted class index
- `scores` — Class probabilities

### Target Layer

- **Layer:** `res5b_branch2b` (layer 64 in ResNet-18)
- **Output:** 7×7×512 feature maps
- **Rationale:** Final convolutional layer before global average pooling

### FC Weight Projection

```
W1: 512 × 512 (fc_dr_1)
W2: 128 × 512 (fc_dr_2)
W3: 5 × 128 (fc_dr_output)

grad = W3(c,:) × W2 × W1  →  1 × 512
```

## Validation Results

| # | Test | Status |
|---|------|--------|
| 1 | Function exists | PASS |
| 2 | Feature extraction | PASS |
| 3 | CAM generation | PASS |
| 4 | Normalization [0,1] | PASS |
| 5 | Size matching | PASS |
| 6 | Deterministic output | PASS |
| 7 | Class-specific CAMs | PASS |
| 8 | Overlay generation | PASS |
| 9 | Invalid input handling | PASS |

**Result: 9/9 PASS**

## GUI Integration

The "Show Heatmap" button in `drScreeningGUI.m` now displays formal Grad-CAM:

1. Preprocesses the current image
2. Calls `gradcamSimple()` with the frozen model
3. Overlays the class-specific activation map
4. Shows predicted grade and label in title

## Files

```
matlab/explainability/
├── gradcamSimple.m        # Formal Grad-CAM implementation
├── gradcam.m              # Alternative implementation (fallback)
└── validateGradCAM.m      # 9-test validation suite

matlab/demo/
└── drScreeningGUI.m       # Updated to use formal Grad-CAM

docs/
└── PHASE11_GRADCAM.md     # This file
```

## How to Run

```matlab
% Generate Grad-CAM for a specific image
cfgTL = transferLearningConfig();
load(fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL');
img = imread('path/to/image.jpg');
imgR = imresize(img, cfgTL.image.size, 'bicubic');
mn = [0.485 0.456 0.406]; sd = [0.229 0.224 0.225];
n = double(imgR)/255;
for c=1:3; n(:,:,c) = (n(:,:,c)-mn(c))/sd(c); end

[cam, predClass, scores] = gradcamSimple(trainedNetTL, n);

% Visualize
figure;
imshow(imgR); hold on;
h = imagesc(cam, [0, 1]);
set(h, 'AlphaData', 0.4);
colormap(jet); colorbar;
title(sprintf('Grad-CAM (Predicted: G%d)', predClass-1));

% Run validation
v = validateGradCAM('Verbose', true);

% Launch GUI with Grad-CAM
drScreeningGUI();
```

## Limitations

1. **Gradient approximation:** Uses FC weight projection instead of true backpropagation through ReLU layers
2. **Single layer:** Uses only `res5b_branch2b`; multi-layer Grad-CAM could provide finer granularity
3. **No lesion localization:** Grad-CAM highlights discriminative regions, not specific lesion types
4. **Not clinically validated:** Explainability is for research transparency, not diagnosis

## What Is NOT in Phase 11

- **No model retraining** — frozen at `cc7bed8`
- **No clinical claims** — research prototype only
- **No lesion detection** — Phase 12 addresses this

## SIH Traceability

| SIH Requirement | Evidence |
|-----------------|----------|
| Grad-CAM | Formal implementation with class-specific maps |
| Attention maps | 7×7→224×224 upsampled activation maps |
| Explainability | GUI integration, visual overlay |
| Deterministic | 9/9 validation tests pass |
