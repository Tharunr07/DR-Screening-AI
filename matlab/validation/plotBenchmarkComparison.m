function fig = plotBenchmarkComparison(benchmarks, varargin)
% plotBenchmarkComparison  Compare our model with published benchmarks
%
%   fig = plotBenchmarkComparison(benchmarks)
%
%   Creates comparison charts for sensitivity, specificity, and AUC.

    p = inputParser;
    addRequired(p, 'benchmarks');
    addParameter(p, 'SavePath', '', @ischar);
    parse(p, benchmarks, varargin{:});

    % Extract data for comparison
    names = fieldnames(benchmarks);
    numBenchmarks = numel(names);

    sensValues = zeros(numBenchmarks, 1);
    specValues = zeros(numBenchmarks, 1);
    aucValues = zeros(numBenchmarks, 1);
    labels = cell(numBenchmarks, 1);

    for i = 1:numBenchmarks
        bm = benchmarks.(names{i});
        sensValues(i) = bm.sensitivity;
        specValues(i) = bm.specificity;
        aucValues(i) = bm.auc;
        labels{i} = bm.name;
    end

    % Create figure
    fig = figure('Name', 'Benchmark Comparison', 'NumberTitle', 'off', ...
        'Position', [100, 100, 1200, 800]);

    % Subplot 1: Sensitivity comparison
    subplot(2, 2, 1);
    barh(sensValues * 100);
    set(gca, 'YTick', 1:numBenchmarks, 'YTickLabel', labels);
    xlabel('Sensitivity (%)');
    title('Sensitivity Comparison');
    xlim([0, 105]);
    grid on;

    % Add value labels
    for i = 1:numBenchmarks
        text(sensValues(i)*100 + 1, i, sprintf('%.1f%%', sensValues(i)*100), ...
            'VerticalAlignment', 'middle');
    end

    % Subplot 2: Specificity comparison
    subplot(2, 2, 2);
    barh(specValues * 100);
    set(gca, 'YTick', 1:numBenchmarks, 'YTickLabel', labels);
    xlabel('Specificity (%)');
    title('Specificity Comparison');
    xlim([0, 105]);
    grid on;

    for i = 1:numBenchmarks
        text(specValues(i)*100 + 1, i, sprintf('%.1f%%', specValues(i)*100), ...
            'VerticalAlignment', 'middle');
    end

    % Subplot 3: AUC comparison
    subplot(2, 2, 3);
    barh(aucValues);
    set(gca, 'YTick', 1:numBenchmarks, 'YTickLabel', labels);
    xlabel('AUC');
    title('AUC Comparison');
    xlim([0, 1.1]);
    grid on;

    for i = 1:numBenchmarks
        text(aucValues(i) + 0.01, i, sprintf('%.3f', aucValues(i)), ...
            'VerticalAlignment', 'middle');
    end

    % Subplot 4: Sensitivity vs Specificity scatter
    subplot(2, 2, 4);
    scatter(specValues * 100, sensValues * 100, 100, 'filled');
    hold on;

    % Add labels
    for i = 1:numBenchmarks
        text(specValues(i)*100 + 1, sensValues(i)*100, labels{i}, ...
            'VerticalAlignment', 'bottom', 'FontSize', 8);
    end

    % Add target lines
    xline(85, '--r', 'Specificity Target');
    yline(90, '--r', 'Sensitivity Target');

    xlabel('Specificity (%)');
    ylabel('Sensitivity (%)');
    title('Sensitivity vs Specificity');
    grid on;
    hold off;

    % Save if path provided
    if ~isempty(p.Results.SavePath)
        saveas(fig, p.Results.SavePath);
    end
end
