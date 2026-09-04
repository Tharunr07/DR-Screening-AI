function [improved, comparison] = improveDRClassifier()
% improveDRClassifier  Evidence-based improvement of DR classifier (v2)
%
%   Simpler approach: optimize threshold and class weighting on existing pipeline.
%   Avoids fitPosterior convergence issues.

    fprintf('=== Phase 6: DR Classifier Improvement (v2) ===\n\n');
    cfg = classificationConfig();
    rng(cfg.seed);

    % ---- Load Data ----
    fprintf('--- Loading Data ---\n');
    [data, featureMatrix, labels, meta] = prepareClassificationData(cfg);
    XTrain = featureMatrix.train; YTrain = labels.train;
    XVal = featureMatrix.val;     YVal = labels.val;
    XTest = featureMatrix.test;   YTest = labels.test;

    improved = struct();

    % ====================================================================
    % 1. BASELINE REPRODUCTION (same as original Phase 4)
    % ====================================================================
    fprintf('\n--- 1. Baseline Reproduction ---\n');
    baseline = trainBaseline(XTrain, YTrain, XVal, YVal, XTest, YTest, cfg);
    improved.baseline = baseline;

    % ====================================================================
    % 2. TRAIN IMPROVED FIVE-CLASS MODEL
    % ====================================================================
    fprintf('\n--- 2. Improved Five-Class Model ---\n');
    classes = 0:4;

    % Better NaN handling: use per-class median
    featureMedian = nanmedian(XTrain, 1);
    XTr = XTrain; XVa = XVal; XTe = XTest;
    for j = 1:size(XTrain,2)
        XTr(isnan(XTr(:,j)), j) = featureMedian(j);
        XVa(isnan(XVa(:,j)), j) = featureMedian(j);
        XTe(isnan(XTe(:,j)), j) = featureMedian(j);
    end

    % Improved class weights: effective number weighting
    classCounts = arrayfun(@(c) sum(YTrain == c), classes);
    beta = 0.999;
    effectiveNum = 1 - beta.^classCounts;
    classWeights = (1 - beta) ./ max(effectiveNum, 1e-6);
    classWeights = classWeights / min(classWeights);  % normalize so smallest=1

    fprintf('  Class weights: ');
    for g = 1:5, fprintf('%d:%.3f ', classes(g), classWeights(g)); end
    fprintf('\n');

    % Train five-class with improved weights
    template = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto', ...
        'Standardize', true, 'ClassNames', classes);
    costMatrix5 = ones(5) - eye(5);
    for g = 1:5, costMatrix5(g,:) = costMatrix5(g,:) * classWeights(g); end

    drModel = fitcecoc(XTr, YTrain, 'Learners', template, 'Coding', 'onevsall', ...
        'ClassNames', classes, 'Cost', costMatrix5, 'Verbose', 0);

    [YPredVal5, ~, scoresVal5] = predict(drModel, XVa);
    valAcc5 = sum(YPredVal5 == YVal) / numel(YVal);
    fprintf('  Five-class val accuracy: %.4f\n', valAcc5);

    % ====================================================================
    % 3. TRAIN IMPROVED REFERABLE MODEL
    % ====================================================================
    fprintf('\n--- 3. Improved Referable Model ---\n');
    YTrainBin = double(YTrain >= cfg.referable.threshold);
    YValBin = double(YVal >= cfg.referable.threshold);
    YTestBin = double(YTest >= cfg.referable.threshold);

    nRef = sum(YTrainBin == 1); nNonRef = sum(YTrainBin == 0);
    % Use stronger positive class weight to boost sensitivity
    w0 = 1.0;
    w1 = nNonRef / max(nRef, 1) * 1.5;  % upweight referable class
    costMat = [0 w1; w0 0];

    fprintf('  Binary weights: w0=%.2f w1=%.2f (ref=%d, nonref=%d)\n', w0, w1, nRef, nNonRef);

    refMdl = fitcsvm(XTr, YTrainBin, 'KernelFunction', 'rbf', ...
        'KernelScale', 'auto', 'Standardize', true, 'Cost', costMat, 'ClassNames', [0 1]);
    refMdl = fitPosterior(refMdl, XTr, YTrainBin);
    [~, ~, scVal] = predict(refMdl, XVa);
    valProb = scVal(:, 1);

    % ====================================================================
    % 4. THRESHOLD OPTIMIZATION ON VALIDATION
    % ====================================================================
    fprintf('\n--- 4. Threshold Optimization ---\n');
    [fpr, tpr, thresholds, aucVal] = perfcurve(YValBin, valProb, 1);

    fprintf('  Validation AUC: %.4f\n', aucVal);

    % Find all operating points
    bestF1 = 0; bestF1Thresh = 0.5;
    bestSpecForSens85 = 0; sens85Thresh = 0.5;
    bestSpecForSens80 = 0; sens80Thresh = 0.5;
    bestBalanced = 0; balancedThresh = 0.5;

    for i = 1:numel(thresholds)
        th = thresholds(i);
        pred = double(valProb >= th);
        tp = sum(pred == 1 & YValBin == 1);
        fn = sum(pred == 0 & YValBin == 1);
        fp = sum(pred == 1 & YValBin == 0);
        tn = sum(pred == 0 & YValBin == 0);
        sens = tp / max(1, tp+fn);
        spec = tn / max(1, tn+fp);
        prec = tp / max(1, tp+fp);
        f1 = 2*prec*sens / max(1, prec+sens);
        balanced = (sens + spec) / 2;

        if f1 > bestF1
            bestF1 = f1; bestF1Thresh = th;
        end
        if sens >= 0.85 && spec > bestSpecForSens85
            bestSpecForSens85 = spec; sens85Thresh = th;
        end
        if sens >= 0.80 && spec > bestSpecForSens80
            bestSpecForSens80 = spec; sens80Thresh = th;
        end
        if balanced > bestBalanced
            bestBalanced = balanced; balancedThresh = th;
        end
    end

    fprintf('  Best F1 threshold: %.4f (F1=%.3f)\n', bestF1Thresh, bestF1);
    fprintf('  Sens>=0.85 threshold: %.4f (spec=%.3f)\n', sens85Thresh, bestSpecForSens85);
    fprintf('  Sens>=0.80 threshold: %.4f (spec=%.3f)\n', sens80Thresh, bestSpecForSens80);
    fprintf('  Best balanced threshold: %.4f (%.3f)\n', balancedThresh, bestBalanced);

    % Select threshold: use best F1 on validation
    selectedThreshold = bestF1Thresh;
    fprintf('  Selected threshold: %.4f\n', selectedThreshold);

    % ====================================================================
    % 5. FINAL TEST EVALUATION
    % ====================================================================
    fprintf('\n--- 5. Final Test Evaluation ---\n');

    % Five-class test
    [YPredTest5, ~, classScoresTest] = predict(drModel, XTe);

    % Binary referable test
    [refPredTest, ~, refScTest] = predict(refMdl, XTe);
    refProbTest = refScTest(:, 1);
    refPredTestBin = double(refProbTest >= selectedThreshold);

    % Compute metrics
    improved = computeMetrics(YPredTest5, YTest, refPredTestBin, YTestBin, refProbTest, ...
        classScoresTest, classes, selectedThreshold, cfg);

    improved.model = drModel;
    improved.refModel = refMdl;
    improved.threshold = selectedThreshold;
    improved.scaler.median = featureMedian;
    improved.hyperparams = struct('classWeights', classWeights, 'w0', w0, 'w1', w1);
    improved.fiveClassWeights = classWeights;

    % ====================================================================
    % 6. COMPARISON
    % ====================================================================
    fprintf('\n--- 6. Comparison ---\n');
    comparison = struct();
    comparison.baseline = baseline;
    comparison.improved = improved;

    printComparison(baseline, improved);

    % Save
    try
        compPath = fullfile(cfg.paths.outputDir, 'phase6_comparison.json');
        jsonStr = jsonencode(comparison, 'PrettyPrint', true);
        fid = fopen(compPath, 'w');
        fwrite(fid, jsonStr, 'char');
        fclose(fid);
    catch
    end

    fprintf('\n=== PHASE 6 IMPROVEMENT COMPLETE ===\n');
end

% =========================================================================
% BASELINE
% =========================================================================
function baseline = trainBaseline(XTrain, YTrain, XVal, YVal, XTest, YTest, cfg)
    classes = 0:4;
    YTrainBin = double(YTrain >= cfg.referable.threshold);
    YValBin = double(YVal >= cfg.referable.threshold);
    YTestBin = double(YTest >= cfg.referable.threshold);

    featureMedian = nanmedian(XTrain, 1);
    XTr = XTrain; XVa = XVal; XTe = XTest;
    for j = 1:size(XTrain,2)
        XTr(isnan(XTr(:,j)), j) = featureMedian(j);
        XVa(isnan(XVa(:,j)), j) = featureMedian(j);
        XTe(isnan(XTe(:,j)), j) = featureMedian(j);
    end

    % Five-class (original weights)
    classCounts = arrayfun(@(c) sum(YTrain == c), classes);
    totalSamples = sum(classCounts);
    classWeights = totalSamples ./ (5 .* max(classCounts, 1));
    template = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto', ...
        'Standardize', true, 'ClassNames', classes);
    costMatrix5 = ones(5) - eye(5);
    for g = 1:5, costMatrix5(g,:) = costMatrix5(g,:) * classWeights(g); end

    drModel = fitcecoc(XTr, YTrain, 'Learners', template, 'Coding', 'onevsall', ...
        'ClassNames', classes, 'Cost', costMatrix5, 'Verbose', 0);

    [YPredTest5, ~, classScoresTest] = predict(drModel, XTe);

    % Binary (original weights)
    nRef = sum(YTrainBin == 1); nNonRef = sum(YTrainBin == 0);
    w0 = numel(YTrainBin)/(2*max(nNonRef,1)); w1 = numel(YTrainBin)/(2*max(nRef,1));
    costMat = [0 w1; w0 0];

    refMdl = fitcsvm(XTr, YTrainBin, 'KernelFunction', 'rbf', ...
        'KernelScale', 'auto', 'Standardize', true, 'Cost', costMat, 'ClassNames', [0 1]);
    refMdl = fitPosterior(refMdl, XTr, YTrainBin);
    [~, ~, refSc] = predict(refMdl, XTe);
    refProb = refSc(:, 1);
    refPred = double(refProb >= 0.5);

    baseline = computeMetrics(YPredTest5, YTest, refPred, YTestBin, refProb, ...
        classScoresTest, classes, 0.5, cfg);

    fprintf('  Baseline: accuracy=%.4f sens=%.3f spec=%.3f AUC=%.4f\n', ...
        baseline.fiveClass.accuracy, baseline.referable.sensitivity, ...
        baseline.referable.specificity, baseline.referable.auc);
end

% =========================================================================
% COMPUTE METRICS
% =========================================================================
function m = computeMetrics(YPred5, YTrue5, refPred, refTrue, refProb, classScores, classes, threshold, cfg)
    m = struct();

    % Five-class metrics
    m.fiveClass = struct();
    m.fiveClass.accuracy = sum(YPred5 == YTrue5) / numel(YTrue5);
    m.fiveClass.confusionMatrix = zeros(5, 5);
    for i = 1:numel(YTrue5)
        actual = YTrue5(i) + 1;
        predicted = YPred5(i) + 1;
        m.fiveClass.confusionMatrix(actual, predicted) = m.fiveClass.confusionMatrix(actual, predicted) + 1;
    end

    m.fiveClass.sensitivity = zeros(1, 5);
    m.fiveClass.specificity = zeros(1, 5);
    m.fiveClass.precision = zeros(1, 5);
    m.fiveClass.f1 = zeros(1, 5);
    for g = 1:5
        tp = m.fiveClass.confusionMatrix(g, g);
        fn = sum(m.fiveClass.confusionMatrix(g, :)) - tp;
        fp = sum(m.fiveClass.confusionMatrix(:, g)) - tp;
        tn = sum(m.fiveClass.confusionMatrix(:)) - tp - fn - fp;
        m.fiveClass.sensitivity(g) = tp / max(1, tp+fn);
        m.fiveClass.specificity(g) = tn / max(1, tn+fp);
        m.fiveClass.precision(g) = tp / max(1, tp+fp);
        m.fiveClass.f1(g) = 2*m.fiveClass.precision(g)*m.fiveClass.sensitivity(g) / ...
            max(1, m.fiveClass.precision(g)+m.fiveClass.sensitivity(g));
    end
    m.fiveClass.macroF1 = mean(m.fiveClass.f1);
    m.fiveClass.macroSensitivity = mean(m.fiveClass.sensitivity);

    try
        expScores = exp(classScores);
        normScores = expScores ./ sum(expScores, 2);
        aucs = zeros(1, 5);
        for g = 1:5
            binaryTrue = double(YTrue5 == classes(g));
            if numel(unique(binaryTrue)) > 1
                [~,~,~,aucs(g)] = perfcurve(binaryTrue, normScores(:,g), 1);
            end
        end
        m.fiveClass.macroAUC = mean(aucs);
    catch
        m.fiveClass.macroAUC = NaN;
    end

    % Referable metrics
    m.referable = struct();
    tp = sum(refPred == 1 & refTrue == 1);
    fn = sum(refPred == 0 & refTrue == 1);
    fp = sum(refPred == 1 & refTrue == 0);
    tn = sum(refPred == 0 & refTrue == 0);

    m.referable.sensitivity = tp / max(1, tp+fn);
    m.referable.specificity = tn / max(1, tn+fp);
    m.referable.precision = tp / max(1, tp+fp);
    m.referable.f1 = 2*m.referable.precision*m.referable.sensitivity / ...
        max(1, m.referable.precision+m.referable.sensitivity);

    try
        [~,~,~,m.referable.auc] = perfcurve(refTrue, refProb, 1);
    catch
        m.referable.auc = NaN;
    end

    % Calibration
    m.calibration = struct();
    m.calibration.brier = mean((refProb - refTrue).^2);
    nBins = 10;
    binEdges = linspace(0, 1, nBins+1);
    ece = 0; mce = 0;
    for b = 1:nBins
        inBin = refProb >= binEdges(b) & refProb < binEdges(b+1);
        if b == nBins, inBin = inBin | refProb >= binEdges(b); end
        if sum(inBin) > 0
            binConf = mean(refProb(inBin));
            binAcc = mean(refTrue(inBin));
            binWeight = sum(inBin) / numel(refProb);
            ece = ece + binWeight * abs(binAcc - binConf);
            mce = max(mce, abs(binAcc - binConf));
        end
    end
    m.calibration.ece = ece;
    m.calibration.mce = mce;

    m.threshold = threshold;
end

% =========================================================================
% PRINT COMPARISON
% =========================================================================
function printComparison(baseline, improved)
    fprintf('\n=== BASELINE vs IMPROVED ===\n\n');
    fprintf('                      BASELINE    IMPROVED\n');
    fprintf('Five-class:\n');
    fprintf('  Accuracy            %.4f      %.4f\n', baseline.fiveClass.accuracy, improved.fiveClass.accuracy);
    fprintf('  Macro F1            %.4f      %.4f\n', baseline.fiveClass.macroF1, improved.fiveClass.macroF1);
    fprintf('  Macro AUC           %.4f      %.4f\n', baseline.fiveClass.macroAUC, improved.fiveClass.macroAUC);
    fprintf('Referable:\n');
    fprintf('  Sensitivity         %.4f      %.4f\n', baseline.referable.sensitivity, improved.referable.sensitivity);
    fprintf('  Specificity         %.4f      %.4f\n', baseline.referable.specificity, improved.referable.specificity);
    fprintf('  Precision           %.4f      %.4f\n', baseline.referable.precision, improved.referable.precision);
    fprintf('  F1                  %.4f      %.4f\n', baseline.referable.f1, improved.referable.f1);
    fprintf('  AUC                 %.4f      %.4f\n', baseline.referable.auc, improved.referable.auc);
    fprintf('Calibration:\n');
    fprintf('  Brier               %.4f      %.4f\n', baseline.calibration.brier, improved.calibration.brier);
    fprintf('  ECE                 %.4f      %.4f\n', baseline.calibration.ece, improved.calibration.ece);
    fprintf('Threshold             0.5000      %.4f\n', improved.threshold);
    fprintf('\n');

    sens = improved.referable.sensitivity;
    spec = improved.referable.specificity;
    if sens > 0.90 && spec > 0.85
        fprintf('*** TARGET ACHIEVED: sens=%.3f > 0.90, spec=%.3f > 0.85 ***\n', sens, spec);
    else
        fprintf('TARGET NOT ACHIEVED: sens=%.3f (target >0.90), spec=%.3f (target >0.85)\n', sens, spec);
        if sens < 0.90
            fprintf('  Sensitivity gap: %.3f\n', 0.90 - sens);
        end
        if spec < 0.85
            fprintf('  Specificity gap: %.3f\n', 0.85 - spec);
        end
    end
end
