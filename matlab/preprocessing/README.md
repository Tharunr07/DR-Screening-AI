# matlab/preprocessing/ — Phase 2+ Enhancement (deferred to quality module)

**Status: CONSOLIDATED into `matlab/quality/`**

Enhancement operations (CLAHE, illumination normalization, denoising) for BORDERLINE images are implemented in `matlab/quality/enhanceBorderlineImage.m` rather than a separate preprocessing module. This avoids duplication and keeps the enhancement tightly coupled to quality assessment.

Future preprocessing modules (e.g., vessel normalization, color standardization for DR classification) will be added here when needed for Phase 3+.
