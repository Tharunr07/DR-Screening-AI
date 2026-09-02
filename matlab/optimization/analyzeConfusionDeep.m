function analysis = analyzeConfusionDeep(predictions, trueLabels, scores, varargin)
% analyzeConfusionDeep  Deep analysis of confusion patterns
%
%   analysis = analyzeConfusionDeep(predictions, trueLabels, scores)
%
%   Analyzes:
%   - Grade-to-grade confusion matrix
%   - G3/G4 misclassification patterns
%   - Confidence of correct vs incorrect predictions
%   - Grade boundary confusion (G1/G2, G2/G3)
%   - Dataset-specific patterns

    p = inputParser;
    addRequired(p, 'predictions');
    addRequired(p, 'trueLabels');
    addRequired(p, 'scores');
    parse(p, predictions, trueLabels, scores);

    predictions = predictions(:);
    trueLabels = trueLabels(:);
    numSamples = numel(trueLabels);

    analysis = struct();

    % === 1. Full Grade-to-Grade Confusion Matrix ===
    numClasses = 5;
    classNames = {'G0', 'G1', 'G2', 'G3', 'G4'};
    confusionMat = zeros(numClasses, numClasses);

    for i = 1:numSamples
        trueGrade = trueLabels(i) + 1;  % 1-indexed
        predGrade = predictions(i) + 1;
        confusionMat(trueGrade, predGrade) = confusionMat(trueGrade, predGrade) + 1;
    end

    analysis.confusionMat = confusionMat;
    analysis.classNames = classNames;

    % === 2. G3/G4 Misclassification Analysis ===
    % G3: Where do the 32 misclassified go?
    g3Idx = find(trueLabels == 3);
    g3Total = numel(g3Idx);
    g3Correct = sum(predictions(g3Idx) == 3);

    analysis.g3 = struct();
    analysis.g3.total = g3Total;
    analysis.g3.correct = g3Correct;
    analysis.g3.accuracy = g3Correct / g3Total;

    % G3 misclassification targets
    g3Misclassified = g3Idx(predictions(g3Idx) ~= 3);
    if ~isempty(g3Misclassified)
        g3MisPred = predictions(g3Misclassified);
        analysis.g3.misclassTargets = zeros(1, numClasses);
        for c = 1:numClasses
            analysis.g3.misclassTargets(c) = sum(g3MisPred == c-1);
        end
        analysis.g3.misclassTargetsPct = analysis.g3.misclassTargets / numel(g3Misclassified);

        % Confidence of G3 misclassifications
        analysis.g3.misclassConfidence = mean(max(scores(g3Misclassified, :), [], 2));
        analysis.g3.correctConfidence = mean(max(scores(g3Idx(predictions(g3Idx) == 3), :), [], 2));
    end

    % G4: Where do the 31 misclassified go?
    g4Idx = find(trueLabels == 4);
    g4Total = numel(g4Idx);
    g4Correct = sum(predictions(g4Idx) == 4);

    analysis.g4 = struct();
    analysis.g4.total = g4Total;
    analysis.g4.correct = g4Correct;
    analysis.g4.accuracy = g4Correct / g4Total;

    % G4 misclassification targets
    g4Misclassified = g4Idx(predictions(g4Idx) ~= 4);
    if ~isempty(g4Misclassified)
        g4MisPred = predictions(g4Misclassified);
        analysis.g4.misclassTargets = zeros(1, numClasses);
        for c = 1:numClasses
            analysis.g4.misclassTargets(c) = sum(g4MisPred == c-1);
        end
        analysis.g4.misclassTargetsPct = analysis.g4.misclassTargets / numel(g4Misclassified);

        % Confidence of G4 misclassifications
        analysis.g4.misclassConfidence = mean(max(scores(g4Misclassified, :), [], 2));
        analysis.g4.correctConfidence = mean(max(scores(g4Idx(predictions(g4Idx) == 4), :), [], 2));
    end

    % === 3. Grade Boundary Confusion ===
    % G1/G2 boundary
    g1Idx = find(trueLabels == 1);
    g2Idx = find(trueLabels == 2);

    analysis.g1g2 = struct();
    % G1 → G2 (upgraded)
    analysis.g1g2.upgraded = sum(predictions(g1Idx) == 2);
    % G2 → G1 (downgraded)
    analysis.g2g1.downgraded = sum(predictions(g2Idx) == 1);

    % G2/G3 boundary
    analysis.g2g3 = struct();
    % G2 → G3 (upgraded)
    analysis.g2g3.upgraded = sum(predictions(g2Idx) == 3);
    % G3 → G2 (downgraded)
    analysis.g3g2.downgraded = sum(predictions(g3Idx) == 2);

    % G3/G4 boundary
    analysis.g3g4 = struct();
    % G3 → G4 (upgraded)
    analysis.g3g4.upgraded = sum(predictions(g3Idx) == 4);
    % G4 → G3 (downgraded)
    analysis.g4g3.downgraded = sum(predictions(g4Idx) == 3);

    % === 4. Confidence Distribution ===
    correctMask = predictions == trueLabels;
    incorrectMask = ~correctMask;

    analysis.confidence = struct();
    analysis.confidence.correctMean = mean(max(scores(correctMask, :), [], 2));
    analysis.confidence.incorrectMean = mean(max(scores(incorrectMask, :), [], 2));
    analysis.confidence.correctStd = std(max(scores(correctMask, :), [], 2));
    analysis.confidence.incorrectStd = std(max(scores(incorrectMask, :), [], 2));

    % Per-class confidence
    analysis.confidence.perClassCorrect = zeros(1, numClasses);
    analysis.confidence.perClassIncorrect = zeros(1, numClasses);
    for c = 1:numClasses
        classIdx = find(trueLabels == c-1);
        classCorrect = classIdx(predictions(classIdx) == c-1);
        classIncorrect = classIdx(predictions(classIdx) ~= c-1);

        if ~isempty(classCorrect)
            analysis.confidence.perClassCorrect(c) = mean(max(scores(classCorrect, :), [], 2));
        end
        if ~isempty(classIncorrect)
            analysis.confidence.perClassIncorrect(c) = mean(max(scores(classIncorrect, :), [], 2));
        end
    end

    % === 5. Referable DR Analysis ===
    referableTrue = trueLabels >= 2;
    referablePred = predictions >= 2;

    % False negatives: truly referable but predicted non-referable
    fnIdx = find(referableTrue == 1 & referablePred == 0);
    analysis.referable = struct();
    analysis.referable.fnCount = numel(fnIdx);
    analysis.referable.fnGradeDist = zeros(1, numClasses);
    for g = 1:numClasses
        analysis.referable.fnGradeDist(g) = sum(trueLabels(fnIdx) == g-1);
    end

    % False positives: non-referable predicted as referable
    fpIdx = find(referableTrue == 0 & referablePred == 1);
    analysis.referable.fpCount = numel(fpIdx);
    analysis.referable.fpGradeDist = zeros(1, numClasses);
    for g = 1:numClasses
        analysis.referable.fpGradeDist(g) = sum(trueLabels(fpIdx) == g-1);
    end

    % === 6. Print Summary ===
    fprintf('\n=== DEEP CONFUSION ANALYSIS ===\n');

    fprintf('\n1. Full Grade-to-Grade Confusion Matrix:\n');
    fprintf('%-6s', '');
    for j = 1:numClasses
        fprintf('%6s', classNames{j});
    end
    fprintf('  (True)\n');

    for i = 1:numClasses
        fprintf('%-6s', classNames{i});
        for j = 1:numClasses
            fprintf('%6d', confusionMat(i, j));
        end
        fprintf('\n');
    end

    fprintf('\n2. G3/G4 Misclassification Analysis:\n');
    fprintf('  G3: %d/%d correct (%.1f%%)\n', g3Correct, g3Total, analysis.g3.accuracy*100);
    fprintf('    Misclassified targets:\n');
    for c = 1:numClasses
        if analysis.g3.misclassTargets(c) > 0
            fprintf('      → %s: %d (%.1f%%)\n', classNames{c}, ...
                analysis.g3.misclassTargets(c), analysis.g3.misclassTargetsPct(c)*100);
        end
    end

    fprintf('  G4: %d/%d correct (%.1f%%)\n', g4Correct, g4Total, analysis.g4.accuracy*100);
    fprintf('    Misclassified targets:\n');
    for c = 1:numClasses
        if analysis.g4.misclassTargets(c) > 0
            fprintf('      → %s: %d (%.1f%%)\n', classNames{c}, ...
                analysis.g4.misclassTargets(c), analysis.g4.misclassTargetsPct(c)*100);
        end
    end

    fprintf('\n3. Grade Boundary Confusion:\n');
    fprintf('  G1→G2 (upgraded): %d cases\n', analysis.g1g2.upgraded);
    fprintf('  G2→G1 (downgraded): %d cases\n', analysis.g2g1.downgraded);
    fprintf('  G2→G3 (upgraded): %d cases\n', analysis.g2g3.upgraded);
    fprintf('  G3→G2 (downgraded): %d cases\n', analysis.g3g2.downgraded);
    fprintf('  G3→G4 (upgraded): %d cases\n', analysis.g3g4.upgraded);
    fprintf('  G4→G3 (downgraded): %d cases\n', analysis.g4g3.downgraded);

    fprintf('\n4. Confidence Analysis:\n');
    fprintf('  Correct predictions: %.3f ± %.3f\n', ...
        analysis.confidence.correctMean, analysis.confidence.correctStd);
    fprintf('  Incorrect predictions: %.3f ± %.3f\n', ...
        analysis.confidence.incorrectMean, analysis.confidence.incorrectStd);

    fprintf('\n5. Referable DR Errors:\n');
    fprintf('  False Negatives: %d (truly referable, predicted non-referable)\n', ...
        analysis.referable.fnCount);
    fprintf('  False Positives: %d (non-referable, predicted referable)\n', ...
        analysis.referable.fpCount);

    fprintf('\n=== ANALYSIS COMPLETE ===\n');
end
