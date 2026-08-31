function [model, trainInfo] = trainDRClassifier(XTrain, YTrain, XVal, YVal, cfg)
% trainDRClassifier  Train 5-class DR severity classifier
%
%   [model, trainInfo] = trainDRClassifier(XTrain, YTrain, XVal, YVal, cfg)
%
%   Trains ECOC-SVM classifier with class-weight balancing.
%   Returns trained model and validation performance info.

    if nargin < 5, cfg = classificationConfig(); end
    rng(cfg.seed);

    fprintf('[trainDRClassifier] Training on %d samples, %d features\n', size(XTrain,1), size(XTrain,2));

    % Handle NaN features: replace with column median
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

    % Class distribution
    classes = 0:4;
    classCounts = arrayfun(@(c) sum(YTrain == c), classes);
    totalSamples = sum(classCounts);

    % Cost-sensitive weights: inverse frequency
    if strcmp(cfg.imbalance.strategy, 'cost-sensitive')
        classWeights = totalSamples ./ (numel(classes) .* max(classCounts, 1));
    else
        classWeights = ones(1, numel(classes));
    end
    fprintf('[trainDRClassifier] Class weights: ');
    for g = 1:numel(classes)
        fprintf('%d:%.3f ', classes(g), classWeights(g));
    end
    fprintf('\n');

    % Template SVM with class weights
    template = templateSVM('KernelFunction', 'rbf', ...
        'KernelScale', 'auto', ...
        'Standardize', true, ...
        'ClassNames', classes);

    % ECOC model with multi-class coding
    model = fitcecoc(XTrain, YTrain, ...
        'Learners', template, ...
        'Coding', 'onevsall', ...
        'ClassNames', classes, ...
        'Verbose', 0);

    % Apply class weights post-hoc via cost matrix
    if strcmp(cfg.imbalance.strategy, 'cost-sensitive')
        costMatrix = ones(numel(classes)) - eye(numel(classes));
        for g = 1:numel(classes)
            costMatrix(g, :) = costMatrix(g, :) * classWeights(g);
        end
        model = fitcecoc(XTrain, YTrain, ...
            'Learners', template, ...
            'Coding', 'onevsall', ...
            'ClassNames', classes, ...
            'Cost', costMatrix, ...
            'Verbose', 0);
    end

    % Validate
    [YPredVal, ~, scoresVal] = predict(model, XValClean);
    valAcc = sum(YPredVal(:) == YVal(:)) / numel(YVal);

    % Per-class sensitivity
    valSensitivity = zeros(1, numel(classes));
    valSpecificity = zeros(1, numel(classes));
    for g = 1:numel(classes)
        tp = sum(YPredVal == classes(g) & YVal == classes(g));
        fn = sum(YPredVal ~= classes(g) & YVal == classes(g));
        fp = sum(YPredVal == classes(g) & YVal ~= classes(g));
        tn = sum(YPredVal ~= classes(g) & YVal ~= classes(g));
        valSensitivity(g) = tp / max(1, tp + fn);
        valSpecificity(g) = tn / max(1, tn + fp);
    end

    trainInfo = struct();
    trainInfo.valAccuracy = valAcc;
    trainInfo.valSensitivity = valSensitivity;
    trainInfo.valSpecificity = valSpecificity;
    trainInfo.classWeights = classWeights;
    trainInfo.featureMedian = featureMedian;
    trainInfo.nTrain = size(XTrain, 1);
    trainInfo.nVal = numel(YVal);

    fprintf('[trainDRClassifier] Validation accuracy: %.4f\n', valAcc);
    fprintf('[trainDRClassifier] Per-class sensitivity: ');
    for g = 1:numel(classes)
        fprintf('%d:%.3f ', classes(g), valSensitivity(g));
    end
    fprintf('\n');
end
