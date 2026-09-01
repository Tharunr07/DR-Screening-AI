function importance = computeFeatureImportance(drModel, refModel, XTest, YTest, drTrainInfo, refTrainInfo, cfg)
% computeFeatureImportance  Permutation-based feature importance for SVM
%
%   importance = computeFeatureImportance(drModel, refModel, XTest, YTest, drTrainInfo, refTrainInfo, cfg)
%
%   For each of the 25 features, shuffles that feature across all test samples
%   and measures the drop in AUC. This is model-agnostic and does NOT require
%   a differentiable model.
%
%   Method: Permutation Feature Importance (NOT SHAP, NOT causal)

    if nargin < 7, cfg = explainabilityConfig(); end

    nFeatures = size(XTest, 2);
    featureNames = cfg.featureNames;
    nSamples = size(XTest, 1);

    % Handle NaN: replace with training medians
    featureMedian = drTrainInfo.featureMedian;
    XTestClean = XTest;
    for j = 1:nFeatures
        nanIdx = isnan(XTestClean(:, j));
        XTestClean(nanIdx, j) = featureMedian(j);
    end

    % Compute baseline referable AUC
    refMedian = refTrainInfo.featureMedian;
    XTestRef = XTestClean;
    for j = 1:nFeatures
        nanIdx = isnan(XTestRef(:, j));
        XTestRef(nanIdx, j) = refMedian(j);
    end
    [~, ~, refScores] = predict(refModel, XTestRef);
    refProbBaseline = refScores(:, 1);
    YTrueBin = double(YTest >= cfg.referable.threshold);
    [~, ~, ~, baselineAUC] = perfcurve(YTrueBin, refProbBaseline, 1);

    % Compute baseline five-class accuracy
    [YPredBaseline, ~, ~] = predict(drModel, XTestClean);
    baselineAccuracy = sum(YPredBaseline(:) == YTest(:)) / numel(YTest);

    fprintf('[computeFeatureImportance] Baseline: referable AUC=%.4f, accuracy=%.4f\n', baselineAUC, baselineAccuracy);

    % Permutation importance for each feature
    importance = struct();
    importance.feature_name = featureNames(:);
    importance.feature_index = (1:nFeatures)';
    importance.baseline_auc = repmat(baselineAUC, nFeatures, 1);
    importance.baseline_accuracy = repmat(baselineAccuracy, nFeatures, 1);
    importance.permuted_auc = nan(nFeatures, 1);
    importance.permuted_accuracy = nan(nFeatures, 1);
    importance.auc_drop = nan(nFeatures, 1);
    importance.accuracy_drop = nan(nFeatures, 1);
    importance.rank_auc = nan(nFeatures, 1);

    for j = 1:nFeatures
        % Create permuted test set: shuffle feature j
        rng(cfg.seed + j);  % deterministic per feature
        permIdx = randperm(nSamples);
        XPerm = XTestClean;
        XPerm(:, j) = XTestClean(permIdx, j);

        % Five-class prediction with permuted feature
        [YPredPerm, ~, ~] = predict(drModel, XPerm);
        permAccuracy = sum(YPredPerm(:) == YTest(:)) / numel(YTest);

        % Referable prediction with permuted feature
        XPermRef = XPerm;
        for k = 1:nFeatures
            nanIdx = isnan(XPermRef(:, k));
            XPermRef(nanIdx, k) = refMedian(k);
        end
        [~, ~, refScoresPerm] = predict(refModel, XPermRef);
        refProbPerm = refScoresPerm(:, 1);
        [~, ~, ~, permAUC] = perfcurve(YTrueBin, refProbPerm, 1);

        importance.permuted_auc(j) = permAUC;
        importance.permuted_accuracy(j) = permAccuracy;
        importance.auc_drop(j) = baselineAUC - permAUC;
        importance.accuracy_drop(j) = baselineAccuracy - permAccuracy;

        fprintf('  Feature %2d/%2d %-25s AUC drop: %+.4f  Acc drop: %+.4f\n', ...
            j, nFeatures, featureNames{j}, importance.auc_drop(j), importance.accuracy_drop(j));
    end

    % Rank by AUC drop (higher drop = more important)
    [~, sortIdx] = sort(importance.auc_drop, 'descend');
    importance.rank_auc(sortIdx) = (1:nFeatures)';

    % Save CSV
    T = table(importance.feature_name, importance.feature_index, ...
        importance.baseline_auc, importance.baseline_accuracy, ...
        importance.permuted_auc, importance.permuted_accuracy, ...
        importance.auc_drop, importance.accuracy_drop, importance.rank_auc, ...
        'VariableNames', {'feature_name', 'feature_index', ...
        'baseline_auc', 'baseline_accuracy', ...
        'permuted_auc', 'permuted_accuracy', ...
        'auc_drop', 'accuracy_drop', 'rank_auc'});
    writetable(T, fullfile(cfg.paths.outputDir, cfg.output.featureImportanceCSV));

    % Save JSON
    importanceJson = struct();
    importanceJson.method = 'Permutation Feature Importance';
    importanceJson.disclaimer = 'NOT causal importance. Measures feature contribution to SVM performance.';
    importanceJson.baseline_auc = baselineAUC;
    importanceJson.baseline_accuracy = baselineAccuracy;
    importanceJson.features = struct();
    for j = 1:nFeatures
        fname = featureNames{j};
        importanceJson.features.(fname) = struct( ...
            'index', j, ...
            'baseline_auc', baselineAUC, ...
            'permuted_auc', importance.permuted_auc(j), ...
            'auc_drop', importance.auc_drop(j), ...
            'baseline_accuracy', baselineAccuracy, ...
            'permuted_accuracy', importance.permuted_accuracy(j), ...
            'accuracy_drop', importance.accuracy_drop(j), ...
            'rank_auc', importance.rank_auc(j));
    end
    jsonStr = jsonencode(importanceJson, 'PrettyPrint', true);
    fid = fopen(fullfile(cfg.paths.outputDir, cfg.output.featureImportanceJSON), 'w');
    fwrite(fid, jsonStr, 'char');
    fclose(fid);

    fprintf('[computeFeatureImportance] Saved to %s\n', cfg.paths.outputDir);
end
