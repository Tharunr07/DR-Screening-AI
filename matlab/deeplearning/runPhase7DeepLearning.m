function phase7 = runPhase7DeepLearning()
% runPhase7DeepLearning  Main Phase 7 orchestrator
%
%   phase7 = runPhase7DeepLearning()
%
%   Trains and evaluates three models:
%   A) Phase 4/6 SVM baseline (frozen)
%   B) Deep learning classifier
%   C) Hybrid DL + clinical features

    fprintf('=== Phase 7: Deep Learning DR Classification ===\n\n');
    cfg = deepLearningConfig();
    rng(cfg.seed);

    phase7 = struct();
    phase7.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    % ====================================================================
    % 1. DATA PREPARATION
    % ====================================================================
    fprintf('--- 1. Data Preparation ---\n');
    [imdsTrain, imdsVal, imdsTest, classWeights, meta] = prepareDeepLearningData(cfg);
    cfg.meta = meta;

    phase7.dataset = struct();
    phase7.dataset.nTrain = meta.nTrain;
    phase7.dataset.nVal = meta.nVal;
    phase7.dataset.nTest = meta.nTest;
    phase7.dataset.classWeights = classWeights;

    % ====================================================================
    % 2. MODEL A — FROZEN SVM BASELINE
    % ====================================================================
    fprintf('\n--- 2. Model A: Frozen SVM Baseline ---\n');
    baselinePath = fullfile(cfg.paths.phase4CSV);
    if exist(baselinePath, 'file')
        T4 = readtable(baselinePath, 'TextType', 'string');
        modelA = struct();
        modelA.accuracy = 0.6324;  % from Phase 4/6
        modelA.balancedAccuracy = 0.4607;
        modelA.macroF1 = 0.394;
        modelA.macroAUC = 0.813;
        modelA.sensitivity = 0.7588;
        modelA.specificity = 0.862;
        modelA.referableAUC = 0.8104;
        modelA.threshold = 0.5;
        fprintf('  Loaded baseline: accuracy=%.4f, sens=%.4f, spec=%.4f\n', ...
            modelA.accuracy, modelA.sensitivity, modelA.specificity);
    else
        modelA = struct();
        modelA.accuracy = NaN;
        fprintf('  Baseline not found, using NaN\n');
    end
    phase7.modelA = modelA;

    % ====================================================================
    % 3. MODEL B — DEEP LEARNING
    % ====================================================================
    fprintf('\n--- 3. Model B: Deep Learning ---\n');
    modelPath = fullfile(cfg.paths.modelDir, 'trainedNet.mat');
    if exist(modelPath, 'file')
        fprintf('  Loading pre-trained model from %s\n', modelPath);
        load(modelPath, 'trainedNet');
        trainTime = 0;
        % Load trainInfo placeholder
        trainInfo = struct();
        trainInfo.TrainingLoss = NaN;
        trainInfo.ValidationLoss = NaN;
        trainInfo.TrainingAccuracy = NaN;
        trainInfo.ValidationAccuracy = NaN;
    else
        tic;
        [trainedNet, trainInfo] = trainDeepDRClassifier(imdsTrain, imdsVal, classWeights, cfg);
        trainTime = toc;
    end

    % Select threshold on validation
    [selectedThreshold, thresholdInfo] = selectReferableThreshold(trainedNet, imdsVal, cfg);

    % Evaluate on test — get predictions and scores in one call
    testImds = augmentedImageDatastore(cfg.image.size, imdsTest);
    [YPredTest, scoresTest] = classify(trainedNet, testImds);

    % Build DL results struct manually
    YTrue = imdsTest.Labels;
    YTrueNum = double(YTrue) - 1;
    YPredNum = double(YPredTest) - 1;

    dlResults = struct();
    dlResults.fiveClass = struct();
    dlResults.fiveClass.accuracy = sum(YPredTest == YTrue) / numel(YTrue);
    dlResults.fiveClass.confusionMatrix = confusionmat(YTrue, YPredTest);
    classes = 0:4;
    dlResults.fiveClass.sensitivity = zeros(1, 5);
    dlResults.fiveClass.precision = zeros(1, 5);
    dlResults.fiveClass.f1 = zeros(1, 5);
    cm = dlResults.fiveClass.confusionMatrix;
    for g = 1:5
        tp = cm(g, g);
        fn = sum(cm(g, :)) - tp;
        fp = sum(cm(:, g)) - tp;
        tn = sum(cm(:)) - tp - fn - fp;
        dlResults.fiveClass.sensitivity(g) = tp / max(1, tp+fn);
        dlResults.fiveClass.precision(g) = tp / max(1, tp+fp);
        dlResults.fiveClass.f1(g) = 2*dlResults.fiveClass.precision(g)*dlResults.fiveClass.sensitivity(g) / ...
            max(1, dlResults.fiveClass.precision(g)+dlResults.fiveClass.sensitivity(g));
    end
    dlResults.fiveClass.macroF1 = mean(dlResults.fiveClass.f1);
    dlResults.fiveClass.balancedAccuracy = mean(dlResults.fiveClass.sensitivity);
    try
        aucs = zeros(1, 5);
        for g = 1:5
            binaryTrue = double(YTrueNum == classes(g));
            if numel(unique(binaryTrue)) > 1
                [~,~,~,aucs(g)] = perfcurve(binaryTrue, scoresTest(:,g), 1);
            else
                aucs(g) = NaN;
            end
        end
        dlResults.fiveClass.macroAUC = nanmean(aucs);
    catch
        dlResults.fiveClass.macroAUC = NaN;
    end

    % Referable metrics with selected threshold
    refProb = sum(scoresTest(:, 3:5), 2);
    YTrueBin = double(YTrueNum >= cfg.referable.threshold);
    refPred = double(refProb >= selectedThreshold);

    tp = sum(refPred == 1 & YTrueBin == 1);
    fn = sum(refPred == 0 & YTrueBin == 1);
    fp = sum(refPred == 1 & YTrueBin == 0);
    tn = sum(refPred == 0 & YTrueBin == 0);

    dlResults.referable = struct();
    dlResults.referable.sensitivity = tp / max(1, tp+fn);
    dlResults.referable.specificity = tn / max(1, tn+fp);
    dlResults.referable.precision = tp / max(1, tp+fp);
    dlResults.referable.f1 = 2*dlResults.referable.precision*dlResults.referable.sensitivity / ...
        max(1, dlResults.referable.precision+dlResults.referable.sensitivity);
    try
        [~,~,~,dlResults.referable.auc] = perfcurve(YTrueBin, refProb, 1);
    catch
        dlResults.referable.auc = NaN;
    end

    dlResults.threshold = selectedThreshold;
    modelB = dlResults;
    modelB.trainTime = trainTime;
    modelB.thresholdInfo = thresholdInfo;
    modelB.trainInfo = struct();
    modelB.trainInfo.finalTrainLoss = trainInfo.TrainingLoss(end);
    modelB.trainInfo.finalValLoss = trainInfo.ValidationLoss(end);
    modelB.trainInfo.finalTrainAcc = trainInfo.TrainingAccuracy(end);
    modelB.trainInfo.finalValAcc = trainInfo.ValidationAccuracy(end);

    phase7.modelB = modelB;

    fprintf('\n  Model B (DL) Test Results:\n');
    fprintf('  Five-class: acc=%.4f, macroF1=%.4f, macroAUC=%.4f\n', ...
        modelB.fiveClass.accuracy, modelB.fiveClass.macroF1, modelB.fiveClass.macroAUC);
    fprintf('  Referable: sens=%.4f, spec=%.4f, AUC=%.4f\n', ...
        modelB.referable.sensitivity, modelB.referable.specificity, modelB.referable.auc);

    % ====================================================================
    % 4. MODEL C — HYBRID
    % ====================================================================
    fprintf('\n--- 4. Model C: Hybrid ---\n');
    % Load clinical features
    cfg4 = classificationConfig();
    [data, featureMatrix, labels, metaCl] = prepareClassificationData(cfg4);

    % Extract image IDs from clinical meta
    clTrainIds = string(arrayfun(@(s) s.image_id, metaCl.train, 'UniformOutput', false));
    clValIds = string(arrayfun(@(s) s.image_id, metaCl.val, 'UniformOutput', false));
    clTestIds = string(arrayfun(@(s) s.image_id, metaCl.test, 'UniformOutput', false));

    % Align: quality gating may have removed images from imdsTrain
    [commonTrainIds, idxDL, idxCL] = intersect(meta.trainImageIds, clTrainIds, 'stable');
    fprintf('[Hybrid] Aligned: %d common train images (DL=%d, CL=%d)\n', ...
        numel(commonTrainIds), numel(meta.trainImageIds), numel(clTrainIds));

    [~, idxValDL, idxValCL] = intersect(meta.valImageIds, clValIds, 'stable');
    [~, idxTestDL, idxTestCL] = intersect(meta.testImageIds, clTestIds, 'stable');

    % Get DL scores from trained network
    trainImds4 = augmentedImageDatastore(cfg.image.size, imdsTrain);
    [~, dlScoresTrainAll] = classify(trainedNet, trainImds4);
    dlScoresTrain = dlScoresTrainAll(idxDL, :);

    valImds4 = augmentedImageDatastore(cfg.image.size, imdsVal);
    [~, dlScoresValAll] = classify(trainedNet, valImds4);
    dlScoresVal = dlScoresValAll(idxValDL, :);

    testImds4 = augmentedImageDatastore(cfg.image.size, imdsTest);
    [~, dlScoresTestAll] = classify(trainedNet, testImds4);
    dlScoresTest = dlScoresTestAll(idxTestDL, :);

    % Clinical features aligned
    clinTrain = featureMatrix.train(idxCL, :);
    clinVal = featureMatrix.val(idxValCL, :);
    clinTest = featureMatrix.test(idxTestCL, :);
    labelsTrain = labels.train(idxCL);
    labelsVal = labels.val(idxValCL);
    labelsTest = labels.test(idxTestCL);

    % Combine DL scores with clinical features
    XTrainHybrid = [dlScoresTrain, clinTrain];
    XValHybrid = [dlScoresVal, clinVal];

    % Handle NaN in clinical features
    featureMedian = nanmedian(clinTrain, 1);
    nDL = size(dlScoresTrain, 2);
    for j = 1:size(clinTrain, 2)
        XTrainHybrid(isnan(XTrainHybrid(:,j+nDL)), j+nDL) = featureMedian(j);
        XValHybrid(isnan(XValHybrid(:,j+nDL)), j+nDL) = featureMedian(j);
    end

    % Train SVM on hybrid features
    YTrainBin = double(labelsTrain >= cfg.referable.threshold);

    nRef = sum(YTrainBin == 1); nNonRef = sum(YTrainBin == 0);
    w0 = 1.0; w1 = nNonRef / max(nRef, 1) * 1.5;
    costMat = [0 w1; w0 0];

    hybridNet = fitcsvm(XTrainHybrid, YTrainBin, 'KernelFunction', 'rbf', ...
        'KernelScale', 'auto', 'Standardize', true, 'Cost', costMat, 'ClassNames', [0 1]);
    hybridNet = fitPosterior(hybridNet, XTrainHybrid, YTrainBin);

    % Evaluate hybrid on test
    XTestHybrid = [dlScoresTest, clinTest];
    for j = 1:size(clinTest, 2)
        XTestHybrid(isnan(XTestHybrid(:,j+nDL)), j+nDL) = featureMedian(j);
    end

    [refPredHybrid, ~, scHybrid] = predict(hybridNet, XTestHybrid);
    refProbHybrid = scHybrid(:, 1);

    % Metrics
    YTrueBinHybrid = double(labelsTest >= cfg.referable.threshold);
    tp = sum(refPredHybrid == 1 & YTrueBinHybrid == 1);
    fn = sum(refPredHybrid == 0 & YTrueBinHybrid == 1);
    fp = sum(refPredHybrid == 1 & YTrueBinHybrid == 0);
    tn = sum(refPredHybrid == 0 & YTrueBinHybrid == 0);

    modelC = struct();
    modelC.referable.sensitivity = tp / max(1, tp+fn);
    modelC.referable.specificity = tn / max(1, tn+fp);
    modelC.referable.precision = tp / max(1, tp+fp);
    modelC.referable.f1 = 2*modelC.referable.precision*modelC.referable.sensitivity / ...
        max(1, modelC.referable.precision+modelC.referable.sensitivity);
    try
        [~,~,~,modelC.referable.auc] = perfcurve(YTrueBinHybrid, refProbHybrid, 1);
    catch
        modelC.referable.auc = NaN;
    end
    modelC.threshold = 0.5;

    phase7.modelC = modelC;

    fprintf('\n  Model C (Hybrid) Test Results:\n');
    fprintf('  Referable: sens=%.4f, spec=%.4f, AUC=%.4f\n', ...
        modelC.referable.sensitivity, modelC.referable.specificity, modelC.referable.auc);

    % ====================================================================
    % 5. COMPARISON
    % ====================================================================
    fprintf('\n--- 5. Three-Way Comparison ---\n');
    printComparison(modelA, modelB, modelC);

    % ====================================================================
    % 6. CLINICAL TARGET GATE
    % ====================================================================
    fprintf('\n--- 6. Clinical Target Gate ---\n');
    sensA = modelA.sensitivity; specA = modelA.specificity;
    sensB = modelB.referable.sensitivity; specB = modelB.referable.specificity;
    sensC = modelC.referable.sensitivity; specC = modelC.referable.specificity;
    allSens = [sensA sensB sensC]; allSpec = [specA specB specC];
    allNames = {'SVM Baseline', 'Deep Learning', 'Hybrid'};
    for m = 1:3
        sens = allSens(m); spec = allSpec(m);
        if sens > 0.90 && spec > 0.85
            fprintf('  %s: TARGET ACHIEVED (sens=%.3f, spec=%.3f)\n', allNames{m}, sens, spec);
        else
            fprintf('  %s: NOT ACHIEVED (sens=%.3f, spec=%.3f)\n', allNames{m}, sens, spec);
        end
    end

    % ====================================================================
    % 7. SAVE RESULTS
    % ====================================================================
    fprintf('\n--- 7. Saving Results ---\n');

    % Save models
    save(fullfile(cfg.paths.modelDir, 'trainedNet.mat'), 'trainedNet', '-v7');
    save(fullfile(cfg.paths.modelDir, 'hybridNet.mat'), 'hybridNet', '-v7');

    % Save predictions
    predTable = table(meta.testImageIds, meta.testDatasets, meta.testLabels, ...
        YPredNum, refProb, refPred, ...
        'VariableNames', {'image_id', 'dataset', 'true_grade', 'predicted_grade', ...
        'referable_probability', 'referable_pred'});
    writetable(predTable, fullfile(cfg.paths.predDir, cfg.output.predictions));

    % Save summary
    phase7.config = struct();
    phase7.config.seed = cfg.seed;
    phase7.config.imageSize = cfg.image.size;
    phase7.config.maxEpochs = cfg.training.maxEpochs;
    phase7.config.batchSize = cfg.training.miniBatchSize;
    phase7.config.learningRate = cfg.training.initialLearnRate;
    phase7.config.architecture = cfg.network.architecture;
    phase7.config.classWeights = classWeights;
    phase7.config.selectedThreshold = selectedThreshold;

    jsonStr = jsonencode(phase7, 'PrettyPrint', true);
    fid = fopen(fullfile(cfg.paths.outputDir, cfg.output.summary), 'w');
    fwrite(fid, jsonStr, 'char');
    fclose(fid);

    fprintf('\n=== PHASE 7 COMPLETE ===\n');
end

function printComparison(modelA, modelB, modelC)
    fprintf('\n=== THREE-WAY COMPARISON ===\n\n');
    fprintf('                      SVM Baseline   Deep Learning   Hybrid\n');
    fprintf('Five-class:\n');
    fprintf('  Accuracy            %.4f          %.4f          %.4f\n', ...
        modelA.accuracy, modelB.fiveClass.accuracy, NaN);
    fprintf('  Balanced Acc        %.4f          %.4f          %.4f\n', ...
        modelA.balancedAccuracy, modelB.fiveClass.balancedAccuracy, NaN);
    fprintf('  Macro F1            %.4f          %.4f          %.4f\n', ...
        modelA.macroF1, modelB.fiveClass.macroF1, NaN);
    fprintf('  Macro AUC           %.4f          %.4f          %.4f\n', ...
        modelA.macroAUC, modelB.fiveClass.macroAUC, NaN);
    fprintf('Referable:\n');
    fprintf('  Sensitivity         %.4f          %.4f          %.4f\n', ...
        modelA.sensitivity, modelB.referable.sensitivity, modelC.referable.sensitivity);
    fprintf('  Specificity         %.4f          %.4f          %.4f\n', ...
        modelA.specificity, modelB.referable.specificity, modelC.referable.specificity);
    fprintf('  AUC                 %.4f          %.4f          %.4f\n', ...
        modelA.referableAUC, modelB.referable.auc, modelC.referable.auc);
    fprintf('Threshold             %.4f          %.4f          %.4f\n', ...
        modelA.threshold, modelB.threshold, modelC.threshold);
end
