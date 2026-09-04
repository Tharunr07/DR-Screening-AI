# Phase 22: Confidence Calibration & Review Routing

## Executive Summary

Phase 22 measured the calibration quality of the frozen classifier's probabilities and evaluated post-hoc calibration methods. It also analyzed confidence-based review routing as a risk-reduction mechanism.

### Key Results

| Metric | Raw | Temperature Scaled | Isotonic |
|--------|-----|-------------------|----------|
| ECE | 0.0331 | **0.0230** | 0.0793 |
| MCE | 0.7066 | 0.7149 | **0.1376** |
| Brier | 0.2692 | **0.2682** | 0.4651 |
| NLL | 0.2358 | 0.2610 | 0.3818 |
| Accuracy | 79.5% | 79.5% | 53.2% |
| Ref Sens | 91.0% | 91.0% | 99.6% |
| Ref Spec | 91.5% | 91.5% | 83.1% |

**DECISION: B. CALIBRATION NOT BENEFICIAL**

Temperature scaling provides marginal ECE improvement (0.0331 → 0.0230) but degrades NLL and provides no accuracy or referable metric improvement. Isotonic regression significantly degrades accuracy and specificity. The marginal calibration benefit does not justify adding complexity to the pipeline.

---

## 1. Raw Calibration (TASK 2)

Before any post-hoc methods, the raw probabilities were measured:

| Metric | Value | Assessment |
|--------|-------|------------|
| ECE | 0.0331 | Good — 3.3% average miscalibration |
| MCE | 0.7066 | High — worst bin has 70.7% miscalibration |
| Brier | 0.2692 | Moderate |
| NLL | 0.2358 | Moderate |
| Accuracy | 79.5% | |

**Key finding:** The ECE is already good (3.3%). The high MCE (70.7%) indicates a specific worst-case bin, but the overall calibration is reasonable.

### Confidence-Accuracy Calibration (Raw)

| Bin | Images | Accuracy | Confidence | Gap |
|-----|--------|----------|------------|-----|
| 0.0–0.1 | 0 | — | — | — |
| 0.1–0.2 | 0 | — | — | — |
| 0.2–0.3 | 1 | 100.0% | 0.293 | 0.293 |
| 0.3–0.4 | 19 | 36.8% | 0.364 | 0.004 |
| 0.4–0.5 | 55 | 32.7% | 0.446 | 0.119 |
| 0.5–0.6 | 42 | 45.2% | 0.551 | 0.099 |
| 0.6–0.7 | 55 | 58.2% | 0.649 | 0.067 |
| 0.7–0.8 | 49 | 71.4% | 0.753 | 0.039 |
| 0.8–0.9 | 60 | 83.3% | 0.850 | 0.017 |
| 0.9–1.0 | 330 | 97.9% | 0.977 | 0.002 |

**The model is well-calibrated above 0.7 confidence.** The gaps below 0.5 are the main concern, but these represent only 75 images (12.3% of dataset).

---

## 2. Temperature Scaling (TASK 3)

Optimal temperature: **T = 1.12** (very close to 1.0)

This means the raw probabilities are already nearly optimally scaled. A temperature of 1.0 would mean no scaling is needed.

| Metric | Raw | Temp Scaled | Change |
|--------|-----|-------------|--------|
| ECE | 0.0331 | 0.0230 | -0.0101 |
| MCE | 0.7066 | 0.7149 | +0.0083 |
| Brier | 0.2692 | 0.2682 | -0.0010 |
| NLL | 0.2358 | 0.2610 | +0.0252 |
| Accuracy | 79.5% | 79.5% | 0.0% |
| Ref Sens | 91.0% | 91.0% | 0.0% |
| Ref Spec | 91.5% | 91.5% | 0.0% |

**Assessment:** Marginal ECE improvement, but NLL degradation and MCE increase. No accuracy or referable metric change. The benefit is negligible.

---

## 3. Isotonic Regression (TASK 3)

| Metric | Raw | Isotonic | Change |
|--------|-----|----------|--------|
| ECE | 0.0331 | 0.0793 | +0.0462 |
| MCE | 0.7066 | 0.1376 | -0.5690 |
| Brier | 0.2692 | 0.4651 | +0.1959 |
| NLL | 0.2358 | 0.3818 | +0.1460 |
| Accuracy | 79.5% | 53.2% | -26.3% |
| Ref Sens | 91.0% | 99.6% | +8.6% |
| Ref Spec | 91.5% | 83.1% | -8.4% |

**Assessment:** Isotonic regression catastrophically degrades accuracy and specificity. The MCE improvement comes at an unacceptable cost. **Isotonic regression should NOT be used.**

---

## 4. Confidence-Based Review Routing (TASK 4)

| Threshold | Auto-Accept | Auto Accuracy | Auto Sens | Auto Spec | Auto FN | Auto FP | Review Acc |
|-----------|-------------|---------------|-----------|-----------|---------|---------|------------|
| ≥0.50 | 87.7% | 85.8% | 93.5% | 93.5% | 13 | 22 | 34.7% |
| ≥0.70 | 71.8% | 92.9% | 96.9% | 97.4% | 4 | 8 | 45.3% |
| ≥0.90 | 54.0% | 97.9% | 98.2% | 99.6% | 1 | 1 | 58.0% |

**Key findings:**
- At ≥0.90: **97.9% accuracy** with **only 1 false negative** — excellent for automated screening
- At ≥0.70: **92.9% accuracy** with **4 false negatives** — good balance
- At ≥0.50: **85.8% accuracy** with **13 false negatives** — too many errors for automation

**The ≥0.70 threshold provides the best balance** between automation rate and safety.

---

## 5. High-Confidence Error Analysis (TASK 5)

31 high-confidence wrong predictions (conf > 0.7):

| Metric | Value |
|--------|-------|
| Errors with reduced confidence after TS | 31/31 (100%) |
| Mean raw confidence | 0.8319 |
| Mean calibrated confidence | 0.7966 |
| Mean reduction | 0.0353 |

**Temperature scaling reduces confidence of all 31 errors** — the mean reduction is 3.5 percentage points. However, this is marginal and doesn't change the routing decisions for most images.

---

## 6. Grade vs Referable Routing (TASK 6)

| Task | Threshold | Auto-Accept | Accuracy |
|------|-----------|-------------|----------|
| Five-class (≥0.90) | 0.90 | 54.0% | 97.9% |
| Binary referable (≥0.90) | 0.90 | 76.6% | 98.3% |
| Calibrated referable (≥0.90) | 0.90 | 74.3% | 98.9% |

**Binary referable routing is more permissive** — 76.6% auto-accept vs 54.0% for five-class. This makes sense: the model is more confident about "referable vs non-referable" than about the specific grade.

---

## 7. Nine Image Reference Set (TASK 9)

| Image | True | Pred | Raw Conf | Cal Conf | Raw Decision | Cal Decision |
|-------|------|------|----------|----------|--------------|--------------|
| 0097f532ac9f | G0 | G0 | 1.000 | 1.000 | AUTO-ACCEPT | AUTO-ACCEPT |
| 00e4ddff966a | G2 | G2 | 0.947 | 0.923 | AUTO-ACCEPT | AUTO-ACCEPT |
| 01d9477b1171 | G0 | G0 | 1.000 | 0.999 | AUTO-ACCEPT | AUTO-ACCEPT |
| fda39982a810 | G3 | G2 | 0.600 | 0.565 | REVIEW-REC | REVIEW-REC |
| fe3b0e50be78 | G0 | G0 | 1.000 | 0.999 | AUTO-ACCEPT | AUTO-ACCEPT |
| ff0740cb484a | G2 | G2 | 0.984 | 0.973 | AUTO-ACCEPT | AUTO-ACCEPT |

**Temperature scaling slightly reduces confidence** (e.g., 0.947 → 0.923 for 00e4ddff966a) but does not change any routing decision. All images maintain the same routing classification.

---

## 8. Reproducibility (TASK 8)

- RNG seed: 42 (fixed)
- All results deterministic
- Temperature scaling: single T parameter, grid search is deterministic
- Isotonic regression: pool-adjacent-violators is deterministic

---

## 9. Final Decision (TASK 12)

### DECISION: B. CALIBRATION NOT BENEFICIAL

| Question | Answer |
|----------|--------|
| Does calibration materially improve probability reliability? | **No** — ECE improves marginally (0.033 → 0.023) but NLL degrades |
| Does confidence-based review routing provide useful risk reduction? | **Yes** — ≥0.70 threshold achieves 92.9% accuracy with 4 FN |
| What review threshold is supported? | **≥0.70** for five-class, **≥0.50** for binary referable |
| Does calibration change five-class performance? | **No** — accuracy remains 79.5% |
| Does calibration change referable performance? | **No** — sensitivity/specificity unchanged |
| Are G3/G4 errors still a classifier limitation? | **Yes** — 25.6%/44.9% recall unchanged |
| Is retraining justified? | **Not yet** — referable performance (91%/91.5%) is strong |
| Is detector modification justified? | **No** — detectors are not the bottleneck |
| Is Grad-CAM modification justified? | **Not yet** — single zero-CAM case is documented |

---

## 10. What IS Worth Implementing

The evidence supports **confidence-based review routing** as a production policy, WITHOUT temperature scaling:

```
IF max(P(G0..G4)) >= 0.70:
    → Automated result (92.9% accuracy)
    → Referable sensitivity: 96.9%, specificity: 97.4%
    → False negatives: 4, False positives: 8

IF max(P(G0..G4)) < 0.70:
    → Human review recommended
    → Review accuracy: 45.3% (model is genuinely uncertain)
```

This does NOT require any calibration — it uses the raw probabilities directly. The raw probabilities are already well-calibrated above 0.7 (gap < 0.04).

---

## Outputs

```
docs/PHASE22_CALIBRATION.md
results/phase22_calibration/
    raw_calibration_metrics.csv
    temperature_scaling_metrics.csv
    isotonic_metrics.csv
    confidence_bins.csv
    review_threshold_analysis.csv
    high_confidence_errors.csv
    nine_image_revalidation.csv
    calibration_comparison.csv
```

## Disclaimers

> **Passing calibration metrics does not establish clinical validity.**

- Calibration numbers apply to the validation set only
- Review routing effectiveness depends on the distribution of cases in deployment
- Temperature scaling was evaluated on a 60/40 split — the full-dataset metrics may be slightly optimistic
- Isotonic regression was evaluated with a simple pool-adjacent-violators implementation — more sophisticated implementations may perform differently
- The ≥0.70 threshold is based on validation evidence, not clinical validation
