function results = optimizeReferableThreshold(scores, trueLabels, varargin)
% optimizeReferableThreshold  Find optimal threshold for referable DR
%
%   results = optimizeReferableThreshold(scores, trueLabels)
%
%   Finds threshold that achieves:
%   - Sensitivity >= 90%
%   - Specificity >= 85%
%
%   Plots ROC, sensitivity/specificity vs threshold, and operating points.

    p = inputParser;
    addRequired(p, 'scores');
    addRequired(p, 'trueLabels');
    addParameter(p, 'SavePath', '', @ischar);
    parse(p, scores, trueLabels, varargin{:});

    trueLabels = trueLabels(:);
    numSamples = numel(trueLabels);

    % Convert to binary: referable (G2+) vs non-referable (G0-G1)
    referableTrue = double(trueLabels >= 2);
    referableProb = scores(:, 3) + scores(:, 4) + scores(:, 5);  % P(G2) + P(G3) + P(G4)

    % Evaluate at different thresholds
    thresholds = linspace(0, 1, 1000);
    sensitivities = zeros(size(thresholds));
    specificities = zeros(size(thresholds));

    for i = 1:numel(thresholds)
        thresh = thresholds(i);
        referablePred = double(referableProb >= thresh);

        tp = sum(referablePred == 1 & referableTrue == 1);
        fp = sum(referablePred == 1 & referableTrue == 0);
        fn = sum(referablePred == 0 & referableTrue == 1);
        tn = sum(referablePred == 0 & referableTrue == 0);

        sensitivities(i) = tp / (tp + fn);
        specificities(i) = tn / (tn + fp);
    end

    % Find thresholds that meet SIH requirements
    sihMask = sensitivities >= 0.90 & specificities >= 0.85;
    sihThresholds = thresholds(sihMask);

    % Find optimal threshold (maximizes Youden's J)
    jStatistic = sensitivities + specificities - 1;
    [~, optimalIdx] = max(jStatistic);
    optimalThreshold = thresholds(optimalIdx);
    optimalSens = sensitivities(optimalIdx);
    optimalSpec = specificities(optimalIdx);

    % Find threshold closest to SIH targets
    if ~isempty(sihThresholds)
        % Find threshold closest to (sens=0.90, spec=0.85)
        targetDist = abs(sensitivities(sihMask) - 0.90) + abs(specificities(sihMask) - 0.85);
        [~, closestIdx] = min(targetDist);
        sihThreshold = sihThresholds(closestIdx);
        sihSens = sensitivities(thresholds == sihThreshold);
        sihSpec = specificities(thresholds == sihThreshold);
    else
        sihThreshold = NaN;
        sihSens = NaN;
        sihSpec = NaN;
    end

    % ROC curve
    [fpr, tpr, ~, auc] = perfcurve(referableTrue, referableProb, 1);

    % Compile results
    results = struct();
    results.thresholds = thresholds;
    results.sensitivities = sensitivities;
    results.specificities = specificities;
    results.optimalThreshold = optimalThreshold;
    results.optimalSens = optimalSens;
    results.optimalSpec = optimalSpec;
    results.sihThreshold = sihThreshold;
    results.sihSens = sihSens;
    results.sihSpec = sihSpec;
    results.auc = auc;
    results.fpr = fpr;
    results.tpr = tpr;
    results.sihRequirementsMet = ~isempty(sihThresholds);

    % Print summary
    fprintf('\n=== THRESHOLD OPTIMIZATION ===\n');
    fprintf('Current threshold (0.5):\n');
    currentSens = sensitivities(thresholds == 0.5);
    currentSpec = specificities(thresholds == 0.5);
    fprintf('  Sensitivity: %.1f%%\n', currentSens*100);
    fprintf('  Specificity: %.1f%%\n', currentSpec*100);

    fprintf('\nOptimal threshold (Youden J):\n');
    fprintf('  Threshold: %.3f\n', optimalThreshold);
    fprintf('  Sensitivity: %.1f%%\n', optimalSens*100);
    fprintf('  Specificity: %.1f%%\n', optimalSpec*100);

    if results.sihRequirementsMet
        fprintf('\nSIH-compliant threshold found:\n');
        fprintf('  Threshold: %.3f\n', sihThreshold);
        fprintf('  Sensitivity: %.1f%%\n', sihSens*100);
        fprintf('  Specificity: %.1f%%\n', sihSpec*100);
    else
        fprintf('\nNo threshold achieves both SIH requirements:\n');
        fprintf('  Sensitivity >= 90%% AND Specificity >= 85%%\n');
        fprintf('  Best trade-off: Sens %.1f%% / Spec %.1f%%\n', optimalSens*100, optimalSpec*100);
    end

    % Create visualization
    fig = figure('Name', 'Threshold Optimization', 'NumberTitle', 'off', ...
        'Position', [100, 100, 1200, 400]);

    % Subplot 1: Sensitivity/Specificity vs Threshold
    subplot(1, 3, 1);
    plot(thresholds, sensitivities*100, 'b-', 'LineWidth', 2); hold on;
    plot(thresholds, specificities*100, 'r-', 'LineWidth', 2);
    xline(0.5, '--k', 'Current');
    if ~isnan(sihThreshold)
        xline(sihThreshold, '--g', 'SIH');
    end
    xlabel('Threshold');
    ylabel('Percentage (%)');
    title('Sensitivity/Specificity vs Threshold');
    legend('Sensitivity', 'Specificity', 'Location', 'best');
    grid on;
    hold off;

    % Subplot 2: ROC curve
    subplot(1, 3, 2);
    plot(fpr*100, tpr*100, 'b-', 'LineWidth', 2); hold on;
    plot([0, 100], [0, 100], '--k');
    xlabel('False Positive Rate (%)');
    ylabel('True Positive Rate (%)');
    title(sprintf('ROC Curve (AUC = %.3f)', auc));
    grid on;
    hold off;

    % Subplot 3: Youden's J statistic
    subplot(1, 3, 3);
    plot(thresholds, jStatistic, 'k-', 'LineWidth', 2); hold on;
    xline(optimalThreshold, '--r', 'Optimal');
    if ~isnan(sihThreshold)
        xline(sihThreshold, '--g', 'SIH');
    end
    xlabel('Threshold');
    ylabel("Youden's J");
    title("Youden's J Statistic");
    grid on;
    hold off;

    % Save if path provided
    if ~isempty(p.Results.SavePath)
        saveas(fig, p.Results.SavePath);
    end
end
