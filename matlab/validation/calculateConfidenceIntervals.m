function ci = calculateConfidenceIntervals(predictions, trueLabels, scores, varargin)
% calculateConfidenceIntervals  Calculate bootstrap confidence intervals
%
%   ci = calculateConfidenceIntervals(predictions, trueLabels, scores)
%
%   Calculates 95% CI for key metrics using bootstrap resampling.
%
%   Input:
%       predictions - Nx1 vector of predicted grades (0-4)
%       trueLabels  - Nx1 vector of true grades (0-4)
%       scores      - Nx5 matrix of class probabilities
%
%   Output:
%       ci - Struct with confidence intervals

    p = inputParser;
    addRequired(p, 'predictions');
    addRequired(p, 'trueLabels');
    addRequired(p, 'scores');
    addParameter(p, 'NumBootstrap', 1000, @isnumeric);
    addParameter(p, 'ConfidenceLevel', 0.95, @isnumeric);
    parse(p, predictions, trueLabels, scores, varargin{:});

    numBootstrap = p.Results.NumBootstrap;
    confLevel = p.Results.ConfidenceLevel;
    alpha = 1 - confLevel;

    % Ensure column vectors
    predictions = predictions(:);
    trueLabels = trueLabels(:);
    n = numel(trueLabels);

    % Bootstrap resampling
    bootSensitivity = zeros(numBootstrap, 1);
    bootSpecificity = zeros(numBootstrap, 1);
    bootAccuracy = zeros(numBootstrap, 1);
    bootF1 = zeros(numBootstrap, 1);
    bootAUC = zeros(numBootstrap, 1);

    for b = 1:numBootstrap
        % Sample with replacement
        idx = randi(n, n, 1);
        bootPred = predictions(idx);
        bootTrue = trueLabels(idx);
        bootScores = scores(idx, :);

        % Binary referable DR
        bootPredBin = double(bootPred >= 2);
        bootTrueBin = double(bootTrue >= 2);

        % Sensitivity
        tp = sum(bootPredBin == 1 & bootTrueBin == 1);
        fn = sum(bootPredBin == 0 & bootTrueBin == 1);
        bootSensitivity(b) = tp / (tp + fn);

        % Specificity
        tn = sum(bootPredBin == 0 & bootTrueBin == 0);
        fp = sum(bootPredBin == 1 & bootTrueBin == 0);
        bootSpecificity(b) = tn / (tn + fp);

        % Accuracy
        bootAccuracy(b) = sum(bootPred == bootTrue) / numel(bootTrue);

        % F1
        ppv = tp / (tp + fp);
        bootF1(b) = 2 * ppv * bootSensitivity(b) / (ppv + bootSensitivity(b));

        % AUC (macro-average)
        numClasses = 5;
        aucPerClass = zeros(numClasses, 1);
        for c = 1:numClasses
            binaryLabels = double(bootTrue == (c-1));
            classScores = bootScores(:, c);
            try
                [~, ~, ~, aucPerClass(c)] = perfcurve(binaryLabels, classScores, 1);
            catch
                aucPerClass(c) = 0.5;
            end
        end
        bootAUC(b) = mean(aucPerClass);
    end

    % Calculate confidence intervals
    ci = struct();
    ci.confidenceLevel = confLevel;
    ci.numBootstrap = numBootstrap;

    % Sensitivity CI
    ci.sensitivity.mean = mean(bootSensitivity);
    ci.sensitivity.std = std(bootSensitivity);
    ci.sensitivity.ci = quantile(bootSensitivity, [alpha/2, 1-alpha/2]);

    % Specificity CI
    ci.specificity.mean = mean(bootSpecificity);
    ci.specificity.std = std(bootSpecificity);
    ci.specificity.ci = quantile(bootSpecificity, [alpha/2, 1-alpha/2]);

    % Accuracy CI
    ci.accuracy.mean = mean(bootAccuracy);
    ci.accuracy.std = std(bootAccuracy);
    ci.accuracy.ci = quantile(bootAccuracy, [alpha/2, 1-alpha/2]);

    % F1 CI
    ci.f1.mean = mean(bootF1);
    ci.f1.std = std(bootF1);
    ci.f1.ci = quantile(bootF1, [alpha/2, 1-alpha/2]);

    % AUC CI
    ci.auc.mean = mean(bootAUC);
    ci.auc.std = std(bootAUC);
    ci.auc.ci = quantile(bootAUC, [alpha/2, 1-alpha/2]);

    % Print summary
    fprintf('\n=== CONFIDENCE INTERVALS (%.0f%% CI, %d bootstrap) ===\n', ...
        confLevel*100, numBootstrap);
    fprintf('Metric         Mean      95%% CI\n');
    fprintf('Sensitivity    %.1f%%    [%.1f%%, %.1f%%]\n', ...
        ci.sensitivity.mean*100, ci.sensitivity.ci(1)*100, ci.sensitivity.ci(2)*100);
    fprintf('Specificity    %.1f%%    [%.1f%%, %.1f%%]\n', ...
        ci.specificity.mean*100, ci.specificity.ci(1)*100, ci.specificity.ci(2)*100);
    fprintf('Accuracy       %.1f%%    [%.1f%%, %.1f%%]\n', ...
        ci.accuracy.mean*100, ci.accuracy.ci(1)*100, ci.accuracy.ci(2)*100);
    fprintf('F1 Score       %.1f%%    [%.1f%%, %.1f%%]\n', ...
        ci.f1.mean*100, ci.f1.ci(1)*100, ci.f1.ci(2)*100);
    fprintf('AUC            %.3f     [%.3f, %.3f]\n', ...
        ci.auc.mean, ci.auc.ci(1), ci.auc.ci(2));
end
