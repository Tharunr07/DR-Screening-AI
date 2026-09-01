function [hybridNet, hybridInfo] = trainHybridClassifier(trainedNet, XTrainClinical, YTrain, XValClinical, YVal, cfg)
% trainHybridClassifier  Train hybrid DL + clinical features model
%
%   [hybridNet, hybridInfo] = trainHybridClassifier(trainedNet, XTrainClinical, YTrain, XValClinical, YVal, cfg)

    if nargin < 6, cfg = deepLearningConfig(); end

    fprintf('[trainHybrid] Training hybrid DL + clinical features model\n');

    % Extract DL features from training images
    % Use the penultimate layer of the trained network
    % For simplicity, we'll use the CNN predictions as features

    % Get DL predictions as features
    trainImds = augmentedImageDatastore(cfg.image.size, ...
        imageDatastore(cfg.meta.trainPaths, 'Labels', categorical(cfg.meta.trainLabels)));
    [~, dlScoresTrain] = classify(trainedNet, trainImds);

    valImds = augmentedImageDatastore(cfg.image.size, ...
        imageDatastore(cfg.meta.valPaths, 'Labels', categorical(cfg.meta.valLabels)));
    [~, dlScoresVal] = classify(trainedNet, valImds);

    % Combine DL features with clinical features
    XTrainHybrid = [dlScoresTrain, XTrainClinical];
    XValHybrid = [dlScoresVal, XValClinical];

    % Handle NaN in clinical features
    featureMedian = nanmedian(XTrainClinical, 1);
    for j = 1:size(XTrainClinical, 2)
        XTrainHybrid(isnan(XTrainHybrid(:,j+5)), j+5) = featureMedian(j);
        XValHybrid(isnan(XValHybrid(:,j+5)), j+5) = featureMedian(j);
    end

    % Train SVM on hybrid features
    YTrainBin = double(YTrain >= cfg.referable.threshold);
    YValBin = double(YVal >= cfg.referable.threshold);

    nRef = sum(YTrainBin == 1); nNonRef = sum(YTrainBin == 0);
    w0 = 1.0; w1 = nNonRef / max(nRef, 1) * 1.5;
    costMat = [0 w1; w0 0];

    hybridNet = fitcsvm(XTrainHybrid, YTrainBin, 'KernelFunction', 'rbf', ...
        'KernelScale', 'auto', 'Standardize', true, 'Cost', costMat, 'ClassNames', [0 1]);
    hybridNet = fitPosterior(hybridNet, XTrainHybrid, YTrainBin);

    % Validate
    [~, ~, scVal] = predict(hybridNet, XValHybrid);
    refProb = scVal(:, 1);

    % Metrics
    tp = sum(refProb >= 0.5 & YValBin == 1);
    fn = sum(refProb < 0.5 & YValBin == 1);
    fp = sum(refProb >= 0.5 & YValBin == 0);
    tn = sum(refProb < 0.5 & YValBin == 0);

    hybridInfo = struct();
    hybridInfo.valSens = tp / max(1, tp+fn);
    hybridInfo.valSpec = tn / max(1, tn+fp);
    try
        [~,~,~,hybridInfo.valAUC] = perfcurve(YValBin, refProb, 1);
    catch
        hybridInfo.valAUC = NaN;
    end
    hybridInfo.featureMedian = featureMedian;

    fprintf('[trainHybrid] Val: sens=%.4f, spec=%.4f, AUC=%.4f\n', ...
        hybridInfo.valSens, hybridInfo.valSpec, hybridInfo.valAUC);
end
