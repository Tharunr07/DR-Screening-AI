function audit = classificationAudit()
% classificationAudit  Comprehensive Phase 4 classifier audit
%
%   audit = classificationAudit()
%
%   Audits: features, class balance, scaling, thresholds, calibration,
%   ordinal performance, quality interaction, hyperparameters.
%   Uses TRAIN/VAL only. TEST is untouched until final evaluation.

    fprintf('=== Phase 6: DR Classification Audit ===\n\n');
    cfg = classificationConfig();
    rng(cfg.seed);

    % ---- Load Data ----
    fprintf('--- Loading Data ---\n');
    [data, featureMatrix, labels, meta] = prepareClassificationData(cfg);
    XTrain = featureMatrix.train; YTrain = labels.train;
    XVal = featureMatrix.val;     YVal = labels.val;
    XTest = featureMatrix.test;   YTest = labels.test;

    audit = struct();
    audit.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    % ====================================================================
    % 1. FEATURE AUDIT
    % ====================================================================
    fprintf('\n--- 1. Feature Audit ---\n');
    featureAudit = auditFeatures(XTrain, YTrain, XVal, YVal, XTest, YTest, cfg);
    audit.features = featureAudit;

    % ====================================================================
    % 2. CLASS IMBALANCE AUDIT
    % ====================================================================
    fprintf('\n--- 2. Class Imbalance Audit ---\n');
    imbalanceAudit = auditClassBalance(YTrain, YVal, YTest);
    audit.imbalance = imbalanceAudit;

    % ====================================================================
    % 3. FEATURE SCALING AUDIT
    % ====================================================================
    fprintf('\n--- 3. Feature Scaling Audit ---\n');
    scalingAudit = auditFeatureScaling(XTrain, YTrain, XVal, YVal, cfg);
    audit.scaling = scalingAudit;

    % ====================================================================
    % 4. SVM HYPERPARAMETER AUDIT
    % ====================================================================
    fprintf('\n--- 4. SVM Hyperparameter Audit ---\n');
    hyperAudit = auditHyperparameters(XTrain, YTrain, XVal, YVal, cfg);
    audit.hyperparameters = hyperAudit;

    % ====================================================================
    % 5. REFERABLE THRESHOLD AUDIT
    % ====================================================================
    fprintf('\n--- 5. Referable Threshold Audit ---\n');
    thresholdAudit = auditReferableThreshold(XTrain, YTrain, XVal, YVal, cfg);
    audit.threshold = thresholdAudit;

    % ====================================================================
    % 6. CALIBRATION AUDIT
    % ====================================================================
    fprintf('\n--- 6. Calibration Audit ---\n');
    calibrationAudit = auditCalibration(XTrain, YTrain, XVal, YVal, cfg);
    audit.calibration = calibrationAudit;

    % ====================================================================
    % 7. FIVE-CLASS CLASSIFICATION AUDIT
    % ====================================================================
    fprintf('\n--- 7. Five-Class Audit ---\n');
    fiveClassAudit = auditFiveClass(XTrain, YTrain, XVal, YVal, cfg);
    audit.fiveClass = fiveClassAudit;

    % ====================================================================
    % 8. ORDINAL ANALYSIS
    % ====================================================================
    fprintf('\n--- 8. Ordinal Analysis ---\n');
    ordinalAudit = auditOrdinal(XTrain, YTrain, XVal, YVal, cfg);
    audit.ordinal = ordinalAudit;

    % ====================================================================
    % 9. QUALITY INTERACTION AUDIT
    % ====================================================================
    fprintf('\n--- 9. Quality Interaction Audit ---\n');
    qualityAudit = auditQualityInteraction(XTrain, YTrain, XVal, YVal, meta.train, meta.val, cfg);
    audit.quality = qualityAudit;

    % ====================================================================
    % 10. PHASE 3 FEATURE DEPENDENCY AUDIT
    % ====================================================================
    fprintf('\n--- 10. Phase 3 Feature Dependency ---\n');
    p3Audit = auditPhase3Dependency(XTrain, YTrain, cfg);
    audit.phase3Dependency = p3Audit;

    % ====================================================================
    % SAVE AUDIT
    % ====================================================================
    auditPath = fullfile(cfg.paths.outputDir, 'classification_audit.json');
    try
        jsonStr = jsonencode(audit, 'PrettyPrint', true);
        fid = fopen(auditPath, 'w');
        fwrite(fid, jsonStr, 'char');
        fclose(fid);
        fprintf('\nAudit saved to: %s\n', auditPath);
    catch ME
        fprintf('Warning: Could not save audit JSON: %s\n', ME.message);
    end

    fprintf('\n=== AUDIT COMPLETE ===\n');
end

% =========================================================================
% FEATURE AUDIT
% =========================================================================
function fa = auditFeatures(XTrain, YTrain, XVal, YVal, XTest, YTest, cfg)
    [nTrain, nFeat] = size(XTrain);
    featureNames = getFeatureNames();

    fa = struct();
    fa.nFeatures = nFeat;
    fa.featureNames = featureNames;

    % Ranges
    fa.trainMin = min(XTrain, [], 1);
    fa.trainMax = max(XTrain, [], 1);
    fa.trainMean = nanmean(XTrain, 1);
    fa.trainStd = nanstd(XTrain, 0, 1);

    % NaN/Inf counts
    fa.trainNaN = sum(isnan(XTrain), 1);
    fa.valNaN = sum(isnan(XVal), 1);
    fa.testNaN = sum(isnan(XTest), 1);
    fa.trainInf = sum(isinf(XTrain), 1);

    % Zero variance
    fa.zeroVar = fa.trainStd < 1e-10;
    fa.nearZeroVar = fa.trainStd ./ max(abs(fa.trainMean), 1e-10) < 0.01;

    % Class-wise distributions
    classes = 0:4;
    fa.classMean = zeros(numel(classes), nFeat);
    fa.classStd = zeros(numel(classes), nFeat);
    for g = 1:numel(classes)
        idx = YTrain == classes(g);
        if sum(idx) > 1
            fa.classMean(g,:) = nanmean(XTrain(idx,:), 1);
            fa.classStd(g,:) = nanstd(XTrain(idx,:), 0, 1);
        end
    end

    % Feature variance ratio (max class mean / min class mean)
    fa.classSeparation = zeros(1, nFeat);
    for j = 1:nFeat
        classMeans = fa.classMean(:,j);
        validMeans = classMeans(classMeans ~= 0 & ~isnan(classMeans));
        if numel(validMeans) >= 2
            fa.classSeparation(j) = max(validMeans) / min(validMeans);
        end
    end

    % Correlation matrix
    fa.trainCorr = corrcoef(XTrain, 'rows', 'pairwise');

    % Print summary
    fprintf('  Features: %d\n', nFeat);
    fprintf('  NaN per feature (train): %s\n', mat2str(fa.trainNaN));
    fprintf('  Zero variance: %d\n', sum(fa.zeroVar));
    fprintf('  Near-zero variance: %d\n', sum(fa.nearZeroVar));
    fprintf('  Top separation: ');
    [~, sortIdx] = sort(fa.classSeparation, 'descend');
    for k = 1:min(5, nFeat)
        fprintf('%s(%.2f) ', featureNames{sortIdx(k)}, fa.classSeparation(sortIdx(k)));
    end
    fprintf('\n');
end

% =========================================================================
% CLASS BALANCE AUDIT
% =========================================================================
function ba = auditClassBalance(YTrain, YVal, YTest)
    classes = 0:4;
    ba = struct();
    ba.trainCounts = zeros(1, 5);
    ba.valCounts = zeros(1, 5);
    ba.testCounts = zeros(1, 5);
    ba.trainWeights = zeros(1, 5);

    for g = 1:5
        ba.trainCounts(g) = sum(YTrain == classes(g));
        ba.valCounts(g) = sum(YVal == classes(g));
        ba.testCounts(g) = sum(YTest == classes(g));
    end

    totalTrain = numel(YTrain);
    ba.trainProportions = ba.trainCounts / totalTrain;

    % Inverse frequency weights
    for g = 1:5
        ba.trainWeights(g) = totalTrain / (5 * max(ba.trainCounts(g), 1));
    end

    % Effective number of samples
    ba.effectiveNum = 1 / sum(ba.trainProportions.^2);

    fprintf('  Train: %s (n=%d)\n', mat2str(ba.trainCounts), totalTrain);
    fprintf('  Val:   %s (n=%d)\n', mat2str(ba.valCounts), numel(YVal));
    fprintf('  Test:  %s (n=%d)\n', mat2str(ba.testCounts), numel(YTest));
    fprintf('  Weights: ');
    for g = 1:5, fprintf('%d:%.3f ', classes(g), ba.trainWeights(g)); end
    fprintf('\n');
    fprintf('  Effective N: %.0f\n', ba.effectiveNum);
end

% =========================================================================
% FEATURE SCALING AUDIT
% =========================================================================
function sa = auditFeatureScaling(XTrain, YTrain, XVal, YVal, cfg)
    sa = struct();

    % Current: Standardize=true in SVM (internal standardization)
    % Test z-score from train
    trainMean = nanmean(XTrain, 1);
    trainStd = nanstd(XTrain, 0, 1);
    trainStd(trainStd < 1e-10) = 1;

    XTrainZ = (XTrain - trainMean) ./ trainStd;
    XValZ = (XVal - trainMean) ./ trainStd;

    % Handle NaN in scaled data
    XTrainZ(isnan(XTrainZ)) = 0;
    XValZ(isnan(XValZ)) = 0;

    % Test: robust scaling (median/IQR)
    trainMedian = nanmedian(XTrain, 1);
    trainIQR = iqr(XTrain, 1);
    trainIQR(trainIQR < 1e-10) = 1;
    XTrainR = (XTrain - trainMedian) ./ trainIQR;
    XValR = (XVal - trainMedian) ./ trainIQR;
    XTrainR(isnan(XTrainR)) = 0;
    XValR(isnan(XValR)) = 0;

    % Compare on referable task
    YTrainBin = double(YTrain >= cfg.referable.threshold);
    YValBin = double(YVal >= cfg.referable.threshold);

    % Z-score model
    rng(cfg.seed);
    nRef = sum(YTrainBin == 1); nNonRef = sum(YTrainBin == 0);
    w0 = numel(YTrainBin)/(2*max(nNonRef,1)); w1 = numel(YTrainBin)/(2*max(nRef,1));
    costMat = [0 w1; w0 0];

    try
        mdlZ = fitcsvm(XTrainZ, YTrainBin, 'KernelFunction', 'rbf', ...
            'KernelScale', 'auto', 'Standardize', false, 'Cost', costMat, 'ClassNames', [0 1]);
        mdlZ = fitPosterior(mdlZ, XTrainZ, YTrainBin);
        [~, ~, scZ] = predict(mdlZ, XValZ);
        refProbZ = scZ(:, 1);
        [~,~,~,aucZ] = perfcurve(YValBin, refProbZ, 1);
        sa.zscoreAUC = aucZ;
    catch
        sa.zscoreAUC = NaN;
    end

    % Robust model
    rng(cfg.seed);
    try
        mdlR = fitcsvm(XTrainR, YTrainBin, 'KernelFunction', 'rbf', ...
            'KernelScale', 'auto', 'Standardize', false, 'Cost', costMat, 'ClassNames', [0 1]);
        mdlR = fitPosterior(mdlR, XTrainR, YTrainBin);
        [~, ~, scR] = predict(mdlR, XValR);
        refProbR = scR(:, 1);
        [~,~,~,aucR] = perfcurve(YValBin, refProbR, 1);
        sa.robustAUC = aucR;
    catch
        sa.robustAUC = NaN;
    end

    sa.trainMean = trainMean;
    sa.trainStd = trainStd;
    sa.trainMedian = trainMedian;
    sa.trainIQR = trainIQR;

    fprintf('  Z-score AUC: %.4f\n', sa.zscoreAUC);
    fprintf('  Robust AUC: %.4f\n', sa.robustAUC);
end

% =========================================================================
% HYPERPARAMETER AUDIT
% =========================================================================
function ha = auditHyperparameters(XTrain, YTrain, XVal, YVal, cfg)
    ha = struct();

    YTrainBin = double(YTrain >= cfg.referable.threshold);
    YValBin = double(YVal >= cfg.referable.threshold);

    % NaN handling
    featureMedian = nanmedian(XTrain, 1);
    XTr = XTrain; XVa = XVal;
    for j = 1:size(XTrain,2)
        XTr(isnan(XTr(:,j)), j) = featureMedian(j);
        XVa(isnan(XVa(:,j)), j) = featureMedian(j);
    end

    nRef = sum(YTrainBin == 1); nNonRef = sum(YTrainBin == 0);
    w0 = numel(YTrainBin)/(2*max(nNonRef,1)); w1 = numel(YTrainBin)/(2*max(nRef,1));

    % Bounded search
    Cvals = [0.01, 0.1, 1, 10, 100];
    gammaVals = [0.001, 0.01, 0.1, 'auto'];
    weightSets = {[w0 w0], [w0*2 w0], [w0 w0*2]};

    bestAUC = 0;
    bestConfig = struct();
    results = {};

    fprintf('  Searching %d configs...\n', numel(Cvals)*numel(gammaVals)*numel(weightSets));

    for ci = 1:numel(Cvals)
        for gi = 1:numel(gammaVals)
            for wi = 1:numel(weightSets)
                try
                    rng(cfg.seed);
                    wSet = weightSets{wi};
                    costMat = [0 wSet(2); wSet(1) 0];

                    ks = gammaVals(gi);
                    if ischar(ks), ksStr = 'auto'; else, ksStr = ks; end

                    mdl = fitcsvm(XTr, YTrainBin, 'KernelFunction', 'rbf', ...
                        'KernelScale', ksStr, 'Standardize', true, ...
                        'Cost', costMat, 'BoxConstraint', Cvals(ci), 'ClassNames', [0 1]);
                    mdl = fitPosterior(mdl, XTr, YTrainBin);
                    [pred, ~, sc] = predict(mdl, XVa);
                    refProb = sc(:, 1);

                    tp = sum(pred == 1 & YValBin == 1);
                    fn = sum(pred == 0 & YValBin == 1);
                    fp = sum(pred == 1 & YValBin == 0);
                    tn = sum(pred == 0 & YValBin == 0);
                    sens = tp / max(1, tp+fn);
                    spec = tn / max(1, tn+fp);
                    [~,~,~,auc] = perfcurve(YValBin, refProb, 1);

                    res = struct('C', Cvals(ci), 'gamma', gammaVals(gi), ...
                        'w0', wSet(1), 'w1', wSet(2), ...
                        'sens', sens, 'spec', spec, 'auc', auc);
                    results{end+1} = res;

                    if auc > bestAUC
                        bestAUC = auc;
                        bestConfig = res;
                    end
                catch
                end
            end
        end
    end

    ha.results = results;
    ha.bestConfig = bestConfig;
    ha.bestAUC = bestAUC;

    fprintf('  Best: C=%.2f gamma=%.3f w0=%.2f w1=%.2f AUC=%.4f sens=%.3f spec=%.3f\n', ...
        bestConfig.C, bestConfig.gamma, bestConfig.w0, bestConfig.w1, ...
        bestConfig.auc, bestConfig.sens, bestConfig.spec);
end

% =========================================================================
% REFERABLE THRESHOLD AUDIT
% =========================================================================
function ta = auditReferableThreshold(XTrain, YTrain, XVal, YVal, cfg)
    ta = struct();

    YTrainBin = double(YTrain >= cfg.referable.threshold);
    YValBin = double(YVal >= cfg.referable.threshold);

    % Train baseline model
    rng(cfg.seed);
    featureMedian = nanmedian(XTrain, 1);
    XTr = XTrain; XVa = XVal;
    for j = 1:size(XTrain,2)
        XTr(isnan(XTr(:,j)), j) = featureMedian(j);
        XVa(isnan(XVa(:,j)), j) = featureMedian(j);
    end

    nRef = sum(YTrainBin == 1); nNonRef = sum(YTrainBin == 0);
    w0 = numel(YTrainBin)/(2*max(nNonRef,1)); w1 = numel(YTrainBin)/(2*max(nRef,1));
    costMat = [0 w1; w0 0];

    mdl = fitcsvm(XTr, YTrainBin, 'KernelFunction', 'rbf', ...
        'KernelScale', 'auto', 'Standardize', true, 'Cost', costMat, 'ClassNames', [0 1]);
    mdl = fitPosterior(mdl, XTr, YTrainBin);
    [~, ~, sc] = predict(mdl, XVa);
    refProb = sc(:, 1);

    % ROC curve
    [fpr, tpr, thresholds, aucVal] = perfcurve(YValBin, refProb, 1);

    ta.auc = aucVal;
    ta.fpr = fpr;
    ta.tpr = tpr;
    ta.thresholds = thresholds;

    % Sensitivity/specificity vs threshold
    nThresh = numel(thresholds);
    ta.sensVsThresh = zeros(nThresh, 1);
    ta.specVsThresh = zeros(nThresh, 1);
    ta.f1VsThresh = zeros(nThresh, 1);

    for i = 1:nThresh
        th = thresholds(i);
        pred = double(refProb >= th);
        tp = sum(pred == 1 & YValBin == 1);
        fn = sum(pred == 0 & YValBin == 1);
        fp = sum(pred == 1 & YValBin == 0);
        tn = sum(pred == 0 & YValBin == 0);
        ta.sensVsThresh(i) = tp / max(1, tp+fn);
        ta.specVsThresh(i) = tn / max(1, tn+fp);
        prec = tp / max(1, tp+fp);
        ta.f1VsThresh(i) = 2*prec*ta.sensVsThresh(i) / max(1, prec+ta.sensVsThresh(i));
    end

    % Find threshold satisfying sens>=0.90, max spec
    validIdx = find(ta.sensVsThresh >= 0.90);
    if ~isempty(validIdx)
        [~, bestSpecIdx] = max(ta.specVsThresh(validIdx));
        ta.targetThreshold = thresholds(validIdx(bestSpecIdx));
        ta.targetSens = ta.sensVsThresh(validIdx(bestSpecIdx));
        ta.targetSpec = ta.specVsThresh(validIdx(bestSpecIdx));
        ta.targetAchievable = true;
    else
        % Find threshold closest to sens=0.90
        [~, closestIdx] = min(abs(ta.sensVsThresh - 0.90));
        ta.targetThreshold = thresholds(closestIdx);
        ta.targetSens = ta.sensVsThresh(closestIdx);
        ta.targetSpec = ta.specVsThresh(closestIdx);
        ta.targetAchievable = false;
    end

    % Also find best F1 threshold
    [~, bestF1Idx] = max(ta.f1VsThresh);
    ta.bestF1Threshold = thresholds(bestF1Idx);
    ta.bestF1 = ta.f1VsThresh(bestF1Idx);
    ta.bestF1Sens = ta.sensVsThresh(bestF1Idx);
    ta.bestF1Spec = ta.specVsThresh(bestF1Idx);

    fprintf('  AUC: %.4f\n', ta.auc);
    fprintf('  Target achievable (sens>=0.90): %s\n', string(ta.targetAchievable));
    fprintf('  Target threshold: %.4f (sens=%.3f, spec=%.3f)\n', ...
        ta.targetThreshold, ta.targetSens, ta.targetSpec);
    fprintf('  Best F1 threshold: %.4f (F1=%.3f, sens=%.3f, spec=%.3f)\n', ...
        ta.bestF1Threshold, ta.bestF1, ta.bestF1Sens, ta.bestF1Spec);
end

% =========================================================================
% CALIBRATION AUDIT
% =========================================================================
function ca = auditCalibration(XTrain, YTrain, XVal, YVal, cfg)
    ca = struct();

    YTrainBin = double(YTrain >= cfg.referable.threshold);
    YValBin = double(YVal >= cfg.referable.threshold);

    rng(cfg.seed);
    featureMedian = nanmedian(XTrain, 1);
    XTr = XTrain; XVa = XVal;
    for j = 1:size(XTrain,2)
        XTr(isnan(XTr(:,j)), j) = featureMedian(j);
        XVa(isnan(XVa(:,j)), j) = featureMedian(j);
    end

    nRef = sum(YTrainBin == 1); nNonRef = sum(YTrainBin == 0);
    w0 = numel(YTrainBin)/(2*max(nNonRef,1)); w1 = numel(YTrainBin)/(2*max(nRef,1));
    costMat = [0 w1; w0 0];

    mdl = fitcsvm(XTr, YTrainBin, 'KernelFunction', 'rbf', ...
        'KernelScale', 'auto', 'Standardize', true, 'Cost', costMat, 'ClassNames', [0 1]);
    mdl = fitPosterior(mdl, XTr, YTrainBin);
    [~, ~, sc] = predict(mdl, XVa);
    rawProb = sc(:, 1);

    % Raw calibration
    [brierRaw, eceRaw, mceRaw] = computeCalibMetrics(rawProb, YValBin);
    ca.rawBrier = brierRaw;
    ca.rawECE = eceRaw;
    ca.rawMCE = mceRaw;

    % Platt scaling (fit on train, apply to val)
    mdlTrain = fitcsvm(XTr, YTrainBin, 'KernelFunction', 'rbf', ...
        'KernelScale', 'auto', 'Standardize', true, 'Cost', costMat, 'ClassNames', [0 1]);
    [~, ~, scTrain] = predict(mdlTrain, XTr);
    trainProb = scTrain(:, 1);

    % Platt: fit logistic on train scores
    try
        [plattA, plattB] = plattFit(trainProb, YTrainBin);
        plattProb = 1 ./ (1 + exp(plattA * rawProb + plattB));
        [brierPlatt, ecePlatt, mcePlatt] = computeCalibMetrics(plattProb, YValBin);
        ca.plattBrier = brierPlatt;
        ca.plattECE = ecePlatt;
        ca.plattMCE = mcePlatt;
        ca.plattA = plattA;
        ca.plattB = plattB;
    catch
        ca.plattBrier = NaN; ca.plattECE = NaN; ca.plattMCE = NaN;
    end

    % Isotonic regression (fit on train, apply to val)
    try
        % Sort train scores for isotonic
        [trainProbSorted, sortIdx] = sort(trainProb);
        trainLabelsSorted = YTrainBin(sortIdx);
        isoModel = fitIsotonic(trainProbSorted, trainLabelsSorted);
        isoProb = interp1(isoModel.x, isoModel.y, rawProb, 'linear', 'extrap');
        isoProb = max(0, min(1, isoProb));
        [brierIso, eceIso, mceIso] = computeCalibMetrics(isoProb, YValBin);
        ca.isoBrier = brierIso;
        ca.isoECE = eceIso;
        ca.isoMCE = mceIso;
    catch
        ca.isoBrier = NaN; ca.isoECE = NaN; ca.isoMCE = NaN;
    end

    fprintf('  Raw:     Brier=%.4f ECE=%.4f MCE=%.4f\n', ca.rawBrier, ca.rawECE, ca.rawMCE);
    fprintf('  Platt:   Brier=%.4f ECE=%.4f MCE=%.4f\n', ca.plattBrier, ca.plattECE, ca.plattMCE);
    fprintf('  Isotonic: Brier=%.4f ECE=%.4f MCE=%.4f\n', ca.isoBrier, ca.isoECE, ca.isoMCE);
end

% =========================================================================
% FIVE-CLASS AUDIT
% =========================================================================
function fca = auditFiveClass(XTrain, YTrain, XVal, YVal, cfg)
    fca = struct();

    rng(cfg.seed);
    featureMedian = nanmedian(XTrain, 1);
    XTr = XTrain; XVa = XVal;
    for j = 1:size(XTrain,2)
        XTr(isnan(XTr(:,j)), j) = featureMedian(j);
        XVa(isnan(XVa(:,j)), j) = featureMedian(j);
    end

    % Train model
    classes = 0:4;
    classCounts = arrayfun(@(c) sum(YTrain == c), classes);
    totalSamples = sum(classCounts);
    classWeights = totalSamples ./ (5 .* max(classCounts, 1));

    template = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto', ...
        'Standardize', true, 'ClassNames', classes);
    costMatrix = ones(5) - eye(5);
    for g = 1:5, costMatrix(g,:) = costMatrix(g,:) * classWeights(g); end

    mdl = fitcecoc(XTr, YTrain, 'Learners', template, 'Coding', 'onevsall', ...
        'ClassNames', classes, 'Cost', costMatrix, 'Verbose', 0);

    [YPred, ~, scores] = predict(mdl, XVa);

    % Confusion matrix
    fca.confusionMatrix = zeros(5, 5);
    for i = 1:numel(YVal)
        actual = YVal(i) + 1;
        predicted = YPred(i) + 1;
        fca.confusionMatrix(actual, predicted) = fca.confusionMatrix(actual, predicted) + 1;
    end

    % Per-class metrics
    fca.sensitivity = zeros(1, 5);
    fca.specificity = zeros(1, 5);
    fca.precision = zeros(1, 5);
    fca.f1 = zeros(1, 5);
    fca.support = zeros(1, 5);

    for g = 1:5
        tp = fca.confusionMatrix(g, g);
        fn = sum(fca.confusionMatrix(g, :)) - tp;
        fp = sum(fca.confusionMatrix(:, g)) - tp;
        tn = sum(fca.confusionMatrix(:)) - tp - fn - fp;
        fca.sensitivity(g) = tp / max(1, tp + fn);
        fca.specificity(g) = tn / max(1, tn + fp);
        fca.precision(g) = tp / max(1, tp + fp);
        fca.f1(g) = 2 * fca.precision(g) * fca.sensitivity(g) / max(1, fca.precision(g) + fca.sensitivity(g));
        fca.support(g) = sum(YVal == classes(g));
    end

    fca.accuracy = sum(YPred == YVal) / numel(YVal);
    fca.macroF1 = mean(fca.f1);
    fca.macroSensitivity = mean(fca.sensitivity);

    fprintf('  Accuracy: %.4f, Macro F1: %.4f\n', fca.accuracy, fca.macroF1);
    fprintf('  Per-class sens: ');
    for g = 1:5, fprintf('%d:%.3f ', classes(g), fca.sensitivity(g)); end
    fprintf('\n');
end

% =========================================================================
% ORDINAL ANALYSIS
% =========================================================================
function oa = auditOrdinal(XTrain, YTrain, XVal, YVal, cfg)
    oa = struct();

    rng(cfg.seed);
    featureMedian = nanmedian(XTrain, 1);
    XTr = XTrain; XVa = XVal;
    for j = 1:size(XTrain,2)
        XTr(isnan(XTr(:,j)), j) = featureMedian(j);
        XVa(isnan(XVa(:,j)), j) = featureMedian(j);
    end

    classes = 0:4;
    classCounts = arrayfun(@(c) sum(YTrain == c), classes);
    totalSamples = sum(classCounts);
    classWeights = totalSamples ./ (5 .* max(classCounts, 1));

    template = templateSVM('KernelFunction', 'rbf', 'KernelScale', 'auto', ...
        'Standardize', true, 'ClassNames', classes);
    costMatrix = ones(5) - eye(5);
    for g = 1:5, costMatrix(g,:) = costMatrix(g,:) * classWeights(g); end

    mdl = fitcecoc(XTr, YTrain, 'Learners', template, 'Coding', 'onevsall', ...
        'ClassNames', classes, 'Cost', costMatrix, 'Verbose', 0);

    [YPred, ~, ~] = predict(mdl, XVa);

    % Mean absolute error
    oa.mae = mean(abs(double(YPred) - double(YVal)));

    % Exact accuracy
    oa.exactAccuracy = sum(YPred == YVal) / numel(YVal);

    % ±1 accuracy
    oa.plusMinus1 = sum(abs(double(YPred) - double(YVal)) <= 1) / numel(YVal);

    % Severe under-grading (actual >= 2, predicted <= 1)
    severeUnder = sum(double(YVal) >= 2 & double(YPred) <= 1);
    totalReferable = sum(double(YVal) >= 2);
    oa.severeUnderGrading = severeUnder / max(1, totalReferable);
    oa.severeUnderCount = severeUnder;

    % Severe over-grading (actual <= 1, predicted >= 3)
    severeOver = sum(double(YVal) <= 1 & double(YPred) >= 3);
    totalNonRef = sum(double(YVal) <= 1);
    oa.severeOverGrading = severeOver / max(1, totalNonRef);
    oa.severeOverCount = severeOver;

    % Weighted confusion (penalize distant errors more)
    weightedErrors = 0;
    for i = 1:numel(YVal)
        err = abs(double(YPred(i)) - double(YVal(i)));
        weightedErrors = weightedErrors + err^2;
    end
    oa.weightedMSE = weightedErrors / numel(YVal);

    fprintf('  MAE: %.3f, Exact: %.3f, ±1: %.3f\n', oa.mae, oa.exactAccuracy, oa.plusMinus1);
    fprintf('  Severe under-grading: %d/%d (%.3f)\n', severeUnder, totalReferable, oa.severeUnderGrading);
    fprintf('  Severe over-grading: %d/%d (%.3f)\n', severeOver, totalNonRef, oa.severeOverGrading);
end

% =========================================================================
% QUALITY INTERACTION AUDIT
% =========================================================================
function qa = auditQualityInteraction(XTrain, YTrain, XVal, YVal, metaTrain, metaVal, cfg)
    qa = struct();

    YTrainBin = double(YTrain >= cfg.referable.threshold);
    YValBin = double(YVal >= cfg.referable.threshold);

    % Get quality status for val set
    valQuality = arrayfun(@(m) string(m.quality_status), metaVal);

    % Train model
    rng(cfg.seed);
    featureMedian = nanmedian(XTrain, 1);
    XTr = XTrain; XVa = XVal;
    for j = 1:size(XTrain,2)
        XTr(isnan(XTr(:,j)), j) = featureMedian(j);
        XVa(isnan(XVa(:,j)), j) = featureMedian(j);
    end

    nRef = sum(YTrainBin == 1); nNonRef = sum(YTrainBin == 0);
    w0 = numel(YTrainBin)/(2*max(nNonRef,1)); w1 = numel(YTrainBin)/(2*max(nRef,1));
    costMat = [0 w1; w0 0];

    mdl = fitcsvm(XTr, YTrainBin, 'KernelFunction', 'rbf', ...
        'KernelScale', 'auto', 'Standardize', true, 'Cost', costMat, 'ClassNames', [0 1]);
    mdl = fitPosterior(mdl, XTr, YTrainBin);
    [pred, ~, sc] = predict(mdl, XVa);
    refProb = sc(:, 1);

    % Per-quality-status metrics
    qualities = {'GOOD', 'BORDERLINE', 'UNGRADABLE'};
    qa.byQuality = struct();
    for q = 1:numel(qualities)
        qName = qualities{q};
        idx = valQuality == qName;
        if sum(idx) < 5, continue; end

        tp = sum(pred(idx) == 1 & YValBin(idx) == 1);
        fn = sum(pred(idx) == 0 & YValBin(idx) == 1);
        fp = sum(pred(idx) == 1 & YValBin(idx) == 0);
        tn = sum(pred(idx) == 0 & YValBin(idx) == 0);

        sens = tp / max(1, tp+fn);
        spec = tn / max(1, tn+fp);
        acc = (tp+tn) / max(1, tp+tn+fp+fn);

        qa.byQuality.(qName) = struct('n', sum(idx), 'sens', sens, 'spec', spec, 'acc', acc);

        fprintf('  %s (n=%d): sens=%.3f spec=%.3f acc=%.3f\n', qName, sum(idx), sens, spec, acc);
    end

    % Borderline false negative rate
    bnIdx = valQuality == 'BORDERLINE';
    bnRef = YValBin(bnIdx == 1);
    bnPred = pred(bnIdx == 1);
    if ~isempty(bnRef)
        qa.borderlineFN = sum(bnPred == 0 & bnRef == 1) / max(1, sum(bnRef == 1));
        fprintf('  Borderline FN rate: %.3f\n', qa.borderlineFN);
    end
end

% =========================================================================
% PHASE 3 DEPENDENCY AUDIT
% =========================================================================
function p3a = auditPhase3Dependency(XTrain, YTrain, cfg)
    p3a = struct();

    % Correlation of each feature with label
    featureNames = getFeatureNames();
    p3a.featureCorrWithLabel = zeros(1, size(XTrain, 2));
    for j = 1:size(XTrain, 2)
        valid = ~isnan(XTrain(:,j));
        if sum(valid) > 10
            p3a.featureCorrWithLabel(j) = corr(XTrain(valid,j), YTrain(valid));
        end
    end

    % Top features
    [~, sortIdx] = sort(abs(p3a.featureCorrWithLabel), 'descend');
    p3a.topFeatures = struct();
    for k = 1:min(10, numel(sortIdx))
        p3a.topFeatures.(sprintf('rank_%d', k)) = struct( ...
            'name', featureNames{sortIdx(k)}, ...
            'corr', p3a.featureCorrWithLabel(sortIdx(k)));
    end

    fprintf('  Top features by correlation with label:\n');
    for k = 1:min(5, numel(sortIdx))
        fprintf('    %s: %.4f\n', featureNames{sortIdx(k)}, p3a.featureCorrWithLabel(sortIdx(k)));
    end
end

% =========================================================================
% HELPERS
% =========================================================================
function names = getFeatureNames()
    names = {'quality_score', ...
        'retinal_area_fraction', 'fov_radius', ...
        'od_detected', 'od_radius', 'od_confidence', ...
        'fovea_detected', 'fovea_confidence', ...
        'vessel_area_fraction', 'vessel_density', ...
        'ma_count', 'ma_area', 'ma_confidence', ...
        'he_count', 'he_area', 'he_confidence', ...
        'ex_count', 'ex_area', 'ex_area_fraction', 'ex_confidence', ...
        'nv_present', 'nv_score', 'nv_confidence', ...
        'total_lesions', 'total_lesion_area'};
end

function [brier, ece, mce] = computeCalibMetrics(probs, labels)
    nBins = 10;
    binEdges = linspace(0, 1, nBins + 1);
    brier = mean((probs - labels).^2);

    ece = 0; mce = 0;
    for b = 1:nBins
        inBin = probs >= binEdges(b) & probs < binEdges(b+1);
        if b == nBins, inBin = inBin | probs >= binEdges(b); end
        if sum(inBin) > 0
            binConf = mean(probs(inBin));
            binAcc = mean(labels(inBin));
            binWeight = sum(inBin) / numel(probs);
            ece = ece + binWeight * abs(binAcc - binConf);
            mce = max(mce, abs(binAcc - binConf));
        end
    end
end

function [a, b] = plattFit(scores, labels)
    % Platt scaling: fit logistic regression
    % labels should be 0/1
    target = zeros(size(labels));
    target(labels == 1) = 1 - 0.01;  % avoid 0/1
    target(labels == 0) = 0.01;

    % Simple gradient descent
    a = 0; b = 0; lr = 0.01;
    for iter = 1:1000
        p = 1 ./ (1 + exp(a * scores + b));
        da = -sum((target - p) .* scores);
        db = -sum((target - p));
        a = a - lr * da / numel(scores);
        b = b - lr * db / numel(scores);
    end
end

function model = fitIsotonic(x, y)
    % Simple isotonic regression (PAV algorithm)
    n = numel(x);
    [x, idx] = sort(x);
    y = y(idx);

    % Block adjacent violators
    blocks = cell(n, 1);
    for i = 1:n
        blocks{i} = struct('x', x(i), 'y', y(i), 'n', 1);
    end

    changed = true;
    while changed
        changed = false;
        i = 1;
        while i < numel(blocks)
            if blocks{i}.y > blocks{i+1}.y
                % Merge blocks
                totalN = blocks{i}.n + blocks{i+1}.n;
                blocks{i}.y = (blocks{i}.y * blocks{i}.n + blocks{i+1}.y * blocks{i+1}.n) / totalN;
                blocks{i}.n = totalN;
                blocks{i+1} = [];
                blocks = blocks(~cellfun('isempty', blocks));
                changed = true;
            else
                i = i + 1;
            end
        end
    end

    model.x = zeros(numel(blocks), 1);
    model.y = zeros(numel(blocks), 1);
    for i = 1:numel(blocks)
        model.x(i) = blocks{i}.x;
        model.y(i) = blocks{i}.y;
    end
end
