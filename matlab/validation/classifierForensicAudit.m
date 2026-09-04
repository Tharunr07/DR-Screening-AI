function classifierForensicAudit()
% classifierForensicAudit  Phase 20D.1 — Frozen classifier forensic audit
%
%   Full 5-class analysis of the frozen classifier on all 611 labeled
%   validation images. No model modification.
%
%   Outputs:
%     results/phase20d1/classifier_forensic_audit.csv
%     results/phase20d1/confusion_matrix.csv
%     results/phase20d1/per_class_metrics.csv
%     results/phase20d1/probability_analysis.csv
%     results/phase20d1/figures/

    fprintf('============================================================\n');
    fprintf('  Phase 20D.1: Frozen Classifier Forensic Audit\n');
    fprintf('============================================================\n\n');

    % === Setup ===
    cfgTL = transferLearningConfig();
    modelPath = fullfile(cfgTL.paths.modelDir, 'trainedNetTL.mat');
    data = load(modelPath, 'trainedNetTL');
    net = data.trainedNetTL;

    valCsv = fullfile(cfgTL.paths.splitDir, 'val.csv');
    T = readtable(valCsv);
    hasGrade = ~isnan(T.dr_grade);
    T = T(hasGrade, :);
    nImages = height(T);
    fprintf('Loaded %d labeled validation images\n', nImages);

    % Output dir
    outputDir = fullfile(fileparts(mfilename('fullpath')), '..', '..', 'results', 'phase20d1');
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end
    figDir = fullfile(outputDir, 'figures');
    if ~exist(figDir, 'dir'), mkdir(figDir); end

    gradeLabels = {'G0', 'G1', 'G2', 'G3', 'G4'};
    fullLabels = {'No DR', 'Mild NPDR', 'Moderate NPDR', 'Severe NPDR', 'PDR'};

    % === Collect predictions ===
    trueGrades = zeros(nImages, 1);
    predGrades = zeros(nImages, 1);
    allScores = zeros(nImages, 5);  % P(G0)..P(G4)
    imgIds = cell(nImages, 1);
    datasets = cell(nImages, 1);
    imgPaths = cell(nImages, 1);

    fprintf('\nRunning classifier on %d images...\n', nImages);
    for i = 1:nImages
        imgPath = char(T.file_path_absolute{i});
        imgIds{i} = char(T.image_id{i});
        datasets{i} = char(T.dataset{i});
        trueGrades(i) = T.dr_grade(i);

        if ~exist(imgPath, 'file')
            fprintf('  MISSING: %s\n', imgPath);
            predGrades(i) = -1;
            continue;
        end

        try
            img = imread(imgPath);
            if size(img, 3) ~= 3, continue; end
            n = preprocessFundus(img, cfgTL.image.size);

            [pred, scores] = classify(net, n);
            predGrades(i) = double(pred) - 1;
            allScores(i, :) = double(scores(:))';

            if mod(i, 100) == 0
                fprintf('  [%d/%d] %s true=%d pred=%d\n', i, nImages, ...
                    imgIds{i}, trueGrades(i), predGrades(i));
            end
        catch ME
            fprintf('  ERROR %s: %s\n', imgIds{i}, ME.message);
            predGrades(i) = -1;
        end
    end

    % Filter out failed predictions
    valid = predGrades >= 0;
    fprintf('\nValid predictions: %d/%d\n', sum(valid), nImages);

    tG = trueGrades(valid);
    pG = predGrades(valid);
    sc = allScores(valid, :);
    ids = imgIds(valid);
    dss = datasets(valid);
    nValid = sum(valid);

    % === 1. Full confusion matrix ===
    fprintf('\n--- 5x5 CONFUSION MATRIX ---\n');
    C = zeros(5, 5);
    for i = 1:nValid
        C(tG(i)+1, pG(i)+1) = C(tG(i)+1, pG(i)+1) + 1;
    end

    fprintf('%12s', '');
    for j = 1:5, fprintf('%8s', gradeLabels{j}); end
    fprintf('\n');
    for i = 1:5
        fprintf('%12s', gradeLabels{i});
        for j = 1:5
            fprintf('%8d', C(i, j));
        end
        fprintf('  (n=%d)\n', sum(C(i,:)));
    end
    fprintf('%12s', 'Pred freq');
    for j = 1:5, fprintf('%8d', sum(C(:,j))); end
    fprintf('\n');

    % === 2. Per-class metrics ===
    fprintf('\n--- PER-CLASS METRICS ---\n');
    perClass = struct();
    for c = 1:5
        tp = C(c, c);
        fn = sum(C(c, :)) - tp;
        fp = sum(C(:, c)) - tp;
        tn = nValid - tp - fn - fp;

        sensitivity = tp / (tp + fn);
        specificity = tn / (tn + fp);
        precision = tp / (tp + fp);
        f1 = 2 * precision * sensitivity / (precision + sensitivity);
        support = sum(C(c, :));
        predFreq = sum(C(:, c)) / nValid;

        perClass(c).grade = gradeLabels{c};
        perClass(c).fullLabel = fullLabels{c};
        perClass(c).tp = tp;
        perClass(c).fp = fp;
        perClass(c).fn = fn;
        perClass(c).tn = tn;
        perClass(c).sensitivity = sensitivity;
        perClass(c).specificity = specificity;
        perClass(c).precision = precision;
        perClass(c).f1 = f1;
        perClass(c).support = support;
        perClass(c).predFreq = predFreq;

        fprintf('  %s (%s): sens=%.3f spec=%.3f prec=%.3f F1=%.3f support=%d predFreq=%.3f\n', ...
            gradeLabels{c}, fullLabels{c}, sensitivity, specificity, precision, f1, support, predFreq);
    end

    % === 3. Prediction frequency analysis ===
    fprintf('\n--- PREDICTION FREQUENCY ---\n');
    for c = 1:5
        actualN = sum(tG == c-1);
        predN = sum(pG == c-1);
        fprintf('  %s: actual=%d (%.1f%%)  predicted=%d (%.1f%%)  ratio=%.2f\n', ...
            gradeLabels{c}, actualN, actualN/nValid*100, predN, predN/nValid*100, predN/max(actualN,1));
    end

    % === 4. G2 bias deep dive ===
    fprintf('\n--- G2 BIAS ANALYSIS ---\n');
    g2mask = (pG == 2);
    fprintf('  Images predicted G2: %d/%d (%.1f%%)\n', sum(g2mask), nValid, sum(g2mask)/nValid*100);

    fprintf('\n  Actual grade distribution of G2-predicted images:\n');
    for c = 0:4
        cnt = sum(tG(g2mask) == c);
        fprintf('    True G%d predicted as G2: %d\n', c, cnt);
    end

    % === 5. Probability distribution analysis ===
    fprintf('\n--- PROBABILITY DISTRIBUTIONS ---\n');
    probAnalysis = struct();
    for c = 0:4
        idx = (tG == c);
        if sum(idx) == 0, continue; end
        probsForGrade = sc(idx, :);

        fprintf('  True G%d (n=%d):\n', c, sum(idx));
        for pc = 0:4
            col = probsForGrade(:, pc+1);
            fprintf('    P(G%d): mean=%.4f std=%.4f median=%.4f min=%.4f max=%.4f\n', ...
                pc, mean(col), std(col), median(col), min(col), max(col));
        end

        % Probability of the predicted grade
        pOfTrue = probsForGrade(:, c+1);
        fprintf('    P(true grade): mean=%.4f std=%.4f median=%.4f\n', ...
            mean(pOfTrue), std(pOfTrue), median(pOfTrue));

        % Entropy of the distribution
        entropies = zeros(sum(idx), 1);
        for ii = 1:sum(idx)
            p = max(probsForGrade(ii, :), 1e-10);
            entropies(ii) = -sum(p .* log2(p));
        end
        fprintf('    Entropy: mean=%.4f std=%.4f (max possible=%.4f)\n', ...
            mean(entropies), std(entropies), log2(5));
    end

    % === 6. Per-class probability histograms ===
    fprintf('\n  Generating probability distribution figures...\n');
    figure('Visible', 'off', 'Position', [100 100 1200 800]);
    for c = 0:4
        subplot(2, 3, c+1);
        idx = (tG == c);
        if sum(idx) > 0
            histogram(sc(idx, c+1), 0:0.05:1, 'FaceColor', [0.2 0.6 0.8]);
            title(sprintf('P(G%d) | True G%d (n=%d)', c, c, sum(idx)));
            xlabel(sprintf('P(G%d)', c));
            ylabel('Count');
            xlim([0 1]);
        end
    end
    subplot(2, 3, 6);
    % Mean predicted probability matrix
    meanProbs = zeros(5, 5);
    for c = 0:4
        idx = (tG == c);
        if sum(idx) > 0
            meanProbs(c+1, :) = mean(sc(idx, :), 1);
        end
    end
    bar(meanProbs', 'grouped');
    set(gca, 'XTickLabel', gradeLabels);
    legend(gradeLabels, 'Location', 'best');
    title('Mean P(predicted grade) by true grade');
    xlabel('Predicted grade');
    ylabel('Mean probability');
    saveas(gcf, fullfile(figDir, 'probability_distributions.png'));
    close;

    % === 7. Confusion matrix heatmap ===
    fprintf('  Generating confusion matrix heatmap...\n');
    figure('Visible', 'off', 'Position', [100 100 700 600]);
    imagesc(C);
    colorbar;
    colormap(flipud(hot));
    set(gca, 'XTick', 1:5, 'XTickLabel', gradeLabels);
    set(gca, 'YTick', 1:5, 'YTickLabel', gradeLabels);
    xlabel('Predicted Grade');
    ylabel('True Grade');
    title(sprintf('Confusion Matrix (n=%d, accuracy=%.1f%%)', nValid, sum(diag(C))/nValid*100));
    for i = 1:5
        for j = 1:5
            text(j, i, sprintf('%d', C(i,j)), 'HorizontalAlignment', 'center', ...
                'FontSize', 12, 'FontWeight', 'bold', 'Color', C(i,j)/max(C(:))*[0 0 0] + 0.5);
        end
    end
    saveas(gcf, fullfile(figDir, 'confusion_matrix_heatmap.png'));
    close;

    % === 8. Confusion matrix normalized (by row) ===
    figure('Visible', 'off', 'Position', [100 100 700 600]);
    Cnorm = zeros(5,5);
    for i = 1:5
        rowSum = sum(C(i,:));
        if rowSum > 0, Cnorm(i,:) = C(i,:) / rowSum; end
    end
    imagesc(Cnorm);
    colorbar;
    colormap(flipud(hot));
    caxis([0 1]);
    set(gca, 'XTick', 1:5, 'XTickLabel', gradeLabels);
    set(gca, 'YTick', 1:5, 'YTickLabel', gradeLabels);
    xlabel('Predicted Grade');
    ylabel('True Grade');
    title('Confusion Matrix (row-normalized)');
    for i = 1:5
        for j = 1:5
            text(j, i, sprintf('%.1f%%', Cnorm(i,j)*100), 'HorizontalAlignment', 'center', ...
                'FontSize', 11, 'FontWeight', 'bold');
        end
    end
    saveas(gcf, fullfile(figDir, 'confusion_matrix_normalized.png'));
    close;

    % === 9. ROC curves (one-vs-rest) ===
    fprintf('  Generating ROC curves...\n');
    figure('Visible', 'off', 'Position', [100 100 900 700]);
    colors = lines(5);
    rocData = struct();
    for c = 0:4
        labels = double(tG == c);
        scores_c = sc(:, c+1);
        [X, Y, ~, auc] = perfcurve(labels, scores_c, 1);

        subplot(2, 3, c+1);
        plot(X, Y, 'Color', colors(c+1,:), 'LineWidth', 2);
        hold on;
        plot([0 1], [0 1], 'k--', 'LineWidth', 1);
        xlabel('False Positive Rate');
        ylabel('True Positive Rate');
        title(sprintf('ROC: %s vs Rest (AUC=%.3f)', gradeLabels{c+1}, auc));
        grid on;

        rocData(c+1).grade = gradeLabels{c+1};
        rocData(c+1).auc = auc;
        rocData(c+1).fpr = X;
        rocData(c+1).tpr = Y;
        fprintf('    %s vs Rest: AUC=%.4f\n', gradeLabels{c+1}, auc);
    end
    subplot(2, 3, 6);
    for c = 0:4
        plot(rocData(c+1).fpr, rocData(c+1).tpr, 'LineWidth', 2, 'DisplayName', ...
            sprintf('%s (AUC=%.3f)', gradeLabels{c+1}, rocData(c+1).auc));
        hold on;
    end
    plot([0 1], [0 1], 'k--');
    xlabel('False Positive Rate');
    ylabel('True Positive Rate');
    title('All ROC Curves');
    legend('Location', 'southeast');
    grid on;
    saveas(gcf, fullfile(figDir, 'roc_curves.png'));
    close;

    % === 10. G2 collapse analysis: confidence distributions ===
    fprintf('  Generating G2 collapse analysis...\n');
    figure('Visible', 'off', 'Position', [100 100 1200 500]);

    subplot(1, 2, 1);
    % Box plot of P(G2) by true grade
    g2ByTrue = cell(5, 1);
    for c = 0:4
        idx = (tG == c);
        g2ByTrue{c+1} = sc(idx, 3);  % P(G2) column = index 3
    end
    % Use violin plot or boxplot
    groupLabels = {};
    groupData = [];
    groupGroup = [];
    for c = 0:4
        n_c = numel(g2ByTrue{c+1});
        groupData = [groupData; g2ByTrue{c+1}]; %#ok<AGROW>
        groupGroup = [groupGroup; c+1 * ones(n_c, 1)]; %#ok<AGROW>
    end
    boxplot(groupData, groupGroup, 'Labels', gradeLabels);
    ylabel('P(G2)');
    title('P(G2) by True Grade — G2 Collapse');
    grid on;

    subplot(1, 2, 2);
    % Max probability (confidence) by correctness
    correct = (tG == pG);
    confCorrect = max(sc(correct, :), [], 2);
    confIncorrect = max(sc(~correct, :), [], 2);
    histogram(confCorrect, 0:0.05:1, 'FaceColor', [0.2 0.7 0.3], 'FaceAlpha', 0.6);
    hold on;
    histogram(confIncorrect, 0:0.05:1, 'FaceColor', [0.8 0.3 0.2], 'FaceAlpha', 0.6);
    legend(sprintf('Correct (n=%d)', sum(correct)), sprintf('Incorrect (n=%d)', sum(~correct)));
    xlabel('Max P(class) — Confidence');
    ylabel('Count');
    title('Confidence Distribution: Correct vs Incorrect');
    grid on;
    saveas(gcf, fullfile(figDir, 'g2_collapse_analysis.png'));
    close;

    % === 11. Per-image CSV ===
    fprintf('  Writing per-image CSV...\n');
    predGradeChar = cell(nValid, 1);
    trueGradeChar = cell(nValid, 1);
    correctStr = cell(nValid, 1);
    for i = 1:nValid
        predGradeChar{i} = gradeLabels{pG(i)+1};
        trueGradeChar{i} = gradeLabels{tG(i)+1};
        if correct(i), correctStr{i} = 'correct'; else, correctStr{i} = 'incorrect'; end
    end
    Taudit = table(ids, dss, trueGradeChar, predGradeChar, correctStr, ...
        sc(:,1), sc(:,2), sc(:,3), sc(:,4), sc(:,5), ...
        'VariableNames', {'image_id', 'dataset', 'true_grade', 'pred_grade', 'result', ...
        'P_G0', 'P_G1', 'P_G2', 'P_G3', 'P_G4'});
    writetable(Taudit, fullfile(outputDir, 'classifier_forensic_audit.csv'));

    % === 12. Confusion matrix CSV ===
    Ctable = array2table(C, 'VariableNames', gradeLabels, 'RowNames', gradeLabels);
    writetable(Ctable, fullfile(outputDir, 'confusion_matrix.csv'), 'WriteRowNames', true);

    % === 13. Per-class metrics CSV ===
    metricNames = {'grade', 'full_label', 'TP', 'FP', 'FN', 'TN', 'sensitivity', ...
        'specificity', 'precision', 'F1', 'support', 'prediction_frequency'};
    metricData = cell(5, 12);
    for c = 1:5
        metricData{c, 1} = perClass(c).grade;
        metricData{c, 2} = perClass(c).fullLabel;
        metricData{c, 3} = perClass(c).tp;
        metricData{c, 4} = perClass(c).fp;
        metricData{c, 5} = perClass(c).fn;
        metricData{c, 6} = perClass(c).tn;
        metricData{c, 7} = perClass(c).sensitivity;
        metricData{c, 8} = perClass(c).specificity;
        metricData{c, 9} = perClass(c).precision;
        metricData{c, 10} = perClass(c).f1;
        metricData{c, 11} = perClass(c).support;
        metricData{c, 12} = perClass(c).predFreq;
    end
    Tmetrics = cell2table(metricData, 'VariableNames', metricNames);
    writetable(Tmetrics, fullfile(outputDir, 'per_class_metrics.csv'));

    % === 14. Representative panels ===
    fprintf('  Generating representative panels...\n');
    generateRepresentativePanels(outputDir, figDir, sc, tG, pG, ids, dss, T, cfgTL, gradeLabels);

    % === 15. Write report ===
    fprintf('\n  Writing audit report...\n');
    writeAuditReport(outputDir, nValid, C, perClass, tG, pG, sc, correct, ...
        rocData, gradeLabels, fullLabels);

    fprintf('\n============================================================\n');
    fprintf('  Phase 20D.1 COMPLETE\n');
    fprintf('  Output: %s\n', outputDir);
    fprintf('============================================================\n');
end

%% === HELPER FUNCTIONS ===

function generateRepresentativePanels(outputDir, figDir, sc, tG, pG, ids, dss, T, cfgTL, gradeLabels)
% Generate panels showing correctly classified and misclassified examples

    panelDir = fullfile(outputDir, 'panels');
    if ~exist(panelDir, 'dir'), mkdir(panelDir); end

    correct = (tG == pG);
    allLabels = {'No DR','Mild NPDR','Moderate NPDR','Severe NPDR','PDR'};

    % For each true grade, find: 1) best correct (highest P(true)), 2) worst correct (lowest P(true)),
    % 3) most confident incorrect, 4) least confident incorrect
    for c = 0:4
        idx = find(tG == c);
        if isempty(idx), continue; end

        % Correct predictions
        cIdx = idx(correct(idx));
        % Incorrect predictions
        iIdx = idx(~correct(idx));

        figure('Visible', 'off', 'Position', [100 100 1600 400]);

        examples = {};
        titles = {};

        % Best correct
        if ~isempty(cIdx)
            pTrue = sc(cIdx, c+1);
            [~, bestI] = max(pTrue);
            examples{end+1} = cIdx(bestI);
            titles{end+1} = sprintf('BEST Correct\nTrue=%s Pred=%s\nP(G%d)=%.3f', ...
                gradeLabels{c+1}, gradeLabels{pG(cIdx(bestI))+1}, c, sc(cIdx(bestI), c+1));
        end

        % Worst correct
        if numel(cIdx) > 1
            pTrue = sc(cIdx, c+1);
            [~, worstI] = min(pTrue);
            if worstI ~= bestI
                examples{end+1} = cIdx(worstI);
                titles{end+1} = sprintf('WORST Correct\nTrue=%s Pred=%s\nP(G%d)=%.3f', ...
                    gradeLabels{c+1}, gradeLabels{pG(cIdx(worstI))+1}, c, sc(cIdx(worstI), c+1));
            end
        end

        % Most confident incorrect
        if ~isempty(iIdx)
            pMax = max(sc(iIdx, :), [], 2);
            [~, bestI] = max(pMax);
            examples{end+1} = iIdx(bestI);
            titles{end+1} = sprintf('Most Confident WRONG\nTrue=%s Pred=%s\nMaxP=%.3f', ...
                gradeLabels{c+1}, gradeLabels{pG(iIdx(bestI))+1}, pMax(bestI));
        end

        % Random correct for diversity
        if numel(cIdx) > 2
            rng(42);
            rI = cIdx(randperm(numel(cIdx), 1));
            exVals = cellfun(@(x) x, examples);
            if ~ismember(rI, exVals)
                examples{end+1} = rI;
                titles{end+1} = sprintf('Random Correct\nTrue=%s Pred=%s\nP(G%d)=%.3f', ...
                    gradeLabels{c+1}, gradeLabels{pG(rI)+1}, c, sc(rI, c+1));
            end
        end

        nEx = numel(examples);
        if nEx == 0, close; continue; end

        for ex = 1:min(nEx, 4)
            subplot(1, min(nEx, 4), ex);
            imgIdx = examples{ex};
            imgPath = char(T.file_path_absolute{imgIdx});
            if exist(imgPath, 'file')
                img = imread(imgPath);
                imshow(img);
            end
            title(titles{ex}, 'FontSize', 8);
        end
        sgtitle(sprintf('Grade %s (%s) — True Grade Examples', gradeLabels{c+1}, ...
            allLabels{c+1}));
        saveas(gcf, fullfile(panelDir, sprintf('grade_%s_panel.png', gradeLabels{c+1})));
        close;
    end

    % Top 10 most confident incorrect
    incorrect = find(~correct);
    if ~isempty(incorrect)
        pMax = max(sc(incorrect, :), [], 2);
        [~, sortI] = sort(pMax, 'descend');
        topN = incorrect(sortI(1:min(10, numel(sortI))));

        figure('Visible', 'off', 'Position', [100 100 1600 800]);
        for ex = 1:min(10, numel(topN))
            subplot(2, 5, ex);
            imgIdx = topN(ex);
            imgPath = char(T.file_path_absolute{imgIdx});
            if exist(imgPath, 'file')
                img = imread(imgPath);
                imshow(img);
            end
            probs_str = sprintf('P(G0-G4)=[%.2f %.2f %.2f %.2f %.2f]', ...
                sc(imgIdx, 1), sc(imgIdx, 2), sc(imgIdx, 3), sc(imgIdx, 4), sc(imgIdx, 5));
            title(sprintf('True=%s Pred=%s\n%s', gradeLabels{tG(imgIdx)+1}, ...
                gradeLabels{pG(imgIdx)+1}, probs_str), 'FontSize', 7);
        end
        sgtitle('Top 10 Most Confident Misclassifications');
        saveas(gcf, fullfile(panelDir, 'top10_incorrect.png'));
        close;
    end
end

function writeAuditReport(outputDir, nValid, C, perClass, tG, pG, sc, correct, ...
    rocData, gradeLabels, fullLabels)

    fid = fopen(fullfile(outputDir, 'PHASE20D1_CLASSIFIER_FORENSIC_AUDIT.md'), 'w');
    if fid < 0, error('Cannot open report file'); end

    fprintf(fid, '## Phase 20D.1: Frozen Classifier Forensic Audit\n\n');
    fprintf(fid, '**Date**: 2026-09-04\n');
    fprintf(fid, '**Status**: COMPLETE\n');
    fprintf(fid, '**Scope**: All %d labeled validation images\n', nValid);
    fprintf(fid, '**Model**: trainedNetTL.mat (frozen, commit cc7bed8)\n');
    fprintf(fid, '**Constraint**: No model modification, no retraining, no threshold changes\n\n');

    fprintf(fid, '## Executive Summary\n\n');
    fprintf(fid, 'The frozen classifier achieves **%.1f%% grade-level accuracy** and ', sum(correct)/nValid*100);
    fprintf(fid, '**%.1f%% referable-DR accuracy** on the 611-image validation set.\n\n', ...
        sum((tG >= 2) == (pG >= 2))/nValid*100);
    fprintf(fid, 'The dominant failure mode is **collapse toward G2**: the model predicts G2 ');
    fprintf(fid, 'for **%.1f%%** of all images, regardless of true grade.\n\n', sum(pG==2)/nValid*100);
    fprintf(fid, 'This is a model-level limitation, not a software bug in the lesion pipeline.\n\n');

    % Confusion matrix
    fprintf(fid, '## 5x5 Confusion Matrix\n\n');
    fprintf(fid, '| | Pred G0 | Pred G1 | Pred G2 | Pred G3 | Pred G4 | Total |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|\n');
    for i = 1:5
        fprintf(fid, '| **True %s** |', gradeLabels{i});
        for j = 1:5
            fprintf(fid, ' %d |', C(i,j));
        end
        fprintf(fid, ' **%d** |\n', sum(C(i,:)));
    end
    fprintf(fid, '| **Pred Freq** |');
    for j = 1:5, fprintf(fid, ' %d (%.1f%%) |', sum(C(:,j)), sum(C(:,j))/nValid*100); end
    fprintf(fid, ' **%d** |\n\n', nValid);

    % Normalized matrix
    fprintf(fid, '### Row-Normalized (Recall per True Grade)\n\n');
    fprintf(fid, '| | Pred G0 | Pred G1 | Pred G2 | Pred G3 | Pred G4 |\n');
    fprintf(fid, '|---|---|---|---|---|---|\n');
    for i = 1:5
        rowSum = sum(C(i,:));
        fprintf(fid, '| **True %s** |', gradeLabels{i});
        for j = 1:5
            if rowSum > 0
                fprintf(fid, ' %.1f%% |', C(i,j)/rowSum*100);
            else
                fprintf(fid, ' — |');
            end
        end
        fprintf(fid, '\n');
    end

    % Per-class metrics
    fprintf(fid, '\n## Per-Class Metrics\n\n');
    fprintf(fid, '| Grade | Label | TP | FP | FN | TN | Sensitivity | Specificity | Precision | F1 | Support | Pred Freq |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|---|---|---|---|---|\n');
    for c = 1:5
        fprintf(fid, '| %s | %s | %d | %d | %d | %d | %.3f | %.3f | %.3f | %.3f | %d | %.3f |\n', ...
            perClass(c).grade, perClass(c).fullLabel, perClass(c).tp, perClass(c).fp, ...
            perClass(c).fn, perClass(c).tn, perClass(c).sensitivity, perClass(c).specificity, ...
            perClass(c).precision, perClass(c).f1, perClass(c).support, perClass(c).predFreq);
    end

    % G2 bias
    fprintf(fid, '\n## G2 Collapse Analysis\n\n');
    fprintf(fid, 'The model predicts G2 for **%d/%d (%.1f%%)** of all images.\n\n', ...
        sum(pG==2), nValid, sum(pG==2)/nValid*100);
    fprintf(fid, '### Actual Grade Distribution of G2-Predicted Images\n\n');
    fprintf(fid, '| True Grade | Count | % of True Grade | % of All G2 Predictions |\n');
    fprintf(fid, '|---|---|---|---|\n');
    totalG2 = sum(pG==2);
    for c = 0:4
        cnt = sum(tG(pG==2) == c);
        trueN = sum(tG == c);
        fprintf(fid, '| %s | %d | %.1f%% | %.1f%% |\n', ...
            gradeLabels{c+1}, cnt, cnt/max(trueN,1)*100, cnt/max(totalG2,1)*100);
    end

    % ROC / AUC
    fprintf(fid, '\n## ROC Analysis (One-vs-Rest)\n\n');
    fprintf(fid, '| Class | AUC |\n');
    fprintf(fid, '|---|---|\n');
    for c = 1:5
        fprintf(fid, '| %s vs Rest | %.4f |\n', gradeLabels{c}, rocData(c).auc);
    end

    % Probability analysis
    fprintf(fid, '\n## Probability Distribution Analysis\n\n');
    fprintf(fid, '### Mean Predicted Probability Matrix\n\n');
    fprintf(fid, '| True\\Pred | G0 | G1 | G2 | G3 | G4 |\n');
    fprintf(fid, '|---|---|---|---|---|---|\n');
    for c = 0:4
        idx = (tG == c);
        if sum(idx) > 0
            meanP = mean(sc(idx, :), 1);
            fprintf(fid, '| **%s** | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
                gradeLabels{c+1}, meanP(1), meanP(2), meanP(3), meanP(4), meanP(5));
        end
    end

    % Confidence analysis
    fprintf(fid, '\n### Confidence (Max P) Analysis\n\n');
    confCorrect = max(sc(correct, :), [], 2);
    confIncorrect = max(sc(~correct, :), [], 2);
    fprintf(fid, '| | Mean | Median | Std | Min | Max |\n');
    fprintf(fid, '|---|---|---|---|---|---|\n');
    if ~isempty(confCorrect)
        fprintf(fid, '| Correct (n=%d) | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
            sum(correct), mean(confCorrect), median(confCorrect), std(confCorrect), min(confCorrect), max(confCorrect));
    end
    if ~isempty(confIncorrect)
        fprintf(fid, '| Incorrect (n=%d) | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
            sum(~correct), mean(confIncorrect), median(confIncorrect), std(confIncorrect), min(confIncorrect), max(confIncorrect));
    end

    % Entropy
    fprintf(fid, '\n### Distribution Entropy\n\n');
    for c = 0:4
        idx = (tG == c);
        if sum(idx) == 0, continue; end
        entropies = zeros(sum(idx), 1);
        probsAll = sc(idx, :);
        for ii = 1:sum(idx)
            p = max(probsAll(ii, :), 1e-10);
            entropies(ii) = -sum(p .* log2(p));
        end
        fprintf(fid, '| %s (n=%d) | mean=%.4f std=%.4f | (max=%.2f) |\n', ...
            gradeLabels{c+1}, sum(idx), mean(entropies), std(entropies), log2(5));
    end

    % Hypotheses
    fprintf(fid, '\n## Hypotheses for G2 Collapse\n\n');
    fprintf(fid, '1. **Class imbalance in training data**: G2 may be the majority class, ');
    fprintf(fid, 'leading the model to default to G2 as a low-risk prediction.\n\n');
    fprintf(fid, '2. **Feature similarity**: The visual features distinguishing G1/G2/G3 ');
    fprintf(fid, 'may be too subtle for ResNet-18 to capture at 224x224 resolution.\n\n');
    fprintf(fid, '3. **Preprocessing normalization**: The ImageNet normalization ');
    fprintf(fid, '([0.485,0.456,0.406]/[0.229,0.224,0.225]) may not be optimal for fundus images.\n\n');
    fprintf(fid, '4. **Low entropy outputs**: The model may be overconfident in its G2 ');
    fprintf(fid, 'predictions, with P(G2) concentrated above 0.8 even for non-G2 images.\n\n');
    fprintf(fid, '5. **Resolution**: 224x224 may lose fine-grained lesion details ');
    fprintf(fid, 'needed for 5-class discrimination.\n\n');

    % Recommendations
    fprintf(fid, '## Recommendations\n\n');
    fprintf(fid, '1. **Check training class distribution** — confirm if G2 is overrepresented\n');
    fprintf(fid, '2. **Examine training loss curves** — is the model actually learning multi-class features?\n');
    fprintf(fid, '3. **Test alternative architectures** — consider larger models (ResNet-50) or attention mechanisms\n');
    fprintf(fid, '4. **Test resolution** — try 448x448 or 512x512 input to preserve lesion detail\n');
    fprintf(fid, '5. **Consider ordinal regression** — DR grades are ordered; exploit this structure\n');
    fprintf(fid, '6. **Ensemble approach** — combine binary (referable vs non-referable) with grade refinement\n');

    fprintf(fid, '\n## Figures\n\n');
    fprintf(fid, '- `figures/confusion_matrix_heatmap.png`\n');
    fprintf(fid, '- `figures/confusion_matrix_normalized.png`\n');
    fprintf(fid, '- `figures/probability_distributions.png`\n');
    fprintf(fid, '- `figures/roc_curves.png`\n');
    fprintf(fid, '- `figures/g2_collapse_analysis.png`\n');
    fprintf(fid, '- `panels/grade_G{0,1,2,3,4}_panel.png`\n');
    fprintf(fid, '- `panels/top10_incorrect.png`\n');

    fprintf(fid, '\n## Data Files\n\n');
    fprintf(fid, '- `classifier_forensic_audit.csv` — per-image predictions\n');
    fprintf(fid, '- `confusion_matrix.csv` — 5x5 matrix\n');
    fprintf(fid, '- `per_class_metrics.csv` — sensitivity/specificity/precision/F1\n');

    fclose(fid);
end
