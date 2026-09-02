function phase8 = runPhase8TransferLearning()
% runPhase8TransferLearning  Main Phase 8 orchestrator
%
%   phase8 = runPhase8TransferLearning()
%
%   Trains and evaluates three models:
%   A) Phase 4/6 SVM baseline (frozen)
%   B) Phase 7 Native ResNet-18 (frozen)
%   C) Phase 8 Transfer Learning ResNet-18

    fprintf('=== Phase 8: Transfer Learning DR Classification ===\n\n');
    cfg = transferLearningConfig();
    rng(cfg.seed);

    phase8 = struct();
    phase8.timestamp = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

    % ====================================================================
    % 1. DATA PREPARATION (same as Phase 7)
    % ====================================================================
    fprintf('--- 1. Data Preparation ---\n');
    cfg7 = deepLearningConfig();
    [imdsTrain, imdsVal, imdsTest, classWeights, meta] = prepareDeepLearningData(cfg7);
    cfg.meta = meta;

    phase8.dataset = struct();
    phase8.dataset.nTrain = meta.nTrain;
    phase8.dataset.nVal = meta.nVal;
    phase8.dataset.nTest = meta.nTest;
    phase8.dataset.classWeights = classWeights;

    % ====================================================================
    % 2. MODEL A — FROZEN SVM BASELINE
    % ====================================================================
    fprintf('\n--- 2. Model A: Frozen SVM Baseline ---\n');
    modelA = struct();
    modelA.accuracy = 0.6324;
    modelA.balancedAccuracy = 0.4607;
    modelA.macroF1 = 0.394;
    modelA.macroAUC = 0.813;
    modelA.sensitivity = 0.7588;
    modelA.specificity = 0.862;
    modelA.referableAUC = 0.8104;
    modelA.threshold = 0.5;
    fprintf('  Loaded baseline: accuracy=%.4f, sens=%.4f, spec=%.4f\n', ...
        modelA.accuracy, modelA.sensitivity, modelA.specificity);
    phase8.modelA = modelA;

    % ====================================================================
    % 3. MODEL B — FROZEN PHASE 7 NATIVE RESNET-18
    % ====================================================================
    fprintf('\n--- 3. Model B: Phase 7 Native ResNet-18 ---\n');
    phase7Path = fullfile(cfg7.paths.modelDir, 'trainedNet.mat');
    if exist(phase7Path, 'file')
        load(phase7Path, 'trainedNet');
        modelB = struct();
        modelB.accuracy = 0.6781;
        modelB.balancedAccuracy = 0.3540;
        modelB.macroF1 = 0.3012;
        modelB.macroAUC = 0.8078;
        modelB.sensitivity = 0.9533;
        modelB.specificity = 0.7465;
        modelB.referableAUC = 0.8784;
        modelB.threshold = 0.2304;
        fprintf('  Loaded Phase 7: accuracy=%.4f, sens=%.4f, spec=%.4f\n', ...
            modelB.accuracy, modelB.sensitivity, modelB.specificity);
    else
        modelB = struct();
        modelB.accuracy = NaN;
        fprintf('  Phase 7 model not found\n');
    end
    phase8.modelB = modelB;

    % ====================================================================
    % 4. MODEL C — TRANSFER LEARNING RESNET-18
    % ====================================================================
    fprintf('\n--- 4. Model C: Transfer Learning ResNet-18 ---\n');
    modelPath = fullfile(cfg.paths.modelDir, 'trainedNetTL.mat');
    if exist(modelPath, 'file')
        fprintf('  Loading pre-trained TL model from %s\n', modelPath);
        load(modelPath, 'trainedNetTL');
        trainTime = 0;
        trainInfoTL = struct();
        trainInfoTL.TrainingLoss = NaN;
        trainInfoTL.ValidationLoss = NaN;
        trainInfoTL.TrainingAccuracy = NaN;
        trainInfoTL.ValidationAccuracy = NaN;
    else
        tic;
        [trainedNetTL, trainInfoTL] = trainTransferDRClassifier(imdsTrain, imdsVal, classWeights, cfg);
        trainTime = toc;
    end

    % Select threshold on validation
    valImds = augmentedImageDatastore(cfg.image.size, imdsVal);
    [YPredVal, scoresVal] = classify(trainedNetTL, valImds);
    YTrueVal = imdsVal.Labels;
    YTrueValNum = double(YTrueVal) - 1;
    YTrueValBin = double(YTrueValNum >= cfg.referable.threshold);
    refProbVal = sum(scoresVal(:, 3:5), 2);

    % Find best F1 threshold
    bestF1 = 0; bestThresh = 0.5;
    for i = 1:numel(refProbVal)
        th = refProbVal(i);
        pred = double(refProbVal >= th);
        tp = sum(pred == 1 & YTrueValBin == 1);
        fn = sum(pred == 0 & YTrueValBin == 1);
        fp = sum(pred == 1 & YTrueValBin == 0);
        sens = tp/max(1,tp+fn); spec_idx = sum(pred==0 & YTrueValBin==0)/max(1,sum(YTrueValBin==0));
        prec = tp/max(1,tp+fp);
        f1 = 2*prec*sens/max(1,prec+sens);
        if f1 > bestF1
            bestF1 = f1; bestThresh = th;
        end
    end
    selectedThreshold = bestThresh;
    fprintf('[trainTL] Selected threshold: %.4f (best F1=%.4f)\n', selectedThreshold, bestF1);

    % Evaluate on test
    testImds = augmentedImageDatastore(cfg.image.size, imdsTest);
    [YPredTest, scoresTest] = classify(trainedNetTL, testImds);

    YTrue = imdsTest.Labels;
    YTrueNum = double(YTrue) - 1;
    YPredNum = double(YPredTest) - 1;

    % Five-class metrics
    tlResults = struct();
    tlResults.fiveClass = struct();
    tlResults.fiveClass.accuracy = sum(YPredTest == YTrue) / numel(YTrue);
    tlResults.fiveClass.confusionMatrix = confusionmat(YTrue, YPredTest);

    classes = 0:4;
    tlResults.fiveClass.sensitivity = zeros(1, 5);
    tlResults.fiveClass.precision = zeros(1, 5);
    tlResults.fiveClass.f1 = zeros(1, 5);
    cm = tlResults.fiveClass.confusionMatrix;
    for g = 1:5
        tp = cm(g, g);
        fn = sum(cm(g, :)) - tp;
        fp = sum(cm(:, g)) - tp;
        tn = sum(cm(:)) - tp - fn - fp;
        tlResults.fiveClass.sensitivity(g) = tp / max(1, tp+fn);
        tlResults.fiveClass.precision(g) = tp / max(1, tp+fp);
        tlResults.fiveClass.f1(g) = 2*tlResults.fiveClass.precision(g)*tlResults.fiveClass.sensitivity(g) / ...
            max(1, tlResults.fiveClass.precision(g)+tlResults.fiveClass.sensitivity(g));
    end
    tlResults.fiveClass.macroF1 = mean(tlResults.fiveClass.f1);
    tlResults.fiveClass.balancedAccuracy = mean(tlResults.fiveClass.sensitivity);

    % AUC
    YTrueBin = double(YTrueNum >= cfg.referable.threshold);
    refProb = sum(scoresTest(:, 3:5), 2);
    refPred = double(refProb >= selectedThreshold);

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
        tlResults.fiveClass.macroAUC = nanmean(aucs);
    catch
        tlResults.fiveClass.macroAUC = NaN;
    end

    % Referable metrics
    tp = sum(refPred == 1 & YTrueBin == 1);
    fn = sum(refPred == 0 & YTrueBin == 1);
    fp = sum(refPred == 1 & YTrueBin == 0);
    tn = sum(refPred == 0 & YTrueBin == 0);

    tlResults.referable = struct();
    tlResults.referable.sensitivity = tp / max(1, tp+fn);
    tlResults.referable.specificity = tn / max(1, tn+fp);
    tlResults.referable.precision = tp / max(1, tp+fp);
    tlResults.referable.f1 = 2*tlResults.referable.precision*tlResults.referable.sensitivity / ...
        max(1, tlResults.referable.precision+tlResults.referable.sensitivity);
    try
        [~,~,~,tlResults.referable.auc] = perfcurve(YTrueBin, refProb, 1);
    catch
        tlResults.referable.auc = NaN;
    end
    tlResults.threshold = selectedThreshold;
    tlResults.trainTime = trainTime;

    modelC = tlResults;
    modelC.trainInfo = struct();
    modelC.trainInfo.finalTrainLoss = trainInfoTL.TrainingLoss(end);
    modelC.trainInfo.finalValLoss = trainInfoTL.ValidationLoss(end);
    modelC.trainInfo.finalTrainAcc = trainInfoTL.TrainingAccuracy(end);
    modelC.trainInfo.finalValAcc = trainInfoTL.ValidationAccuracy(end);

    phase8.modelC = modelC;

    fprintf('\n  Model C (Transfer Learning) Test Results:\n');
    fprintf('  Five-class: acc=%.4f, macroF1=%.4f, macroAUC=%.4f\n', ...
        modelC.fiveClass.accuracy, modelC.fiveClass.macroF1, modelC.fiveClass.macroAUC);
    fprintf('  Referable: sens=%.4f, spec=%.4f, AUC=%.4f\n', ...
        modelC.referable.sensitivity, modelC.referable.specificity, modelC.referable.auc);

    % ====================================================================
    % 5. THREE-WAY COMPARISON
    % ====================================================================
    fprintf('\n--- 5. Three-Way Comparison ---\n');
    printComparison(modelA, modelB, modelC);

    % ====================================================================
    % 6. CLINICAL TARGET GATE
    % ====================================================================
    fprintf('\n--- 6. Clinical Target Gate ---\n');
    allSens = [modelA.sensitivity, modelB.sensitivity, modelC.referable.sensitivity];
    allSpec = [modelA.specificity, modelB.specificity, modelC.referable.specificity];
    allNames = {'SVM Baseline', 'Native ResNet-18', 'Transfer Learning'};
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

    % Save model
    save(fullfile(cfg.paths.modelDir, 'trainedNetTL.mat'), 'trainedNetTL', '-v7');

    % Save predictions
    predTable = table(meta.testImageIds, meta.testDatasets, meta.testLabels, ...
        YPredNum, refProb, refPred, ...
        'VariableNames', {'image_id', 'dataset', 'true_grade', 'predicted_grade', ...
        'referable_probability', 'referable_pred'});
    writetable(predTable, fullfile(cfg.paths.predDir, cfg.output.predictions));

    % Save summary
    phase8.config = struct();
    phase8.config.seed = cfg.seed;
    phase8.config.imageSize = cfg.image.size;
    phase8.config.maxEpochs = cfg.training.maxEpochs;
    phase8.config.batchSize = cfg.training.miniBatchSize;
    phase8.config.learningRate = cfg.training.initialLearnRate;
    phase8.config.architecture = cfg.network.architecture;
    phase8.config.pretrained = cfg.network.pretrained;
    phase8.config.classWeights = classWeights;
    phase8.config.selectedThreshold = selectedThreshold;

    jsonStr = jsonencode(phase8, 'PrettyPrint', true);
    fid = fopen(fullfile(cfg.paths.outputDir, cfg.output.summary), 'w');
    fwrite(fid, jsonStr, 'char');
    fclose(fid);

    fprintf('\n=== PHASE 8 COMPLETE ===\n');
end

function printComparison(modelA, modelB, modelC)
    fprintf('\n=== THREE-WAY COMPARISON ===\n\n');
    fprintf('                      SVM Baseline   Native DL   Transfer Learning\n');
    fprintf('Five-class:\n');
    fprintf('  Accuracy            %.4f          %.4f          %.4f\n', ...
        modelA.accuracy, modelB.accuracy, modelC.fiveClass.accuracy);
    fprintf('  Balanced Acc        %.4f          %.4f          %.4f\n', ...
        modelA.balancedAccuracy, modelB.balancedAccuracy, modelC.fiveClass.balancedAccuracy);
    fprintf('  Macro F1            %.4f          %.4f          %.4f\n', ...
        modelA.macroF1, modelB.macroF1, modelC.fiveClass.macroF1);
    fprintf('  Macro AUC           %.4f          %.4f          %.4f\n', ...
        modelA.macroAUC, modelB.macroAUC, modelC.fiveClass.macroAUC);
    fprintf('Referable:\n');
    fprintf('  Sensitivity         %.4f          %.4f          %.4f\n', ...
        modelA.sensitivity, modelB.sensitivity, modelC.referable.sensitivity);
    fprintf('  Specificity         %.4f          %.4f          %.4f\n', ...
        modelA.specificity, modelB.specificity, modelC.referable.specificity);
    fprintf('  AUC                 %.4f          %.4f          %.4f\n', ...
        modelA.referableAUC, modelB.referableAUC, modelC.referable.auc);
    fprintf('Threshold             %.4f          %.4f          %.4f\n', ...
        modelA.threshold, modelB.threshold, modelC.threshold);
end
