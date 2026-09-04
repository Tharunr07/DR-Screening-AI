function [selectedThreshold, thresholdInfo] = selectReferableThreshold(trainedNet, imdsVal, cfg)
% selectReferableThreshold  Select optimal threshold for referable DR on validation
%
%   [selectedThreshold, thresholdInfo] = selectReferableThreshold(trainedNet, imdsVal, cfg)

    if nargin < 3, cfg = deepLearningConfig(); end

    fprintf('[selectThreshold] Selecting threshold on validation set\n');

    % Get validation predictions
    valImds = augmentedImageDatastore(cfg.image.size, imdsVal);
    [YPred, scores] = classify(trainedNet, valImds);
    YTrue = imdsVal.Labels;

    % Convert to numeric
    YTrueNum = double(YTrue) - 1;
    YTrueBin = double(YTrueNum >= cfg.referable.threshold);

    % Referable probability
    refProb = sum(scores(:, 3:5), 2);

    % ROC curve
    [fpr, tpr, thresholds, aucVal] = perfcurve(YTrueBin, refProb, 1);

    % Find thresholds
    bestF1 = 0; bestF1Thresh = 0.5;
    bestSpecForSens85 = 0; sens85Thresh = 0.5;
    bestSpecForSens90 = 0; sens90Thresh = 0.5;

    for i = 1:numel(thresholds)
        th = thresholds(i);
        pred = double(refProb >= th);
        tp = sum(pred == 1 & YTrueBin == 1);
        fn = sum(pred == 0 & YTrueBin == 1);
        fp = sum(pred == 1 & YTrueBin == 0);
        tn = sum(pred == 0 & YTrueBin == 0);
        sens = tp / max(1, tp+fn);
        spec = tn / max(1, tn+fp);
        prec = tp / max(1, tp+fp);
        f1 = 2*prec*sens / max(1, prec+sens);

        if f1 > bestF1
            bestF1 = f1; bestF1Thresh = th;
        end
        if sens >= 0.85 && spec > bestSpecForSens85
            bestSpecForSens85 = spec; sens85Thresh = th;
        end
        if sens >= 0.90 && spec > bestSpecForSens90
            bestSpecForSens90 = spec; sens90Thresh = th;
        end
    end

    % Select threshold: best F1 on validation
    selectedThreshold = bestF1Thresh;

    thresholdInfo = struct();
    thresholdInfo.auc = aucVal;
    thresholdInfo.bestF1Threshold = bestF1Thresh;
    thresholdInfo.bestF1 = bestF1;
    thresholdInfo.sens85Threshold = sens85Thresh;
    thresholdInfo.sens85Spec = bestSpecForSens85;
    thresholdInfo.sens90Threshold = sens90Thresh;
    thresholdInfo.sens90Spec = bestSpecForSens90;
    thresholdInfo.selectedThreshold = selectedThreshold;

    % Validate at selected threshold
    pred = double(refProb >= selectedThreshold);
    tp = sum(pred == 1 & YTrueBin == 1);
    fn = sum(pred == 0 & YTrueBin == 1);
    fp = sum(pred == 1 & YTrueBin == 0);
    tn = sum(pred == 0 & YTrueBin == 0);
    thresholdInfo.selectedSens = tp / max(1, tp+fn);
    thresholdInfo.selectedSpec = tn / max(1, tn+fp);

    fprintf('[selectThreshold] AUC: %.4f\n', aucVal);
    fprintf('[selectThreshold] Best F1: %.4f at threshold %.4f\n', bestF1, bestF1Thresh);
    fprintf('[selectThreshold] Sens>=0.85: spec=%.3f at threshold %.4f\n', bestSpecForSens85, sens85Thresh);
    fprintf('[selectThreshold] Sens>=0.90: spec=%.3f at threshold %.4f\n', bestSpecForSens90, sens90Thresh);
    fprintf('[selectThreshold] Selected: %.4f (sens=%.3f, spec=%.3f)\n', ...
        selectedThreshold, thresholdInfo.selectedSens, thresholdInfo.selectedSpec);
end
