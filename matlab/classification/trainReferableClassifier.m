function [model, trainInfo] = trainReferableClassifier(XTrain, YTrain, XVal, YVal, cfg)
% trainReferableClassifier  Train binary referable-DR classifier
%
%   [model, trainInfo] = trainReferableClassifier(XTrain, YTrain, XVal, YVal, cfg)
%
%   Converts 5-class labels to binary: 0=non-referable (grade 0,1), 1=referable (grade 2,3,4)
%   Trains SVM with RBF kernel.

    if nargin < 5, cfg = classificationConfig(); end
    rng(cfg.seed);

    % Convert to binary labels
    YTrainBin = double(YTrain >= cfg.referable.threshold);
    YValBin = double(YVal >= cfg.referable.threshold);

    fprintf('[trainReferableClassifier] Training on %d samples (%d referable, %d non-referable)\n', ...
        numel(YTrainBin), sum(YTrainBin == 1), sum(YTrainBin == 0));

    % Handle NaN features
    featureMedian = nanmedian(XTrain, 1);
    for j = 1:size(XTrain, 2)
        nanIdx = isnan(XTrain(:, j));
        XTrain(nanIdx, j) = featureMedian(j);
    end
    XValClean = XVal;
    for j = 1:size(XVal, 2)
        nanIdx = isnan(XVal(:, j));
        XValClean(nanIdx, j) = featureMedian(j);
    end

    % Class weights for imbalance
    nRef = sum(YTrainBin == 1);
    nNonRef = sum(YTrainBin == 0);
    totalSamples = numel(YTrainBin);
    w0 = totalSamples / (2 * max(nNonRef, 1));
    w1 = totalSamples / (2 * max(nRef, 1));

    costMatrix = [0 w1; w0 0];

    model = fitcsvm(XTrain, YTrainBin, ...
        'KernelFunction', 'rbf', ...
        'Standardize', true, ...
        'Cost', costMatrix, ...
        'ClassNames', [0 1]);

    % Enable probability estimates
    model = fitPosterior(model, XTrain, YTrainBin);

    % Validate
    [YPredVal, ~, scoresVal] = predict(model, XValClean);

    % Metrics
    tp = sum(YPredVal == 1 & YValBin == 1);
    fn = sum(YPredVal == 0 & YValBin == 1);
    fp = sum(YPredVal == 1 & YValBin == 0);
    tn = sum(YPredVal == 0 & YValBin == 0);

    sensitivity = tp / max(1, tp + fn);
    specificity = tn / max(1, tn + fp);
    precision   = tp / max(1, tp + fp);
    npv         = tn / max(1, tn + fn);
    f1          = 2 * precision * sensitivity / max(1, precision + sensitivity);
    accuracy    = (tp + tn) / max(1, tp + tn + fp + fn);

    % ROC-AUC
    refProb = scoresVal(:, 2);
    [fpr, tpr, ~, aucVal] = perfcurve(YValBin, refProb, 1);

    trainInfo = struct();
    trainInfo.valAccuracy = accuracy;
    trainInfo.valSensitivity = sensitivity;
    trainInfo.valSpecificity = specificity;
    trainInfo.valPrecision = precision;
    trainInfo.valNPV = npv;
    trainInfo.valF1 = f1;
    trainInfo.valAUC = aucVal;
    trainInfo.featureMedian = featureMedian;
    trainInfo.nTrain = numel(YTrainBin);
    trainInfo.nVal = numel(YValBin);
    trainInfo.weights = [w0, w1];

    fprintf('[trainReferableClassifier] Validation: acc=%.4f sens=%.4f spec=%.4f AUC=%.4f\n', ...
        accuracy, sensitivity, specificity, aucVal);
end
