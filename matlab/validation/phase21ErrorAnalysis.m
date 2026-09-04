function phase21ErrorAnalysis()
% phase21ErrorAnalysis  Phase 21 — Error Analysis & Improvement Decision
%
%   Deep analysis of the 611-image validation set to identify remaining
%   weaknesses and make evidence-based improvement decisions.

    fprintf('============================================================\n');
    fprintf('  Phase 21: Error Analysis & Improvement Decision\n');
    fprintf('============================================================\n\n');

    outputDir = 'results/phase21_error_analysis';
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end

    % Load merged data
    T = readtable('results/phase20c1/phase20c1_merged.csv', 'TextType', 'string');
    n = height(T);
    fprintf('Loaded %d validation images\n\n', n);

    %% ====================================================================
    %  1. CONFUSION MATRIX AND PER-CLASS ANALYSIS
    %  ====================================================================
    fprintf('--- 1. Confusion Matrix & Per-Class Analysis ---\n\n');

    trueG = T.dr_grade;
    predG = T.pred_grade;
    grades = 0:4;
    gradeLabels = {'G0','G1','G2','G3','G4'};
    nGrades = numel(grades);

    % Build confusion matrix
    cm = zeros(nGrades, nGrades);
    for i = 1:n
        t = trueG(i) + 1;
        p = predG(i) + 1;
        cm(t, p) = cm(t, p) + 1;
    end

    fprintf('Confusion Matrix (rows=true, cols=predicted):\n');
    fprintf('%-6s', '');
    for j = 1:nGrades, fprintf('%-8s', gradeLabels{j}); end
    fprintf('\n');
    for i = 1:nGrades
        fprintf('%-6s', gradeLabels{i});
        for j = 1:nGrades
            fprintf('%-8d', cm(i,j));
        end
        fprintf('(n=%d)\n', sum(cm(i,:)));
    end

    % Per-class metrics
    fprintf('\nPer-Class Metrics:\n');
    fprintf('%-6s  %-6s  %-6s  %-6s  %-8s  %-8s  %-8s  %-8s  %-8s\n', ...
        'Grade', 'TP', 'FP', 'FN', 'Sens', 'Spec', 'Prec', 'F1', 'Support');

    classMetrics = struct();
    for i = 1:nGrades
        tp = cm(i,i);
        fp = sum(cm(:,i)) - tp;
        fn = sum(cm(i,:)) - tp;
        tn = n - tp - fp - fn;
        sens = tp / (tp + fn);
        spec = tn / (tn + fp);
        prec = tp / (tp + fp);
        f1 = 2 * prec * sens / (prec + sens);
        support = sum(cm(i,:));

        classMetrics(i).grade = gradeLabels{i};
        classMetrics(i).tp = tp; classMetrics(i).fp = fp;
        classMetrics(i).fn = fn; classMetrics(i).tn = tn;
        classMetrics(i).sens = sens; classMetrics(i).spec = spec;
        classMetrics(i).prec = prec; classMetrics(i).f1 = f1;
        classMetrics(i).support = support;

        fprintf('%-6s  %-6d  %-6d  %-6d  %-8.3f  %-8.3f  %-8.3f  %-8.3f  %-6d\n', ...
            gradeLabels{i}, tp, fp, fn, sens, spec, prec, f1, support);
    end

    %% ====================================================================
    %  2. G3 AND G4 FAILURE PATTERNS
    %  ====================================================================
    fprintf('\n--- 2. G3 & G4 Failure Patterns ---\n\n');

    % G3 failures
    g3True = find(trueG == 3);
    g3Pred = predG(g3True);
    fprintf('G3 (Severe NPDR) — %d true cases:\n', numel(g3True));
    fprintf('  Predicted G0: %d (%.1f%%)\n', sum(g3Pred==0), sum(g3Pred==0)/numel(g3True)*100);
    fprintf('  Predicted G1: %d (%.1f%%)\n', sum(g3Pred==1), sum(g3Pred==1)/numel(g3True)*100);
    fprintf('  Predicted G2: %d (%.1f%%)\n', sum(g3Pred==2), sum(g3Pred==2)/numel(g3True)*100);
    fprintf('  Predicted G3: %d (%.1f%%) [correct]\n', sum(g3Pred==3), sum(g3Pred==3)/numel(g3True)*100);
    fprintf('  Predicted G4: %d (%.1f%%)\n', sum(g3Pred==4), sum(g3Pred==4)/numel(g3True)*100);

    % Where do G3 cases go?
    g3misclass = g3True(g3Pred ~= 3);
    if ~isempty(g3misclass)
        fprintf('\n  G3 misclassified as:\n');
        for i = 1:numel(g3misclass)
            idx = g3misclass(i);
            fprintf('    %s -> G%d (conf=%.3f, MA=%d HE=%d EX=%d quality=%s)\n', ...
                T.image_id(idx), predG(idx), T.confidence(idx), ...
                T.ma_count(idx), T.he_count(idx), T.ex_count(idx), T.quality_status(idx));
        end
    end

    % G4 failures
    g4True = find(trueG == 4);
    g4Pred = predG(g4True);
    fprintf('\nG4 (PDR) — %d true cases:\n', numel(g4True));
    fprintf('  Predicted G0: %d (%.1f%%)\n', sum(g4Pred==0), sum(g4Pred==0)/numel(g4True)*100);
    fprintf('  Predicted G1: %d (%.1f%%)\n', sum(g4Pred==1), sum(g4Pred==1)/numel(g4True)*100);
    fprintf('  Predicted G2: %d (%.1f%%)\n', sum(g4Pred==2), sum(g4Pred==2)/numel(g4True)*100);
    fprintf('  Predicted G3: %d (%.1f%%)\n', sum(g4Pred==3), sum(g4Pred==3)/numel(g4True)*100);
    fprintf('  Predicted G4: %d (%.1f%%) [correct]\n', sum(g4Pred==4), sum(g4Pred==4)/numel(g4True)*100);

    g4misclass = g4True(g4Pred ~= 4);
    if ~isempty(g4misclass)
        fprintf('\n  G4 misclassified as:\n');
        for i = 1:numel(g4misclass)
            idx = g4misclass(i);
            fprintf('    %s -> G%d (conf=%.3f, MA=%d HE=%d EX=%d quality=%s)\n', ...
                T.image_id(idx), predG(idx), T.confidence(idx), ...
                T.ma_count(idx), T.he_count(idx), T.ex_count(idx), T.quality_status(idx));
        end
    end

    %% ====================================================================
    %  3. CONFIDENCE CALIBRATION
    %  ====================================================================
    fprintf('\n--- 3. Confidence Calibration ---\n\n');

    % Overall confidence stats
    fprintf('Confidence distribution:\n');
    fprintf('  Mean: %.3f\n', mean(T.confidence));
    fprintf('  Median: %.3f\n', median(T.confidence));
    fprintf('  Std: %.3f\n', std(T.confidence));
    fprintf('  Min: %.3f\n', min(T.confidence));
    fprintf('  Max: %.3f\n', max(T.confidence));

    % Confidence bins
    bins = [0 0.3 0.5 0.7 0.9 1.0];
    binLabels = {'0-0.3','0.3-0.5','0.5-0.7','0.7-0.9','0.9-1.0'};
    fprintf('\nConfidence calibration (bin | n | correct | accuracy):\n');
    for b = 1:numel(bins)-1
        mask = T.confidence >= bins(b) & T.confidence < bins(b+1);
        if b == numel(bins)-1
            mask = T.confidence >= bins(b) & T.confidence <= bins(b+1);
        end
        nBin = sum(mask);
        nCorrect = sum(T.grade_match(mask) == 1);
        acc = nCorrect / nBin;
        fprintf('  %-10s: %4d images, %4d correct (%.1f%%)\n', binLabels{b}, nBin, nCorrect, acc*100);
    end

    % Per-grade confidence
    fprintf('\nPer-grade confidence (mean +/- std):\n');
    for i = 0:4
        mask = trueG == i;
        fprintf('  G%d: %.3f +/- %.3f (n=%d)\n', i, mean(T.confidence(mask)), std(T.confidence(mask)), sum(mask));
    end

    %% ====================================================================
    %  4. HIGH-CONFIDENCE WRONG AND LOW-CONFIDENCE CORRECT
    %  ====================================================================
    fprintf('\n--- 4. High-Confidence Wrong & Low-Confidence Correct ---\n\n');

    % High-confidence wrong (conf > 0.7, grade_match = 0)
    hcWrong = T(T.confidence > 0.7 & T.grade_match == 0, :);
    fprintf('HIGH-CONFIDENCE WRONG (conf > 0.7, wrong grade): %d images\n', height(hcWrong));
    fprintf('  Grade distribution of wrong predictions:\n');
    for i = 0:4
        nH = sum(hcWrong.pred_grade == i);
        if nH > 0
            fprintf('    Predicted G%d: %d\n', i, nH);
        end
    end
    fprintf('  True grade distribution:\n');
    for i = 0:4
        nH = sum(hcWrong.dr_grade == i);
        if nH > 0
            fprintf('    True G%d: %d\n', i, nH);
        end
    end

    % Top 10 highest-confidence wrong
    hcWrong_sorted = sortrows(hcWrong, 'confidence', 'descend');
    fprintf('\n  Top 10 highest-confidence wrong predictions:\n');
    for i = 1:min(10, height(hcWrong_sorted))
        row = hcWrong_sorted(i,:);
        fprintf('    %s: True G%d -> Pred G%d (conf=%.3f, MA=%d HE=%d EX=%d)\n', ...
            row.image_id, row.dr_grade, row.pred_grade, row.confidence, ...
            row.ma_count, row.he_count, row.ex_count);
    end

    % Low-confidence correct (conf < 0.5, grade_match = 1)
    lcCorrect = T(T.confidence < 0.5 & T.grade_match == 1, :);
    fprintf('\nLOW-CONFIDENCE CORRECT (conf < 0.5, correct grade): %d images\n', height(lcCorrect));
    fprintf('  Grade distribution:\n');
    for i = 0:4
        nL = sum(lcCorrect.dr_grade == i);
        if nL > 0
            fprintf('    True G%d: %d\n', i, nL);
        end
    end

    % Top 10 lowest-confidence correct
    lcCorrect_sorted = sortrows(lcCorrect, 'confidence', 'ascend');
    fprintf('\n  Top 10 lowest-confidence correct predictions:\n');
    for i = 1:min(10, height(lcCorrect_sorted))
        row = lcCorrect_sorted(i,:);
        fprintf('    %s: True G%d = Pred G%d (conf=%.3f, MA=%d HE=%d EX=%d)\n', ...
            row.image_id, row.dr_grade, row.pred_grade, row.confidence, ...
            row.ma_count, row.he_count, row.ex_count);
    end

    %% ====================================================================
    %  5. QUALITY VS ERRORS
    %  ====================================================================
    fprintf('\n--- 5. Image Quality vs Classification Errors ---\n\n');

    qualityStatuses = {'GOOD', 'BORDERLINE', 'POOR'};
    for q = 1:numel(qualityStatuses)
        qs = qualityStatuses{q};
        mask = T.quality_status == qs;
        nQ = sum(mask);
        nCorrect = sum(T.grade_match(mask) == 1);
        acc = nCorrect / nQ;
        meanConf = mean(T.confidence(mask));

        fprintf('  %s: %4d images, accuracy=%.1f%%, mean_conf=%.3f\n', qs, nQ, acc*100, meanConf);

        % Per-grade accuracy within this quality tier
        for g = 0:4
            gmask = mask & trueG == g;
            ng = sum(gmask);
            if ng > 0
                nc = sum(T.grade_match(gmask) == 1);
                fprintf('    G%d: %3d images, accuracy=%.1f%%\n', g, ng, nc/ng*100);
            end
        end
    end

    %% ====================================================================
    %  6. LESION COUNTS VS CLASSIFICATION
    %  ====================================================================
    fprintf('\n--- 6. Lesion Counts vs Classification ---\n\n');

    % Total lesion count distribution by true grade
    for g = 0:4
        mask = trueG == g;
        les = T.total_lesions(mask);
        fprintf('  G%d: mean_lesions=%.1f, median=%d, max=%d (n=%d)\n', ...
            g, mean(les), median(les), max(les), sum(mask));
    end

    % Correlation between lesion count and correct classification
    fprintf('\nCorrect vs incorrect by lesion count:\n');
    for g = 0:4
        mask = trueG == g;
        correctLes = T.total_lesions(mask & T.grade_match == 1);
        wrongLes = T.total_lesions(mask & T.grade_match == 0);
        if ~isempty(correctLes) && ~isempty(wrongLes)
            fprintf('  G%d: correct mean_les=%.1f, wrong mean_les=%.1f\n', ...
                g, mean(correctLes), mean(wrongLes));
        end
    end

    % Lesion evidence help analysis
    fprintf('\nLesion evidence analysis:\n');
    % Cases with lesions but predicted as G0 (possible false negatives)
    lesionButG0 = T(T.total_lesions > 0 & predG == 0 & trueG ~= 0, :);
    fprintf('  Images with lesions (>0) but predicted G0: %d\n', height(lesionButG0));
    if height(lesionButG0) > 0
        for i = 1:min(5, height(lesionButG0))
            row = lesionButG0(i,:);
            fprintf('    %s: True G%d, MA=%d HE=%d EX=%d\n', ...
                row.image_id, row.dr_grade, row.ma_count, row.he_count, row.ex_count);
        end
    end

    % Cases with no lesions but predicted as referable (possible false positives)
    noLesRef = T(T.total_lesions == 0 & predG >= 2 & trueG < 2, :);
    fprintf('  Images with 0 lesions but predicted referable: %d\n', height(noLesRef));

    %% ====================================================================
    %  7. OVERALL STATISTICS
    %  ====================================================================
    fprintf('\n--- 7. Overall Statistics ---\n\n');

    accuracy = sum(T.grade_match == 1) / n * 100;
    referable_true = T.dr_grade >= 2;
    referable_pred = T.pred_grade >= 2;
    sens_ref = sum(referable_true & referable_pred) / sum(referable_true) * 100;
    spec_ref = sum(~referable_true & ~referable_pred) / sum(~referable_true) * 100;
    auc_ref = NaN; % Would need roc_data

    fprintf('  Overall accuracy: %.1f%% (%d/%d)\n', accuracy, sum(T.grade_match==1), n);
    fprintf('  Referable sensitivity: %.1f%%\n', sens_ref);
    fprintf('  Referable specificity: %.1f%%\n', spec_ref);
    fprintf('  G0 accuracy: %.1f%%\n', classMetrics(1).sens*100);
    fprintf('  G1 accuracy: %.1f%%\n', classMetrics(2).sens*100);
    fprintf('  G2 accuracy: %.1f%%\n', classMetrics(3).sens*100);
    fprintf('  G3 accuracy: %.1f%%\n', classMetrics(4).sens*100);
    fprintf('  G4 accuracy: %.1f%%\n', classMetrics(5).sens*100);

    %% ====================================================================
    %  8. WRITE OUTPUTS
    %  ====================================================================
    fprintf('\n--- Writing outputs ---\n');

    % Confusion matrix CSV
    Tcm = array2table(cm, 'VariableNames', gradeLabels, 'RowNames', gradeLabels);
    writetable(Tcm, fullfile(outputDir, 'confusion_matrix.csv'), 'WriteRowNames', true);
    fprintf('  confusion_matrix.csv\n');

    % Per-class metrics CSV
    Tpc = table();
    for i = 1:nGrades
        idx = size(Tpc, 1) + 1;
        Tpc.grade(idx) = string(classMetrics(i).grade);
        Tpc.TP(idx) = classMetrics(i).tp;
        Tpc.FP(idx) = classMetrics(i).fp;
        Tpc.FN(idx) = classMetrics(i).fn;
        Tpc.sensitivity(idx) = classMetrics(i).sens;
        Tpc.specificity(idx) = classMetrics(i).spec;
        Tpc.precision(idx) = classMetrics(i).prec;
        Tpc.F1(idx) = classMetrics(i).f1;
        Tpc.support(idx) = classMetrics(i).support;
    end
    writetable(Tpc, fullfile(outputDir, 'per_class_metrics.csv'));
    fprintf('  per_class_metrics.csv\n');

    % High-confidence wrong CSV
    writetable(hcWrong_sorted, fullfile(outputDir, 'high_confidence_wrong.csv'));
    fprintf('  high_confidence_wrong.csv (%d images)\n', height(hcWrong_sorted));

    % Low-confidence correct CSV
    writetable(lcCorrect_sorted, fullfile(outputDir, 'low_confidence_correct.csv'));
    fprintf('  low_confidence_correct.csv (%d images)\n', height(lcCorrect_sorted));

    % G3 failure details CSV
    Tg3 = T(g3True, :);
    writetable(Tg3, fullfile(outputDir, 'g3_true_cases.csv'));
    fprintf('  g3_true_cases.csv (%d images)\n', height(Tg3));

    % G4 failure details CSV
    Tg4 = T(g4True, :);
    writetable(Tg4, fullfile(outputDir, 'g4_true_cases.csv'));
    fprintf('  g4_true_cases.csv (%d images)\n', height(Tg4));

    % Quality breakdown CSV
    Tq = table();
    for q = 1:numel(qualityStatuses)
        qs = qualityStatuses{q};
        mask = T.quality_status == qs;
        idx = size(Tq, 1) + 1;
        Tq.quality_status(idx) = string(qs);
        Tq.n_images(idx) = sum(mask);
        Tq.accuracy(idx) = sum(T.grade_match(mask)==1) / sum(mask);
        Tq.mean_confidence(idx) = mean(T.confidence(mask));
    end
    writetable(Tq, fullfile(outputDir, 'quality_breakdown.csv'));
    fprintf('  quality_breakdown.csv\n');

    fprintf('\n============================================================\n');
    fprintf('  Phase 21 Error Analysis COMPLETE\n');
    fprintf('============================================================\n');
end
