# Phase 1 — Validation Report

Generated: 2026-08-30 21:02:56

Project root: `C:\dev\SIH\DR_Screening`

Overall: **PASS** (10/10 checks passed, 100%)

| Check | Pass | Details |
|-------|------|--------|
| parse | PASS | 12 files checked |
| configurablePaths | PASS | configurable=1 |
| manifestGeneration | PASS | rows=7872 |
| unreadableHandling | PASS | corrupt file correctly reported; audit correctly counts missing/unreadable |
| countsConsistent | PASS | manifest=7872 audit=7872 sumByDataset=7872 |
| annotationMapping | PASS | IDRiD rows=1395 DRIVE rows=40 (mapping verified where data present) |
| splitReproducible | PASS | two runs produced identical split assignments |
| noLeakage | PASS | checked 3662 patients — no leakage |
| rawNotModified | PASS | raw mtimes unchanged |
| resultsGenerated | PASS | audit generated, total=7872 |

> Validation infrastructure executed successfully. If datasets are NOT PRESENT, counts will be zero but infrastructure is validated.
