function stats = runPhase4Classification(varargin)
% runPhase4Classification  Full Phase 4 DR classification pipeline
%
%   stats = runPhase4Classification()
%   stats = runPhase4Classification('verbose', true)

    p = inputParser;
    addParameter(p, 'verbose', true);
    parse(p, varargin{:});
    verbose = p.Results.verbose;

    cfg = classificationConfig();
    rng(cfg.seed);

    if verbose
        fprintf('=== Phase 4: DR Severity Classification ===\n');
        fprintf('Version: %s | Seed: %d\n', cfg.version, cfg.seed);
    end

    % 1. Prepare data
    if verbose, fprintf('\n--- Step 1: Prepare Data ---\n'); end
    [data, featureMatrix, labels, sampleMeta] = prepareClassificationData(cfg);

    XTrain = featureMatrix.train;
    YTrain = labels.train;
    XVal   = featureMatrix.val;
    YVal   = labels.val;
    XTest  = featureMatrix.test;
    YTest  = labels.test;

    if verbose
        fprintf('Train: %d samples, %d features\n', size(XTrain, 1), size(XTrain, 2));
        fprintf('Val:   %d samples\n', size(XVal, 1));
        fprintf('Test:  %d samples\n', size(XTest, 1));
    end

    % 2. Train five-class classifier
    if verbose, fprintf('\n--- Step 2: Train 5-Class Classifier ---\n'); end
    [drModel, drTrainInfo] = trainDRClassifier(XTrain, YTrain, XVal, YVal, cfg);

    % 3. Train referable-DR classifier
    if verbose, fprintf('\n--- Step 3: Train Referable DR Classifier ---\n'); end
    [refModel, refTrainInfo] = trainReferableClassifier(XTrain, YTrain, XVal, YVal, cfg);

    % 4. Predict on test set
    if verbose, fprintf('\n--- Step 4: Predict on Test Set ---\n'); end
    testImageIds = arrayfun(@(s) s.image_id, sampleMeta.test, 'UniformOutput', false);
    testDatasets = arrayfun(@(s) s.dataset, sampleMeta.test, 'UniformOutput', false);
    testResults = predictDRSeverity(drModel, refModel, XTest, ...
        testImageIds, testDatasets, drTrainInfo, refTrainInfo, cfg);

    % 5. Evaluate five-class
    if verbose, fprintf('\n--- Step 5: Evaluate 5-Class ---\n'); end
    YTestClass = testResults.predicted_grade;
    classScores = zeros(numel(YTest), cfg.nGrades);
    for g = 0:4
        classScores(:, g+1) = testResults.(sprintf('prob_level_%d', g));
    end
    drMetrics = evaluateDRClassifier(YTest, YTestClass, classScores, cfg);

    % 6. Evaluate referable DR
    if verbose, fprintf('\n--- Step 6: Evaluate Referable DR ---\n'); end
    refMetrics = evaluateReferableDR(YTest, testResults.referable_pred, ...
        testResults.referable_probability, cfg);

    % 7. Save predictions
    if verbose, fprintf('\n--- Step 7: Save Results ---\n'); end
    savePredictions(testResults, YTest, sampleMeta.test, cfg);

    % 8. Save metrics
    saveMetrics(drMetrics, refMetrics, drTrainInfo, refTrainInfo, cfg);

    % Summary
    stats = struct();
    stats.fiveClassAccuracy = drMetrics.accuracy;
    stats.fiveClassBalancedAccuracy = drMetrics.balancedAccuracy;
    stats.fiveClassMacroF1 = drMetrics.macroF1;
    stats.fiveClassMacroAUC = drMetrics.macroAUC;
    stats.referableSensitivity = refMetrics.sensitivity;
    stats.referableSpecificity = refMetrics.specificity;
    stats.referableAUC = refMetrics.auc;
    stats.nTrain = size(XTrain, 1);
    stats.nVal = size(XVal, 1);
    stats.nTest = size(XTest, 1);
    stats.targetSensitivityMet = refMetrics.sensitivity > 0.90;
    stats.targetSpecificityMet = refMetrics.specificity > 0.85;

    if verbose
        fprintf('\n=== PHASE 4 SUMMARY ===\n');
        fprintf('5-Class Accuracy: %.4f\n', drMetrics.accuracy);
        fprintf('5-Class Balanced Acc: %.4f\n', drMetrics.balancedAccuracy);
        fprintf('5-Class Macro F1: %.4f\n', drMetrics.macroF1);
        fprintf('5-Class Macro AUC: %.4f\n', drMetrics.macroAUC);
        fprintf('Referable Sensitivity: %.4f (target >0.90: %s)\n', ...
            refMetrics.sensitivity, bool2str(stats.targetSensitivityMet));
        fprintf('Referable Specificity: %.4f (target >0.85: %s)\n', ...
            refMetrics.specificity, bool2str(stats.targetSpecificityMet));
        fprintf('Referable AUC: %.4f\n', refMetrics.auc);
        fprintf('Results saved to: %s\n', cfg.paths.outputDir);
    end
end

function savePredictions(testResults, YTest, testMeta, cfg)
    nSamples = numel(YTest);
    imageIds = testResults.image_id;
    datasets = testResults.dataset;
    trueGrades = YTest(:);
    predGrades = testResults.predicted_grade(:);
    refTrue = double(trueGrades >= 2);
    refPred = testResults.referable_pred(:);
    refProb = testResults.referable_probability(:);
    confidence = testResults.confidence_score(:);
    
    nMeta = numel(testMeta);
    qualStatus = strings(nMeta, 1);
    qualScore = nan(nMeta, 1);
    for i = 1:nMeta
        qualStatus(i) = string(testMeta(i).quality_status);
        qualScore(i) = testMeta(i).quality_score;
    end
    classStatus = testResults.classification_status;

    % Ensure column vectors
    if size(predGrades, 1) == 1, predGrades = predGrades'; end
    if size(refPred, 1) == 1, refPred = refPred'; end
    if size(refProb, 1) == 1, refProb = refProb'; end
    if size(confidence, 1) == 1, confidence = confidence'; end

    p0 = testResults.prob_level_0(:);
    p1 = testResults.prob_level_1(:);
    p2 = testResults.prob_level_2(:);
    p3 = testResults.prob_level_3(:);
    p4 = testResults.prob_level_4(:);

    T = table(imageIds(:), datasets(:), trueGrades, predGrades, ...
        p0, p1, p2, p3, p4, ...
        refTrue(:), refPred, refProb, confidence, ...
        qualStatus, qualScore, classStatus(:), ...
        'VariableNames', {'image_id', 'dataset', 'true_grade', 'predicted_grade', ...
        'prob_level_0', 'prob_level_1', 'prob_level_2', 'prob_level_3', 'prob_level_4', ...
        'referable_true', 'referable_pred', 'referable_probability', 'confidence_score', ...
        'quality_status', 'quality_score', 'classification_status'});

    writetable(T, fullfile(cfg.paths.outputDir, cfg.output.predictions));
    fprintf('[savePredictions] %d predictions saved\n', nSamples);
end

function saveMetrics(drMetrics, refMetrics, drTrainInfo, refTrainInfo, cfg)
    % Confusion matrix CSV
    confMat = drMetrics.confusionMatrix;
    Tconf = array2table(confMat, 'VariableNames', arrayfun(@(g) sprintf('pred_%d', g), 0:4, 'UniformOutput', false), ...
        'RowNames', arrayfun(@(g) sprintf('true_%d', g), 0:4, 'UniformOutput', false));
    writetable(Tconf, fullfile(cfg.paths.outputDir, cfg.output.confusion), 'WriteRowNames', true);

    % Feature importance (placeholder - SVM doesn't provide direct importance)
    Tfeat = table(drTrainInfo.featureMedian(:), 'VariableNames', {'median_value'});
    writetable(Tfeat, fullfile(cfg.paths.outputDir, cfg.output.featureImp));

    % Metrics JSON
    metrics = struct();
    metrics.fiveClass = struct();
    metrics.fiveClass.accuracy = drMetrics.accuracy;
    metrics.fiveClass.balancedAccuracy = drMetrics.balancedAccuracy;
    metrics.fiveClass.macroSensitivity = drMetrics.macroSensitivity;
    metrics.fiveClass.macroPrecision = drMetrics.macroPrecision;
    metrics.fiveClass.macroF1 = drMetrics.macroF1;
    metrics.fiveClass.macroAUC = drMetrics.macroAUC;
    metrics.fiveClass.confusionMatrix = drMetrics.confusionMatrix;
    metrics.referable = struct();
    metrics.referable.sensitivity = refMetrics.sensitivity;
    metrics.referable.specificity = refMetrics.specificity;
    metrics.referable.precision = refMetrics.precision;
    metrics.referable.f1 = refMetrics.f1;
    metrics.referable.auc = refMetrics.auc;
    metrics.referable.prAUC = refMetrics.prAUC;
    metrics.config = struct('seed', 42, 'version', '4.0.0', ...
        'nTrain', drTrainInfo.nTrain, 'nVal', drTrainInfo.nVal);

    jsonStr = jsonencode(metrics, 'PrettyPrint', true);
    fid = fopen(fullfile(cfg.paths.outputDir, cfg.output.metrics), 'w');
    fwrite(fid, jsonStr, 'char');
    fclose(fid);

    % Referable metrics JSON
    refJson = struct('sensitivity', refMetrics.sensitivity, ...
        'specificity', refMetrics.specificity, ...
        'precision', refMetrics.precision, ...
        'f1', refMetrics.f1, ...
        'auc', refMetrics.auc, ...
        'prAUC', refMetrics.prAUC, ...
        'tp', refMetrics.tp, 'fn', refMetrics.fn, ...
        'fp', refMetrics.fp, 'tn', refMetrics.tn);
    jsonStr2 = jsonencode(refJson, 'PrettyPrint', true);
    fid = fopen(fullfile(cfg.paths.outputDir, cfg.output.referable), 'w');
    fwrite(fid, jsonStr2, 'char');
    fclose(fid);

    fprintf('[saveMetrics] Metrics saved\n');
end

function s = bool2str(b)
    if b, s = 'YES'; else, s = 'NO'; end
end
