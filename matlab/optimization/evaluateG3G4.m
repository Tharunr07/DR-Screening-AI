function results = evaluateG3G4(predictions, trueLabels, varargin)
% evaluateG3G4  Evaluate Grade 3/4 detection performance
%
%   results = evaluateG3G4(predictions, trueLabels)
%
%   Analyzes G3/G4 misclassification patterns and recovery strategies.

    p = inputParser;
    addRequired(p, 'predictions');
    addRequired(p, 'trueLabels');
    parse(p, predictions, trueLabels);

    predictions = predictions(:);
    trueLabels = trueLabels(:);

    results = struct();

    % G3 analysis
    g3Idx = find(trueLabels == 3);
    g3Total = numel(g3Idx);
    g3Correct = sum(predictions(g3Idx) == 3);

    results.g3 = struct();
    results.g3.total = g3Total;
    results.g3.correct = g3Correct;
    results.g3.accuracy = g3Correct / g3Total;

    % G3 misclassification targets
    g3Misclassified = g3Idx(predictions(g3Idx) ~= 3);
    if ~isempty(g3Misclassified)
        results.g3.misclassTargets = zeros(1, 5);
        for c = 1:5
            results.g3.misclassTargets(c) = sum(predictions(g3Misclassified) == c-1);
        end
    end

    % G4 analysis
    g4Idx = find(trueLabels == 4);
    g4Total = numel(g4Idx);
    g4Correct = sum(predictions(g4Idx) == 4);

    results.g4 = struct();
    results.g4.total = g4Total;
    results.g4.correct = g4Correct;
    results.g4.accuracy = g4Correct / g4Total;

    % G4 misclassification targets
    g4Misclassified = g4Idx(predictions(g4Idx) ~= 4);
    if ~isempty(g4Misclassified)
        results.g4.misclassTargets = zeros(1, 5);
        for c = 1:5
            results.g4.misclassTargets(c) = sum(predictions(g4Misclassified) == c-1);
        end
    end

    % G3/G4 combined (severe DR)
    severeTrue = trueLabels >= 3;
    severePred = predictions >= 3;

    tp = sum(severePred == 1 & severeTrue == 1);
    fp = sum(severePred == 1 & severeTrue == 0);
    fn = sum(severePred == 0 & severeTrue == 1);
    tn = sum(severePred == 0 & severeTrue == 0);

    results.severe = struct();
    results.severe.sensitivity = tp / (tp + fn);
    results.severe.specificity = tn / (tn + fp);
    results.severe.ppv = tp / (tp + fp);
    results.severe.npv = tn / (tn + fn);

    % Print summary
    fprintf('\n=== G3/G4 EVALUATION ===\n');
    fprintf('G3 (Severe): %d/%d correct (%.1f%%)\n', g3Correct, g3Total, results.g3.accuracy*100);
    fprintf('  Misclassified targets:\n');
    classNames = {'G0', 'G1', 'G2', 'G3', 'G4'};
    for c = 1:5
        if results.g3.misclassTargets(c) > 0
            fprintf('    → %s: %d\n', classNames{c}, results.g3.misclassTargets(c));
        end
    end

    fprintf('G4 (PDR): %d/%d correct (%.1f%%)\n', g4Correct, g4Total, results.g4.accuracy*100);
    fprintf('  Misclassified targets:\n');
    for c = 1:5
        if results.g4.misclassTargets(c) > 0
            fprintf('    → %s: %d\n', classNames{c}, results.g4.misclassTargets(c));
        end
    end

    fprintf('\nSevere DR (G3+G4):\n');
    fprintf('  Sensitivity: %.1f%%\n', results.severe.sensitivity*100);
    fprintf('  Specificity: %.1f%%\n', results.severe.specificity*100);
    fprintf('  PPV: %.1f%%\n', results.severe.ppv*100);
    fprintf('  NPV: %.1f%%\n', results.severe.npv*100);
end
