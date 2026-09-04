function plotCalibrationCurve(cal, varargin)
% plotCalibrationCurve  Plot reliability diagram and calibration metrics
%
%   plotCalibrationCurve(cal)
%   plotCalibrationCurve(cal, 'SavePath', 'path/to/save.png')
%
%   Input:
%       cal - Output from evaluateCalibration

    p = inputParser;
    addRequired(p, 'cal');
    addParameter(p, 'SavePath', '', @ischar);
    parse(p, cal, varargin{:});

    fig = figure('Name', 'Calibration Analysis', 'NumberTitle', 'off', ...
        'Position', [100, 100, 1200, 400]);

    % === Subplot 1: Reliability Curve ===
    subplot(1, 3, 1);
    binConf = cal.reliability.binConfidence;
    binAcc = cal.reliability.binAccuracy;
    binCount = cal.reliability.binCount;

    % Plot perfect calibration line
    plot([0, 1], [0, 1], 'k--', 'LineWidth', 1.5);
    hold on;

    % Plot calibration curve
    validBins = binCount > 0;
    if any(validBins)
        scatter(binConf(validBins), binAcc(validBins), 50, binCount(validBins), 'filled');
        colorbar;
    end

    xlabel('Mean Predicted Probability');
    ylabel('Fraction of Positives');
    title(sprintf('Reliability Curve (ECE=%.3f)', cal.ece));
    grid on;
    axis square;
    xlim([0, 1]);
    ylim([0, 1]);
    hold off;

    % === Subplot 2: Confidence Distribution ===
    subplot(1, 3, 2);
    histogram('BinEdges', cal.reliability.binEdges, 'BinCounts', cal.reliability.binCount);
    xlabel('Confidence');
    ylabel('Count');
    title(sprintf('Confidence Distribution (Brier=%.3f)', cal.brier));
    grid on;

    % === Subplot 3: Per-Grade Metrics ===
    subplot(1, 3, 3);
    grades = cal.perGrade.grades;
    meanConf = cal.perGrade.meanConf;
    accuracy = cal.perGrade.accuracy;

    bar(grades, [meanConf, accuracy], 'grouped');
    xlabel('DR Grade');
    ylabel('Score');
    legend('Mean Confidence', 'Accuracy', 'Location', 'best');
    title('Per-Grade Calibration');
    grid on;

    sgtitle('DR Classifier Calibration Analysis', 'FontSize', 13, 'FontWeight', 'bold');

    % Save if path provided
    if ~isempty(p.Results.SavePath)
        saveas(fig, p.Results.SavePath);
    end
end
