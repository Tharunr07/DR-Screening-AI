function metrics = evaluateModelPerformance(predictions, trueLabels, varargin)
% evaluateModelPerformance  Evaluate 5-class DR classification performance
%
%   metrics = evaluateModelPerformance(predictions, trueLabels)
%
%   Calculates comprehensive metrics for DR grading:
%       - Accuracy, balanced accuracy
%       - Sensitivity, specificity per class
%       - Precision, recall, F1 per class
%       - Macro averages
%       - Confusion matrix
%
%   Input:
%       predictions - Nx1 vector of predicted grades (0-4)
%       trueLabels  - Nx1 vector of true grades (0-4)
%
%   Output:
%       metrics - Struct with comprehensive performance metrics

    p = inputParser;
    addRequired(p, 'predictions');
    addRequired(p, 'trueLabels');
    parse(p, predictions, trueLabels);

    % Ensure column vectors
    predictions = predictions(:);
    trueLabels = trueLabels(:);

    numClasses = 5;
    classNames = {'G0', 'G1', 'G2', 'G3', 'G4'};

    % Initialize metrics
    metrics = struct();
    metrics.numSamples = numel(trueLabels);
    metrics.numClasses = numClasses;
    metrics.classNames = classNames;

    % === Confusion Matrix ===
    confMat = zeros(numClasses, numClasses);
    for i = 1:numClasses
        for j = 1:numClasses
            confMat(i, j) = sum(trueLabels == (i-1) & predictions == (j-1));
        end
    end
    metrics.confusionMatrix = confMat;

    % === Overall Metrics ===
    metrics.accuracy = sum(predictions == trueLabels) / numel(trueLabels);

    % Per-class metrics
    tp = zeros(numClasses, 1);
    fp = zeros(numClasses, 1);
    fn = zeros(numClasses, 1);
    tn = zeros(numClasses, 1);

    for c = 1:numClasses
        tp(c) = confMat(c, c);
        fp(c) = sum(confMat(:, c)) - confMat(c, c);
        fn(c) = sum(confMat(c, :)) - confMat(c, c);
        tn(c) = sum(confMat(:)) - tp(c) - fp(c) - fn(c);
    end

    metrics.tp = tp;
    metrics.fp = fp;
    metrics.fn = fn;
    metrics.tn = tn;

    % Sensitivity (Recall) per class
    sensitivity = zeros(numClasses, 1);
    for c = 1:numClasses
        if (tp(c) + fn(c)) > 0
            sensitivity(c) = tp(c) / (tp(c) + fn(c));
        end
    end
    metrics.sensitivityPerClass = sensitivity;

    % Specificity per class
    specificity = zeros(numClasses, 1);
    for c = 1:numClasses
        if (tn(c) + fp(c)) > 0
            specificity(c) = tn(c) / (tn(c) + fp(c));
        end
    end
    metrics.specificityPerClass = specificity;

    % Precision (PPV) per class
    precision = zeros(numClasses, 1);
    for c = 1:numClasses
        if (tp(c) + fp(c)) > 0
            precision(c) = tp(c) / (tp(c) + fp(c));
        end
    end
    metrics.precisionPerClass = precision;

    % F1 score per class
    f1 = zeros(numClasses, 1);
    for c = 1:numClasses
        if (precision(c) + sensitivity(c)) > 0
            f1(c) = 2 * precision(c) * sensitivity(c) / (precision(c) + sensitivity(c));
        end
    end
    metrics.f1PerClass = f1;

    % Class distribution
    classCounts = zeros(numClasses, 1);
    for c = 1:numClasses
        classCounts(c) = sum(trueLabels == (c-1));
    end
    metrics.classCounts = classCounts;
    metrics.classDistribution = classCounts / sum(classCounts);

    % Macro averages
    metrics.macroSensitivity = mean(sensitivity);
    metrics.macroSpecificity = mean(specificity);
    metrics.macroPrecision = mean(precision);
    metrics.macroF1 = mean(f1);

    % Weighted averages (by class support)
    weights = classCounts / sum(classCounts);
    metrics.weightedSensitivity = sum(sensitivity .* weights);
    metrics.weightedSpecificity = sum(specificity .* weights);
    metrics.weightedPrecision = sum(precision .* weights);
    metrics.weightedF1 = sum(f1 .* weights);

    % Balanced accuracy (macro sensitivity)
    metrics.balancedAccuracy = metrics.macroSensitivity;

    % Print summary
    fprintf('\n=== MODEL PERFORMANCE SUMMARY ===\n');
    fprintf('Test Samples: %d\n', metrics.numSamples);
    fprintf('Accuracy: %.1f%%\n', metrics.accuracy * 100);
    fprintf('Balanced Accuracy: %.1f%%\n', metrics.balancedAccuracy * 100);
    fprintf('Macro F1: %.1f%%\n', metrics.macroF1 * 100);
    fprintf('\nPer-Class Metrics:\n');
    fprintf('%-5s %8s %8s %8s %8s %8s\n', 'Class', 'Count', 'Sens', 'Spec', 'Prec', 'F1');
    for c = 1:numClasses
        fprintf('%-5s %8d %7.1f%% %7.1f%% %7.1f%% %7.1f%%\n', ...
            classNames{c}, classCounts(c), ...
            sensitivity(c)*100, specificity(c)*100, ...
            precision(c)*100, f1(c)*100);
    end
end
