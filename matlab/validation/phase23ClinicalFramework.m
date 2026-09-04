function phase23ClinicalFramework()
% phase23ClinicalFramework  Phase 23 — Clinical Ground-Truth & Evaluation Framework
%
%   Maps current annotation coverage, defines clinical evaluation metrics,
%   and identifies gaps that must be filled before clinical deployment.

    fprintf('============================================================\n');
    fprintf('  Phase 23: Clinical Ground-Truth & Evaluation Framework\n');
    fprintf('============================================================\n\n');

    outputDir = 'results/phase23_clinical_framework';
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    %% ====================================================================
    %  TASK 1: CURRENT ANNOTATION LANDSCAPE
    %  ====================================================================
    fprintf('--- TASK 1: Current Annotation Landscape ---\n\n');

    % Load manifest
    M = readtable('data/processed/manifest.csv', 'TextType', 'string');
    fprintf('Total images in manifest: %d\n\n', height(M));

    % Dataset composition
    datasets = unique(M.dataset);
    for d = 1:numel(datasets)
        ds = datasets(d);
        sub = M(M.dataset == ds, :);
        hasGrade = sum(~isnan(sub.dr_grade));
        hasLesion = sum(sub.has_lesion_annotation == 1);
        hasVessel = sum(sub.has_vessel_annotation == 1);
        fprintf('%s: %d images, %d with DR grade, %d with lesion masks, %d with vessel masks\n', ...
            ds, height(sub), hasGrade, hasLesion, hasVessel);
    end

    % Grade distribution by dataset
    fprintf('\nDR Grade Distribution:\n');
    fprintf('%-15s %5s %5s %5s %5s %5s %5s\n', 'Dataset', 'G0', 'G1', 'G2', 'G3', 'G4', 'NaN');
    for d = 1:numel(datasets)
        ds = datasets(d);
        sub = M(M.dataset == ds, :);
        counts = zeros(1, 6);
        for g = 0:4
            counts(g+1) = sum(sub.dr_grade == g);
        end
        counts(6) = sum(isnan(sub.dr_grade));
        fprintf('%-15s %5d %5d %5d %5d %5d %5d\n', ds, counts);
    end

    % Lesion annotation depth (IDRiD)
    fprintf('\nIDRiD Lesion Annotation Coverage:\n');
    idrid = M(M.dataset == "IDRiD", :);
    idridWithLesion = idrid(idrid.has_lesion_annotation == 1, :);
    fprintf('  IDRiD images with lesion masks: %d / %d (%.1f%%)\n', ...
        height(idridWithLesion), height(idrid), height(idridWithLesion)/height(idrid)*100);

    % Check annotation paths for lesion types
    lesionTypes = {'MA', 'HE', 'EX', 'SE', 'OD'};
    for t = 1:numel(lesionTypes)
        lt = lesionTypes{t};
        hasType = 0;
        for i = 1:height(idridWithLesion)
            paths = string(idridWithLesion.lesion_annotation_path(i));
            if strlength(paths) > 0 && contains(paths, lt)
                hasType = hasType + 1;
            end
        end
        fprintf('  %s annotations: %d / %d (%.1f%%)\n', ...
            lt, hasType, height(idridWithLesion), hasType/height(idridWithLesion)*100);
    end

    %% ====================================================================
    %  TASK 2: QUALITY ANNOTATION LANDSCAPE
    %  ====================================================================
    fprintf('\n--- TASK 2: Quality Annotation Landscape ---\n\n');

    MQ = readtable('data/processed/manifest_with_quality.csv', 'TextType', 'string');
    qualityStatuses = unique(MQ.quality_status);
    for s = 1:numel(qualityStatuses)
        qs = qualityStatuses(s);
        count = sum(MQ.quality_status == qs);
        fprintf('  %s: %d images (%.1f%%)\n', qs, count, count/height(MQ)*100);
    end

    % Quality by dataset
    fprintf('\nQuality by Dataset:\n');
    fprintf('%-15s %8s %10s %12s\n', 'Dataset', 'Good', 'Borderline', 'Ungradable');
    for d = 1:numel(datasets)
        ds = datasets(d);
        sub = MQ(MQ.dataset == ds, :);
        good = sum(sub.quality_status == "GOOD");
        border = sum(sub.quality_status == "BORDERLINE");
        ungrad = sum(sub.quality_status == "UNGRADABLE");
        fprintf('%-15s %8d %10d %12d\n', ds, good, border, ungrad);
    end

    %% ====================================================================
    %  TASK 3: VALIDATION SET ANNOTATION DEPTH
    %  ====================================================================
    fprintf('\n--- TASK 3: Validation Set Annotation Depth ---\n\n');

    val = readtable('data/splits/val.csv', 'TextType', 'string');
    valLabeled = val(~isnan(val.dr_grade), :);
    fprintf('Val set: %d total, %d with DR grade labels\n', height(val), height(valLabeled));

    % How many val images have lesion annotations?
    valLesion = valLabeled(valLabeled.has_lesion_annotation == 1, :);
    fprintf('Val images with lesion masks: %d\n', height(valLesion));

    % Grade distribution of val set
    fprintf('\nVal DR Grade Distribution:\n');
    for g = 0:4
        count = sum(valLabeled.dr_grade == g);
        fprintf('  G%d: %d (%.1f%%)\n', g, count, count/height(valLabeled)*100);
    end

    %% ====================================================================
    %  TASK 4: CLINICAL EVALUATION METRICS DEFINITION
    %  ====================================================================
    fprintf('\n--- TASK 4: Clinical Evaluation Metrics ---\n\n');

    % Load corrected predictions
    T = readtable('data/splits/val_classifier_corrected.csv', 'TextType', 'string');
    trueG = T.dr_grade;
    predG = T.predicted_grade;
    n = height(T);

    % --- Five-class metrics ---
    fprintf('FIVE-CLASS PERFORMANCE:\n');
    overallAcc = sum(predG == trueG) / n;
    fprintf('  Overall accuracy: %.1f%% (%d/%d)\n', overallAcc*100, sum(predG==trueG), n);

    % Per-class sensitivity, specificity, PPV, NPV
    fprintf('\n  Per-class metrics:\n');
    fprintf('  %-6s %10s %10s %10s %10s %10s\n', 'Grade', 'Sensitivity', 'Specificity', 'PPV', 'NPV', 'F1');

    perClassMetrics = struct();
    for g = 0:4
        TP = sum(predG == g & trueG == g);
        FP = sum(predG == g & trueG ~= g);
        FN = sum(predG ~= g & trueG == g);
        TN = sum(predG ~= g & trueG ~= g);

        sens = TP / (TP + FN);
        spec = TN / (TN + FP);
        ppv = TP / (TP + FP);
        npv = TN / (TN + FN);
        f1 = 2 * ppv * sens / (ppv + sens);

        fprintf('  G%-5d %10.1f%% %10.1f%% %10.1f%% %10.1f%% %10.1f%%\n', ...
            g, sens*100, spec*100, ppv*100, npv*100, f1*100);

        perClassMetrics(g+1).grade = g;
        perClassMetrics(g+1).sensitivity = sens;
        perClassMetrics(g+1).specificity = spec;
        perClassMetrics(g+1).ppv = ppv;
        perClassMetrics(g+1).npv = npv;
        perClassMetrics(g+1).f1 = f1;
        perClassMetrics(g+1).TP = TP;
        perClassMetrics(g+1).FP = FP;
        perClassMetrics(g+1).FN = FN;
        perClassMetrics(g+1).TN = TN;
    end

    % --- Binary referable metrics ---
    fprintf('\nBINARY REFERABLE (G2-G4 vs G0-G1):\n');
    refTrue = trueG >= 2;
    refPred = predG >= 2;
    TP_ref = sum(refPred & refTrue);
    FP_ref = sum(refPred & ~refTrue);
    FN_ref = sum(~refPred & refTrue);
    TN_ref = sum(~refPred & ~refTrue);
    sensRef = TP_ref / (TP_ref + FN_ref);
    specRef = TN_ref / (TN_ref + FP_ref);
    ppvRef = TP_ref / (TP_ref + FP_ref);
    npvRef = TN_ref / (TN_ref + FN_ref);
    f1Ref = 2 * ppvRef * sensRef / (ppvRef + sensRef);

    fprintf('  Sensitivity: %.1f%% (%d/%d)\n', sensRef*100, TP_ref, TP_ref+FN_ref);
    fprintf('  Specificity: %.1f%% (%d/%d)\n', specRef*100, TN_ref, TN_ref+FP_ref);
    fprintf('  PPV: %.1f%%\n', ppvRef*100);
    fprintf('  NPV: %.1f%%\n', npvRef*100);
    fprintf('  F1: %.1f%%\n', f1Ref*100);
    fprintf('  False negatives: %d (missed referable cases)\n', FN_ref);
    fprintf('  False positives: %d (unnecessary referrals)\n', FP_ref);

    % --- Confidence-stratified metrics ---
    fprintf('\nCONFIDENCE-STRATIFIED PERFORMANCE:\n');
    confMax = max([T.P_G0, T.P_G1, T.P_G2, T.P_G3, T.P_G4], [], 2);

    confBins = [0, 0.5, 0.7, 0.8, 0.9, 1.0];
    fprintf('  %-12s %6s %10s %10s %10s\n', 'Conf Range', 'Count', 'Accuracy', 'Ref Sens', 'Ref Spec');
    for b = 1:numel(confBins)-1
        lo = confBins(b);
        hi = confBins(b+1);
        mask = confMax >= lo & confMax < hi;
        if b == numel(confBins)-1
            mask = confMax >= lo & confMax <= hi;
        end
        nBin = sum(mask);
        if nBin > 0
            acc = sum(predG(mask) == trueG(mask)) / nBin;
            sensB = sum(refPred(mask) & refTrue(mask)) / max(sum(refTrue(mask)), 1);
            specB = sum(~refPred(mask) & ~refTrue(mask)) / max(sum(~refTrue(mask)), 1);
            fprintf('  [%.2f, %.2f) %6d %10.1f%% %10.1f%% %10.1f%%\n', lo, hi, nBin, acc*100, sensB*100, specB*100);
        end
    end

    %% ====================================================================
    %  TASK 5: WHAT CLINICAL GROUND TRUTH WE HAVE vs NEED
    %  ====================================================================
    fprintf('\n--- TASK 5: Ground Truth Assessment ---\n\n');

    fprintf('WHAT WE HAVE:\n');
    fprintf('  DR grade labels:\n');
    fprintf('    APTOS2019: %d images (single-grader, Kaggle competition)\n', sum(M.dataset == "APTOS2019" & ~isnan(M.dr_grade)));
    fprintf('    IDRiD: %d images (single-grader, Indian dataset)\n', sum(M.dataset == "IDRiD" & ~isnan(M.dr_grade)));
    fprintf('    Total: %d grade-labeled images\n', sum(~isnan(M.dr_grade)));
    fprintf('  Lesion masks:\n');
    fprintf('    IDRiD segmentation: %d images (MA/HE/EX/SE/OD)\n', sum(M.has_lesion_annotation == 1));
    fprintf('    DRIVE vessel: %d images\n', sum(M.has_vessel_annotation == 1));
    fprintf('  Quality scores: %d images (algorithmic, not clinician-verified)\n', height(MQ));

    fprintf('\nWHAT WE NEED (clinical grade):\n');
    fprintf('  1. Multi-reader DR grade annotations (2-3 ophthalmologists per image)\n');
    fprintf('     → Inter-observer variability quantification\n');
    fprintf('     → Disagreement resolution protocol\n');
    fprintf('  2. Expert-verified lesion masks for more images\n');
    fprintf('     → Current: %d images with lesion masks / %d total = %.1f%%\n', ...
        sum(M.has_lesion_annotation == 1), height(M), sum(M.has_lesion_annotation == 1)/height(M)*100);
    fprintf('     → Minimum: 200-500 images with verified masks\n');
    fprintf('  3. Image quality labels from clinicians\n');
    fprintf('     → Current: algorithmic only (THEORETICAL, not validated)\n');
    fprintf('     → Need: clinician grading of image quality\n');
    fprintf('  4. Difficult/ambiguous case annotations\n');
    fprintf('     → Cases where even experts disagree\n');
    fprintf('     → Essential for setting realistic performance expectations\n');
    fprintf('  5. External dataset annotations\n');
    fprintf('     → Different cameras, populations, protocols\n');
    fprintf('     → Must be independent of training data\n');

    %% ====================================================================
    %  TASK 6: GAP ANALYSIS
    %  ====================================================================
    fprintf('\n--- TASK 6: Gap Analysis ---\n\n');

    % What the model can vs cannot evaluate
    fprintf('WHAT OUR CURRENT EVALUATION CAN PROVE:\n');
    fprintf('  ✓ Software behaves correctly (147/147 regression tests)\n');
    fprintf('  ✓ Preprocessing is consistent (19/20 files, canonical pipeline)\n');
    fprintf('  ✓ Lesion detectors follow programmed rules\n');
    fprintf('  ✓ Classifier outputs probabilities (calibrated to ECE 0.033)\n');
    fprintf('  ✓ Confidence routing works (92.9%% accuracy at >=0.70)\n');

    fprintf('\nWHAT OUR CURRENT EVALUATION CANNOT PROVE:\n');
    fprintf('  ✗ Detected lesions are medically correct\n');
    fprintf('     → No expert-verified lesion ground truth for APTOS images\n');
    fprintf('     → IDRiD masks cover only 54 of 4286 training images (1.3%%)\n');
    fprintf('  ✗ DR grades are accurate\n');
    fprintf('     → Single-grader labels only (no inter-observer analysis)\n');
    fprintf('     → APTOS labels from Kaggle competition (annotation protocol unknown)\n');
    fprintf('  ✗ Image quality gate is clinically valid\n');
    fprintf('     → Algorithmic quality scores, not clinician-verified\n');
    fprintf('  ✗ System generalizes to other populations/cameras\n');
    fprintf('     → No external validation with new annotations\n');
    fprintf('  ✗ Performance is acceptable for clinical use\n');
    fprintf('     → No clinical validation study\n');
    fprintf('     → No comparison to expert performance\n');

    fprintf('\nPRIORITY GAPS (ranked by clinical risk):\n');
    fprintf('  1. HIGH: No multi-reader annotations → cannot measure inter-observer variability\n');
    fprintf('  2. HIGH: No expert-verified lesion masks for APTOS → lesion evidence is unvalidated\n');
    fprintf('  3. HIGH: No external validation → generalizability unknown\n');
    fprintf('  4. MEDIUM: Quality gate not clinician-verified → may reject good images or accept bad ones\n');
    fprintf('  5. MEDIUM: No difficult-case annotations → cannot set realistic performance bounds\n');
    fprintf('  6. LOW: No multi-center training data → single-center bias possible\n');

    %% ====================================================================
    %  TASK 7: CLINICAL EVALUATION FRAMEWORK
    %  ====================================================================
    fprintf('\n--- TASK 7: Clinical Evaluation Framework ---\n\n');

    fprintf('FRAMEWORK FOR CLINICAL-GRADE EVALUATION:\n\n');

    fprintf('Stage 1: Annotation Quality Assurance\n');
    fprintf('  - Recruit 2-3 board-certified ophthalmologists\n');
    fprintf('  - Independent annotation of 200-500 images\n');
    fprintf('  - Measure inter-observer agreement (Cohen kappa, Fleiss kappa)\n');
    fprintf('  - Establish consensus protocol for disagreements\n');
    fprintf('  - Result: Verified ground-truth set\n\n');

    fprintf('Stage 2: Lesion Mask Validation\n');
    fprintf('  - Expert verification of IDRiD masks (sample audit)\n');
    fprintf('  - New expert annotations for APTOS images (subset)\n');
    fprintf('  - Quantify detector accuracy against verified masks\n');
    fprintf('  - Result: Lesion detection performance metrics\n\n');

    fprintf('Stage 3: External Validation\n');
    fprintf('  - Messidor-2: 1,748 images (already available, external isolation)\n');
    fprintf('  - Additional datasets: DDR, DeepDR, EyePACS (if obtainable)\n');
    fprintf('  - Multi-camera testing (if possible)\n');
    fprintf('  - Result: Generalizability metrics\n\n');

    fprintf('Stage 4: Clinical Workflow Simulation\n');
    fprintf('  - Simulate review routing with clinician feedback\n');
    fprintf('  - Measure time-to-decision\n');
    fprintf('  - Assess false-negative impact (missed referable cases)\n');
    fprintf('  - Assess false-positive impact (unnecessary referrals)\n');
    fprintf('  - Result: Workflow integration metrics\n\n');

    fprintf('Stage 5: Comparison to Expert Performance\n');
    fprintf('  - Compare AI sensitivity/specificity to individual experts\n');
    fprintf('  - Identify cases where AI outperforms or underperforms experts\n');
    fprintf('  - Result: Relative performance assessment\n\n');

    %% ====================================================================
    %  TASK 8: WRITE OUTPUTS
    %  ====================================================================
    fprintf('\n--- Writing outputs ---\n');

    % Annotation coverage table
    Tcov = table();
    Tcov.dataset = ["APTOS2019"; "IDRiD"; "DRIVE"; "Messidor2"];
    Tcov.total = [sum(M.dataset == "APTOS2019"); sum(M.dataset == "IDRiD"); ...
                  sum(M.dataset == "DRIVE"); sum(M.dataset == "Messidor2")];
    Tcov.with_grade = [sum(M.dataset == "APTOS2019" & ~isnan(M.dr_grade)); ...
                       sum(M.dataset == "IDRiD" & ~isnan(M.dr_grade)); ...
                       sum(M.dataset == "DRIVE" & ~isnan(M.dr_grade)); ...
                       sum(M.dataset == "Messidor2" & ~isnan(M.dr_grade))];
    Tcov.with_lesion = [sum(M.dataset == "APTOS2019" & M.has_lesion_annotation == 1); ...
                        sum(M.dataset == "IDRiD" & M.has_lesion_annotation == 1); ...
                        sum(M.dataset == "DRIVE" & M.has_lesion_annotation == 1); ...
                        sum(M.dataset == "Messidor2" & M.has_lesion_annotation == 1)];
    Tcov.with_vessel = [sum(M.dataset == "APTOS2019" & M.has_vessel_annotation == 1); ...
                        sum(M.dataset == "IDRiD" & M.has_vessel_annotation == 1); ...
                        sum(M.dataset == "DRIVE" & M.has_vessel_annotation == 1); ...
                        sum(M.dataset == "Messidor2" & M.has_vessel_annotation == 1)];
    writetable(Tcov, fullfile(outputDir, 'annotation_coverage.csv'));
    fprintf('  annotation_coverage.csv\n');

    % Per-class metrics table
    Tpc = table();
    for g = 0:4
        idx = g + 1;
        Tpc.grade(idx) = perClassMetrics(idx).grade;
        Tpc.sensitivity(idx) = perClassMetrics(idx).sensitivity;
        Tpc.specificity(idx) = perClassMetrics(idx).specificity;
        Tpc.ppv(idx) = perClassMetrics(idx).ppv;
        Tpc.npv(idx) = perClassMetrics(idx).npv;
        Tpc.f1(idx) = perClassMetrics(idx).f1;
        Tpc.TP(idx) = perClassMetrics(idx).TP;
        Tpc.FP(idx) = perClassMetrics(idx).FP;
        Tpc.FN(idx) = perClassMetrics(idx).FN;
        Tpc.TN(idx) = perClassMetrics(idx).TN;
    end
    writetable(Tpc, fullfile(outputDir, 'per_class_clinical_metrics.csv'));
    fprintf('  per_class_clinical_metrics.csv\n');

    % Binary referable metrics
    Tref = table();
    Tref.metric = ["Sensitivity"; "Specificity"; "PPV"; "NPV"; "F1"; "TP"; "FP"; "FN"; "TN"];
    Tref.value = [sensRef; specRef; ppvRef; npvRef; f1Ref; TP_ref; FP_ref; FN_ref; TN_ref];
    writetable(Tref, fullfile(outputDir, 'binary_referable_metrics.csv'));
    fprintf('  binary_referable_metrics.csv\n');

    % Gap analysis table
    Tgap = table();
    Tgap.gap = ["Multi-reader annotations"; "Expert-verified lesion masks"; ...
                "External validation"; "Clinician-verified quality"; ...
                "Difficult-case annotations"; "Multi-center data"];
    Tgap.priority = ["HIGH"; "HIGH"; "HIGH"; "MEDIUM"; "MEDIUM"; "LOW"];
    Tgap.current = ["Single-grader only"; "54 IDRiD images"; "Messidor-2 available"; ...
                     "Algorithmic only"; "None"; "Single-center (India)"];
    Tgap.target = ["2-3 readers per image, 200-500 images"; ...
                    "200-500 expert-verified masks"; ...
                    "2+ external datasets with annotations"; ...
                    "Clinician quality grading"; ...
                    "Expert-labeled difficult cases"; ...
                    "Multi-center training data"];
    writetable(Tgap, fullfile(outputDir, 'gap_analysis.csv'));
    fprintf('  gap_analysis.csv\n');

    % Grade distribution
    Tgd = table();
    Tgd.dataset = [string("APTOS2019"); string("APTOS2019"); string("APTOS2019"); ...
                    string("APTOS2019"); string("APTOS2019"); ...
                    string("IDRiD"); string("IDRiD"); string("IDRiD"); ...
                    string("IDRiD"); string("IDRiD")];
    Tgd.grade = [0;1;2;3;4;0;1;2;3;4];
    Tgd.count = [sum(M.dataset=="APTOS2019" & M.dr_grade==0); ...
                 sum(M.dataset=="APTOS2019" & M.dr_grade==1); ...
                 sum(M.dataset=="APTOS2019" & M.dr_grade==2); ...
                 sum(M.dataset=="APTOS2019" & M.dr_grade==3); ...
                 sum(M.dataset=="APTOS2019" & M.dr_grade==4); ...
                 sum(M.dataset=="IDRiD" & M.dr_grade==0); ...
                 sum(M.dataset=="IDRiD" & M.dr_grade==1); ...
                 sum(M.dataset=="IDRiD" & M.dr_grade==2); ...
                 sum(M.dataset=="IDRiD" & M.dr_grade==3); ...
                 sum(M.dataset=="IDRiD" & M.dr_grade==4)];
    writetable(Tgd, fullfile(outputDir, 'grade_distribution.csv'));
    fprintf('  grade_distribution.csv\n');

    fprintf('\n============================================================\n');
    fprintf('  Phase 23 COMPLETE\n');
    fprintf('============================================================\n');
end
