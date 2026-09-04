function results = evaluateDeepLearning(trainedNet, imdsTest, cfg)
% evaluateDeepLearning  Evaluate deep learning model on test set
%
%   results = evaluateDeepLearning(trainedNet, imdsTest, cfg)

    if nargin < 3, cfg = deepLearningConfig(); end

    fprintf('[evalDL] Evaluating on test set\n');

    % Get predictions
    testImds = augmentedImageDatastore(cfg.image.size, imdsTest);
    [YPred, scores] = classify(trainedNet, testImds);

    % Get true labels
    YTrue = imdsTest.Labels;

    % Convert to numeric
    YPredNum = double(YPred) - 1;
    YTrueNum = double(YTrue) - 1;

    results = struct();

    % Five-class metrics
    results.fiveClass = struct();
    results.fiveClass.accuracy = sum(YPred == YTrue) / numel(YTrue);
    results.fiveClass.confusionMatrix = confusionmat(YTrue, YPred);

    % Per-class metrics
    classes = 0:4;
    results.fiveClass.sensitivity = zeros(1, 5);
    results.fiveClass.specificity = zeros(1, 5);
    results.fiveClass.precision = zeros(1, 5);
    results.fiveClass.f1 = zeros(1, 5);

    cm = results.fiveClass.confusionMatrix;
    for g = 1:5
        tp = cm(g, g);
        fn = sum(cm(g, :)) - tp;
        fp = sum(cm(:, g)) - tp;
        tn = sum(cm(:)) - tp - fn - fp;
        results.fiveClass.sensitivity(g) = tp / max(1, tp+fn);
        results.fiveClass.specificity(g) = tn / max(1, tn+fp);
        results.fiveClass.precision(g) = tp / max(1, tp+fp);
        results.fiveClass.f1(g) = 2*results.fiveClass.precision(g)*results.fiveClass.sensitivity(g) / ...
            max(1, results.fiveClass.precision(g)+results.fiveClass.sensitivity(g));
    end
    results.fiveClass.macroF1 = mean(results.fiveClass.f1);
    results.fiveClass.macroSensitivity = mean(results.fiveClass.sensitivity);

    % Balanced accuracy
    results.fiveClass.balancedAccuracy = mean(results.fiveClass.sensitivity);

    % AUC
    try
        scoresArray = scores;
        aucs = zeros(1, 5);
        for g = 1:5
            binaryTrue = double(YTrue == classes(g));
            if numel(unique(binaryTrue)) > 1
                [~,~,~,aucs(g)] = perfcurve(binaryTrue, scoresArray(:,g), 1);
            end
        end
        results.fiveClass.macroAUC = mean(aucs);
        results.fiveClass.perClassAUC = aucs;
    catch
        results.fiveClass.macroAUC = NaN;
    end

    % Referable metrics
    YTrueBin = double(YTrueNum >= cfg.referable.threshold);
    YPredBin = double(YPredNum >= cfg.referable.threshold);

    % Probability of referable = sum of probabilities for grades 2,3,4
    refProb = sum(scores(:, 3:5), 2);

    results.referable = struct();
    tp = sum(YPredBin == 1 & YTrueBin == 1);
    fn = sum(YPredBin == 0 & YTrueBin == 1);
    fp = sum(YPredBin == 1 & YTrueBin == 0);
    tn = sum(YPredBin == 0 & YTrueBin == 0);

    results.referable.sensitivity = tp / max(1, tp+fn);
    results.referable.specificity = tn / max(1, tn+fp);
    results.referable.precision = tp / max(1, tp+fp);
    results.referable.f1 = 2*results.referable.precision*results.referable.sensitivity / ...
        max(1, results.referable.precision+results.referable.sensitivity);

    try
        [~,~,~,results.referable.auc] = perfcurve(YTrueBin, refProb, 1);
    catch
        results.referable.auc = NaN;
    end

    % Calibration
    results.calibration = struct();
    results.calibration.brier = mean((refProb - YTrueBin).^2);
    nBins = 10;
    binEdges = linspace(0, 1, nBins+1);
    ece = 0; mce = 0;
    for b = 1:nBins
        inBin = refProb >= binEdges(b) & refProb < binEdges(b+1);
        if b == nBins, inBin = inBin | refProb >= binEdges(b); end
        if sum(inBin) > 0
            binConf = mean(refProb(inBin));
            binAcc = mean(YTrueBin(inBin));
            binWeight = sum(inBin) / numel(refProb);
            ece = ece + binWeight * abs(binAcc - binConf);
            mce = max(mce, abs(binAcc - binConf));
        end
    end
    results.calibration.ece = ece;
    results.calibration.mce = mce;

    % Ordinal metrics
    results.ordinal = struct();
    results.ordinal.mae = mean(abs(YPredNum - YTrueNum));
    results.ordinal.exactAccuracy = sum(YPredNum == YTrueNum) / numel(YTrueNum);
    results.ordinal.plusMinus1 = sum(abs(YPredNum - YTrueNum) <= 1) / numel(YTrueNum);
    results.ordinal.severeUnderGrading = sum(YTrueNum >= 2 & YPredNum <= 1) / max(1, sum(YTrueNum >= 2));
    results.ordinal.severeOverGrading = sum(YTrueNum <= 1 & YPredNum >= 3) / max(1, sum(YTrueNum <= 1));

    % Store predictions
    results.predictions = YPredNum;
    results.trueLabels = YTrueNum;
    results.probabilities = scores;
    results.refProb = refProb;

    fprintf('[evalDL] Five-class: acc=%.4f, macroF1=%.4f, macroAUC=%.4f\n', ...
        results.fiveClass.accuracy, results.fiveClass.macroF1, results.fiveClass.macroAUC);
    fprintf('[evalDL] Referable: sens=%.4f, spec=%.4f, AUC=%.4f\n', ...
        results.referable.sensitivity, results.referable.specificity, results.referable.auc);
    fprintf('[evalDL] Ordinal: MAE=%.3f, ±1=%.3f, severeUnder=%.3f\n', ...
        results.ordinal.mae, results.ordinal.plusMinus1, results.ordinal.severeUnderGrading);
end
