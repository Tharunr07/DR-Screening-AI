function [auc, fpr, tpr] = plotROCCurve(scores, trueLabels, varargin)
% plotROCCurve  Plot ROC curve for multi-class DR classification
%
%   [auc, fpr, tpr] = plotROCCurve(scores, trueLabels)
%
%   Plots one-vs-rest ROC curves for each DR grade and macro-average.
%
%   Input:
%       scores     - Nx5 matrix of class probabilities
%       trueLabels - Nx1 vector of true grades (0-4)
%
%   Output:
%       auc  - Area under curve (macro-average)
%       fpr  - False positive rates (macro-average)
%       tpr  - True positive rates (macro-average)

    p = inputParser;
    addRequired(p, 'scores');
    addRequired(p, 'trueLabels');
    addParameter(p, 'SavePath', '', @ischar);
    parse(p, scores, trueLabels, varargin{:});

    trueLabels = trueLabels(:);
    numClasses = 5;
    classNames = {'G0 (No DR)', 'G1 (Mild)', 'G2 (Moderate)', 'G3 (Severe)', 'G4 (PDR)'};
    colors = lines(numClasses);

    % Store per-class ROC data
    allFPR = cell(numClasses, 1);
    allTPR = cell(numClasses, 1);
    allAUC = zeros(numClasses, 1);

    fig = figure('Name', 'ROC Curve Analysis', 'NumberTitle', 'off', ...
        'Position', [100, 100, 1000, 500]);

    % Subplot 1: Per-class ROC
    subplot(1, 2, 1);
    hold on;

    for c = 1:numClasses
        % One-vs-rest binary labels
        binaryLabels = double(trueLabels == (c-1));

        % Get scores for this class
        classScores = scores(:, c);

        % Compute ROC
        [fpr_c, tpr_c, ~, auc_c] = perfcurve(binaryLabels, classScores, 1);

        allFPR{c} = fpr_c;
        allTPR{c} = tpr_c;
        allAUC(c) = auc_c;

        plot(fpr_c, tpr_c, 'Color', colors(c, :), 'LineWidth', 2, ...
            'DisplayName', sprintf('%s (AUC=%.3f)', classNames{c}, auc_c));
    end

    % Plot diagonal (random classifier)
    plot([0, 1], [0, 1], 'k--', 'LineWidth', 1, 'DisplayName', 'Random');

    xlabel('False Positive Rate (1 - Specificity)');
    ylabel('True Positive Rate (Sensitivity)');
    title('Per-Class ROC Curves');
    legend('Location', 'southeast', 'FontSize', 8);
    grid on;
    axis square;
    xlim([0, 1]);
    ylim([0, 1]);
    hold off;

    % Subplot 2: Macro-average ROC
    subplot(1, 2, 2);

    % Interpolate all ROCs to common FPR points
    commonFPR = linspace(0, 1, 100);
    interpTPR = zeros(numClasses, 100);

    for c = 1:numClasses
        % Remove duplicate FPR values
        [uniqueFPR, uniqueIdx] = unique(allFPR{c});
        uniqueTPR = allTPR{c}(uniqueIdx);

        if numel(uniqueFPR) > 1
            interpTPR(c, :) = interp1(uniqueFPR, uniqueTPR, commonFPR, 'linear', 0);
        else
            interpTPR(c, :) = 0;
        end
    end

    % Macro-average
    macroTPR = mean(interpTPR, 1);
    macroAUC = trapz(commonFPR, macroTPR);

    % Store for output
    fpr = commonFPR;
    tpr = macroTPR;
    auc = macroAUC;

    plot(commonFPR, macroTPR, 'b-', 'LineWidth', 3, ...
        'DisplayName', sprintf('Macro-average (AUC=%.3f)', macroAUC));
    hold on;
    plot([0, 1], [0, 1], 'k--', 'LineWidth', 1, 'DisplayName', 'Random');
    xlabel('False Positive Rate (1 - Specificity)');
    ylabel('True Positive Rate (Sensitivity)');
    title('Macro-Average ROC Curve');
    legend('Location', 'southeast');
    grid on;
    axis square;
    xlim([0, 1]);
    ylim([0, 1]);
    hold off;

    sgtitle('DR Classification ROC Analysis', 'FontSize', 13, 'FontWeight', 'bold');

    % Save if path provided
    if ~isempty(p.Results.SavePath)
        saveas(fig, p.Results.SavePath);
    end

    % Print summary
    fprintf('\n=== ROC ANALYSIS ===\n');
    fprintf('Per-Class AUC:\n');
    for c = 1:numClasses
        fprintf('  %s: %.3f\n', classNames{c}, allAUC(c));
    end
    fprintf('Macro-average AUC: %.3f\n', macroAUC);
end
