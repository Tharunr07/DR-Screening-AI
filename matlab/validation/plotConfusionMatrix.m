function plotConfusionMatrix(confMat, varargin)
% plotConfusionMatrix  Plot confusion matrix for DR classification
%
%   plotConfusionMatrix(confMat)
%
%   Input:
%       confMat - 5x5 confusion matrix (rows=true, cols=predicted)

    p = inputParser;
    addRequired(p, 'confMat');
    addParameter(p, 'SavePath', '', @ischar);
    parse(p, confMat, varargin{:});

    numClasses = 5;
    classNames = {'G0', 'G1', 'G2', 'G3', 'G4'};

    fig = figure('Name', 'Confusion Matrix', 'NumberTitle', 'off', ...
        'Position', [100, 100, 700, 600]);

    % Normalize by row (true labels) for percentages
    rowSums = sum(confMat, 2);
    confMatNorm = zeros(size(confMat));
    for i = 1:numClasses
        if rowSums(i) > 0
            confMatNorm(i, :) = confMat(i, :) / rowSums(i);
        end
    end

    % Plot confusion matrix as heatmap
    h = heatmap(classNames, classNames, confMatNorm, ...
        'Colormap', parula, ...
        'ColorLimits', [0, 1]);

    xlabel('Predicted Grade');
    ylabel('True Grade');
    title('DR Classification Confusion Matrix');

    % Save if path provided
    if ~isempty(p.Results.SavePath)
        saveas(fig, p.Results.SavePath);
    end

    % Print summary
    fprintf('\n=== CONFUSION MATRIX ===\n');
    fprintf('%-6s', '');
    for j = 1:numClasses
        fprintf('%6s', classNames{j});
    end
    fprintf('\n');

    for i = 1:numClasses
        fprintf('%-6s', classNames{i});
        for j = 1:numClasses
            fprintf('%6d', confMat(i, j));
        end
        fprintf('  (n=%d)\n', rowSums(i));
    end

    % Per-class accuracy
    fprintf('\nPer-class accuracy:\n');
    for i = 1:numClasses
        if rowSums(i) > 0
            acc = confMat(i, i) / rowSums(i) * 100;
            fprintf('  %s: %.1f%%\n', classNames{i}, acc);
        end
    end
end
